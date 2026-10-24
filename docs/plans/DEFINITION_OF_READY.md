# DEFINITION OF READY / DONE — chuẩn để “bắt đầu vào code”

Mục đích: mọi task (dù ở root hay trong bất kỳ repo nào) có **cùng một cửa vào** và **cùng một cửa ra**. Không còn cảnh mỗi repo làm một kiểu.

---

## 1. Cửa vào chung (DoR-0) — áp dụng cho MỌI task

- [ ] `git rev-parse HEAD` = `meta.json.lastCommit` của repo đó; nếu khác → `node .gitnexus/run.cjs analyze` (rule `RL-05`).
- [ ] Đã đọc theo ma trận `AGENTS.md` §3 của repo tương ứng (6 file `specs/` + `AGENTS.md`).
- [ ] Đã chạy `impact({target:"<symbol>", direction:"upstream"})` cho **từng symbol sẽ sửa**; báo cáo blast radius cho user.
- [ ] Nếu risk `HIGH`/`CRITICAL` → **dừng**, xin xác nhận trước khi sửa.
- [ ] Task có `ID` trong `FIX_BACKLOG.md` (hoặc tạo mới) + `Files` + `Accept` + `h` + `Dep`.
- [ ] Task không phụ thuộc mục P0 còn mở (xem đường găng).
- [ ] Plan đã trình bày (rule §1): Objective · Files · Impact · Steps · Verification.

## 2. Cửa vào theo loại task

### 2.1 Thêm 1 RPC gRPC vào service
- [ ] `contracts/proto/shop.proto` (root) đã có message + `rpc` (nguồn duy nhất — **không** sửa bản copy).
- [ ] Đã chạy `scripts/sync-proto.sh` → 4 bản copy cùng md5.
- [ ] `specs/02_API_GRPC_CONTRACTS.md` của service đã liệt kê rpc đó (bỏ nếu là rpc nội bộ).
- [ ] Use case đã có trong Application (`Features/` hoặc `Services/`) — **không** viết logic trong gRPC class.
- [ ] Có test cho use case (tối thiểu happy path + 1 lỗi).

### 2.2 Thêm 1 endpoint REST ở Gateway
- [ ] Có rpc tương ứng ở backend (hoặc mock fixture nếu chưa có).
- [ ] `GrpcClientsExtension.cs` đã có named client cho service đó.
- [ ] Controller dùng `GatewayDispatcher.DispatchAsync` — **không** tự gọi `GrpcServiceCaller`.
- [ ] Route theo `specs/03` (`api/v1/<domain>/...`), có `[BackendTag]`.
- [ ] Có mock data (`Seeds/` + `MockEngine`) để test khi backend chưa xong.
- [ ] `specs/02_GATEWAY_CONTROLLERS_ROUTING.md` cập nhật danh mục action.

### 2.3 Thêm 1 event (publish hoặc consume)
- [ ] Event `record` nằm trong **shared contracts** (`contracts/events/` hoặc project `Nexus.Contracts`) — không khai 2 lần ở 2 repo.
- [ ] `specs/04_SHARED_CONTRACTS_REGISTRY.md` (root) có dòng: publisher, consumer, routing key, `Status`.
- [ ] `specs/03_EVENT_MESSAGING.md` của service ghi rõ publish/consume.
- [ ] Publisher: publish **sau** khi DB commit (Outbox nếu là nghiệp vụ tiền).
- [ ] Consumer: idempotent (khoá theo `MessageId`) + retry/DLQ.
- [ ] Có test bằng `InMemoryTestHarness` hoặc bắn qua RabbitMQ HTTP API.

### 2.4 Thêm/sửa entity + migration
- [ ] `dbml/service/<svc>.dbml` cập nhật **cùng PR** (không để drift `CT-09`).
- [ ] `DbSet` + `IEntityTypeConfiguration` (nếu có) + `ToTable` naming.
- [ ] Migration mới **không** xoá lịch sử cũ (không regenerate — bài học `HY-02`).
- [ ] `dotnet ef migrations script` chạy được trên DB rỗng và trên DB có dữ liệu cũ.
- [ ] Seed data cập nhật nếu là bảng danh mục.

### 2.5 Thêm/sửa doc hoặc spec
- [ ] File nằm đúng chỗ: root → `docs/`/`specs/`; service → `src/Services/<S>/specs/`.
- [ ] **Không** link ra ngoài repo (inward-only) — kiểm bằng `audit.py --gate doclink`.
- [ ] Mọi con số (số entity, số rpc, số bảng) **sinh từ code**, không viết tay (`DC-03`).
- [ ] Có cột `Status` nếu mô tả thứ chưa tồn tại.

