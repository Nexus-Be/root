# SETUP PHASE PLAN — Nexus-Be

**Trạng thái:** đề xuất, chờ duyệt. **Phạm vi:** chỉ file cấu hình / hạ tầng / tài liệu / luật — **không viết code nghiệp vụ, không thêm API, không sửa Program.cs của service**.
**Căn cứ:** `docs/plans/00_SYSTEM_AUDIT_AND_ALIGNMENT_PLAN.md` (audit Phase 0–4 đã xong), `docs/plans/FIX_BACKLOG.md`, `docs/plans/SCORECARD.md`, và đợt kiểm chứng hạ tầng ngày 24/10/2026 (mục §2 dưới đây).
**Nguyên tắc:** setup chưa đạt thì không code service. Mỗi task có `Accept` phải chạy được bằng lệnh, không cảm tính.

---

## §1. Vì sao tách "setup" khỏi "code"

Trong 31 mục của `FIX_BACKLOG.md`, có hai loại việc khác hẳn nhau về rủi ro:

| Loại | Ví dụ | Đụng code nghiệp vụ? | Làm được ngay? |
|---|---|---|---|
| **Setup** (file cấu hình, luật, doc, hạ tầng) | proto SoT, `.gitmodules`, port, secret, compose, Dockerfile, CI, specs, dbml | Không | Có — không phụ thuộc quyết định nghiệp vụ |
| **Code** (bề mặt service, hợp đồng, quan sát) | thêm `MapGrpcService` cho 5 service, `Login` + JWT, `POST /log/batch`, OTel, test | Có | Chỉ sau khi setup xong |

Toàn bộ Wave 0 của backlog cũ trộn hai loại này, nên khi thi hành sẽ vừa sửa proto vừa phải viết gRPC — đúng thứ bạn muốn hoãn. Bản plan này tách ra: **Track S (setup)** làm trước, **Track C (code)** để nguyên, chỉ liệt kê.

---

## §2. Kết quả kiểm chứng hạ tầng + code base (đã chạy, không suy đoán)

### 2.1 Hạ tầng — những gì ĐANG chạy được

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Cú pháp compose | ✅ 12/12 file hợp lệ | `docker compose -f <file> config -q` → 0 lỗi (root, infra, `src/Infrastructure`, 9 repo) |
| Dải port published | ✅ khớp `specs/01` | DB `5433–5440`, service `8000–8008`, Rabbit `5672/15672`, Redis `6379`, OTLP `4317/4318`, Tempo UI `3200`, Grafana `3000` |
| Dockerfile | ✅ 9/9 có `EXPOSE` + `ASPNETCORE_URLS` đúng port spec | vd `Auction`: `EXPOSE 8005`, `ENV ASPNETCORE_URLS=http://+:8005` |
| Định tuyến trong container | ✅ compose override đúng DNS nội bộ | Gateway: `Gateway__Services__catalog__Address=http://catalog-service:8002`; service: `Host=catalog-db;Port=5432` |
| DB / Rabbit / Redis | ✅ 10 healthcheck | 8 DB + `rabbitmq` + `redis` |
| Migration sinh schema | ✅ 8/8 có file Initial, đủ bảng | `CreateTable` = Auction 16, Catalog 12, Commerce 19, Fulfillment 13, Log 9, Notification 13, User 17, Wallet 11 |
| Build | ✅ 9/9 | `dotnet build <S>.sln -c Release` → 0 error (log `docs/plans/audit/logs/build-all.log`) |
| Test hiện có | ✅ 3/3 xanh | Gateway 62 fact, User 9, Notification 2 |

### 2.2 Hạ tầng — những gì SAI, chặn mục tiêu

