# QUY CHUẨN KIẾN TRÚC CLEAN ARCHITECTURE 4 TẦNG CHO CÁC MICROSERVICES
## (CLEAN ARCHITECTURE IMPLEMENTATION GUIDE ACROSS ALL SERVICES)

> **Mục tiêu tài liệu**: Định nghĩa cấu trúc thư mục, quy tắc phân tầng, trách nhiệm của từng project và tiêu chuẩn viết mã đồng nhất cho toàn bộ **8 Microservices backend** trong hệ sinh thái Nexus (`UserService`, `CatalogService`, `CommerceService`, `LogService`, `AuctionService`, `FulfillmentService`, `NotificationService`, `WalletService`).

---

## 1. NGUYÊN TẮC LUỒNG PHỤ THUỘC (THE DEPENDENCY RULE)

Mỗi Microservice được cấu trúc thành một Solution `.sln` độc lập bao gồm **4 projects tương ứng với 4 tầng kiến trúc**:

```
                       ┌─────────────────────────┐
                       │        *.Domain         │ ◄── Lõi nghiệp vụ (Trung tâm)
                       └────────────▲────────────┘
                                    │ Phụ thuộc vào Domain
                       ┌────────────┴────────────┐
                       │      *.Application      │ ◄── Ca sử dụng nghiệp vụ (CQRS)
                       └──────▲───────────▲──────┘
         Phụ thuộc vào App    │           │    Phụ thuộc vào App
     ┌────────────────────────┴───┐   ┌───┴────────────────────────┐
     │     *.Infrastructure       │   │           *.Api            │
     │ (EF Core, RabbitMQ, Redis) │   │ (gRPC Server, DI, Program) │
     └────────────────────────────┘   └────────────────────────────┘
```

### Quy tắc bất biến:
1. **Mã nguồn ở tầng trong KHÔNG BAO GIỜ được biết về tầng ngoài**:
   - `Domain` không phụ thuộc vào bất kỳ project nào.
   - `Application` chỉ phụ thuộc vào `Domain`.
   - `Infrastructure` và `Api` phụ thuộc vào `Application` và `Domain`.
2. **Không gọi chéo trực tiếp giữa Infrastructure và Api**: Mọi giao tiếp đều thông qua các Interface được khai báo tại tầng `Application`.

---

## 2. CHI TIẾT TỪNG TẦNG: PHẦN NÀO LÀM CÁI NÀO?

### 2.1. TẦNG DOMAIN (`{Service}.Domain`) — LÕI NGHIỆP VỤ BẤT BIẾN

* **Bản chất**: Trái tim của microservice, chứa mô hình dữ liệu doanh nghiệp và các quy tắc nghiệp vụ cốt lõi.
* **Cấu trúc thư mục**:
  ```
  {Service}.Domain/
  ├── Base/               # Lớp cơ sở: Entity, AggregateRoot, ValueObject, DomainEvent
  ├── Entities/           # Các thực thể nghiệp vụ (User, Product, Order, Wallet...)
  ├── Enums/              # Các kiểu liệt kê trạng thái (UserStatus, OrderStatus...)
  └── Exceptions/         # Domain Exceptions (DomainValidationException, InsufficientBalanceException...)
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **100% C# thuần (POCO)**: Tuyệt đối **CẤM** import Entity Framework Core, ASP.NET Core, MassTransit, hoặc bất kỳ thư viện UI/DB nào vào tầng Domain.
  - **Encapsulation (Bảo vệ tính toàn vẹn)**: Toàn bộ thuộc tính phải dùng `private set;` hoặc `protected set;`. Không dùng `public get; set;` tự do.
  - **Phương thức nghiệp vụ bên trong Entity**: Mọi hành vi thay đổi trạng thái phải thông qua method của Entity (ví dụ: `order.CancelOrder()`, `wallet.DeductBalance(amount)`).
  - **Không dùng primitive Obsession**: Các trường số tiền bắt buộc dùng `decimal` chính xác, mã định danh dùng `Guid` hoặc chuỗi chuẩn hóa.

---

### 2.2. TẦNG APPLICATION (`{Service}.Application`) — ĐIỀU PHỐI CA SỬ DỤNG (USE CASES)

* **Bản chất**: Hiện thực hóa các Use Cases của hệ thống. Khử ghép nối lỏng (Loose Coupling), phân tách theo từng miền tính năng (Feature-based Services).
* **Cấu trúc thư mục**:
  ```
  {Service}.Application/
  ├── Interfaces/                                    # Interfaces của CSDL và các dịch vụ hạ tầng ngoài
  │   ├── I{Service}DbContext.cs                     # Abstraction của DbContext
  │   └── I{External}Service.cs                      # Abstraction dịch vụ hạ tầng (Email, Cache, Storage...)
  │
  ├── Common/                                        # Các thành phần dùng chung trong Application
  │   ├── Exceptions/                                # NotFoundException, ValidationException...
  │   └── Models/                                    # Result<T>, PaginatedList<T>...
  │
  ├── Services/                                      # CÁC DỊCH VỤ XỬ LÝ USE CASE (MODULE HÓA THEO FEATURE)
  │   ├── {FeatureA}/                                # Ví dụ: Cart/ hoặc Auth/ hoặc Product/
  │   │   ├── I{FeatureA}Service.cs                  # Interface ca sử dụng của feature đó
  │   │   ├── {FeatureA}Service.cs                   # Class hiện thực use case (kế thừa interface trên)
  │   │   └── {FeatureA}Dtos.cs                      # DTOs riêng biệt phục vụ cho feature này
  │   └── {FeatureB}/                                # Ví dụ: Order/ hoặc User/ hoặc Category/
  │       ├── I{FeatureB}Service.cs
  │       ├── {FeatureB}Service.cs
  │       └── {FeatureB}Dtos.cs
  │
  └── DependencyInjection.cs                         # Đăng ký AddApplicationServices()
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Đóng gói trọn vẹn theo Feature**: Mỗi feature service (như `CartService`, `OrderService`, `AuthService`) sở hữu trọn vẹn Interface, Implementation và DTOs tương ứng bên trong cùng thư mục `Services/{Feature}/`.
  - **Khai báo Interface, không phụ thuộc cụ thể**: Tầng Application chỉ phụ thuộc vào `I{Service}DbContext` và abstraction `I{External}Service`, hoàn toàn không biết chi tiết hạ tầng (PostgreSQL, Redis, MailKit, AWS SES...).
  - **Truy vấn đọc tối ưu**: Luôn luôn sử dụng truy vấn `.AsNoTracking()` của EF Core khi đọc dữ liệu để đạt hiệu năng tối đa.

