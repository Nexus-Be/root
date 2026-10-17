# Nexus Microservices Ecosystem (.NET 8)

Hệ sinh thái thương mại điện tử & đấu giá trực tuyến phân tán xây dựng trên nền tảng **.NET 8 LTS (C# 12)** theo kiến trúc **Clean Architecture** và **3-Tier Decoupling Gateway**.

---

## 1. Bản Đồ Dịch Vụ & Cổng Mạng (Service & Port Catalog)

| Dịch Vụ | Port App | Database | Port DB | Nhiệm Vụ Chính |
| :--- | :---: | :--- | :---: | :--- |
| **ApiGateway** | **8000** | Redis 7 | **6379** | Điểm vào duy nhất, Rate Limiting, JWT/RBAC, Mock Engine |
| **UserService** | **8001** | `usermanagement_db` (Postgres) | **5432** | Đăng ký, đăng nhập, JWT, User Profile, RBAC, Duyệt Seller |
| **CatalogService** | **8002** | `category_db` (Postgres) | **5433** | Danh mục, sản phẩm, quản lý tồn kho kho ảo của Seller |
| **CommerceService** | **8003** | `commerce_db` (Postgres) | **5434** | Giỏ hàng, đơn hàng, điều phối Checkout Saga |
| **LogService** | **8004** | `log_db` (Postgres) | **5435** | Nhật ký hệ thống tập trung (Centralized log trail) |
| **AuctionService** | **8005** | `auction_db` (Postgres) | **5436** | Phiên đấu giá, trả giá (bid), đồng hồ đếm ngược |
| **FulfillmentService** | **8006** | `fulfillment_db` (Postgres) | **5437** | Kho bãi vật lý, tính phí vận chuyển, tra cứu vận đơn |
| **NotificationService** | **8007** | `notification_db` (Postgres) | **5438** | Quản lý thông báo, cài đặt thông báo người dùng |
| **WalletService** | **8008** | `wallet_db` (Postgres) | **5439** | Ví điện tử, số dư, nạp/rút tiền, chuyển tiền nội bộ |

### Hạ Tầng Dùng Chung (Shared Platform Infrastructure)
- **RabbitMQ**: Port `5672` (AMQP), Port `15672` (Management UI tại `http://localhost:15672`, tài khoản: `guest` / `guest`).
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
- 7 Cơ sở dữ liệu PostgreSQL độc lập (ports 5432 - 5438)

---

### Cách 2: Chạy Toàn Bộ Hệ Thống Bằng Container (Full Stack)
Khi cần demo hoặc kiểm thử tích hợp toàn sàn:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose up -d
```
Lệnh này dựng trọn bộ:
- Toàn bộ Hạ tầng & Databases
- API Gateway (port 8000)
- 7 Microservices container (ports 8001 - 8007)

---

### Cách 3: Làm Việc Độc Lập Trong Từng Microservice Repository
Mỗi Microservice là một repository độc lập và sở hữu file `docker-compose.yml` riêng:
```bash
# Ví dụ khi chỉ làm việc với CatalogService:
cd src/Services/Catalog

# 1. Chỉ bật Database riêng của Catalog (category_db tại port 5433):
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

## 4. Tài Liệu Kỹ Thuật Chi Tiết
- **[Hướng Dẫn Các Bước Tiếp Theo & Checklist Triển Khai (docs/NEXT_STEPS_AND_CHECKLIST.md)](docs/NEXT_STEPS_AND_CHECKLIST.md)**
- [Tài liệu Hệ Thống & Quy Chuẩn (specs/README.md)](specs/README.md)
- [Hệ Thống 15 Quyết Định Kiến Trúc (docs/adr/ADR.md)](docs/adr/ADR.md)
- [Hướng Dẫn Phát Triển API Gateway (src/Services/ApiGateway/DEV_GUIDE.md)](src/Services/ApiGateway/DEV_GUIDE.md)
- [Hướng Dẫn Tích Hợp Backend Services (src/Services/ApiGateway/SETUP_GUIDE_SERVICES.md)](src/Services/ApiGateway/SETUP_GUIDE_SERVICES.md)