| # | Vấn đề | Bằng chứng | Chặn tiêu chí nào |
|---|---|---|---|
| H-1 | **6/9 `launchSettings.json` sai port** → `dotnet run` mặc định chạy sai cổng | Auction `5230/7202` (spec `8005`), Catalog `5272/7232` (`8002`), Commerce `5105/7035` (`8003`), Fulfillment `5228/7014` (`8006`), Log `5280/7103` (`8004`), Wallet `5096/7218` (`8008`) | (1) dễ dev, (4) chạy độc lập |
| H-2 | **Compose nội suy `$` trong env → hỏng giá trị** | `docker compose config` cảnh báo 3 biến `d`, `G`, `M` chưa set; 3 chuỗi này khớp đúng đoạn `$d)…`, `$G{…`, `$M#…` của JWT signature | (5) auth/trace, (2) ổn định |
| H-3 | **Không có healthcheck cho tầng app** | 11 service không healthcheck: 9 app + tempo + grafana; `depends_on` không đợi app sẵn sàng | (4) chạy độc lập, (5) debug |
| H-4 | **8 DB khai 2 lần** | `docker-compose.infra.yml` (12 service) trùng 8 DB với `docker-compose.yml` (21 service) | (8) đồng nhất |
| H-5 | **Secret nằm trong file tracked** | JWT key ở `ApiGateway/Nexus.Gateway/appsettings.json:26` + `appsettings.Development.json:25`; `MatkhaucuaTui123@` ở 8 `docker-compose.yml` + 2 compose root + `src/Infrastructure/` + 8 `.env.example` | (7) luật |
| H-6 | **Không ESCAPE `$` cho secret** | như H-2: nếu đưa JWT key qua env phải viết `$$` trong compose | (5) trace/auth |
| H-7 | **Dockerfile thiếu `USER` + `HEALTHCHECK`** | 9/9 chạy root, không khai healthcheck | (7) luật, (8) đồng nhất |
| **H-8** | **P0 — image `postgres:16-alpine` trên máy bị hỏng: `docker-entrypoint.sh` = 0 byte** → 8 container DB `Restarting (255)`, log `exec /usr/local/bin/docker-entrypoint.sh: exec format error`. Đã thử `postgres:15-alpine` (pull mới) → chạy tốt, `PostgreSQL 15.19`. Không phải lỗi repo, nhưng **repo không có cơ chế phát hiện**: app vẫn khởi động khi DB chết | `docker inspect nexus-catalog-db` → `restarting exit=255`; `docker run --rm --entrypoint /bin/sh postgres:16-alpine -c 'ls -l /usr/local/bin/docker-entrypoint.sh'` → `0` byte; digest local = `sha256:f4610795…` (đúng official) nên `docker pull` không tải lại | (4) chạy độc lập — **chặn hoàn toàn DB layer** |
| **H-9** | **P0 — `/health` nói dối**: khi DB chết, `Catalog.Api` vẫn boot, `/health` trả `200 {"status":"Healthy","service":"Catalog.Api"}` vì migration fail bị nuốt; do đó healthcheck dựa trên `/health` (S-10) sẽ luôn xanh dù hệ thống không dùng được | smoke test `docs/plans/audit/logs/smoke-catalog.log`: `Now listening on: http://localhost:8002` + `/health HTTP = 200` trong khi `NpgsqlException: Failed to connect to 127.0.0.1:5434` | (4), (5) — health không phải nguồn sự thật |

> Ghi chú: file `.env` bị chặn bởi policy đọc file nhạy cảm nên chưa đối chiếu được key-by-key; H-2 suy ra từ tên biến trong cảnh báo (khớp 100% với 3 đoạn `$` của JWT key). Task S-05 sẽ xác minh dứt điểm bằng `docker compose config` (kỳ vọng: 0 warning).

### 2.4 Smoke test thật (Catalog) — chạy 24/10 18:43–18:45

Mục đích: trả lời “hệ thống có chạy được không” bằng bằng chứng, không bằng suy luận. Kịch bản: `.tools/audit/smoke-catalog.sh` (dựng `catalog-db`+`rabbitmq`+`tempo`+`redis` bằng compose root → `dotnet run Catalog.Api --no-launch-profile` ở port `8002` → gọi `/health` → đếm bảng trong `category_db`).

| Bước | Kết quả | Ý nghĩa |
|---|---|---|
| `docker compose up -d` 4 service | ✅ exit 0 | compose định nghĩa đúng |
| Container DB healthy | ❌ `restarting (255)` suốt 90s | **H-8: image hỏng** |
| `dotnet run` boot | ✅ `Now listening on: http://localhost:8002` | code boot được, port đúng khi chỉ định tay |
| `/health` | ✅ `200 {"status":"Healthy","service":"Catalog.Api"}` | **H-9: health nói dối** — DB đang chết |
| Kết nối DB | ❌ `NpgsqlException 0x80004005: Failed to connect to 127.0.0.1:5434` | exception bị nuốt, app vẫn sống |
| Bảng trong `category_db` | **không kiểm được** (DB không lên) | migration chưa từng chạy thật lần nào trên máy này |

