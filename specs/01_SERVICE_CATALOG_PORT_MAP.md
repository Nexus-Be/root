# 01 — BẢN ĐỒ DỊCH VỤ, CỔNG MẠNG & HẠ TẦNG (SERVICE CATALOG & PORT MAP)

> **Trạng thái triển khai (2026-10-27):** ✅ Đã chuẩn hóa toàn bộ 8 Microservices giao tiếp với ApiGateway qua **HTTP RESTful (`8001`-`8008`)**, loại bỏ giao tiếp gRPC để đạt tính đồng bộ, type-safe và dễ kiểm thử.

Tài liệu này quy chuẩn toàn bộ bản đồ cổng mạng (Ports), cơ sở dữ liệu và biến môi trường kết nối cho toàn bộ 8 Microservices, ApiGateway và CheckHealService.

---

## 1. BẢNG QUY HOẠCH CỔNG GIAO TIẾP & CƠ SỞ DỮ LIỆU

| Service Name | Cổng HTTP REST (Downstream) | Giao Thức Downstream | Database Engine | Cổng DB | DB Name | Cổng Redis / RabbitMQ |
|:---|:---:|:---:|:---:|:---:|:---|:---:|
| **ApiGateway** | `8000` | HTTP/REST (Edge Proxy) | Redis *(Cache/RateLimit)* | `6379` | `db0` | Redis: `6379` |
| **UserService** | `8001` | REST (JSON over HTTP) | PostgreSQL | `5433` | `usermanagement_db` | RabbitMQ: `5672` |
| **CatalogService** | `8002` | REST (JSON over HTTP) | PostgreSQL (Neon Cloud) | `5434` / Cloud | `catalog_db` | RabbitMQ: `5672` |
| **CommerceService** | `8003` | REST (JSON over HTTP) | PostgreSQL | `5435` | `commerce_db` | RabbitMQ: `5672` |
| **LogService** | `8004` | REST (JSON over HTTP) | PostgreSQL | `5436` | `log_db` | RabbitMQ: `5672` |
| **AuctionService** | `8005` | REST (JSON over HTTP) | PostgreSQL | `5437` | `auction_db` | RabbitMQ: `5672` |
| **FulfillmentService** | `8006` | REST (JSON over HTTP) | PostgreSQL | `5438` | `fulfillment_db` | RabbitMQ: `5672` |
| **NotificationService** | `8007` | REST (JSON over HTTP) | PostgreSQL (Neon Cloud) | `5439` / Cloud | `notification_db` | RabbitMQ: `5672` |
| **WalletService** | `8008` | REST (JSON over HTTP) | PostgreSQL | `5440` | `wallet_db` | RabbitMQ: `5672` |
| **CheckHealService** | `8009` | HTTP Monitoring / Webhook | PostgreSQL Keep-Alive | N/A *(Client)* | Neon / Render | N/A |

**Trạng thái bảng trên:** ✅ cổng trong `Dockerfile` (`EXPOSE` + `ASPNETCORE_URLS`) và `docker-compose.yml` khớp 8/8 service; ✅ connection string trong `appsettings*.json` khớp DB port/name 8/8. Cột "Cổng HTTP REST" ghi `N/A` là **đặc tả mục tiêu** — hiện mọi service đều mở `/health` qua HTTP và Catalog mở thêm REST mock (xem §1.1).

### 1.1. Cổng THẬT khi chạy local (`dotnet run` → `launchSettings.json`)

Chạy `dotnet run` **không** dùng port đặc tả trừ khi set `ASPNETCORE_URLS`. Đây là port thật trong `Properties/launchSettings.json`:

| Service | Port spec | Port local thật | Trạng thái |
|:---|:---:|:---:|:---|
| UserService | `8001` | `8001` | ✅ khớp |
| CatalogService | `8002` | `5272` (https `7232`) | ❌ lệch |
| CommerceService | `8003` | `5105` (https `7035`) | ❌ lệch |
| LogService | `8004` | `5280` (https `7103`) | ❌ lệch |
| AuctionService | `8005` | `5230` (https `7202`) | ❌ lệch |
| FulfillmentService | `8006` | `5228` (https `7014`) | ❌ lệch |
| NotificationService | `8007` | `8007` | ✅ khớp |
| WalletService | `8008` | `5096` (https `7218`) | ❌ lệch |

