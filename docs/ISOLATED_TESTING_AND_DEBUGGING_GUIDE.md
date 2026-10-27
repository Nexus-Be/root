# CẨM NANG KIỂM THỬ ĐỘC LẬP RESTFUL API, EVENT BUS & CHẨN ĐOÁN LỖI TOÀN HỆ THỐNG
## (ISOLATED RESTFUL API TESTING, EVENT BUS & DISTRIBUTED DEBUGGING GUIDE)

> **Mục tiêu tài liệu**: Cung cấp cẩm nang thực hành chi tiết cho lập trình viên để **kiểm thử độc lập từng Endpoint RESTful HTTP/JSON và từng Event Consumer/Publisher bất đồng bộ** bằng Swagger UI, Postman và cURL mà **không cần thông qua API Gateway**, đồng thời hướng dẫn quy trình 3 bước sử dụng **Grafana Tempo & RabbitMQ Dead-Letter Queues** để định vị chính xác file `.cs` và dòng code bị lỗi khi có sự cố xảy ra.

---

## 1. BỨC TRANH TỔNG QUAN VỀ KIỂM THỬ ĐỘC LẬP

Trong hệ thống Microservices Nexus, khi lập trình viên vừa code xong một tính năng hoặc Endpoint tại một Service (ví dụ: `UserService` hoặc `WalletService`), việc phải bật toàn bộ 9 services cùng API Gateway để kiểm thử qua giao diện là rất cồng kềnh, tốn RAM và khó đặt breakpoint debug.

Tuân thủ **Nguyên tắc 4** và **ADR 06**, toàn bộ hệ thống Nexus đã chuẩn hóa hai trục giao tiếp tách biệt:
1. **Trục Đồng Bộ (Synchronous)**: **100% RESTful HTTP/JSON** (CẤM TUYỆT ĐỐI gRPC). Mỗi microservice backend sở hữu dải cổng riêng (`8001`-`8008`) và có thể tiếp nhận trực tiếp các request HTTP REST từ Swagger UI, Postman hoặc cURL.
2. **Trục Bất Đồng Bộ (Asynchronous)**: **100% Event-driven qua RabbitMQ** (MassTransit) kết hợp Outbox Pattern và Dead-Letter Queues (`*_error`).

Hệ thống cho phép bạn chia tách việc kiểm thử thành 3 trụ cột độc lập:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                      POSTMAN / cURL / SWAGGER UI / DÒNG LỆNH                     │
│                                                                                  │
│   [Kiểm Thử RESTful API Đồng Bộ]           [Kiểm Thử Event Bất Đồng Bộ]          │
│   HTTP GET/POST/PUT/PATCH/DELETE           Postman HTTP REST Request             │
│   (Swagger UI / cURL / Postman)            (Basic Auth: guest/guest hoặc $RABBITMQ_PASSWORD) │
└───────────────┬──────────────────────────────────────────┬───────────────────────┘
                │ HTTP/1.1 REST (JSON)                     │ HTTP POST (Port 15672)
                ▼                                          ▼
┌───────────────────────────────┐          ┌───────────────────────────────────────┐
│     MICROSERVICE BACKEND      │          │        RABBITMQ MANAGEMENT API        │
│   Port: 8001, 8002, 8008...   │          │  POST /api/exchanges/%2f/{name}/publish│
│                               │          └───────────────────┬───────────────────┘
│   - Minimal API / Controller  │                              │ AMQP Routing
│   - Swagger UI (/swagger)     │                              ▼
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

## 2. PHẦN 1: KIỂM THỬ RIÊNG LẺ RESTFUL ENDPOINT CỦA BACKEND MICROSERVICE (ĐỒNG BỘ - CẤM gRPC)

Mỗi backend microservice trong Nexus là một ứng dụng Web API độc lập chạy máy chủ Kestrel. Khi khởi chạy độc lập (qua `dotnet run` hoặc Visual Studio / Rider / Docker), service sẽ lắng nghe tại cổng HTTP đã được quy hoạch cố định và tích hợp sẵn **Swagger UI** (trong môi trường `Development`).

