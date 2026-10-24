# FIX_BACKLOG — Nexus-Be (sau audit)

**Cách dùng:** mỗi mục có `Files` (đường dẫn thật), `Change` (làm gì), `Accept` (kiểm bằng gì — phải chạy được), `h` (giờ công), `Dep` (phải xong trước).
**Quy ước:** P0 = chặn “hệ thống là một hệ thống”; P1 = chặn mục tiêu bạn nêu; P2 = chất lượng/đồng nhất.
**Trước khi sửa bất kỳ symbol nào:** chạy `impact({target:"<symbol>", direction:"upstream"})` theo `AGENTS.md` §1 (sau khi re-index).

Tổng: **31 mục — P0 14 · P1 8 · P2 9 ≈ 60–70 giờ** (không tính viết nghiệp vụ mới).

---

## WAVE 0 — Gỡ bế tắc (1.5 ngày) · phải xong trước mọi thứ khác

| ID | Sev | Repo/Files | Change | Accept | h | Dep |
|---|---|---|---|---|---|---|
| **FIX-001** | P0 | `src/Services/{8 service}/**/Migrations/` | Commit migration regenerated: mỗi repo `git add -A .../Migrations` + `.../AppDbContext.cs` + `Persistence/Seeds/*.cs`; **review schema diff trước** (User: kiểm 3 migration cũ bị gộp có mất `Outbox/Inbox` không) | `node .tools/audit/audit.py --gate format` sạch; `git -C <repo> status --porcelain` = 0 | 4 | — |
| **FIX-002** | P0 | `contracts/proto/shop.proto` *(mới, root)* + 4 bản copy | Tạo 1 proto chuẩn ở **root** từ bản đầy đủ nhất (Log/Wallet `8a7d8698…` hoặc User `af33177…` — chọn bản có `CreateUser`), thêm `scripts/sync-proto.sh` copy xuống `ApiGateway/Nexus.Gateway/Contracts/`, `User|Log|Wallet/*.Api/Contracts/`; sửa `specs/04_SHARED_CONTRACTS_REGISTRY.md` | `md5sum` 4 bản giống nhau; `specs/04` trỏ về `contracts/proto/` | 3 | — |
| **FIX-003** | P0 | `.gitmodules` | Thêm `branch = dev` cho 8 service, `branch = mock` cho ApiGateway (hoặc đổi Gateway về `dev` nếu `mock` chỉ là thử nghiệm) | `git submodule update --remote --dry-run` đúng nhánh | 1 | user quyết nhánh |
| **FIX-004** | P0 | `ApiGateway/Nexus.Gateway/appsettings.json:26`, `appsettings.Development.json:25` | Bỏ khoá JWT thật; đọc từ `Jwt:Signature` env/secret; rotate key; `.gitignore` `appsettings.Development.json` (giữ `.example`) | `grep -rn 'Signature": "\$d)'` = 0 | 1 | — |
| **FIX-005** | P0 | 18 `.env(.example)` + `docker-compose*.yml` | Thay `MatkhaucuaTui123@` bằng `CHANGE_ME` trong example; compose dùng `${POSTGRES_PASSWORD:?}` / `${RABBITMQ_PASSWORD:?}` | `grep -rl 'MatkhaucuaTui123@'` chỉ còn `.env` (ignored) | 1.5 | — |
| **FIX-006** | P0 | `specs/02`, `specs/04`, `docs/adr/ADR.md` | Cập nhật đúng **hiện trạng**: `specs/04` event bảng thêm cột `Status: implemented/planned`; `specs/02` tách `AS-IS` / `TO-BE`; thêm `ADR-033` (proto SoT), `ADR-034` (ai phát JWT), `ADR-035` (kho thuộc Fulfillment) | Đọc `specs/02` không còn câu nào sai sự thật; `*.md` link nội bộ đúng | 3 | FIX-002 |

## WAVE 1 — Mở mặt tiền cho 5 service (2.5 ngày)

> Mẫu chuẩn: **Catalog** (ít entity, Gateway đã có `ProductsController` stub). Làm Catalog xong, lặp lại cho 4 service còn lại.

