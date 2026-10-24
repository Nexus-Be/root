# CẨM NANG KIỂM THỬ ĐỘC LẬP gRPC, EVENT BUS & CHẨN ĐOÁN LỖI TOÀN HỆ THỐNG
## (ISOLATED TESTING & DISTRIBUTED DEBUGGING GUIDE)

> **Mục tiêu tài liệu**: Cung cấp cẩm nang thực hành chi tiết cho lập trình viên để **kiểm thử độc lập từng Function gRPC và từng Event Consumer/Publisher bất đồng bộ** bằng Postman và grpcurl mà **không cần thông qua API Gateway**, đồng thời hướng dẫn quy trình 3 bước sử dụng **Grafana Tempo & RabbitMQ Dead-Letter Queues** để định vị chính xác file `.cs` và dòng code bị lỗi khi có sự cố xảy ra.

---

## 1. BỨC TRANH TỔNG QUAN VỀ KIỂM THỬ ĐỘC LẬP

Trong hệ thống Microservices, khi lập trình viên vừa code xong một Function tại một Service (ví dụ: `UserService` hoặc `WalletService`), việc phải bật toàn bộ 9 services cùng API Gateway để test qua Swagger REST là rất cồng kềnh, tốn RAM và khó đặt breakpoint debug.

Hệ thống Nexus cho phép bạn chia tách việc kiểm thử thành 3 trụ cột độc lập:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             POSTMAN / DÒNG LỆNH (CLI)                            │
│                                                                                  │
│   [Kiểm Thử gRPC Đồng Bộ]                  [Kiểm Thử Event Bất Đồng Bộ]          │
│   Postman gRPC Request                     Postman HTTP REST Request             │
│   (Server Reflection)                      (Basic Auth: guest/MatkhaucuaTui123@) │
└───────────────┬──────────────────────────────────────────┬───────────────────────┘
                │ HTTP/2 gRPC                              │ HTTP POST (Port 15672)
                ▼                                          ▼
┌───────────────────────────────┐          ┌───────────────────────────────────────┐
│     MICROSERVICE BACKEND      │          │        RABBITMQ MANAGEMENT API        │
│   Port: 8001, 8004, 8008...   │          │  POST /api/exchanges/%2f/{name}/publish│
│                               │          └───────────────────┬───────────────────┘
│   - MapGrpcService            │                              │ AMQP Routing
│   - MapGrpcReflectionService  │                              ▼
│   - MassTransit Consumers     │◄─────────────────── RabbitMQ Exchange / Queue
└───────────────┬───────────────┘                     (Kích hoạt độc lập Consumer)
                │ OTLP Traces (gRPC 4317)
                ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         CHẨN ĐOÁN LỖI: GRAFANA TEMPO                             │
│       Dán TraceId -> Xem Biểu đồ Waterfall -> Click Span Đỏ -> Thấy File & Dòng   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. PHẦN 1: KIỂM THỬ RIÊNG LẺ gRPC FUNCTION BẰNG POSTMAN

Các backend microservices chạy giao thức gRPC trên HTTP/2. Nhờ gói thư viện **`Grpc.AspNetCore.Server.Reflection`**, bạn không cần phải copy hay import file `shop.proto` thủ công vào Postman. Postman sẽ tự động truy vấn Server và sinh ra danh sách hàm cùng mẫu payload JSON.

### Bảng Cổng gRPC Các Backend Services

> **Trạng thái triển khai (2026-10-24): ❌ Không đạt — chỉ 3/8 service thật sự có gRPC server.** Chỉ các service đánh dấu ✅ mới có `MapGrpcService<…>()` + `MapGrpcReflectionService()`, nên chỉ chúng mới test được bằng Postman reflection. 5 service còn lại **chưa có gRPC** (chỉ `MapGet("/health")`) — bước “Postman tự truy vấn Server” bên dưới sẽ **thất bại** với chúng.
> **Nguồn sự thật:** `Program.cs` từng service + `*.Api/Services/*GrpcService.cs`.