### Bảng Cổng RESTful API & Swagger UI Trực Tiếp Các Backend Services

| Service | Cổng REST Trực Tiếp | Swagger UI Endpoint | Đường Dẫn API Tiêu Biểu |
| :--- | :---: | :--- | :--- |
| **API Gateway** | `localhost:8080` | `http://localhost:8080/swagger` | `/api/v1/*` (Reverse Proxy & Điều phối) |
| **User Service** | `localhost:8001` | `http://localhost:8001/swagger` | `/api/v1/auth/*`, `/api/v1/users/*` |
| **Catalog Service** | `localhost:8002` | `http://localhost:8002/swagger` | `/api/v1/products/*`, `/api/v1/categories/*` |
| **Commerce Service**| `localhost:8003` | `http://localhost:8003/swagger` | `/api/v1/cart/*`, `/api/v1/orders/*` |
| **Log Service** | `localhost:8004` | `http://localhost:8004/swagger` | `/api/v1/logs/*` |
| **Auction Service** | `localhost:8005` | `http://localhost:8005/swagger` | `/api/v1/auctions/*`, `/api/v1/bids/*` |
| **Fulfillment Service** | `localhost:8006` | `http://localhost:8006/swagger` | `/api/v1/shipments/*`, `/api/v1/inventory/*` |
| **Notification Service**| `localhost:8007` | `http://localhost:8007/swagger` | `/api/v1/notifications/*` |
| **Wallet Service** | `localhost:8008` | `http://localhost:8008/swagger` | `/api/v1/wallets/*`, `/api/v1/transactions/*` |

> ⚠️ Cả 8 service đều có `GET /health` (trả `{"status":"Healthy","service":"…"}`), nhưng **`/health` không kiểm tra trạng thái kết nối Database**: khi Postgres chết, `/health` vẫn trả 200. Vì vậy, luôn kiểm thử các API nghiệp vụ có thao tác DB thực tế để xác nhận service hoạt động chính xác.

---

### Các Bước Kiểm Thử RESTful Endpoint Độc Lập

#### Cách 1: Sử Dụng Swagger UI Trực Tiếp Của Service (Trực Quan Nhất)
1. Khởi chạy duy nhất service bạn cần làm việc (ví dụ `UserService`):
   ```bash
   cd src/Services/User/User.Api
   dotnet run
   ```
2. Mở trình duyệt truy cập: **`http://localhost:8001/swagger`**.
3. Chọn API cần test (ví dụ `POST /api/v1/auth/register`) $\rightarrow$ Bấm **Try it out**.
4. Điền Request Body JSON và bấm **Execute**.
5. Đặt Breakpoint trong code C# Controller/Handler để dừng và debug trực tiếp.