**Kết luận:** “chạy được” hiện chỉ đúng ở tầng process (app boot, /health 200). **DB + migration + 5 service surface chưa từng được chứng minh chạy.** Vì vậy mọi tuyên bố “hệ thống hoạt động ổn” trong tài liệu hiện tại là chưa có bằng chứng.


### 2.3 Code base — hiện trạng so với 8 mục tiêu (đã có trong SCORECARD, tóm tắt)

| Mục tiêu | Điểm | Nút chặn chính (thuộc setup hay code) |
|---|---|---|
| (1) Dễ dev | 2/5 | Port dev sai (S), 5 service không có bề mặt (C) |
| (2) Dễ sửa, ít phụ thuộc | 4/5 | `deps` gate 0 phát hiện — tốt nhất trong 8 mục |
| (3) File đúng chỗ, liên kết đồng nhất | 2/5 | 4 bản proto / 3 hash (S), doc lạc ở Gateway (S) |
| (4) Test/chạy độc lập | 1/5 | 6/9 repo không có test project (C), port (S) |
| (5) Theo dõi request | 2/5 | 6 service không OTel (C), trace id không xuyên (C) |
| (6) Doc là sự thật | 2/5 | `specs/02`, `specs/04`, `docs/ISOLATED_TESTING…` nói sai hiện trạng (S) |
| (7) Luật đúng | 3/5 | 3 bản luật (`AGENTS.md` ≡ `CLAUDE.md`, `specs/05`), secret (S) |
| (8) Format đồng nhất | 2/5 | 3 style Application layer (C), thiếu `Directory.Build.props`/`.editorconfig`, BOM (S) |
| **TB** | **2.7/5** | |

**Kết luận:** hạ tầng đã đủ để chạy (compose hợp lệ, port đúng, DB đúng), nhưng **chưa đủ để gọi là "một hệ thống"** vì 4 lý do thuộc setup: proto lệch, secret lộ, port dev lệch, CI không kiểm. Sửa xong 4 thứ này thì mới nên viết code service.

---

## §3. Track S — task setup (được phép làm ngay)

Ký hiệu: `S-xx`. Cột `Accept` là lệnh phải chạy được. `h` = giờ công ước tính.

### Wave S0 — Chặn (bắt buộc trước mọi thứ) · ~7h

| ID | Repo | Files | Change | Accept | h |
|---|---|---|---|---|---|
| **S-01** | root | `contracts/proto/shop.proto` *(mới)*, `scripts/sync-proto.sh` *(mới)*, 4 bản copy | Lấy bản đầy đủ nhất (Log/Wallet `8a7d8698…`, có `CreateUser`) làm chuẩn ở root; script copy xuống `ApiGateway/Nexus.Gateway/Contracts/`, `User|Log|Wallet/Api/Contracts/` | `md5sum` 4 bản giống nhau; `bash scripts/sync-proto.sh --check` exit 0 | 3 |
| **S-02** | root | `.gitmodules` | Thêm `branch = dev` cho 8 service; Gateway: `branch = dev` (đưa `mock` về `dev`) hoặc `branch = mock` nếu giữ | `git submodule update --remote --dry-run` ra đúng nhánh từng repo | 1 |
| **S-03** | ApiGateway | `Nexus.Gateway/appsettings.json:26`, `appsettings.Development.json:25`, `*.example.json` | Bỏ key thật → `Jwt:Signature` đọc từ env/user-secrets; rotate key; `.example` để placeholder | `grep -rn 'Signature": "\$d)'` = 0; `dotnet build` + `dotnet test` xanh | 1.5 |
| **S-04** | root + 9 repo | 10 `docker-compose.yml`, `src/Infrastructure/docker-compose.yml`, 18 `.env.example` | `MatkhaucuaTui123@` → `${POSTGRES_PASSWORD:?}` / `${RABBITMQ_PASSWORD:?}`; example để `CHANGE_ME` | `grep -rl 'MatkhaucuaTui123@' --exclude='.env'` = 0 | 1.5 |
| **S-05** | root | các compose + env | Escape `$` → `$$` cho giá trị chứa `$` (JWT key); hoặc chuyển sang `env_file` + không nội suy | `docker compose -f docker-compose.yml config -q` → **0 warning** | 1 |