| Service | Cổng HTTP/gRPC | Service Name trong Protobuf | gRPC server |
| :--- | :---: | :--- | :--- |
| **User Service** | `localhost:8001` | `ShoppingCart.Contracts.V1.UsersApi` | ✅ có (`User.Api/Program.cs:64`), reflection bật ở Development |
| **Catalog Service** | `localhost:8002` | `ShoppingCart.Contracts.V1.CatalogApi` | ❌ **không có** — chỉ REST mock (`api/v1/catalog/*`) |
| **Commerce Service**| `localhost:8003` | `ShoppingCart.Contracts.V1.CommerceApi` | ❌ **không có** — chỉ `/health` |
| **Log Service** | `localhost:8004` | `ShoppingCart.Contracts.V1.LogApi` | ✅ có (`Log.Api/Program.cs:47`), reflection bật ở Development |
| **Auction Service** | `localhost:8005` | `ShoppingCart.Contracts.V1.AuctionApi` | ❌ **không có** — chỉ `/health` |
| **Fulfillment Service** | `localhost:8006` | `ShoppingCart.Contracts.V1.FulfillmentApi` | ❌ **không có** — chỉ `/health` |
| **Notification Service**| `localhost:8007` | `ShoppingCart.Contracts.V1.NotificationApi` | ❌ **không có** — chỉ `/health` |
| **Wallet Service** | `localhost:8008` | `ShoppingCart.Contracts.V1.WalletApi` | ✅ có (`Wallet.Api/Program.cs:47`), reflection bật ở Development |

> ⚠️ Cả 8 service đều có `GET /health` (trả `{"status":"Healthy","service":"…"}`), nhưng **`/health` không phản ánh DB**: khi Postgres chết, `/health` vẫn trả 200 (bằng chứng: `docs/plans/SETUP_PHASE_PLAN.md` §2.4). Không dùng `/health` để kết luận service “chạy được”.

---

### Các Bước Thực Hiện Trên Postman (Từng Bước)

#### Bước 1: Tạo gRPC Request trong Postman
1. Mở ứng dụng **Postman**.
2. Bấm nút **New** (ở góc trên bên trái) $\rightarrow$ Chọn **gRPC Request**.

#### Bước 2: Kết nối Server Reflection
1. Tại ô nhập địa chỉ Server URL, điền URL của service cần test (ví dụ: `http://localhost:8001` cho UserService).
2. Tại mục **Service definition**, chọn **Use Server reflection**.
3. Postman sẽ tự động kết nối tới endpoint Reflection và tải về danh sách các Service cùng Methods.

#### Bước 3: Chọn Function & Tự Động Sinh Payload
1. Nhấp vào ô chọn Method $\rightarrow$ Chọn method bạn muốn kiểm thử (ví dụ: `UsersApi/Login` hoặc `UsersApi/Register`).
2. Tại tab **Message**, bấm nút **Use Example Message** (hoặc **Generate Example Message**). Postman sẽ tự động điền sẵn khung JSON đúng 100% với schema Protobuf.
3. Chỉnh sửa dữ liệu đầu vào, ví dụ:
   ```json
   {
     "email": "buyer01@nexus.local",
     "password": "Password123!"
   }
   ```

#### Bước 4: Giả lập Metadata Header (User Context / RBAC)
Khi một request đi qua Gateway, Gateway sẽ gắn các Header định danh vào gRPC Metadata. Khi test trực tiếp gRPC, bạn có thể truyền thẳng các header này tại tab **Metadata**:
- `x-user-id`: `01912345-6789-7abc-def0-123456789abc`
- `x-user-roles`: `Admin` (hoặc `Buyer`, `Seller`)
- `x-user-email`: `admin@nexus.local`

#### Bước 5: Bấm "Invoke" & Xem Kết Quả
Bấm nút **Invoke**. Postman sẽ nhận kết quả trả về ngay lập tức với Response Time tính bằng mili-giây.

---