---

### 2.3. TẦNG INFRASTRUCTURE (`{Service}.Infrastructure`) — TRIỂN KHAI KỸ THUẬT

* **Bản chất**: Tương tác với thế giới bên ngoài (Database, Message Broker, Redis, External APIs, File Storage).
* **Cấu trúc thư mục**:
  ```
  {Service}.Infrastructure/
  ├── Persistence/                                   # Quản lý CSDL PostgreSQL & EF Core 8
  │   ├── AppDbContext.cs                            # Triển khai I{Service}DbContext
  │   ├── Configurations/                            # Fluent API Configurations (*Configuration.cs)
  │   ├── Migrations/                                # Code-first DB Migrations sinh bởi EF Core
  │   └── Seeds/                                     # Dữ liệu hạt giống (Seed Data)
  │
  ├── Services/                                      # CÁC DỊCH VỤ HẠ TẦNG KỸ THUẬT (THEO MODULE RIÊNG)
  │   ├── Email/                                     # Module gửi Email (nếu service có dùng)
  │   │   ├── IEmailService.cs                       # Interface nội bộ tầng infra
  │   │   ├── SmtpOptions.cs                         # Options cấu hình đọc từ appsettings
  │   │   └── MailKitEmailSenderService.cs           # Triển khai cụ thể dùng MailKit
  │   ├── Redis/                                     # Module Cache / OTP (nếu service có dùng)
  │   │   ├── RedisOptions.cs                        # Options cấu hình
  │   │   └── RedisOtpService.cs                     # Triển khai thao tác Redis
  │   └── ...                                        # Sau này đổi sang SendGrid/SES chỉ sửa folder này
  │
  ├── Consumers/                                     # MassTransit Message Consumers lắng nghe RabbitMQ
  │   └── OrderCreatedConsumer.cs
  ├── Common/                                        # Tiện ích dùng chung trong Infrastructure
  └── DependencyInjection.cs                         # Đăng ký AddInfrastructureServices(configuration)
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Áp dụng No-Repository Pattern (ADR 05)**:
    - Không viết thêm tầng `GenericRepository<T>` bọc ngoài `DbContext`. `DbContext` và `DbSet` của EF Core bản thân nó đã là Unit of Work & Repository hoàn hảo.
    - Tầng `Application` inject trực tiếp `I{Service}DbContext` để viết câu truy vấn LINQ linh hoạt.
  - **Đóng gói dịch vụ hạ tầng theo Folder riêng**: Mỗi module hạ tầng (như `Email/`, `Redis/`) có riêng Interface, Options và Class triển khai.
  - **Cấu hình bảng qua Fluent API**:
    - Toàn bộ ràng buộc CSDL (Primary Key, Foreign Key, Index, MaxLength, Nullability) được định nghĩa trong thư mục `Configurations/` bằng cách triển khai `IEntityTypeConfiguration<T>`.
    - Không dùng Data Annotations bừa bãi trong Entity của Domain.

---

### 2.4. TẦNG API (`{Service}.Api`) — ĐẦU MỐI GIAO TIẾP & MIDDLEWARE TOÀN CỤC

* **Bản chất**: Điểm khởi động ứng dụng (Entry Point), tiếp nhận các cuộc gọi gRPC từ API Gateway hoặc các Service khác, trang bị Middleware toàn cục.
* **Cấu trúc thư mục**:
  ```
  {Service}.Api/
  ├── Middleware/                                    # MIDDLEWARE TOÀN CỤC CỦA SERVICE
  │   └── GlobalExceptionHandlerMiddleware.cs        # Bắt mọi lỗi ngoại lệ, format RFC 9110 ProblemDetails
  ├── Services/                                      # Triển khai gRPC Services kế thừa từ Base Class do Protobuf sinh ra
  │   └── UsersGrpcService.cs
  ├── Contracts/                                     # Chứa file shop.proto đồng bộ từ Gateway
  ├── appsettings.json                               # Cấu hình ConnectionString, RabbitMQ, Redis, Logging
  └── Program.cs                                     # Khởi động ứng dụng, nạp DI, app.UseGlobalExceptionHandler()
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Global Exception Middleware**: Mỗi service bắt buộc phải có `GlobalExceptionHandlerMiddleware` tại tầng Api để bắt mọi ngoại lệ未 xử lý, ghi log chi tiết kèm `TraceId` và trả về JSON chuẩn RFC 9110 ProblemDetails cho client.
  - **Cực kỳ mỏng (Thin Presentation Layer)**:
    - `*GrpcService` chỉ làm nhiệm vụ:
      1. Nhận gRPC request $\rightarrow$ Map sang Application DTO.
      2. Gọi Application Service xử lý nghiệp vụ.
      3. Nhận kết quả $\rightarrow$ Map sang gRPC Protobuf Response và trả về.
    - Tuyệt đối **không viết logic nghiệp vụ hay truy vấn SQL trong gRPC Service**.
  - **Bảo mật danh tính qua gRPC Metadata**:
    - Trích xuất thông tin người dùng được Gateway chuyển tiếp qua HTTP/2 Headers: `x-user-id`, `x-user-roles`, `x-user-email`.

