<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **root** (6723 symbols, 9712 relationships, 184 execution flows). Index stale? Run `node .gitnexus/run.cjs analyze --index-only`.

- **MUST run impact before editing:** `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`. Report callers, processes, risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing:** `detect_changes({scope: "all"})` or `node .gitnexus/run.cjs detect-changes --scope all --repo .`. Compare: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn on HIGH/CRITICAL `risk` pre-edit;** never waive with `riskSharedAxes`.
- **MUST treat `risk: UNKNOWN` as unresolved, not low.** Confirm with text search before modifying/deleting.
- **MUST use `query` for concepts/flows, `context` for symbols, or `impact` for blast radius.**
- **NEVER** edit before impact analysis · **NEVER** rename with find-and-replace · **NEVER** commit before detect_changes.
- Resources: `gitnexus://repo/root/context` · `clusters` · `processes` · `process/{name}`. CLI skills in `.claude/skills/gitnexus-*/SKILL.md`.
<!-- gitnexus:end -->

---

# QUY CHUẨN VẬN HÀNH DÀNH CHO TẤT CẢ CÁC AI CODING AGENTS

## 🛑 NGUYÊN TẮC 1: BẮT BUỘC LẬP KẾ HOẠCH TRƯỚC KHI HÀNH ĐỘNG (PLAN-FIRST RULE)
Mọi AI Agent khi nhận nhiệm vụ kỹ thuật **BẮT BUỘC PHẢI LẬP VÀ TRÌNH BÀY PLAN** trước khi thực hiện bất kỳ hành động sửa đổi mã nguồn, thêm/xóa file, refactor, tạo migration hay thay đổi cấu hình.
1. **Mục tiêu (Objective)**: Tóm tắt chính xác điều cần làm.
2. **Context & Files cần đọc**: Liệt kê các file theo ma trận đọc file tại Nguyên tắc 3.
3. **Phân tích rủi ro & Phạm vi ảnh hưởng (Impact Analysis)**: Dùng GitNexus `impact`, cảnh báo rõ HIGH/CRITICAL.
4. **Checklist các bước thực hiện (Step-by-Step Implementation)**: Từng bước logic, chi tiết.
5. **Kế hoạch kiểm chứng (Verification)**: Lệnh `dotnet build` và `dotnet test` tương ứng.

## 🧭 NGUYÊN TẮC 2: QUY TẮC ĐỊNH HƯỚNG TÀI NGUYÊN MỘT CHIỀU (INWARD-ONLY SCOPING)
1. **File ở Root (`Nexus-Be/`)**: ĐƯỢC PHÉP trỏ vào trong các thư mục con và service repo (`src/Services/...`).
2. **File bên trong từng Service Repo / Submodule (`src/Services/{Service}/`)**:
   - TUYỆT ĐỐI CHỈ ĐƯỢC trỏ tới tài nguyên nội bộ của chính repo đó.
   - TUYỆT ĐỐI KHÔNG trỏ ngược ra ngoài Root (`../../../docs/...`, `../../specs/...`) hoặc sang Sibling Service (`../../Catalog/...`). Mỗi service phải 100% Self-contained.

## 📚 NGUYÊN TẮC 3: DANH MỤC FILE BẮT BUỘC PHẢI ĐỌC
Khi bắt đầu phiên làm việc tại bất kỳ repository nào, AI Agent **BẮT BUỘC PHẢI ĐỌC** theo danh mục chi tiết tại `docs/agents/reading-matrix.md`.
- **Root**: `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`, `specs/01` qua `05`, `AGENTS.md`.
- **ApiGateway**: `specs/00_AGENT_MISSION_GUARDRAILS.md` qua `05`, `MOCK_GUIDE.md`, `DEV_GUIDE.md`, `Nexus.Gateway/Dtos/`.
- **Microservices Backend**: `specs/00_AGENT_MISSION_GUARDRAILS.md` qua `05_DEV_VERIFICATION_CHECKLIST.md` của service đó.

