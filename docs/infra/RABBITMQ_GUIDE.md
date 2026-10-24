# HƯỚNG DẪN HẠ TẦNG RABBITMQ & HỆ THỐNG MESSAGE BUS (MASSTRANSIT)
## (RABBITMQ ARCHITECTURE, MANAGEMENT UI & EVENT-DRIVEN GUIDE)

> **Mục tiêu tài liệu**: Giải thích bản chất kiến trúc, vai trò của RabbitMQ trong hệ thống Nexus Microservices, thông tin kết nối và hướng dẫn chi tiết cách sử dụng RabbitMQ Management UI để kiểm tra, giám sát và gỡ lỗi (debug) các thông điệp sự kiện (Integration Events).

---

## 1. BẢN CHẤT & VAI TRÒ TRONG KIẾN TRÚC NEXUS

Trong kiến trúc Microservices phân tán, **RabbitMQ đóng vai trò là Trục giao tiếp bất đồng bộ (Asynchronous Event Bus)**:

```
[ UserService ] ──(Bắn Event)──▶ [ Exchange: SendOtpEmailIntegrationEvent ]
                                                │
                                                ▼ (Routing Key Binding)
                                 [ Queue: notification-service.otp-email ]
                                                │
                                                ▼ (Consume & Send Email)
                                     [ NotificationService ]
```

### Tại sao phải dùng RabbitMQ thay vì gọi trực tiếp HTTP/gRPC?
1. **Khử ghép nối thời gian (Temporal Decoupling)**: Khi người dùng bấm Đăng ký tài khoản, `UserService` lưu thông tin vào CSDL rồi bắn một sự kiện `SendOtpEmailIntegrationEvent` lên RabbitMQ và trả kết quả thành công ngay trong 50ms. Người dùng không cần phải chờ 2-3 giây để dịch vụ gửi mail SMTP xử lý xong.
2. **Khả năng chịu lỗi cao (Fault Tolerance & High Availability)**: Nếu `NotificationService` hoặc mạng gửi email bị sập tạm thời, thông điệp vẫn nằm an toàn trong hàng đợi (Queue) của RabbitMQ. Khi service sống lại, nó sẽ tự động lấy thông điệp ra xử lý tiếp mà không bị mất dữ liệu.
3. **Điều phối Giao dịch Phân tán (Saga Orchestration)**: Phục vụ luồng **Checkout Saga** giữa `CommerceService` (tạo đơn) $\rightarrow$ `WalletService` (trừ tiền) $\rightarrow$ `CatalogService` (trừ tồn kho) $\rightarrow$ `FulfillmentService` (giao vận). Nếu bất kỳ bước nào thất bại, các sự kiện bù trừ (Compensating Events) sẽ được bắn qua RabbitMQ để hoàn tiền và hoàn kho tự động.

---

## 2. THÔNG SỐ KẾT NỐI & TÀI KHOẢN TRUY CẬP

| Thông Số | Giá Trị Mặc Định | Ghi Chú |
| :--- | :--- | :--- |
| **Tên Container Docker** | `nexus-shared-rabbitmq` | Ảnh `rabbitmq:3-management-alpine` |
| **Cổng AMQP (Code kết nối)** | `5672` | Dành cho thư viện MassTransit trong C# |
| **Cổng Management Web UI** | `15672` | Truy cập trình duyệt: `http://localhost:15672` |
| **Tài khoản mặc định (User)** | `guest` | Cấu hình qua biến môi trường `RABBITMQ_USER` |
| **Mật khẩu mặc định (Password)**| `MatkhaucuaTui123@` | Cấu hình qua biến môi trường `RABBITMQ_PASSWORD` |
| **Virtual Host (vhost)** | `/` | Virtual host mặc định của RabbitMQ |

### Khởi động nhanh bằng Docker:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d rabbitmq
```

---

## 3. HƯỚNG DẪN SỬ DỤNG RABBITMQ MANAGEMENT WEB UI

Mở trình duyệt truy cập: **`http://localhost:15672`**, đăng nhập bằng `guest` / `MatkhaucuaTui123@`.

### 3.1. Tab **Overview** (Tổng Quan Hoạt Động)
* **Message Rates**: Biểu đồ thời gian thực hiển thị:
  - `Publish`: Tốc độ bắn tin nhắn mới vào broker (msg/s).
  - `Deliver (manual ack)`: Tốc độ các consumer đang nhận và xử lý tin nhắn.
