# 01 — BẢN ĐỒ DỊCH VỤ, CỔNG MẠNG & HẠ TẦNG (SERVICE CATALOG & PORT MAP)

> **Trạng thái triển khai (2026-10-27):** ✅ Đã chuẩn hóa toàn bộ 8 Microservices giao tiếp với ApiGateway qua **HTTP RESTful (`8001`-`8008`)**, loại bỏ hoàn toàn gRPC client/server. Gateway chuyển tiếp qua `RestDownstreamDispatcher` (`ForwardAsync` / `ForwardPagedAsync` / `ForwardNoContentAsync`).
> **Nguồn sự thật:** code và cấu hình Gateway/Microservices (`PLAN-20261027-1400-GLOBAL-RESTFUL-PIVOT-AND-GATEWAY-DECOUPLING.md`).
> **Cập nhật lần cuối:** 2026-10-27.

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

---

### 1.1. Cổng THẬT khi chạy local (`dotnet run` → `launchSettings.json`)

Chạy `dotnet run` **không** dùng port đặc tả trừ khi set `ASPNETCORE_URLS`. Đây là port trong `Properties/launchSettings.json`:

| Service | Port spec | Port local thật | Trạng thái |
|:---|:---:|:---:|:---|
| UserService | `8001` | `8001` | ✅ khớp |
| CatalogService | `8002` | `5272` (https `7232`) | ⚠️ Cần đồng bộ sang 8002 |
| CommerceService | `8003` | `5105` (https `7035`) | ⚠️ Cần đồng bộ sang 8003 |
| LogService | `8004` | `5280` (https `7103`) | ⚠️ Cần đồng bộ sang 8004 |
| AuctionService | `8005` | `5230` (https `7202`) | ⚠️ Cần đồng bộ sang 8005 |
| FulfillmentService | `8006` | `5228` (https `7014`) | ⚠️ Cần đồng bộ sang 8006 |
| NotificationService | `8007` | `8007` | ✅ khớp |
| WalletService | `8008` | `5096` (https `7218`) | ⚠️ Cần đồng bộ sang 8008 |

---

## 2. DỊCH VỤ HẠ TẦNG DÙNG CHUNG (INFRASTRUCTURE SERVICES)

### A. RabbitMQ Message Broker
- **AMQP Port**: `5672` (Giao tiếp Event Bus qua MassTransit).
- **Management UI Port**: `15672` (Giao diện web quản trị queues/exchanges: `http://localhost:15672`).
- **Mặc định**: `guest` / `MatkhaucuaTui123@`.
- **Cấu hình Exchange**:
  - Dạng Exchange: `fanout` hoặc `topic`.
  - Tên Exchange: Theo chuẩn kebab-case của MassTransit (`order-submitted`, `send-otp-email-integration-event`, v.v.).

### B. Cơ Sở Dữ Liệu PostgreSQL (Dải Port 5433 -> 5440)
- **Tài khoản mặc định**: `postgres` / `MatkhaucuaTui123@`.
- **Dải port ánh xạ host**: Bắt đầu từ `5433` đến `5440`, tránh hoàn toàn xung đột với port PostgreSQL mặc định `5432` trên máy host.

### C. Redis In-Memory Store
- **Cổng**: `6379`.
- **Mục đích**:
  - Edge Distributed Rate Limiting (Fixed/Sliding Window per IP & User).
  - Trạng thái phiên & Idempotency key deduplication.
- **Fail-Open Policy**: Trong môi trường `Development`, nếu Redis chưa bật hoặc mất kết nối, Gateway tự động cho request đi qua để không gián đoạn lập trình.

### D. OpenTelemetry OTLP Collector (Observability)
- **HTTP OTLP Receiver Port**: `4318`.
- **HTTP/REST Trace Header**: Chuyển tiếp qua HTTP request headers: `x-trace-id` và W3C `traceparent`.

---

## 3. NGUYÊN TẮC QUY ĐỊNH CỔNG CHO AI AGENTS

- **Tuyệt đối KHÔNG thay đổi dải port** từ `8000` đến `8008` trong code hay cấu hình.
- Khi tạo mới một service backend hoặc thêm endpoint, địa chỉ REST downstream trong `appsettings.json` của Gateway phải ánh xạ đúng port của service đó (ví dụ Catalog $\rightarrow$ `http://localhost:8002`, Notification $\rightarrow$ `http://localhost:8007`).
- Gateway chuyển tiếp hoàn toàn qua HTTP REST downstream (`IHttpClientFactory`), không sử dụng gRPC clients.