### Tùy Chọn: Kiểm Thử Bằng Dòng Lệnh Với `grpcurl` (CLI)
Nếu bạn thích dùng Terminal/Dòng lệnh:
```bash
# 1. Liệt kê các service đang chạy qua Reflection:
grpcurl -plaintext localhost:8001 list

# 2. Liệt kê các hàm trong UsersApi:
grpcurl -plaintext localhost:8001 list ShoppingCart.Contracts.V1.UsersApi

# 3. Gọi trực tiếp hàm gRPC với payload JSON:
grpcurl -plaintext -d '{"email": "buyer01@nexus.local", "password": "Password123!"}' \
  localhost:8001 ShoppingCart.Contracts.V1.UsersApi/Login
```

---

## 3. PHẦN 2: KIỂM THỬ RIÊNG LẺ EVENT CONSUMER (BẤT ĐỒNG BỘ)

Khi bạn viết một Consumer (ví dụ: `SendOtpEmailConsumer` gửi email OTP, hoặc `StockReservedConsumer` trừ ví tiền), làm thế nào để test hàm `Consume()` mà **không cần chạy các service khác**?

### Phương Pháp Khuyên Dùng: Dùng Postman Bắn Event Qua RabbitMQ HTTP API

RabbitMQ cung cấp sẵn bộ REST API trên cổng Management UI (`15672`). Bạn có thể dùng Postman gửi HTTP POST để publish một event giả lập vào thẳng Exchange của MassTransit.

#### Cấu Hình Request Trong Postman:
1. **Method**: `POST`
2. **URL**: `http://localhost:15672/api/exchanges/%2f/{ExchangeName}/publish`
3. **Tab Authorization**:
   - Type: `Basic Auth`
   - Username: `guest`
   - Password: `MatkhaucuaTui123@` (hoặc mật khẩu cấu hình trong `.env`)
4. **Tab Headers**:
   - `Content-Type`: `application/json`

---

### Mẫu Payload JSON Cho Từng Event Phổ Biến

Trong MassTransit, tên Exchange mặc định chính là `Namespace:ContractName`. Dưới đây là các mẫu JSON sẵn dùng:

#### 1. Test Gửi Email OTP (`NotificationService`)
- **Exchange URL**: `http://localhost:15672/api/exchanges/%2f/Nexus.Contracts.Events:SendOtpEmailIntegrationEvent/publish`
- **Body (raw JSON)**:
  ```json
  {
    "properties": {
      "content_type": "application/vnd.masstransit+json"
    },
    "routing_key": "",
    "payload": "{\"messageType\": [\"urn:message:Nexus.Contracts.Events:SendOtpEmailIntegrationEvent\"], \"message\": {\"email\": \"test.dev@gmail.com\", \"fullName\": \"Nguyen Van A\", \"otp\": \"888999\", \"expiresInMinutes\": 5}}",
    "payload_encoding": "string"
  }
  ```
- **Kết quả kiểm chứng**: `NotificationService` lập tức kích hoạt `SendOtpEmailConsumer.Consume()` và gửi mail qua SMTP.

#### 2. Test Ghi Nhật Ký Hệ Thống (`LogService`)
- **Exchange URL**: `http://localhost:15672/api/exchanges/%2f/Log.Domain.Events:ILogEventOccurred/publish`
- **Body (raw JSON)**:
  ```json
  {
    "properties": {
      "content_type": "application/vnd.masstransit+json"
    },
    "routing_key": "",
    "payload": "{\"messageType\": [\"urn:message:Log.Domain.Events:ILogEventOccurred\"], \"message\": {\"serviceName\": \"OrderService\", \"eventType\": \"ORDER_PAYMENT_SUCCESS\", \"action\": \"PaymentSuccess\", \"logLevel\": \"Information\", \"entityName\": \"Orders\", \"entityId\": \"ORD-999\", \"payload\": \"{\\\"amount\\\": 250000}\"}}",
    "payload_encoding": "string"
  }
  ```
- **Kết quả kiểm chứng**: `LogService` ghi 1 dòng log vào bảng `LogEntries` trong database `log_db`.

