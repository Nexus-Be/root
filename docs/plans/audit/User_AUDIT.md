# AUDIT — User (`src/Services/User`)

- **Branch:** `dev` · **Commit:** `f65d2f1` · **Dirty:** 10 file (`Migrations` ×3 deleted + 1 mới untracked, `UserSeedData.cs`, `AGENTS.md`, `CLAUDE.md`)
- **Quy mô:** 65 file `.cs` / 2.434 LOC · Infrastructure 949 · Domain 521 · Application 374 · Api 324 · Tests 266
- **Port:** HTTP/gRPC `8001` ✅ (Dockerfile + `ASPNETCORE_URLS` + launchSettings đều khớp) · **DB:** `5433` `user_db` ✅
- **Index:** 92 file / 618 symbol / 971 edge / 16 flow (nhiều flow thứ 2 hệ thống)

## 1. Kết luận nhanh

Đây là service **trưởng thành nhất** của backend: 4 tầng sạch, 14 DbSet ↔ 14 bảng `user.dbml`, có gRPC server thật (4 method), có test project (9 fact), có RabbitMQ publish (`SendOtpEmailIntegrationEvent`), seed role mặc định.

Nhưng nó **không thể là “User service của một hệ thống có auth”** vì:

1. **Không có logic đăng nhập và không có nơi phát hành JWT.** `IAuthService` chỉ có `RegisterAsync`, `VerifyOtpAsync`, `ResendOtpAsync` (`User.Application/Services/Auth/IAuthService.cs:9-11`); grep `Jwt|Token|Login` toàn repo = **0 chỗ sinh token** (chỉ có entity `RefreshToken` chưa dùng). Gateway thì validate JWT bằng key hardcode → **không client nào lấy được token hợp lệ**.
2. **`rpc Login` có trong `shop.proto:52` nhưng `UsersGrpcService` không override** → gọi vào trả `UNIMPLEMENTED` (500/501).
3. **Spec hứa 11 rpc, thực tế 4** → `specs/02_API_GRPC_CONTRACTS.md` là tài liệu *mong muốn*, không phải *hiện trạng*.
4. **Không có OTel** → `AuditLog.TraceId` (`User.Domain/Entities/AuditLog.cs:9`) sẽ ghi ID cục bộ, không nối được với `x-trace-id` của Gateway.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ✅ | `Application/Services/Auth/{IAuthService,AuthService,AuthDtos}.cs` tách đúng; Domain 34 file entity/enum/exception độc lập; Api chỉ 3 file |
| C2 | Dễ sửa, ít phụ thuộc | ✅ | Application phụ thuộc `IUserDbContext` (interface) chứ không phụ thuộc EF cụ thể; 0 tham chiếu chéo service |
| C3 | File đúng folder | ✅ | 14 DbSet ↔ 14 entity ↔ 14 bảng dbml, không thừa/thiếu |
| C4 | Test/chạy độc lập | ⚠️ | Có `User.Tests/AuthServiceTests.cs` (9 fact) nhưng **chỉ phủ Register/VerifyOtp/ResendOtp**, 0 test cho 4 gRPC method, 0 test cho consumer/publisher |
| C5 | Theo dõi request | ❌ | Không `AddOpenTelemetry`; `GlobalExceptionHandlerMiddleware.cs:34` dùng `Activity.Current ?? context.TraceIdentifier` → trace id không đến từ Gateway |
| C6 | Doc là sự thật | ❌ | `specs/02` hứa 11 rpc (`Login, CreateUser, ListUsers, AssignRoles, ListRoles, ListPermissions, ApproveSeller, RequestSellerUpgrade, UpdateProfile, GetProfile, Register`), code có 4 |
| C7 | Luật đúng | ✅ | Không dùng Repository pattern (dùng `IUserDbContext` trực tiếp), error message English, error code SCREAMING_SNAKE |
| C8 | Format đồng nhất | ⚠️ | `nuget.config` ở root repo (chỉ User + Notification có) |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| US-01 | **P0** | **Không có login, không có phát hành JWT** — toàn hệ thống không thể authenticate thật | `IAuthService.cs:9-11` không có `LoginAsync`; `grep -r "JwtSecurityToken\|GenerateToken" src/Services/User` = 0; `csproj` không có `System.IdentityModel.Tokens.Jwt` | Thêm `LoginAsync` (BCrypt verify `PasswordHash`) + `ITokenService` phát access/refresh token; map `Login` rpc; test 1 flow login |
| US-02 | **P0** | `rpc Login` khai báo nhưng không implement | `User.Api/Contracts/shop.proto:52` ↔ `UsersGrpcService.cs` 4 override | Gộp với US-01 |
| US-03 | **P1** | Spec 11 rpc vs code 4 (chênh 7) | `specs/02_API_GRPC_CONTRACTS.md` | Đánh dấu rpc “planned/implemented” trong spec, hoặc cắt spec về đúng hiện trạng |
| US-04 | **P1** | Không OTel, không đọc `x-trace-id` inbound | không có `AddOpenTelemetry`; `GlobalExceptionHandlerMiddleware.cs:34` | `AddOpenTelemetry` + `ServerCallContextInterceptor` đọc metadata `x-trace-id` → `Activity.Current` |
| US-05 | **P1** | `AuditLog.TraceId` tồn tại nhưng không được set từ request | `User.Domain/Entities/AuditLog.cs:9`; không chỗ nào gán từ header | Gán trong interceptor/`SaveChanges` interceptor |
| US-06 | **P1** | Test chỉ phủ 3/8 hành vi; 0 test gRPC | `User.Tests/AuthServiceTests.cs` (266 LOC, 9 fact) | Thêm test cho `GetProfile`, `Login`, consumer event |
| US-07 | **P2** | Migrations bị regenerate thành 1 file `20261024103058_InitialUserSchema` (mất lịch sử 3 migration: `InitialUserSchema`, `SeedDefaultRoles`, `AddMassTransitOutboxInboxTables`), **chưa commit** | `git status`: 3× `D` + 1× `??` | Commit bộ migration mới (đã gộp đủ InboxState/OutboxMessage + 6 `InsertData` role) hoặc revert và giữ lịch sử |
| US-08 | **P2** | `nuget.config` chỉ có ở User/Notification | `src/Services/User/nuget.config` | Chuẩn hoá: hoặc có ở tất cả, hoặc bỏ (dùng NuGet.config mặc định) |
| US-09 | **P2** | `IUserDbContext` nằm ở Application nhưng expose toàn bộ `DbSet` | `User.Application/Interfaces/IUserDbContext.cs:11` | Chấp nhận được (đúng luật “no repository”), nhưng nên gom về `Persistence` contract |

## 4. Điểm mạnh

- Cấu trúc `Application/Services/Auth/` (interface + impl + DTO cùng folder) là **mẫu tốt nhất** trong 8 service để nhân bản — dễ tìm, dễ test, 1 folder = 1 use case.
- `UserSeedData.cs` + `SeedDefaultRoles` (nay nằm trong Initial) cho thấy có quan tâm RBAC seed.
- `Password` hash bằng BCrypt (`BCrypt.Net-Next`) — đúng, không tự chế.

## 5. Việc phải làm trước khi coi User “xong”

1. `US-01` + `US-02` — login + JWT (đường găng của toàn hệ thống).
2. `US-04` + `US-05` — trace xuyên service.
3. `US-07` — chốt migration rồi commit để `git status` sạch.
