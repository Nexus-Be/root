# AUDIT — ApiGateway (`src/Services/ApiGateway`)

- **Branch:** `mock` · **Commit:** `efb840d` · **Dirty:** 0 (trước audit) → 2 (`AGENTS.md`, `CLAUDE.md` do re-index)
- **Quy mô:** 98 file `.cs` / 7.468 LOC · `Nexus.Gateway` 79 file (5.456 LOC) + `Nexus.Gateway.Tests` 19 file (2.012 LOC)
- **Port:** HTTP `8080` (khớp `specs/01_SERVICE_CATALOG_PORT_MAP.md`, đổi từ 8000 tránh xung đột Portainer) · **DB:** không có (đúng bounded context)
- **Index:** 150 file / 1.252 symbol / 2.601 edge / **100 execution flow**

## 1. Kết luận nhanh (TL;DR)

Gateway **là phần duy nhất của hệ thống thực sự “chạy được”** về mặt khung: pipeline Mock/Real, dispatcher, trace header, rate-limit, health-prober, response envelope đều có code thật và có 25 file test (62 `[Fact]`).

Nhưng nó **chưa phải gateway của hệ thống microservice** vì:

1. **11/15 controller là file rỗng 10 dòng** — không có một Action nào (`ProductsController.cs:1-10` chỉ có comment `// TODO (Team)`). Toàn bộ `catalog`, `commerce`, `auction`, `fulfillment`, `notification`, `wallet`, `log`, `cart`, `orders`, `inventory`, `admin users` **không có endpoint**.
2. **Chỉ 1 backend được nối thật**: `GrpcClientsExtension.cs:12` đăng ký duy nhất `UsersApiClient`; `shop.proto` chỉ khai báo `UsersApi` (5 rpc). 7 service còn lại cấu hình `Mode: "Real"` trong `appsettings.json` nhưng **không có client để gọi** → “Real” là cấu hình chết.
3. **Login chết end-to-end**: gateway `AuthController.cs:120` gọi `_client.LoginAsync`, nhưng `UsersGrpcService` **không override `Login`** (chỉ có `Register`, `VerifyOtp`, `ResendOtp`, `GetProfile`) → gRPC trả `UNIMPLEMENTED`. Không có user nào đăng nhập được.
4. **Secret JWT nằm trong file tracked**: `appsettings.json:26` `"Signature": "$d)aam<...JN%eZ"`.
5. **Tài liệu phân mảnh**: 6 file `.md` lạc ở root repo (68 KB `dac_ta.md`, 15 KB `ADR.md`, 15 KB `CONFIG_REFERENCE.md`, 12 KB `SETUP_GUIDE_SERVICES.md`, 7 KB `PLAN.md`, 1,4 KB `input.md`) song song với `specs/` 6 file — hai nguồn “sự thật” cạnh tranh.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ⚠️ | 15 thư mục tách bạch rõ (`Dispatching/`, `MockEngine/`, `HealthProber/`, `Responses/`…), nhưng 11 controller rỗng → dev mới mở ra không biết viết gì, không có mẫu hoàn chỉnh ngoài `AuthController` |
| C2 | Dễ sửa, ít phụ thuộc | ✅ | `GatewayDispatcher` phụ thuộc interface (`IModeEvaluator`, `IMockDataMapper`, `IGrpcServiceCaller`, `IApiResponseFactory`) — blast radius thấp, 0 coupling chéo service |
| C3 | File đúng folder, liên kết đồng nhất | ⚠️ | Code đúng chỗ; **doc sai chỗ** (6 md lạc root); `shop.proto` lệch hash với User/Log/Wallet |
| C4 | Test/chạy độc lập từng phần | ⚠️ | 62 `[Fact]` pass, `dotnet test` exit 0; nhưng chỉ test được **users + mock engine**, 7 service khác không có bề mặt để test |
| C5 | Theo dõi request | ⚠️ | Có `x-trace-id` outbound (`GrpcServiceCaller.cs:88`), `ActivitySource "Nexus.Gateway.Backend"`; nhưng **backend không đọc lại header** → trace đứt ở hop 1 (xem `13_RULES_AND_HYGIENE_AUDIT.md`) |
| C6 | Doc đúng chỗ, là sự thật | ❌ | `specs/02_GATEWAY_CONTROLLERS_ROUTING.md` liệt kê 15 controller như thể đã có API, thực tế 11 file không có Action; `PLAN.md`/`dac_ta.md` mô tả trạng thái không tồn tại |
| C7 | Luật đúng | ❌ | Rule “port bất biến” OK; rule “error message 100% English” bị vi phạm 3 chỗ (`ValidationHelpers.cs:23,29`, `MoneyPrecision.cs:18`); secret hardcode |
| C8 | Format đồng nhất | ⚠️ | Cùng 4-layer + `.gitignore` giống 8 service; nhưng là repo **duy nhất** có `global.json`, `run-dev.sh/.ps1`, `logs/`, `nuget` không có, `README` khác hệ |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| GW-01 | **P0** | 11/15 controller rỗng, không Action | `Controllers/{Products,Categories,Cart,Orders,Inventory,Auction,Fulfillment,Notification,Wallet,Log,AdminUsers}Controller.cs` — mỗi file 10 dòng, `[Http*]` = 0 | Viết action theo mẫu `AuthController` + `MOCK_GUIDE.md`, hoặc xoá route khỏi Swagger cho tới khi làm |
| GW-02 | **P0** | Chỉ 1/8 backend có gRPC client | `Extensions/GrpcClientsExtension.cs:12` — `AddNamedGrpcClient<UsersApi.UsersApiClient>("users")` duy nhất | Bổ sung 8 service vào `shop.proto` rồi đăng ký client |
| GW-03 | **P0** | `Login` rpc khai báo nhưng không impl | `Contracts/shop.proto:11` `rpc Login` ↔ `User.Api/Services/UsersGrpcService.cs` chỉ 4 override; grep `LoginRequest` trong repo User = **0 hit** | Implement `Login` trong `UsersGrpcService` (phát JWT) hoặc bỏ rpc + endpoint |
| GW-04 | **P1** | JWT signing key hardcode trong appsettings tracked | `Nexus.Gateway/appsettings.json:26` | Đưa về `JWT__SIGNATURE` env / user-secrets; rotate key |
| GW-05 | **P1** | 6 doc lạc root, trùng chức năng `specs/` | `dac_ta.md` 68 KB, `ADR.md`, `PLAN.md`, `input.md`, `SETUP_GUIDE_SERVICES.md`, `CONFIG_REFERENCE.md` | Chuyển vào `specs/`/`docs/`, hoặc xoá nếu đã bị `specs/` thay thế; giữ 1 nguồn |
| GW-06 | **P1** | Branch `mock` ≠ 8 service (`dev`) | `.git` HEAD; `.gitmodules` không khai báo `branch` | Merge `mock`→`dev` hoặc khai báo `branch = dev` trong `.gitmodules` |
| GW-07 | **P1** | `specs/02_GATEWAY_CONTROLLERS_ROUTING.md` không phản ánh thực tế | spec mô tả 15 controller có API; 11 file 0 action | Thêm cột “Trạng thái: stub/implemented” hoặc cập nhật spec |
| GW-08 | **P1** | 3 error message tiếng Việt | `Common/ValidationHelpers.cs:23` `"{field} phải là UUID"`, `:29` `"{field} là bắt buộc"`, `Common/MoneyPrecision.cs:18` `"{field} phải là số > 0"` | Dịch sang English sentence case theo `AGENTS.md` Nguyên tắc 5 |
| GW-09 | **P2** | `logs/` sinh runtime trong repo, `run-dev.*` ở root | `logs/health/*`, `run-dev.sh`, `run-dev.ps1` | Gitignore `logs/`, chuyển script vào `.tools/` |
| GW-10 | **P2** | `Production` appsettings? thiếu cấu hình môi trường | chỉ `appsettings.json` + `appsettings.Development.json` | Thêm `appsettings.Production.json` hoặc tài liệu hoá env-only |

## 4. Điểm mạnh cần giữ

- `GatewayDispatcher.DispatchAsync` là **một điểm cắt duy nhất** cho Mock/Real + response envelope + timeout + health gate → mọi Action mới chỉ cần 1 dòng gọi dispatcher. Đây chính là “format chung” mà 8 service còn thiếu.
- `GrpcServiceCaller.BuildCallOptions` propagate `authorization`, `idempotency-key`, `x-trace-id`, `x-user-id`, `x-user-roles`, `x-user-email` — mẫu chuẩn để copy sang HTTP client nếu sau này cần.
- `Nexus.Gateway.Tests` (19 file, 2012 LOC, 62 fact) là **bộ test duy nhất đáng học** trong toàn hệ thống; nên nhân bản cấu trúc này cho 8 service.

## 5. Việc phải làm trước khi coi Gateway “xong”

1. `GW-03` (Login) — vì toàn bộ auth flow phụ thuộc.
2. `GW-02` + `GW-01` — dựng 1 service mẫu end-to-end (đề xuất `catalog`: 2 endpoint `GET /products`, `GET /products/{id}`) để chứng minh pattern Mock/Real chạy với backend thật.
3. `GW-04` + `GW-05` + `GW-07` — dọn secret và doc.
