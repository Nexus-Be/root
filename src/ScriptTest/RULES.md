# Danh mục Rule của ScriptTest

Mỗi rule ánh xạ trực tiếp tới một bất biến trong `AGENTS.md`, `specs/06_ARCHITECTURAL_INVARIANTS_AND_CONTRACT_SPECIFICATION.md`
hoặc `AGENTS.md` của từng service. Khi sửa rule, cập nhật cả bảng này và checker tương ứng.

## ENUM - Ranh giới tuần tự hóa Enum

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| ENUM-001 | ERROR | Mỗi `*.Api` phải đăng ký `PascalCaseJsonStringEnumConverter`; nếu dùng `ConfigureHttpJsonOptions` thì phải đăng ký trong đó | AGENTS.md - Enum Serialization Boundary Rule |
| ENUM-002 | ERROR | Cấm `JsonStringEnumConverter` built-in và `[JsonConverter(typeof(JsonStringEnumConverter))]` | AGENTS.md - Enum Boundary |
| ENUM-003 | ERROR | Cấm `HasConversion<string>`; enum lưu `int32` | AGENTS.md - Database Governance |
| ENUM-004 | ERROR | Member enum phải PascalCase, cấm `ACTIVE` / `active` | specs/06 |
| ENUM-005 | ERROR | Enum phải gán số tường minh và không trùng giá trị (alias) | specs/06 |
| ENUM-006 | WARN | Member enum nên khai báo giá trị số tường minh | specs/06 |
| ENUM-007 | WARN | Property `*Status/*Type/*State/*Role` trong Responses/Dtos không nên là `int` | AGENTS.md - Enum Boundary |
| ENUM-008 | WARN | Cấm `Enum.ToString().ToUpper...` | AGENTS.md - Enum Boundary |

## ERRC - Mã lỗi

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| ERRC-001 | ERROR | `errorCode` phải khớp `^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$` | AGENTS.md - Error Handling |
| ERRC-002 | ERROR | Cấm tiền tố `ERR_` | AGENTS.md - Error Handling |
| ERRC-003 | ERROR | Cùng một `errorCode` không được mang hai message khác nhau (miễn trừ `VAL_`) | specs/06 |
| ERRC-004 | WARN | `VAL_` chỉ dành cho lỗi validation đầu vào | AGENTS.md - Error Handling |
| ERRC-005 | WARN | `errorCode` phải là literal tĩnh, không nội suy/ghép chuỗi | specs/06 |
| ERRC-006 | ERROR | Mỗi `*.Api` phải map `VAL_INVALID_ARGUMENT` và `INTERNAL_SERVER_ERROR` | AGENTS.md - Error Handling |

## ERRS - Thông báo lỗi

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| ERRS-001 | ERROR | Message 100% tiếng Anh, không ký tự non-ASCII | AGENTS.md - Error Handling |
| ERRS-002 | ERROR | Chữ cái đầu tiên phải viết hoa | AGENTS.md - Error Handling |
| ERRS-003 | ERROR | Cấm viết hoa toàn bộ message | AGENTS.md - Error Handling |
| ERRS-004 | ERROR | Cấm Title Case; allowlist `ID, OTP, JWT, URL, UUID, Email, API, HTTP, VNPay, IP, SMTP, TTL, GUID` | AGENTS.md - Error Handling |
| ERRS-005 | ERROR | Cấm khoảng trắng đầu/cuối và khoảng trắng lặp | AGENTS.md - Error Handling |
| ERRS-006 | WARN | Message nên kết thúc bằng `.`, `?`, `!` | AGENTS.md - Error Handling |
| ERRS-007 | WARN | Message quá ngắn (< 5 ký tự) | AGENTS.md - Error Handling |

## ROUTE - Định tuyến và Controller

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| ROUTE-001 | ERROR | Đúng một `[Route("api/v1/...")]`, không `/` cuối, không alias | AGENTS.md - REST API & Routing |
| ROUTE-002 | ERROR | Danh từ collection phải số nhiều; ngoại lệ `auth`, `me`, `health`, `healthcheck`, `vnpay`, `otp`, `password` | AGENTS.md - REST API & Routing |
| ROUTE-003 | ERROR | Controller phải nằm trong `Controllers/Public/`; không tạo `Controllers/Internal/` | AGENTS.md - Internal API tạm khóa |
| ROUTE-004 | ERROR | Route công khai không được chứa `/api/v1/internal` | AGENTS.md - Internal API tạm khóa |
| ROUTE-005 | ERROR | Mỗi action chỉ một HTTP verb attribute | AGENTS.md - No Duplicate Route Aliases |
| ROUTE-006 | ERROR | Không trùng cặp `(verb, full path)` trong cùng service | AGENTS.md - No Duplicate Route Aliases |
| ROUTE-007 | WARN | Route có tham số `{...id...}` phải kiểm tra quyền sở hữu | AGENTS.md - Resource Ownership |

