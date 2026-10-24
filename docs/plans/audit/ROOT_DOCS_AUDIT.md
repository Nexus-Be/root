# AUDIT — Root `docs/` (15 tài liệu)

**Phạm vi:** `docs/README.md` + 9 guide + `docs/adr/ADR.md` + `docs/infra/` 4 file. **Không** tính `docs/plans/` (do audit sinh ra).

## 0. Kết luận

Vị trí và phân cấp **đúng** (`docs/` cho toàn hệ, `docs/infra/` cho hạ tầng, `docs/adr/` cho quyết định; spec thuộc từng repo nằm trong repo đó — không có file root nào bị đặt sai chỗ hay trỏ ngược vào submodule).

Nhưng **3 tài liệu hướng dẫn đang dạy người đọc làm những việc không thể làm trên code hiện tại**: `ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md` (test gRPC bằng reflection cho 8 service — chỉ 3 service có), `INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md` (chạy `dotnet test` từng service — 6/8 không có test project), và `HEALTH_AND_LOGGING_ARCHITECTURE.md` (Gateway gửi log lên `POST /api/v1/log/batch` — endpoint không tồn tại, đang 404 âm thầm).

## 1. Bảng đối chiếu

| File | Vị trí | Đúng sự thật? | Bằng chứng |
|---|---|---|---|
| `README.md` | ✅ | ⚠️ | Claim “78 Enums” ✅ (đếm được 78); claim “**88 Entities**” ❌ (86 class entity, 87 bảng dbml) |
| `CLEAN_ARCHITECTURE_SERVICE_GUIDE.md` | ✅ | ✅ | 4 tầng + cấm Repository pattern khớp code 9/9 (gate `deps` 0 vi phạm) |
| `GATEWAY_ARCHITECTURE_AND_FOLDERS.md` | ✅ | ⚠️ | Mô tả `ModeEvaluator`/`gateway.runtime.json` **đúng** (file tồn tại `Nexus.Gateway/gateway.runtime.json`); nhưng mô tả pipeline như đã nối 8 backend — thực tế 1 |
| `GUIDE_MOCK_DATA_GATEWAY.md` | ✅ | ✅ | Mock engine + `Seeds/` + `X-Gateway-Mode` khớp `GatewayDispatcher`/`MockDataMapper` |
| `HEALTH_AND_LOGGING_ARCHITECTURE.md` | ✅ | ❌ | `:89-90` yêu cầu chọn 1 trong 2 cơ chế đẩy log sang LogService; code chọn HTTP `POST /api/v1/log/batch`, LogService **không có endpoint này** (chỉ `/health`, `/`, gRPC `:8004`) → 404 bị `catch {}` nuốt |
| `INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md` | ✅ | ❌ | `:104` dùng `gateway.runtime.json` ✅; `:181-187` “chạy bộ test tự động của service” ❌ cho 6/8 service (không có test project) |
| `ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md` | ✅ | ❌❌ | `:44` “nhờ `Grpc.AspNetCore.Server.Reflection` … không cần import proto” nhưng 5/8 service **không có gRPC server**; `:46-56` bảng 8 cổng gRPC như thể cả 8 hoạt động; 3 ví dụ event: OTP ✅ chạy được, Log ❌ (không publisher), Wallet ❌ (`IStockReservedEvent` không ai phát) |
| `FRONTEND_ENTITY_AND_ENUM_CATALOG.md` | ✅ | ⚠️ | 88 entity như README → cùng sai lệch |
| `FRONTEND_ENUM_SPECIFICATION.md` | ✅ | ✅ | 78 enum khớp |
| `NEXT_STEPS_AND_CHECKLIST.md` | ✅ | ⚠️ | Lộ trình 4 giai đoạn — nhưng không đánh dấu giai đoạn nào đã xong, đọc không biết đang ở đâu |
| `adr/ADR.md` | ✅ | ⚠️ | 32 mục ADR về kiến trúc **không** có ADR cho 3 quyết định đang chặn tiến độ: (a) nguồn sự thật proto, (b) Ai phát JWT, (c) Kho thuộc Catalog hay Fulfillment |
| `infra/OBSERVABILITY_GUIDE.md` | ✅ | ⚠️ | Hướng dẫn Tempo/Grafana; thực tế `infra/tempo/tempo.yaml` + `infra/grafana/datasources.yaml` có, nhưng 6 service không export OTel → Grafana chỉ thấy Gateway |
| `infra/POSTGRES_DATABASES_GUIDE.md` | ✅ | ✅ | 8 DB/port khớp `specs/01` + compose |
| `infra/RABBITMQ_GUIDE.md` | ✅ | ⚠️ | Mô tả exchange/queue chuẩn; thực tế 6/8 event trong `specs/04` không tồn tại nên chỉ 1 queue thật sự có traffic |
| `infra/REDIS_GUIDE.md` | ✅ | ✅ | Rate limit/idempotency khớp `Security/` + middleware Gateway |

## 2. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| DC-01 | **P0** | Guide “test độc lập từng function” không thực hiện được với 5/8 service | `ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md:44-56` | Thêm cảnh báo “service X chưa có gRPC” hoặc chỉ viết guide sau khi có surface (xem `T1.6`) |
| DC-02 | **P0** | Kiến trúc logging đứt: Gateway → LogService 404 | `Nexus/Gateway/Logging/GatewayBatchLogSink.cs:55` vs `Log.Api/Program.cs:66-67` | Thêm endpoint `POST /api/v1/log/batch` (hoặc publish `LogBatchCreatedIntegrationEvent` qua RabbitMQ) + bỏ `catch {}` |
| DC-03 | **P1** | Số liệu doc lệch code (88 entity / 78 enum) | 86 entity class, 87 bảng dbml, 78 enum | Sinh số liệu bằng `.tools/audit/repo_facts.py` thay vì viết tay |
| DC-04 | **P1** | ADR thiếu 3 quyết định đang chặn (proto SoT, JWT issuer, quyền sở hữu kho) | `docs/adr/ADR.md` mục lục | Viết ADR-033/034/035 trước khi sửa code liên quan |
| DC-05 | **P2** | `NEXT_STEPS_AND_CHECKLIST.md` không có trạng thái | — | Thêm cột `Done/Doing/Todo` + gate tương ứng |
| DC-06 | **P2** | 3 tài liệu dạy cách dùng event không tồn tại (Log, Wallet) | `ISOLATED_TESTING…:148-176` | Comment “chưa khả dụng — xem FIX_BACKLOG” |

## 3. Về câu hỏi “doc đã tách biệt từng phần chưa?”

**Có, nhưng không đều.** Root `docs/` chỉ mô tả **toàn hệ + Gateway + hạ tầng** (đúng vai trò). Tài liệu riêng từng service nằm ở `specs/` của repo đó (đúng nguyên tắc inward-only, gate `doclink` 0 outward link). Vấn đề là **spec từng service đang hứa nhiều hơn code** (xem 9 file `*_AUDIT.md`) — nên “doc là thành phần sự thật” hiện chỉ đúng ở `specs/01`, `specs/03` (phần envelope), `CLEAN_ARCHITECTURE_SERVICE_GUIDE`, `infra/POSTGRES_DATABASES_GUIDE`, `GUIDE_MOCK_DATA_GATEWAY`.
