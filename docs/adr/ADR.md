# HỆ THỐNG QUYẾT ĐỊNH KIẾN TRÚC TOÀN HỆ THỐNG (SYSTEM ARCHITECTURE DECISION RECORDS)
## Dự án: Nexus Microservices Ecosystem (.NET 8)

> **Trạng thái tài liệu:** Đã phê duyệt (Approved) & Có hiệu lực trên toàn hệ thống  
> **Áp dụng cho:** ApiGateway và toàn bộ 8 Microservices (`UserService`, `CatalogService`, `CommerceService`, `LogService`, `AuctionService`, `FulfillmentService`, `NotificationService`, `WalletService`)  
> **Nguồn lưu trữ trung tâm:** `docs/adr/ADR.md` (Thư mục gốc của repository)

---

## MỤC LỤC DANH MỤC ADR

| Mã ADR | Tiêu Đề Quyết Định | Trạng Thái |
|:---:|:---|:---:|
| **ADR 01** | Nền tảng công nghệ cốt lõi: .NET 8 (C# 12) toàn hệ sinh thái | `Approved` |
| **ADR 02** | Mô hình kiến trúc phân tán Microservices & Edge API Gateway mỏng | `Approved` |
| **ADR 03** | Ranh giới miền nghiệp vụ (DDD Bounded Contexts) & Database-Per-Service | `Approved` |
| **ADR 04** | Cấu trúc mã nguồn Clean Architecture 4 tầng chuẩn mực cho Microservices | `Approved` |
| **ADR 05** | Nguyên tắc No-Repository Pattern bọc ngoài Entity Framework Core 8 | `Approved` |
| **ADR 06** | Hai trục giao tiếp liên service: gRPC (Đồng bộ) & RabbitMQ (Bất đồng bộ) | `Approved` |
| **ADR 07** | Đơn nguồn sự thật (Single Source of Truth) cho Hợp đồng gRPC Protobuf | `Approved` |
| **ADR 08** | Điều phối giao dịch phân tán bằng Saga State Machine & Transactional Outbox | `Approved` |
| **ADR 09** | Kiến trúc 3 khối cho API Gateway & Bộ điều phối Mock/Real thông minh | `Approved` |
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
Hệ thống Nexus là sàn thương mại điện tử kết hợp đấu giá trực tuyến quy mô lớn, đòi hỏi thông lượng cao, độ trễ thấp và khả năng scale linh hoạt. Cần một nền tảng công nghệ đồng nhất cho cả Gateway và 8 Microservices để tối ưu hóa chi phí phát triển, chia sẻ mã nguồn hợp đồng (Protobuf/Contracts) và tối đa hóa hiệu năng runtime.

#### 2. Quyết định kiến trúc (Decision)
- Toàn bộ Gateway và các microservices sử dụng thống nhất **.NET 8 LTS** với ngôn ngữ **C# 12**.
- Tận dụng các tính năng mới nhất của .NET 8: Native gRPC client/server, System.Text.Json source generation, TimeProvider, Minimal APIs & Controller actions kết hợp, OpenTelemetry native instrumentation.

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
  - Chỉ đảm nhận các trách nhiệm hạ tầng: Định tuyến (Routing), Chuyển đổi giao thức (HTTP REST sang gRPC), Xác thực JWT, Kiểm tra quyền RBAC, Rate Limiting phân tán, Điều phối Mock/Real.
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
  - Mỗi microservice sở hữu cơ sở dữ liệu **PostgreSQL vật lý riêng biệt** trên các port mạng riêng biệt (`5433` đến `5440`, mật khẩu mặc định `MatkhaucuaTui123@`).
  - **CẤM TUYỆT ĐỐI:** Truy cập trực tiếp vào DB của service khác (cấm cross-database query, cấm tạo foreign key trỏ sang DB khác).
  - Mọi trao đổi hoặc tra cứu dữ liệu liên service bắt buộc phải qua **gRPC Query** (đồng bộ) hoặc **Domain Event qua RabbitMQ** (bất đồng bộ).

#### 3. Phân bổ Database vật lý:
| Service | Bounded Context | Tên DB | Port DB |
|:---|:---|:---|:---:|
| `UserService` | Identity & Access Management | `usermanagement_db` | `5433` |
| `CatalogService` | Product & Inventory Catalog | `category_db` | `5434` |
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
├── 3. ServiceName.Infrastructure   (DbContext, EF Core Configurations, MassTransit Consumers, Repositories nội bộ)
└── 4. ServiceName.Api              (gRPC Services, Endpoints, DI Configuration, Middlewares)
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
Một anti-pattern rất phổ biến trong cộng đồng .NET là viết thêm một lớp `GenericRepository<T>` và `IUnitOfWork` bọc ngoài Entity Framework Core. Điều này dẫn đến:
- Che khuất và làm mất các tính năng mạnh mẽ của EF Core: `IQueryable`, `AsNoTracking()`, `Include()`, Linq projection, batch updates.
- Tạo ra hàng chục file wrapper vô nghĩa chỉ làm nhiệm vụ chuyển tiếp `_dbSet.AddAsync()` hay `_dbSet.FindAsync()`.
- Bản thân `DbContext` đã chính là một **Unit of Work** và `DbSet<T>` đã chính là một **Repository** hoàn chỉnh.

#### 2. Quyết định kiến trúc (Decision)
- **CẤM TUYỆT ĐỐI:** Tạo các lớp `GenericRepository<T>`, `IRepository<T>`, `IUnitOfWork` bọc ngoài EF Core.
- Tại tầng `Application`: Sử dụng trực tiếp `DbContext` (hoặc interface `IApplicationDbContext`) và `DbSet<T>` để truy vấn và lưu trữ dữ liệu.
- Tận dụng triệt để Linq, Change Tracker, Execution Strategy và asynchronous API của EF Core 8.

---

### ADR 06: Hai trục giao tiếp liên service: gRPC (Đồng bộ) & RabbitMQ (Bất đồng bộ)

#### 1. Ngữ cảnh & Vấn đề (Context)
Cần ranh giới kỹ thuật rõ ràng để các lập trình viên và AI agents không lạm dụng giao tiếp đồng bộ (gây cascading failure) hoặc lạm dụng giao tiếp bất đồng bộ (gây phức tạp không cần thiết cho các tác vụ truy vấn tức thì).

#### 2. Quyết định kiến trúc (Decision)
Phân định dứt khoát 2 kênh giao tiếp:
1. **Giao tiếp Đồng bộ (Synchronous Query/Command) qua gRPC (Protobuf v3 - HTTP/2)**:
   - Dành cho:
     - Gateway gọi xuống Backend Services để lấy dữ liệu hiển thị (ví dụ: `ListProducts`, `GetCart`, `GetProfile`).
     - Tác vụ cần xác nhận kết quả tức thì trong mạng nội bộ với độ trễ cực thấp (< 5ms).
2. **Giao tiếp Bất đồng bộ (Asynchronous Event-Driven) qua RabbitMQ & MassTransit 8.3.0**:
   - Dành cho:
     - Các sự kiện trạng thái thay đổi (Domain Events): `OrderSubmittedEvent`, `StockReservedEvent`, `PaymentCompletedEvent`.
     - Kích hoạt các luồng xử lý phi tập trung không chặn người dùng (gửi email thông báo, ghi log hệ thống).
     - Điều phối quy trình nghiệp vụ phức tạp liên service qua Saga State Machine.

---

### ADR 07: Đơn nguồn sự thật (Single Source of Truth) cho Hợp đồng gRPC Protobuf

#### 1. Ngữ cảnh & Vấn đề (Context)
Khi nhiều service giao tiếp qua gRPC, việc mỗi service tự chỉnh sửa file `.proto` riêng lẻ sẽ dẫn đến sai lệch kiểu dữ liệu, gãy contract nhị phân và lỗi runtime tại môi trường Production.

#### 2. Quyết định kiến trúc (Decision)
- Toàn bộ định nghĩa gRPC cho 8 Microservices được lưu trữ tại **Đơn nguồn sự thật duy nhất (Single Source of Truth)**:
  `src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto`
- **Quy tắc tiến hóa hợp đồng an toàn (Contract Evolution):**
  - Mọi thay đổi về RPC hoặc Message bắt buộc phải bắt đầu từ file `shop.proto` này.
  - Sau khi cập nhật, file được copy/đồng bộ sang thư mục `Contracts/` của service backend đích.
  - **CẤM TUYỆT ĐỐI:** Thay đổi hoặc xóa bỏ số thứ tự trường (Field Tag Number) đã có trong `.proto`. Chỉ thêm trường mới với field tag tăng dần hoặc đánh dấu `[deprecated = true]`.

---

### ADR 08: Điều phối giao dịch phân tán bằng Saga State Machine & Transactional Outbox

#### 1. Ngữ cảnh & Vấn đề (Context)
Một quy trình nghiệp vụ như **Đặt hàng (Checkout)** đòi hỏi sự tham gia của 4 service: `CommerceService` (tạo đơn) $\rightarrow$ `CatalogService` (giữ kho) $\rightarrow$ `WalletService` (trừ tiền) $\rightarrow$ `FulfillmentService` (tạo vận đơn). Vì mỗi service dùng một DB riêng biệt, không thể dùng ACID transaction thông thường hay 2-Phase Commit (2PC).

#### 2. Quyết định kiến trúc (Decision)
1. **Saga State Machine với Giao dịch bù trừ (Compensating Transactions):**
   - Áp dụng **Commerce Saga State Machine** quản lý vòng đời đơn hàng: `PENDING` $\rightarrow$ `STOCK_RESERVED` $\rightarrow$ `PAID` $\rightarrow$ `COMPLETED`.
   - Nếu bất kỳ bước nào thất bại, hệ thống tự động kích hoạt sự kiện bù trừ:
     - *Ví dụ:* Trừ tiền ví thất bại (`PaymentFailedEvent`) $\rightarrow$ `CatalogService` lắng nghe và tự động **nhả kho ảo đã giữ** (`ReleaseStock`) $\rightarrow$ `CommerceService` chuyển trạng thái đơn sang `CANCELLED`.
2. **Transactional Outbox & Inbox Pattern (MassTransit):**
   - Mọi service khi lưu dữ liệu DB phải ghi event vào bảng `OutboxMessage` trong cùng một Local Transaction.
   - Background worker tự động đọc Outbox và phát lên RabbitMQ $\rightarrow$ Đảm bảo không bao giờ mất message (At-least-once delivery).
   - Phía Consumer sử dụng bảng `InboxMessage` dựa trên `MessageId` để đảm bảo tính Idempotent (chống xử lý trùng lặp 2 lần).

---

### ADR 09: Kiến trúc 3 khối cho API Gateway & Bộ điều phối Mock/Real thông minh

#### 1. Ngữ cảnh & Vấn đề (Context)
Trong quá trình phát triển, các team frontend và backend thường phát triển song song. Nếu Gateway phụ thuộc cứng vào việc backend phải chạy thì frontend sẽ bị nghẽn (block). Gateway cần khả năng phục vụ độc lập dữ liệu Mock mà không cần sửa code controller khi backend sẵn sàng.

#### 2. Quyết định kiến trúc (Decision)
Gateway được thiết kế theo **mô hình 3 khối phân tách hoàn toàn (3-Tier Decoupling)**:
1. **Khối Đầu Vào (Input - Controllers):**
   - Các controller RESTful chuẩn mực (`[ApiController]`), nhận Request DTOs và gọi điều phối.
   - **Tuyệt đối không chứa logic `if (mode == "Mock")`**.
2. **Khối Điều Phối Trung Tâm (Dispatching Core - GatewayDispatcher):**
   - `ModeEvaluator`: Tự động nhận diện Service Mode (`Mock` hay `Real`) từ cấu hình hoặc request header.
   - **Nếu Mode = Mock:** `MockDataMapper` nạp file fixture JSON tương ứng trong `Seeds/{service}/{operation}.json`, kiểm tra tính hợp lệ cú pháp qua Protobuf MessageParser của gRPC, và trả về dữ liệu mẫu.
   - **Nếu Mode = Real:** `GrpcServiceCaller` tự động forward token JWT, Idempotency-Key và TraceId xuống gRPC client để gọi backend thật.
3. **Khối Đầu Ra (Output - ApiResponseFactory):**
   - Đóng gói dữ liệu thành envelope chuẩn `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`.

---

### ADR 10: Hai trục trạng thái Gateway: Service Mode vs Auth Mode

#### 1. Ngữ cảnh & Vấn đề (Context)
Frontend cần 2 khả năng thử nghiệm độc lập:
- Muốn test API của 1 service cụ thể bằng mock data trong khi các service khác đang chạy thật.
- Muốn test nhanh giao diện UI mà không cần đăng nhập tạo token.

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
- **Token Format:** JWT Bearer Token chuẩn RFC 7519, ký HMAC-SHA256 hoặc RSA-256 bởi `UserService`.
- **Chuyển tiếp danh tính (Identity Propagation):** Gateway sau khi xác thực token sẽ forward nguyên vẹn header `Authorization: Bearer <token>` vào gRPC Metadata xuống backend.
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
Các API public của Gateway dễ bị tấn công brute-force mật khẩu hoặc spam request làm quá tải backend microservices. Việc giới hạn tần suất trên bộ nhớ cục bộ của 1 instance Gateway sẽ không có tác dụng khi scale nhiều instance Gateway.

#### 2. Quyết định kiến trúc (Decision)
- Áp dụng **Distributed Sliding Window Rate Limiting** sử dụng Redis (`RedisRateLimitMiddleware`).
- Khóa Redis được định danh theo: `{prefix}:rate:{service}:{identity}:{window_bucket}` với `identity` ưu tiên `UserId` (từ token sub claim) hoặc IP kết nối.
- **Chính sách Fail-Open linh hoạt:**
  - Trong môi trường `Development`: Nếu Redis chưa khởi động hoặc gặp sự cố kết nối, Gateway tự động cho request đi qua (Fail-Open) kèm log cảnh báo, không làm gián đoạn lập trình viên.
  - Trong môi trường `Production`: Áp dụng chính sách Fail-Closed an toàn, trả về HTTP `503 Service Unavailable` nếu hệ thống kiểm soát lưu lượng bị ngắt quãng.

---

### ADR 13: Quy chuẩn đóng gói phản hồi (Unified Response Envelope) & Zero-Validation Controller

#### 1. Ngữ cảnh & Vấn đề (Context)
Trước đây, Controller phải viết nhiều dòng kiểm tra thủ công (`if (!pagination.IsValid) return Bad(...)`), gây phình to mã nguồn và khiến cấu trúc JSON trả về giữa thành công và thất bại không đồng nhất.

#### 2. Quyết định kiến trúc (Decision)
1. **Quy chuẩn Response Envelope thống nhất:**
   - Mọi API thành công trả về cấu trúc:
     ```json
     {
       "success": true,
       "statusCode": 200,
       "message": "Thông báo thành công",
       "data": { ... },
       "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-...",
       "timestamp": "2026-10-16T12:00:00Z"
     }
     ```
   - Mọi API thất bại tuân theo chuẩn IETF RFC 9110 / ProblemDetails:
     ```json
     {
       "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
       "title": "One or more validation errors occurred.",
       "status": 400,
       "errorCode": "VAL_INVALID_INPUT",
       "detail": "Mô tả lỗi chi tiết",
       "errors": { "Field": ["Thông báo lỗi"] },
       "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-...",
       "timestamp": "2026-10-16T12:00:00Z"
     }
     ```
2. **Zero-Validation Controller & Centralized Exception Handling:**
   - Controller **hoàn toàn không chứa `try-catch`** và **không tự tạo response `.Error(...)` thủ công**.
   - Kiểm tra input được chuẩn hóa qua các helper tự động ném `GatewayInputException`:
     - `pagination.EnsureValid();`
     - `ValidationHelpers.EnsureGuid(id, "Field");`
     - `ValidationHelpers.EnsureRequired(text, "Field");`
     - `MoneyPrecision.EnsurePositive(price, "Field");`
   - `GatewayExceptionHandler` trung tâm tự động bắt `GatewayInputException`, `RpcException`, `TimeoutException` và map sang mã HTTP cùng envelope lỗi chuẩn xác.

---

### ADR 14: Giám sát phân tán (Distributed Tracing & Observability) với OpenTelemetry W3C

#### 1. Ngữ cảnh & Vấn đề (Context)
Trong hệ thống phân tán gồm 1 Gateway và 8 Microservices giao tiếp chéo qua cả gRPC và RabbitMQ, việc truy tìm nguyên nhân gốc rễ (Root Cause) khi một request bị chậm hoặc lỗi là cực kỳ khó khăn nếu không có mã truy vết xuyên suốt.

#### 2. Quyết định kiến trúc (Decision)
- Sử dụng chuẩn **W3C TraceContext** và **OpenTelemetry (OTel)**.
- Khi request đi vào Gateway, `ApiResponseFactory.ResolveTraceId` sẽ phát hành hoặc tái sử dụng `TraceIdentifier` làm `TraceId` duy nhất.
- `TraceId` này được gắn vào:
  - Header phản hồi HTTP `X-Trace-Id` gửi về cho Client.
  - Trường `traceId` trong JSON body của cả phản hồi Success và Error.
  - Header gRPC Metadata chuyển tiếp xuống tất cả các microservices backend.
  - Header của các message Event bắn lên RabbitMQ.
- Cho phép tra cứu một giao dịch từ Frontend $\rightarrow$ Gateway $\rightarrow$ Backend gRPC $\rightarrow$ RabbitMQ Consumer trên các hệ thống giám sát tập trung (Jaeger, Prometheus, Grafana).

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