### 2.6 Thay đổi format/CI dùng chung
- [ ] Sửa ở **root** (`Directory.Build.props`, `.editorconfig`, reusable workflow) — không sửa 9 bản.
- [ ] Áp cho 9 repo, chạy `dotnet build -c Release` 9/9 trước khi commit.

---

## 3. Cửa ra chung (DoD-0)

Tất cả phải đúng, không có ngoại lệ “tạm”:

| # | Điều kiện | Lệnh kiểm |
|---|---|---|
| 1 | Build 100% | `dotnet build <S>.sln -c Release` → 0 error, 0 warning mới |
| 2 | Test 100% pass | `dotnet test <S>.sln -c Release` |
| 3 | Gate sạch (không P0) | `python .tools/audit/audit.py --gate all` |
| 4 | Proto đồng nhất | `md5sum` 4 bản = nhau |
| 5 | Không link ra ngoài | `audit.py --gate doclink` |
| 6 | Git sạch, không rác | `git status --porcelain` chỉ có file chủ đích; 0 `bin/`, `obj/`, `.vs/`, `.idea/` |
| 7 | Doc đi cùng code | `specs/` liên quan đã sửa trong **cùng commit** |
| 8 | Impact đã báo cáo | comment trong PR/plan ghi blast radius |

## 4. Cửa ra theo loại task (bổ sung)

| Loại | Thêm điều kiện |
|---|---|
| RPC mới | `grpcurl -plaintext localhost:<port> list` thấy service + method; gọi thử 1 request thật |
| Endpoint Gateway mới | `curl` qua `localhost:8000` với `X-Gateway-Mode: Mock` **và** `Real` đều đúng |
| Event mới | Test publish→consume end-to-end (bật RabbitMQ); DLQ nhận được message lỗi |
| Migration | `dotnet ef database update` trên DB trống + chạy lại app không lỗi |
| Doc/spec | `audit.py --gate doclink` = 0; số liệu khớp `repo_facts.py` |
| CI/format | Push nhánh thử → CI xanh; cố tình vi phạm → CI đỏ |

## 5. Mẫu báo cáo khi hoàn tất task (dán vào PR)

```markdown
## Task: <FIX-xxx> — <tên>
**Repo:** src/Services/<S> · **Branch:** dev · **Commit:** <sha>
**Impact:** <symbol> ← <n> caller, <m> process; risk <LOW|MEDIUM|HIGH>
**Đã làm:** <3–5 gạch đầu dòng>
**Kiểm chứng:**
- `dotnet build ... -c Release` → 0 error
- `dotnet test ...` → <x>/<y> pass
- `audit.py --gate all` → 0 P0
- Thủ công: <curl/grpcurl + kết quả>
**Còn lại / rủi ro:** <nếu có>
```

## 6. Bảng gate ↔ lệnh (dùng chung, không tự chế)

| Gate | Lệnh | Ngưỡng đạt |
|---|---|---|
| port | `audit.py --gate port` | 0 finding |
| proto | `audit.py --gate proto` | 0 P0, 4 hash bằng nhau |
| deps | `audit.py --gate deps` | 0 vi phạm |
| doclink | `audit.py --gate doclink` | 0 outward |
| errmsg | `audit.py --gate errmsg` | 0 P0 |
| surface | `audit.py --gate surface` | mỗi service ≥1 gRPC hoặc ≥1 endpoint |
| trace | `audit.py --gate trace` | mỗi service có OTel + propagation |
| test | `audit.py --gate test` | mỗi service có test project, ≥6 fact |
| format | `audit.py --gate format` | 0 finding |

## 7. Điều cấm (ghi thẳng vào `AGENTS.md` §7)

1. Cấm sửa bản copy `shop.proto` — chỉ sửa `contracts/proto/` rồi sync.
2. Cấm `dotnet ef migrations remove` + regenerate để “cho sạch” (mất lịch sử, phá môi trường đã có dữ liệu).
3. Cấm commit secret vào `appsettings*.json` / `.env.example`.
4. Cấm copy doc giữa các repo bằng tay — doc dùng chung phải ở root.
5. Cấm thêm endpoint/service mà không có gate `surface`/`test` đi kèm.
