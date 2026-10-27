# HƯỚNG DẪN HẠ TẦNG RABBITMQ & HỆ THỐNG MESSAGE BUS (MASSTRANSIT)
## (RABBITMQ LIGHTWEIGHT TUNING, MODERN GRAFANA DASHBOARD & EVENT-DRIVEN GUIDE)

> **Mục tiêu tài liệu**: Hướng dẫn chi tiết về cấu hình RabbitMQ tối ưu siêu nhẹ (Lightweight), cách theo dõi và giám sát trực quan thông qua **Grafana Dashboard hiện đại (`:3000`)** hoặc **RabbitMQ Management Web UI (`:15672`)**, và quy chuẩn gỡ lỗi (debug) các thông điệp sự kiện (Integration Events) trong hệ sinh thái Nexus Microservices.

---

## 1. BẢN CHẤT & VAI TRÒ TRONG KIẾN TRÚC NEXUS

Trong kiến trúc Microservices phân tán, **RabbitMQ đóng vai trò là Trục giao tiếp bất đồng bộ (Asynchronous Event Bus)** kết nối các dịch vụ thông qua thư viện MassTransit:

```
[ UserService ] ──(Bắn Event)──▶ [ Exchange: SendOtpEmailIntegrationEvent ]
                                                │
                                                ▼ (Routing Key Binding)
                                  [ Queue: notification-service.otp-email ]
                                                │
                                                ▼ (Consume & Send Email)
                                      [ NotificationService ]
```

### Tại sao sử dụng RabbitMQ?
1. **Khử ghép nối thời gian (Temporal Decoupling)**: Khi người dùng bấm Đăng ký tài khoản, `UserService` lưu thông tin vào CSDL rồi bắn một sự kiện `SendOtpEmailIntegrationEvent` lên RabbitMQ và trả kết quả thành công ngay trong 50ms. Người dùng không cần phải chờ 2-3 giây để dịch vụ gửi mail SMTP xử lý xong.
2. **Khả năng chịu lỗi cao (Fault Tolerance & High Availability)**: Nếu `NotificationService` hoặc mạng gửi email bị sập tạm thời, thông điệp vẫn nằm an toàn trong hàng đợi (Queue) của RabbitMQ. Khi service sống lại, nó sẽ tự động lấy thông điệp ra xử lý tiếp mà không bị mất dữ liệu.
3. **Điều phối Giao dịch Phân tán (Saga Orchestration)**: Phục vụ luồng **Checkout Saga** giữa `CommerceService` (tạo đơn) $\rightarrow$ `WalletService` (trừ tiền) $\rightarrow$ `CatalogService` (trừ tồn kho) $\rightarrow$ `FulfillmentService` (giao vận). Nếu bất kỳ bước nào thất bại, các sự kiện bù trừ (Compensating Events) sẽ được bắn qua RabbitMQ để hoàn tiền và hoàn kho tự động.

---

## 2. CẤU HÌNH TỐI ƯU SIÊU NHẸ (LIGHTWEIGHT TUNING)

Mặc định RabbitMQ có thể tiêu tốn khá nhiều RAM (~150MB - 300MB) và CPU do mở nhiều Erlang scheduler threads và tính toán thống kê chi tiết từng giây. Hệ sinh thái Nexus đã áp dụng bộ cấu hình tinh chỉnh giúp RabbitMQ chạy **siêu nhẹ, chỉ ~70MB - 100MB RAM**:

| Tham Số Tối Ưu | Giá Trị Cấu Hình | Ý Nghĩa Kỹ Thuật |
| :--- | :--- | :--- |
| **Base Image** | `rabbitmq:3-management-alpine` | Bản Alpine siêu nhỏ gọn (chỉ **87.7MB** trên ổ cứng, nhẹ hơn bản Debian 3 lần). |
| **Giới hạn RAM (mem_limit)** | `350m` (Limit `350M`) | Đảm bảo container không bao giờ chiếm dụng quá 350MB RAM của máy dev. |
| **Erlang VM Schedulers** | `+S 2:2 +P 1048576` | Giới hạn 2 threads scheduler Erlang, giảm thiểu tối đa context switch và CPU ngầm. |
| **RAM High Watermark** | `0.6` (~210MB) | Yêu cầu Erlang chủ động gom rác (Garbage Collection) khi chạm 60% mức giới hạn. |
| **Management Rates Mode** | `basic` | Chuyển chế độ tính toán thống kê sang `basic` thay vì `detailed`, giúp **giảm 40% CPU/RAM**. |
| **Prometheus Exporter** | Cổng `15692` | Kích hoạt plugin `rabbitmq_prometheus` xuất chỉ số chuẩn hóa cho Prometheus & Grafana. |

File cấu hình chi tiết: `infra/rabbitmq/rabbitmq.conf`.

---

## 3. THÔNG SỐ KẾT NỐI & CÁC CỔNG DỊCH VỤ

