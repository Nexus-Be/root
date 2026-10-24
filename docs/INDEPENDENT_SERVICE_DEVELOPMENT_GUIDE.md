# CẨM NANG PHÁT TRIỂN & KIỂM THỬ ĐỘC LẬP TỪNG MICROSERVICE
## (ISOLATED LOCAL DEVELOPMENT GUIDE FOR DEVELOPERS)

> **Mục tiêu tài liệu**: Hướng dẫn một lập trình viên khi chỉ phụ trách **1 service duy nhất** (ví dụ `CatalogService`, `UserService` hay `CommerceService`) có thể tự khởi động, viết mã nguồn và kiểm thử toàn diện service của mình trên máy tính cá nhân **mà KHÔNG CẦN bật toàn bộ 9 services**, tiết kiệm tối đa tài nguyên RAM/CPU (chỉ cần < 2GB RAM).

---

## 1. NGUYÊN TẮC LÀM VIỆC ĐỘC LẬP (ISOLATED DEVELOPMENT PARADIGM)

Hệ sinh thái Nexus bao gồm **9 services độc lập**:
- **1 API Gateway** (`Nexus.Gateway` tại cổng `8000`)
- **8 Microservices backend** (`UserService:8001`, `CatalogService:8002`, `CommerceService:8003`, `LogService:8004`, `AuctionService:8005`, `FulfillmentService:8006`, `NotificationService:8007`, `WalletService:8008`)

### ❌ Sai lầm phổ biến:
Chạy `docker compose up -d` để dựng toàn bộ cả 9 services containers cùng lúc.  
*Hậu quả:* Máy ngốn 8 - 12GB RAM, quạt quay tối đa, khởi động chậm, khó đặt breakpoint debug trong IDE, và khi gặp lỗi không biết do service nào gây ra.

### ✅ Giải pháp chuẩn mực của Nexus:
1. **Bạn chỉ cần bật Cơ sở dữ liệu và Hạ tầng liên quan của riêng service bạn.**
2. **Chạy Service của bạn trực tiếp trong IDE (Visual Studio / Rider / VS Code) với chế độ Debug (`F5`).**
3. **Chạy API Gateway ở chế độ Dual-Runtime**:
   - Service bạn đang code được đặt là **`"Real"`** $\rightarrow$ Gateway gọi gRPC trực tiếp sang code của bạn.
   - Toàn bộ 7 services còn lại được đặt là **`"Mock"`** $\rightarrow$ Gateway tự trả JSON mẫu giả lập, không cần bất kỳ container nào của 7 service kia chạy thật!

---

## 2. BƯỚC 1: KHỞI ĐỘNG HẠ TẦNG TỐI THIỂU CẦN THIẾT

Tùy theo nhu cầu công việc, bạn chọn 1 trong 2 cách sau:

### Cách A: Siêu Nhẹ (Chỉ bật đúng Database của Service — Khuyên Dùng khi code CRUD/Logic)
Mỗi thư mục service đều có sẵn file `docker-compose.yml` cục bộ.

Ví dụ: Bạn đang code **`CatalogService`**:
```bash
# 1. Đi vào thư mục của service:
cd src/Services/Catalog

# 2. Chỉ khởi động đúng container database của Catalog (category_db tại port 5434):
docker compose up -d catalog-db
```

Ví dụ: Bạn đang code **`UserService`**:
```bash
cd src/Services/User
docker compose up -d user-db
```

*Lợi ích:* Chỉ tốn khoảng ~80MB RAM cho một container PostgreSQL nhỏ gọn!

---

### Cách B: Hạ Tầng Dùng Chung Đầy Đủ (Khi cần test cả RabbitMQ & Redis Cache)
Khi tính năng của bạn có bắn Sự kiện (Integration Event qua RabbitMQ) hoặc đọc/ghi Redis Cache:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d
```
Lệnh này khởi động toàn bộ:
- RabbitMQ (`5672`, Web UI `15672`)
- Redis (`6379`)
- Grafana Tempo Tracing (`4317`, `3000`)
- 8 Databases PostgreSQL (`5433` - `5440`)

---

## 3. BƯỚC 2: CHẠY & DEBUG SERVICE CỤC BỘ TRONG IDE

1. **Mở Solution của Service:**
   - Mở file `.sln` của service (ví dụ `src/Services/Catalog/Catalog.sln` hoặc `src/Services/User/User.sln`) bằng Visual Studio, JetBrains Rider hoặc VS Code.
2. **Kiểm tra file cấu hình môi trường (`appsettings.Development.json`):**
   - Đảm bảo Connection String trỏ đúng vào cổng DB máy host (ví dụ `Catalog` dùng port `5434`):
     ```json
     "ConnectionStrings": {
       "DefaultConnection": "Host=localhost;Port=5434;Database=category_db;Username=postgres;Password=MatkhaucuaTui123@"
     }
     ```
   - RabbitMQ trỏ về `localhost:5672`:
     ```json
     "RabbitMq": {
       "Host": "localhost",
       "Port": 5672,
       "User": "guest",
       "Password": "MatkhaucuaTui123@"
     }
     ```
3. **Áp dụng Database Migration (nếu có):**
   ```bash
   dotnet ef database update --project Catalog.Infrastructure --startup-project Catalog.Api
   ```
4. **Chạy ứng dụng:**
   - Bấm nút **Debug (F5)** trong IDE hoặc gõ lệnh:
     ```bash
     dotnet run --project Catalog.Api
     ```
   - Service của bạn sẽ khởi động trên cổng mạng quy hoạch (ví dụ Catalog: `http://localhost:8002`).

