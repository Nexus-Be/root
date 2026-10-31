# QUY CHUẨN KIẾN TRÚC CLEAN ARCHITECTURE 4 TẦNG CHO CÁC MICROSERVICES
## (CLEAN ARCHITECTURE IMPLEMENTATION GUIDE ACROSS ALL SERVICES)

> **Mục tiêu tài liệu**: Định nghĩa cấu trúc thư mục, quy tắc phân tầng, trách nhiệm của từng project và tiêu chuẩn viết mã đồng nhất cho **8 Microservices backend** trong hệ sinh thái Nexus (`UserService`, `CatalogService`, `CommerceService`, `LogService`, `AuctionService`, `FulfillmentService`, `NotificationService`, `WalletService`). `CheckHealService` dùng cùng layout 4 tầng nhưng là dịch vụ giám sát, không nằm trong phạm vi nghiệp vụ của tài liệu này; `ApiGateway` là YARP reverse proxy, không có Domain/Application/Infrastructure theo mô hình dưới đây.
>
> **Trạng thái triển khai (2026-10-31):** ✅ 4 tầng Clean Architecture, No-Repository pattern. Dịch vụ nghiệp vụ dùng Feature Service; riêng Wallet dùng MediatR/CQRS. gRPC, Message Broker, Saga và Outbox đã bị gỡ bỏ.
> **Nguồn sự thật:** cấu trúc project và `*.csproj` trong từng `src/Services/{Service}/`.
> **Cập nhật lần cuối:** 2026-10-31.

---

## 1. NGUYÊN TẮC LUỒNG PHỤ THUỘC (THE DEPENDENCY RULE)

Mỗi Microservice được cấu trúc thành một Solution `.sln` độc lập bao gồm **4 projects tương ứng với 4 tầng kiến trúc**:

```
                       ┌─────────────────────────┐
                       │        *.Domain         │ ◄── Lõi nghiệp vụ (Trung tâm)
                       └────────────▲────────────┘
                                    │ ProjectReference
                       ┌────────────┴────────────┐
                       │      *.Application      │ ◄── Ca sử dụng nghiệp vụ (Feature Services; Wallet dùng CQRS)
                       └──────▲───────────▲──────┘
         ProjectReference     │           │    ProjectReference
     ┌────────────────────────┴───┐   ┌───┴────────────────────────┐
     │     *.Infrastructure       │   │           *.Api            │
     │ (EF Core, Redis, REST clients) │ │ (Controllers, Middleware, DI) │
     └────────────────────────────┘   └────────────────────────────┘
```

### Quy tắc bất biến

1. **Domain là tầng trong cùng**:
   - `{Service}.Domain.csproj` không có `ProjectReference` và không tham chiếu EF Core, ASP.NET Core, Redis hay bất kỳ thư viện hạ tầng nào.
   - Domain chỉ chứa entity, enum, base type và domain exception.
2. **Application chỉ tham chiếu project Domain**:
   - Ở mức project reference, `Application` không tham chiếu `Infrastructure` hay `Api`.
   - `Application` có thể package-reference EF Core (`Microsoft.EntityFrameworkCore`) để dùng `DbSet<T>`, `IQueryable<T>`, `AsNoTracking()`; đây là phụ thuộc thư viện, không phải phụ thuộc tầng.
3. **Infrastructure tham chiếu Application và Domain**:
   - Triển khai `I{Service}DbContext`, typed REST client, Redis, JWT, background worker.
   - Không chứa controller hay logic trình bày HTTP.
4. **Api tham chiếu Application và Infrastructure**:
   - `Program.cs` là composition root duy nhất được gọi `AddApplicationServices()` và `AddInfrastructureServices(...)`.
   - Controller chỉ inject feature service (hoặc `ISender` với Wallet), không inject `DbContext` hay typed client trực tiếp.
5. **Không có lời gọi nghiệp vụ trực tiếp giữa Infrastructure và Api**:
   - Api không gọi class Infrastructure để xử lý nghiệp vụ; mọi thứ đi qua interface ở Application.
   - Ngoại lệ duy nhất là đăng ký DI trong `Program.cs`.

---

## 2. CHI TIẾT TỪNG TẦNG: PHẦN NÀO LÀM CÁI NÀO?

### 2.1. TẦNG DOMAIN (`{Service}.Domain`) — LÕI NGHIỆP VỤ BẤT BIẾN