Hệ quả: gọi Gateway ở chế độ `Real` tới `http://localhost:8002` sẽ **connection refused** nếu service chạy bằng `dotnet run`. Việc sửa 6 file `launchSettings.json` nằm trong `docs/plans/FIX_BACKLOG.md` (FIX-013) / `docs/plans/SETUP_PHASE_PLAN.md` (S-05).

---

## 2. DỊCH VỤ HẠ TẦNG DÙNG CHUNG (INFRASTRUCTURE SERVICES)

### A. RabbitMQ Message Broker
- **AMQP Port**: `5672` (Giao tiếp Event Bus qua MassTransit).
- **Management UI Port**: `15672` (Giao diện web quản trị queues/exchanges: `http://localhost:15672`).
- **Mặc định**: `guest` / `MatkhaucuaTui123@`.
- **Cấu hình Exchange**:
  - Dạng Exchange: `fanout` hoặc `topic`.
  - Tên Exchange: Theo chuẩn kebab-case của MassTransit (`order-submitted`, `stock-reserved`, v.v.).

### B. Cơ Sở Dữ Liệu PostgreSQL (Dải Port 5433 -> 5440)
- **Tài khoản mặc định**: `postgres` / `MatkhaucuaTui123@`.
- **Dải port ánh xạ host**: Bắt đầu từ `5433` đến `5440`, tránh hoàn toàn xung đột với port PostgreSQL mặc định `5432` trên máy host.

### B. Redis In-Memory Store
- **Cổng**: `6379`.
- **Mục đích**:
  - Edge Distributed Rate Limiting (Fixed/Sliding Window per IP & User).
  - Trạng thái phiên & Idempotency key deduplication.
- **Fail-Open Policy**: Trong môi trường `Development`, nếu Redis chưa bật hoặc mất kết nối, Gateway tự động cho request đi qua để không gián đoạn lập trình.

### C. OpenTelemetry OTLP Collector (Observability)
- **gRPC OTLP Receiver Port**: `4317`.
- **HTTP OTLP Receiver Port**: `4318`.
- **Tích hợp (hiện trạng 2026-10-24):** ⚠️ Một phần — Gateway có set/echo `x-trace-id` (`Nexus.Gateway/Dispatching/GrpcServiceCaller.cs:68`, `Extensions/PipelineExtensions.cs:48`) nhưng **0/8 backend đọc header này** (grep `x-trace-id` trong `src/Services/*` ngoài ApiGateway = 0 hit) và **không** có propagation W3C `traceparent`. OpenTelemetry chỉ được cài ở 3 project: `Nexus.Gateway`, `Wallet.Api`, `Log.Api`; 6 service còn lại có key `Otel:Endpoint` trong `appsettings.json` nhưng không có package ⇒ cấu hình chết.

---

## 3. NGUYÊN TẮC QUY ĐỊNH CỔNG CHO AI AGENTS

- **Tuyệt đối KHÔNG thay đổi dải port** từ `8000` đến `8008` trong code hay cấu hình.
  - ⚠️ **Vi phạm hiện tại:** 6/8 `launchSettings.json` đang dùng port ngoài dải (xem §1.1). Đây là lỗi cần sửa về `8000–8008`, không phải ngoại lệ được phép.
- Khi tạo mới một service backend hoặc thêm endpoint, địa chỉ REST downstream trong `appsettings.json` của Gateway phải ánh xạ đúng port của service đó (ví dụ Catalog $\rightarrow$ `http://localhost:8002`).
  - ⚠️ **Vi phạm hiện tại:** `Nexus.Gateway/appsettings.json` khai 8 service `Mode: "Real"` + address `8001–8008`, nhưng `Extensions/GrpcClientsExtension.cs:12` chỉ đăng ký **1** client (`users`). 7 địa chỉ còn lại không có client tương ứng nên không gọi được.
