# HƯỚNG DẪN CÁC BƯỚC TIẾP THEO & BỘ CHECKLIST TRIỂN KHAI MICROSERVICES
## (NEXT STEPS & IMPLEMENTATION CHECKLIST)

> **Quy chuẩn kiến trúc chiến lược (ADR 06 & Nguyên tắc 4)**: Toàn bộ hệ thống giao tiếp đồng bộ đã chuẩn hóa **100% RESTful HTTP/JSON** (CẤM TUYỆT ĐỐI gRPC). Mỗi microservice backend expose endpoint REST tại dải cổng `8001`-`8008`, và giao tiếp bất đồng bộ duy trì 100% Event-driven qua RabbitMQ.

Tài liệu này đóng vai trò là **Kim Chỉ Nam Hành Động** cho giai đoạn tiếp theo của dự án sau khi **Nexus API Gateway** đã hoàn thành toàn diện. Tài liệu giải đáp chi tiết:
1. *API Gateway đã xong chưa? Còn cần làm gì thêm nữa không?*
2. *Các bước tiếp theo cần triển khai những gì? Thứ tự ưu tiên ra sao?*
3. *Quy trình và Checklist kỹ thuật chuẩn cho từng Microservice.*

---

## 1. ĐÁNH GIÁ TRẠNG THÁI HIỆN TẠI: API GATEWAY ĐÃ XONG CHƯA?

### 👉 CÂU TRẢ LỜI: API GATEWAY ĐÃ HOÀN TẤT 100% PHẦN CỐT LÕI (FEATURE-COMPLETE)

Gateway hiện tại đã đạt độ hoàn thiện cao, vượt qua toàn bộ **105/105 bài kiểm thử tự động**, sẵn sàng làm điểm tiếp nhận duy nhất cho toàn bộ hệ thống:

| Thành phần Gateway | Trạng thái | Chi tiết đã hoàn thành |
| :--- | :---: | :--- |
| **10 Controllers RESTful** | ✅ Hoàn thành | Chuẩn hóa toàn bộ URL `/api/v1/{service}/*`, validate DTOs tập trung. |
| **Dispatching Core 3 Tầng** | ✅ Hoàn thành | `ModeEvaluator`, `MockDataMapper`, `GrpcServiceCaller`, `GatewayDispatcher`. |
| **gRPC Client Typed** | ✅ Hoàn thành | Đã tạo đủ 8 gRPC Clients strongly-typed dựa trên `shop.proto` v3. |
| **Mock Engine & Seed Data** | ✅ Hoàn thành | Tự động đọc dữ liệu giả lập từ `Seeds/` để test Frontend độc lập. |
| **Hot-Reload Runtime Modes** | ✅ Hoàn thành | Hỗ trợ đổi `Mock` ➔ `Real` tức thì qua file `gateway.runtime.json` hoặc Admin API. |
| **Xác thực & Phân quyền** | ✅ Hoàn thành | JWT Bearer, RBAC 5 vai trò (`buyer`, `seller`, `staff`, `admin`, `gateway-admin`). |
| **User Identity Propagation** | ✅ Hoàn thành | Tự động trích xuất và gắn `x-user-id`, `x-user-roles`, `x-user-email` sang gRPC Metadata. |
| **Distributed Rate Limiting** | ✅ Hoàn thành | Giới hạn theo User ID / IP phân tán qua Redis với cơ chế Fail-Open ở Dev. |
| **Distributed Tracing** | ✅ Hoàn thành | Chuẩn W3C `traceparent` & `x-trace-id`, kết nối OTLP tự động tới Grafana Tempo. |
| **RFC Problem Details** | ✅ Hoàn thành | Exception Handler trung tâm trả lỗi chuẩn RFC 9110 / RFC 6585. |

### ❓ Gateway có cần làm thêm gì nữa không?
* **Ở GIAI ĐOẠN HIỆN TẠI (Development & Feature Building):** **KHÔNG CẦN LÀM THÊM GÌ Ở GATEWAY NỮA.** Bạn không cần chỉnh sửa code Gateway trừ khi có thêm API endpoint mới từ nghiệp vụ.
* **Ở GIAI ĐOẠN PRODUCTION (Sau khi đã xong hết Microservices):** Chỉ cần bổ sung các tính năng hạ tầng nâng cao (chưa cần làm ngay bây giờ):
  - *Reverse Proxy SSL Termination:* Đặt Nginx / Cloudflare ở vành đai ngoài để giải mã HTTPS.
  - *Circuit Breaker / Retry Policy (Polly):* Tự động ngắt mạch nếu một service con bị sập liên tục.
  - *Output Caching (Redis):* Cache các API đọc công khai ít thay đổi (như danh mục sản phẩm).

---

## 2. THỰC TRẠNG CÁC SERVICE CON & NHIỆM VỤ TIẾP THEO