* **Bản chất**: Trái tim của microservice, chứa mô hình dữ liệu doanh nghiệp và các quy tắc nghiệp vụ cốt lõi.
* **Cấu trúc thư mục thực tế**:
  ```
  {Service}.Domain/
  ├── Base/               # BaseEntity<TKey>, IAuditable, ISoftDelete
  ├── Entities/           # Thực thể nghiệp vụ (User, Product, Order, Wallet...)
  ├── Enums/              # Kiểu liệt kê trạng thái (UserStatus, OrderStatus...)
  └── Exceptions/         # DomainException; một số service có thêm exception chuyên biệt
  ```
* **Nội dung Base/ hiện tại**:
  - `BaseEntity<TKey>` chứa `Id`, `CreatedAt`, `UpdatedAt`, `IsDeleted`, `DeletedAt`.
  - `IAuditable` và `ISoftDelete` là interface đánh dấu.
  - Không có `AggregateRoot`, `ValueObject` hay `DomainEvent` trong code hiện tại.
* **Nội dung Exceptions/ hiện tại**:
  - `DomainException` là gốc, mang `ErrorCode` và `StatusCode`.
  - `EntityNotFoundException` và `BusinessRuleValidationException` kế thừa `DomainException` ở các service đang dùng (ví dụ User).
  - Không có `DomainValidationException` dùng chung toàn hệ thống.
* **Quy chuẩn lập trình**:
  - **100% C# thuần (POCO)**: Tuyệt đối **CẤM** import Entity Framework Core, ASP.NET Core, message broker hoặc thư viện DB vào Domain.
  - **Thuộc tính entity**: Code hiện tại dùng `public get; set;` để EF Core materialize và seed dữ liệu; **không** áp dụng `private set;` trên toàn bộ entity. Nếu muốn chuyển sang đóng gói chặt, phải refactor đồng bộ entity + cấu hình EF + seed + test, không làm nửa vời.
  - **Hành vi nghiệp vụ**: Có thể đặt method trên entity cho quy tắc nội tại (ví dụ `wallet.DeductBalance(amount)`), nhưng phần lớn use case hiện nằm trong feature service ở Application.
  - **Kiểu dữ liệu**: Tiền tệ dùng `decimal` với precision cấu hình ở Infrastructure; định danh dùng `Guid`; không dùng `double` cho tiền.

---

### 2.2. TẦNG APPLICATION (`{Service}.Application`) — ĐIỀU PHỐI CA SỬ DỤNG (USE CASES)

* **Bản chất**: Hiện thực hóa use case, phân tách theo miền tính năng (Feature Co-location). Wallet là ngoại lệ dùng MediatR/CQRS.
* **Cấu trúc thư mục thực tế**:
  ```
  {Service}.Application/
  ├── Common/
  │   ├── Exceptions/                                # Exception dùng chung của Application (nếu có)
  │   └── Models/
  │       └── PagedData.cs                           # PagedData<T> + PaginationMetadata
  │
  ├── Interfaces/
  │   ├── I{Service}DbContext.cs                     # Abstraction của DbContext
  │   └── I{External}Client.cs                       # Abstraction typed REST client liên service
  │
  ├── Services/
  │   └── {Feature}/
  │       ├── I{Feature}Service.cs                   # Contract của use case
  │       ├── {Feature}Service.cs                    # Implementation, inject I{Service}DbContext
  │       ├── {Feature}Requests.cs                   # Request records
  │       ├── {Feature}Responses.cs                  # Response records
  │       └── {Feature}Dtos.cs                       # DTO nội bộ (tùy chọn)
  │
  └── DependencyInjection.cs                         # AddApplicationServices()
  ```
* **Ngoại lệ WalletService**:
  - Use case nằm tại `Wallet.Application/Features/{Area}/Commands|Queries/{UseCase}/`, gồm `{UseCase}Command.cs` hoặc `{UseCase}Query.cs`, `{UseCase}Handler.cs` và response record.
  - Không có `Wallet.Application/Services/{Feature}/`, không có `IWalletService` facade.
  - Controller Wallet inject `ISender`, không inject feature service.
* **Quy chuẩn lập trình**:
  - **Đóng gói theo feature**: Interface, implementation, request, response và DTO của một feature nằm cùng `Services/{Feature}/`.
  - **Phụ thuộc abstraction**: Application chỉ biết `I{Service}DbContext` và `I{External}Client`; không biết PostgreSQL, Redis, MailKit hay HTTP cụ thể.
  - **Validation hiện tại**: Với các service dùng Feature Service, validation nghiệp vụ viết tay trong service (kiểm tra chuỗi, độ dài, trạng thái, quyền sở hữu); request record không gắn DataAnnotations nghiệp vụ và hệ thống **không dùng FluentValidation**. Wallet là ngoại lệ: Command/Query dùng DataAnnotations và đi qua `ValidationBehavior<,>`. Lỗi model binding/JSON được `ApiValidationProblemFactory` chuyển thành `VAL_INVALID_INPUT`.
  - **Truy vấn đọc**: Dùng `.AsNoTracking()` cho truy vấn chỉ đọc khi phù hợp; không bắt buộc cho mọi câu query.
  - **Phân trang**: Tính tại database bằng `.Skip((page - 1) * pageSize).Take(pageSize)` và `.CountAsync()`, trả `PagedData<T>`.

