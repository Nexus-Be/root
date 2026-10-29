# Cụm Cơ Sở Dữ Liệu Cục Bộ (Nexus Local Databases)

Thư mục này chứa cấu hình Docker Compose để khởi chạy độc lập 8 container PostgreSQL cho 8 microservices của hệ sinh thái Nexus.

## Danh sách CSDL & Cổng Host

| Service | Database Name | Container Name | Host Port | Internal Port |
| :--- | :--- | :--- | :---: | :---: |
| **UserService** | `usermanagement_db` | `nexus-user-db` | `5433` | `5432` |
| **CatalogService** | `catalog_db` | `nexus-catalog-db` | `5434` | `5432` |
| **CommerceService** | `commerce_db` | `nexus-commerce-db` | `5435` | `5432` |
| **LogService** | `log_db` | `nexus-log-db` | `5436` | `5432` |
| **AuctionService** | `auction_db` | `nexus-auction-db` | `5437` | `5432` |
| **FulfillmentService** | `fulfillment_db` | `nexus-fulfillment-db` | `5438` | `5432` |
| **NotificationService** | `notification_db` | `nexus-notification-db` | `5439` | `5432` |
| **WalletService** | `wallet_db` | `nexus-wallet-db` | `5440` | `5432` |

## Hướng dẫn sử dụng

### 1. Khởi chạy 8 CSDL
Chỉ cần di chuyển vào thư mục này và chạy:
```bash
cd infra/databases
docker compose up -d
```

### 2. Kiểm tra trạng thái sức khỏe
```bash
docker compose ps
```
Đảm bảo tất cả 8 container đều hiển thị `healthy`.

### 3. Dừng cụm CSDL
```bash
docker compose down
```
*(Dữ liệu được lưu trữ bền vững trong Docker volumes có tiền tố `nexus-be_*`)*
