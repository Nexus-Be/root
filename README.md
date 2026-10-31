# Nexus Microservices Ecosystem (.NET 8)

Hệ sinh thái thương mại điện tử & đấu giá trực tuyến phân tán xây dựng trên nền tảng **.NET 8 LTS (C# 12)** theo kiến trúc **Clean Architecture** và **3-Tier Decoupling Gateway**.

---

## 1. Bản Đồ Dịch Vụ & Cổng Mạng (Service & Port Catalog)

| Dịch Vụ | Port App | Database Neon | Port DB | Nhiệm Vụ Chính |
| :--- | :---: | :--- | :---: | :--- |
| **Gateway** | **8080** | Redis Rate Limit | **6379** | Điểm vào duy nhất, Rate Limiting, JWT/RBAC, Identity Propagation |
| **UserService** | **8001** | `user` | **5432** | Đăng ký, đăng nhập, JWT, User Profile, RBAC, Duyệt Seller |
| **CatalogService** | **8002** | `catalog` | **5432** | Danh mục, sản phẩm, quản lý tồn kho kho ảo của Seller |
| **CommerceService** | **8003** | `commerce` | **5432** | Giỏ hàng, đơn hàng, điều phối Checkout qua REST |
| **LogService** | **8004** | `log` | **5432** | Nhật ký hệ thống tập trung |
| **AuctionService** | **8005** | `auction` | **5432** | Phiên đấu giá, trả giá, đồng hồ đếm ngược |
| **FulfillmentService** | **8006** | `fulfillment` | **5432** | Kho bãi vật lý, phí vận chuyển, vận đơn |
| **NotificationService** | **8007** | `notification` | **5432** | Thông báo in-app, email SMTP/OTP |
| **WalletService** | **8008** | `wallet` | **5432** | Ví điện tử, số dư, nạp/rút, chuyển tiền nội bộ |
| **CheckHealService** | **8009** | Không có DB riêng | - | Giám sát health 8 service và 8 database Neon |

### Hạ Tầng Dùng Chung (Shared Platform Infrastructure)
- **Redis In-Memory Store**: Port `6379` (`nexus-shared-redis`, 500MB RAM, chia sẻ giữa Gateway Rate Limit và User OTP/Cache).
- **Grafana Tempo**: Port `4317` (OTLP gRPC), Port `4318` (OTLP HTTP), Port `3200` (API).
- **Prometheus**: Port `9090`.
- **Grafana Dashboard**: Port `3000` (`http://localhost:3000/explore`).
- **Database**: 8 database Neon Cloud độc lập, một database cho mỗi service. Cụm PostgreSQL local trong `src/Infrastructure/databases` chỉ là phương án dự phòng khi phát triển offline.

---

## 2. Hướng Dẫn Vận Hành Với Docker Compose

Hệ thống tách làm 2 lớp: hạ tầng dùng chung và stack 10 service.

### Bước 0: Tạo network dùng chung
```bash
docker network create nexus-network
```
Chỉ cần chạy một lần trên mỗi máy.

### Cách 1: Chỉ chạy hạ tầng dùng chung (khuyên dùng khi dev bằng IDE)
```bash
docker compose -f docker-compose.infra.yml up -d
```
Lệnh này chỉ khởi động Redis, Tempo, Prometheus, Grafana. Cụm database local trong `src/Infrastructure/databases` là tùy chọn dự phòng, mặc định hệ thống dùng Neon.

### Cách 2: Chạy toàn bộ stack 10 service
```bash
docker compose up -d --build
```
Root `docker-compose.yml` là stack phẳng gồm đúng 10 service trong `src/Services`: Gateway, User, Catalog, Commerce, Log, Auction, Fulfillment, Notification, Wallet, CheckHeal. File này không chứa Redis, Tempo, Prometheus, Grafana và không chứa container database.

Chạy riêng một service:
```bash
docker compose up -d user-service
```

### Cách 3: Làm việc độc lập trong từng microservice repository
Mỗi repo trong `src/Services` có `.env`, `.env.example` và `docker-compose.yml` riêng, dùng được độc lập:
```bash
cd src/Services/Catalog
cp .env.example .env
docker compose up -d --build
```
Repo con dùng chung container name với stack root, nên chỉ chạy một trong hai tại một thời điểm.

---

## 3. Theo Dõi Distributed Tracing Trên Grafana
1. Mở trình duyệt vào: `http://localhost:3000/explore`.
2. Datasource đã được cấu hình mặc định là **Tempo**.
3. Dán `traceId` từ HTTP response header `X-Trace-Id` vào ô tìm kiếm để xem toàn bộ luồng request xuyên suốt từ Gateway qua các Microservices và Database SQL queries.

---

## 4. Tài Liệu Kỹ Thuật Chi Tiết (Documentation Index)

Toàn bộ tài liệu kỹ thuật được chuẩn hóa và lưu trữ tại thư mục **`docs/`**:

### 📘 Cẩm Nang Phát Triển (Developer Guides):
- **[Hướng Dẫn Cầm Tay Chỉ Việc: Ghép Nối API & Tích Hợp Liên Microservice (SERVICE_INTEGRATION_GUIDE.md)](SERVICE_INTEGRATION_GUIDE.md)** *(Đọc khi ghép luồng Gateway - REST Downstream - Typed Clients)*
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
- **[Hướng Dẫn Hạ Tầng Redis: Rate Limiting & Mã OTP (docs/infra/REDIS_GUIDE.md)](docs/infra/REDIS_GUIDE.md)**
- **[Hướng Dẫn Giám Sát Phân Tán: Grafana & Tempo Traces (docs/infra/OBSERVABILITY_GUIDE.md)](docs/infra/OBSERVABILITY_GUIDE.md)**
- **[Hướng Dẫn 8 Cơ Sở Dữ Liệu PostgreSQL & EF Core Migrations (docs/infra/POSTGRES_DATABASES_GUIDE.md)](docs/infra/POSTGRES_DATABASES_GUIDE.md)**

### 🏛️ Quyết Định Kiến Trúc & Quy Chuẩn Hệ Thống:
- **[Hệ Thống 15 Quyết Định Kiến Trúc Toàn Hệ Thống (docs/adr/ADR.md)](docs/adr/ADR.md)**
- **[Kiến Trúc Health Prober & Chiến Lược Log Tập Trung (docs/HEALTH_AND_LOGGING_ARCHITECTURE.md)](docs/HEALTH_AND_LOGGING_ARCHITECTURE.md)**
- **[Bộ Đặc Tả Kỹ Thuật Trung Tâm (specs/README.md)](specs/README.md)**
- **[Trung Tâm Điều Hướng Tài Liệu Tổng Thể (docs/README.md)](docs/README.md)**