---

### 2.3. TẦNG INFRASTRUCTURE (`{Service}.Infrastructure`) — TRIỂN KHAI KỸ THUẬT

* **Bản chất**: Tương tác với thế giới bên ngoài: PostgreSQL, Redis, typed REST client, JWT, background worker. Không còn message broker.
* **Cấu trúc thư mục thực tế** (ví dụ User):
  ```
  {Service}.Infrastructure/
  ├── Persistence/
  │   ├── AppDbContext.cs                            # Triển khai I{Service}DbContext
  │   ├── Configurations/                            # IEntityTypeConfiguration<T>
  │   ├── Migrations/                                # EF Core migrations
  │   └── Seeds/                                     # Seed data dùng GUID cố định
  │
  ├── BackgroundWorkers/                             # Worker nền (ví dụ OtpEmailDispatchWorker)
  │
  ├── Services/
  │   ├── Common/                                    # InternalServiceAuthHandler (chưa đăng ký)
  │   ├── Jwt/                                       # JwtTokenGenerator
  │   ├── Notification/                              # EmailNotificationClient, OTP queue
  │   └── Redis/                                     # RedisOtpService, RedisOptions
  │
  └── DependencyInjection.cs                         # AddInfrastructureServices(configuration)
  ```
* **Quy chuẩn lập trình**:
  - **No-Repository Pattern**:
    - Không tạo `IRepository<T>`, `GenericRepository<T>` hay `UnitOfWork`.
    - Application inject trực tiếp `I{Service}DbContext` và query `DbSet<T>`.
  - **Giao tiếp liên service bằng typed HttpClient**:
    - Interface đặt tại `Application/Interfaces/`.
    - Triển khai tại `Infrastructure/Services/{Service}/`.
    - Đăng ký trong `DependencyInjection.cs` với `BaseAddress` và `Timeout` (hiện là `10s` cho client nghiệp vụ).
  - **InternalServiceAuthHandler**: file tồn tại trong `Services/Common/` nhưng **chưa đăng ký** trong pipeline do Internal API tạm khóa từ 2026-10-31. Không thêm header `X-Internal-Service-Key` vào request liên service.
  - **Cấu hình bảng qua Fluent API**:
    - Ràng buộc CSDL (PK, FK, index, max length, nullability) đặt trong `Configurations/` bằng `IEntityTypeConfiguration<T>`.
    - Không dùng Data Annotations trong entity Domain.
  - **Enum trong DB**: lưu `integer`, không dùng `HasConversion<string>()` hay PostgreSQL enum type.
  - **Soft delete**: entity nghiệp vụ có `IsDeleted`/`DeletedAt` và global query filter `!IsDeleted`.
  - **Concurrency/transaction**: thao tác tiền, tồn kho và trạng thái đơn phải dùng transaction; không có Outbox/Inbox.

---

### 2.4. TẦNG API (`{Service}.Api`) — ĐẦU MỐI GIAO TIẾP & MIDDLEWARE TOÀN CỤC

* **Bản chất**: Entry point Kestrel, tiếp nhận RESTful HTTP/JSON từ Gateway hoặc từ Swagger/Postman/cURL khi kiểm thử độc lập. Không có gRPC.
* **Cấu trúc thư mục thực tế**:
  ```
  {Service}.Api/
  ├── Controllers/
  │   └── Public/                                    # Toàn bộ controller hiện tại
  │       ├── AuthController.cs
  │       ├── UsersController.cs
  │       └── ...
  ├── Middleware/
  │   ├── GlobalExceptionHandlerMiddleware.cs        # RFC 9110 problem+json
  │   └── InternalServiceAuthMiddleware.cs           # Chỉ còn file, chưa đăng ký
  ├── Common/                                        # ApiValidationProblemFactory, converters
  ├── Extensions/                                    # ServiceDefaults, Observability, HttpContext
  ├── Swagger/                                       # Swagger filters (nếu có)
  ├── appsettings.json
  ├── appsettings.Development.json
  └── Program.cs                                     # Composition root + MapControllers + /health
  ```
