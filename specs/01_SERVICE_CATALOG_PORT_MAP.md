# 01 — BẢN ĐỒ DỊCH VỤ, CỔNG MẠNG & HẠ TẦNG (SERVICE CATALOG & PORT MAP)

Tài liệu này quy chuẩn toàn bộ bản đồ cổng mạng (Ports), cơ sở dữ liệu và biến môi trường kết nối cho toàn bộ 8 Microservices và ApiGateway.

---

## 1. BẢNG QUY HOẠCH CỔNG GIAO TIẾP & CƠ SỞ DỮ LIỆU

| Service Name | Cổng HTTP REST | Cổng gRPC | Database Engine | Cổng DB | DB Name | Cổng Redis / RabbitMQ |
|:---|:---:|:---:|:---:|:---:|:---|:---:|
| **ApiGateway** | `8000` | N/A *(Client)* | Redis *(Cache/RateLimit)* | `6379` | `db0` | Redis: `6379` |
| **UserService** | N/A | `8001` | PostgreSQL | `5433` | `usermanagement_db` | RabbitMQ: `5672` |
| **CatalogService** | N/A | `8002` | PostgreSQL | `5434` | `category_db` | RabbitMQ: `5672` |
| **CommerceService** | N/A | `8003` | PostgreSQL | `5435` | `commerce_db` | RabbitMQ: `5672` |
| **LogService** | N/A | `8004` | PostgreSQL | `5436` | `log_db` | RabbitMQ: `5672` |
| **AuctionService** | N/A | `8005` | PostgreSQL | `5437` | `auction_db` | RabbitMQ: `5672` |
| **FulfillmentService** | N/A | `8006` | PostgreSQL | `5438` | `fulfillment_db` | RabbitMQ: `5672` |
| **NotificationService** | N/A | `8007` | PostgreSQL | `5439` | `notification_db` | RabbitMQ: `5672` |
| **WalletService** | N/A | `8008` | PostgreSQL | `5440` | `wallet_db` | RabbitMQ: `5672` |

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
- **Tích hợp**: Mọi gRPC call và Gateway request đều được gán `traceId` chuẩn W3C TraceContext và chuyển tiếp qua header `x-trace-id`.

---

## 3. NGUYÊN TẮC QUY ĐỊNH CỔNG CHO AI AGENTS

- **Tuyệt đối KHÔNG thay đổi dải port** từ `8000` đến `8008` trong code hay cấu hình.
- Khi tạo mới một service backend hoặc thêm endpoint, địa chỉ gRPC upstream trong `appsettings.json` của Gateway phải ánh xạ đúng port của service đó (ví dụ Catalog $\rightarrow$ `http://localhost:8002`).