Toàn bộ 8 Microservices backend (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`) hiện tại:
- **Đã có:** Cấu trúc 4 tầng Clean Architecture, file Solution (`.sln`), `Dockerfile`, `docker-compose.yml` cục bộ, `.env.example`, và bộ tài liệu đặc tả (`specs/`).
- **Chưa có:** Mã nguồn nghiệp vụ thực sự (file `Program.cs` hiện mới là template rỗng).

👉 **NHIỆM VỤ TIẾP THEO CỦA BẠN:** Tiến hành triển khai logic nghiệp vụ thật cho **từng Microservice một**, sau đó bật chế độ `Real` tại Gateway để kết nối và kiểm thử tích hợp.

---

## 3. LỘ TRÌNH TRIỂN KHAI THEO THỨ TỰ ƯU TIÊN (IMPLEMENTATION ROADMAP)

Tuyệt đối **không nên làm song song cả 7 service cùng lúc**. Hãy triển khai tuần tự theo đúng 4 giai đoạn dựa trên luồng phụ thuộc dữ liệu:

```
[GIAI ĐOẠN 1: NỀN TẢNG ĐỊNH DANH & DỮ LIỆU SẢN PHẨM]
  ├── 1. UserService       (Port 8001 | usermanagement_db:5433)  <── BẮT BUỘC ĐẦU TIÊN
  └── 2. CatalogService    (Port 8002 | category_db:5434)        <── BẮT BUỘC THỨ HAI
           │
           ▼
[GIAI ĐOẠN 2: NGHIỆP VỤ MUA BÁN & GIAO DỊCH CỐT LÕI]
  ├── 3. CommerceService   (Port 8003 | commerce_db:5435)        <── Giỏ hàng, Đơn hàng, Saga
  └── 4. WalletService     (Port 8008 | wallet_db:5440)          <── Ví tiền, Trừ tiền checkout
           │
           ▼
[GIAI ĐOẠN 3: GIAO VẬN VÀ ĐẤU GIÁ]
  ├── 5. FulfillmentService(Port 8006 | fulfillment_db:5438)     <── Kho vật lý, Vận đơn
  └── 6. AuctionService    (Port 8005 | auction_db:5437)         <── Phòng đấu giá, Bidding
           │
           ▼
[GIAI ĐOẠN 4: HỆ THỐNG PHỤ TRỢ & SỰ KIỆN TOÀN SÀN]
  ├── 7. NotificationService(Port 8007 | notification_db:5439)   <── Lắng nghe Event, gửi thông báo
  └── 8. LogService         (Port 8004 | log_db:5436)            <── Lắng nghe Event, lưu System Log Trail
```

### Chi Tiết Lý Do Phải Theo Thứ Tự Này:
1. **Làm UserService đầu tiên:** Vì mọi hành động trong hệ thống đều cần biết *"Ai đang gọi?"*. UserService cấp phát Token JWT thật và quản lý quyền RBAC. Khi có User thật, Gateway sẽ không cần chạy token giả lập nữa.
2. **Làm CatalogService thứ hai:** Vì muốn mua hàng, đấu giá hay giao vận thì hệ thống bắt buộc phải có Sản phẩm (Product) và Danh mục (Category).
3. **Làm CommerceService & WalletService thứ ba:** Khi đã có User và Product, bạn ghép nối nghiệp vụ tạo Giỏ hàng, Đặt đơn hàng và trừ tiền ví qua **Checkout Saga (MassTransit RabbitMQ)**.
4. **Làm Fulfillment & Auction thứ tư:** Xử lý vận đơn sau khi đơn đã thanh toán thành công, và mở phòng đấu giá sản phẩm.
5. **Làm Notification & Log sau cùng:** Hai service này là **Event Consumers** thuần túy, đóng vai trò lắng nghe các sự kiện do các service trên bắn ra qua RabbitMQ để gửi email và ghi vết nhật ký hệ thống.

---

## 4. CHECKLIST KỸ THUẬT CHUẨN ĐỂ CODE MỘT MICROSERVICE
*(Áp dụng công thức này đồng nhất cho cả 7 service — Mỗi service làm đúng theo 7 bước)*

Khi bắt tay vào code bất kỳ service nào (Ví dụ: `UserService`), hãy làm theo checklist:

- [ ] **Bước 1: Đồng bộ Contract Protobuf**
  - Copy file `src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto` vào thư mục `Contracts/` của service đó.
  - Cấu hình file `*.Api.csproj`:
    ```xml
    <Protobuf Include="Contracts/shop.proto" GrpcServices="Server" />
    ```

- [ ] **Bước 2: Triển khai Domain Layer (`*.Domain`)**
  - Tạo các Entity và Value Objects theo đặc tả trong `specs/04_DATA_PERSISTENCE.md` của service.
  - Đóng gói Business Invariants (Quy tắc bất biến) vào các method của Entity (ví dụ: không cho phép trừ tồn kho âm).
  - Tuyệt đối không import thư viện ngoài hay framework vào tầng Domain.

- [ ] **Bước 3: Triển khai Persistence Layer (`*.Infrastructure`)**
  - Cài đặt package `Npgsql.EntityFrameworkCore.PostgreSQL`.
  - Tạo class `ApplicationDbContext` kế thừa `DbContext`.
  - **Quy tắc ADR 05:** Không viết Repository Pattern bọc ngoài. Khai báo trực tiếp `DbSet<T>`.
  - Tạo Migration ban đầu:
    ```bash
    dotnet ef migrations add InitialCreate --project *.Infrastructure --startup-project *.Api
    ```

- [ ] **Bước 4: Triển khai Application Layer (`*.Application`)**
  - Viết Commands / Queries / Use cases xử lý logic nghiệp vụ.
  - Sử dụng `FluentValidation` để kiểm tra dữ liệu đầu vào.
  - Nếu có lỗi nghiệp vụ: Ném exception map sang mã lỗi RFC 9110 hoặc gRPC Status tương ứng.

- [ ] **Bước 5: Triển khai RESTful Controllers / Minimal APIs (`*.Api`) — CẤM gRPC**
  - Tạo Controller kế thừa `ControllerBase` hoặc Minimal API map endpoint `/api/v1/{resource}`.
  - Lấy thông tin user trực tiếp từ HTTP Headers:
    ```csharp
    var userId = Request.Headers["x-user-id"].FirstOrDefault();
    var roles = Request.Headers["x-user-roles"].FirstOrDefault();
    var email = Request.Headers["x-user-email"].FirstOrDefault();
    ```
  - Trả về bọc trong vỏ chuẩn `ApiResponse<T>`, `ApiResponse<PagedData<T>>` hoặc `204 NoContent`.
  - Đăng ký controllers và Swagger trong `Program.cs`:
    ```csharp
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    // ...
    app.MapControllers();
    ```

- [ ] **Bước 6: Tích Hợp OpenTelemetry Tracing (1 dòng duy nhất)**
  - Thêm file `ObservabilityExtensions.cs` (theo mẫu trong `SETUP_GUIDE_SERVICES.md`).
  - Gọi trong `Program.cs`:
    ```csharp
    builder.Services.AddServiceObservability(builder.Configuration, "Tên_Service");
    ```

- [ ] **Bước 7: Tích Hợp RabbitMQ & MassTransit 8.3.0 (Nếu có bắn hoặc nhận Event)**
  - Cấu hình `AddMassTransit` kèm **Transactional Outbox Pattern** với EF Core PostgreSQL để chống thất thoát event khi lưu DB.

---

## 5. QUY TRÌNH KIỂM THỬ TÍCH HỢP TỪNG BƯỚC VỚI API GATEWAY

Mỗi khi bạn hoàn thành xong một Microservice (Ví dụ: `UserService`):

### Bước 1: Khởi động Hạ tầng & DB của service
Mở terminal tại thư mục gốc:
```bash
# Bật RabbitMQ, Redis, Tempo, Grafana và Database của service:
docker compose -f docker-compose.infra.yml up -d
```

### Bước 2: Chạy Service con
Mở terminal tại service đó:
```bash
cd src/Services/User
dotnet run --project User.Api
# Service sẽ khởi động và lắng nghe RESTful API tại port 8001
```

### Bước 3: Chuyển Gateway sang chế độ Real cho Service đó
Mở file `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`, sửa:
```json
"users": {
  "Mode": "Real",
  "Address": "http://localhost:8001"
}
```
*(Nhờ cơ chế Hot-Reload, Gateway tự động chuyển sang gọi HTTP REST thật mà không cần khởi động lại! Các service khác vẫn giữ "Mode": "Mock")*.

### Bước 4: Kiểm thử End-to-End trên Swagger
1. Truy cập Swagger Gateway: `http://localhost:8080/swagger`.
2. Gọi API `POST /api/v1/auth/register` để tạo tài khoản thật.
3. Gọi API `POST /api/v1/auth/login` để lấy Token thật.
4. Mở DB PostgreSQL kiểm tra xem dữ liệu đã được lưu chuẩn xác vào bảng chưa.

### Bước 5: Kiểm tra Distributed Tracing trên Grafana
1. Truy cập Grafana: `http://localhost:3000/explore`.
2. Dán mã `X-Trace-Id` từ response của Gateway vào ô tìm kiếm.
3. Quan sát cây vết (Flame Graph):
   - Nhìn thấy request từ Client vào Gateway.
   - Nhìn thấy Gateway điều phối HTTP REST sang UserService.
   - Nhìn thấy thời gian câu lệnh SQL thực thi trong PostgreSQL và event bắn vào RabbitMQ.

---

## 6. BẢNG CHECKLIST TỔNG HỢP TIẾN ĐỘ TOÀN SÀN

| Service | Database Port | REST Port | Domain Entities | EF Core DbContext | REST API Impl | RabbitMQ Events | Tracing | Gateway Test |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **ApiGateway** | 6379 | 8080 | N/A | N/A | ✅ Done | N/A | ✅ Done | ✅ 404/404 Passed |
| **UserService** | 5433 | 8001 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **CatalogService** | 5434 | 8002 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **CommerceService** | 5435 | 8003 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **WalletService** | 5440 | 8008 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **FulfillmentService** | 5438 | 8006 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **AuctionService** | 5437 | 8005 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **NotificationService** | 5439 | 8007 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| **LogService** | 5436 | 8004 | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |