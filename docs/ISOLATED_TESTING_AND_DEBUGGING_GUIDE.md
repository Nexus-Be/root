# CẨM NANG KIỂM THỬ ĐỘC LẬP RESTFUL API & CHẨN ĐOÁN LỖI TOÀN HỆ THỐNG
## (ISOLATED RESTFUL API TESTING & DISTRIBUTED DEBUGGING GUIDE)

> **Trạng thái triển khai (2026-10-31):** ✅ Hệ thống giao tiếp 100% bằng RESTful HTTP/JSON. RabbitMQ, MassTransit, Saga, Outbox/Inbox và gRPC đã bị gỡ bỏ. Internal API đang **tạm khóa**; các service gọi nhau bằng route công khai. Chẩn đoán phân tán dùng **OpenTelemetry + Grafana Tempo**.
> **Nguồn sự thật:** `src/Services/*/Controllers`, `src/Services/*/Extensions/ObservabilityExtensions.cs`, `src/Services/Gateway/Gateway/` và `docker-compose.infra.yml`. Tài liệu này mô tả code đang chạy, không mô tả thiết kế mong muốn.
> **Cập nhật lần cuối:** 2026-10-31.

> **Mục tiêu tài liệu**: Hướng dẫn kiểm thử từng endpoint RESTful tại backend mà không cần bật toàn bộ hệ thống; kiểm thử một lời gọi liên service mà không cần chạy service gọi; và chẩn đoán lỗi theo 3 tầng: đọc mã lỗi, tra trace trên Grafana Tempo, kiểm tra service đích cùng database.

---

## 1. BỨC TRANH TỔNG QUAN

### 1.1. Hai đường kiểm thử, ba lớp cần phân biệt

Một request có thể đi theo hai đường:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                 POSTMAN / cURL / SWAGGER UI / DÒNG LỆNH                      │
│                                                                              │
│   [Đường A: gọi thẳng backend]          [Đường B: gọi qua Gateway]           │
│   http://localhost:8001-8009            http://localhost:8080                │
└───────────────────┬────────────────────────────────────┬─────────────────────┘
                    │ HTTP/JSON                          │ HTTP/JSON + JWT
                    ▼                                    ▼
        ┌───────────────────────┐              ┌───────────────────────────┐
        │  BACKEND SERVICE      │              │  API GATEWAY (YARP)       │
        │  Kestrel + Swagger    │              │  JWT, RBAC, Rate Limit,   │
        │  Feature Service      │              │  Anti-spoofing, Envelope  │
        │  DbContext            │              └─────────────┬─────────────┘
        └───────────┬───────────┘                            │ ForwardAsync
                    │                                        ▼
                    │                          ┌───────────────────────────┐
                    │                          │  BACKEND SERVICE          │
                    │                          │  (nhận x-user-* headers)  │
                    │                          └─────────────┬─────────────┘
                    │                                        │
                    └──────────────────┬─────────────────────┘
                                       │ REST/JSON (đồng bộ)
                                       ▼
                          ┌───────────────────────────┐
                          │  SERVICE ĐÍCH (nếu có)    │
                          │  Notification / Wallet /  │
                          │  Fulfillment / Catalog    │
                          └─────────────┬─────────────┘
                                        │ OTLP (4317)
                                        ▼
                          ┌───────────────────────────┐
                          │  GRAFANA TEMPO + GRAFANA  │
                          │  Waterfall, exception,    │
                          │  HTTP client spans        │
                          └───────────────────────────┘
