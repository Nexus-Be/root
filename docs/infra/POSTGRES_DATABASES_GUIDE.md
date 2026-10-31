# HƯỚNG DẪN 8 CƠ SỞ DỮ LIỆU POSTGRESQL & QUẢN LÝ EF CORE MIGRATIONS
## (POSTGRESQL DATABASE CATALOG, DBEAVER SETUP & EF CORE MIGRATION GUIDE)

> **Trạng thái triển khai (2026-10-31):** ✅ Đã chuyển sang Neon Cloud. Mỗi service dùng một database Neon riêng và migration `Initial*` đã apply thành công trên cả 8 database.
> **Nguồn sự thật:** `src/Services/*/*.Infrastructure/Persistence/Migrations/*.cs`, file `.env` và `appsettings.Development.json` của từng repo.
> **Cập nhật lần cuối:** 2026-10-31.

> **Mục tiêu tài liệu**: Cung cấp danh mục chi tiết 8 Cơ sở dữ liệu PostgreSQL độc lập theo nguyên tắc **Database-Per-Service (ADR 03)**, hướng dẫn kết nối qua công cụ đồ họa (DBeaver, pgAdmin), và quy trình chuẩn quản lý Code-First Database Migrations bằng Entity Framework Core 8.

---

## 1. NGUYÊN TẮC BẤT BIẾN: DATABASE-PER-SERVICE (ADR 03)

Trong hệ sinh thái Nexus Microservices:
* **Mỗi Microservice sở hữu 1 Cơ sở dữ liệu PostgreSQL hoàn toàn độc lập.**
* **TUYỆT ĐỐI KHÔNG TRUY CẬP CHÉO CƠ SỞ DỮ LIỆU**: `UserService` không bao giờ được kết nối vào CSDL của `CatalogService`, và ngược lại.
* **Không dùng Khóa Ngoại (Foreign Key) liên database**: Mọi liên kết giữa các miền nghiệp vụ được thực hiện thông qua mã định danh chuẩn `Guid` (ví dụ: `Order` lưu `UserId` dạng UUID, nhưng không tạo Foreign Key trỏ sang bảng `Users`). Khi cần lấy thông tin chi tiết, service gọi qua typed REST client.

---

## 2. BẢN ĐỒ 8 DATABASE NEON

Mỗi service trỏ tới một database riêng trên Neon Cloud. Tên database trùng với tên miền nghiệp vụ. Connection string đầy đủ nằm trong `.env` của từng repo và không commit.

| STT | Service | Database | Neon Host | Biến môi trường |
|:---:| :--- | :--- | :--- | :--- |
| **1** | **UserService** | **`user`** | `ep-fancy-poetry-a1frv94q-pooler.ap-southeast-1.aws.neon.tech` | `USER_DB_CONNECTION` |
| **2** | **CatalogService** | **`catalog`** | `ep-snowy-lake-a1b8fywo-pooler.ap-southeast-1.aws.neon.tech` | `CATALOG_DB_CONNECTION` |
| **3** | **CommerceService** | **`commerce`** | `ep-fancy-poetry-a1frv94q-pooler.ap-southeast-1.aws.neon.tech` | `COMMERCE_DB_CONNECTION` |
| **4** | **LogService** | **`log`** | `ep-summer-shape-b3m9hy77-pooler.c-4.ap-southeast-1.aws.neon.tech` | `LOG_DB_CONNECTION` |
| **5** | **AuctionService** | **`auction`** | `ep-summer-shape-b3m9hy77-pooler.c-4.ap-southeast-1.aws.neon.tech` | `AUCTION_DB_CONNECTION` |
| **6** | **FulfillmentService** | **`fulfillment`** | `ep-quiet-credit-azf5li7q-pooler.c-3.ap-southeast-1.aws.neon.tech` | `FULFILLMENT_DB_CONNECTION` |
| **7** | **NotificationService**| **`notification`** | `ep-snowy-lake-a1b8fywo-pooler.ap-southeast-1.aws.neon.tech` | `NOTIFICATION_DB_CONNECTION` |
| **8** | **WalletService** | **`wallet`** | `ep-quiet-credit-azf5li7q-pooler.c-3.ap-southeast-1.aws.neon.tech` | `WALLET_DB_CONNECTION` |

### Thông tin kết nối:
* **Định dạng**: URI `postgresql://<USERNAME>:<PASSWORD>@<HOST>/<DATABASE>?sslmode=require&channel_binding=require`.
* **SSL**: bắt buộc. `NormalizeConnectionString` tự thêm `SSL Mode=Require` khi nhận URI.
* **Nguồn giá trị thật**: file `.env` của từng repo, đã nằm trong `.gitignore`.
* **Dự phòng offline**: cụm PostgreSQL local trong `src/Infrastructure/databases/docker-compose.yml`, host port `5433` đến `5440`, user `postgres`, password `postgres`.

---

## 3. HƯỚNG DẪN KẾT NỐI QUA GIAO DIỆN ĐỒ HỌA (DBEAVER / PGADMIN)

Khuyên dùng công cụ miễn phí **DBeaver** (hoặc pgAdmin, DataGrip):

