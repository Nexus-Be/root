# Nexus Local Databases Infrastructure

Thư mục quản lý cụm 8 cơ sở dữ liệu PostgreSQL cục bộ độc lập cho 8 Microservices của Nexus.

## Danh sách CSDL & Cổng Host

| Service | Container Name | Database Name | Host Port | Internal Port |
| :--- | :--- | :--- | :--- | :--- |
| **User** | `nexus-postgres-user` | `usermanagement_db` | `5433` | `5432` |
| **Catalog** | `nexus-postgres-catalog` | `category_db` | `5434` | `5432` |
| **Commerce** | `nexus-postgres-commerce` | `commerce_db` | `5435` | `5432` |
| **Log** | `nexus-postgres-log` | `log_db` | `5436` | `5432` |
| **Auction** | `nexus-postgres-auction` | `auction_db` | `5437` | `5432` |
| **Fulfillment** | `nexus-postgres-fulfillment` | `fulfillment_db` | `5438` | `5432` |
| **Notification** | `nexus-postgres-notification` | `notification_db` | `5439` | `5432` |
| **Wallet** | `nexus-postgres-wallet` | `wallet_db` | `5440` | `5432` |

## Lệnh Khởi Chạy

### 1. Khởi chạy toàn bộ 8 CSDL
```bash
docker compose -f src/Infrastructure/databases/docker-compose.yml up -d
```

### 2. Khởi chạy riêng 1 CSDL cho 1 Service (ví dụ User)
```bash
docker compose -f src/Infrastructure/databases/docker-compose.yml up -d postgres-user
```

### 3. Dừng cụm CSDL
```bash
docker compose -f src/Infrastructure/databases/docker-compose.yml down
```

### 4. Dừng và xóa toàn bộ dữ liệu volumes
```bash
docker compose -f src/Infrastructure/databases/docker-compose.yml down -v
```

## Chuỗi kết nối mặc định (Localhost)
- Username: `postgres`
- Password: `postgres`
- Định dạng: `Host=localhost;Port=<PORT>;Database=<DB_NAME>;Username=postgres;Password=postgres`
