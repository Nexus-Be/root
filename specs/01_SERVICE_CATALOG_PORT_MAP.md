# 01 — BẢN ĐỒ DỊCH VỤ, CỔNG MẠNG & HẠ TẦNG (SERVICE CATALOG & PORT MAP)

> **Trạng thái triển khai (2026-10-30):** ✅ Đã chuẩn hóa toàn bộ 8 Microservices giao tiếp với ApiGateway qua **HTTP RESTful (`8001`-`8008`)**, loại bỏ hoàn toàn gRPC client/server. Đã bãi bỏ hoàn toàn RabbitMQ Message Broker và MassTransit, thiết lập cụm Dual-Mode Database (Local PostgreSQL ports 5433-5440 và Remote/Neon DB).
> **Nguồn sự thật:** code và cấu hình Gateway/Microservices (`PLAN-20261030-0330-REMOVE-RABBITMQ-AND-SETUP-DUAL-DB.md`).
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này quy chuẩn toàn bộ bản đồ cổng mạng (Ports), cơ sở dữ liệu và biến môi trường kết nối cho toàn bộ 8 Microservices, ApiGateway và CheckHealService.

---

## 1. BẢNG QUY HOẠCH CỔNG GIAO TIẾP & CƠ SỞ DỮ LIỆU

| Service Name | Cổng HTTP REST (Downstream) | Giao Thức Downstream | Database Engine | Cổng DB | DB Name | Hạ Tầng Phụ Trợ |
|:---|:---:|:---:|:---:|:---:|:---|:---:|
| **Gateway (YARP)** | `8080` | HTTP/REST (Edge Proxy) | Redis *(Cache/RateLimit)* | `6379` | `db0` | Redis: `6379` |
| **UserService** | `8001` | REST (JSON over HTTP) | PostgreSQL | `5433` | `usermanagement_db` | Redis: `6379` (OTP/Cache) |
| **CatalogService** | `8002` | REST (JSON over HTTP) | PostgreSQL (Local / Neon) | `5434` / Cloud | `category_db` | N/A |
| **CommerceService** | `8003` | REST (JSON over HTTP) | PostgreSQL (Local / Remote) | `5435` | `commerce_db` | N/A |
| **LogService** | `8004` | REST (JSON over HTTP) | PostgreSQL (Local / Remote) | `5436` | `log_db` | N/A |
| **AuctionService** | `8005` | REST (JSON over HTTP) | PostgreSQL (Local / Remote) | `5437` | `auction_db` | N/A |
| **FulfillmentService** | `8006` | REST (JSON over HTTP) | PostgreSQL (Local / Remote) | `5438` | `fulfillment_db` | N/A |
| **NotificationService** | `8007` | REST (JSON over HTTP) | PostgreSQL (Local / Neon) | `5439` / Cloud | `notification_db` | N/A |
| **WalletService** | `8008` | REST (JSON over HTTP) | PostgreSQL (Local / Remote) | `5440` | `wallet_db` | N/A |
| **CheckHealService** | `8009` | HTTP Monitoring / Webhook | PostgreSQL Keep-Alive | N/A *(Client)* | Neon / Render | N/A |

---

### 1.1. Cổng THẬT khi chạy local (`dotnet run` → `launchSettings.json`)

Chạy `dotnet run` **không** dùng port đặc tả trừ khi set `ASPNETCORE_URLS`. Đây là port trong `Properties/launchSettings.json`:

| Service | Port spec | Port local thật | Trạng thái |
|:---|:---:|:---:|:---|
| ApiGateway | `8080` | `8080` | ✅ khớp (tránh xung đột Portainer 8000) |
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

### A. RabbitMQ Message Broker (ĐÃ BÃI BỎ / DECOMMISSIONED)
- RabbitMQ và MassTransit đã được loại bỏ hoàn toàn khỏi hệ thống để đơn giản hóa kiến trúc và chuyển dịch 100% sang giao tiếp đồng bộ RESTful HTTP/JSON.

### B. Cơ Sở Dữ Liệu PostgreSQL (Dải Port 5433 -> 5440)
- **Cơ chế Dual-Mode**: Hỗ trợ chạy local độc lập qua cụm container tại `src/Infrastructure/databases/docker-compose.yml` (ports `5433` -> `5440`) hoặc kết nối trực tiếp đến PostgreSQL Remote (Neon Cloud).
- **Tài khoản mặc định**: `postgres` / `Password123!`.
- **Dải port ánh xạ host**: Bắt đầu từ `5433` đến `5440`, tránh hoàn toàn xung đột với port PostgreSQL mặc định `5432` trên máy host.

### C. Redis In-Memory Store (Shared Instance - Cổng 6379, Định mức 500MB)
- **Cổng**: `6379` (Container: `nexus-shared-redis`, service: `redis`).
- **Định mức RAM**: Tối đa `500MB` (`--maxmemory 460mb`, `mem_limit: 500m`, policy: `allkeys-lru`, chừa 40MB buffer runtime jemalloc chống OOM).
- **Phân chia Namespace & Mục đích**:
  - **API Gateway**: Edge Distributed Rate Limiting (Fixed/Sliding Window per IP & User) với prefix `nexus:gateway:*`.
    * *Fail-Open Policy*: Trong môi trường `Development`, nếu Redis chưa bật hoặc mất kết nối, Gateway tự động cho request đi qua để không gián đoạn lập trình.
  - **User Service**: Lưu trữ mã OTP đăng ký / đặt lại mật khẩu với cơ chế tự hủy TTL, và cache hồ sơ người dùng với prefix `nexus:otp:*` / `otp:*`.
  - **Cơ chế an toàn**: Nhờ phân vùng key prefix độc lập, một instance Redis 500MB đảm nhận trơn tru cả 2 nhiệm vụ mà không lo xung đột dữ liệu.

### D. OpenTelemetry OTLP Collector (Observability)
- **HTTP OTLP Receiver Port**: `4318`.
- **HTTP/REST Trace Header**: Chuyển tiếp qua HTTP request headers: `x-trace-id` và W3C `traceparent`.

---

## 3. NGUYÊN TẮC QUY ĐỊNH CỔNG CHO AI AGENTS

- **Tuyệt đối tuân thủ quy hoạch dải port**: ApiGateway chạy cổng `8080` (tránh xung đột với Portainer chạy port 8000 trên máy dev); các Microservices backend cố định từ `8001` đến `8008` (CheckHeal: `8009`). Cấm tự ý đổi port trong code hay cấu hình.
- Khi tạo mới một service backend hoặc thêm endpoint, địa chỉ REST downstream trong `appsettings.json` của Gateway phải ánh xạ đúng port của service đó (ví dụ Catalog $\rightarrow$ `http://localhost:8002`, Notification $\rightarrow$ `http://localhost:8007`).
- Gateway chuyển tiếp hoàn toàn qua HTTP REST downstream (`IHttpClientFactory`), không sử dụng gRPC clients.
