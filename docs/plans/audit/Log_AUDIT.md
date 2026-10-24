# AUDIT — Log (`src/Services/Log`)

- **Branch:** `dev` · **Commit:** `6dcc1d8` · **Dirty:** 5 (`Migrations` ×3 `D` + 1 `??`, `AGENTS.md`, `CLAUDE.md`)
- **Quy mô:** 40 file `.cs` / 1.359 LOC · Application 430 · Infrastructure 349 · Api 328 · Domain 252 · **Tests 0**
- **Port:** Dockerfile/`ASPNETCORE_URLS` `8004` ✅ · **`launchSettings.json`: `5280/7103`** ❌ · **DB:** `5436` `log_db` ✅
- **Index:** 62 file / 414 symbol / 557 edge / **2 flow** (ít nhất hệ thống cùng với Notification)

## 1. Kết luận nhanh

Log service có **hợp đồng khớp** (4/4 rpc: `QueryLogs, GetLog, ListLogEventTypes, SetLogEventTypeEnabled`), có OTel, có CQRS + consumer.

Nhưng **toàn bộ đường ống log của hệ thống đang chết ở cả hai đầu** — và chết âm thầm:

1. **Gateway gửi log tới một endpoint không tồn tại.** `GatewayBatchLogSink.cs:55` POST `{RemoteEndpoint}/api/v1/log/batch` với `RemoteEndpoint = http://localhost:8004` (`appsettings.json:18`). Log service chỉ có `app.MapGet("/health")` và `app.MapGet("/")` (`Log.Api/Program.cs:66-67`) → **404**, và lỗi bị nuốt bởi `catch { /* fail-safe */ }` (`:57-60`). Không một log nào từ gateway tới được Log service.
2. **Event `ILogEventOccurred` không có publisher.** Interface ở `Log.Domain/Events/LogEvents.cs:3`, consumer ở `Log.Application/Consumers/GlobalLogConsumer.cs:10` — grep toàn 9 repo: **0 chỗ publish**. Consumer là code chết.
3. **3 thông báo lỗi tiếng Việt** trong gRPC service (`LogGrpcService.cs:70` “ID nhật ký không hợp lệ”, `:74` “Không tìm thấy nhật ký tương ứng”, `:122` “Code không được để trống”).
4. **Port trong `launchSettings.json` lệch spec** (`5280/7103` thay vì `8004`) — dev chạy F5 sẽ lên sai port, gateway gọi `8004` không thấy gì.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ✅ | `Application/Features/`, `Consumers/`, `DTOs/`, `Common/` rạch ròi; `Api/Contracts` chứa proto |
| C2 | Dễ sửa, ít phụ thuộc | ✅ | 0 ref chéo service; MediatR handler độc lập |
| C3 | File đúng folder, liên kết đồng nhất | ❌ | Gateway↔Log đứt ở cả HTTP (`/api/v1/log/batch` không tồn tại) và event (không publisher) |
| C4 | Test/chạy độc lập | ❌ | 0 test project |
| C5 | Theo dõi request | ⚠️ | Là **1 trong 3 repo có OTel**, nhưng không đọc `x-trace-id` inbound; và vì không nhận được log nên không hiển thị được trace nào |
| C6 | Doc là sự thật | ⚠️ | `specs/02` 4 rpc ↔ 4 impl ✅; nhưng `specs/03` mô tả consumer `ILogEventOccurred` như đang hoạt động, thực tế không publisher |
| C7 | Luật đúng | ❌ | 3 chuỗi tiếng Việt; port lệch spec (luật “port bất biến”) |
| C8 | Format đồng nhất | ⚠️ | `Log` là repo duy nhất có `Api/Contracts` + `Api/Extensions`; package `FluentValidation` chỉ Log + Wallet |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| LG-01 | **P0** | Gateway → Log ingestion 404, lỗi bị nuốt | `Nexus.Gateway/Logging/GatewayBatchLogSink.cs:55` POST `/api/v1/log/batch`; `Log.Api/Program.cs:66-67` chỉ `/health`, `/`; `catch {}` tại sink `:57` | Hoặc thêm `POST /api/v1/log/batch` vào Log.Api (map sang `CreateLogBatchCommand`), hoặc đổi sink sang publish `ILogEventOccurred` qua RabbitMQ |
| LG-02 | **P0** | `ILogEventOccurred` không có publisher | `Log.Domain/Events/LogEvents.cs:3`; grep 9 repo = 0 publisher | Chọn **một** cơ chế (HTTP batch hoặc event) và xoá cơ chế còn lại |
| LG-03 | **P0** | 3 error message tiếng Việt | `Log.Api/Services/LogGrpcService.cs:70,74,122` | Dịch English + error code (`LOG_ID_INVALID`, `LOG_NOT_FOUND`, `LOG_CODE_REQUIRED`) |
| LG-04 | **P0** | 0 test | không có `Log.Tests` | Thêm test cho 4 handler + consumer |
| LG-05 | **P1** | `launchSettings.json` port `5280/7103` ≠ `8004` | `Log.Api/Properties/launchSettings.json` | Sửa về `8004` |
| LG-06 | **P1** | Không đọc `x-trace-id` từ metadata → log entry không nối được request | không có interceptor; `AuditLog.TraceId` (nếu có) luôn null | Thêm `Interceptor` gRPC đọc header → `Activity`/`LogEntry.TraceId` |
| LG-07 | **P2** | `SetLogEventTypeEnabled` là command nhưng không phân quyền admin ở tầng service (chỉ dựa vào gateway) | `LogGrpcService.cs` không kiểm tra `x-user-roles` | Kiểm tra role ở service (defense in depth) |

## 4. Điểm mạnh

- Có OTel + có `AuditSyncBatch`, `SecurityAuditAlert`, `LogEventType` — mô hình dữ liệu log khá đầy đủ (6 bảng).
- Query có phân trang (`QueryLogsQuery` → `LogPageDto`) — đúng hướng cho tra cứu log.

## 5. Việc phải làm trước khi coi Log “xong”

1. `LG-01` + `LG-02` — chọn 1 đường ống log duy nhất (khuyến nghị: event qua RabbitMQ, vì đã có consumer + MassTransit).
2. `LG-03` + `LG-04`.
3. `LG-05` — port.
