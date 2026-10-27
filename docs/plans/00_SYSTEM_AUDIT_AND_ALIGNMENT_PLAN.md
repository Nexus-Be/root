# KẾ HOẠCH AUDIT TOÀN HỆ NEXUS — “Operational Readiness & Alignment”

> Trạng thái: **DRAFT — chờ duyệt** (chưa sửa một dòng code nào)
> Ngày lập: 2026-10-24 · Phạm vi: 1 root repo + 8 service repo + 1 gateway repo (9 submodule/repo)
> Ngôn ngữ báo cáo: tiếng Việt · Ngôn ngữ artifact kỹ thuật trong repo: English

---

## 1. Mục tiêu (Objective)

Trả lời được, bằng **bằng chứng file:dòng**, câu hỏi: *“Hệ microservice Nexus đã thật sự vận hành ổn và đã sẵn sàng để bắt đầu code tính năng mới chưa?”* — đồng thời biến 7 tiêu chí của bạn thành **8 cổng kiểm (gate) đo được**, chạy lặp lại được trên từng repo và trên root, để sau này mỗi lần refactor đều chứng minh được “vẫn đồng nhất”.

Kết quả cuối cùng không phải là “một bản báo cáo”, mà là:
1. **Baseline GitNexus** đã re-index, không còn stale (hiện Catalog đang index trên `main` trong khi branch `dev`).
2. **Bộ audit script read-only** trong `.tools/audit/` → xuất JSON + bảng Markdown, tái sử dụng cho CI.
3. **9 báo cáo repo + 1 báo cáo hệ thống**, mỗi phát hiện có `path:line` + mức độ.
4. **Scorecard 8 tiêu chí × 9 repo** (0–5) + **backlog fix P0/P1/P2** đã qua `gitnexus impact`.
5. **Definition of Ready**: điều kiện tối thiểu để được phép bắt đầu code tính năng mới.

---

## 2. Bản đồ 7 tiêu chí của bạn → 8 gate đo được

| # | Tiêu chí bạn nêu | Gate | Câu hỏi kiểm chứng (đo được) | Ngưỡng ĐẠT |
|---|---|---|---|---|
| G1 | Dễ dev: mọi thứ rõ ràng, mỗi phần 1 việc | **G1-SURFACE** | Mỗi service có bề mặt API thật (gRPC impl / Controller / endpoint) khớp `specs/02_API_GRPC_CONTRACTS.md`? Mỗi folder `Application/Services/<Feature>` có đúng 1 interface + 1 impl + 1 DTO? | 100% endpoint trong spec có implementation; 0 service “rỗng” |
| G2 | Dễ sửa: không phụ thuộc chéo | **G2-DEPS** | Ma trận `ProjectReference`: `Domain` không ref gì; `Application` → `Domain`; `Infrastructure` → `Application`+`Domain`; `Api` → `Application`+`Infrastructure`; 0 reference chéo service; 0 `ProjectReference` ra ngoài repo | 0 vi phạm |
| G3 | File đúng folder, liên kết service đồng nhất | **G3-CONTRACT** | Port HTTP/gRPC/DB khớp `specs/01`; `shop.proto` **1 hash duy nhất**; tên event khớp `specs/04`; DB name/port khớp compose; địa chỉ upstream trong Gateway khớp port map | 0 lệch |
| G4 | Test/run độc lập từng phần (REST, gRPC, event, function) | **G4-TEST** | Có test project? `dotnet test` xanh? Có host test riêng cho gRPC + MassTransit + REST? Có `docker-compose.yml` riêng + `appsettings.Development.example.json` + `.http`? | Mỗi repo: build 0 error, test xanh, chạy độc lập được 1 mình |
| G5 | Theo dõi request: client → gateway → service → DB/event, biết tắc ở đâu | **G5-TRACE** | Có OTel SDK + exporter? `traceparent` W3C được propagate? `x-trace-id` có mặt ở mọi hop? Serilog có enricher `TraceId`/`SpanId`? Có Tempo/Grafana để xem? | 1 trace ID xuyên suốt 1 request mẫu |
| G6 | Doc đúng chỗ, đúng context, tách biệt, là nguồn sự thật | **G6-DOCS** | Mỗi repo chỉ có doc thuộc repo đó (inward-only); không có doc lạc; không có 2 bản doc song song (AGENTS vs CLAUDE); doc khớp code | 0 link trỏ ra ngoài, 0 doc trùng nguồn sự thật |
| G7 | Các luật đã đúng chưa (AGENTS.md + error rules) | **G7-RULES** | Rule trong AGENTS.md có **thực thi được** không? Error message 100% English + sentence case + mã `SCREAMING_SNAKE_CASE`? Không Repository pattern? DB-per-service? | 0 vi phạm, rule nào không enforce được thì bị sửa/loại |
| G8 | Format chung giống nhau, chỉ khác cách xử lý | **G8-FORMAT** | 8 backend service: cùng cây thư mục, cùng `Program.cs` pipeline order, cùng bộ key appsettings, cùng Dockerfile pattern, cùng skeleton specs, cùng `.editorconfig`/`Directory.Build.props` | diff matrix = chỉ khác tên miền nghiệp vụ |