* **Queued Messages**:
  - `Ready`: Số lượng tin nhắn đang nằm chờ trong hàng đợi. Nếu số này tăng vọt và không giảm $\rightarrow$ Consumer đang bị chết hoặc xử lý quá chậm.
  - `Unacked`: Số lượng tin nhắn Consumer đã nhận nhưng chưa gửi xác nhận (Ack).

---

### 3.2. Tab **Exchanges** (Nơi Tiếp Nhận Sự Kiện)
* **Quy ước đặt tên của MassTransit**: MassTransit tự động tạo Exchange theo dạng Namespace và Tên Class của Event:
  - Ví dụ: `ShoppingCart.Contracts.V1:SendOtpEmailIntegrationEvent`
  - Kiểu Exchange: `fanout` (phát tán cho mọi queue đăng ký) hoặc `topic`.
* Bạn có thể bấm vào một Exchange để xem danh sách các Queue đang được liên kết (Bindings) với Exchange đó.

---

### 3.3. Tab **Queues** (Hàng Đợi Xử Lý)
Hiển thị danh sách tất cả các hàng đợi của các service.

#### Cách đọc và soi nội dung tin nhắn trong Queue:
1. Trong tab **Queues**, bấm vào tên hàng đợi bạn muốn kiểm tra (ví dụ `notification-service.send-otp-email`).
2. Cuộn chuột xuống mục **Get messages**.
3. Điền các thông số:
   - `Messages`: Số lượng tin muốn xem (ví dụ `1`).
   - `Requeue`: Chọn **`Yes`** (Rất quan trọng! Để sau khi xem xong, tin nhắn vẫn nằm lại trong hàng đợi cho consumer xử lý).
   - `Encoding`: `Auto string / UTF-8`.
4. Bấm nút **Get Message(s)**.
5. Nội dung JSON của sự kiện sẽ hiển thị ngay bên dưới, bao gồm:
   - `messageId`, `correlationId`, `conversationId` (chuẩn MassTransit).
   - `message`: Payload dữ liệu thực tế (Email, OTP code, v.v.).

---

### 3.4. Xử Lý Khi Có Tin Nhắn Lỗi: Hàng Đợi `_error` và `_skipped`
MassTransit có cơ chế tự động bảo vệ tin nhắn khi xảy ra sự cố:
* **Hàng đợi `_error` (ví dụ: `notification-service_error`)**:
  - Khi Consumer gặp lỗi ngoại lệ chưa xử lý (Unhandled Exception) và retry hết số lần cho phép, MassTransit sẽ **chuyển tin nhắn bị lỗi sang hàng đợi `_error`** thay vì xóa bỏ.
  - *Cách kiểm tra:* Bấm vào queue `_error` $\rightarrow$ Get Message. Trong phần Headers sẽ chứa chi tiết:
    - `MT-Fault-Message`: Nội dung lỗi exception.
    - `MT-Fault-StackTrace`: Dấu vết dòng code bị lỗi trong C#!
* **Hàng đợi `_skipped`**:
  - Chứa các tin nhắn gửi vào queue nhưng không có Consumer nào đăng ký kiểu dữ liệu đó.

---

## 4. QUY CHUẨN ĐẶC TẢ SỰ KIỆN TRONG C# (MASSTRANSIT INTEGRATION EVENTS)

1. **Đặt tên theo thì quá khứ**: Thể hiện một sự việc đã hoàn thành trong hệ thống:
   - ✅ Đúng: `SendOtpEmailIntegrationEvent`, `OrderCreatedIntegrationEvent`, `PaymentDeductedIntegrationEvent`.
   - ❌ Sai: `SendOtpEmail`, `CreateOrder` (Đây là tên của Command, không phải Event).
2. **Lưu trữ tập trung trong Contracts**:
   - Khai báo các record immutable:
     ```csharp
     namespace ShoppingCart.Contracts.V1;

     public sealed record SendOtpEmailIntegrationEvent(
         string Email,
         string OtpCode,
         DateTime ExpiresAt,
         string TraceId);
     ```
3. **Luôn gắn `TraceId` vào sự kiện**:
   - Giúp liên kết vết (Distributed Tracing) từ request HTTP của Gateway qua gRPC rồi xuyên suốt qua RabbitMQ tới Worker ngầm.
