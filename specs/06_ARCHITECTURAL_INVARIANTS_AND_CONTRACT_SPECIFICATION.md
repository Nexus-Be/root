# 06 — ĐẶC TẢ BẤT BIẾN KIẾN TRÚC VÀ HỢP ĐỒNG GIAO TIẾP HỆ THỐNG
# (ARCHITECTURAL INVARIANTS & CONTRACT SPECIFICATION)

> **Trạng thái:** ✅ ĐÃ ĐÓNG ĐINH (LOCKED & ENFORCED)
> **Nguồn sự thật:** Mã nguồn `src/Services/Gateway/` (YARP 2.3.0, Port 8080) và 9 Backend Microservices (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`, `CheckHeal`).
> **Ngày phê chuẩn:** 2026-10-31.
> **Quy chuẩn bắt buộc:** Mọi thay đổi mã nguồn, refactor, tạo service mới hoặc cấu hình hệ thống BẮT BUỘC tuân thủ 100% các bất biến trong tài liệu này.

---

## 1. RANH GIỚI CHUYỂN GIAO TRÁCH NHIỆM (RESPONSIBILITY BOUNDARY)

Hệ thống Nexus phân định ranh giới trách nhiệm tuyệt đối giữa **Gateway tại Biên (Edge)** và **Microservices tại Nhân (Core)**:

```text
               CLIENT (Web Next.js / Mobile App)
                               │
                               ▼  [Internet / Untrusted Traffic]
═══════════════════════════════════════════════════════════════════════════
 [GATEWAY BIÊN - EDGE] (Microsoft YARP Reverse Proxy - Port 8080)
 1. Bóc tách & chặn đứng Header giả mạo (Anti-Header-Spoofing -> 403)
 2. Chặn đứng truy cập vào endpoint nội bộ (/internal/* -> 404)
 3. Xác thực chữ ký số JWT Bearer Token tại biên (Edge Authentication)
 4. Khống chế tần suất nhạy cảm (Sensitive Rate Limiting qua Redis 6379)
 5. Phân quyền Admin thô tại biên (/api/v1/admin/** -> 401/403)
 6. Kiểm tra & chuyển tiếp Idempotency-Key
 7. Lan truyền danh tính tin cậy (Identity Propagation Transform)
 8. Tự động bọc phong bì phản hồi chuẩn (ResponseEnvelopeMiddleware -> ApiResponse<T>)
═══════════════════════════════════════════════════════════════════════════
                               │
                               ▼  [Internal Network / Trusted Mesh Traffic]
 ┌────────────────────────────────────────────────────────────────────────┐
 │ [MICROSERVICES NHÂN - CORE] (Ports 8001 - 8009)                        │
 │ 1. Không giải mã lại JWT; đọc trực tiếp x-user-* từ HttpContext.Header │
 │ 2. Kiểm tra quyền sở hữu tài nguyên (Resource Ownership Authorization)  │
 │ 3. Thực thi nghiệp vụ thuần túy bằng 4-Layer Clean Architecture        │
 │ 4. Truy vấn CSDL độc lập qua DbContext (CẤM Repository / gRPC / Broker)│
 │ 5. Phân trang 100% tại SQL Query (Skip.Take, CountAsync -> PagedData<T>)│
 │ 6. Xác thực liên service cho /internal/* qua InternalServiceAuthMiddleware│
 │ 7. Trả về DTO nghiệp vụ thô (200/201) hoặc 204 NoContent                │
 │ 8. Trả mã lỗi RFC 9110, message Sentence-case tiếng Anh 100%           │
 └────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CÁC BẤT BIẾN TẠI API GATEWAY (EDGE GATEWAY INVARIANTS)

1. **Gateway là Edge Reverse Proxy thuần túy (Stateless Microsoft YARP v2.3.0)**:
   - Gateway chạy cố định tại cổng `8080`, 0 Database, 0 Domain Entities, 0 Mock Engine, 0 Stateful Logic.
   - Gateway chỉ định tuyến lưu lượng HTTP trực tiếp xuống 9 microservices nội bộ.
   - Gateway **TUYỆT ĐỐI KHÔNG BAO GIỜ** tính toán phân trang hoặc gom tập dữ liệu thô lớn trong RAM để tự cắt trang (tránh cạn kiệt bộ nhớ và tắc nghẽn mạng).

2. **Cơ chế Chặn Đứng Giả Mạo Danh Tính (Active Anti-Header-Spoofing Rejection)**:
   - `ClientContextMiddleware` tại Gateway chủ động quét toàn bộ request bên ngoài gửi lên (không phân biệt hoa thường).
   - Nếu client gửi bất kỳ header nào trong danh sách cấm:
     * `x-user-id`
     * `x-user-email`
     * `x-user-roles`
     * `x-user-role`
     * `x-user-permissions`
     * `x-user-permission`
     * `x-internal-service-key`
   - Gateway **NGẮT PIPELINE NGAY LẬP TỨC**, ghi log cảnh báo bảo mật kèm Client IP, và trả về HTTP `403 Forbidden`:
     ```json
     {
       "success": false,
       "statusCode": 403,
       "errorCode": "FORBIDDEN_HEADER_SPOOFING",
       "message": "Security violation: Untrusted identity header detected in external request.",
       "traceId": "0HNPGT7G285Q2",
       "timestamp": "2026-10-31T01:30:00Z"
     }
     ```
   - **Hệ quả kiến trúc**: Không một client bên ngoài nào có thể gửi header giả mạo tới backend services. Mọi header `x-user-*` đến service đều là header TIN CẬY 100% do Gateway xác thực và tiêm vào.

3. **Rào chắn cô lập Internal REST APIs (Strict Internal Route Isolation)**:
   - Gateway từ chối ngay lập tức mọi request bên ngoài có đường dẫn bắt đầu bằng `/api/v1/internal` hoặc chứa `/internal/` với HTTP `404 Not Found` (`errorCode: "NOT_FOUND"`).
   - Cấu hình YARP ReverseProxy (`Gateway/appsettings.json`) TUYỆT ĐỐI CẤM khai báo route cho bất kỳ đường dẫn nội bộ nào chứa `/internal/`.

4. **Cơ chế Lan Truyền Danh Tính Tin Cậy (Zero-Trust Identity Propagation)**:
   - Gateway giải mã token JWT Bearer tại biên, kiểm tra chữ ký với `Jwt:Signature`.
   - `IdentityPropagationTransform` trích xuất các claims và tiêm an toàn vào downstream request headers:
     * `x-user-id`: GUID định danh duy nhất của người dùng (từ claim `sub`, `userId`, hoặc `id`).
     * `x-user-email`: Email của người dùng (từ claim `email`).
     * `x-user-roles`: Chuỗi các vai trò viết thường, phân tách bằng dấu phẩy (ví dụ: `buyer`, `seller`, `admin`).
     * `x-user-permissions`: Chuỗi các quyền viết hoa, phân tách bằng dấu phẩy (ví dụ: `ORDER_CREATE,PRODUCT_MANAGE`).
     * `x-client-ip`: IP thực tế của client (sau khi đã validate).
     * `x-trace-id`: Mã truy vết phân tán W3C.

5. **Chuẩn hóa Phong Bì Phản Hồi Tự Động (Automatic Response Envelope)**:
   - `ResponseEnvelopeMiddleware` tại Gateway tự động bắt các phản hồi HTTP 200/201 thô dạng JSON từ downstream microservice và bọc thành phong bì chuẩn:
     ```json
     {
       "success": true,
       "statusCode": 200,
       "message": "Operation completed successfully.",
       "data": { ... },
       "traceId": "0HNPGT7G285Q2",
       "timestamp": "2026-10-31T01:30:00Z"
     }
     ```
   - **Quy tắc HTTP 204 NoContent**: Nếu thao tác là xóa hoặc không có dữ liệu trả về, microservice BẮT BUỘC trả về HTTP `204 NoContent` (`return NoContent();`). Gateway truyền thẳng luồng rỗng về client mà không bọc JSON.
   - **Quy tắc Chống Bọc Lồng (Idempotent Wrapping)**: Nếu phản hồi từ microservice đã có sẵn thuộc tính `success`, Gateway bỏ qua không bọc lại lần hai.

6. **Khống chế Tần Suất Tuyến Nhạy Cảm (Sensitive Rate Limiting)**:
   - Gateway áp dụng thuật toán Fixed-Window Rate Limiting qua Redis (`6379`) với key prefix `nexus:gateway:ratelimit:*`:
     * `POST /api/v1/auth/resend-otp`: 3 requests / 60s
     * `POST /api/v1/auth/verify-otp`: 5 requests / 60s
     * `POST /api/v1/auth/register`: 5 requests / 300s
     * `POST /api/v1/auth/login`: 10 requests / 60s
   - Backend UserService không cần tự viết thêm Rate Limiter cho các tuyến này.

7. **Phân Quyền Admin Thô Tại Biên (Coarse-Grained Admin Guard)**:
   - Gateway chặn đứng mọi request vào `/api/v1/admin/**` nếu client chưa xác thực (HTTP 401 `UNAUTHORIZED`) hoặc không có role `admin` / `staff` (HTTP 403 `FORBIDDEN`).

8. **Kiểm Tra & Chuyển Tiếp Khóa Idempotency (Idempotency Guard)**:
   - Gateway kiểm tra định dạng và độ dài của header `Idempotency-Key` (tối đa 128 ký tự) trên các phương thức `POST`, `PUT`, `PATCH` và chuyển tiếp an toàn xuống backend.

---

## 3. CÁC BẤT BIẾN TẠI BACKEND MICROSERVICES (CORE MICROSERVICE INVARIANTS)

1. **Kiến Trúc 4 Tầng Clean Architecture Thống Nhất**:
   - `{Service}.Domain`: Pure Domain Entities, Value Objects, Domain Enums, Domain Exceptions. Zero external library dependencies.
   - `{Service}.Application`: Use cases, Interface `I{Service}DbContext`, Request/Response records, typed client interfaces (`Interfaces/`).
   - `{Service}.Infrastructure`: Triển khai `AppDbContext`, EF Core Fluent Configurations, Migrations, Seeds, Typed HTTP Clients.
   - `{Service}.Api`: Thin Controllers (`Public/` & `Internal/`), Middlewares, Extensions, DI composition root (`Program.cs`).

2. **Feature Co-Location (Bắt buộc tại Application Layer)**:
   Toàn bộ mã nguồn của một tính năng phải đặt tập trung tại `{Service}.Application/Services/{Feature}/`:
   - `I{Feature}Service.cs`: Hợp đồng dịch vụ.
   - `{Feature}Service.cs`: Triển khai nghiệp vụ, inject trực tiếp `I{Service}DbContext`.
   - `{Feature}Requests.cs`: Các C# record request.
   - `{Feature}Responses.cs`: Các C# record response.
   - `{Feature}Dtos.cs` *(tùy chọn)*: Sub-DTOs nội bộ.

3. **Thin 1-to-1 Controller Pairing**:
   - Mỗi Controller kế thừa `ControllerBase`, chỉ inject DUY NHẤT một `I{Feature}Service`.
   - Tuyệt đối không query database, không chứa logic nghiệp vụ rẽ nhánh phức tạp tại Controller.
   - Dùng single-line XML `<summary>` trên mỗi action. Cấm viết multiline comment phân đoạn kẻ ngang.

4. **Năm Điều Cấm Kỵ Tuyệt Đối (Absolute Prohibitions)**:
   - 🛑 **CẤM Repository Pattern / Unit of Work bọc ngoài EF Core**: Inject trực tiếp `DbContext` và query `DbSet<T>`.
   - 🛑 **CẤM MediatR & CQRS tại tất cả service, TRỪ `WalletService`**: Logic đặt trong Feature Service, không chia tách Commands/Queries handlers. `WalletService` là ngoại lệ duy nhất: bắt buộc dùng classic CQRS qua MediatR với layout `Wallet.Application/Features/{Area}/Commands|Queries/{UseCase}/` và không có `I{Feature}Service` facade.
   - 🛑 **CẤM gRPC**: Toàn bộ giao tiếp đồng bộ là 100% RESTful HTTP/JSON.
   - 🛑 **CẤM Message Brokers (RabbitMQ, MassTransit, Saga, Outbox/Inbox tables)**: Toàn bộ giao tiếp liên service chuyển sang gọi đồng bộ bằng Typed HttpClient qua `IHttpClientFactory`.
   - 🛑 **CẤM truy vấn chéo cơ sở dữ liệu**: Mỗi service sở hữu database độc lập trên Neon Cloud.

5. **Phân Tách Public REST API và Internal Service REST API**:
   - Thư mục Controller tại `{Service}.Api/Controllers/` bắt buộc chia thành 2 thư mục con độc lập:
     * `Controllers/Public/`: Tiếp nhận lưu lượng từ Gateway (`/api/v1/{resources}`).
     * `Controllers/Internal/`: Tiếp nhận lưu lượng liên service trực tiếp (`/api/v1/internal/{resources}`).
   - Endpoint nội bộ bắt buộc kích hoạt `InternalServiceAuthMiddleware`, kiểm tra header `X-Internal-Service-Key` khớp với cấu hình `InternalSecurity:ServiceKey` (hoặc biến môi trường `INTERNAL_SERVICE_SECRET`). Thiếu hoặc sai key lập tức trả về HTTP 403 `FORBIDDEN`.
   - Outbound HttpClient gọi service khác (ví dụ: Catalog gọi Fulfillment khởi tạo kho, Commerce gọi Wallet thanh toán, User gọi Notification gửi OTP email) phải đăng ký kèm `InternalServiceAuthHandler` (DelegatingHandler) để tự động gắn header `X-Internal-Service-Key`.

6. **Quy Chuẩn Định Danh Route: 100% SỐ NHIỀU (100% Plural Route Convention)**:
   - Toàn bộ danh từ tài nguyên dùng danh từ số nhiều viết thường: `/api/v1/users`, `/api/v1/products`, `/api/v1/categories`, `/api/v1/carts`, `/api/v1/orders`, `/api/v1/shipments`, `/api/v1/wallets`, `/api/v1/auctions`, `/api/v1/notifications`, `/api/v1/logs`.
   - Ngoại lệ đơn lẻ (Contextual Singleton): `/api/v1/me` (hồ sơ của chính mình), `/api/v1/auth` (xác thực).
   - Tuyệt đối CẤM dùng route số ít dạng `/api/v1/cart`, `/api/v1/product`, `/api/v1/user`, `/api/v1/order`.
   - Tuyệt đối CẤM khai báo nhiều route attribute trên cùng một Action.

7. **Quy Chuẩn Phân Trang Tại Cơ Sở Dữ Liệu (Database-Level Pagination)**:
   - Microservice chịu trách nhiệm 100% tính toán phân trang qua `.Skip((page - 1) * pageSize).Take(pageSize)` và đếm `.CountAsync()`.
   - Đóng gói dữ liệu trả về theo cấu trúc `PagedData<T>`:
     ```json
     {
       "items": [ ... ],
       "pagination": {
         "pageIndex": 1,
         "pageSize": 20,
         "totalCount": 100,
         "totalPages": 5,
         "hasPreviousPage": false,
         "hasNextPage": true
       }
     }
     ```
   - Tuyệt đối CẤM trả danh sách thô lớn không giới hạn.

8. **Quy Chuẩn Thông Báo Lỗi Toàn Hệ Thống (RFC 9110 Error Standard)**:
   - Ngôn ngữ: 100% tiếng Anh. Tuyệt đối cấm tiếng Việt trong chuỗi thông báo trả về client.
   - Casing cho Error Message: Sentence case (chỉ viết hoa chữ cái đầu: `"User account not found."`).
   - Casing cho Error Code: `SCREAMING_SNAKE_CASE` (ví dụ: `USER_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `VAL_INVALID_INPUT`).
   - Model Binding Failure (Validation Filter): Mọi `{Service}.Api` bắt buộc đăng ký `ApiValidationProblemFactory` tại `{Service}.Api/Common/` qua `ConfigureApiBehaviorOptions(options => options.InvalidModelStateResponseFactory = ApiValidationProblemFactory.Create)` và trả `400 application/problem+json` với `errorCode = VAL_INVALID_INPUT`. Trường `detail` tuyệt đối CẤM chứa text exception hoặc tên type C# nội bộ; khi body không đọc được phải trả `"The request body is not valid."`. Kiểm chứng bằng `tools/probe_validation_contract.sh`.
   - Cấu trúc Error Response thống nhất:
     ```json
     {
       "success": false,
       "statusCode": 404,
       "errorCode": "USER_NOT_FOUND",
       "message": "User account not found for the specified identifier.",
       "traceId": "0HNPGT7G285Q2",
       "timestamp": "2026-10-31T01:30:00Z"
     }
     ```

9. **Quy Chuẩn Lưu Trữ và Tuần Tự Hóa Enum (Enum Persistence & Serialization)**:
   - Trong PostgreSQL: 100% Enum lưu dưới dạng số nguyên `integer` (int32). CẤM dùng `HasConversion<string>()` hay custom enum types.
   - Trong C#: 100% dùng strongly-typed enum kế thừa kiểu ngầm định `int`.
   - JSON Output: Bắt buộc tuần tự hóa thành chuỗi PascalCase qua `PascalCaseJsonStringEnumConverter` (`"Active"`, `"Pending"`).
   - JSON Input: Chấp nhận chuỗi PascalCase hoặc `SCREAMING_SNAKE_CASE`. CẤM nhận số nguyên thô (`allowIntegerValues: false`).

---

## 4. MA TRẬN PHÂN CẤP ĐỘ TIN CẬY CỦA HEADERS (HEADER TRUST MATRIX)

| Header HTTP | Nguồn Gửi (Origin) | Gateway Xử Lý | Microservice Xử Lý | Mức Độ Tin Cậy |
|:---|:---|:---|:---|:---:|
| `Authorization` | Client ngoài | Xác thực chữ ký JWT; nếu hợp lệ thì giải mã claims | Bỏ qua; không cần xác thực lại | ⭐⭐⭐⭐⭐ (Sau khi Gateway verify) |
| `x-user-id` | Client ngoài | 🛑 CHẶN ĐỨNG VÀ TRẢ 403 `FORBIDDEN_HEADER_SPOOFING` | Không thể đến được Microservice | ❌ KHÔNG TIN CẬY |
| `x-user-id` | Gateway tiêm | Tiêm từ claim `sub` / `userId` của token JWT hợp lệ | Đọc trực tiếp qua `this.GetUserId()` | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `x-user-email` | Gateway tiêm | Tiêm từ claim `email` của token JWT hợp lệ | Đọc trực tiếp qua `this.GetUserEmail()` | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `x-user-roles` | Gateway tiêm | Tiêm từ claims `role` / `roles` của token JWT hợp lệ | Đọc trực tiếp qua `this.GetUserRoles()` / `HasRole()` | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `x-user-permissions` | Gateway tiêm | Tiêm từ claims `permission`/`permissions` | Đọc trực tiếp qua `this.GetUserPermissions()` | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `x-client-ip` | Gateway tiêm | Ghi đè bằng IP kết nối thực tế từ RemoteIpAddress | Đọc nếu cần audit trail | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `x-trace-id` | Gateway tiêm | Sinh mã W3C TraceId nếu thiếu, gắn vào response | Ghi log OpenTelemetry / Tempo | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `X-Internal-Service-Key` | Client ngoài | 🛑 CHẶN ĐỨNG VÀ TRẢ 403 `FORBIDDEN_HEADER_SPOOFING` | Không thể đến được Microservice | ❌ KHÔNG TIN CẬY |
| `X-Internal-Service-Key` | Service gọi | Bỏ qua (không qua Gateway) | `InternalServiceAuthMiddleware` kiểm tra khớp secret key | ⭐⭐⭐⭐⭐ TIN CẬY 100% |
| `Idempotency-Key` | Client ngoài | Validate độ dài <= 128 chars, chuyển tiếp | Đọc kiểm tra duplicate transaction | ⭐⭐⭐⭐ ĐƯỢC CHỨNG THỰC |

---

## 5. MA TRẬN ĐÓNG GÓI PHẢN HỒI VÀ MÃ TRẠNG THÁI (RESPONSE ENVELOPE MATRIX)

| HTTP Status | Thao Tác Nghiệp Vụ | Dạng Dữ Liệu Microservice Trả Về | Gateway Xử Lý Đóng Gói | Kết Quả Client Nhận Được |
|:---:|:---|:---|:---|:---|
| **200 OK** | Đọc dữ liệu thành công (Query) | DTO thô JSON (ví dụ `UserProfileDto`) | Bọc vào `ApiResponse<T>` với `success: true` | `ApiResponse<UserProfileDto>` |
| **200 OK** | Phân trang danh sách | `PagedData<T>` thô | Bọc vào `ApiResponse<PagedData<T>>` | `ApiResponse<PagedData<T>>` |
| **201 Created** | Tạo mới tài nguyên thành công | DTO thô của entity vừa tạo | Bọc vào `ApiResponse<T>` với `success: true` | `ApiResponse<T>` |
| **204 NoContent** | Xóa hoặc cập nhật không cần body | `return NoContent();` (Body rỗng) | **Truyền thẳng (Passthrough) rỗng** | `HTTP 204 NoContent` (0 byte) |
| **400 BadRequest** | Dữ liệu đầu vào sai validation | ProblemDetails / JSON có `errorCode` | Giữ nguyên để `GlobalException` chuẩn hóa | `ApiErrorResponse` (`success: false`) |
| **401 Unauthorized**| Token JWT thiếu hoặc hết hạn | Bị chặn ngay tại Gateway Authentication | Gateway trả về trực tiếp | `ApiErrorResponse` (`UNAUTHORIZED`) |
| **403 Forbidden** | Không đủ quyền hoặc Header Spoofing | Bị chặn tại Gateway Guard hoặc Microservice | Trả về mã `FORBIDDEN` | `ApiErrorResponse` (`FORBIDDEN`) |
| **404 NotFound** | Không tìm thấy tài nguyên | ProblemDetails với `errorCode` | Giữ nguyên body lỗi | `ApiErrorResponse` (`*_NOT_FOUND`) |
| **409 Conflict** | Trùng lặp dữ liệu (Email, Username) | ProblemDetails với `errorCode` | Giữ nguyên body lỗi | `ApiErrorResponse` (`*_EXISTS`) |
| **500 ServerError** | Lỗi ngoại lệ chưa xử lý | Exception phát sinh trong code | Bắt bởi Global Exception Handler | `ApiErrorResponse` (`INTERNAL_SERVER_ERROR`) |

---

## 6. DANH MỤC CỔNG MẠNG VÀ CƠ SỞ DỮ LIỆU ĐỘC LẬP (TOPOLOGY MAPPING)

| Service | Port REST | Database Host:Port | Database Name | Trách Nhiệm Miền Nghiệp Vụ |
|:---|:---:|:---:|:---|:---|
| **Gateway** | `8080` | None (0 DB) | None | Edge Reverse Proxy, YARP Streaming, Anti-Spoofing, Identity Propagation |
| **UserService** | `8001` | `5433` | `usermanagement_db` | Xác thực, định danh người dùng, phát hành JWT, phân quyền RBAC |
| **CatalogService** | `8002` | `5434` | `category_db` | Cây danh mục, sản phẩm, biến thể SKU, kho ảo của seller |
| **CommerceService** | `8003` | `5435` | `commerce_db` | Giỏ hàng, đơn hàng, thanh toán đơn, sub-orders |
| **LogService** | `8004` | `5436` | `log_db` | Nhật ký hệ thống tập trung, kiểm toán bất biến (Append-only) |
| **AuctionService** | `8005` | `5437` | `auction_db` | Phòng đấu giá, bước giá, lịch sử đặt giá (Bids), chốt phiên |
| **FulfillmentService** | `8006` | `5438` | `fulfillment_db` | Kho bãi vật lý thực tế, tồn kho thực tế, vận đơn và theo dõi giao nhận |
| **NotificationService**| `8007` | `5439` | `notification_db` | Đa kênh thông báo (In-app, Push, Email), lưu lịch sử, gửi OTP email |
| **WalletService** | `8008` | `5440` | `wallet_db` | Ví điện tử, nạp tiền VNPay, rút tiền ngân hàng, trừ tiền thanh toán |
| **CheckHealService** | `8009` | None (Prober) | In-Memory Telemetry | Giám sát trạng thái hoạt động và keep-alive toàn bộ hệ sinh thái |
| **Hạ Tầng Chung** | Redis: `6379`, Tempo: `3200`, Prometheus: `9090`, Grafana: `3000` | Quản lý độc quyền tại `./infra/` và `docker-compose.yml` |

---

## 7. QUY TRÌNH KIỂM CHỨNG BẮT BUỘC (MANDATORY DEFINITION OF DONE)

Một tác vụ phát triển hoặc refactor bất kỳ chỉ được coi là hoàn tất khi:
1. **Lập Kế Hoạch Trước Khi Làm (Plan-First Rule)**: Ghi nhận plan chi tiết tại `.agents/plan/PLAN-*.md`.
2. **Tuân thủ Phạm Vi Một Chiều (Inward-Only Scoping)**: 100% self-contained bên trong submodule đó.
3. **Biên dịch Thành Công Tuyệt Đối**: `dotnet build <Solution>.sln -c Release` đạt 0 lỗi, 0 cảnh báo.
4. **Kiểm thử Vượt Qua 100%**: `dotnet test <Solution>.sln -c Release` đạt tỷ lệ vượt qua 100%.
5. **Cập nhật Hồ Sơ Tài Liệu API**: Tạo hoặc cập nhật file tài liệu tương ứng tại `docs/api/B_none/` hoặc `docs/api/A_Active/` theo mẫu `API_DOC_TEMPLATE.md` với đầy đủ Error Matrix.
