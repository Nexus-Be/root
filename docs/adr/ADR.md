# HỆ THỐNG QUYẾT ĐỊNH KIẾN TRÚC TOÀN HỆ THỐNG (SYSTEM ARCHITECTURE DECISION RECORDS)
## Dự án: Nexus Microservices Ecosystem (.NET 8)

> **Trạng thái tài liệu:** Đã phê duyệt (Approved) & Có hiệu lực trên toàn hệ thống  
> **Áp dụng cho:** ApiGateway và toàn bộ 8 Microservices (`UserService`, `CatalogService`, `CommerceService`, `LogService`, `AuctionService`, `FulfillmentService`, `NotificationService`, `WalletService`)  
> **Nguồn lưu trữ trung tâm:** `docs/adr/ADR.md` (Thư mục gốc của repository)  
> **Cập nhật kiến trúc chiến lược:** 2026-10-27 — Chuyển dịch toàn diện sang 100% RESTful HTTP/JSON cho giao tiếp đồng bộ, loại bỏ hoàn toàn gRPC.

---

## MỤC LỤC DANH MỤC ADR

| Mã ADR | Tiêu Đề Quyết Định | Trạng Thái |
|:---:|:---|:---:|
| **ADR 01** | Nền tảng công nghệ cốt lõi: .NET 8 (C# 12) toàn hệ sinh thái | `Approved` |
| **ADR 02** | Mô hình kiến trúc phân tán Microservices & Edge API Gateway mỏng | `Approved` |
| **ADR 03** | Ranh giới miền nghiệp vụ (DDD Bounded Contexts) & Database-Per-Service | `Approved` |
| **ADR 04** | Cấu trúc mã nguồn Clean Architecture 4 tầng chuẩn mực cho Microservices | `Approved` |
| **ADR 05** | Nguyên tắc No-Repository Pattern bọc ngoài Entity Framework Core 8 | `Approved` |
| **ADR 06** | Hai trục giao tiếp liên service: RESTful HTTP/JSON (Đồng bộ) & RabbitMQ (Bất đồng bộ) — CẤM gRPC | `Approved` |
| **ADR 07** | Chuẩn hóa hợp đồng dữ liệu RESTful DTOs & Đóng gói JSON — Thay thế Protobuf | `Approved` |
| **ADR 08** | Điều phối giao dịch phân tán bằng Saga State Machine & Transactional Outbox | `Approved` |
| **ADR 09** | Kiến trúc 3 khối cho API Gateway & Bộ điều phối Mock/Real thông minh (REST Downstream) | `Approved` |
| **ADR 10** | Hai trục trạng thái Gateway: Service Mode (Mock/Real) vs Auth Mode (Standard/Bypass) | `Approved` |
| **ADR 11** | Chiến lược bảo mật JWT Bearer & Ma trận phân quyền vai trò RBAC 5 cấp bậc | `Approved` |
| **ADR 12** | Giới hạn tần suất gọi phân tán (Distributed Rate Limiting) bằng Redis với Fail-Open | `Approved` |
| **ADR 13** | Quy chuẩn đóng gói phản hồi (Unified Response Envelope) & Zero-Validation Controller | `Approved` |
| **ADR 14** | Giám sát phân tán (Distributed Tracing & Observability) với OpenTelemetry W3C | `Approved` |
| **ADR 15** | Tương thích ngược đường dẫn URL Gateway (Transparent Route Rewrite) | `Approved` |

---

## CHI TIẾT CÁC QUYẾT ĐỊNH KIẾN TRÚC

---

### ADR 01: Nền tảng công nghệ cốt lõi: .NET 8 (C# 12) toàn hệ sinh thái

#### 1. Ngữ cảnh & Vấn đề (Context)
Hệ thống Nexus là sàn thương mại điện tử kết hợp đấu giá trực tuyến quy mô lớn, đòi hỏi thông lượng cao, độ trễ thấp và khả năng scale linh hoạt. Cần một nền tảng công nghệ đồng nhất cho cả Gateway và 8 Microservices để tối ưu hóa chi phí phát triển, chia sẻ mã nguồn hợp đồng và tối đa hóa hiệu năng runtime.

#### 2. Quyết định kiến trúc (Decision)
- Toàn bộ Gateway và các microservices sử dụng thống nhất **.NET 8 LTS** với ngôn ngữ **C# 12**.
- Tận dụng các tính năng mới nhất của .NET 8: Tối ưu hóa I/O với Kestrel HTTP/1.1 & HTTP/2 pooling, System.Text.Json source generation, TimeProvider, ASP.NET Core MVC & Minimal APIs, OpenTelemetry native instrumentation.

#### 3. Hệ quả (Consequences)
- **Tích cực:** Tối ưu hóa hiệu năng I/O; đội ngũ kỹ thuật chỉ cần làm chủ một stack duy nhất; dễ dàng chia sẻ contracts và tooling CI/CD.
- **Tiêu cực:** Đòi hỏi môi trường runtime máy chủ/container cài đặt .NET 8 SDK / Runtime đồng nhất.

---

### ADR 02: Mô hình kiến trúc phân tán Microservices & Edge API Gateway mỏng

#### 1. Ngữ cảnh & Vấn đề (Context)
Nếu để Client (Web Next.js / Mobile App) gọi trực tiếp vào từng microservice nội bộ:
- Phức tạp hóa việc xác thực, phân quyền, CORS, và rate limiting tại từng service.
- Client phải quản lý nhiều domain, nhiều địa chỉ IP/port khác nhau.
- Khó thay đổi hoặc tái cấu trúc backend mà không làm ảnh hưởng đến client.

#### 2. Quyết định kiến trúc (Decision)
- Xây dựng **1 Edge API Gateway duy nhất** (`ApiGateway` - HTTP Port `8000`) làm cổng tiếp nhận duy nhất cho toàn bộ lưu lượng ngoại vi từ Client.
- Gateway là **Thin Edge Reverse Proxy**:
  - Chỉ đảm nhận các trách nhiệm hạ tầng: Định tuyến (Routing), Chuyển tiếp REST downstream sang các backend microservices, Xác thực JWT, Kiểm tra quyền RBAC, Rate Limiting phân tán, Điều phối Mock/Real.
  - **Tuyệt đối KHÔNG chứa cơ sở dữ liệu nghiệp vụ**, không lưu trữ in-memory stateful data của các service khác.
- Phía sau Gateway là **8 Backend Microservices độc lập**: `UserService` (8001), `CatalogService` (8002), `CommerceService` (8003), `LogService` (8004), `AuctionService` (8005), `FulfillmentService` (8006), `NotificationService` (8007), `WalletService` (8008).

#### 3. Hệ quả (Consequences)
- **Tích cực:** Toàn bộ backend ẩn an toàn trong mạng nội bộ; client chỉ thấy một API endpoint duy nhất `/api/v1/...`; Gateway nhẹ, tải nhanh và dễ scale.
- **Tiêu cực:** Gateway là điểm chịu tải trung tâm (Single Entry Point), cần đảm bảo tính sẵn sàng cao và cấu hình Rate Limiting để chống DoS.

---

### ADR 03: Ranh giới miền nghiệp vụ (DDD Bounded Contexts) & Database-Per-Service

#### 1. Ngữ cảnh & Vấn đề (Context)
Các hệ thống microservices thường gặp thất bại lớn nếu dùng chung một cơ sở dữ liệu (Shared Database), dẫn đến việc coupling dữ liệu chặt chẽ, tranh chấp transaction, và không thể mở rộng hoặc triển khai độc lập.

#### 2. Quyết định kiến trúc (Decision)
- Áp dụng triệt để nguyên tắc **Domain-Driven Design (DDD) Bounded Contexts** và **Database-Per-Service**:
  - Mỗi microservice sở hữu cơ sở dữ liệu **PostgreSQL vật lý riêng biệt** trên Neon Cloud hoặc port riêng biệt (`5433` đến `5440`).
  - **CẤM TUYỆT ĐỐI:** Truy cập trực tiếp vào DB của service khác (cấm cross-database query, cấm tạo foreign key trỏ sang DB khác).
  - Mọi trao đổi hoặc tra cứu dữ liệu liên service bắt buộc phải qua **RESTful API Query** (đồng bộ) hoặc **Domain Event qua RabbitMQ** (bất đồng bộ).

#### 3. Phân bổ Database vật lý:
| Service | Bounded Context | Tên DB | Port DB Local |
|:---|:---|:---|:---:|
| `UserService` | Identity & Access Management | `usermanagement_db` | `5433` |
| `CatalogService` | Product & Inventory Catalog | `catalog_db` | `5434` |
| `CommerceService` | Shopping Cart & Order Lifecycle | `commerce_db` | `5435` |
| `LogService` | Centralized Logging & System Auditing | `log_db` | `5436` |
| `AuctionService` | Real-time Bidding & Auction Room | `auction_db` | `5437` |
| `FulfillmentService` | Logistics, Warehouses & Delivery | `fulfillment_db` | `5438` |
| `NotificationService` | Multi-channel Messaging & Alerts | `notification_db` | `5439` |
| `WalletService` | Digital Wallet, Balance & Transfers | `wallet_db` | `5440` |

---

### ADR 04: Cấu trúc mã nguồn Clean Architecture 4 tầng chuẩn mực cho Microservices

#### 1. Ngữ cảnh & Vấn đề (Context)
Cần một cấu trúc dự án chuẩn tắc cho toàn bộ 8 Microservices để đảm bảo code dễ bảo trì, tách bạch rõ ràng logic nghiệp vụ khỏi chi tiết kỹ thuật hạ tầng (DB, Message Bus, External API), và hỗ trợ viết Unit Test dễ dàng.

#### 2. Quyết định kiến trúc (Decision)
Mỗi microservice trong `src/Services/{ServiceName}/` được tổ chức thành đúng 4 projects theo **Clean Architecture (Onion Architecture)**:
```
[ ServiceName.sln ]
├── 1. ServiceName.Domain           (Entities, Value Objects, Domain Events, Enums)
├── 2. ServiceName.Application      (Commands, Queries, DTOs, Validators, Interfaces)
├── 3. ServiceName.Infrastructure   (DbContext, EF Core Configurations, MassTransit Consumers)
└── 4. ServiceName.Api              (RESTful Controllers, Endpoints, DI Configuration, Middlewares)
```
- **Quy tắc phụ thuộc bất biến (Dependency Inversion Principle):**
  - `Domain` độc lập 100%, không tham chiếu bất kỳ project nào khác.
  - `Application` chỉ tham chiếu `Domain`.
  - `Infrastructure` tham chiếu `Application` và `Domain`.
  - `Api` tham chiếu `Infrastructure`, `Application`, `Domain`.
  - **Tuyệt đối cấm** `Domain` hoặc `Application` phụ thuộc ngược vào `Infrastructure` hoặc `Api`.

---

### ADR 05: Nguyên tắc No-Repository Pattern bọc ngoài Entity Framework Core 8

#### 1. Ngữ cảnh & Vấn đề (Context)
Một anti-pattern rất phổ biến trong cộng đồng .NET là viết thêm một lớp `GenericRepository<T>` và `IUnitOfWork` bọc ngoài Entity Framework Core. Điều này dẫn đến che khuất các tính năng mạnh mẽ của EF Core (`IQueryable`, `AsNoTracking()`, `Include()`) và tạo ra hàng chục file wrapper vô nghĩa.

#### 2. Quyết định kiến trúc (Decision)
- **CẤM TUYỆT ĐỐI:** Tạo các lớp `GenericRepository<T>`, `IRepository<T>`, `IUnitOfWork` bọc ngoài EF Core.
- Tại tầng `Application`: Sử dụng trực tiếp `DbContext` (hoặc interface `IApplicationDbContext`) và `DbSet<T>` để truy vấn và lưu trữ dữ liệu.
- Tận dụng triệt để Linq, Change Tracker, Execution Strategy và asynchronous API của EF Core 8.

---

### ADR 06: Hai trục giao tiếp liên service: RESTful HTTP/JSON (Đồng bộ) & RabbitMQ (Bất đồng bộ) — CẤM gRPC

#### 1. Ngữ cảnh & Vấn đề (Context)
Việc sử dụng gRPC trước đây gây ra rào cản nghiêm trọng trong quá trình phát triển phân tán: 5/9 microservices không có gRPC server, file `shop.proto` bị lệch hash/drift, việc sinh mã phức tạp và khó khăn khi debug bằng cURL/Postman thông thường. Cần một tiêu chuẩn giao tiếp đơn giản, chuẩn mực, phổ quát và dễ dàng kiểm thử độc lập.

#### 2. Quyết định kiến trúc (Decision)
Phân định dứt khoát 2 kênh giao tiếp:
1. **Giao tiếp Đồng bộ (Synchronous Query/Command) qua RESTful HTTP/JSON**:
   - **BẮT BUỘC 100%**: Toàn bộ giao tiếp đồng bộ từ ApiGateway xuống Microservices và giữa các Microservices với nhau sử dụng chuẩn **RESTful Web API** (JSON qua HTTP/1.1 hoặc HTTP/2).
   - **CẤM TUYỆT ĐỐI**: Triển khai hoặc sử dụng gRPC Server/Client cho các dịch vụ đồng bộ trong toàn bộ hệ thống.
   - Định dạng dữ liệu: JSON chuẩn `camelCase`, phân trang qua query parameters, phản hồi bọc thống nhất trong `ApiResponse<T>`.
2. **Giao tiếp Bất đồng bộ (Asynchronous Event-Driven) qua RabbitMQ & MassTransit 8.3.0**:
   - Dành cho:
     - Các sự kiện trạng thái thay đổi (Domain Events): `OrderSubmittedEvent`, `SendOtpEmailIntegrationEvent`, v.v.
     - Kích hoạt các luồng xử lý phi tập trung không chặn người dùng (gửi email thông báo, ghi log hệ thống).
     - Điều phối quy trình nghiệp vụ phức tạp liên service qua Saga State Machine & Transactional Outbox.

---

### ADR 07: Chuẩn hóa hợp đồng dữ liệu RESTful DTOs & Đóng gói JSON — Thay thế Protobuf

#### 1. Ngữ cảnh & Vấn đề (Context)
Tệp Protobuf nhị phân cũ gây phụ thuộc chéo giữa các service, khó duy trì tính tương thích ngược và thường xuyên bị out-of-sync khi nhiều team cùng làm việc.

#### 2. Quyết định kiến trúc (Decision)
- **Loại bỏ hoàn toàn các tệp Protobuf (`*.proto`)**: Toàn bộ các file `shop.proto` bị xóa bỏ khỏi Gateway và các microservices.
- **Nguồn sự thật hợp đồng RESTful DTOs**:
  - Tại Gateway: `src/Services/ApiGateway/Nexus.Gateway/Dtos/{Service}/`
  - Tại Microservice: `src/Services/{Service}/{Service}.Application/DTOs/` hoặc `Api/Controllers/`
- **Quy chuẩn Casing & Kiểu Dữ Liệu**:
  - JSON API: `camelCase`.
  - C# DTO: `PascalCase`.
  - Enums: Serialize dạng chuỗi (`JsonStringEnumConverter`) hoặc số nguyên tương ứng.
  - Mọi phản hồi thành công bọc trong `ApiResponse<T>`, phản hồi danh sách bọc trong `ApiResponse<PagedData<T>>`, lỗi bọc trong `ApiErrorResponse` chuẩn RFC 9110.

---

### ADR 08: Điều phối giao dịch phân tán bằng Saga State Machine & Transactional Outbox

#### 1. Ngữ cảnh & Vấn đề (Context)
Quy trình nghiệp vụ Checkout đòi hỏi sự tham gia của 4 service: `CommerceService` (tạo đơn) $\rightarrow$ `CatalogService` (giữ kho) $\rightarrow$ `WalletService` (trừ tiền) $\rightarrow$ `FulfillmentService` (tạo vận đơn). Vì mỗi service dùng một DB riêng biệt, không thể dùng ACID transaction thông thường.

#### 2. Quyết định kiến trúc (Decision)
1. **Saga State Machine với Giao dịch bù trừ (Compensating Transactions):**
   - Áp dụng **Commerce Saga State Machine** quản lý vòng đời đơn hàng: `PENDING` $\rightarrow$ `STOCK_RESERVED` $\rightarrow$ `PAID` $\rightarrow$ `COMPLETED`.
   - Nếu bất kỳ bước nào thất bại, hệ thống tự động kích hoạt sự kiện bù trừ (`ReleaseStock`, `PaymentFailedEvent`, `CANCELLED`).
2. **Transactional Outbox & Inbox Pattern (MassTransit):**
   - Mọi service khi lưu dữ liệu DB phải ghi event vào bảng `OutboxMessage` trong cùng một Local Transaction.
   - Background worker tự động đọc Outbox và phát lên RabbitMQ $\rightarrow$ Đảm bảo không bao giờ mất message (At-least-once delivery).
   - Phía Consumer sử dụng bảng `InboxMessage` dựa trên `MessageId` để đảm bảo tính Idempotent.

---

### ADR 09: Kiến trúc 3 khối cho API Gateway & Bộ điều phối Mock/Real thông minh (REST Downstream)

#### 1. Ngữ cảnh & Vấn đề (Context)
Trong quá trình phát triển, các team frontend và backend thường phát triển song song. Gateway cần khả năng phục vụ độc lập dữ liệu Mock mà không cần sửa code controller khi backend sẵn sàng.

#### 2. Quyết định kiến trúc (Decision)
Gateway được thiết kế theo **mô hình 3 khối phân tách hoàn toàn (3-Tier Decoupling)**:
1. **Khối Đầu Vào (Input - Controllers):**
   - Các controller RESTful chuẩn mực (`[ApiController]`), kế thừa `GatewayBaseController`.
   - Dùng các helper `ForwardAsync`, `ForwardPagedAsync`, `ForwardNoContentAsync` để ủy quyền điều phối.
   - **Tuyệt đối không chứa logic `if (mode == "Mock")`**.
2. **Khối Điều Phối Trung Tâm (Dispatching Core - GatewayDispatcher):**
   - `ModeEvaluator`: Tự động nhận diện Service Mode (`Mock` hay `Real`) từ cấu hình hoặc request header.
   - **Nếu Mode = Mock:** `MockDataMapper` nạp file fixture JSON tương ứng trong `Seeds/{service}/{operation}.json`, trả về dữ liệu mẫu trong trường `data`.
   - **Nếu Mode = Real:** `HttpBackendCaller` tự động chuyển tiếp request HTTP REST downstream (`HttpClient`) xuống địa chỉ backend tương ứng (port `8001`-`8008`), chuyển tiếp kèm token JWT, Idempotency-Key và TraceId.
3. **Khối Đầu Ra (Output - ApiResponseFactory):**
   - Đóng gói dữ liệu thành envelope chuẩn `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`.

---

### ADR 10: Hai trục trạng thái Gateway: Service Mode vs Auth Mode

#### 1. Ngữ cảnh & Vấn đề (Context)
Frontend cần khả năng test API bằng mock data độc lập trong khi backend khác chạy thật, đồng thời muốn test giao diện UI mà không cần đăng nhập tạo token.

#### 2. Quyết định kiến trúc (Decision)
Tách biệt Gateway thành **2 trục trạng thái độc lập hoàn toàn**:
1. **Trục 1: Service Mode (`Mock` vs `Real`):**
   - Cấu hình riêng biệt cho từng service trong `gateway.runtime.json`:
     `"Gateway:Services:catalog:Mode": "Mock"`, `"Gateway:Services:users:Mode": "Real"`.
   - Có thể thay đổi runtime qua API quản trị `/api/v1/gateway/modes/{service}` hoặc override qua header `X-Service-Mode-{service}` (trong môi trường Development).
2. **Trục 2: Auth Mode (`Standard` vs `Bypass`):**
   - `Standard` (Mặc định): Bắt buộc xác thực JWT và kiểm tra phân quyền RBAC nghiêm ngặt (chặn 401/403).
   - `Bypass` (Chỉ cho phép trong Development): Cho phép gọi các mock API không cần token, Gateway tự động cấp danh tính giả lập để test UI.
   - **Quy tắc an toàn bất biến:** Các endpoint quản trị Gateway (`/api/v1/gateway/...` và `/api/v1/mock-engine/...`) được gắn thuộc tính `[DisableMockAuthorizationBypass]`, **tuyệt đối không cho phép bypass**, bắt buộc phải có token thật với vai trò `gateway-admin`.

---

### ADR 11: Chiến lược bảo mật JWT Bearer & Ma trận phân quyền vai trò RBAC 5 cấp bậc

#### 1. Ngữ cảnh & Vấn đề (Context)
Hệ thống cần quản lý chặt chẽ ranh giới bảo mật giữa người dùng vãng lai, khách mua hàng, người bán hàng, nhân viên vận hành và quản trị viên.

#### 2. Quyết định kiến trúc (Decision)
- **Token Format:** JWT Bearer Token chuẩn RFC 7519, ký HMAC-SHA256 bởi `UserService`.
- **Chuyển tiếp danh tính (Identity Propagation):** Gateway sau khi xác thực token sẽ forward nguyên vẹn header `Authorization: Bearer <token>` cùng các HTTP headers định danh (`x-user-id`, `x-user-roles`, `x-user-email`) sang HTTP REST request downstream xuống backend.
- **Ma trận phân quyền RBAC 5 cấp bậc có tính kế thừa:**
  1. `anonymous` (Cấp 0): Khách vãng lai, chỉ được xem danh mục, sản phẩm, đăng ký, đăng nhập.
  2. `buyer` / `authenticated` (Cấp 1): Khách hàng đăng nhập, quản lý giỏ hàng, đặt hàng, ví tiền, đấu giá.
  3. `seller` (Cấp 2 - Kế thừa `buyer`): Người bán hàng đã duyệt, đăng bán sản phẩm, chỉnh kho, tạo phiên đấu giá.
  4. `staff` (Cấp 3 - Kế thừa `buyer`): Nhân viên vận hành sàn, xét duyệt seller, xem toàn bộ đơn sàn, xem nhật ký hệ thống (/log/logs).
  5. `admin` (Cấp 4 - Kế thừa `staff`, `seller`, `buyer`): Quản trị viên hệ thống, quản lý tài khoản, gán role, cấu hình danh mục.
  - *Riêng biệt:* `gateway-admin` (Quản trị viên hạ tầng kỹ thuật Gateway, quản lý mode runtime và mock engine).

---

### ADR 12: Giới hạn tần suất gọi phân tán (Distributed Rate Limiting) bằng Redis với Fail-Open

#### 1. Ngữ cảnh & Vấn đề (Context)
Cần bảo vệ toàn bộ cụm Microservices khỏi tấn công từ chối dịch vụ (DoS), brute-force đăng nhập và spam đặt hàng, đồng thời không làm nghẽn môi trường lập trình local khi Redis chưa bật.

#### 2. Quyết định kiến trúc (Decision)
- Áp dụng **Sliding Window Rate Limiting** bằng Redis tại Gateway (`StackExchange.Redis`).
- Phân chia hạn ngạch (Rate Limit Quotas):
  - `Default API`: 100 requests / phút / IP.
  - `Auth / Login / Register / OTP`: 10 requests / phút / IP.
  - `Order / Checkout`: 20 requests / phút / User ID.
- **Chính sách Fail-Open an toàn cho Developer:**
  - Nếu Redis offline hoặc mất kết nối trong môi trường `Development`, Gateway ghi nhận cảnh báo `LogWarning` và tự động cho request đi qua (không chặn 500/503), giúp quá trình lập trình diễn ra mượt mà.

---

### ADR 13: Quy chuẩn đóng gói phản hồi (Unified Response Envelope) & Zero-Validation Controller

#### 1. Ngữ cảnh & Vấn đề (Context)
Frontend cần cấu trúc JSON đồng nhất 100% trên toàn bộ các endpoints để xây dựng Interceptor xử lý lỗi và trích xuất dữ liệu tự động, tránh việc mỗi endpoint trả một kiểu dữ liệu khác nhau.

#### 2. Quyết định kiến trúc (Decision)
- **Chuẩn phản hồi thành công:**
  ```json
  {
    "success": true,
    "statusCode": 200,
    "message": "Operation completed successfully.",
    "data": { ... },
    "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  }
  ```
- **Chuẩn phản hồi danh sách phân trang:**
  ```json
  {
    "success": true,
    "statusCode": 200,
    "message": "Data retrieved successfully.",
    "data": {
      "items": [ ... ],
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    },
    "traceId": "..."
  }
  ```
- **Chuẩn phản hồi lỗi (RFC 9110 / ProblemDetails):**
  - Toàn bộ thông báo lỗi viết bằng **100% Tiếng Anh, Sentence case**.
  - Mã lỗi viết dạng **SCREAMING_SNAKE_CASE** (ví dụ: `EMAIL_ALREADY_EXISTS`, `INVALID_CREDENTIALS`).
  - `GatewayExceptionHandler` trung tâm tự động bắt `GatewayInputException`, `HttpRequestException`, `TimeoutException` và map sang mã HTTP cùng envelope lỗi chuẩn xác.

---

### ADR 14: Giám sát phân tán (Distributed Tracing & Observability) với OpenTelemetry W3C

#### 1. Ngữ cảnh & Vấn đề (Context)
Trong hệ thống phân tán gồm 1 Gateway và 8 Microservices giao tiếp qua RESTful HTTP và RabbitMQ, việc truy tìm nguyên nhân gốc rễ (Root Cause) khi một request bị chậm hoặc lỗi là cực kỳ khó khăn nếu không có mã truy vết xuyên suốt.

#### 2. Quyết định kiến trúc (Decision)
- Sử dụng chuẩn **W3C TraceContext** và **OpenTelemetry (OTel)**.
- Khi request đi vào Gateway, `ApiResponseFactory.ResolveTraceId` sẽ phát hành hoặc tái sử dụng `TraceIdentifier` làm `TraceId` duy nhất.
- `TraceId` này được gắn vào:
  - Header phản hồi HTTP `X-Trace-Id` gửi về cho Client.
  - Trường `traceId` trong JSON body của cả phản hồi Success và Error.
  - Header HTTP downstream `X-Trace-Id` và `traceparent` chuyển tiếp xuống các microservices backend.
  - Header của các message Event bắn lên RabbitMQ.
- Cho phép tra cứu một giao dịch từ Frontend $\rightarrow$ Gateway $\rightarrow$ Backend REST $\rightarrow$ RabbitMQ Consumer trên các hệ thống giám sát tập trung (Jaeger, Prometheus, Grafana).

---

### ADR 15: Tương thích ngược đường dẫn URL Gateway (Transparent Route Rewrite)

#### 1. Ngữ cảnh & Vấn đề (Context)
Trước đây hệ thống sử dụng tiền tố `/gateway/api/v1/...`, sau đó được nâng cấp sang chuẩn RESTful ngắn gọn và chuyên nghiệp hơn: `/api/v1/...`. Cần giải pháp hỗ trợ đồng thời cả hai mà không phải duplicate code trong controller.

#### 2. Quyết định kiến trúc (Decision)
- Toàn bộ Controller khai báo route chuẩn mới: `[Route("api/v1/...")]`.
- Bổ sung middleware **Transparent URL Rewrite** ngay đầu pipeline của Gateway:
  ```csharp
  if (context.Request.Path.StartsWithSegments("/gateway/api", out var remaining))
  {
      context.Request.Path = "/api" + remaining;
  }
  ```
- Mọi client cũ gọi `/gateway/api/v1/...` đều được âm thầm chuyển hướng nội bộ sang `/api/v1/...` mà không sinh thêm HTTP 301/302 redirect roundtrip, đảm bảo tương thích ngược 100%.

---

## TỔNG KẾT & HƯỚNG DẪN ÁP DỤNG

Mọi thành viên trong đội ngũ phát triển và các **AI Coding Agents** khi thực hiện bất kỳ thay đổi nào trên mã nguồn Nexus-Be **bắt buộc phải tuân thủ 15 điều quyết định kiến trúc nêu trên**. Mọi đề xuất thay đổi kiến trúc cốt lõi phải được thảo luận, tạo ADR mới và phê duyệt trước khi áp dụng vào codebase.