---

## 3. Hiện trạng đã khảo sát sơ bộ (bằng chứng — dùng để ưu tiên)

> Đây là kết quả **quét nhanh 12 lệnh** trước khi lập plan. Phase 2 sẽ xác nhận lại từng dòng.

| # | Phát hiện | Bằng chứng | Mức |
|---|---|---|---|
| 1 | **5/9 service không có bề mặt gRPC**, `Program.cs` chỉ có `/health` | `Catalog/Catalog.Api/Program.cs:60` chỉ `MapGet("/health")`; không `AddGrpc`/`MapGrpcService`. Áp dụng cho `Auction`, `Catalog`, `Commerce`, `Fulfillment`, `Notification` | **P0** |
| 2 | Gateway chỉ đăng ký **1 gRPC client** (Users) cho 15 controller | `ApiGateway/Nexus.Gateway/Extensions/GrpcClientsExtension.cs:12` + comment “bổ sung sau” | **P0** |
| 3 | `shop.proto` có **4 bản / 3 hash khác nhau** | sha1: Gateway `9268ed5d…`, User `f5bf2ce3…`, Log+Wallet `588427ad…` → hợp đồng đã trôi | **P0** |
| 4 | Proto chỉ có `UsersApi` (5 rpc) | `ApiGateway/Nexus.Gateway/Contracts/shop.proto:8-14` | **P0** |
| 5 | **6/9 repo 0 test** | chỉ có `ApiGateway/Nexus.Gateway.Tests` (25 file), `User/User.Tests` (7), `Notification/Notification.Tests` (7) | **P0** |
| 6 | **6/9 service không có OpenTelemetry** | chỉ Gateway, Log, Wallet có `OpenTelemetry.*` trong `.csproj` | **P0** |
| 7 | Event gần như chưa nối | consumer: Log/Notification/Wallet (1 mỗi bên); publisher: User (2). `Auction/Catalog/Commerce/Fulfillment` = 0 publish, 0 consume | **P1** |
| 8 | Doc lạc trong ApiGateway root | `dac_ta.md`, `input.md`, `PLAN.md`, `ADR.md`, `CONFIG_REFERENCE.md`, `SETUP_GUIDE_SERVICES.md`, `run-dev.ps1`, `run-dev.sh`, `logs/` | **P1** |
| 9 | **AGENTS.md ≡ CLAUDE.md** (cùng 10522 bytes) ở root và cả 9 repo → 2 nguồn sự thật song song | `ls -l AGENTS.md CLAUDE.md` | **P1** |
| 10 | GitNexus index **stale** | `Catalog`: “last analyzed on 'main'”, current branch `dev`, commit `4c74107` vs `0250799` | **P1** |
| 11 | JWT `Signature` hardcode trong `appsettings.json` (không chỉ file example) | `ApiGateway/Nexus.Gateway/appsettings.json` block `Jwt` | **P1** (security) |
| 12 | Application layer mỏng, chưa nối vào API | `Catalog.Application`: 2 feature folder (`Product`, `Category`), 14 file; không được map ra endpoint nào | **P0** (hệ quả của #1) |

**Kết luận sơ bộ:** hệ **build được và có kiến trúc 4 tầng đồng nhất**, nhưng **chưa “hoạt động ổn” end-to-end**: phần lớn service là skeleton, gateway chạy mock, không có trace xuyên service, không có test bảo vệ. Vì vậy plan ưu tiên: *chứng minh & đo* trước, *sửa P0* sau.

---

## 4. Phương pháp & thứ tự thực hiện

```
Phase 0  Re-index GitNexus (root + 9 repo)            → baseline, không đọc code bằng grep mù
Phase 1  Dựng 9 gate scripts read-only (.tools/audit) → đo tự động, tái lặp, xuất JSON/MD
Phase 2  Audit sâu từng repo (9 task song song)       → báo cáo repo + phát hiện cấp file
Phase 3  Audit hệ thống ở root                        → specs/docs/dbml/compose/rules đối chiếu thực tế
Phase 4  Scorecard + backlog P0/P1/P2 + Definition of Ready
```

Nguyên tắc bất di bất dịch trong suốt audit:
- **Read-only.** Không sửa code service. Chỉ thêm: `.tools/audit/*` và `docs/plans/audit/*.md`.
- Trước mọi thay đổi ở Phase 4: chạy `impact({target, direction:"upstream"})` theo AGENTS.md; HIGH/CRITICAL thì báo bạn trước.
- Mỗi phát hiện phải có `path:line`. Không có bằng chứng = không đưa vào backlog.

---

## 5. Chi tiết task

### Phase 0 — Baseline GitNexus (bắt buộc làm trước, ~40 phút)

| ID | Task | Việc làm cụ thể | Output | DoD | Phụ thuộc |
|---|---|---|---|---|---|
| **T0.1** | Chốt trạng thái 9 repo | Với từng submodule: `git status --short`, `git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD`, `git log -1 --format=%ci`. Ghi vào bảng baseline | `docs/plans/audit/00_REPO_BASELINE.md` | 9/9 repo có branch+commit+dirty flag | — |
| **T0.2** | Re-index 9 repo | Trong mỗi `src/Services/<Repo>`: `node .gitnexus/run.cjs analyze` (tuần tự, timeout 180s/repo, lưu log). Nếu runner thiếu → `npx gitnexus analyze` | `docs/plans/audit/logs/analyze-<repo>.log` | 9/9 exit 0, `status` = fresh | T0.1 |
| **T0.3** | Re-index root | `node .gitnexus/run.cjs analyze` tại root (index gộp 5272 symbols hiện có) | log + số liệu mới | exit 0 | T0.2 |
| **T0.4** | Trích baseline tri thức | Từ index: số symbol/relationship/flow mỗi repo; liệt kê flow chính (`auth`, `order`, `auction-bid`, `wallet-topup`…). Dùng để Phase 2 biết “đường đi thật” của request | `00_REPO_BASELINE.md` mục “flows” | Có ≥1 flow/repo hoặc ghi rõ “0 flow” | T0.3 |

> Vì sao phải làm: `status` hiện báo **stale** (index `main`, code `dev`). Mọi kết luận impact/flow ở Phase 2–4 sẽ sai nếu index cũ.

### Phase 1 — 9 gate scripts read-only (~1 ngày)

Mỗi gate = 1 script độc lập, exit code 0/1, xuất `docs/plans/audit/gates/<gate>.json` + `.md`. Chạy được cả root lẫn từng repo.

| ID | Gate | Cách đo (cụ thể) | Bắt được lỗi gì |
|---|---|---|---|
| **T1.1** | `G3-PORT` | Parse `specs/01_SERVICE_CATALOG_PORT_MAP.md` (bảng 9 dòng) → đối chiếu: `*.Api/Properties/launchSettings.json`, `appsettings*.json`, `docker-compose.yml` (root) + `docker-compose.yml` (từng repo), `Nexus.Gateway/appsettings*.json` mục `Gateway:Services`. So 3 trục: HTTP, gRPC, DB port | Port lệch, thiếu mapping, service gọi sai port |
| **T1.2** | `G3-PROTO` | sha1 tất cả `shop.proto`; parse `service`/`rpc`; so với `specs/04_SHARED_CONTRACTS_REGISTRY.md`; so với `AddGrpcClient`/`MapGrpcService` trong code | Contract drift, rpc khai báo mà không implement |
| **T1.3** | `G2-DEPS` | Parse mọi `.csproj` `ProjectReference` → dựng ma trận; kiểm 4 luật tầng G2; kiểm 0 ref ra ngoài `<repo>/` | Vi phạm Clean Architecture, coupling chéo |
| **T1.4** | `G6-DOCLINK` | Quét mọi `.md` trong repo con: link `../` trỏ ra ngoài repo = FAIL; file `.md` ngoài whitelist (`README`, `AGENTS`, `CLAUDE`, `specs/*`, `docs/*` trong repo) = WARN | Doc lạc, link ngược root (vi phạm Nguyên tắc 2) |
| **T1.5** | `G7-ERRORMSG` | Trích string literal trong `throw new`, `ProblemDetails`, `ErrorMessage`, `Results.Problem`; regex: ký tự có dấu tiếng Việt; ALL CAPS; Title Case; mã lỗi không khớp `^[A-Z][A-Z0-9_]+$` | Vi phạm Nguyên tắc 5 |
| **T1.6** | `G1-SURFACE` | Liệt kê endpoint thật: `MapGrpcService`, `[Http*]`, `MapGet/Post/Put/Delete`; đối chiếu `specs/02_API_GRPC_CONTRACTS.md` + Controller của Gateway | Spec hứa, code không có (và ngược lại) |
| **T1.7** | `G5-TRACE` | Kiểm `.csproj` có `OpenTelemetry.*`; `Program.cs` có `AddOpenTelemetry/TracerProvider`; grep `traceparent`, `x-trace-id`, `Activity.Current`; Serilog `Enrich.WithSpan/WithTraceId` | Đứt trace giữa các hop |
| **T1.8** | `G4-TEST` | Có `<Repo>.Tests`? đếm `[Fact]/[Theory]`; `dotnet test -c Release --no-build` exit code; có `WebApplicationFactory`, `Grpc.Net.Client` test host, MassTransit test harness? | Thiếu lưới an toàn |
| **T1.9** | `G8-FORMAT` | Diff cấu trúc: cây folder cấp 2, danh sách `PackageReference`, thứ tự middleware trong `Program.cs`, key trong `appsettings.example.json`, Dockerfile stage, skeleton `specs/` | “Cùng loại repo nhưng mỗi repo một kiểu” |

**DoD Phase 1:** 9/9 gate chạy được trên 9 repo + root, exit 0 khi sạch; có README hướng dẫn chạy; 0 false-positive đã biết (nếu có, ghi vào `KNOWN_LIMITS`).

### Phase 2 — Audit sâu từng repo (9 task, chạy song song được, ~2.5 ngày)

**Template chung** — mỗi repo lặp đúng 10 bước sau, chỉ khác phần “đặc thù”:

| Bước | Nội dung | Bằng chứng cần nộp |
|---|---|---|
| 2.1 | **Bản đồ repo**: cây thư mục 3 cấp, đếm file/LOC theo tầng, entrypoint | bảng + `tree` |
| 2.2 | **Trách nhiệm**: mỗi folder/service = 1 việc? Có lớp “God service” (>300 dòng, >7 public method)? | danh sách + số dòng |
| 2.3 | **Bề mặt**: endpoint thật vs `specs/02` vs Gateway controller | bảng 3 cột khớp/lệch |
| 2.4 | **Phụ thuộc**: ma trận ref + có đọc DB service khác? có gọi gRPC service khác đúng port? | ma trận + `path:line` |
| 2.5 | **Hợp đồng**: proto hash, tên message/field, event name/version | sha1 + diff |
| 2.6 | **Dữ liệu**: `DbContext`, `DbSet`, migration mới nhất, DB name/port, index/FK | đối chiếu `specs/04` + `dbml/service/*.dbml` |
| 2.7 | **Messaging**: publish/consume, retry, outbox, idempotency, DLQ | danh sách event 2 chiều |
| 2.8 | **Test & chạy độc lập**: `dotnet build -c Release`, `dotnet test -c Release`, `docker compose config`, chạy 1 mình | log + exit code |
| 2.9 | **Trace & log**: OTel, correlation, log sink, có gửi Log service? | `path:line` |
| 2.10 | **Doc & luật**: `AGENTS.md`/`specs/*` khớp code? link inward-only? error message đúng chuẩn? | danh sách lệch |

**9 task cụ thể (đặc thù đã biết trước):**

| ID | Repo | Đặc thù cần soi kỹ | Ước lượng |
|---|---|---|---|
| **T2.1** | `src/Services/ApiGateway` (7468 LOC) | 15 controller/1 gRPC client; `MockEngine` + `Seeds/*` (nhiều folder chỉ có README); `HealthProber` (interval 60s, threshold 5, auto-recover); `Dispatching`; `AuthMode Enforce`; JWT secret trong `appsettings.json`; 8 file doc lạc ở root repo; `logs/` bị track? | 4h |
| **T2.2** | `src/Services/User` (2212 LOC, có test) | `UsersApi` server thật (6 file Api); OTP flow; `User.Tests` 7 file — coverage có thật? error message OTP (`OTP_EXPIRED`…); publish 2 event — có consumer nào nhận? | 3h |
| **T2.3** | `src/Services/Catalog` (997 LOC) | **0 endpoint**, chỉ `/health`; `ProductService`/`CategoryService` chưa expose; `category_db:5434`; không event; **0 test** | 2.5h |
| **T2.4** | `src/Services/Commerce` (1704 LOC, 44 file Domain) | Domain lớn nhất nhưng 0 endpoint/0 event; `commerce_db:5435`; kiểm tra entity có “ôm” việc của Catalog/Auction không (boundary) | 3h |
| **T2.5** | `src/Services/Auction` (1101 LOC) | 0 endpoint/0 event/0 test; logic bid/time-window nằm ở đâu? `auction_db:5437`; phụ thuộc Catalog? | 2.5h |
| **T2.6** | `src/Services/Fulfillment` (1075 LOC) | 0 endpoint/0 event/0 test; `fulfillment_db:5438`; quan hệ với Commerce order | 2.5h |
| **T2.7** | `src/Services/Log` (1257 LOC) | Có gRPC server + OTel + 1 consumer + health prober gọi; cần soi: log batching từ Gateway (`BatchDirectory`, `RemoteEndpoint` 8004) có khớp schema không | 3h |
| **T2.8** | `src/Services/Wallet` (1659 LOC) | Có gRPC + OTel + 1 consumer; tiền tệ/số dư/idempotency — có transaction+outbox? `wallet_db:5440` | 3h |
| **T2.9** | `src/Services/Notification` (1264 LOC, có test) | Có 1 consumer + test 7 file; gửi email/SMS có adapter thật hay stub? `notification_db:5439` | 3h |

**Output mỗi task:** `docs/plans/audit/{Repo}_AUDIT.md` theo đúng 10 mục + bảng phát hiện `{id, severity, path:line, mô tả, đề xuất, impact}`.
**DoD mỗi task:** build Release 0 error; test (nếu có) xanh; 10/10 mục có kết luận; ≥0 phát hiện (không được bỏ trống mục).

### Phase 3 — Audit hệ thống ở root (~1 ngày)

| ID | Task | Việc làm cụ thể | Output |
|---|---|---|---|
| **T3.1** | **Specs vs thực tế** | Đối chiếu 6 file `specs/00..05` với code: port map, ma trận gRPC/Saga, RBAC 5 role, registry proto; mỗi dòng spec gắn nhãn `ĐÚNG / SAI / CHƯA-CÓ` | `docs/plans/audit/ROOT_SPECS_GAP.md` |
| **T3.2** | **Chuẩn hoá doc** | Phân loại `docs/` (15 file) + `docs/adr/` + `docs/infra/`: file nào là nguồn sự thật, file nào trùng lặp, file nào lỗi thời; đề xuất đích đến (giữ/di chuyển vào repo con/xoá). Kiểm tra toàn bộ link nội bộ | `ROOT_DOCS_MAP.md` + bảng move/keep/delete |
| **T3.3** | **DBML vs EF migrations** | 8 file `dbml/service/*.dbml` vs `*/Migrations/*` + `AppDbContext` + `specs/04`: bảng/cột/kiểu/enum lệch ở đâu; `dbml/enum/*` có khớp enum C#? | `DBML_DRIFT.md` (8 dòng) |
| **T3.4** | **Hạ tầng vs port map** | `docker-compose.yml` (9 service + 8 DB + rabbit/redis/tempo/grafana) + `docker-compose.infra.yml` + `infra/`: port mapping, healthcheck, `depends_on`, network, volume, env var so với `specs/01` và `.env.example` | `INFRA_DRIFT.md` |
| **T3.5** | **Luật & nguồn sự thật của luật** | `AGENTS.md` vs `CLAUDE.md` (giống 100%?) ở root + 9 repo; rule nào **không thể enforce** (vd “CẤM Repository pattern” nhưng có `ICatalogDbContext`?), rule nào xung đột với thực tế (DoD đòi `dotnet test` trong repo không có test) | `RULES_AUDIT.md` + đề xuất 1 canonical + phần “generated” |
| **T3.6** | **Repo & bí mật** | `.gitmodules` (9 submodule, branch policy?), submodule trỏ commit nào; `.env` vs `.env.example` parity; secret hardcode (`Jwt.Signature`, `MatkhaucuaTui123@`); `.gitignore` có chặn `bin/obj/logs/.idea`? | `REPO_HYGIENE.md` |
| **T3.7** | **Onboarding path** | `README.md` root + 9 README: các bước chạy hệ thống có đúng thực tế (lệnh, port, thứ tự)? Một người mới làm theo có chạy được? | `ONBOARDING_CHECK.md` |

### Phase 4 — Chấm điểm & backlog (~0.5 ngày)

| ID | Task | Việc làm | Output |
|---|---|---|---|
| **T4.1** | Scorecard | 8 gate × 9 repo, thang 0–5 + trọng số (P0 gate ×3). Tính điểm hệ thống | `SCORECARD.md` (bảng + biểu đồ) |
| **T4.2** | Backlog fix | Gom phát hiện → P0 (chặn vận hành) / P1 (chặn mở rộng) / P2 (vệ sinh). Mỗi item: mô tả, file, cách sửa, ước lượng, **impact analysis** (`upstream`, risk level), thứ tự phụ thuộc | `FIX_BACKLOG.md` |
| **T4.3** | Definition of Ready | Điều kiện tối thiểu để bắt đầu code tính năng: vd “service X phải có gRPC server + 1 test + trace”, “proto phải 1 hash” | `DEFINITION_OF_READY.md` |

---

## 6. Deliverables & nơi lưu

```
docs/plans/
  00_SYSTEM_AUDIT_AND_ALIGNMENT_PLAN.md      ← file này
  SCORECARD.md
  FIX_BACKLOG.md
  DEFINITION_OF_READY.md
  audit/
    00_REPO_BASELINE.md
    ROOT_SPECS_GAP.md  ROOT_DOCS_MAP.md  DBML_DRIFT.md  INFRA_DRIFT.md
    RULES_AUDIT.md  REPO_HYGIENE.md  ONBOARDING_CHECK.md
    ApiGateway_AUDIT.md  User_AUDIT.md  Catalog_AUDIT.md  Commerce_AUDIT.md
    Auction_AUDIT.md  Fulfillment_AUDIT.md  Log_AUDIT.md  Wallet_AUDIT.md  Notification_AUDIT.md
    gates/*.json gates/*.md
    logs/analyze-*.log
.tools/audit/                                 ← 9 gate scripts + README
```

---

## 7. Ước lượng & thứ tự

| Phase | Nội dung | Người·ngày | Song song? | Chặn bởi |
|---|---|---|---|---|
| 0 | Re-index + baseline | 0.1 | không (tuần tự để tránh KuzuDB lock) | — |
| 1 | 9 gate scripts | 1.0 | 3–4 gate song song | Phase 0 |
| 2 | 9 repo audit | 2.5 | **có, 9 subagent song song** | Phase 1 (gate phải xong để có số liệu chuẩn) |
| 3 | Root audit | 1.0 | 4 task song song | Phase 2 (cần dữ liệu repo) |
| 4 | Scorecard + backlog | 0.5 | không | Phase 2+3 |
| | **Tổng** | **~5.1 người·ngày** (thực tế ~1.5 ngày lịch nếu fan-out subagent) | | |

Đường găng: `T0.2 → T1.2/T1.6 → T2.* → T3.1 → T4.2`.

---

## 8. Kế hoạch kiểm chứng (Verification)

```bash
# Build từng repo (0 error, Release)
for d in src/Services/*/; do dotnet build "$d"*.sln -c Release --nologo; done

# Test từng repo (chỉ 3 repo hiện có test; phần còn lại ghi nhận "N/A - thiếu test project")
dotnet test src/Services/User/User.sln -c Release --nologo
dotnet test src/Services/Notification/Notification.sln -c Release --nologo
dotnet test src/Services/ApiGateway/ApiGateway.sln -c Release --nologo

# Hạ tầng
docker compose config -q
docker compose -f docker-compose.infra.yml config -q

# Gate scripts (sau Phase 1)
bash .tools/audit/run-all.sh --root .            # phải exit 0 khi sạch
node .gitnexus/run.cjs status                    # phải "fresh"

# Trace end-to-end (Phase 4, sau khi sửa P0) — 1 request mẫu
curl -s -H "x-trace-id: audit-$(date +%s)" http://localhost:8080/health
# mở Grafana → Tempo, tìm trace đó → phải thấy gateway + service + (nếu có) DB span
```

---

## 9. Rủi ro & cách né

| Rủi ro | Ảnh hưởng | Cách xử lý |
|---|---|---|
| `gitnexus analyze` chạy lâu/corrupt KuzuDB | Mất index, phải build lại | chạy tuần tự, timeout 180s, backup `.gitnexus/lbug` trước |
| Submodule đang dirty / khác branch | Kết luận sai | T0.1 chốt baseline, ghi rõ dirty file; không tự `git checkout` |
| 6 repo không có test → DoD AGENTS.md không thoả | Audit “FAIL” hàng loạt | Ghi nhận là phát hiện P0, **không** tự thêm test trong phase audit (scope creep) |
| Docker engine không chạy | Không test được end-to-end | Phase 2 dùng build + unit; đánh dấu “chưa verify runtime” thay vì kết luận sai |
| Audit bị hiểu là “được sửa code” | Phá baseline | Nguyên tắc read-only ở mục 4; mọi sửa nằm ở Phase 4 sau khi bạn duyệt |

---

## 10. Cần bạn xác nhận trước khi bắt đầu

1. **Phạm vi**: chỉ audit read-only (plan này) → rồi mới fix? Hay muốn mình gộp luôn “fix P0” vào cùng đợt?
2. **Test**: 6 repo thiếu test — có nằm trong scope đợt này (thêm test project + smoke test), hay để backlog riêng?
3. **Chuẩn doc**: giữ `AGENTS.md` làm canonical và để `CLAUDE.md` chỉ là file generated/pointer? (hiện 2 file giống nhau 100% ở 10 nơi)
4. **Báo cáo**: tiếng Việt (mặc định) — phần code/spec/error message vẫn English theo Nguyên tắc 5?

---

## 11. KẾT QUẢ THỰC THI (audit run — 2026-10-24)

**Trạng thái: Phase 0 → Phase 4 hoàn tất.** Chỉ tạo file trong `.tools/audit/`, `docs/plans/`; không sửa code service (đúng scope read-only). Ngoại lệ do tool: `node .gitnexus/run.cjs analyze` regenerate block GitNexus trong `AGENTS.md`/`CLAUDE.md` của 9 repo.

| Phase | Output | Kết quả |
|---|---|---|
| 0 | `audit/00_REPO_BASELINE.md`, `audit/logs/analyze-*.log` | 10/10 repo `EXIT 0`, 9/9 `up-to-date`; 5960 symbol/8926 edge/191 flow ở root |
| 1 | `.tools/audit/{audit.py,repo_facts.py,run-all.sh,README.md}`, `audit/gates/*.json` | **170 finding: P0 42 · P1 23 · P2 105** |
| 2 | 9 × `audit/{Repo}_AUDIT.md` (52 finding có ID) | build **9/9 EXIT 0**; test **3/3 repo có test EXIT 0** |
| 3 | 6 × `audit/ROOT_*_AUDIT.md` | specs/docs/contracts/infra/rules/hygiene |
| 4 | `SCORECARD.md`, `FIX_BACKLOG.md`, `DEFINITION_OF_READY.md` | 31 FIX item (14 P0 · 8 P1 · 9 P2) + đường găng + cửa vào/ra chuẩn |

**Ba kết luận gọn:**
1. Hệ thống **build được, chạy được một phần**, nhưng **chưa phải một hệ thống**: 5/8 service không có bề mặt mạng, 11/15 controller Gateway rỗng, 6/8 event trong registry không tồn tại.
2. Nút thắt số một **không phải code** mà là **nguồn sự thật**: proto có 4 bản/3 hash và bản “canonical” lại thiếu 8/9 service; migration đúng nhưng chưa commit; luật có 3 bản và 0 cưỡng chế.
3. Điểm mạnh thật: **kỷ luật tầng** (0 Repository pattern, 0 phụ thuộc chéo, 0 link ra ngoài), **port/DB/compose khớp spec**, **Mock Engine Gateway**, và **1 luồng event OTP chạy thật**.

**Điểm số:** trung bình hệ thống **2.7/5** (Gateway 3.9 · Wallet/Log/User 3.5 · Notification 2.8 · Catalog 2.4 · Commerce 2.1 · Auction/Fulfillment 2.0 · Root 2.6).

**Đường găng để bắt đầu code:** `FIX-001` (commit migration) → `FIX-002` (proto SoT) → `FIX-010/011` (Catalog end-to-end) → `FIX-020` (trace) → `FIX-030/031` (test + CI).