> Từ 2026-10-31, Internal API tạm khóa: không tạo `Controllers/Internal/`, không đăng ký `InternalServiceAuthMiddleware`, route liên service dùng đường dẫn công khai.
* **Quy chuẩn lập trình**:
  - **Global Exception Middleware**: mỗi service có `GlobalExceptionHandlerMiddleware` bắt exception, ghi log kèm trace id và trả `application/problem+json` với `type`, `title`, `status`, `errorCode`, `detail`, `traceId`.
  - **Thin Controller**:
    1. Nhận route/query/body và map sang request record của Application.
    2. Gọi feature service (hoặc `ISender.Send` với Wallet).
    3. Trả kết quả **thô** (`Ok(dto)`, `StatusCode(201, dto)`) hoặc `204 NoContent`.
    - **Không** bọc `ApiResponse<T>` tại backend. Việc bọc envelope là trách nhiệm của `ResponseEnvelopeMiddleware` tại API Gateway.
    - Không viết logic nghiệp vụ hay query SQL trong controller.
  - **Identity Propagation**:
    - Đọc `x-user-id`, `x-user-roles`, `x-user-email`, `x-user-permissions` do Gateway tiêm.
    - Kiểm tra quyền sở hữu bằng `HttpContext.GetUserId()`; không tin `userId`/`buyerId` từ query hoặc body.
  - **Port**: mỗi service lắng nghe `8001`-`8009` theo `launchSettings.json` và Docker; Gateway ở `8080`.

---

## 3. QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG

Mọi exception, validation error và response error trong toàn bộ microservice **BẮT BUỘC** tuân thủ:

1. **Ngôn ngữ (100% English)**:
   - Toàn bộ thông báo lỗi trả về client viết bằng tiếng Anh. Không dùng tiếng Việt trong runtime response.
2. **Quy cách viết hoa (Sentence case)**:
   - Viết hoa duy nhất chữ cái đầu câu; các từ sau viết thường, trừ tên riêng hoặc từ viết tắt kỹ thuật (`ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`, `API`, `HTTP`).
   - ✅ `"Email is already registered in the system."`
   - ✅ `"OTP code has expired or does not exist."`
   - ❌ `"invalid email address"` (không viết hoa chữ đầu)
   - ❌ `"INVALID EMAIL ADDRESS"` (viết hoa toàn bộ)
   - ❌ `"Invalid Email Address Provided"` (Title Case)
3. **Mã lỗi (SCREAMING_SNAKE_CASE)**:
   - Viết hoa toàn bộ, nối bằng gạch dưới: `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `OTP_INVALID`, `OTP_ALREADY_USED`, `USER_NOT_FOUND`, `WALLET_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `UNAUTHORIZED`, `FORBIDDEN`.
   - Cấm tiền tố `ERR_`. Tiền tố `VAL_` chỉ dùng cho lỗi validation đầu vào (`VAL_INVALID_INPUT`, `VAL_INVALID_EMAIL`, `VAL_INVALID_ARGUMENT`).
4. **Enum đầu ra REST API**:
   - Serialize thành chuỗi PascalCase (`"Active"`, `"Pending"`, `"Delivered"`), không trả số nguyên.
   - Đầu vào chấp nhận PascalCase, case-insensitive và SCREAMING_SNAKE_CASE; từ chối số nguyên.

---

## 4. MA TRẬN PHÂN CHIA TRÁCH NHIỆM GIỮA 4 TẦNG

| Thành phần kỹ thuật | Đặt tại tầng nào? | Lý do kỹ thuật |
| :--- | :---: | :--- |
| **Entity / Base type** | `*.Domain` | Chứa dữ liệu và quy tắc nghiệp vụ bất biến của thực thể. |
| **Feature Service (Request/Response)** | `*.Application` | Đại diện cho use case nghiệp vụ cụ thể. Wallet dùng Command/Query + Handler. |
| **Validation nghiệp vụ** | `*.Application` | Kiểm tra thủ công trong feature service; không dùng FluentValidation. |
| **Interface DbContext / Client** | `*.Application` | Trừu tượng hóa lưu trữ và dịch vụ bên ngoài để đảo ngược phụ thuộc. |
| **EF Core DbContext & Configurations** | `*.Infrastructure` | Triển khai ánh xạ entity xuống PostgreSQL. |
| **Typed REST client** | `*.Infrastructure` | Gọi service khác qua `IHttpClientFactory`, xử lý timeout và fallback. |
| **Background worker** | `*.Infrastructure` | Worker nền (OTP queue, retry, dọn dẹp) không thuộc HTTP pipeline. |
| **RESTful Controllers** | `*.Api` | Nhận HTTP request, gọi feature service, trả DTO thô hoặc `204`. |
| **Program.cs, Middleware, Swagger** | `*.Api` | Composition root, pipeline và tài liệu OpenAPI; port `8001`-`8009`. |
