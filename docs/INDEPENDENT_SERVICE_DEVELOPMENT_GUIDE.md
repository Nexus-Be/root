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

### Hiện trạng Cơ sở dữ liệu: Cloud-First (Neon PostgreSQL)
Toàn bộ database của 8 microservices (`usermanagement_db`, `category_db`, `commerce_db`, `log_db`, `auction_db`, `fulfillment_db`, `notification_db`, `wallet_db`) đã được quản lý tập trung trên **Neon Cloud PostgreSQL**.
- **Không cần chạy container PostgreSQL cục bộ**: Bạn không cần tốn RAM chạy container Postgres trên máy dev. Connection strings trong file cấu hình (`appsettings.json` hoặc `.env`) đã được cấu hình trỏ trực tiếp đến CSDL Neon Cloud tương ứng (hỗ trợ `sslmode=require`).
- **Tiết kiệm tài nguyên tối đa**: Máy dev hoàn toàn không phải chịu tải của 8 container Postgres cục bộ.

### Khi nào cần bật Docker hạ tầng?
Chỉ khi tính năng bạn đang phát triển cần:
1. **Bắn / Nhận Sự kiện bất đồng bộ qua RabbitMQ** (Integration Events, Saga Consumers).
2. **Đọc / Ghi Cache qua Redis**.
3. **Thu thập Trace qua OpenTelemetry / Grafana Tempo**.

Lúc đó, bạn chỉ cần khởi động cụm hạ tầng nhẹ dùng chung (không chứa DB, chỉ tốn ~200MB RAM):
```bash
# Từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d
```
Lệnh này khởi động:
- **RabbitMQ**: Cổng AMQP `5672`, Web UI `15672` (tài khoản `guest`, mật khẩu mặc định `guest` hoặc `${RABBITMQ_PASSWORD}`).
- **Redis**: Cổng `6379`.
- **Grafana Tempo Tracing**: Cổng nhận OTLP `4317`, Web UI Grafana `3000`.

---

## 3. BƯỚC 2: CHẠY & DEBUG SERVICE CỤC BỘ TRONG IDE

1. **Mở Solution của Service:**
   - Mở file `.sln` của service (ví dụ `src/Services/Catalog/Catalog.sln` hoặc `src/Services/User/User.sln`) bằng Visual Studio, JetBrains Rider hoặc VS Code.
2. **Kiểm tra file cấu hình môi trường (`appsettings.Development.json` hoặc `.env`):**
   - Connection String đã được cấu hình trỏ tới Neon Cloud (hoặc biến môi trường `ConnectionStrings__DefaultConnection`):
     ```json
     "ConnectionStrings": {
       "DefaultConnection": "Host=ep-xxx.ap-southeast-1.aws.neon.tech;Database=category_db;Username=...;Password=...;SSL Mode=Require;Trust Server Certificate=true"
     }
     ```
   - RabbitMQ trỏ về `localhost:5672`:
     ```json
     "RabbitMq": {
       "Host": "localhost",
       "Port": 5672,
       "User": "guest",
       "Password": "guest"
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

> ⚠️ **Lưu ý hiện trạng**: Các service đang có gRPC Server thật + Reflection bật sẵn gồm: **`UserService:8001`**, **`LogService:8004`**, **`WalletService:8008`**. (Catalog hiện đang chạy REST Mock tại cổng 8002).

#### A. Dùng Postman (Hỗ trợ Server Reflection):
1. Mở Postman $\rightarrow$ Chọn **New** $\rightarrow$ **gRPC Request**.
2. Điền URL: `http://localhost:8008` (Wallet) hoặc `http://localhost:8001` (User).
3. Tại **Service definition**, chọn **Use Server reflection**. Postman sẽ tự động nạp danh sách RPC methods mà không cần bạn phải copy file `.proto` thủ công!
4. Chọn method (ví dụ `WalletApi/GetWallet`), bấm **Use Example Message** để sinh JSON payload.
5. Soạn thảo request và bấm **Invoke** để nhận kết quả ngay.

#### B. Dùng giao diện Web UI trực quan bằng `grpcui`:
```bash
# Biến gRPC thành giao diện web tương tác như Swagger:
grpcui -plaintext localhost:8008
```