| Thông Số | Cổng Mặc Định | Mục Đích Sử Dụng |
| :--- | :---: | :--- |
| **AMQP Protocol** | **`5672`** | Cổng giao tiếp chính cho MassTransit trong mã nguồn C#. |
| **Grafana Dashboard** *(Khuyên dùng)* | **`3000`** | Giao diện giám sát trực quan, hiện đại, dark theme tại `/d/nexus-rabbitmq`. |
| **Classic Management UI** | **`15672`** | Giao diện web gốc của RabbitMQ để quản lý và xem trực tiếp nội dung JSON tin nhắn. |
| **Prometheus Metrics** | **`15692`** | Endpoint thu thập metrics (`/metrics`) cho Prometheus. |
| **Tài khoản mặc định** | `guest` / `guest` | User và Password đăng nhập Web UI và kết nối AMQP local. |

### Lệnh khởi chạy nhanh:
```bash
# Khởi động RabbitMQ cùng hạ tầng Observability từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d rabbitmq prometheus grafana
```

---

## 4. HƯỚNG DẪN GIÁM SÁT & CÔNG CỤ THAO TÁC RABBITMQ TRỰC QUAN

Để giám sát và thao tác với RabbitMQ một cách dễ dàng, đẹp mắt và thuận tiện nhất cho lập trình viên, hệ thống hỗ trợ các phương án sau:

### 🌟 PHƯƠNG ÁN 1: GRAFANA DASHBOARD HIỆN ĐẠI (KHUYÊN DÙNG ĐỂ GIÁM SÁT)
👉 **Truy cập ngay**: **`http://localhost:3000/d/nexus-rabbitmq`** (Tự động đăng nhập Admin 100%, không cần tài khoản).

Giao diện được thiết kế với **Dark Theme hiện đại, trực quan và dễ nhìn**:

```
+---------------------------------------------------------------------------------------+
| 🐰 RabbitMQ Message Broker - Modern Overview                    [⚡ LIGHTWEIGHT 350MB] |
+---------------------------------------------------------------------------------------+
| 📦 Total Queued | ⏳ Ready (Waiting) | ⚙️ In-Flight | 🚀 Publish Rate | ✅ Ack Rate    |
|       0         |         0          |      0       |     0.0 req/s   |   0.0 req/s    |
+---------------------------------------------------------------------------------------+
| 📈 Real-Time Message Throughput                       | 🧠 RAM Footprint vs Watermark |
| [Biểu đồ Publish vs Deliver vs Ack Rate]              | [RAM thực tế ~74MB / 210MB]   |
+---------------------------------------------------------------------------------------+
| 📋 Live Queues Breakdown & Depth                      | 🍩 Distribution by Queue      |
| [Bảng chi tiết từng hàng đợi, ready, unack, total]    | [Biểu đồ tròn tỷ trọng queue] |
+---------------------------------------------------------------------------------------+
```

#### Các Panels chính trên Dashboard:
1. **Total Queued Messages**: Tổng số tin nhắn đang tồn đọng trong toàn bộ các hàng đợi. (Màu xanh: tốt, Màu vàng/đỏ: có ứ đọng).
2. **Ready (Waiting Delivery)**: Số tin nhắn đã vào hàng đợi và đang chờ Worker/Consumer lấy ra xử lý.
3. **In-Flight (Unacked)**: Số tin nhắn mà Consumer đã nhận nhưng chưa hoàn tất xử lý (chưa gửi Ack).
4. **Publish / Deliver / Ack Rates**: Biểu đồ thông lượng tin nhắn thời gian thực (tin nhắn vào vs tin nhắn ra mỗi giây).
5. **Live Queues Breakdown Table**: Liệt kê chi tiết từng hàng đợi (ví dụ: `send-otp-email`, `user-service`), cho phép phát hiện ngay hàng đợi nào đang bị nghẽn.
6. **Chuyển đổi 1-Click**: Trên thanh điều hướng đầu trang có nút bấm:
   - 🚀 **`Nexus Overview`**: Quay lại dashboard tổng quan microservices (`:3000/d/nexus-overview`).
   - 🐰 **`RabbitMQ Web UI (15672)`**: Mở nhanh giao diện gốc để soi JSON payload.

---

### 💻 PHƯƠNG ÁN 2: CÔNG CỤ GUI DESKTOP & EXTENSION DỄ DÙNG NHẤT CHO DEV

Nếu bạn muốn một công cụ **dễ thao tác kéo thả, xem JSON đẹp, re-queue, test message** mà không thích giao diện web cổ điển:

#### 1. VS Code Extension: "RabbitMQ" (Khuyên dùng khi code)
- **Cài đặt**: Tìm kiếm `RabbitMQ` trên VS Code Marketplace (của tác giả *bpatra* hoặc *redhat*).
- **Kết nối**: Điền URL `http://guest:guest@localhost:15672`.
- **Tính năng nổi bật**:
  + Hiển thị cây Queues / Exchanges ngay trên thanh Sidebar của VS Code.
  + Xem số lượng tin nhắn, purge queue, di chuyển tin nhắn chỉ bằng 1 click chuột phải.
  + Gửi tin nhắn mẫu (Publish test message) trực tiếp từ editor mà không cần mở trình duyệt.