#### 3. Test Khấu Trừ Ví Tiền Saga (`WalletService`)
- **Exchange URL**: `http://localhost:15672/api/exchanges/%2f/Wallet.Application.Consumers:IStockReservedEvent/publish`
- **Body (raw JSON)**:
  ```json
  {
    "properties": {
      "content_type": "application/vnd.masstransit+json"
    },
    "routing_key": "",
    "payload": "{\"messageType\": [\"urn:message:Wallet.Application.Consumers:IStockReservedEvent\"], \"message\": {\"orderId\": \"01912345-6789-7abc-def0-123456789abc\", \"userId\": \"buyer-user-id-01\", \"totalAmount\": 150000.00}}",
    "payload_encoding": "string"
  }
  ```

👉 **Mẹo Debug**: Trước khi bấm **Send** trên Postman, hãy đặt Breakpoint tại dòng đầu tiên của hàm `Consume(ConsumeContext<T> context)` trong IDE (Visual Studio / Rider). IDE sẽ lập tức dừng đúng vị trí để bạn kiểm tra từng biến!

---

## 4. PHẦN 3: KIỂM THỬ KẾT HỢP (FUNCTION VỪA gRPC VỪA PHÁT TÁN EVENT)

Nhiều Function nghiệp vụ có tính chất kết hợp: Client gọi gRPC vào $\rightarrow$ Service ghi nhận vào Database $\rightarrow$ Đồng thời bắn Event lên RabbitMQ (ví dụ: `UsersApi/Register` vừa lưu User vừa bắn Event gửi mail).

### Quy Trình Kiểm Thử 2 Mắt Xích:
1. **Bước 1 (Kích hoạt gRPC)**: Mở Postman gRPC Request gọi `UsersApi/Register`.
   - Postman nhận Response: `200 OK` hoặc `{ "userId": "..." }`.
2. **Bước 2 (Kiểm tra Event được bắn ra)**:
   - Mở trình duyệt vào RabbitMQ Management: `http://localhost:15672/#/queues`.
   - Tìm queue nhận (ví dụ: `send-otp-email`). Bạn sẽ thấy:
     - Biểu đồ **Message rates** nhảy lên `1 msg/s`.
     - Nếu `NotificationService` đang chạy, message sẽ được consume ngay lập tức.
     - Nếu `NotificationService` chưa bật, message sẽ nằm chờ ở trạng thái `Ready: 1`.

---

## 5. PHẦN 4: CHẨN ĐOÁN LỖI CHUYÊN SÂU: LỖI Ở ĐÂU, LỖI GÌ, SỬA NHƯ THẾ NÀO?

Khi một API bị lỗi trong môi trường Microservices, hãy làm theo quy trình chẩn đoán 3 tầng dưới đây:

