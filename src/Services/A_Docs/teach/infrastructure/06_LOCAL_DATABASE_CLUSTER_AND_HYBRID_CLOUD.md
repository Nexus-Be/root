# Chuyen De 06: Cum Co So Du Lieu Cuc Bo & Hybrid Cloud (Local Database Cluster Architecture)

Chuyen de nay huong dan chi tiet ve kien truc cum 8 co so du lieu PostgreSQL cuc bo (`src/Infrastructure/databases/`), quy hoach phan bo cong mang 5433 - 5440, nguyen tac kiem tra suc khoe `pg_isready`, va chien luoc ket hop Hybrid Cloud voi Neon PostgreSQL.

---

## 1. Chien Luoc Ha Tang CSDL Hybrid Cloud

He sinh thai Nexus ap dung mo hinh kien truc CSDL lai (Hybrid Database Strategy):

```text
                               ┌────────────────────────────────────────┐
                               │ NEON CLOUD SERVERLESS POSTGRESQL       │
                               │ - Môi trường Staging, UAT, Production  │
                               │ - Tính năng Branching theo Git branch  │
                               │ - Tự động Scale-to-Zero khi không dùng │
                               └───────────────────▲────────────────────┘
                                                   │
  Cấu hình chuỗi kết nối tự động                   │ (Chuyển đổi qua biến môi trường)
  thông qua NormalizeConnectionString              │
                                                   │
                               ┌───────────────────▼────────────────────┐
                               │ LOCAL DOCKER POSTGRESQL CLUSTER        │
                               │ - Môi trường phát triển Offline        │
                               │ - Cụm 8 container độc lập (5433-5440)  │
                               │ - Dữ liệu cô lập tuyệt đối per-service │
                               └────────────────────────────────────────┘
```

---

## 2. Bang Phan Bo Cong Va Ten CSDL Cuc Bo (Ports & Databases Catalog)

Trong file `src/Infrastructure/databases/docker-compose.yml`, he thong khai bao dung 8 container PostgreSQL 16 Alpine:

| STT | Vi Dich Vu So Huu | Port Host | Port Container | Ten Co So Du Lieu (Database) | Ten Volume Du Lieu |
|:---:|:---|:---:|:---:|:---|:---|
| 1 | **UserService** | `5433` | `5432` | `usermanagement_db` | `postgres_user_data` |
| 2 | **CatalogService** | `5434` | `5432` | `category_db` | `postgres_catalog_data` |
| 3 | **CommerceService** | `5435` | `5432` | `commerce_db` | `postgres_commerce_data` |
| 4 | **LogService** | `5436` | `5432` | `log_db` | `postgres_log_data` |
| 5 | **AuctionService** | `5437` | `5432` | `auction_db` | `postgres_auction_data` |
| 6 | **FulfillmentService**| `5438` | `5432` | `fulfillment_db` | `postgres_fulfillment_data`|
| 7 | **NotificationService**| `5439` | `5432` | `notification_db` | `postgres_notification_data`|
| 8 | **WalletService** | `5440` | `5432` | `wallet_db` | `postgres_wallet_data` |

*Luu y: Dich vu CheckHealService (Port 8009) khong co co so du lieu vi quan ly trang thai hoan toan in-memory.*

---

## 3. Co Che Kiem Tra Suc Khoe CSDL (`pg_isready`)

Moi container CSDL deu duoc gan hook healthcheck su dung tien ich san co `pg_isready` cua PostgreSQL:

```yaml
# src/Infrastructure/databases/docker-compose.yml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres} -d usermanagement_db"]
  interval: 10s
  timeout: 5s
  retries: 5
```

### Y nghia van hanh:
- Dam bao container chi duoc danh dau la `healthy` khi tien trinh PostgreSQL server da thuc su khoi dong xong va san sang tiep nhan truy van SQL tren database do.
- Ngan ngua loi ket noi `ConnectionRefused` khi cac ung dung .NET khoi chay song song voi Docker.

---

## 4. Co Lap Du Lieu Tuyet Doi (Database-per-Service Isolation)

Cac container duoc thiet lap voi cac Named Volumes rieng biet (`postgres_user_data`, `postgres_catalog_data`...).

### Nguyen tac bat bien:
1. **Khong dung chung Volume:** Moi CSDL ghi du lieu vao mot thu muc o dia vat ly hoan toan doc lap tren may host.
2. **Khong dung chung Process:** Moi CSDL chay tren mot tien trinh PostgreSQL rieng biet. Su co treo hoac qua tai o CSDL `commerce_db` khong bao gio anh huong den CSDL `usermanagement_db` hay `wallet_db`.
3. **Tuong thich hoan hao voi Clean Architecture:** Cau truc nay cu the hoa nguyen tac kien truc cap he thong: **Tuyet doi cam truy van cheo CSDL giua cac vi dich vu**.