| ID | Sev | Repo/Files | Change | Accept | h | Dep |
|---|---|---|---|---|---|---|
| **FIX-010** | P0 | `Catalog/Catalog.Api/Program.cs:60`, `Catalog.Api/Services/CatalogGrpcService.cs` *(mới)* | Thêm `MapGrpcService<CatalogGrpcService>()` + 4 rpc lõi: `ListProducts, GetProduct, CreateProduct, UpdateProduct` (gọi `ProductService`) | `grpcurl -plaintext localhost:8002 list` thấy `CatalogApi`; gọi `GetProduct` trả 1 product | 4 | FIX-002 |
| **FIX-011** | P0 | `ApiGateway/Nexus.Gateway/Extensions/GrpcClientsExtension.cs:12`, `Controllers/ProductsController.cs` | Thêm `AddNamedGrpcClient<CatalogApi.CatalogApiClient>("catalog")` + 4 action (`GET products`, `GET products/{id}`, `POST`, `PUT`) dùng `GatewayDispatcher.DispatchAsync` | `curl localhost:8000/api/v1/catalog/products` → 200 + `X-Gateway-Mode: Real` | 3 | FIX-010 |
| **FIX-012** | P0 | `Auction|Commerce|Fulfillment|Notification` — tương tự FIX-010 | Mỗi service 3 rpc tối thiểu theo `specs/02`: Auction `ListAuctions/GetAuction/PlaceBid`; Commerce `GetCart/CreateOrder/ListOrders`; Fulfillment `GetInventory/CalculateShippingFee/GetShipmentTracking`; Notification `ListNotifications/GetPreferences/UpdatePreferences` | `grpcurl` từng port `8003/8005/8006/8007` list được service | 12 | FIX-002 |
| **FIX-013** | P0 | 6× `*/Api/Properties/launchSettings.json` | Sửa `applicationUrl` về đúng port: Auction `8005`, Catalog `8002`, Commerce `8003`, Fulfillment `8006`, Log `8004`, Wallet `8008` (bỏ profile thừa, xoá BOM UTF-8) | `python .tools/audit/audit.py --gate port` = 0 finding | 1.5 | — |
| **FIX-014** | P1 | `User/User.Api/Services/UsersGrpcService.cs`, `User.Application/Services/Auth/*` | Quyết định `Login`: hoặc implement (`IAuthService.LoginAsync` + phát JWT + thêm `System.IdentityModel.Tokens.Jwt`), hoặc xoá `rpc Login` khỏi proto. Không để `UNIMPLEMENTED` âm thầm | `grpcurl ... UsersApi/Login` trả token **hoặc** proto không còn `Login` | 6 | FIX-002 |
| **FIX-015** | P1 | `Log/Log.Api/Program.cs:66`, `Nexus.Gateway/Logging/GatewayBatchLogSink.cs:55` | Thêm `MapPost("/api/v1/log/batch", ...)` nhận mảng log → ghi `LogEntry`; bỏ `catch {}` ở sink (log warning + đếm fail) | `curl -XPOST localhost:8004/api/v1/log/batch` → 202; Grafana/Log thấy bản ghi | 3 | — |

## WAVE 2 — Quan sát & lỗi (1 ngày)

| ID | Sev | Repo/Files | Change | Accept | h | Dep |
|---|---|---|---|---|---|---|
| **FIX-020** | P0 | 6 service `Program.cs` | Thêm `AddOpenTelemetry` (như Wallet) + `ActivitySource("Nexus.<S>")` + middleware/`Activity` đọc `x-trace-id` từ metadata | Trace 1 request Gateway→Catalog thấy **1 trace id** xuyên 2 service trong Tempo | 6 | FIX-010..012 |
| **FIX-021** | P0 | `Wallet.Application/Consumers/StockReservedConsumer.cs:32,49,93`; `Wallet.Domain/.../WalletAccount.cs:23,32,44`; `Wallet.Api/Services/WalletGrpcService.cs:31,51,61,71,89,99,117`; `ApiGateway/.../Common/ValidationHelpers.cs:23,29`; `Common/MoneyPrecision.cs:18`; `Log.Api/.../LogGrpcService.cs:70,74,122` | Dịch 19 chuỗi lỗi sang tiếng Anh, sentence case (giữ mã `*_*` SCREAMING_SNAKE) | `python .tools/audit/audit.py --gate errmsg` → 0 P0 | 2 | — |
| **FIX-022** | P1 | 3 chỗ ALL CAPS/Title Case trong ngữ cảnh lỗi | Sửa kiểu chữ | gate `errmsg` → 0 P1 | 0.5 | FIX-021 |
| **FIX-023** | P1 | `Notification.Infrastructure/Consumers/SendOtpEmailConsumer.cs:31-40` | Ghi `NotificationRecord` + `NotificationDelivery` (đang chỉ log) | Sau khi gửi OTP, bảng `Notifications` có 1 dòng | 2 | — |
| **FIX-024** | P1 | `Notification.Infrastructure/DependencyInjection.cs:33` | `UseMessageRetry` + `UseDelayedRedelivery` + DLQ config | Tắt SMTP → message retry → vào `_error` queue | 2 | — |

## WAVE 3 — Test & CI (2 ngày)