#### 2. Ứng dụng Desktop: "QueueExplorer" hoặc "RabbitConnect"
- **Đặc điểm**: Giao diện giống như File Explorer của Windows/macOS.
- **Ưu điểm**:
  + Xem danh sách tin nhắn theo dạng bảng (Message ID, Payload size, Timestamp).
  + Bấm đúp vào tin nhắn để xem nội dung JSON với định dạng màu sắc (syntax highlighting).
  + Hỗ trợ kéo thả tin nhắn từ Dead-Letter Queue / Error Queue về lại hàng đợi chính để retry cực kỳ tiện lợi.

---

### 🔍 PHƯƠNG ÁN 3: RABBITMQ WEB MANAGEMENT GỐC (ĐÃ TỐI ƯU SIÊU NHẸ)
👉 **Truy cập**: **`http://localhost:15672`** (Đăng nhập: `guest` / `guest`).

Sử dụng giao diện này khi bạn cần **soi nội dung chi tiết từng trường dữ liệu JSON** của tin nhắn hoặc xem sơ đồ liên kết Exchange-Queue (Bindings).

#### Cách đọc và soi nội dung tin nhắn trong Queue:
1. Trên thanh menu, chọn tab **Queues**.
2. Bấm vào tên hàng đợi bạn muốn kiểm tra (ví dụ: `send-otp-email`).
3. Cuộn chuột xuống mục **Get messages**.
4. Điền các thông số:
   - `Messages`: `1` (Số lượng tin muốn xem).
   - `Requeue`: **Chọn `Yes`** *(CỰC KỲ QUAN TRỌNG: Để sau khi xem xong, tin nhắn vẫn nằm lại trong hàng đợi cho worker xử lý, không bị mất dữ liệu)*.
   - `Encoding`: `Auto string / UTF-8`.
5. Bấm nút **Get Message(s)**.
6. Toàn bộ nội dung JSON của sự kiện sẽ hiển thị ngay bên dưới (Headers, MassTransit metadata, Body).

---

## 5. XỬ LÝ SỰ CỐ & GỠ LỖI TIN NHẮN (DEBUGGING GUIDE)

### 5.1. Tin nhắn bị lỗi: Hàng đợi `_error`
Khi một Consumer gặp lỗi ngoại lệ chưa xử lý (ví dụ: lỗi kết nối SMTP, lỗi CSDL) và retry hết số lần cho phép:
- MassTransit sẽ tự động di chuyển tin nhắn đó sang hàng đợi có đuôi `_error` (ví dụ: `notification-service_error`).
- **Cách gỡ lỗi**:
  1. Vào RabbitMQ UI (`:15672`) $\rightarrow$ tab **Queues** $\rightarrow$ chọn queue có đuôi `_error`.
  2. Bấm **Get Message(s)**.
  3. Kiểm tra mục **Headers**:
     - `MT-Fault-Message`: Tóm tắt thông báo lỗi Exception.
     - `MT-Fault-StackTrace`: Dòng code C# chính xác gây ra lỗi!

### 5.2. Tin nhắn bị bỏ qua: Hàng đợi `_skipped`
- Xảy ra khi một tin nhắn được gửi vào queue nhưng không có bất kỳ Consumer nào trong service đăng ký kiểu dữ liệu của tin nhắn đó.
- Kiểm tra lại khai báo interface/record sự kiện giữa Producer và Consumer.

---

## 6. QUY CHUẨN ĐẶC TẢ SỰ KIỆN TRONG C# (MASSTRANSIT INTEGRATION EVENTS)

1. **Quy tắc đặt tên theo thì Quá Khứ (Past Tense)**:
   - Thể hiện sự kiện đã xảy ra thành công trong hệ thống.
   - ✅ Đúng: `SendOtpEmailIntegrationEvent`, `UserRegisteredIntegrationEvent`, `OrderCreatedIntegrationEvent`.
   - ❌ Sai: `SendOtpEmail`, `CreateOrder` (Đây là Command, không phải Event).
2. **Khai báo Record Immutable**:
   - Sử dụng `record` trong C# với các thuộc tính chỉ đọc:
   ```csharp
   namespace Nexus.Contracts.Events;

   public sealed record SendOtpEmailIntegrationEvent(
       string Email,
       string FullName,
       string Otp,
       int ExpiresInMinutes,
       string? TraceId = null);
   ```
3. **Liên kết Distributed Tracing**:
   - Luôn kèm `TraceId` trong payload hoặc header để Tempo & Grafana liên kết luồng gọi từ HTTP Gateway sang RabbitMQ Worker.