## 🔒 NGUYÊN TẮC 4: RÀO CHẮN BẤT BIẾN CHỐNG ẢO GIÁC (ZERO-HALLUCINATION)
1. **CẤM DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**: Dùng trực tiếp `DbContext` và `DbSet<T>` trong Application Layer.
2. **CÔ LẬP TUYỆT ĐỐI DATABASE (DATABASE-PER-SERVICE)**: Không query trực tiếp DB của service khác.
3. **CẤU HÌNH PORT LÀ BẤT BIẾN**: Gateway `8080`, Microservices HTTP/REST `8001`-`8008`, DB `5433`-`5440`.
4. **100% SỬ DỤNG RESTFUL HTTP/JSON — CẤM gRPC VÀ BÃI BỎ MESSAGE BROKER**:
   - Chuẩn RESTful: `/api/v1/{resource}`, RFC 9110 (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
   - Dữ liệu trả về: `ApiResponse<T>`, `ApiResponse<PagedData<T>>`, hoặc `204 NoContent`.
   - Bãi bỏ hoàn toàn RabbitMQ, MassTransit, Saga State Machine và Transactional Outbox/Inbox tables. Giao tiếp liên service chuyển sang gọi trực tiếp qua HTTP REST Clients.
5. **ĐỐI SOÁT TÀI LIỆU EXCEL**: Chỉ tin ý đồ nghiệp vụ (semantic), KHÔNG tin định dạng/casing. Quy chuẩn Role (PascalCase theo `specs/03`), DTO (camelCase), DB (snake_case).
6. **BẢO MẬT & QUẢN LÝ BIẾN MÔI TRƯỜNG (`.env`)**:
   - CẤM tự ý xóa/ghi đè secrets. Khi có chỉ đạo trực tiếp từ người dùng, rà soát `.env.example`, `.env.test`, compose và cung cấp block cấu hình rõ ràng. Tuyệt đối cấm duplicate keys.
7. **HẠ TẦNG PHỤ TRỢ TẬP TRUNG (SINGLE SHARED INFRASTRUCTURE)**:
   - Redis (`6379`), Tempo, Grafana chỉ khai báo 1 lần tại `src/Infrastructure/` hoặc `docker-compose.infra.yml`. CẤM khai báo riêng lẻ trong submodule. Dùng Key Prefix riêng trên Redis chung (`nexus:gateway:*`, `otp:*`, `user:*`).
8. **FEATURE-DRIVEN CO-LOCATION & 1-TO-1 CONTROLLER PAIRING (CHUẨN HÓA ĐẶC TẢ `specs/01`)**:
   - Tầng Application: Toàn bộ thành phần của một tính năng đặt tại `{Service}.Application/Services/{Feature}/` gồm: `I{Feature}Service.cs`, `{Feature}Service.cs` (inject trực tiếp `I{Service}DbContext`, cấm Repository), `{Feature}Requests.cs`, `{Feature}Responses.cs`, `{Feature}Dtos.cs` (tùy chọn).
   - Tầng Api: Ghép cặp 1-to-1 với một thin controller tại `{Service}.Api/Controllers/{Feature}Controller.cs`, chỉ inject duy nhất `I{Feature}Service`.
   - **NGOẠI LỆ DUY NHẤT — `WalletService` (ĐÓNG BĂNG)**: dùng classic CQRS qua MediatR tại `Wallet.Application/Features/{Area}/Commands|Queries/{UseCase}/`, mỗi use case gồm Command/Query, Handler và response record. Controller inject `ISender`, giữ đúng 3 file. Cấm tạo lại `I{Feature}Service` facade, cấm tách controller theo tài nguyên, cấm gỡ MediatR. Chạy `src/Services/Wallet/scripts/verify-wallet-architecture.sh` trước khi sửa. Chi tiết tại `src/Services/Wallet/AGENTS.md`.
9. **GIAO TIẾP LIÊN DỊCH VỤ 100% QUA TYPED REST CLIENT**:
   - Định nghĩa Interface tại `{Service}.Application/Interfaces/` (ví dụ `IEmailNotificationClient`).
   - Triển khai `HttpClient` tại `{Service}.Infrastructure/Services/` và đăng ký typed client trong `Infrastructure/DependencyInjection.cs`.
   - Các tương tác liên service thực hiện trực tiếp qua HTTP REST API có timeout, retry và graceful fallback.
10. **QUY CHUẨN BẮT BIẾN KHI PHÁT TRIỂN & KHAI BÁO API MỚI (MANDATORY API RULES)**:
   - **Cấm trùng lặp Route alias (No Duplicate Route Aliases)**: Cấm tuyệt đối khai báo nhiều route attributes trùng lặp (ví dụ `[HttpGet("user")]` và `[HttpGet("users")]`) trên cùng một Action. Mỗi action chỉ có 1 route endpoint chính thức duy nhất.
   - **Quy chuẩn Định danh Route: 100% SỐ NHIỀU (100% Plural Route Convention)**:
     - Toàn bộ danh từ tài nguyên bộ sưu tập (Domain Collections) trên toàn bộ hệ thống Nexus BẮT BUỘC dùng danh từ số nhiều viết thường (lowercase plural, kebab-case nếu là từ ghép):
       - Người dùng & Quản trị: `/api/v1/users`, `/api/v1/users/{userId}`, `/api/v1/admin/users`, `/api/v1/admin/users/{userId}`, `/api/v1/sellers`, `/api/v1/sellers/{sellerId}`.
       - Danh mục & Sản phẩm: `/api/v1/products`, `/api/v1/products/{productId}`, `/api/v1/categories`, `/api/v1/categories/{categoryId}`, `/api/v1/variants`.
       - Đơn hàng & Giỏ hàng: `/api/v1/carts`, `/api/v1/carts/items`, `/api/v1/orders`, `/api/v1/orders/{orderId}`, `/api/v1/sub-orders`, `/api/v1/checkouts`.
       - Kho vận: `/api/v1/shipments`, `/api/v1/warehouses`, `/api/v1/inventories`.
       - Đấu giá: `/api/v1/auctions`, `/api/v1/bids`.
       - Ví tiền: `/api/v1/wallets`, `/api/v1/wallets/transactions`, `/api/v1/wallets/withdrawals`.
       - Thông báo & Nhật ký: `/api/v1/notifications`, `/api/v1/logs`.
     - **Ngoại lệ duy nhất cho ngữ cảnh đặc thù (Contextual Singleton)**:
       - `/api/v1/me`: Đại diện cho chính bản thân người dùng đang xác thực (`/api/v1/me`, `/api/v1/me/sessions`, `/api/v1/me/penalties`, `/api/v1/me/reports`).
       - `/api/v1/auth`: Nhóm hành động xác thực phi tài nguyên (`/api/v1/auth/login`, `/api/v1/auth/register`, `/api/v1/auth/refresh`, `/api/v1/auth/otp/verify`).
     - TUYỆT ĐỐI CẤM sử dụng các route số ít dạng `/api/v1/cart`, `/api/v1/product`, `/api/v1/user`, `/api/v1/seller`, `/api/v1/order`.
   - **Mô hình Thin Controller & Kế thừa đúng chuẩn**:
     - Tại API Gateway: Controller bắt buộc kế thừa `GatewayBaseController`, không chứa business logic, chỉ validate input cơ bản qua `UserValidation` và ủy quyền downstream qua `ForwardAsync` / `ForwardPagedAsync` / `ForwardNoContentAsync`.
     - Tại Microservice: Kế thừa `ControllerBase`, ghép cặp 1-to-1 với feature service tương ứng.
   - **Phong bì dữ liệu chuẩn (Envelope Standard)**: Mọi endpoint trả dữ liệu đều phải bọc qua `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`. Endpoint xóa hoặc không trả dữ liệu body bắt buộc trả HTTP `204 NoContent`. DTOs dùng PascalCase trong C# và camelCase trong JSON serialization.
   - **Quy chuẩn Phân trang Hệ thống (System Pagination Governance)**:
     - **Trách nhiệm tính toán phân trang thuộc 100% về Backend Microservices**: Chỉ microservice sở hữu cơ sở dữ liệu mới có quyền thực hiện phân trang qua câu lệnh truy vấn SQL (`OFFSET/LIMIT` hoặc `.Skip((page - 1) * pageSize).Take(pageSize)`) và đếm tổng bản ghi (`SELECT COUNT(*)` hoặc `.CountAsync()`). Microservice chịu trách nhiệm đóng gói cấu trúc phân trang chuẩn `PagedData<T>` (`items` và `pagination: { pageIndex, pageSize, totalCount, totalPages, hasPreviousPage, hasNextPage }`) hoặc DTO phân trang tương đương và trả về trực tiếp trong payload HTTP 200.
     - **Gateway là Edge Reverse Proxy phi trạng thái (Zero Pagination Calculation at Gateway)**: Gateway tuyệt đối KHÔNG truy cập cơ sở dữ liệu, KHÔNG nhận tập dữ liệu thô lớn không giới hạn về bộ nhớ để tự cắt trang (gây nghẽn mạng và cạn kiệt tài nguyên Gateway). Gateway chỉ đóng vai trò chuyển tiếp downstream qua YARP hoặc bọc vỏ phong bì `ApiResponse<PagedData<T>>`.
   - **Quy chuẩn Quản lý Hồ sơ Tài liệu API Hai Trạng Thái (Dual-Stage API Documentation Lifecycle)**:
     - Mọi API trong hệ sinh thái Nexus đều phải có đúng 1 file tài liệu độc lập theo mẫu chuẩn `docs/api/API_DOC_TEMPLATE.md` và được quản lý ở 1 trong 2 thư mục:
       - `docs/api/B_none/{Service}/{ID}_{FEATURE}.md`: API đang phát triển (WIP), mới lên spec hoặc chưa vượt qua kiểm thử.
       - `docs/api/A_Active/{Service}/{ID}_{FEATURE}.md`: API đã hoàn tất (100% test pass) và được Người dùng nghiệm thu.
     - Mỗi file tài liệu phải chứa đầy đủ 7 mục bắt buộc: (1) Mô tả & Routing RBAC, (2) Code Trace chi tiết (Service, Controller, Function, DB Table), (3) Quy chuẩn Validation, (4) Phong bì dữ liệu mẫu, (5) Ma trận mã lỗi RFC 9110, (6) Bảng danh mục Enum liên quan (giá trị int trong DB vs string PascalCase ở API), (7) Checklist hoàn thành.
     - Khi một Function trong service bổ sung mã lỗi mới hoặc exception mới, BẮT BUỘC phải cập nhật ngay vào bảng Error Matrix của file doc tương ứng để Frontend luôn nắm bắt chính xác.
   - **Chuẩn hóa XML Comment Endpoint**: Chỉ dùng single-line XML `<summary>` ngắn gọn trực tiếp trên từng Action method. Cấm viết class-level remarks, section dividers kẻ ngang hoặc comment dài dòng nhiều dòng.
   - **Đồng bộ Tài liệu & Specs**: Khi thêm mới hoặc thay đổi bất kỳ route/DTO nào, bắt buộc cập nhật đồng thời file spec tương ứng (`specs/02_GATEWAY_CONTROLLERS_ROUTING.md`) và tài liệu API Frontend (`docs/FRONTEND_API_ENDPOINT_MAPPING.md`).
   - **Skill thực thi Endpoint**: Trước khi thêm hoặc sửa bất kỳ endpoint nào, bắt buộc đọc và làm theo checklist tại `.agents/skills/new-feature-endpoint/SKILL.md`; khi làm việc trong service repo thì dùng overlay `.agents/skills/new-feature-endpoint/SKILL.md` của chính service đó.
   - **Quy trình Bắt buộc khi Triển khai & Đóng gói 1 API (API Implementation & Documentation Lifecycle)**:
     Khi thực hiện bất kỳ 1 API nào (mới hoặc refactor):
     1. Tầng Application: Hoàn thiện `I{Feature}Service.cs`, `{Feature}Service.cs`, `{Feature}Requests.cs`, `{Feature}Responses.cs` (riêng `WalletService` dùng Command/Query + Handler theo CQRS).
     2. Tầng Api: Ghép cặp Thin Controller 1-to-1, áp dụng chuẩn Route, Envelope và XML summary.
     3. Kiểm thử tự động: Viết test case và chạy `dotnet test` vượt qua 100%.
     4. Ghi nhận vào Hồ sơ Tài liệu API: Ngay sau khi code và test xong, BẮT BUỘC cập nhật/ghi nhận vào file tài liệu API tương ứng (`docs/api/...`, `docs/api/active/...`, và `specs/02_API_REST_CONTRACTS.md`) đầy đủ:
        - **Mô tả nghiệp vụ & Routing**: HTTP Method, Endpoint, Quyền hạn RBAC (`AllowAnonymous`, `Buyer`, `Seller`, `StaffOrAdmin`, `Admin`).
        - **Quy chuẩn Validation**: Chi tiết từng trường (Bắt buộc/Tùy chọn, Kiểu dữ liệu, Format, Min/Max, Range, Constraints).
        - **Ma trận Mã lỗi (RFC 9110 Error Matrix)**: HTTP status (`400`, `401`, `403`, `404`, `409`, `500`), `errorCode` chuẩn `SCREAMING_SNAKE_CASE`, `message` 100% tiếng Anh Sentence case, và điều kiện kích hoạt lỗi.
        - **Payload Mẫu**: Request body và Response envelope `ApiResponse<T>` hoặc `204 NoContent`.
        - **Checklist Trạng thái Hoàn thành (Completion Checklist)**:
          - `[x]` Service & Controller implemented
          - `[x]` Validation rules & Error handling active
          - `[x]` Unit/Integration tests passed (kèm tên file test)
          - `[x]` Gateway routing / mock fixture aligned
          - `[x]` Trạng thái chính thức: `✅ COMPLETED`
   - **11. QUY CHUẨN THAY ĐỔI & THAO TÁC CƠ SỞ DỮ LIỆU (DATABASE GOVERNANCE & MIGRATION RULES)**:
     Khi thay đổi mã nguồn, tạo mới thực thể, chỉnh sửa bảng hoặc đụng tới cơ sở dữ liệu, mọi AI Coding Agent BẮT BUỘC tuân thủ nghiêm ngặt 7 điều răn sau:
     1. **Lưu trữ & Ép kiểu Enum (Enum Persistence & Boundary Serialization)**:
        - **Bên trong DB (PostgreSQL)**: 100% Enum phải được lưu dưới dạng số nguyên `integer` (32-bit signed int). TUYỆT ĐỐI CẤM dùng `HasConversion<string>()` hoặc PostgreSQL Custom Enum Types (`CREATE TYPE ... AS ENUM`). Tối ưu dung lượng lưu trữ, tốc độ đánh chỉ mục (B-Tree index) và bảo đảm tương thích migration khi mở rộng giá trị mới.
        - **Bên trong Domain & Service Layer**: 100% sử dụng C# Enum strongly-typed (kế thừa ngầm định kiểu `int32`), gán giá trị số rõ ràng từ `0`. Tuyệt đối CẤM dùng số nguyên ma thuật (magic numbers) hay chuỗi ký tự thô để so sánh trạng thái thực thể.
        - **Đầu ra REST API (Outbound to Client)**: 100% phải được tuần tự hóa thành chuỗi PascalCase (`"Active"`, `"PendingVerification"`). Tuyệt đối không để lộ số nguyên thô ra bên ngoài JSON response.
        - **Đầu vào REST API (Inbound from Client)**:
          - Với JSON Body: Bắt buộc qua `PascalCaseJsonStringEnumConverter`, chấp nhận case-insensitive và SCREAMING_SNAKE_CASE (tự động loại bỏ dấu gạch dưới). CẤM nhận số nguyên thô (`allowIntegerValues: false`). Nếu giá trị không hợp lệ, ném ngoại lệ `JsonException` tiếng Anh Sentence case liệt kê toàn bộ giá trị hợp lệ.
          - Với Query Parameters & Route Data: Bắt buộc dùng `EnumExtensions.TryToEnum<TEnum>(out var result)` để parse an toàn hoặc `ToEnum<TEnum>()` (ném `ArgumentException` được middleware chuyển thành HTTP 400 `VAL_INVALID_ARGUMENT`).
     2. **Quy trình Quản lý Migration EF Core (EF Core Migration Lifecycle)**:
        - **Bắt buộc Lập kế hoạch trước khi Migration (Plan-First)**: Trước khi tạo migration, phải trình bày rõ: danh sách cột thêm/sửa, kiểu dữ liệu, index, và ảnh hưởng tới code hiện tại.
        - **Quy ước Đặt tên Migration**: Sử dụng timestamp kết hợp hành động nghiệp vụ rõ ràng (ví dụ: `20261030054250_InitialCreate` hoặc `20261030143000_AddSellerVerificationStatus`).
        - **Cấm Migration Phá Hủy (Zero Destructive Migrations without Explicit Approval)**: Tuyệt đối CẤM tự ý thêm lệnh `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, hoặc `RENAME COLUMN` trên cơ sở dữ liệu nếu chưa có sự phê duyệt rõ ràng từ Người dùng (Sếp). Mọi thay đổi phải đi theo hướng an toàn Additive (thêm cột mới nullable hoặc có default value).
        - **Đồng bộ Migration Designer & ModelSnapshot**: Khi tạo hoặc cập nhật migration, bắt buộc kiểm tra `AppDbContextModelSnapshot.cs` và file `*.Designer.cs` khớp 100% với schema entity, không để sót migration rác hay migration dở dang.
        - **Tự động áp dụng Migration An toàn (Startup Safe Auto-Migration)**: Service chỉ gọi `db.Database.Migrate()` khi `db.Database.IsRelational()` là `true`, và bắt buộc bọc trong khối `try-catch` với log cảnh báo rõ ràng để tránh crash ứng dụng khi DB chưa sẵn sàng.
     3. **Cô lập Cơ sở dữ liệu Tuyệt đối (Database-per-Service Isolation)**:
        - Mỗi microservice sở hữu cơ sở dữ liệu riêng biệt (`usermanagement_db:5433`, `category_db:5434`, `commerce_db:5435`, `log_db:5436`, `auction_db:5437`, `fulfillment_db:5438`, `notification_db:5439`, `wallet_db:5440`).
        - Tuyệt đối CẤM truy vấn chéo giữa các database (cấm dùng dblink, foreign data wrapper, hoặc raw SQL join sang DB khác).
        - Tuyệt đối CẤM chia sẻ `DbContext` giữa các microservices.
     4. **Cấm dùng Repository Pattern bọc ngoài EF Core**:
        - Tầng Application trực tiếp inject `I{Service}DbContext` và truy vấn `DbSet<T>`. Cấm tạo `IRepository<T>`, `GenericRepository`, hoặc `UnitOfWork`.
     5. **Quy chuẩn Đặt tên và Cấu hình Thực thể (Entity & Fluent API Configuration)**:
        - **Tên bảng**: PascalCase mặc định theo tên Entity / DbSet (không tự ý viết `builder.ToTable("snake_case")`).
        - **Kiểu khóa chính**: Bắt buộc dùng `Guid` cho Primary Key của tất cả các entity nghiệp vụ (kế thừa `BaseEntity<Guid>` hoặc `AuditableEntity<Guid>`).
        - **Khóa ngoại & Hành vi Xóa (Foreign Keys & DeleteBehavior)**: Ưu tiên dùng `DeleteBehavior.Restrict` hoặc `DeleteBehavior.SetNull`. CẤM dùng `DeleteBehavior.Cascade` bừa bãi gây lỗi cascade cycle hoặc mất dữ liệu diện rộng ngoài ý muốn.
        - **Xóa mềm (Soft Delete)**: Mọi entity nghiệp vụ phải chứa trường `IsDeleted` (boolean) và `DeletedAt` (DateTimeOffset?). Bắt buộc khai báo bộ lọc toàn cục `builder.HasQueryFilter(x => !x.IsDeleted)` trong file `*Configuration.cs`.
        - **Chỉ mục Hiệu năng (Performance Indexes)**: Tất cả các trường tìm kiếm thường xuyên (`Email`, `Username`, `PhoneNumber`, `Status`) hoặc khóa ngoại phải có chỉ mục. Các trường unique nullable bắt buộc dùng filtered index (ví dụ: `builder.HasIndex(x => x.Username).IsUnique().HasFilter("\"Username\" IS NOT NULL")`).
        - **Độ chính xác tiền tệ (Currency & Decimal Precision)**: Mọi trường số tiền, số dư (như `Wallet.Balance`, `Product.Price`, `Bid.Amount`) phải cấu hình kiểu decimal với độ chính xác rõ ràng `HasPrecision(18, 2)`.
     6. **Quy chuẩn Dữ liệu Khởi tạo (Seed Data Standards)**:
        - Toàn bộ dữ liệu seed khai báo qua `HasData()` trong `OnModelCreating` hoặc các class helper tại `Persistence/Seeds/`.
        - Khóa chính ID trong Seed Data BẮT BUỘC dùng GUID cố định (Deterministic GUIDs như `Guid.Parse("11111111-1111-1111-1111-111111111111")`). TUYỆT ĐỐI CẤM dùng `Guid.NewGuid()` trong `HasData` vì sẽ làm sai lệch snapshot migration sau mỗi lần build.
        - Mọi mật khẩu mẫu cho tài khoản seed bắt buộc phải hash bằng BCrypt có salt trước khi đưa vào cấu hình seed (`$2a$11$...`), không lưu plain text.
     7. **Bảo vệ Bí mật và Chuỗi kết nối Database**:
        - Tuyệt đối CẤM commit mật khẩu thật, connection string thực tế vào mã nguồn hay git. Mọi thông tin nhạy cảm phải đọc từ biến môi trường.
   - **12. QUY CHUẨN TẠM KHÓA INTERNAL API (INTERNAL API TEMPORARY DISABLE)**:
     Từ 2026-10-31, hệ thống tạm khóa mô hình Internal API và chuyển giao tiếp liên service sang REST thường:
     1. **Route liên service dùng tiền tố công khai**:
        - Gửi OTP email: `POST /api/v1/notifications/email/otp` và `POST /api/v1/notifications/email/send`.
        - Trừ tiền ví: `POST /api/v1/wallets/checkout/direct`.
        - Khởi tạo và tra cứu tồn kho: `POST /api/v1/inventories/initialize` và `GET /api/v1/inventories/{skuId:guid}`.
        - Nạp batch log: `POST /api/v1/logs/batch`.
        - Cấm đặt lại tiền tố `/api/v1/internal` hoặc tạo thư mục `Controllers/Internal/`.
     2. **Bảo mật internal đang tạm khóa**:
        - `InternalServiceAuthMiddleware` và `InternalServiceAuthHandler` chỉ còn file; đăng ký trong pipeline và DI đã bị comment.
        - Không yêu cầu header `X-Internal-Service-Key` cho các route trên.
        - Gateway không chặn path internal và không xóa path internal khỏi tài liệu OpenAPI.
     3. **Hệ quả cần kiểm soát**:
        - Các route trên đi qua Gateway như API thường. Cấm thêm dữ liệu nhạy cảm mới vào các route này khi chưa có xác thực.
        - Muốn bật lại mô hình cũ, phải có phê duyệt rõ ràng của Người dùng và khôi phục đồng bộ middleware, handler, Gateway và docs.
   - **13. QUY CHUẨN BẮT BIẾN: BẢO VỆ DANH TÍNH CHỐNG GIẢ MẠO CHỦ ĐỘNG VÀ LAN TRUYỀN CLAIMS (ACTIVE ANTI-SPOOFING & IDENTITY PROPAGATION GOVERNANCE)**:
     Toàn bộ hệ thống Nexus áp dụng cơ chế Zero-Trust Edge Gateway đối với việc xác thực và truyền tải danh tính người dùng:
     1. **Chặn Đứng Tuyệt Đối Header Giả Mạo Từ Bên Ngoài (Active Anti-Header-Spoofing Rejection)**:
        - `ClientContextMiddleware` tại API Gateway chủ động kiểm tra (không phân biệt hoa thường) toàn bộ các header định danh nhạy cảm gửi từ bên ngoài (`x-user-id`, `x-user-email`, `x-user-roles`, `x-user-role`, `x-user-permissions`, `x-user-permission`, `x-internal-service-key`).
        - Nếu phát hiện bất kỳ header nào trong danh sách cấm, Gateway BẮT BUỘC ngắt pipeline ngay lập tức, ghi log cảnh báo bảo mật kèm Client IP, và trả về HTTP `403 Forbidden` (`errorCode: "FORBIDDEN_HEADER_SPOOFING"`, `message: "Security violation: Untrusted identity header detected in external request."`). TUYỆT ĐỐI CẤM âm thầm bỏ qua hay cho phép request đi tiếp.
     2. **Lan Truyền Danh Tính Tin Cậy từ JWT Bearer Token (Edge Identity Propagation)**:
        - Gateway giải mã và xác thực chữ ký số JWT Bearer token tại biên.
        - `IdentityPropagationTransform` của YARP Reverse Proxy trích xuất các claims: `sub` (User ID), `email`, `role`/`roles`, `permission`/`permissions`, và tiêm an toàn vào downstream request headers (`x-user-id`, `x-user-email`, `x-user-roles`, `x-user-permissions`).
     3. **Phân Quyền Chi Tiết Tại Backend Microservices (Microservice Fine-Grained Authorization)**:
        - Các microservice backend (`8001`-`8008`) đọc thông tin `x-user-id` và `x-user-roles` từ HttpContext để kiểm tra quyền sở hữu tài nguyên (Resource Ownership) và thực thi nghiệp vụ.
   - **14. QUY CHUẨN BẮT BIẾN: PHÂN QUYỀN TINH VÀ BẢO VỆ QUYỀN SỞ HỮU TÀI NGUYÊN (RESOURCE OWNERSHIP & FINE-GRAINED AUTHORIZATION GOVERNANCE)**:
     1. **Trách nhiệm bảo vệ quyền sở hữu thuộc 100% về Microservices Backend**: Gateway chỉ kiểm tra chữ ký token và phân quyền thô cho route Admin. Từng microservice sở hữu dữ liệu phải chịu trách nhiệm phân quyền chi tiết.
     2. **Cấm tin tưởng tham số định danh từ Client**: Tuyệt đối CẤM tin tưởng các tham số `buyerId`, `userId`, `sellerId` truyền qua Query string (`[FromQuery]`) hoặc Route path (`[FromRoute]`).
     3. **Xác thực quyền sở hữu bắt buộc**: Controller hoặc Service bắt buộc lấy `currentUserId` từ `HttpContext.GetUserId()` và so sánh:
        - Nếu `currentUserId != targetId` và người dùng không có vai trò `admin` hoặc `staff` (`!HttpContext.HasRole("admin") && !HttpContext.HasRole("staff")`), lập tức trả về HTTP `403 Forbidden` (`errorCode: "FORBIDDEN"`, `message: "You do not have permission to access or modify this resource."`).
        - Nếu request yêu cầu xác thực mà không có danh tính hợp lệ, lập tức trả về HTTP `401 Unauthorized` (`errorCode: "UNAUTHORIZED"`).
   - **15. QUY CHUẨN PHÂN TRANG HỆ THỐNG ĐỒNG BỘ (SYSTEM PAGINATION GOVERNANCE & PAGED DATA ENVELOPE)**:
     1. **Tính toán phân trang tại Database**: Mọi truy vấn danh sách phân trang bắt buộc thực hiện tại Database qua `.Skip((page - 1) * pageSize).Take(pageSize)` và `.CountAsync()`.
     2. **Đóng gói cấu trúc PagedData chuẩn**: Toàn bộ endpoint phân trang phải trả về cấu trúc:
        ```csharp
        public sealed record PagedData<T>(
            IReadOnlyList<T> Items,
            PaginationMetadata Pagination);
        public sealed record PaginationMetadata(
            int PageIndex,
            int PageSize,
            int TotalCount,
            int TotalPages,
            bool HasPreviousPage,
            bool HasNextPage);
        ```
     3. **Gateway là Reverse Proxy phi trạng thái**: Gateway tuyệt đối không nhận dữ liệu thô không giới hạn về bộ nhớ để tự cắt trang. Gateway bọc trực tiếp payload phân trang từ service thành `ApiResponse<PagedData<T>>`.
   - **16. QUY CHUẨN GHI NHẬT KÝ KIỂM TOÁN TẬP TRUNG (CENTRALIZED AUDIT LOGGING GOVERNANCE)**:
     1. **Ghi qua Extension Method tập trung**: Mọi thao tác ghi nhật ký kiểm toán vào bảng `AuditLogs` bắt buộc thực hiện qua extension method `_dbContext.AddAuditLog(...)` trên `I{Service}DbContext`. TUYỆT ĐỐI CẤM khởi tạo thủ công `new AuditLog { ... }` rải rác trong code tầng Application hay Api.
     2. **Tự động hóa JSON Serialization & Thuộc tính cơ sở**:
        - Tham số `oldValues`, `newValues`, `changedColumns` nhận `object?` và tự động serialize sang JSON string; nếu truyền vào chuỗi raw JSON đã serialize thì giữ nguyên, không double-serialize.
        - Tự động chuẩn hóa `ServiceName` theo tên dịch vụ (ví dụ: `"user-service"`), tự động gán `CreatedAt = DateTimeOffset.UtcNow`, và thiết lập `IsSynced = false`.
     3. **Lưu trữ Cố định và Bất biến (Persistent & Append-Only)**:
        - Audit Log bắt buộc được commit cùng transaction nghiệp vụ vào bảng `AuditLogs` của database dịch vụ đó (`usermanagement_db`, `wallet_db`...).
        - TUYỆT ĐỐI CẤM dùng `_logger.LogInformation` để thay thế cho AuditLog nghiệp vụ nhạy cảm (như phân quyền, khóa tài khoản, duyệt hồ sơ người bán, điều chỉnh số dư ví).
        - Bản ghi AuditLog là bất biến: chỉ được phép INSERT và SELECT, cấm viết API UPDATE hoặc DELETE bản ghi kiểm toán.

## 💬 NGUYÊN TẮC 5: QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG (MANDATORY ERROR & ENUM RULES)
1. **Ngôn ngữ (100% English)**: Toàn bộ thông báo lỗi, exception details, problem details, validation failures viết bằng 100% tiếng Anh. Tuyệt đối CẤM tiếng Việt trong response và runtime exception.
2. **Quy cách viết hoa thông báo lỗi (100% Sentence case)**:
   - Viết hoa DUY NHẤT chữ cái đầu tiên của câu thông báo.
   - Toàn bộ các từ tiếp theo viết thường, TRỪ các từ viết tắt kỹ thuật hoặc tên riêng: `ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`, `API`, `HTTP`.
   - TUYỆT ĐỐI CẤM viết hoa toàn bộ thông báo (ví dụ cấm: `"WALLET NOT FOUND"`, `"INVALID INPUT"`).
   - TUYỆT ĐỐI CẤM dùng Title Case (ví dụ cấm: `"Wallet Not Found Provided"`).
   - Ví dụ đúng: `"Wallet account not found for the specified user."`, `"Insufficient balance to complete the transaction."`, `"Email is already registered in the system."`
3. **Mã lỗi (100% SCREAMING_SNAKE_CASE)**:
   - Viết hoa toàn bộ và nối bằng gạch dưới: `WALLET_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `OTP_INVALID`, `VAL_INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`.
   - CẤM tự ý thêm tiền tố `ERR_` bừa bãi (ví dụ cấm: `ERR_INVALID_CREDENTIALS`, `ERR_SOD_VIOLATION` -> sửa thành: `INVALID_CREDENTIALS`, `SOD_VIOLATION`).
   - Tiền tố `VAL_` chỉ dành riêng cho lỗi validation dữ liệu đầu vào (ví dụ: `VAL_INVALID_INPUT`, `VAL_INVALID_EMAIL`, `VAL_INVALID_ARGUMENT`).
4. **Quy chuẩn Tuần tự hóa Enum đầu ra REST API (PascalCase Serialization)**:
   - 100% giá trị Enum trả về trong JSON Response (`ApiResponse<T>` hoặc `PagedData<T>`) BẮT BUỘC là chuỗi **PascalCase** (`"Active"`, `"PendingVerification"`, `"Delivered"`, `"Payment"`).
   - TUYỆT ĐỐI CẤM trả về chuỗi viết hoa toàn bộ (`"ACTIVE"`, `"PENDING"`, `"DELIVERED"`, `"PAYMENT"`) hoặc số nguyên thô (`0`, `1`, `2`) trong payload response.

## 🎯 NGUYÊN TẮC 6: ĐIỀU KIỆN HOÀN THÀNH NHIỆM VỤ (DEFINITION OF DONE)
- [ ] Đã lập Plan chi tiết trước khi thực hiện.
- [ ] Tuân thủ nguyên tắc Inward-Only.
- [ ] `dotnet build <Solution>.sln -c Release` thành công 100% (0 error).
- [ ] `dotnet test <Solution>.sln -c Release` vượt qua 100% kiểm thử.
- [ ] Đã hoàn thiện tài liệu hóa API vào file tương ứng kèm đầy đủ: mô tả, validation, ma trận mã lỗi tiếng Anh và checklist trạng thái hoàn thành.
- [ ] Git sạch, không commit file rác (`bin/`, `obj/`, `.vs/`).

## 🧪 NGUYÊN TẮC 7: HIỆN TRẠNG HỆ THỐNG & ĐIỀU KIỆN BẮT ĐẦU
Chi tiết audit: `docs/agents/system-audit.md`, `docs/plans/SCORECARD.md`, `docs/plans/FIX_BACKLOG.md`.
- Code nghiệp vụ mới CHỈ bắt đầu sau khi hoàn tất Track S trong `docs/plans/SETUP_PHASE_PLAN.md`.
- Mọi tài liệu khi sửa phải có banner trạng thái theo `docs/plans/DOC_UPDATE_PROTOCOL.md`.
- Không coi `/health` là bằng chứng service hoạt động vì không kiểm tra DB.

## 📝 NGUYÊN TẮC 8: QUY CHUẨN ĐÓNG PHIÊN, BÁO CÁO & LƯU TRỮ KẾ HOẠCH
Tuân thủ quy trình đầu/cuối phiên chi tiết tại `docs/agents/session-protocol.md`.
1. **Lưu trữ Kế hoạch**: Ghi tại `.agents/plan/PLAN-YYYYMMDD-HHMM-[TEN_VAN_DE].md` (Mục tiêu, Hướng giải quyết, Checklist).
2. **Báo cáo Nhật ký**: Ghi tại `.agents/history/YYYY-MM-DD_session_summary.md` (Tổng thể, Nghiên cứu, Link Plan, Báo cáo cá nhân, Báo cáo toàn team).

## 📌 NGUYÊN TẮC 9: CƠ CHẾ DUY TRÌ & CẬP NHẬT RULE BỀN VỮNG (PERSISTENT "GHI VÀO RULE" TRIGGER)
Bất cứ khi nào Người dùng (Sếp) chỉ thị *"ghi vào rule"*, *"thêm vào rule"*, hoặc yêu cầu chuẩn hóa quy chuẩn kỹ thuật:
1. AI Coding Agent **BẮT BUỘC PHẢI LẬP TỨC GHI NHẬN VÀ ĐỒNG BỘ** vào:
   - `.agents/AGENTS.md`
   - Root `AGENTS.md`
   - `.cursor/rules/` (`error-handling.mdc`, `api-standards.mdc`, `agent-mission-protocol.mdc`)
   - Tất cả các file `AGENTS.md` và `specs/00_AGENT_MISSION_GUARDRAILS.md` của các submodule liên quan (`src/Services/{Service}/`).
2. Tuyệt đối không được bỏ qua hay trì hoãn việc cập nhật các file rule này, đảm bảo mọi AI Agent trong các phiên làm việc tiếp theo luôn kế thừa đầy đủ và tuân thủ 100%.
Tuân thủ quy trình đầu/cuối phiên chi tiết tại `docs/agents/session-protocol.md`.
1. **Lưu trữ Kế hoạch**: Ghi tại `.agents/plan/PLAN-YYYYMMDD-HHMM-[TEN_VAN_DE].md` (Mục tiêu, Hướng giải quyết, Checklist).
2. **Báo cáo Nhật ký**: Ghi tại `.agents/history/YYYY-MM-DD_session_summary.md` (Tổng thể, Nghiên cứu, Link Plan, Báo cáo cá nhân, Báo cáo toàn team).

<!-- super-board:begin v3.1.2 (managed; edits inside are overwritten on upgrade) -->
## Super Board

Board: Backlog · Ready · Building · QA · Review · Blocked · Done. Labels route: `qa` skips Building · `bug`, `feature`, none → built first.

| When | Use | NEVER |
|---|---|---|
| Set up / repair the board | `/super-board onboard` | DON'T hand-edit config mid-run |
| Check tickets before a run | `/super-board lint` | NEVER run with AC-less tickets |
| Drain the board | `/super-board run` | NEVER build, test or merge from the orchestrator |
| Board state / halt | `/super-board status` · `/super-board stop` | |
| Build one ticket | `/super-build` | NEVER build outside the card's worktree |
| QA a branch, or a live URL alone | `/super-qa` · `/super-qa <url>` | NEVER mark QA pass without evidence |
| Review a PR, merge | `/super-review` | NEVER `gh pr merge` direct — merge gate only |
| File bugs from Sentry, PostHog, PRs | `/super-collect` | DON'T file without a verifier pass |
| UI polish | `/ui-refine-loop` (human runs it) | board NEVER runs it |
| Diagram / explainer page | `/visual` | |
| Commit, pull, push this branch | `/git-sync` | NEVER force push or rebase shared history |

| Rule | Value |
|---|---|
| Config | `.claude/super-board/configs/<slug>.json` |
| Isolation | 1 card · 1 worktree · 1 branch |
| Merge | auto for normal changes · money, auth, destructive schema (DROP/TRUNCATE/RENAME) → human · PR > 400 changed lines → human |
| Migrations | additive → robot migrates allowed DBs only · live DB ALWAYS → 🙋 needs you |
| Blocked card | block-template comment · last line `blocked-by:` · 🙋 = needs you |
| Secrets | NEVER read `.env`; key names via `.claude/bin/super-board-env-check.sh` |

## Writing (super-board)

| Thing | Format → `.claude/skills/super-board/references/writing-standard.md` |
|---|---|
| Commit, PR title | `<emoji> [type] scope: subject` + short bullets · ✨ feat 🐛 fix 🔧 chore ♻️ refactor 🧪 test 📝 docs |
| PR body | blocks: status · Problem · Solution · AC + proof · history · Before\|After · Risk — `super-board-pr-body.sh` |
| Ticket | Problem · Context · Fix · AC · Risk · Blocked by → `docs/agents/issue-tracker.md` |
| Comment | `[role] [label] status` · Did · ✅ Done · ❌ Not done · Next · ≤ 8 lines |
| PR author notes | file + critical inline review comments: Purpose · What changed · Why it matters → `pr-author-notes.md` |

- NEVER chain steps with arrows. One step per line, lettered under Where.
- NEVER link screenshots. Embed a raw URL pinned to a sha.
- DON'T repeat file lists in status comments. DON'T write "Not verified" or "Next" in a PR body.
<!-- super-board:end -->