---

## 3. QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG (MANDATORY ERROR RULES)

Mọi Exception, Validation Error và Response Error trong toàn bộ các Microservices **BẮT BUỘC** tuân thủ 3 nguyên tắc sau:

1. **Ngôn ngữ (100% English)**:
   - Toàn bộ thông báo lỗi trả về cho client phải viết bằng tiếng Anh chuẩn. Tuyệt đối không dùng tiếng Việt trong chuỗi thông báo lỗi.
2. **Quy cách viết hoa (Sentence case)**:
   - Viết hoa duy nhất chữ cái đầu câu, các từ tiếp theo viết thường (ngoại trừ tên riêng hoặc từ viết tắt kỹ thuật như `ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`...).
   - ✅ Đúng: `"Email is already registered in the system."`
   - ✅ Đúng: `"OTP code has expired or does not exist."`
   - ✅ Đúng: `"Username, valid email, and password with at least 8 characters are required."`
   - ❌ Sai: `"Lỗi mã OTP không hợp lệ"` (Không dùng tiếng Việt)
   - ❌ Sai: `"invalid email address"` (Chữ cái đầu không viết hoa)
   - ❌ Sai: `"INVALID EMAIL ADDRESS"` (Cấm viết hoa toàn bộ)
   - ❌ Sai: `"Invalid Email Address Provided"` (Không dùng Title Case)
3. **Mã lỗi (Error Codes — SCREAMING_SNAKE_CASE)**:
   - Mã lỗi luôn viết hoa toàn bộ và nối bằng dấu gạch dưới:
   - Ví dụ: `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `OTP_INVALID`, `OTP_ALREADY_USED`, `USER_NOT_FOUND`, `VAL_INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`.

---

## 4. MA TRẬN PHÂN CHIA TRÁCH NHIỆM GIỮA 4 TẦNG

| Thành phần kỹ thuật | Đặt tại tầng nào? | Lý do kỹ thuật |
| :--- | :---: | :--- |
| **Entity / Aggregate Root** | `*.Domain` | Chứa dữ liệu và quy tắc nghiệp vụ bất biến của thực thể. |
| **Domain Event** | `*.Domain` | Đại diện cho sự kiện nghiệp vụ nội bộ vừa xảy ra trong Domain. |
| **Command & Query** | `*.Application` | Đại diện cho Use Case nghiệp vụ cụ thể. |
| **FluentValidation Rules** | `*.Application` | Kiểm tra tính hợp lệ của dữ liệu đầu vào cho Use Case. |
| **Interface DbContext / Services** | `*.Application` | Trừu tượng hóa việc lưu trữ và dịch vụ bên thứ ba để đảo ngược phụ thuộc (DIP). |
| **EF Core DbContext & Configurations** | `*.Infrastructure` | Triển khai chi tiết cách ánh xạ Entity xuống PostgreSQL. |
| **MassTransit Consumer** | `*.Infrastructure` | Nhận sự kiện từ RabbitMQ và ủy thác cho Application Command xử lý. |
| **gRPC Server Implementation** | `*.Api` | Tiếp nhận RPC call từ Gateway và chuyển tiếp vào MediatR. |
| **Program.cs & Cấu hình Kestrel** | `*.Api` | Khởi động container và thiết lập cổng mạng HTTP/2. |