#### Cách 2: Sử Dụng Postman Hoặc File `.http`
1. Mở Postman, tạo một HTTP Request thông thường (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
2. Điền URL trực tiếp tới backend: ví dụ `http://localhost:8001/api/v1/auth/login`.
3. Điền Body định dạng `raw` JSON.

#### Cách 3: Kiểm Thử Bằng Dòng Lệnh Với `curl` (CLI)
```bash
# 1. Kiểm tra health check:
curl -i http://localhost:8001/health

# 2. Gọi API đăng ký tài khoản (User Service):
curl -i -X POST http://localhost:8001/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "buyer01@nexus.local",
    "password": "Password123!",
    "fullName": "Nguyen Van A",
    "role": "Buyer"
  }'

# 3. Lấy thông tin sản phẩm (Catalog Service):
curl -i http://localhost:8002/api/v1/products/01912345-6789-7abc-def0-123456789abc
```

---

### Giả Lập Header Danh Tính Người Dùng (Identity Propagation / RBAC)

Khi request đi qua API Gateway, Gateway sẽ xác thực JWT token và tự động gắn các Header định danh vào request chuyển tiếp sang backend microservice:
- `x-user-id`: Mã UUID của người dùng (`01912345-6789-7abc-def0-123456789abc`)
- `x-user-roles`: Quyền hạn (`Buyer`, `Seller`, `Staff`, `Admin`, `SuperAdmin`)
- `x-user-email`: Email của người dùng (`buyer01@nexus.local`)

Khi bạn **kiểm thử độc lập trực tiếp tại backend microservice (không qua Gateway)**, bạn chỉ cần truyền các header này trong Swagger UI, Postman Headers hoặc cURL:

```bash
curl -i -X GET http://localhost:8008/api/v1/wallets/my-balance \
  -H "x-user-id: 01912345-6789-7abc-def0-123456789abc" \
  -H "x-user-roles: Buyer" \
  -H "x-user-email: buyer01@nexus.local"
```
Hành động này giúp bạn kiểm tra phân quyền RBAC và logic nghiệp vụ theo từng User mà không cần phải thực hiện bước đăng nhập lấy JWT token từ Gateway!

---

### Quy Chuẩn Cấu Trúc Dữ Liệu Trả Về (Response Standards)

1. **Phản hồi thành công (Success)**: Bọc trong vỏ chuẩn `ApiResponse<T>`:
   ```json
   {
     "success": true,
     "data": {
       "id": "01912345-6789-7abc-def0-123456789abc",
       "email": "buyer01@nexus.local"
     },
     "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
     "timestamp": "2026-10-27T14:50:00Z"
   }
   ```
2. **Phản hồi danh sách phân trang (Paged Data)**: Bọc trong `ApiResponse<PagedData<T>>`.
3. **Phản hồi không nội dung (No Content)**: Trả về mã HTTP `204 NoContent` (không có body).
4. **Phản hồi lỗi (Error)**: Tuân thủ chuẩn RFC 9110 / ProblemDetails (xem chi tiết tại Phần 4).

---

## 3. PHẦN 2: KIỂM THỬ RIÊNG LẺ EVENT CONSUMER (BẤT ĐỒNG BỘ QUA RABBITMQ)

Khi bạn viết một Consumer (ví dụ: `SendOtpEmailConsumer` gửi email OTP, hoặc `StockReservedConsumer` xử lý trừ tiền ví), làm thế nào để test hàm `Consume()` mà **không cần chạy các service khác**?

Bạn có thể đưa Event giả lập vào thẳng RabbitMQ Broker theo 2 cách:

### Cách 1: Bắn Event Trực Tiếp Trên RabbitMQ Management Web UI (Không Cần Bật Postman)
1. Mở trình duyệt vào: **`http://localhost:15672`** (đăng nhập: `guest` / `guest`).
2. Vào tab **Exchanges** $\rightarrow$ Bấm vào tên Exchange tương ứng với Event bạn muốn kích hoạt.
3. Cuộn xuống mục **Publish message**:
   - **Routing key**: để trống.
   - **Headers**: Thêm dòng header:
     - Name: `Content-Type`
     - Value: `application/vnd.masstransit+json`
   - **Payload**: Dán phần ruột JSON của message (xem mẫu payload chi tiết bên dưới).
4. Bấm nút **Publish message**. Service tương ứng sẽ lập tức nhận được message và thực thi Consumer!

---

### Cách 2: Dùng Postman Bắn Event Qua RabbitMQ HTTP REST API
RabbitMQ cung cấp sẵn bộ REST API trên cổng Management UI (`15672`). Bạn có thể dùng Postman gửi HTTP POST để publish một event giả lập vào thẳng Exchange của MassTransit.

#### Cấu Hình Request Trong Postman:
1. **Method**: `POST`
2. **URL**: `http://localhost:15672/api/exchanges/%2f/{ExchangeName}/publish`
3. **Tab Authorization**:
   - Type: `Basic Auth`
   - Username: `guest`
   - Password: `guest` (hoặc mật khẩu cấu hình trong biến môi trường `RABBITMQ_PASSWORD`)
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
    "payload": "{\"messageType\": [\"urn:message:Log.Domain.Events:ILogEventOccurred\"], \"message\": {\"serviceName\": \"OrderService\", \"eventType\": \"ORDER_PAYMENT_SUCCESS\", \"actorUserId\": \"01912345-6789-7abc-def0-123456789abc\", \"logLevel\": \"Information\", \"entityName\": \"Orders\", \"entityId\": \"ORD-999\", \"detailsJson\": \"{\\\"amount\\\": 250000}\"}}",
    "payload_encoding": "string"
  }
  ```
- **Kết quả kiểm chứng**: `LogService` ghi 1 dòng log vào bảng `LogEntries` trong database `log_db`. Lưu ý: `DetailsJson` là chuỗi JSON chứa chi tiết sự kiện; `actorUserId` là định danh tài khoản thực hiện.

#### 3. Test Khấu Trừ Ví Tiền Saga (`WalletService`)
- **Exchange URL**: `http://localhost:15672/api/exchanges/%2f/Wallet.Domain.Events:IStockReservedEvent/publish`
- **Body (raw JSON)**:
  ```json
  {
    "properties": {
      "content_type": "application/vnd.masstransit+json"
    },
    "routing_key": "",
    "payload": "{\"messageType\": [\"urn:message:Wallet.Domain.Events:IStockReservedEvent\"], \"message\": {\"orderId\": \"ORD-001\", \"reservationId\": \"RES-001\", \"userId\": \"01912345-6789-7abc-def0-123456789abc\", \"totalAmount\": \"150000.00\"}}",
    "payload_encoding": "string"
  }
  ```