```

Ba lớp cần phân biệt trước khi bắt đầu:

| Lớp | Câu hỏi | Nguồn dữ liệu |
| :--- | :--- | :--- |
| **Edge** | Request có bị chặn trước khi tới service không? | `ClientContextMiddleware`, `AdminAuthorizationGuardMiddleware`, `SensitiveRateLimitMiddleware`, `IdempotencyGuardMiddleware` |
| **Service** | Nghiệp vụ có ném lỗi không? | `GlobalExceptionHandlerMiddleware` của từng service, `errorCode`, `traceId` |
| **Downstream** | Service đích có trả lỗi hoặc timeout không? | Span `HttpClient`, log `LogWarning` của typed client, trạng thái database |

### 1.2. Ba khác biệt bắt buộc phải nhớ

| Tiêu chí | Gọi thẳng backend (`8001`-`8009`) | Gọi qua Gateway (`8080`) |
| :--- | :--- | :--- |
| **Xác thực** | Không có JWT; tự gửi `x-user-id`, `x-user-roles` | Route bảo vệ cần JWT Bearer; Gateway tiêm header danh tính. Các route công khai (`auth/login`, danh sách sản phẩm) không cần token |
| **Chống giả mạo header** | Không kiểm tra (đây là môi trường test nội bộ) | Gửi `x-user-*` từ ngoài sẽ bị chặn `403 FORBIDDEN_HEADER_SPOOFING` |
| **Vỏ phản hồi thành công** | Dữ liệu thô do controller trả về | `ApiResponse<T>` do `ResponseEnvelopeMiddleware` bọc |
| **Vỏ phản hồi lỗi** | `application/problem+json` của service | Lỗi service đi xuyên qua; lỗi do Gateway sinh ra dùng `ApiErrorResponse` |
| **`traceId`** | Chỉ có trong body lỗi; không có response header | Có trong body envelope và header `X-Trace-Id` |
| **Rate limit** | Không áp dụng | Áp dụng cho `register`, `login`, `otp/verify`, `otp/resend` |
| **RBAC admin** | Do filter `[RequireRole]` của service quyết định | Gateway chặn `/api/v1/admin/**` trước, service kiểm tra lại |

> **Kết luận thực hành:** Khi test thẳng backend, đừng tìm `data` trong JSON và đừng chờ header `X-Trace-Id`. Khi test qua Gateway, đừng gửi `x-user-*`; hãy gửi JWT.

---

## 2. PHẦN 1: KIỂM THỬ RIÊNG LẺ ENDPOINT CỦA BACKEND MICROSERVICE

Mỗi backend là một Web API Kestrel độc lập. Khi chạy bằng `dotnet run`, service dùng đúng port trong `Properties/launchSettings.json` và bật Swagger UI khi `ASPNETCORE_ENVIRONMENT=Development` hoặc `Swagger:Enabled=true`.

### 2.1. Bảng port và route tiêu biểu

| Service | HTTP | Swagger trực tiếp | Route tiêu biểu | Database |
| :--- | :---: | :--- | :--- | :--- |
| **API Gateway** | `8080` | `http://localhost:8080/swagger` | `/api/v1/*` (reverse proxy, gộp Swagger của 9 service) | Không có |
| **User** | `8001` | `http://localhost:8001/swagger` | `/api/v1/auth/*`, `/api/v1/me/*`, `/api/v1/users/*`, `/api/v1/sellers/*` | `usermanagement_db` (`5433`) |
| **Catalog** | `8002` | `http://localhost:8002/swagger` | `/api/v1/products/*`, `/api/v1/categories/*` | `category_db` (`5434`) |
| **Commerce** | `8003` | `http://localhost:8003/swagger` | `/api/v1/carts/*`, `/api/v1/orders/*` | `commerce_db` (`5435`) |
| **Log** | `8004` | `http://localhost:8004/swagger` | `/api/v1/logs/*` | `log_db` (`5436`) |
| **Auction** | `8005` | `http://localhost:8005/swagger` | `/api/v1/auctions/*` | `auction_db` (`5437`) |
| **Fulfillment** | `8006` | `http://localhost:8006/swagger` | `/api/v1/shipments/*`, `/api/v1/warehouses/*`, `/api/v1/inventories/*` | `fulfillment_db` (`5438`) |
| **Notification** | `8007` | `http://localhost:8007/swagger` | `/api/v1/notifications/*`, `/api/v1/notifications/email/*` | `notification_db` (`5439`) |
| **Wallet** | `8008` | `http://localhost:8008/swagger` | `/api/v1/wallets/*`, `/api/v1/admin/wallets/*` | `wallet_db` (`5440`) |
| **CheckHeal** | `8009` | `http://localhost:8009/swagger` | `/api/v1/healthcheck/*`, `/health/*` | Không có DB riêng |

Lưu ý về route:

- Wallet dùng `/api/v1/wallets/me`, **không phải** `/api/v1/wallets/my-balance`.
- Giao dịch ví nằm dưới `/api/v1/wallets/transactions`, không phải `/api/v1/transactions`.
- Tồn kho nằm dưới `/api/v1/inventories/*`, không phải `/api/v1/inventory/*`.
- Bid chỉ có `GET /api/v1/auctions/{auctionId:guid}/bids`; không có `/api/v1/bids` độc lập.
- Một số route tồn tại trong controller nhưng chưa có route Gateway (`/api/v1/checkouts`, `/api/v1/sub-orders`, `/api/v1/reviews`, `/api/v1/admin/auctions`). Gọi qua Gateway các route này trả `404`; muốn test phải gọi thẳng service hoặc bổ sung route Gateway trước.

### 2.2. `/health` không chứng minh service hoạt động

Mọi service đều có `GET /health` trả `200` khi process còn sống. Endpoint này **không kiểm tra database, Redis hay downstream**. Vì vậy:

- Muốn xác nhận service xử lý được nghiệp vụ, phải gọi một endpoint có đọc/ghi DB thật.
- Muốn xác nhận database sống, dùng CheckHeal (`GET /api/v1/healthcheck/status` kèm `X-Api-Key`) hoặc kết nối trực tiếp database của service đó.
- Một service trả `200 /health` vẫn có thể trả `500` cho mọi API nghiệp vụ nếu connection string sai.

### 2.3. Ba cách gọi thẳng backend

#### Cách 1: Swagger UI của service

```bash
# Chạy duy nhất service cần test; port lấy từ launchSettings.json
dotnet run --project src/Services/User/User.Api
# Mở http://localhost:8001/swagger
```

Với Wallet, chạy `dotnet run --project src/Services/Wallet/Wallet.Api` và mở `http://localhost:8008/swagger`.

Nếu cần xem toàn bộ hợp đồng của 9 service trên một giao diện, chạy Gateway và mở `http://localhost:8080/swagger`. Gateway gộp Swagger downstream qua `/swagger/downstream/{service}/swagger.json`; các service đích phải đang chạy, nếu không tài liệu tương ứng sẽ không tải được.

#### Cách 2: Postman hoặc file `.http`

- Method và URL trỏ thẳng backend, ví dụ `POST http://localhost:8001/api/v1/auth/login`.
- Body chọn `raw` → `JSON`.
- Với endpoint cần danh tính, thêm header `x-user-id`, `x-user-roles` thay vì `Authorization: Bearer`.

#### Cách 3: cURL

```bash
# 1. Health check
curl -i http://localhost:8001/health

# 2. Đăng ký tài khoản (User Service) — đúng hợp đồng RegisterApiRequest
curl -i -X POST http://localhost:8001/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "buyer01@nexus.local",
    "password": "Password123!",
    "firstName": "Van A",
    "lastName": "Nguyen",
    "username": "buyer01",
    "phoneNumber": "0900000001"
  }'

# 3. Đăng nhập (User Service)
curl -i -X POST http://localhost:8001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "buyer01@nexus.local",
    "password": "Password123!"
  }'

# 4. Danh sách sản phẩm (Catalog Service)
curl -i "http://localhost:8002/api/v1/products?page=1&pageSize=10"
```

`RegisterApiRequest` chỉ nhận `email`, `password`, `firstName`, `lastName`, `phoneNumber`, `username`. Không có trường `fullName` hay `role`; các trường lạ trong JSON bị bỏ qua.

### 2.4. Giả lập danh tính khi gọi thẳng backend

Gateway tiêm các header sau vào request downstream:

| Header | Giá trị Gateway gửi xuống | Định dạng khi test thủ công |
| :--- | :--- | :--- |
| `x-user-id` | `sub` / NameIdentifier của JWT | GUID hợp lệ, ví dụ `01912345-6789-7abc-def0-123456789abc` |
| `x-user-email` | `email` của JWT | Email |
| `x-user-roles` | Danh sách role, **chữ thường**, phân tách bằng dấu phẩy | `buyer`, `seller`, `admin`, `staff` |
| `x-user-permissions` | Danh sách permission, **chữ in hoa**, phân tách bằng dấu phẩy | `PRODUCT_READ`, `WALLET_WITHDRAW` |
| `x-client-ip` | IP client do Gateway xác định | Tùy chọn |
| `x-trace-id` | Trace id của Gateway | Tùy chọn, chỉ để đối chiếu log |

Ví dụ gọi thẳng Wallet và Log:

```bash
# Ví của chính người dùng
curl -i http://localhost:8008/api/v1/wallets/me \
  -H "x-user-id: 01912345-6789-7abc-def0-123456789abc" \
  -H "x-user-roles: buyer" \
  -H "x-user-email: buyer01@nexus.local"

# Truy vấn log — LogController yêu cầu role admin hoặc staff
curl -i "http://localhost:8004/api/v1/logs?page=1&pageSize=20" \
  -H "x-user-id: 01912345-6789-7abc-def0-123456789abc" \
  -H "x-user-roles: admin"
```

Quy tắc RBAC tại service:

- Thiếu `x-user-id` hoặc GUID không hợp lệ → `401 UNAUTHORIZED`, `detail: "Authentication is required to access this resource."`.
- Có danh tính nhưng sai role → `403 FORBIDDEN`, `detail` liệt kê role được yêu cầu.
- `admin` và `staff` được xem là role quản trị trong `RequireRoleAttribute`; nhiều action còn kiểm tra quyền sở hữu tài nguyên bằng `GetUserId()`.

> **Cảnh báo:** Gọi thẳng backend là cách bỏ qua Gateway. Chỉ làm trên máy dev. Không mở port `8001`-`8009` ra Internet khi Internal API còn tạm khóa, vì hiện không có `X-Internal-Service-Key` để bảo vệ các route liên service.

### 2.5. Hợp đồng phản hồi: thẳng backend khác Gateway

**Gọi thẳng backend — thành công:** controller trả dữ liệu thô, không có lớp `success`/`data`.

```json
{
  "userId": "01912345-6789-7abc-def0-123456789abc",
  "email": "buyer01@nexus.local",
  "otpExpiresIn": 300
}
```

**Gọi thẳng backend — lỗi:** `application/problem+json` do `GlobalExceptionHandlerMiddleware` sinh ra.

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "Business rule violation",
  "status": 400,
  "errorCode": "EMAIL_ALREADY_EXISTS",
  "detail": "Email is already registered in the system.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
}
```

**Gọi qua Gateway — thành công:** `ResponseEnvelopeMiddleware` bọc payload 2xx vào `ApiResponse<T>`.

```json
{
  "success": true,
  "statusCode": 201,
  "message": "Operation completed successfully.",
  "data": {
    "userId": "01912345-6789-7abc-def0-123456789abc",
    "email": "buyer01@nexus.local",
    "otpExpiresIn": 300
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-31T05:56:00Z"
}
```

**Gọi qua Gateway — lỗi do service:** Gateway **không** bọc lại response lỗi. Body vẫn là `problem+json` của service, chỉ khác là client nhận thêm header `X-Trace-Id`.

**Gọi qua Gateway — lỗi do Gateway:** dùng `ApiErrorResponse`, không có `detail`, chỉ có `message`.

```json
{
  "success": false,
  "statusCode": 403,
  "errorCode": "FORBIDDEN_HEADER_SPOOFING",
  "message": "Security violation: Untrusted identity header detected in external request.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-31T05:56:00Z"
}
```

**Phân trang:** service trả `PagedData<T>` với `items` và `pagination`; Gateway bọc nguyên khối vào `data`.

```json
{
  "items": [],
  "pagination": {
    "pageIndex": 1,
    "pageSize": 20,
    "totalCount": 0,
    "totalPages": 0,
    "hasPreviousPage": false,
    "hasNextPage": false
  }
}
```

**204 NoContent:** endpoint xóa hoặc không có body trả `204`; Gateway giữ nguyên `204`, không tạo envelope.

**Enum:** mọi enum trong JSON đầu ra là chuỗi PascalCase (`"Active"`, `"Pending"`, `"Delivered"`). Đầu vào chấp nhận chuỗi PascalCase, case-insensitive và SCREAMING_SNAKE_CASE (dấu gạch dưới được chuẩn hóa); số nguyên bị từ chối.

---

## 3. PHẦN 2: KIỂM THỬ MỘT LỜI GỌI LIÊN SERVICE QUA REST

Không còn event consumer, không còn RabbitMQ. Một "consumer" cũ tương đương với một endpoint REST mà service khác gọi vào. Muốn test luồng này, có hai cách:

1. **Test service đích độc lập:** gọi thẳng endpoint của service đích bằng cURL/Postman, không cần chạy service gọi.
2. **Test service gọi:** chạy service gọi và service đích, kích hoạt nghiệp vụ ở service gọi, rồi đối chiếu response, log và trace.

### 3.1. Ma trận lời gọi đang tồn tại trong code

| Caller | Callee | Method và path | Biến cấu hình | Timeout |
| :--- | :--- | :--- | :--- | :---: |
| User | Notification | `POST /api/v1/notifications/email/otp` | `NOTIFICATION_SERVICE_URL` | `10s` |
| Catalog | Fulfillment | `POST /api/v1/inventories/initialize` | `FULFILLMENT_SERVICE_URL` | `10s` |
| Commerce | Wallet | `POST /api/v1/wallets/checkout/direct` | `WALLET_SERVICE_URL` | `10s` |
| Commerce | Catalog | `POST /api/v1/products/reserve` | `CATALOG_SERVICE_URL` | `10s` |
| Các service | Log | `POST /api/v1/logs/batch` | `LOG_SERVICE_URL` | — |
| CheckHeal | 8 service | `GET /health` | `HealthCheck:Services:*` | `5s` |

`POST /api/v1/logs/batch` đã có controller nhưng hiện chưa có caller thường trực trong code. Các target của CheckHeal mặc định tắt; phải bật qua API toggle trước khi dùng để chẩn đoán.

### 3.2. Test từng service đích bằng cURL

#### A. Notification — gửi email OTP

```bash
curl -i -X POST http://localhost:8007/api/v1/notifications/email/otp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "buyer01@nexus.local",
    "fullName": "Nguyen Van A",
    "otpCode": "888999",
    "expiresInMinutes": 5
  }'
```

Kết quả mong đợi:

- `200 OK` với `{ "success": true, "message": "...", "data": { ... } }` khi SMTP gửi thành công.
- `400 VAL_INVALID_EMAIL` khi email rỗng hoặc sai định dạng.
- `400 VAL_INVALID_OTP` khi thiếu `otpCode`.
- `500 EMAIL_SEND_FAILED` khi SMTP từ chối hoặc timeout; đọc log Notification để xem lỗi SMTP gốc.

Endpoint này không yêu cầu JWT và không kiểm tra `x-user-id`; nó là route liên service đang dùng đường dẫn công khai.

#### B. Fulfillment — khởi tạo tồn kho

```bash
curl -i -X POST http://localhost:8006/api/v1/inventories/initialize \
  -H "Content-Type: application/json" \
  -d '{
    "skuId": "01912345-6789-7abc-def0-123456789abc",
    "warehouseId": null,
    "initialQuantity": 100
  }'
```

`skuId` phải là GUID. `warehouseId` có thể null. `initialQuantity` mặc định `0`. Kết quả mong đợi là `200 OK` kèm `InventoryItemResponse`.

#### C. Wallet — thanh toán trực tiếp từ ví

`CheckoutDirectCommand` yêu cầu đủ `orderId`, `amount`, `gateway`, `returnUrl`; `userId` lấy từ header `x-user-id`, không lấy từ body.

```bash
curl -i -X POST http://localhost:8008/api/v1/wallets/checkout/direct \
  -H "Content-Type: application/json" \
  -H "x-user-id: 01912345-6789-7abc-def0-123456789abc" \
  -H "Idempotency-Key: 3f1c2b4a-1111-4a2b-9c3d-1234567890ab" \
  -d '{
    "orderId": "01912345-6789-7abc-def0-123456789abd",
    "amount": 150000.00,
    "gateway": "VnPay",
    "bankCode": null,
    "returnUrl": "https://example.com/payment/return"
  }'
```

Hành vi cần biết khi đọc kết quả:

- Endpoint tạo giao dịch `Pending` và trả `paymentUrl`, **chưa trừ số dư**. Việc trừ tiền xảy ra ở luồng IPN/return của VNPay.
- `amount` phải lớn hơn `0`; `orderId` phải là GUID.
- `x-user-id` phải là GUID và tương ứng với ví đã tồn tại, nếu không trả `404 WALLET_NOT_FOUND`.
- Gọi lại cùng `orderId` với cùng `amount` và cùng `gateway` sẽ trả lại giao dịch `Pending` cũ; khác amount/gateway sẽ bị từ chối `400`. Đây là cơ chế chống trùng theo `ReferenceId == orderId`.
- Test sai `x-user-id` sẽ nhận `400 VAL_INVALID_USER_ID`; thiếu `gateway` hoặc `returnUrl` sẽ nhận `400 VAL_INVALID_INPUT` do validation của MediatR.

#### D. Log — nhận batch log

```bash
curl -i -X POST http://localhost:8004/api/v1/logs/batch \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "serviceName": "user-service",
        "eventType": "USER_REGISTERED",
        "logLevel": "Information",
        "entityName": "Users",
        "entityId": "01912345-6789-7abc-def0-123456789abc"
      }
    ]
  }'
```

Endpoint nhận `object` và trả `202 Accepted` với `{ "success": true, "message": "Log batch accepted for processing." }`. Hiện implementation chỉ ghi log tiếp nhận và trả `202`, chưa persist từng entry vào bảng log; đừng dùng endpoint này để kiểm chứng dữ liệu log đã ghi. Muốn kiểm chứng persistence, dùng `GET /api/v1/logs` sau khi có luồng ghi log thật.

### 3.3. Test service gọi và service đích cùng lúc

Ví dụ luồng `User → Notification` khi đăng ký:

1. Chạy User và Notification.
2. Gọi `POST http://localhost:8001/api/v1/auth/register`.
3. Kiểm tra response User: `201 Created` kèm `userId`, `email`, `otpExpiresIn`.
4. Kiểm tra log User: có dòng `[OTP DISPATCH]` chứa mã OTP và dòng `Dispatched OTP email via REST Notification client`.
5. Kiểm tra log Notification: có dòng `[REST Email] Dispatching OTP email to ...`.
6. Nếu Notification chết, User **vẫn đăng ký thành công**: `EmailNotificationClient` bắt exception, trả `false`, và User ghi `LogWarning` với OTP fallback. Đây là graceful fallback có chủ đích, không phải lỗi đăng ký.
7. Nếu cần OTP để test tiếp, đọc mã trong log User hoặc Redis (`otp:*`), không phụ thuộc email thật.

Ví dụ luồng `Catalog → Fulfillment` khi tạo sản phẩm:

1. Chạy Catalog và Fulfillment.
2. Gọi `POST http://localhost:8002/api/v1/products` với `x-user-id` và `x-user-roles: seller`.
3. Catalog gọi `POST /api/v1/inventories/initialize` sang Fulfillment.
4. Kiểm tra response Catalog, log `FulfillmentClient`, rồi gọi `GET http://localhost:8006/api/v1/inventories/{skuId}` để xác nhận tồn kho đã tạo.

### 3.4. Hai lệch hợp đồng đang tồn tại

Hai lỗi dưới đây là lỗi hợp đồng giữa các service, không phải lỗi hạ tầng. Đừng chẩn đoán nhầm thành "service chết" hoặc "network lỗi":

| Luồng | Hiện trạng | Triệu chứng khi bật luồng |
| :--- | :--- | :--- |
| Commerce → Wallet | `WalletClient` gửi `{ orderId, userId, amount }`, thiếu `gateway` và `returnUrl` | Wallet trả `400 VAL_INVALID_INPUT` |
| Commerce → Catalog | `CatalogClient` gọi `POST /api/v1/products/reserve`, nhưng `ProductsController` chưa có action này | Catalog trả `404` |

Hai lệch này được ghi nhận chi tiết tại `docs/SERVICE_CONNECTIVITY_GUIDE.md` mục 5.1. Khi sửa code, cập nhật lại cả hai tài liệu.

### 3.5. Trạng thái Internal API (2026-10-31)

- Không còn route `/api/v1/internal/**`.
- Không còn thư mục `Controllers/Internal/`.
- `InternalServiceAuthMiddleware` và `InternalServiceAuthHandler` chỉ còn file, chưa đăng ký trong pipeline.
- Các route liên service dùng đường dẫn công khai: `/api/v1/notifications/email/otp`, `/api/v1/notifications/email/send`, `/api/v1/wallets/checkout/direct`, `/api/v1/inventories/initialize`, `/api/v1/inventories/{skuId}`, `/api/v1/logs/batch`.
- Gateway không chặn path internal, nhưng các route trên đi qua Gateway như API thường.

Hệ quả khi test: không cần gửi `X-Internal-Service-Key`. Đồng thời, bất kỳ ai gọi được các route này đều có thể gửi OTP, tạo giao dịch ví `Pending` hoặc khởi tạo tồn kho. Chỉ test trên môi trường dev hoặc mạng nội bộ.

---

## 4. PHẦN 3: KIỂM THỬ KẾT HỢP GATEWAY → SERVICE → DOWNSTREAM → DATABASE

Phần này kiểm tra toàn bộ mắt xích mà người dùng thật đi qua. Ví dụ luồng đăng ký:

### 4.1. Luồng đăng ký và xác thực OTP

**Bước 1 — Đăng ký qua Gateway.** Gateway áp rate limit `5 request / 300 giây / IP` cho `POST /api/v1/auth/register`.

```bash
curl -i -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "buyer01@nexus.local",
    "password": "Password123!",
    "firstName": "Van A",
    "lastName": "Nguyen",
    "username": "buyer01"
  }'
```

Kết quả mong đợi: `201 Created` với envelope `success: true`, `data.userId`, `data.email`, `data.otpExpiresIn`. Nếu gọi quá nhanh: `429 RATE_LIMIT_EXCEEDED` kèm header `Retry-After`.

**Bước 2 — Lấy OTP.** OTP được lưu Redis 5 phút và ghi log User. Nếu Notification đang chạy và SMTP đúng, email sẽ tới hộp thư; nếu không, đọc log User hoặc Redis.

**Bước 3 — Xác thực OTP qua Gateway.**

```bash
curl -i -X POST http://localhost:8080/api/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer01@nexus.local","otp":"888999"}'
```

**Bước 4 — Đăng nhập và lấy JWT.**

```bash
curl -i -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"buyer01@nexus.local","password":"Password123!"}'
```

**Bước 5 — Gọi API bảo vệ bằng JWT.**

```bash
curl -i http://localhost:8080/api/v1/wallets/me \
  -H "Authorization: Bearer <accessToken>"
```

**Bước 6 — Đối chiếu trạng thái thật.**

- User DB: bản ghi `Users` chuyển `PendingVerification` → `Active`; `EmailVerifiedAt` được điền.
- User DB: `UserRoles` có role `Buyer`; `ReputationScores` có điểm khởi tạo `50`.
- Redis: key OTP bị đánh dấu consumed sau khi xác thực.
- Wallet DB: nếu gọi `/wallets/me` trả `404 WALLET_NOT_FOUND`, ví chưa được tạo cho user đó; đây là lỗi nghiệp vụ, không phải lỗi Gateway.

### 4.2. Checklist xác nhận một luồng kết hợp

- [ ] Response của service gọi thành công (`2xx`) và đúng envelope khi đi qua Gateway.
- [ ] Response của service đích xuất hiện trong span `HttpClient` hoặc log typed client.
- [ ] Dữ liệu đã ghi đúng database của service sở hữu.
- [ ] Nếu service đích chết, service gọi vẫn xử lý được theo graceful fallback đã thiết kế (ví dụ OTP email).
- [ ] Không có `x-user-*` nào do client tự gửi khi đi qua Gateway.
- [ ] `traceId` của request được lưu lại để tra Tempo khi cần.

---

## 5. PHẦN 4: CHẨN ĐOÁN LỖI THEO 3 TẦNG

### 5.1. Tầng 1 — Đọc đúng loại phản hồi lỗi

Có ba nguồn lỗi khác nhau; đọc sai nguồn sẽ chẩn đoán sai:

| Nguồn | Content-Type | Trường nhận diện | Ý nghĩa |
| :--- | :--- | :--- | :--- |
| **Gateway** | `application/json` | `success: false`, `statusCode`, `errorCode`, `message`, `traceId`, `timestamp` | Bị chặn ở biên: spoofing, admin guard, rate limit, idempotency key, exception của Gateway |
| **Service** | `application/problem+json` | `type`, `title`, `status`, `errorCode`, `detail`, `traceId` | Validation, domain exception, lỗi nghiệp vụ, lỗi hạ tầng của service |
| **Hạ tầng / YARP** | Có thể không theo chuẩn | `502`, `504`, body text hoặc HTML | Không kết nối được destination, timeout proxy |

Mã lỗi thường gặp:

| HTTP | errorCode | Nguồn | Điều kiện |
| :---: | :--- | :--- | :--- |
| `400` | `VAL_INVALID_INPUT` | Gateway hoặc service | Model binding/validation thất bại; `Idempotency-Key` rỗng hoặc dài quá 128 ký tự |
| `400` | `VAL_INVALID_EMAIL` | User / Notification | Email sai định dạng |
| `400` | `VAL_INVALID_OTP` | Notification / User | Thiếu hoặc sai OTP |
| `400` | `OTP_EXPIRED` | User | OTP hết hạn hoặc không tồn tại |
| `400` | `OTP_INVALID` | User | OTP không khớp |
| `400` | `OTP_ALREADY_USED` | User | OTP đã được dùng |
| `400` | `EMAIL_ALREADY_EXISTS` | User | Email đã đăng ký và đang active |
| `400` | `USERNAME_ALREADY_EXISTS` | User | Username đã tồn tại |
| `400` | `VAL_INVALID_USER_ID` | Wallet | Thiếu hoặc sai `x-user-id` |
| `400` | `VAL_INVALID_ORDER_ID` | Wallet | `orderId` không phải UUID |
| `400` | `INSUFFICIENT_BALANCE` | Wallet | Số dư không đủ |
| `401` | `UNAUTHORIZED` | Gateway hoặc service | Thiếu JWT/danh tính ở route yêu cầu xác thực |
| `403` | `FORBIDDEN` | Gateway hoặc service | Sai role, không phải admin/staff |
| `403` | `FORBIDDEN_HEADER_SPOOFING` | Gateway | Client gửi `x-user-*` hoặc `x-internal-service-key` |
| `404` | `WALLET_NOT_FOUND` | Wallet | User chưa có ví |
| `404` | `SERVICE_NOT_FOUND` | CheckHeal | Target health không tồn tại |
| `429` | `RATE_LIMIT_EXCEEDED` | Gateway | Vượt rate limit auth |
| `500` | `INTERNAL_SERVER_ERROR` | Gateway hoặc service | Exception không được xử lý |
| `500` | `EMAIL_SEND_FAILED` | Notification | SMTP gửi thất bại |

Quy ước thông báo: 100% tiếng Anh, **sentence case** ở `detail`/`message`, `errorCode` là `SCREAMING_SNAKE_CASE`.

### 5.2. Tầng 2 — Tra trace trên Grafana Tempo

#### Bước 1: Lấy trace id

- **Qua Gateway:** đọc header `X-Trace-Id` hoặc trường `traceId` trong body.
- **Gọi thẳng service:** trường `traceId` trong body lỗi; response thành công không có header trace.
- **Chủ động:** gửi header W3C `traceparent` khi test để tất cả service dùng chung một trace id:

```bash
curl -i http://localhost:8001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" \
  -d '{"identifier":"buyer01@nexus.local","password":"Password123!"}'
```

Giá trị `traceId` trong code là `Activity.Current.Id`, nên có thể là chuỗi W3C đầy đủ dạng `00-<32 hex trace-id>-<16 hex span-id>-01`. Khi tìm trong Tempo, dùng **32 ký tự hex ở giữa**, ví dụ `4bf92f3577b34da6a3ce929d0e0e4736`.

#### Bước 2: Mở Grafana

1. Truy cập `http://localhost:3000/explore`.
2. Chọn datasource **Tempo**.
3. Dán trace id vào ô tìm kiếm, chạy query.
4. Mở **Waterfall**.

#### Bước 3: Đọc waterfall đúng thực tế instrumentation

Code hiện tại chỉ bật hai instrumentation:

```csharp
t.AddAspNetCoreInstrumentation()   // span HTTP request vào service
 .AddHttpClientInstrumentation();  // span HTTP client gọi service khác
```

Vì vậy:

- **Có** span request đến từng service và span gọi REST liên service.
- **Có thể có** exception event trên span bị lỗi (`exception.type`, `exception.message`, `exception.stacktrace`), nhưng chỉ khi exception thoát khỏi pipeline instrumentation. Vì mỗi service có `GlobalExceptionHandlerMiddleware` bắt exception để trả `problem+json`, không phải lỗi nghiệp vụ nào cũng hiện thành span đỏ. Luôn đối chiếu thêm `errorCode`, log service và response body.
- **Không có** span SQL/EF Core vì chưa bật `AddEntityFrameworkCoreInstrumentation` hoặc `AddNpgsql`. Đừng tìm `db.statement` trong Tempo; muốn có, phải bổ sung instrumentation vào `ObservabilityExtensions.cs` của service tương ứng.
- **Gateway không xuất span** vì Gateway không cấu hình OpenTelemetry exporter. Tempo chỉ chứa span của backend service. Khi cần đối chiếu request ở biên, dùng `X-Trace-Id` và log Gateway.
- Tempo lưu trace cục bộ với retention `48h` (cấu hình `infra/tempo/tempo.yaml`). Trace cũ hơn sẽ không tra được.

#### Bước 4: Xác định điểm lỗi

- Span đỏ ở service nào → xem exception event nếu có, rồi đối chiếu `errorCode` và log service đó để lấy file `.cs`/số dòng.
- Span `HttpClient` đỏ hoặc có duration gần timeout → lỗi nằm ở service đích hoặc mạng, không phải logic service gọi.
- Không thấy span nào → kiểm tra `OTEL_EXPORTER_OTLP_ENDPOINT`; nếu sai, service không gửi được trace về Tempo.
- Trace có nhưng thiếu span downstream → service gọi không thực hiện request, hoặc request bị chặn trước khi ra ngoài.

### 5.3. Tầng 3 — Chẩn đoán lời gọi liên service thất bại

Các typed client hiện tại không ném lỗi ra controller: `EmailNotificationClient`, `WalletClient`, `CatalogClient` trả `bool`, `FulfillmentClient` trả `null`, và mọi client chỉ ghi log. Vì vậy API của service gọi có thể vẫn trả `2xx` dù downstream thất bại. Quy trình kiểm tra:

1. **Đọc log service gọi.** Tìm `LogWarning` của typed client, ví dụ `[REST Wallet Client] Checkout payment failed ... Status: 400, Details: ...`. Log này chứa status và body lỗi thật của service đích.
2. **Đọc trace.** Span `HttpClient` cho biết thời gian và status; nếu duration xấp xỉ `10s`, đó là timeout mặc định.
3. **Gọi lại service đích độc lập** bằng cURL theo mục 3.2 để tái hiện lỗi mà không qua service gọi.
4. **Kiểm tra service đích còn sống.** `GET /health` chỉ chứng minh process sống; dùng CheckHeal để kiểm tra sâu hơn:

```bash
curl -i http://localhost:8009/api/v1/healthcheck/status \
  -H "X-Api-Key: <HealthCheck__ApiKey>"
```

Nếu target đang tắt, bật bằng `PUT /api/v1/healthcheck/services/{serviceName}/toggle` (gọi thẳng `8009`, nhớ gửi `X-Api-Key`) với body `{"enabled":true,"url":"http://localhost:8001/health"}`. CheckHeal mặc định tắt target; phải bật mới có dữ liệu.

5. **Kiểm tra database.** Nếu service đích trả `500` khi thao tác DB, xem log service đích và kết nối đúng database của nó (`5433`-`5440`). Không kiểm tra database của service khác.
6. **Thử lại an toàn.** Không có retry tự động. Chỉ retry thao tác idempotent:
   - Wallet chống trùng theo `ReferenceId == orderId`.
   - Có thể gửi `Idempotency-Key` (UUIDv4, tối đa 128 ký tự) khi gọi qua Gateway; Gateway chỉ chuyển tiếp header nếu hợp lệ.
   - Với thao tác không idempotent, phải kiểm tra trạng thái thật trước khi gọi lại.

### 5.4. Bảng lỗi thường gặp khi test

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
| :--- | :--- | :--- |
| `Connection refused` | Service chưa chạy hoặc sai port | Kiểm tra process và `launchSettings.json` |
| `404` khi gọi Gateway | Route chưa khai báo trong `Gateway/appsettings.json` | Gọi thẳng service hoặc bổ sung route |
| `401 UNAUTHORIZED` | Thiếu JWT (qua Gateway) hoặc thiếu `x-user-id` (gọi thẳng) | Gửi đúng header |
| `403 FORBIDDEN_HEADER_SPOOFING` | Client tự gửi `x-user-*` qua Gateway | Bỏ các header đó; để Gateway tiêm |
| `403 FORBIDDEN` | Sai role hoặc không phải `admin`/`staff` | Dùng tài khoản đúng role |
| `429 RATE_LIMIT_EXCEEDED` | Vượt giới hạn auth | Chờ theo `Retry-After` |
| `400 VAL_INVALID_INPUT` | DTO hai bên lệch hợp đồng hoặc validation thất bại | Đối chiếu mục 3.4 và Swagger của service đích |
| `502` hoặc timeout | Destination chết hoặc chậm quá `10s` | Kiểm tra service đích, log typed client |
| API trả `2xx` nhưng nghiệp vụ không xảy ra | Typed client trả `false` và chỉ ghi log | Đọc log service gọi và kiểm tra service đích |
| Trace không tìm thấy trên Tempo | Sai `OTEL_EXPORTER_OTLP_ENDPOINT`, trace cũ hơn 48h, hoặc đang tìm full `traceparent` thay vì 32 hex | Sửa endpoint; dùng đúng 32 hex trace id |

---

## 6. TÓM TẮT MA TRẬN CÔNG CỤ TEST & DEBUG

| Nhiệm vụ | Công cụ | Cách thực hiện | Lợi ích |
| :--- | :--- | :--- | :--- |
| **Test một endpoint độc lập** | Swagger UI, Postman, cURL | Gọi `http://localhost:8001`-`8009` trực tiếp | Không cần Gateway, đặt breakpoint dễ |
| **Test hợp đồng qua Gateway** | Postman, cURL | Gọi `http://localhost:8080` kèm JWT | Kiểm tra đúng đường người dùng thật đi |
| **Test service đích của một lời gọi liên service** | cURL/Postman | Gọi thẳng Notification, Fulfillment, Wallet, Log | Không cần chạy service gọi |
| **Test service gọi** | Swagger/Postman + log | Kích hoạt nghiệp vụ, đọc `LogWarning` của typed client | Phát hiện lỗi fallback và lệch hợp đồng |
| **Tra cứu lỗi theo trace** | Grafana Tempo | `http://localhost:3000/explore`, dán 32 hex trace id | Xem waterfall, exception, span HTTP client |
| **Kiểm tra sâu service và database** | CheckHeal | `GET /api/v1/healthcheck/status` kèm `X-Api-Key` | Phát hiện DB chết dù `/health` vẫn 200 |
| **Kiểm tra mạng và port** | `getent`, `nc`, `curl` | DNS → TCP → health → API | Loại trừ lỗi hạ tầng trước khi đọc code |

---

## 7. CHECKLIST TRƯỚC KHI KẾT LUẬN MỘT ENDPOINT ĐÃ HOẠT ĐỘNG

- [ ] Gọi thẳng service trả đúng dữ liệu hoặc đúng `204`.
- [ ] Gọi qua Gateway trả đúng envelope và đúng `statusCode`.
- [ ] Trường hợp lỗi trả đúng `errorCode` và message tiếng Anh sentence case.
- [ ] Danh tính lấy từ `x-user-id`/JWT, không lấy từ query hoặc body.
- [ ] Enum trả về là chuỗi PascalCase.
- [ ] Phân trang do service tính, có `items` và `pagination`.
- [ ] Typed client gọi downstream có timeout và xử lý fallback rõ ràng.
- [ ] Có trace id và tìm được span tương ứng trên Tempo (nếu bật tracing).
- [ ] Đã kiểm tra dữ liệu thật trong database của service sở hữu.
- [ ] Không có secret, connection string hoặc `.env` bị đưa vào tài liệu hay commit.
