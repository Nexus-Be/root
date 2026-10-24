# AUDIT — Hạ tầng & vận hành (compose, Dockerfile, CI, cấu hình, bí mật)

**Câu hỏi:** có chạy được như một hệ thống không; format chung có đồng nhất không.

## 0. Kết luận

Phần **build/đóng gói rất tốt và đồng nhất**: 9 Dockerfile cùng khuôn, 9 solution build 100% ở `Release`, compose dựng đủ 21 container (4 hạ tầng + 8 DB + Gateway + 8 service), `specs/01` khớp 100% port/DB.

Phần **vận hành (delivery pipeline) thì chưa tồn tại**: CI ở cả 9 repo **giống hệt nhau** nhưng chỉ chạy khi push/PR vào nhánh `main` — trong khi 8 repo làm việc trên `dev` và Gateway trên `mock` → **CI chưa từng chạy**. CI cũng **không chạy `dotnet test`**: chỉ build image Docker rồi push. Test chỉ tồn tại ở 3 repo và chỉ chạy tay.

Hai vấn đề bí mật: khoá ký JWT thật bị commit vào `appsettings.json` + `appsettings.Development.json` của Gateway; mật khẩu Postgres/RabbitMQ thật (`MatkhaucuaTui123@`) nằm trong **toàn bộ `.env.example`** và cả 2 compose file.

## 1. Compose

| Hạng mục | Thực tế | Đánh giá |
|---|---|---|
| `docker-compose.yml` (root) | **21 service**: `rabbitmq, redis, tempo, grafana` + 8 DB (`user-db`…`wallet-db`) + `gateway` + 8 `*-service` | ✅ Đủ |
| Healthcheck | **10** (`8 DB + rabbitmq + redis`) | ✅ DB/broker có gate |
| `docker-compose.infra.yml` | 12 service (4 hạ tầng + 8 DB) | ⚠️ **Định nghĩa 8 DB lặp lại ở 2 file** → sửa 1 chỗ là lệch chỗ kia |
| Port mapping | khớp `specs/01` (`8000–8008`, `5433–5440`, `5672/15672`, `6379`, `4317/4318`) | ✅ gate `port` 0 lỗi |

## 2. Dockerfile

9 file, cùng khuôn `aspnet:8.0 → sdk:8.0 build → publish → final`, `EXPOSE` + `ASPNETCORE_URLS` đúng port từng service.

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| OP-01 | **P1** | Dockerfile chạy bằng **root** (không `USER app`) | 9/9 Dockerfile | Thêm `USER $APP_UID` |
| OP-02 | **P2** | Không `HEALTHCHECK` trong image (chỉ compose healthcheck DB) | 9/9 | Thêm `HEALTHCHECK` gọi `/health` |
| OP-03 | **P2** | Dockerfile copy `*.Tests.csproj` chỉ có ở `User/Dockerfile` → thêm Tests cho service khác sẽ **vỡ image build** (restore sln cần file) | `src/Services/User/Dockerfile:13` vs Catalog (không có) | Bỏ restore theo sln, restore theo từng csproj |

## 3. CI/CD

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| OP-04 | **P0** | CI **chưa từng chạy**: trigger chỉ `main`, thực tế làm trên `dev`/`mock` | 9 file `.github/workflows/ci-cd.yml` **cùng md5 `e072b742e593a29bfc02cbed24472ccf`**, `on: push/pull_request: branches: ["main"]` | Thêm `dev` + `mock` vào trigger (hoặc đổi default branch) |
| OP-05 | **P0** | CI **không chạy test**, không build .NET — chỉ build Docker image và push | toàn bộ workflow: `checkout → buildx → login → metadata → build-push` | Thêm job `dotnet build -c Release` + `dotnet test` trước job image; fail thì không push |
| OP-06 | **P1** | Không có quality gate (format, warning-as-error, proto breaking change) | không `.editorconfig`, không `Directory.Build.props`, không `TreatWarningsAsErrors` ở bất kỳ csproj | Thêm `Directory.Build.props` chung (root) + `.editorconfig`; job `dotnet format --verify-no-changes` |
| OP-07 | **P1** | 9 bản CI y hệt nhau phải sửa 9 lần | cùng md5 | Chuyển sang reusable workflow ở root (`.github/workflows/service-ci.yml` + 9 file gọi `uses:`) |

## 4. Cấu hình & bí mật

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| OP-08 | **P0** | Khoá ký JWT thật bị commit | `ApiGateway/Nexus.Gateway/appsettings.json:26` và `appsettings.Development.json:25` cùng giá trị `$d)aam<_ze0E0bGB/5b7YE\|^(sxQF_V(,dZusL*?$G{aqgXd&$M#+wd(R+<JN%eZ`; 2 file `*.example.json` đã đúng placeholder | Rotate key, chuyển sang `Jwt:Signature` từ env/secret, thêm vào `.gitignore` |
| OP-09 | **P0** | Mật khẩu Postgres/RabbitMQ thật nằm trong 18 file `.env.example` + 2 compose | `grep -l 'MatkhaucuaTui123@'` → 8×`.env`, 8×`.env.example`, `docker-compose.yml`, `docker-compose.infra.yml` | Đổi sang `CHANGE_ME` trong example; compose đọc `${POSTGRES_PASSWORD:?}` |
| OP-10 | **P1** | `.env` đã được gitignore đúng (`!.env.example` whitelist) — tốt | `src/Services/User/.gitignore:38-42` | Giữ nguyên |
| OP-11 | **P2** | `appsettings.Development.json` được commit (thường không nên) | có trong git | Đưa vào `.gitignore`, giữ `.example` |

## 5. Bảng “chạy được hay không” (thực nghiệm)

| Bước | Kết quả thực tế |
|---|---|
| `dotnet build <S>.sln -c Release` | ✅ 9/9 EXIT 0 |
| `dotnet test` | ✅ 3/3 repo có test EXIT 0 (ApiGateway 62 fact, User 9, Notification 2) · 6 repo không có test project |
| `docker compose up` toàn hệ | ⚠️ chưa chạy trong audit (read-only) — nhưng DB migrate lúc startup sẽ **không tạo bảng** nếu dùng migration cũ, và migration mới chưa commit (xem `HY-02`) |
| Gọi 1 API thật qua Gateway | ⚠️ chỉ nhánh `users` có client; 11/15 controller rỗng |
| Nhận event OTP | ✅ User publish → Notification consume (khi RabbitMQ bật) |
| Xem trace trên Grafana | ⚠️ chỉ Gateway/Log/Wallet export OTel |