- **Lưu ý kỹ thuật cho Wallet Consumer**:
  - Exchange chuẩn trong code là `Wallet.Domain.Events:IStockReservedEvent` (interface nằm ở `Wallet.Domain.Events`).
  - `totalAmount` là chuỗi `string` (ví dụ `"150000.00"`), không phải số thực.
  - `userId` bắt buộc phải là chuỗi định dạng **Guid hợp lệ** (`Guid.TryParse`) và tương ứng với một ví đã tồn tại trong database `wallet_db`.

👉 **Mẹo Debug**: Trước khi bấm **Send** trên Postman hoặc **Publish** trên RabbitMQ UI, hãy đặt Breakpoint tại dòng đầu tiên của hàm `Consume(ConsumeContext<T> context)` trong IDE (Visual Studio / Rider). IDE sẽ lập tức dừng đúng vị trí để bạn kiểm tra từng biến!

---

## 4. PHẦN 3: KIỂM THỬ KẾT HỢP (RESTFUL API ĐỒNG BỘ + PHÁT TÁN EVENT BẤT ĐỒNG BỘ)

Nhiều tính năng nghiệp vụ có tính chất kết hợp: Client gửi HTTP POST/PUT vào RESTful API $\rightarrow$ Service ghi nhận vào Database $\rightarrow$ Đồng thời bắn Event lên RabbitMQ (ví dụ: `POST /api/v1/auth/register` vừa lưu User vừa bắn Event gửi email OTP).

### Quy Trình Kiểm Thử 2 Mắt Xích:
1. **Bước 1 (Kích hoạt RESTful API)**:
   - Gửi request `POST http://localhost:8001/api/v1/auth/register` qua Swagger UI, Postman hoặc cURL.
   - Nhận Response `200 OK` hoặc `201 Created` kèm payload JSON.
2. **Bước 2 (Kiểm tra Event được bắn ra trên RabbitMQ Broker)**:
   - Mở trình duyệt vào RabbitMQ Management: `http://localhost:15672/#/queues`.
   - Tìm queue nhận (ví dụ: `send-otp-email`). Bạn sẽ thấy:
     - Biểu đồ **Message rates** nhảy lên `1 msg/s`.
     - Nếu `NotificationService` đang chạy, message sẽ được consume ngay lập tức (`Unacked: 0`, `Ready: 0`).
     - Nếu `NotificationService` chưa bật, message sẽ nằm chờ an toàn trong hàng đợi ở trạng thái `Ready: 1`.

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
  "timestamp": "2026-10-27T14:50:00Z"
}
```
- `errorCode`: Cho biết danh mục lỗi nghiệp vụ viết hoa theo `SCREAMING_SNAKE_CASE` (ví dụ: `VAL_INVALID_INPUT`, `USER_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `DOWNSTREAM_UNHEALTHY`).
- `detail`: Lý do bị từ chối bằng 100% tiếng Anh Sentence case theo đúng **Nguyên tắc 5**.
- `traceId`: Chìa khóa định danh duy nhất để tra cứu xuyên suốt hệ thống tại Tầng 2.