### Các bước tạo kết nối mới trên DBeaver:
1. Mở DBeaver $\rightarrow$ Bấm nút **New Database Connection** (biểu tượng phích cắm điện với dấu `+`).
2. Chọn loại CSDL: **PostgreSQL** $\rightarrow$ Bấm **Next**.
3. Dán connection string Neon (lấy từ `.env` của service tương ứng) vào ô **URL**, DBeaver tự tách host, port, database, user và password.
4. Bấm nút **Test Connection**:
   - Nếu DBeaver yêu cầu tải PostgreSQL JDBC Driver, bấm **Download** (tự động 100%).
   - Khi hiện thông báo `Connected` màu xanh lá $\rightarrow$ Bấm **Finish**.
5. Bây giờ bạn có thể duyệt xem các bảng, xem dữ liệu, và thực thi câu lệnh SQL trực quan!

---

## 4. HƯỚNG DẪN QUẢN LÝ CODE-FIRST DATABASE MIGRATIONS (EF CORE)

Hệ thống sử dụng **Entity Framework Core 8 Code-First**. Khi bạn thêm hoặc sửa Entity trong tầng Domain, hãy dùng các lệnh sau để cập nhật CSDL:

### 4.1. Chuẩn bị công cụ EF Core CLI
Nếu máy bạn chưa có công cụ `dotnet-ef`, cài đặt 1 lần duy nhất:
```bash
dotnet tool install --global dotnet-ef
```

---

### 4.2. Tạo một Bản Migration Mới (Add Migration)
Khi bạn vừa thêm bảng mới hoặc sửa trường dữ liệu trong Entity:
```bash
# Ví dụ đối với UserService:
dotnet ef migrations add <TenMigration> \
  --project src/Services/User/User.Infrastructure \
  --startup-project src/Services/User/User.Api

# Ví dụ đối với CatalogService:
dotnet ef migrations add AddProductCategoriesTable \
  --project src/Services/Catalog/Catalog.Infrastructure \
  --startup-project src/Services/Catalog/Catalog.Api
```
EF Core sẽ tạo một file C# mới trong thư mục `Persistence/Migrations/` của tầng Infrastructure.

---

### 4.3. Cập nhật Thay Đổi Vào CSDL PostgreSQL (Update Database)
Đảm bảo database Neon tương ứng đang bật và `.env` của service đã có connection string, sau đó gõ:
```bash
# Áp dụng migration cho UserService:
dotnet ef database update \
  --project src/Services/User/User.Infrastructure \
  --startup-project src/Services/User/User.Api

# Áp dụng migration cho CatalogService:
dotnet ef database update \
  --project src/Services/Catalog/Catalog.Infrastructure \
  --startup-project src/Services/Catalog/Catalog.Api
```

---

### 4.4. Các lệnh hữu ích khác:
* **Hủy bỏ migration vừa tạo (khi chưa update database):**
  ```bash
  dotnet ef migrations remove --project src/Services/User/User.Infrastructure --startup-project src/Services/User/User.Api
  ```
* **Xuất mã SQL Script để bàn giao cho DevOps / DBA:**
  ```bash
  dotnet ef migrations script --project src/Services/User/User.Infrastructure --startup-project src/Services/User/User.Api -o migration.sql
  ```

---

## 5. CÁC TIÊU CHUẨN THIẾT KẾ CƠ SỞ DỮ LIỆU TRONG NEXUS

Mọi bảng và cột trong CSDL PostgreSQL của Nexus phải tuân thủ các chuẩn sau:

1. **Quy chuẩn đặt tên (Naming Convention)**:
   - Sử dụng chữ thường phân cách bởi dấu gạch dưới (`snake_case`) cho tên bảng và tên cột (cấu hình tự động qua `UseSnakeCaseNamingConvention()` của Npgsql EF Core).
   - Ví dụ: Bảng `users`, cột `display_name`, `created_at`, `phone_number`.
2. **Khóa chính (Primary Key)**:
   - 100% các bảng sử dụng kiểu dữ liệu **UUID v4 (`uuid`)** làm khóa chính, không sử dụng số nguyên tự tăng (`serial / identity`) nhằm tránh lộ số lượng bản ghi và hỗ trợ sinh khóa an toàn từ client.
3. **Các trường dấu vết chuẩn (Auditing Fields)**:
   - Mọi bảng quan trọng đều phải có các cột:
     - `created_at`: Kiểu `timestamp with time zone` (UTC).
     - `updated_at`: Kiểu `timestamp with time zone` (UTC), nullable.
     - `is_deleted`: Kiểu `boolean`, mặc định `false` (hỗ trợ Soft Delete khi cần).
4. **Độ chính xác tiền tệ (Money Precision)**:
   - Các trường liên quan đến số tiền (Giá sản phẩm, Số dư ví, Phí vận chuyển) **tuyệt đối không dùng `float` hay `double`**.
   - Bắt buộc dùng kiểu: **`numeric(18, 2)`** trong PostgreSQL tương ứng với kiểu `decimal` trong C#.
5. **Lưu trữ trạng thái Enum**:
   - Trong CSDL lưu dạng **số nguyên `integer`** để tối ưu hóa dung lượng đĩa và tốc độ đánh chỉ mục (Index). Khi trả ra REST API cho Frontend, Gateway tự động chuyển đổi thành chuỗi `PascalCase`.