## ARCH - Kiến trúc

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| ARCH-001 | ERROR | `*.Domain.csproj` không có `PackageReference` | AGENTS.md - 4-Layer Clean Architecture |
| ARCH-002 | ERROR | Cấm `IRepository<T>`, `GenericRepository`, `UnitOfWork` | AGENTS.md - Absolute Prohibitions |
| ARCH-003 | ERROR | MediatR/CQRS chỉ trong WalletService | AGENTS.md - Wallet exception |
| ARCH-004 | ERROR | Cấm gRPC, `.proto`, MassTransit, RabbitMQ, Outbox/Inbox, Saga | AGENTS.md - Absolute Prohibitions |
| ARCH-005 | ERROR | Controller không được tham chiếu `DbContext` | AGENTS.md - Thin 1-to-1 Controller |
| ARCH-006 | ERROR | Controller phải inject `I*Service` hoặc `I*Manager` (Wallet miễn trừ: `ISender`) | AGENTS.md - Thin 1-to-1 Controller |
| ARCH-007 | ERROR | `ProjectReference` không được rời khỏi service sở hữu | AGENTS.md - Inward-Only Scoping |
| ARCH-008 | WARN | `Application/Services/{Feature}` đủ contract, implementation, Requests, Responses | AGENTS.md - Feature Co-Location |
| ARCH-009 | ERROR | Kết quả `Wallet/scripts/verify-wallet-architecture.sh` phải pass | Wallet AGENTS.md - Architecture Freeze |

## DB - Quản trị cơ sở dữ liệu

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| DB-001 | ERROR | Cấm `HasConversion<string>` | AGENTS.md - Database Governance |
| DB-002 | ERROR | `HasData` không dùng `Guid.NewGuid()` | AGENTS.md - Seed Data Standards |
| DB-003 | ERROR | Cấm `EnsureCreated()`; phải dùng migration (miễn trừ test) | AGENTS.md - Migration Lifecycle |
| DB-004 | WARN | Entity có `decimal` phải cấu hình `HasPrecision(18, 2)` | AGENTS.md - Currency Precision |
| DB-005 | WARN | Entity có `IsDeleted` phải có `HasQueryFilter` | AGENTS.md - Soft Delete |
| DB-006 | WARN | Hạn chế `DeleteBehavior.Cascade` | AGENTS.md - Foreign Keys |
| DB-007 | ERROR | Connection string phải đúng port (5433-5440) và đúng database của service | AGENTS.md - Database Isolation |

## GW - Gateway biên

| ID | Mức | Nội dung | Nguồn |
|:---|:---:|:---|:---|
| GW-001 | ERROR | Gateway bắt buộc chạy port `8080` | Gateway AGENTS.md - Port invariant |
| GW-002 | ERROR | Gateway không có `DbContext`, EF Core, Npgsql | Gateway AGENTS.md - Stateless |
| GW-003 | ERROR | Route proxy phải bắt đầu `/api/v1/`, không chứa `internal` (trừ `/health`, `/swagger`) | Gateway AGENTS.md - Routerules |
| GW-004 | ERROR | Route proxy không dùng segment số ít | Gateway AGENTS.md - Plural routes |
| GW-005 | ERROR | Cấm `api/v1/admin/{**catch-all}` duy nhất | Gateway AGENTS.md - Admin route split |
| GW-006 | ERROR | Pipeline phải giữ `ClientContext`, `GlobalException`, `ResponseEnvelope`, `IdempotencyGuard`, `AdminAuthorizationGuard` và `AddIdentityPropagation` | Gateway AGENTS.md - Pipeline |
| GW-007 | ERROR | `ClientContextMiddleware` phải chặn 7 header giả mạo, trả `FORBIDDEN_HEADER_SPOOFING`, và chặn `/api/v1/internal` | Gateway AGENTS.md - Anti-Spoofing |
| GW-008 | ERROR | Gateway không khai báo container Redis riêng | Gateway AGENTS.md - Shared Redis |
| GW-009 | WARN | Phải tồn tại `Gateway.Tests/ArchitecturalContractInvariantTests.cs` | specs/06 |