#### C. Dùng công cụ dòng lệnh `grpcurl`:
```bash
# Liệt kê các service gRPC đang mở trên cổng 8008:
grpcurl -plaintext localhost:8008 list

# Gọi một method cụ thể kèm payload:
grpcurl -plaintext -d '{"userId": "01912345-6789-7abc-def0-123456789abc"}' \
  localhost:8008 ShoppingCart.Contracts.V1.WalletApi/GetWallet
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
2. Đăng nhập: tài khoản `guest` / mật khẩu `guest` (hoặc mật khẩu cấu hình trong biến môi trường `RABBITMQ_PASSWORD`).
3. Vào tab **Exchanges**: Bạn sẽ thấy MassTransit tự động tạo Exchange mang tên Event (ví dụ: `ShoppingCart.Contracts.V1:SendOtpEmailIntegrationEvent` hoặc `Log.Domain.Events:ILogEventOccurred`).
4. Vào tab **Queues**: Bạn có thể xem số lượng tin nhắn đang chờ xử lý (`Ready`), số lượng tin nhắn đã nhận (`Unacked`).
5. Bấm vào một hàng đợi $\rightarrow$ Cuộn xuống mục **Get messages** $\rightarrow$ Bấm **Get Message(s)** để xem nội dung JSON của sự kiện vừa được bắn ra!

---

## 6. BẢNG TỔNG HỢP DANH MỤC CỔNG MẠNG CHO TỪNG SERVICE

Khi bạn làm việc trên service nào, hãy tra cứu đúng cổng của service đó:

| Service của bạn | Port Code App (`dotnet run`) | Dịch vụ Hạ Tầng Phụ Trợ | Cổng Phụ Trợ | Tên Database PostgreSQL (Neon Cloud) |
| :--- | :---: | :--- | :---: | :--- |
| **ApiGateway** | **8000** | `nexus-shared-redis` | `6379` | *(Redis Key-Value)* |
| **UserService** | **8001** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `usermanagement_db` |
| **CatalogService** | **8002** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `category_db` |
| **CommerceService** | **8003** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `commerce_db` |
| **LogService** | **8004** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `log_db` |
| **AuctionService** | **8005** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `auction_db` |
| **FulfillmentService** | **8006** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `fulfillment_db` |
| **NotificationService** | **8007** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `notification_db` |
| **WalletService** | **8008** | Neon Cloud PostgreSQL | Cổng Cloud (`5432`) | `wallet_db` |

*Ghi chú hạ tầng dùng chung*:
- **RabbitMQ**: AMQP `5672`, Management UI `15672`.
- **Redis**: Port `6379`.
- **Grafana Tempo**: OTLP gRPC `4317`, Grafana Explore `3000`.

---

## 7. XỬ LÝ CÁC SỰ CỐ THƯỜNG GẶP KHI CODE ĐỘC LẬP (TROUBLESHOOTING)

1. **Lỗi kết nối CSDL (Npgsql.PostgresException / Connection Timeout):**
   - *Nguyên nhân:* Mạng internet bị gián đoạn hoặc chuỗi kết nối Neon Cloud thiếu cấu hình SSL mode.
   - *Khắc phục:* Kiểm tra kết nối mạng và đảm bảo chuỗi kết nối chứa `SSL Mode=Require;Trust Server Certificate=true`.
2. **Lỗi Gateway báo `503 SERVICE_UNAVAILABLE` hoặc `DOWNSTREAM_UNHEALTHY`:**
   - *Nguyên nhân:* Bạn đang để service ở mode `"Real"` trong `gateway.runtime.json`, nhưng chưa chạy ứng dụng Backend trên port tương ứng (ví dụ chưa chạy `localhost:8001`).
   - *Khắc phục:* Khởi động project backend của bạn trong IDE hoặc đổi tạm service đó thành `"Mock"` trong `gateway.runtime.json`.
3. **Lỗi sửa Protobuf nhưng code không nhận method mới:**
   - *Khắc phục:* Chạy lệnh `dotnet build` trên project API để công cụ Grpc.Tools tự động biên dịch lại C# stub class từ file `shop.proto`.
4. **Lỗi xung đột cổng mạng (Port already in use):**
   - *Khắc phục:* Kiểm tra xem có tiến trình nào đang chiếm cổng (ví dụ trên Linux/Mac: `lsof -i :8001` hoặc trên Windows: `netstat -ano | findstr 8001`), sau đó kết thúc tiến trình cũ trước khi chạy lại.