**Gate S0:** `docker compose config` 0 warning · 4 proto cùng hash · 0 secret tracked · `git submodule update --remote --dry-run` đúng nhánh.

### Wave S1 — Dev parity (một lệnh chạy đúng) · ~9h

| ID | Repo | Files | Change | Accept | h |
|---|---|---|---|---|---|
| **S-06** | 6 service | `*/Api/Properties/launchSettings.json` | Đưa `applicationUrl` về port spec, bỏ profile `https`/`IIS Express` thừa, strip BOM | `python3 .tools/audit/audit.py --gate port` → 0 finding | 1.5 |
| **S-07** | root | `global.json`, `Directory.Build.props`, `.editorconfig` *(mới)* | Pin SDK `8.0.x`; chung `Nullable`, `ImplicitUsings`, analyzer, style; `global.json` chuyển từ Gateway lên root | 9/9 `dotnet build` xanh; `dotnet format --verify-no-changes` sạch | 2 |
| **S-08** | root | `nuget.config` | Một nguồn NuGet chung ở root (User/Notification đang có riêng) | `dotnet restore` 9/9 OK khi xoá `nuget.config` con | 1 |
| **S-09** | 9 repo | 9 `Dockerfile` | `USER $APP_UID`, `HEALTHCHECK` gọi `/health`, gom base image cùng tag | `docker build` 9/9; `docker run … whoami` ≠ root | 2 |
| **S-10** | root | `docker-compose.yml` | Thêm healthcheck cho 9 app + `depends_on: condition: service_healthy` | `docker compose up -d` → mọi container `healthy` trong 120s | 1.5 |
| **S-11** | root + 9 repo | `docker-compose.infra.yml`, 9 `docker-compose.yml` | Root compose là nguồn duy nhất; infra bỏ 8 DB trùng; compose repo chỉ giữ DB của mình | `docker compose config --services` không có service trùng định nghĩa | 2 |
| **S-12** | 9 repo | `.gitignore`, `.env.example` | `.gitignore` đồng nhất (md5 bằng nhau); `.env.example` đủ key như `.env` | `md5sum */…/.gitignore` 1 giá trị; diff key `.env` vs `.env.example` = 0 | 1 |
| **S-22** | máy dev (không phải repo) | image `postgres:16-alpine` | Sửa H-8: `docker compose down` các DB → `docker rmi postgres:16-alpine` → `docker pull postgres:16-alpine` → `docker compose up -d catalog-db` → kiểm `pg_isready`. Nếu vẫn 0 byte: pin `postgres:15-alpine` trong compose + ghi ADR | `docker run --rm postgres:16-alpine postgres --version` in ra version (không còn `exec format error`); 8 DB container `healthy` | 1 |

**Gate S1:** 6 port đúng · 0 warning compose · 21 container healthy · 9 Dockerfile non-root · format gate 0 P2 về `nuget.config`/package.

### Wave S2 — Hợp đồng & tài liệu là sự thật · ~10h