---

## 4. BƯỚC 3: PHỐI HỢP VỚI API GATEWAY ĐỂ KIỂM THỬ ĐẦU-CUỐI (END-TO-END)

Để Frontend gọi vào hoặc bạn kiểm thử luồng từ Gateway xuống Backend của mình:

### 1. Cấu hình file `gateway.runtime.json` tại API Gateway:
Mở file `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`:
- Đặt service của bạn là **`"Real"`**.
- Tất cả các service khác giữ nguyên là **`"Mock"`**.

*Ví dụ khi bạn đang code `catalog`:*
```json
{
  "Gateway": {
    "AuthMode": "Bypass", 
    "Services": {
      "catalog": {
        "Mode": "Real",
        "Address": "http://localhost:8002",
        "TimeoutSeconds": 5
      },
      "users": {
        "Mode": "Mock"
      },
      "commerce": {
        "Mode": "Mock"
      },
      "wallet": {
        "Mode": "Mock"
      }
    }
  }
}
```

> 💡 **Mẹo Bypass Auth**: Đặt `"AuthMode": "Bypass"` giúp bạn gọi mọi API yêu cầu đăng nhập (`[Authorize]`) trên Swagger của Gateway mà không cần mất công tạo token đăng nhập thật!

### 2. Khởi chạy API Gateway:
Mở một cửa sổ Terminal riêng và chạy Gateway:
```bash
cd src/Services/ApiGateway/Nexus.Gateway
dotnet run
```
Gateway sẽ lắng nghe tại cổng `http://localhost:8000`.

---

## 5. BỐN PHƯƠNG PHÁP KIỂM THỬ DÀNH CHO DEVELOPER (TESTING TOOLKIT)

### Phương Pháp 1: Kiểm thử qua RESTful Swagger UI của Gateway (Trực quan nhất)
1. Mở trình duyệt vào: `http://localhost:8000/swagger`.
2. Tìm đến nhóm API của service bạn (ví dụ `/api/v1/catalog/...`).
3. Bấm **Try it out** $\rightarrow$ Điền Request Body / Query Params $\rightarrow$ Bấm **Execute**.
4. **Điều gì sẽ diễn ra?**
   - Gateway nhận request HTTP REST.
   - Nhận diện `catalog` đang ở chế độ `Real` $\rightarrow$ Tự động chuyển đổi thành gRPC call và gọi tới `http://localhost:8002`.
   - IDE của bạn sẽ dừng lại tại các Breakpoint bạn đã đặt trong Service để debug từng dòng mã!
   - Kết quả trả về cho Swagger được đóng gói trong vỏ chuẩn `ApiResponse<T>` với mã HTTP 200, 201 hoặc ProblemDetails 400, 404...

---

### Phương Pháp 2: Kiểm thử trực tiếp gRPC Service (Không cần qua Gateway)
Khi bạn muốn test nhanh phương thức gRPC mà không cần bật Gateway:

#### A. Dùng Postman (Hỗ trợ gRPC Native từ phiên bản v9+):
1. Mở Postman $\rightarrow$ Chọn **New** $\rightarrow$ **gRPC Request**.
2. Điền URL: `http://localhost:8002` (hoặc cổng service của bạn).
3. Chọn file hợp đồng: Nhập file `src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto`.
4. Postman sẽ tự động liệt kê các RPC methods (ví dụ `GetProductById`, `ListProducts`...).
5. Soạn thảo JSON request và bấm **Invoke** để nhận kết quả ngay.

#### B. Dùng công cụ dòng lệnh `grpcurl`:
```bash
# Liệt kê các service gRPC đang mở:
grpcurl -plaintext localhost:8002 list

# Gọi một method cụ thể kèm payload:
grpcurl -plaintext -d '{"id": "prod-001"}' localhost:8002 ShoppingCart.Contracts.V1.CatalogApi/GetProduct
```

