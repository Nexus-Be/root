# Nexus Microservices Ecosystem (.NET 8)

Hệ sinh thái thương mại điện tử & đấu giá trực tuyến phân tán xây dựng trên nền tảng **.NET 8 LTS (C# 12)** theo kiến trúc **Clean Architecture** và **3-Tier Decoupling Gateway**.

---

## 1. Bản Đồ Dịch Vụ & Cổng Mạng (Service & Port Catalog)

| Dịch Vụ | Port App | Database | Port DB | Nhiệm Vụ Chính |
| :--- | :---: | :--- | :---: | :--- |
| **ApiGateway** | **8080** | Redis 7 | **6379** | Điểm vào duy nhất, Rate Limiting, JWT/RBAC, Mock Engine |
| **UserService** | **8001** | `usermanagement_db` (Postgres) | **5433** | Đăng ký, đăng nhập, JWT, User Profile, RBAC, Duyệt Seller |
| **CatalogService** | **8002** | `category_db` (Postgres) | **5434** | Danh mục, sản phẩm, quản lý tồn kho kho ảo của Seller |
| **CommerceService** | **8003** | `commerce_db` (Postgres) | **5435** | Giỏ hàng, đơn hàng, điều phối Checkout Saga |
| **LogService** | **8004** | `log_db` (Postgres) | **5436** | Nhật ký hệ thống tập trung (Centralized log trail) |
| **AuctionService** | **8005** | `auction_db` (Postgres) | **5437** | Phiên đấu giá, trả giá (bid), đồng hồ đếm ngược |
| **FulfillmentService** | **8006** | `fulfillment_db` (Postgres) | **5438** | Kho bãi vật lý, tính phí vận chuyển, tra cứu vận đơn |
| **NotificationService** | **8007** | `notification_db` (Postgres) | **5439** | Quản lý thông báo, cài đặt thông báo người dùng |
| **WalletService** | **8008** | `wallet_db` (Postgres) | **5440** | Ví điện tử, số dư, nạp/rút tiền, chuyển tiền nội bộ |

### Hạ Tầng Dùng Chung (Shared Platform Infrastructure)
- **RabbitMQ**: Port `5672` (AMQP), Port `15672` (Management UI tại `http://localhost:15672`, tài khoản: `guest` / `MatkhaucuaTui123@`).
- **Redis**: Port `6379` (Distributed Cache & Rate Limiting).
- **Grafana Tempo**: Port `4317` (OTLP gRPC), Port `4318` (OTLP HTTP), Port `3200` (API).
- **Grafana Dashboard**: Port `3000` (`http://localhost:3000/explore`).

---

## 2. Hướng Dẫn Vận Hành Với Docker Compose

Hệ thống được thiết kế linh hoạt với 3 cấp độ vận hành tùy theo nhu cầu:

### Cách 1: Chỉ Chạy Hạ Tầng Nền Tảng & Databases (Khuyên dùng khi Dev)
Khi bạn muốn viết code bằng Visual Studio / Rider / VS Code và chạy service bằng `dotnet run`:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d
```
Lệnh này khởi động toàn bộ:
- RabbitMQ, Redis, Tempo, Grafana
- 8 Cơ sở dữ liệu PostgreSQL độc lập (ports 5433 - 5440, mật khẩu mặc định `MatkhaucuaTui123@`)

---

### Cách 2: Chạy Toàn Bộ Hệ Thống Bằng Container (Full Stack)
Khi cần demo hoặc kiểm thử tích hợp toàn sàn:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose up -d
```
Lệnh này dựng trọn bộ:
- Toàn bộ Hạ tầng & Databases
- API Gateway (port 8080)
- 8 Microservices container (ports 8001 - 8008)

---

### Cách 3: Làm Việc Độc Lập Trong Từng Microservice Repository
Mỗi Microservice là một repository độc lập và sở hữu file `docker-compose.yml` riêng:
```bash
# Ví dụ khi chỉ làm việc với CatalogService:
cd src/Services/Catalog

# 1. Chỉ bật Database riêng của Catalog (category_db tại port 5434):
docker compose up -d db

# 2. Chạy ứng dụng Catalog cục bộ:
dotnet run --project Catalog.Api
```

---

## 3. Theo Dõi Distributed Tracing Trên Grafana
1. Mở trình duyệt vào: `http://localhost:3000/explore`.
2. Datasource đã được cấu hình mặc định là **Tempo**.
3. Dán `traceId` từ HTTP response header `X-Trace-Id` vào ô tìm kiếm để xem toàn bộ luồng request xuyên suốt từ Gateway qua các Microservices, Database SQL queries và RabbitMQ events.

---

## 4. Tài Liệu Kỹ Thuật Chi Tiết (Documentation Index)

Toàn bộ tài liệu kỹ thuật được chuẩn hóa và lưu trữ tại thư mục **`docs/`**:

### 📘 Cẩm Nang Phát Triển (Developer Guides):
- **[Hướng Dẫn Cầm Tay Chỉ Việc: Ghép Nối API & Tích Hợp Liên Microservice (SERVICE_INTEGRATION_GUIDE.md)](SERVICE_INTEGRATION_GUIDE.md)** *(Đọc khi ghép luồng Gateway - gRPC - RabbitMQ Event)*
- **[Cẩm Nang Phát Triển & Kiểm Thử Độc Lập 1 Service (docs/INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md)](docs/INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md)** *(Đọc trước khi code service)*
- **[Quy Chuẩn Kiến Trúc Clean Architecture 4 Tầng Cho Microservices (docs/CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)](docs/CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)**
- **[Hướng Dẫn Tạo Mock API, Chuyển Đổi Runtime, Bypass Auth & Health Check (docs/GUIDE_MOCK_DATA_GATEWAY.md)](docs/GUIDE_MOCK_DATA_GATEWAY.md)**
- **[Đặc Tả Kiến Trúc & Cẩm Nang 15 Thư Mục API Gateway (docs/GATEWAY_ARCHITECTURE_AND_FOLDERS.md)](docs/GATEWAY_ARCHITECTURE_AND_FOLDERS.md)**
- **[Lộ Trình Các Bước Kế Tiếp & Checklist Triển Khai (docs/NEXT_STEPS_AND_CHECKLIST.md)](docs/NEXT_STEPS_AND_CHECKLIST.md)**
- **[Đặc Tả Danh Mục Entity & Enum Chuẩn Form Cho Frontend (docs/FRONTEND_ENTITY_AND_ENUM_CATALOG.md)](docs/FRONTEND_ENTITY_AND_ENUM_CATALOG.md)**
- **Cẩm Nang Riêng Của Từng Service**:
  - [UserService](src/Services/User/README.md) | [CatalogService](src/Services/Catalog/README.md) | [CommerceService](src/Services/Commerce/README.md) | [AuctionService](src/Services/Auction/README.md)
  - [FulfillmentService](src/Services/Fulfillment/README.md) | [NotificationService](src/Services/Notification/README.md) | [LogService](src/Services/Log/README.md) | [WalletService](src/Services/Wallet/README.md) | [ApiGateway](src/Services/ApiGateway/README.md)

### 🛠️ Cẩm Nang Hạ Tầng Kỹ Thuật Chuyên Biệt (Infrastructure Guides):
- **[Hướng Dẫn Hạ Tầng RabbitMQ & MassTransit Message Bus (docs/infra/RABBITMQ_GUIDE.md)](docs/infra/RABBITMQ_GUIDE.md)**
- **[Hướng Dẫn Hạ Tầng Redis: Rate Limiting & Mã OTP (docs/infra/REDIS_GUIDE.md)](docs/infra/REDIS_GUIDE.md)**
- **[Hướng Dẫn Giám Sát Phân Tán: Grafana & Tempo Traces (docs/infra/OBSERVABILITY_GUIDE.md)](docs/infra/OBSERVABILITY_GUIDE.md)**
- **[Hướng Dẫn 8 Cơ Sở Dữ Liệu PostgreSQL & EF Core Migrations (docs/infra/POSTGRES_DATABASES_GUIDE.md)](docs/infra/POSTGRES_DATABASES_GUIDE.md)**

### 🏛️ Quyết Định Kiến Trúc & Quy Chuẩn Hệ Thống:
- **[Hệ Thống 15 Quyết Định Kiến Trúc Toàn Hệ Thống (docs/adr/ADR.md)](docs/adr/ADR.md)**
- **[Kiến Trúc Health Prober & Chiến Lược Log Tập Trung (docs/HEALTH_AND_LOGGING_ARCHITECTURE.md)](docs/HEALTH_AND_LOGGING_ARCHITECTURE.md)**
- **[Bộ Đặc Tả Kỹ Thuật Trung Tâm (specs/README.md)](specs/README.md)**
- **[Trung Tâm Điều Hướng Tài Liệu Tổng Thể (docs/README.md)](docs/README.md)**