| ID | Repo | Files | Change | Accept | h |
|---|---|---|---|---|---|
| **S-13** | root | `specs/02`, `specs/04`, `docs/adr/ADR.md` | `specs/04` thêm cột `Status: implemented/planned` cho 8 event + 8 gRPC service; `specs/02` tách `AS-IS` / `TO-BE`; thêm `ADR-033` protobuf SoT, `ADR-034` ai phát JWT, `ADR-035` kho thuộc Fulfillment | Đọc `specs/02` không còn câu sai sự thật; link nội bộ không gãy | 3 |
| **S-14** | root | `docs/ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md:44-56,148-176`, `docs/HEALTH_AND_LOGGING_ARCHITECTURE.md:89-90`, `docs/README.md` | Ghi rõ chỉ 3 service có gRPC/reflection; đánh dấu 2 ví dụ event chưa khả dụng; chọn dứt điểm event-bus hay HTTP cho log; `88 Entities` → `86 entity/87 bảng` | Làm theo guide không gặp 404/UNIMPLEMENTED; số trong doc = số trong code | 2 |
| **S-15** | ApiGateway | `ADR.md`, `PLAN.md`, `dac_ta.md`, `input.md`, `CONFIG_REFERENCE.md`, `SETUP_GUIDE_SERVICES.md`, `logs/`, `run-dev.*` | Chuyển doc còn giá trị vào `specs/`, xoá bản nháp; `run-dev.*` lên root `scripts/` | Gateway root chỉ còn file chuẩn như 8 repo khác | 1.5 |
| **S-16** | root + 9 repo | `CLAUDE.md` ×10 | Thay bằng 1 dòng `@AGENTS.md` | `md5sum` chỉ còn 1 bản luật; `specs/05` chỉ giải thích | 1 |
| **S-17** | root | `dbml/service/auction-db.dbml:299`, `dbml/enum/` | Xoá `SagaStates` (không có trong code); sinh enum doc cho Commerce/Fulfillment/Log | dbml Auction 13 bảng = 13 `DbSet`; 8/8 service có enum doc | 1.5 |
| **S-18** | Catalog | `Catalog/specs/02_API_GRPC_CONTRACTS.md` | Sửa: kho thuộc **Fulfillment**, không phải Catalog (CA-03) | Spec không mô tả rpc kho trong Catalog | 1 |

**Gate S2:** 0 câu sai sự thật trong `specs/` + `docs/` · 1 bản luật · dbml = code · 0 doc lạc.

### Wave S3 — Kiểm soát tự động · ~7h

| ID | Repo | Files | Change | Accept | h |
|---|---|---|---|---|---|
| **S-19** | 9 repo | `.github/workflows/ci-cd.yml` | Trigger `[main, dev, mock]`; thêm job `dotnet restore/build` (+ `test` khi S-20 có test) **trước** job build image | Push thử 1 commit → CI chạy; cố tình sai port → đỏ | 3 |
| **S-20** | root | `.github/workflows/audit.yml` *(mới)* | Chạy `.tools/audit/audit.py` 9 gate, fail nếu có P0, upload `gates/*.json` | PR mẫu sai port bị chặn | 2 |
| **S-21** | root | `.tools/audit/repo_facts.py`, `docs/README.md` | CI sinh `facts/<Repo>.md` + số liệu doc từ code (không viết tay) | Số trong `docs/` do máy sinh, diff = 0 | 2 |

**Gate S3:** CI xanh trên `dev`/`mock`; audit P0 = 0; số liệu doc tự sinh.

---

## §4. Task lặp qua từng repo (ma trận thi hành)

Ô ghi task ID. `—` = không áp dụng.

| Repo | Port (S-06) | Proto copy (S-01) | Compose (S-04,S-11) | Dockerfile (S-09) | `.gitignore`/env (S-12) | `CLAUDE.md` (S-16) | CI (S-19) | Spec/doc riêng |
|---|---|---|---|---|---|---|---|---|
| ApiGateway | ✅ đúng | ✅ bản Gateway | ✅ | ✅ | ✅ | ✅ | ✅ | S-15 doc lạc, S-03 secret |
| Auction | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Catalog | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | S-18 kho thuộc Fulfillment |
| Commerce | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Fulfillment | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| Log | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ADR-035 kho |
| Notification | ✅ đúng | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| User | ✅ đúng | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ADR-034 JWT |
| Wallet | S-06 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |

**Root:** S-01, S-02, S-05, S-07, S-08, S-10, S-11, S-13, S-14, S-16, S-17, S-20, S-21.

---

## §5. Track C — việc code, KHÔNG làm trong phase này

Chỉ liệt kê để không quên; mỗi mục phải chờ S0–S1 xong.

