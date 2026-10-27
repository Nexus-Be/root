# ĐẶC TẢ KIẾN TRÚC & CẨM NANG CÁC THƯ MỤC CỦA NEXUS API GATEWAY
## (NEXUS EDGE API GATEWAY ARCHITECTURE & FOLDERS REFERENCE)

> **Mục tiêu tài liệu**: Cung cấp bức tranh toàn cảnh về kiến trúc **Edge API Gateway (.NET 8 LTS, C# 12)**, giải thích chi tiết chức năng của **15 thư mục mã nguồn** bên trong `Nexus.Gateway`, cùng danh mục toàn bộ các tính năng cốt lõi đang vận hành trong Gateway.

---

## 1. TỔNG QUAN KIẾN TRÚC EDGE API GATEWAY

API Gateway là **vành đai phòng thủ và điểm tiếp nhận duy nhất (Single Entry Point)** cho toàn bộ lưu lượng truy cập từ các ứng dụng Frontend (Web SPA, Mobile App, Postman) gọi vào hệ thống backend:

```
[ Frontend: React / Vue / Mobile ]
               │  (HTTP/1.1 REST JSON, Port 8080)
               ▼
┌────────────────────────────────────────────────────────┐
│                   NEXUS API GATEWAY                    │
│                                                        │
│  [1. Serilog Request Logging & W3C X-Trace-Id]        │
│  [2. Transparent Route Rewrite (/gateway/api -> /api)]│
│  [3. CORS Policy Engine & Preflight Options]          │
│  [4. Dual-Runtime Resolver (Real vs Mock)]             │
│  [5. JWT Bearer & RBAC Authorization Engine]           │
│  [6. Distributed Dynamic Rate Limiter (Redis)]         │
│  [7. Declarative Mock Engine (Mocks/*.mock.json)]      │
│  [8. Gateway Dispatcher -> gRPC Client / Seeds Data]  │
│  [9. RFC 9110 / RFC 7807 Centralized ProblemDetails]  │
└───────┬──────────────────────────────────┬─────────────┘
        │ (Mode = Real)                    │ (Mode = Mock)
        ▼ (HTTP/2 gRPC, Ports 8001-8008)   ▼
┌────────────────────────────────┐   ┌─────────────────────────────┐
│    8 BACKEND MICROSERVICES     │   │ STATIC SEED FIXTURES        │
│  (Users, Catalog, Commerce...) │   │ (Seeds/{feature}/*.json)    │
└────────────────────────────────┘   └─────────────────────────────┘
```

---

## 2. GIẢI THÍCH CHI TIẾT 15 THƯ MỤC CỦA `Nexus.Gateway`

Dưới đây là sơ đồ cây và chức năng của từng thư mục trong `src/Services/ApiGateway/Nexus.Gateway/`:

```
Nexus.Gateway/
├── Common/            # Tiện ích dùng chung, Exceptions & JSON Enums Converters
├── Contracts/         # Hợp đồng gRPC Protobuf (shop.proto)
├── Controllers/       # HTTP REST Controllers tiếp nhận request từ Client
├── Dispatching/       # Bộ não điều phối cuộc gọi sang Backend gRPC hoặc Mock Seed
├── Dtos/              # Request / Response Data Transfer Objects
├── Extensions/        # Các Extension Methods cấu hình Dependency Injection & Pipeline
├── HealthProber/      # Hệ thống giám sát chủ động sức khỏe 8 Microservices (Prober Daemons)
├── Logging/           # Cấu hình Serilog & Batching sink đẩy log tập trung
├── Middleware/        # Middleware tùy biến (Distributed Redis Rate Limiter)
├── MockEngine/        # Động cơ phân giải Declarative Mocks từ file JSON
├── Mocks/             # Chứa các file mock nhanh 0-dòng C# (*.mock.json) cho Frontend
├── Responses/         # Chuẩn hóa vỏ bọc ApiResponse<T> & RFC ProblemDetails
├── Security/          # Bảo mật JWT, RBAC, Mock Security Adapter & Policy Filters
├── Seeds/             # Chứa dữ liệu giả lập chuẩn Protobuf (Seeds/auth/, Seeds/users/...)
└── Services/          # Quản lý cấu hình Runtime (GatewayRuntimeManager)
```

---

### Chi Tiết Từng Thư Mục:

#### 1. `Common/` (Tiện Ích & Xử Lý Chuẩn Hóa)
* **`GatewayInputException.cs`**: Exception chuẩn dùng khi client truyền thiếu hoặc sai dữ liệu đầu vào. Tự động được bắt bởi Pipeline và chuyển thành HTTP 400 ProblemDetails với mã lỗi `VAL_INVALID_INPUT`.
* **`PascalCaseJsonStringEnumConverter.cs`**: Bộ chuyển đổi 2 chiều Enum tự động. Khi Frontend gửi lên chuỗi PascalCase (ví dụ `"PendingVerification"`, `"Active"`), nó chuyển thành số nguyên `int` để gửi xuống Backend gRPC; và ngược lại, khi Backend trả về số `int`, Gateway chuyển thành chuỗi PascalCase cho Frontend dễ đọc.

#### 2. `Contracts/` (Hợp Đồng gRPC Protobuf)
* **`shop.proto`**: Đơn nguồn sự thật (Single Source of Truth) định nghĩa các dịch vụ gRPC (`UsersApi`, `CatalogApi`, v.v.) và các thông điệp dữ liệu (Messages). Grpc.Tools tự động biên dịch file này thành các lớp C# strongly-typed khi build.

#### 3. `Controllers/` (REST Controllers)
* **`AuthController.cs`**: Chứa 4 API vàng đã triển khai hoàn tất:
  - `POST /api/v1/auth/register` (Đăng ký tài khoản mới)
  - `POST /api/v1/auth/login` (Đăng nhập hệ thống)
  - `POST /api/v1/auth/verify-otp` (Xác thực mã kích hoạt OTP)
  - `POST /api/v1/auth/resend-otp` (Gửi lại mã OTP)
* **`UsersController.cs`**: Chứa API `GET /api/v1/users/me` (Lấy thông tin cá nhân của người dùng đang đăng nhập).
* **`GatewayControlController.cs`**: Quản lý cấu hình runtime của Gateway: xem danh sách mode của 8 services (`GET /api/v1/gateway/modes`), chuyển đổi mode (`PUT /api/v1/gateway/modes`), nạp lại mock engine (`POST /api/v1/mock-engine/reload`).
* **`HealthProberController.cs`**: Cung cấp API quản lý các Prober Daemons kiểm tra sức khỏe 8 services (`GET /api/v1/gateway/prober/status`, `PUT /api/v1/gateway/prober/{service}`, `POST /api/v1/gateway/prober/check/{service}`).
* **Các Controller Stub** (`ProductsController.cs`, `CartController.cs`, `OrdersController.cs`, `WalletController.cs`...): Các khung sườn Controller đã được chuẩn hóa sẵn Route và BackendTag, sẵn sàng cho team mở rộng thêm API theo nghiệp vụ.

#### 4. `Dispatching/` (Bộ Não Điều Phối)
* **`GatewayDispatcher.cs`**: Lớp điều phối trung tâm. Nhận request từ Controller, kiểm tra xem service đang ở chế độ `Real` hay `Mock`. Nếu `Real` $\rightarrow$ gọi `GrpcServiceCaller`; nếu `Mock` $\rightarrow$ gọi `MockDataMapper` để đọc dữ liệu mẫu từ thư mục `Seeds/`.
* **`GrpcServiceCaller.cs`**: Thực hiện cuộc gọi gRPC sang downstream backend, tự động gắn Header danh tính người dùng (`x-user-id`, `x-user-roles`, `x-user-email`) và `x-trace-id` sang gRPC Metadata.
* **`MockDataMapper.cs`**: Định vị và đọc file JSON trong thư mục `Seeds/` tương ứng với service và operation, sau đó parse sang đối tượng phản hồi.
* **`ModeEvaluator.cs`**: Đánh giá mode ưu tiên theo thứ tự: Request Header override $\rightarrow$ Cấu hình runtime `gateway.runtime.json` $\rightarrow$ Cấu hình tĩnh `appsettings.json`.

#### 5. `Dtos/` (Data Transfer Objects)
* Chứa các DTO nhận dữ liệu từ Client:
  - `Auth/`: `RegisterRequestDto`, `LoginRequestDto`, `VerifyOtpRequestDto`, `ResendOtpRequestDto`.
  - `GatewayControl/`: `UpdateGatewayModesRequestDto`, `BulkUpdateModesDto`.
  - `HealthProber/`: `UpdateProberRequestDto`, `BulkUpdateProberDto`.
  - `Common/`: `PaginationRequest` (hỗ trợ phân trang chuẩn `page`, `pageSize`).

#### 6. `Extensions/` (Đăng Ký Dịch Vụ & Pipeline)
* **`CoreServicesExtension.cs`**: Đăng ký các service nền tảng (Dispatcher, MockEngine, Serializer, ResponseFactory, RateLimitStore).
* **`GrpcClientsExtension.cs`**: Đăng ký các Typed gRPC Clients kết nối tới các microservices.
* **`PipelineExtensions.cs`**: Xây dựng thứ tự chạy chuẩn mực của các Middleware trong Gateway.
* **`TelemetryExtension.cs`**: Cấu hình OpenTelemetry Tracing và Metrics xuất dữ liệu sang Grafana Tempo qua OTLP.
* **`SwaggerExtension.cs`**: Cấu hình Swagger UI, hỗ trợ hiển thị cả Controller APIs lẫn Declarative Mock Endpoints.
* **`LoggingExtensions.cs`**: Cấu hình Serilog Structured Logging.

#### 7. `HealthProber/` (Giám Sát Sức Khỏe & Tự Phục Hồi)
* **`HealthProberManager.cs`**: Quản lý vòng đời của 8 Prober Daemons chạy nền cho 8 services.
* **`ServiceProberDaemon.cs`**: Luồng chạy ngầm gửi request thăm dò định kỳ (Interval 60s, Timeout 30s, FailureThreshold 5) tới endpoint `/health` của backend.
* **`SagaRollbackPublisher.cs`**: Hook kích hoạt bắn sự kiện `ServiceUnhealthyIntegrationEvent` lên RabbitMQ khi phát hiện service bị chết để kích hoạt Saga Rollback.
* **`DockerRecoveryManager.cs`**: Quản lý việc tự động khôi phục / khởi động lại container bị lỗi.

#### 8. `Logging/` (Quản Lý Log Tập Trung)
* **`SerilogConfiguration.cs`**: Cấu hình ghi log ra Console và File `logs/gateway-.log`.
* **`SerilogBatchSink.cs`**: Bộ đệm gom cụm log (Batching Sink: gom đủ 50 log hoặc sau 3 giây) để sẵn sàng đẩy sang `LogService` trong tương lai mà không làm nghẽn thread pool.

#### 9. `Middleware/` (Phần Mềm Trung Gian Tùy Biến)
* **`RedisRateLimitMiddleware.cs`**: Quản lý giới hạn tần suất gọi phân tán bằng Redis theo thuật toán Fixed-Window Bucket. Hỗ trợ nhiều chính sách (Policies) riêng biệt cho từng API.

#### 10. `MockEngine/` & 11. `Mocks/` (Động Cơ Mock Tự Động)
* **`MockEngineMiddleware.cs`**: Quét request đi vào, nếu trùng khớp với bất kỳ file định nghĩa nào trong thư mục `Mocks/*.mock.json`, Gateway sẽ tự động trả kết quả mock ngay lập tức mà không cần đi qua Controller C#.
* **`Mocks/`**: Nơi dev lưu các file `*.mock.json` định nghĩa route, phương thức HTTP, policy và payload mẫu.

#### 12. `Responses/` (Chuẩn Hóa Dữ Liệu Phản Hồi)
* **`ApiResponse.cs`**: Cấu trúc bọc dữ liệu chuẩn toàn hệ thống: `success`, `statusCode`, `message`, `data`, `traceId`, `timestamp`.
* **`ApiResponseFactory.cs`**: Factory tạo response thành công hoặc thất bại, trích xuất traceId chuẩn.
* **`PagedResult.cs`**: Cấu trúc phân trang chuẩn gồm `items` và `pagination` (`pageIndex`, `pageSize`, `totalCount`, `totalPages`).

#### 13. `Security/` (Bảo Mật & Phân Quyền)
* **`EdgeMiddlewareConfiguration.cs`**: Cấu hình CORS và Concurrency Limiter.
* **`GatewayAuthorization.cs`**: Khai báo 5 chính sách phân quyền RBAC: `public`, `authenticated`, `seller`, `staff`, `admin`, `gateway-admin`.
* **`MockSecurityAdapterMiddleware.cs`**: Hỗ trợ cơ chế Bypass Auth khi ở môi trường Development, tự động cấp token danh tính giả lập để test giao diện dễ dàng.

#### 14. `Seeds/` (Dữ Liệu Fixture Cho Controller)
* Chứa các file JSON dữ liệu chuẩn Protobuf được chia theo nhóm tính năng: `Seeds/auth/`, `Seeds/users/`, `Seeds/products/`, `Seeds/cart/`, `Seeds/orders/`. Khi Controller gọi `_dispatcher.DispatchAsync(...)` ở chế độ `Mock`, Gateway sẽ đọc dữ liệu từ thư mục này.

#### 15. `Services/` (Dịch Vụ Runtime)
* **`GatewayRuntimeManager.cs`**: Nạp và theo dõi sự thay đổi của file cấu hình `gateway.runtime.json`, hỗ trợ hot-reload mode của 8 services mà không cần khởi động lại Gateway.

---

## 3. DANH MỤC CÁC TÍNH NĂNG CỐT LÕI HIỆN CÓ CỦA GATEWAY

| Tính Năng | Mô Tả Kỹ Thuật | Lợi Ích Cho Hệ Thống |
| :--- | :--- | :--- |
| **Dual-Runtime Dispatcher** | Điều phối linh hoạt giữa `Mock` (đọc file JSON) và `Real` (gọi gRPC). | Frontend và Backend có thể phát triển song song độc lập. |
| **Fine-Grained Rate Limiting** | Giới hạn tần suất phân tầng theo 4 policy (`auth-strict`: 5/p, `auth-login`: 10/p, `user-frequent`: 120/p, `default`: 100/p) qua Redis. | Bảo vệ API đăng ký/OTP khỏi tấn công Brute-force và chống spam request. |
| **Two-way Enum Conversion** | Chuyển đổi tự động giữa số nguyên `int` ở CSDL và chuỗi `PascalCase` ở Frontend qua `PascalCaseJsonStringEnumConverter`. | Frontend nhận chuỗi trực quan (`"Active"`, `"Suspended"`), CSDL tối ưu lưu trữ bằng số nguyên. |
| **User Identity Propagation** | Tự động đọc thông tin từ JWT và gắn vào gRPC Metadata (`x-user-id`, `x-user-roles`, `x-user-email`). | Các Microservices con luôn biết chính xác ai đang thực hiện hành động. |
| **Distributed Tracing** | Tự động tạo và lan truyền mã `X-Trace-Id` chuẩn W3C sang OpenTelemetry và Grafana Tempo. | Theo dõi toàn bộ luồng request xuyên suốt từ Gateway qua các service và database. |
| **Circuit Breaker Fast-Fail** | Khi service bị Unhealthy, Gateway ngắt mạch trong 0ms trả về lỗi 503 ProblemDetails. | Ngăn chặn hiện tượng nghẽn luồng tầng (Cascading Failure). |
| **RFC 9110 / 7807 Error Contract** | Chuẩn hóa thông báo lỗi 100% tiếng Anh, Sentence case, mã lỗi `SCREAMING_SNAKE_CASE`. | Đồng nhất trải nghiệm xử lý lỗi cho Frontend và Mobile App. |
| **CORS Policy Engine** | Tự động cấu hình Allowed Origins, Methods, Headers và Credentials. | Bảo vệ Gateway khỏi các cuộc tấn công Cross-Origin trái phép. |