### Tầng 1: Đọc Mã Lỗi & ProblemDetails Ngay Tại Response (Dưới 3 Giây)
Mọi phản hồi lỗi từ hệ thống Nexus đều chuẩn hóa theo RFC 9110 / RFC 7807:
```json
{
  "type": "https://httpstatuses.com/400",
  "title": "Bad Request",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Email is already registered in the system.",
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "timestamp": "2026-10-24T12:00:00Z"
}
```
- `errorCode`: Cho biết danh mục lỗi nghiệp vụ (ví dụ: `VAL_INVALID_INPUT`, `USER_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `DOWNSTREAM_UNHEALTHY`).
- `detail`: Lý do người dùng bị từ chối bằng tiếng Anh chuẩn.
- `traceId`: Chìa khóa vàng để chuyển sang Tầng 2.

---

### Tầng 2: Mở Grafana Tempo Định Vị Tên File & Số Dòng Code Bị Crash
Nếu API trả về `500 Internal Server Error` hoặc lỗi không rõ nguyên nhân:

1. **Lấy mã `TraceId`**: Copy chuỗi `traceId` từ response JSON hoặc từ Response Header `X-Trace-Id`.
2. **Mở Grafana Tempo**: Truy cập `http://localhost:3000/explore` (đã bật sẵn Anonymous Admin, không cần mật khẩu).
3. **Tra cứu Trace**: Đảm bảo datasource chọn **Tempo**, dán mã `TraceId` vào ô tìm kiếm và bấm **Run query**.
4. **Đọc biểu đồ Waterfall**:
   - Toàn bộ cây thực thi từ Gateway $\rightarrow$ gRPC $\rightarrow$ EF Core SQL $\rightarrow$ MassTransit Publish/Consume sẽ hiện ra.
   - Thanh Span nào bị crash hoặc ném Exception sẽ **chuyển sang màu ĐỎ RỰC**.
5. **Xem chi tiết lỗi**: Bấm chuột vào thanh màu đỏ đó. Bảng thông số bên phải sẽ hiển thị:
   - `exception.type`: Loại Exception (ví dụ: `Npgsql.PostgresException`, `NullReferenceException`).
   - `exception.message`: Nội dung lỗi chi tiết.
   - **`exception.stacktrace`**: **Hiển thị trực tiếp tên file C# và số dòng bị lỗi** (ví dụ: `AuthService.cs:line 42`).
   - `db.statement`: Câu lệnh SQL gây lỗi cùng các giá trị tham số (`@p0`, `@p1`).

---

### Tầng 3: Chẩn Đoán Lỗi Event Bất Đồng Bộ Qua Dead-Letter Queue (`*_error`)
Nếu luồng gRPC đã xong nhưng tác vụ ngầm bị thất bại (ví dụ: Worker gửi mail bị sai mật khẩu SMTP, hoặc worker ghi log bị đầy ổ cứng):

1. Mở **RabbitMQ UI**: `http://localhost:15672/#/queues`.
2. Tìm các Queue có hậu tố **`_error`** (MassTransit tự động gom các message lỗi vào đây sau khi đã retry hết số lần quy định, ví dụ: `send-otp-email_error`).
3. Nhấp vào queue `_error` đó $\rightarrow$ Kéo xuống mục **Get messages**:
   - Chọn `Ack mode: Nack message (requeue false)`
   - Bấm nút **Get Message(s)**.
4. RabbitMQ sẽ hiển thị toàn bộ chi tiết:
   - `Payload`: Dữ liệu JSON ban đầu được gửi đi.
   - `MT-Fault-Message`: Chuỗi thông báo lỗi ném ra từ Consumer.
   - `MT-Fault-StackTrace`: Toàn bộ call stack và dòng code bị crash trong Consumer.
5. Sau khi sửa code xong, bạn có thể bấm **Move messages** trên giao diện RabbitMQ để đẩy lại message vào queue chính xử lý lại mà không bị mất dữ liệu!

---

## 6. TÓM TẮT MA TRẬN CÔNG CỤ TEST & DEBUG

| Nhiệm Vụ | Công Cụ | Cách Thực Hiện | Lợi Ích |
| :--- | :--- | :--- | :--- |
| **Test 1 hàm gRPC** | **Postman gRPC Request** | Nhập `localhost:800x`, chọn hàm qua Reflection, điền JSON, bấm Invoke. | Không cần import `.proto`, tự gợi ý field, test độc lập từng service. |
| **Test 1 Event Consumer** | **Postman REST $\rightarrow$ RabbitMQ API** | Gửi HTTP POST tới `:15672/api/exchanges/.../publish`. | Kích hoạt worker ngầm mà không cần chạy các service nguồn. |
| **Test Function gRPC + Event** | **Postman gRPC + RabbitMQ UI** | Invoke gRPC trên Postman, kiểm tra Queue trên RabbitMQ UI (`:15672`). | Xác nhận cả 2 mắt xích đồng bộ & bất đồng bộ đều thông suốt. |
| **Bắt lỗi Code & Dòng Crash** | **Grafana Tempo** | Dán `TraceId` vào `:3000/explore`, bấm vào Span đỏ. | Chỉ rõ file `.cs`, số dòng code bị lỗi và câu lệnh SQL gây lỗi. |
| **Bắt lỗi Worker ngầm** | **RabbitMQ Dead-Letter** | Xem các queue `*_error` trên `:15672`. | Xem nguyên nhân crash của Consumer và replay lại message dễ dàng. |
