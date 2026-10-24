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

### 2.2. TẦNG APPLICATION (`{Service}.Application`) — ĐIỀU PHỐI CA SỬ DỤNG

* **Bản chất**: Hiện thực hóa các Use Cases của hệ thống theo mô hình **CQRS (Command Query Responsibility Segregation)** kết hợp `MediatR`.
* **Cấu trúc thư mục**:
  ```
  {Service}.Application/
  ├── Commands/           # Các ca sử dụng làm THAY ĐỔI dữ liệu (Create, Update, Delete)
  │   └── RegisterUser/
  │       ├── RegisterUserCommand.cs
  │       ├── RegisterUserCommandHandler.cs
  │       └── RegisterUserCommandValidator.cs
  ├── Queries/            # Các ca sử dụng CHỈ ĐỌC dữ liệu (Get, List, Search)
  │   └── GetUserProfile/
  │       ├── GetUserProfileQuery.cs
  │       └── GetUserProfileQueryHandler.cs
  ├── DTOs/               # Data Transfer Objects trao đổi giữa các tầng
  ├── Interfaces/         # Hợp đồng giao tiếp (IApplicationDbContext, IEmailSender, ITokenService...)
  └── Validators/         # Quy chuẩn kiểm tra dữ liệu đầu vào (sử dụng FluentValidation)
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Tách biệt rõ ràng Command và Query**:
    - `Command`: Trả về `Result<T>` hoặc `Guid/Id` của bản ghi mới tạo. Có thể bắn Domain Event hoặc Integration Event.
    - `Query`: Luôn luôn sử dụng truy vấn `.AsNoTracking()` của EF Core để tối ưu hóa bộ nhớ và tốc độ xử lý.
  - **Khai báo Interface, không triển khai cụ thể**:
    - Ví dụ khai báo `IUserDbContext` chứa các `DbSet<User>`, `Task<int> SaveChangesAsync(...)`.
    - Việc DbContext chạy trên PostgreSQL, SQL Server hay In-Memory do tầng `Infrastructure` chịu trách nhiệm.

---

### 2.3. TẦNG INFRASTRUCTURE (`{Service}.Infrastructure`) — TRIỂN KHAI KỸ THUẬT

* **Bản chất**: Tương tác với thế giới bên ngoài (Database, Message Broker, Redis, External APIs, File Storage).
* **Cấu trúc thư mục**:
  ```
  {Service}.Infrastructure/
  ├── Persistence/        # Cấu hình Cơ sở dữ liệu Entity Framework Core 8
  │   ├── Configurations/ # Fluent API Configurations (*Configuration.cs)
  │   ├── Migrations/     # Code-first DB Migrations sinh tự động bởi EF Core
  │   └── ApplicationDbContext.cs # Triển khai interface IApplicationDbContext
  ├── Consumers/          # MassTransit Message Consumers lắng nghe sự kiện RabbitMQ
  │   └── OrderCreatedConsumer.cs
  ├── Services/           # Triển khai các dịch vụ kỹ thuật (BCryptHasher, MailKitSender, RedisCache...)
  └── ValueConverters/    # Chuyển đổi kiểu dữ liệu tùy biến cho CSDL PostgreSQL
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Áp dụng No-Repository Pattern (ADR 05)**:
    - Không viết thêm tầng `GenericRepository<T>` bọc ngoài `DbContext`. `DbContext` và `DbSet` của EF Core bản thân nó đã là Unit of Work & Repository hoàn hảo.
    - Tầng `Application` inject trực tiếp `IApplicationDbContext` để viết câu truy vấn LINQ linh hoạt.
  - **Cấu hình bảng qua Fluent API**:
    - Toàn bộ ràng buộc CSDL (Primary Key, Foreign Key, Index, MaxLength, Nullability) được định nghĩa trong thư mục `Configurations/` bằng cách triển khai `IEntityTypeConfiguration<T>`.
    - Không dùng Data Annotations bừa bãi trong Entity của Domain.
  - **Event-Driven Messaging**:
    - Nhận tin nhắn qua MassTransit Consumers kế thừa `IConsumer<TIntegrationEvent>`.
    - Đảm bảo tính Idempotent (chống xử lý lặp lại tin nhắn khi mạng chập chờn).

---

### 2.4. TẦNG API (`{Service}.Api`) — ĐẦU MỐI GIAO TIẾP GIAO THỨC

* **Bản chất**: Điểm khởi động ứng dụng (Entry Point), tiếp nhận các cuộc gọi gRPC từ API Gateway hoặc các Service khác.
* **Cấu trúc thư mục**:
  ```
  {Service}.Api/
  ├── Contracts/          # Chứa file shop.proto đồng bộ từ Gateway
  ├── Services/           # Triển khai gRPC Services kế thừa từ Base Class do Protobuf sinh ra
  │   └── UsersGrpcService.cs
  ├── Extensions/         # Extension methods nạp Dependency Injection (AddApplication, AddInfrastructure)
  ├── appsettings.json    # Cấu hình ConnectionString, RabbitMQ, Redis, Logging
  └── Program.cs          # Khởi động ứng dụng, nạp DI, Map gRPC endpoints, Health Checks
  ```
* **Quy chuẩn lập trình bắt buộc**:
  - **Cực kỳ mỏng (Thin Presentation Layer)**:
    - `UsersGrpcService` chỉ làm 3 việc:
      1. Nhận gRPC request $\rightarrow$ Map sang Application Command/Query.
      2. Gửi qua MediatR `_sender.Send(command, cancellationToken)`.
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