| ID | Sev | Repo/Files | Change | Accept | h | Dep |
|---|---|---|---|---|---|---|
| **FIX-030** | P0 | `{Auction|Catalog|Commerce|Fulfillment|Log|Wallet}.Tests/` *(mới)* | Tạo test project per service + ≥6 `[Fact]`/service cho use case rủi ro nhất: Auction `PlaceBid` (giá thấp, hết hạn, race); Commerce tổng tiền/voucher; Catalog update product; Fulfillment reserve/release (concurrent); Log `SetLogEventTypeEnabled`; Wallet balance âm | `dotnet test <S>.sln -c Release` 9/9 xanh | 12 | FIX-010..012 |
| **FIX-031** | P0 | 9× `.github/workflows/ci-cd.yml` | Thêm `branches: [main, dev, mock]`; thêm job `dotnet build -c Release` + `dotnet test` **trước** job image; fail ⇒ không push | Push thử 1 commit → CI chạy và đỏ khi test fail | 3 | — |
| **FIX-032** | P1 | `.github/workflows/audit.yml` *(mới, root)* | Chạy `.tools/audit/audit.py` (9 gate) + fail nếu có P0; upload `gates/*.json` làm artifact | PR mẫu bị chặn khi cố tình sai port | 2 | FIX-013 |
| **FIX-033** | P1 | `.github/workflows/` | Gom 9 CI thành **reusable workflow** ở root, 9 file chỉ `uses:` | Sửa 1 chỗ → 9 repo đổi hành vi | 2 | FIX-031 |

## WAVE 4 — Format & tài liệu (1.5 ngày)

| ID | Sev | Files | Change | Accept | h | Dep |
|---|---|---|---|---|---|---|
| **FIX-040** | P1 | `Directory.Build.props`, `.editorconfig` *(mới, root)* | Chung `Nullable`, `TreatWarningsAsErrors`, analyzer level, style rules | `dotnet build` 9/9 vẫn xanh; `dotnet format --verify-no-changes` sạch | 3 | — |
| **FIX-041** | P2 | `CLAUDE.md` (root + 9 repo) | Thay bằng 1 dòng `@AGENTS.md`; `specs/05` chỉ giữ phần giải thích | `md5sum` chỉ còn 1 bản luật | 1 | — |
| **FIX-042** | P2 | `docs/README.md`, `docs/FRONTEND_ENTITY_AND_ENUM_CATALOG.md` | Sửa “88 Entities” → số thật (86 entity / 87 bảng dbml), sinh bằng `repo_facts.py` | Số trong doc = số trong code | 1 | — |
| **FIX-043** | P2 | `docs/ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md:44-56,148-176` | Ghi rõ service nào chưa có gRPC/reflection; 2 ví dụ event chưa khả dụng | Đọc guide làm theo không gặp 404/UNIMPLEMENTED | 1.5 | FIX-010..012 |
| **FIX-044** | P2 | 13 file BOM | Strip UTF-8 BOM (`.csproj`, `launchSettings.json`) | gate `format` 0 finding | 0.5 | — |
| **FIX-045** | P2 | `dbml/service/auction-db.dbml:299` | Xoá `SagaStates` (không có trong code) | dbml 13 bảng = 13 DbSet | 0.5 | — |
| **FIX-046** | P2 | `dbml/enum/` | Sinh enum doc cho Commerce, Fulfillment, Log (đang thiếu 3/8) | 8/8 service có enum doc | 2 | — |
| **FIX-047** | P2 | `src/Services/ApiGateway/{ADR.md,PLAN.md,dac_ta.md,input.md,CONFIG_REFERENCE.md,SETUP_GUIDE_SERVICES.md}`, `global.json`, `run-dev.*` | Chuyển doc vào `specs/`, xoá bản nháp, đưa `global.json`/script lên root | Gateway root = 8 repo còn lại (chỉ có file chuẩn) | 1.5 | — |
| **FIX-048** | P2 | 10 `docker-compose.yml` (9 repo + root) | Repo chỉ giữ DB của mình; toàn hệ do root quản; xoá 8 DB trùng trong `docker-compose.infra.yml` | `docker compose config` không còn service trùng định nghĩa | 3 | — |
| **FIX-049** | P2 | `{8 service}/docker-compose.yml` | Thêm `USER $APP_UID` + `HEALTHCHECK` vào 9 Dockerfile | `docker run ... whoami` ≠ root | 2 | — |

---

## Đường găng (critical path)

```
FIX-002 (proto SoT) ─┬─▶ FIX-010 (Catalog gRPC) ─▶ FIX-011 (Gateway) ─┬─▶ FIX-020 (trace) ─┐
                     ├─▶ FIX-012 (4 service)                           ├─▶ FIX-030 (test)  ├─▶ FIX-031/032 (CI)
FIX-001 (migration) ─┘                                                 └─▶ FIX-043 (doc)   ┘
FIX-003/004/005 (nhánh, secret) ─▶ FIX-031 (CI) ─▶ FIX-033 (reusable)
```

## Thứ tự thi hành đề xuất (nếu chỉ có 3 ngày)

1. **Ngày 1:** FIX-001 → FIX-002 → FIX-003 → FIX-004/005 (gỡ bế tắc, không đụng logic).
2. **Ngày 2:** FIX-013 → FIX-010 → FIX-011 → FIX-021 (Catalog chạy end-to-end + sai port + lỗi tiếng Việt).
3. **Ngày 3:** FIX-020 (trace Catalog) → FIX-030 (test Catalog + 2 service mới) → FIX-031 (CI bật `dev`).

Sau 3 ngày đó, hệ thống có **1 service chạy thật end-to-end làm khuôn**, CI có hiệu lực, và không còn P0 về tái lập/contract.