---

### Tầng 2: Mở Grafana Tempo Định Vị Tên File & Số Dòng Code Bị Crash

Nếu API trả về `500 Internal Server Error` hoặc lỗi không rõ nguyên nhân:

1. **Lấy mã `TraceId`**: Copy chuỗi `traceId` từ response JSON hoặc từ Response Header `X-Trace-Id`.
2. **Mở Grafana Tempo**: Truy cập `http://localhost:3000/explore` (đã bật sẵn Anonymous Admin, không cần mật khẩu).
3. **Tra cứu Trace**: Đảm bảo datasource chọn **Tempo**, dán mã `TraceId` vào ô tìm kiếm và bấm **Run query**.
4. **Đọc biểu đồ Waterfall**:
   - Toàn bộ cây thực thi từ Gateway $\rightarrow$ HTTP REST call $\rightarrow$ EF Core SQL $\rightarrow$ MassTransit Publish/Consume sẽ hiện ra.
   - Thanh Span nào bị crash hoặc ném Exception sẽ **chuyển sang màu ĐỎ RỰC**.
5. **Xem chi tiết lỗi**: Bấm chuột vào thanh màu đỏ đó. Bảng thông số bên phải sẽ hiển thị:
   - `exception.type`: Loại Exception (ví dụ: `Npgsql.PostgresException`, `NullReferenceException`).
   - `exception.message`: Nội dung lỗi chi tiết.
   - **`exception.stacktrace`**: **Hiển thị trực tiếp tên file C# và số dòng bị lỗi** (ví dụ: `AuthService.cs:line 42`).
   - `db.statement`: Câu lệnh SQL gây lỗi cùng các giá trị tham số (`@p0`, `@p1`).

---

### Tầng 3: Chẩn Đoán Lỗi Event Bất Đồng Bộ Qua Dead-Letter Queue (`*_error`)
Nếu luồng RESTful HTTP đã xong nhưng tác vụ ngầm bị thất bại (ví dụ: Consumer gửi email OTP bị sai mật khẩu SMTP, hoặc worker ghi log bị lỗi kết nối DB):

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
| **Test 1 Endpoint RESTful** | **Swagger UI / Postman / cURL** | Truy cập `localhost:800x/swagger` hoặc gọi HTTP trực tiếp. | Không cần import proto, có UI trực quan, test độc lập từng service. |
| **Test 1 Event Consumer** | **Postman REST $\rightarrow$ RabbitMQ API** | Gửi HTTP POST tới `:15672/api/exchanges/.../publish`. | Kích hoạt worker ngầm mà không cần chạy các service nguồn. |
| **Test Kết Hợp REST + Event** | **Swagger/Postman + RabbitMQ UI** | Gửi request REST, kiểm tra Queue trên RabbitMQ UI (`:15672`). | Xác nhận cả 2 mắt xích đồng bộ & bất đồng bộ đều thông suốt. |
| **Bắt lỗi Code & Dòng Crash** | **Grafana Tempo** | Dán `TraceId` vào `:3000/explore`, bấm vào Span đỏ. | Chỉ rõ file `.cs`, số dòng code bị lỗi và câu lệnh SQL gây lỗi. |
| **Bắt lỗi Worker ngầm** | **RabbitMQ Dead-Letter** | Xem các queue `*_error` trên `:15672`. | Xem nguyên nhân crash của Consumer và replay lại message dễ dàng. |