---

### Phương Pháp 3: Chạy Bộ Kiểm Thử Tự Động (Unit & Integration Tests)
Mỗi service đều có thư mục test riêng biệt (ví dụ `User.Tests/`):
```bash
# Chạy toàn bộ test của service:
dotnet test src/Services/User/User.Tests/User.Tests.csproj

# Chạy test với thông báo chi tiết:
dotnet test src/Services/User/User.Tests/User.Tests.csproj --logger "console;verbosity=detailed"
```
*Nguyên tắc:* Các bài Unit Test sử dụng Fake/Mock cho DbContext và Bus, giúp kiểm tra logic nghiệp vụ chỉ trong vài mili-giây mà không cần bất kỳ kết nối mạng hay container nào.

---

### Phương Pháp 4: Kiểm thử Sự Kiện Bất Đồng Bộ Qua RabbitMQ Management
Khi service của bạn bắn sự kiện (Publish Event):
1. Mở trình duyệt vào: `http://localhost:15672`.
2. Đăng nhập: tài khoản `guest` / mật khẩu `MatkhaucuaTui123@`.
3. Vào tab **Exchanges**: Bạn sẽ thấy MassTransit tự động tạo Exchange mang tên Event (ví dụ: `ShoppingCart.Contracts.V1:SendOtpEmailIntegrationEvent`).
4. Vào tab **Queues**: Bạn có thể xem số lượng tin nhắn đang chờ xử lý (`Ready`), số lượng tin nhắn đã nhận (`Unacked`).
5. Bấm vào một hàng đợi $\rightarrow$ Cuộn xuống mục **Get messages** $\rightarrow$ Bấm **Get Message(s)** để xem nội dung JSON của sự kiện vừa được bắn ra!

---

## 6. BẢNG TỔNG HỢP DANH MỤC CỔNG MẠNG CHO TỪNG SERVICE

Khi bạn làm việc trên service nào, hãy tra cứu đúng cổng của service đó:

| Service của bạn | Port Code App (`dotnet run`) | Container Database | Port DB Host | Tên Database Postgres |
| :--- | :---: | :--- | :---: | :--- |
| **ApiGateway** | **8000** | `nexus-shared-redis` | `6379` | *(Redis Key-Value)* |
| **UserService** | **8001** | `nexus-user-db` | `5433` | `usermanagement_db` |
| **CatalogService** | **8002** | `nexus-catalog-db` | `5434` | `category_db` |
| **CommerceService** | **8003** | `nexus-commerce-db` | `5435` | `commerce_db` |
| **LogService** | **8004** | `nexus-log-db` | `5436` | `log_db` |
| **AuctionService** | **8005** | `nexus-auction-db` | `5437` | `auction_db` |
| **FulfillmentService** | **8006** | `nexus-fulfillment-db` | `5438` | `fulfillment_db` |
| **NotificationService** | **8007** | `nexus-notification-db` | `5439` | `notification_db` |
| **WalletService** | **8008** | `nexus-wallet-db` | `5440` | `wallet_db` |

---

## 7. XỬ LÝ CÁC SỰ CỐ THƯỜNG GẶP KHI CODE ĐỘC LẬP (TROUBLESHOOTING)

1. **Lỗi `Connection refused (localhost:543x)` khi chạy service:**
   - *Nguyên nhân:* Container database của service chưa được bật.
   - *Khắc phục:* Chạy `docker ps` xem container có đang chạy không. Nếu chưa, gõ `docker compose up -d <tên-db>`.
2. **Lỗi Gateway báo `503 SERVICE_UNAVAILABLE` hoặc `DOWNSTREAM_UNHEALTHY`:**
   - *Nguyên nhân:* Bạn đang để service ở mode `"Real"` trong `gateway.runtime.json`, nhưng chưa chạy ứng dụng Backend trên port tương ứng (ví dụ chưa chạy `localhost:8001`).
   - *Khắc phục:* Khởi động project backend của bạn trong IDE hoặc đổi tạm service đó thành `"Mock"` trong `gateway.runtime.json`.
3. **Lỗi sửa Protobuf nhưng code không nhận method mới:**
   - *Khắc phục:* Chạy lệnh `dotnet build` trên project API để công cụ Grpc.Tools tự động biên dịch lại C# stub class từ file `shop.proto`.
4. **Lỗi xung đột cổng mạng (Port already in use):**
   - *Khắc phục:* Kiểm tra xem có tiến trình nào đang chiếm cổng (ví dụ trên Linux/Mac: `lsof -i :8001` hoặc trên Windows: `netstat -ano | findstr 8001`), sau đó kết thúc tiến trình cũ trước khi chạy lại.