| ID cũ | Việc | Vì sao phải chờ setup |
|---|---|---|
| FIX-010..012 | Thêm gRPC surface cho Auction/Catalog/Commerce/Fulfillment/Notification | Phải có proto chuẩn (S-01) trước, nếu không lại sinh bản thứ 5 |
| FIX-014 | `UsersApi/Login` + phát JWT | Cần ADR-034 (S-13) chốt ai phát token |
| FIX-015 | `POST /api/v1/log/batch` | Cần ADR chốt event-bus vs HTTP (S-13/S-14) |
| FIX-020 | OTel cho 6 service | Cần trace id xuyên service thống nhất (S-05 escape, S-10 health) |
| FIX-021/022 | Dịch 19 lỗi tiếng Việt | Không phụ thuộc setup, nhưng làm cùng lúc với sửa code service sẽ gọn hơn |
| FIX-023/024 | Notification ghi DB + retry/DLQ | Code nghiệp vụ |
| FIX-030 | Test project cho 6 service | Sau khi có bề mặt (FIX-010..012) mới test được |
| **C-01 (H-9)** | `/health` phải phản ánh DB: thêm `AddHealthChecks().AddNpgSql(...)` + map `/health/ready`, giữ `/health/live` cho process; bỏ `catch { }` nuốt lỗi migration | Phải sửa **Program.cs** của 9 service → là code, không phải setup; nhưng S-10 chỉ có ý nghĩa sau khi C-01 xong |
| Style Application layer | 3 style → 1 | Refactor lớn, phải có test trước |

---

## §6. Thứ tự thi hành & đường găng

```
S-01 (proto) ──► S-13 (specs) ──┐
S-04/S-05 (secret) ─► S-10 ─────┼──► [Gate Setup] ──► Track C
S-02 (.gitmodules) ─────────────┤
S-06 (port) ─► S-07 (build chuẩn) ┘
S-19/S-20 (CI) chạy song song, chốt cuối
```

**Ước lượng:** S0 7h · S1 9h · S2 10h · S3 7h ≈ **33h ≈ 4 ngày công**, làm tuần tự 1 người; song song 2 người còn ~2.5 ngày.
**Ba ngày đầu nếu chỉ có 3 ngày:** S-01 → S-02 → S-03 → S-04 → S-05 → S-06 (đủ để "hệ thống là một hệ thống" và dev chạy đúng port).

---

## §7. Definition of Ready để bắt đầu code service

Chỉ khi tất cả đúng:

- [ ] 4 bản `shop.proto` cùng một hash, sinh từ `contracts/proto/` (S-01)
- [ ] `docker compose config` 0 warning; `up -d` 21 container `healthy` ≤ 120s (S-05, S-10)
- [ ] 8 DB container `healthy` + `psql` vào được; `docker-entrypoint.sh` của image Postgres > 0 byte (S-22)
- [ ] Smoke test: một service boot → migration tạo bảng thật → `/health` 500 khi DB tắt (S-22 + C-01)
- [ ] 0 secret tracked; JWT key đọc từ env (S-03, S-04)
- [ ] `dotnet run` ở 9 service dùng đúng port spec, không cần sửa tay (S-06)
- [ ] `dotnet build` 9/9 và `dotnet test` 3/3 xanh trên `dev` (S-07)
- [ ] `specs/02` + `specs/04` mô tả đúng hiện trạng, có cột `Status` (S-13)
- [ ] CI chạy trên `dev`/`mock`, audit P0 = 0 (S-19, S-20)

---

## §8. Rủi ro

| Rủi ro | Ảnh hưởng | Giảm thiểu |
|---|---|---|
| Đổi proto (S-01) làm lệch hợp đồng 3 service đang chạy | Gateway/User/Log/Wallet có thể không build | Chọn bản **đầy đủ nhất** (union) làm chuẩn, chỉ thêm không xoá; build lại 4 repo trước khi commit |
| Secret rotate (S-03) làm token cũ invalid | Phiên dev đang chạy phải login lại | Chấp nhận; ghi rõ trong PR |
| `branch = dev` cho Gateway (S-02) làm mất code `mock` | Nếu `mock` có commit chưa merge | Trước khi đổi, `git log dev..mock` phải rỗng; nếu không thì merge trước |
| S-11 xoá DB trùng trong infra | Ai đang dùng `docker-compose.infra.yml` để chạy DB sẽ phải dùng compose root | Giữ `infra` chỉ chứa 4 hạ tầng; ghi trong README |
| S-09 `USER $APP_UID` làm container không ghi được file | Nếu app ghi `logs/` trong image | Kiểm tra path ghi; chuyển sang volume |
