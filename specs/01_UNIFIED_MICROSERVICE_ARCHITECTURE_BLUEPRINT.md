# 01 — KIẾN TRÚC VI DỊCH VỤ CHUẨN HÓA (UNIFIED MICROSERVICE ARCHITECTURE BLUEPRINT)

> **Trạng thái triển khai (2026-10-30):** 🎯 CHUẨN THIẾT KẾ ĐÍCH TOÀN HỆ THỐNG — Áp dụng đồng nhất cho 8 microservices backend (`User`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Notification`, `Log`).
> **Nguyên tắc cốt lõi:** 100% RESTful HTTP/JSON (bãi bỏ gRPC đồng bộ) · Giao tiếp đồng bộ trực tiếp qua REST client (bãi bỏ hoàn toàn RabbitMQ, MassTransit và Outbox/Inbox) · No-Repository pattern over EF Core · Feature Co-location · 1-to-1 Controller.
> **Cập nhật lần cuối:** 2026-10-30.

---

## 1. PHÂN TẦNG VÀ CHIỀU PHỤ THUỘC (DEPENDENCY RULE)

Mỗi microservice độc lập chứa đúng 4 project tương ứng 4 tầng Clean Architecture:

```
[ {Service}.Api ] ─────────────┐
                               │
                               ▼
               [ {Service}.Application ] ──▶ [ {Service}.Domain ]
                               ▲
                               │
[ {Service}.Infrastructure ] ──┘
```

### Trách nhiệm từng tầng:
1. **`{Service}.Domain`**: Chứa Core Entities, Value Objects, Domain Events, Enums, Domain Exceptions. **Không tham chiếu bất kỳ project hay thư viện bên ngoài nào** (zero-dependency, không cài EF Core hay MediatR vào Domain).
2. **`{Service}.Application`**: Chứa toàn bộ nghiệp vụ ứng dụng, định nghĩa interface `I{Service}DbContext`, Feature Services, DTOs, và Client Interfaces giao tiếp liên service. **Ngoại lệ duy nhất:** `WalletService` dùng classic CQRS qua MediatR tại `Features/{Area}/Commands|Queries/{UseCase}/`, không có Feature Service facade.
3. **`{Service}.Infrastructure`**: Hiện thực `I{Service}DbContext`, cấu hình EF Core (Fluent API), PostgreSQL Migrations, HTTP REST Clients gọi liên service, và adapters bên ngoài (MailKit, VNPay, Redis).
4. **`{Service}.Api`**: Điểm vào HTTP duy nhất của service (REST Controllers, Middlewares, DI Bootstrap trong `Program.cs`). **Tuyệt đối không chứa logic nghiệp vụ hay truy vấn database trực tiếp**.

---

## 2. CẤU TRÚC THƯ MỤC CHUẨN TẠI TỪNG SERVICE

```text
src/Services/{Service}/
├── {Service}.Domain/
│   ├── Entities/
│   ├── Enums/
│   ├── Events/
│   └── Exceptions/
│
├── {Service}.Application/
│   ├── Common/
│   │   ├── Extensions/
│   │   │   └── EnumExtensions.cs               # Parse enum an toàn & tiện ích chung
│   │   └── Models/
│   │       └── PagedResultDto.cs               # DTO phân trang chuẩn
│   ├── Interfaces/                             # Toàn bộ DbContext và Typed Client Interfaces
│   │   ├── I{Service}DbContext.cs              # Interface trừu tượng hóa EF Core context
│   │   └── I{Sibling}InternalClient.cs         # Interfaces giao tiếp ngoài (vd: IEmailNotificationClient, IFulfillmentInternalClient)
│   ├── Services/                               # Feature Co-location (Nghiệp vụ đồng bộ)
│   │   ├── {FeatureA}/
│   │   │   ├── I{FeatureA}Service.cs
│   │   │   ├── {FeatureA}Service.cs            # Inject I{Service}DbContext trực tiếp
│   │   │   ├── {FeatureA}Requests.cs           # Request DTOs
│   │   │   ├── {FeatureA}Responses.cs          # Response DTOs
│   │   │   └── {FeatureA}Dtos.cs               # Internal sub-DTOs (nếu có)
│   │   └── {FeatureB}/
│   │       ├── I{FeatureB}Service.cs
│   │       ├── {FeatureB}Service.cs
│   │       ├── {FeatureB}Requests.cs
│   │       └── {FeatureB}Responses.cs
│   └── DependencyInjection.cs                  # Đăng ký Application Services & FluentValidation
│
├── {Service}.Infrastructure/
│   ├── Persistence/
│   │   ├── Configurations/                     # EF Core EntityTypeConfiguration<T>
│   │   ├── Migrations/                         # PostgreSQL EF Migrations
│   │   └── {Service}DbContext.cs               # Triển khai I{Service}DbContext
│   ├── Services/                               # Adapters hạ tầng & REST clients liên service
│   └── DependencyInjection.cs                  # Cấu hình DB, HttpClient, Redis
│
└── {Service}.Api/
    ├── Controllers/                            # REST Controllers (Phân tách Public vs Internal)
    │   ├── Public/                             # API phục vụ người dùng qua Gateway (/api/v1/{resources})
    │   │   ├── {FeatureA}Controller.cs         # Chỉ inject I{FeatureA}Service
    │   │   └── {FeatureB}Controller.cs
    │   └── Internal/                           # API phục vụ liên service nội bộ (/api/v1/internal/{resources})
    │       └── Internal{Feature}Controller.cs  # Yêu cầu header X-Internal-Service-Key
    ├── Middlewares/
    │   ├── GlobalExceptionHandlerMiddleware.cs
    │   └── InternalServiceAuthMiddleware.cs    # Kiểm tra X-Internal-Service-Key cho /api/v1/internal/*
    ├── appsettings.json
    └── Program.cs                              # Bootstrap DI, Middlewares, Map Controllers
```

---

## 3. QUY TẮC CO-LOCATION TẠI TẦNG APPLICATION

Toàn bộ các file phục vụ một tính năng nghiệp vụ phải được đặt chung trong một thư mục `{Service}.Application/Services/{Feature}/`:

### Danh mục file bắt buộc trong một Feature folder:
1. `I{Feature}Service.cs`: Hợp đồng nghiệp vụ ca sử dụng.
2. `{Feature}Service.cs`: Triển khai nghiệp vụ, **sử dụng trực tiếp `I{Service}DbContext` và `DbSet<T>`**.
3. `{Feature}Requests.cs`: Gom toàn bộ record request đầu vào của tính năng (tránh xé lẻ mỗi request một file class rác).
4. `{Feature}Responses.cs`: Gom toàn bộ record response đầu ra của tính năng.
5. `{Feature}Dtos.cs` *(tùy chọn)*: Gom các DTO phụ trợ dùng nội bộ trong feature.

### 🛑 Rào chắn cấm Repository Pattern:
- **CẤM** tạo lớp `IRepository<T>`, `GenericRepository`, `UnitOfWork` bọc ngoài EF Core.
- Triển khai nghiệp vụ gọi trực tiếp `_dbContext.{Entities}.Where(...).ToListAsync()` hoặc `_dbContext.{Entities}.Add(...)`.

---

## 4. QUY CHUẨN GIAO TIẾP LIÊN DỊCH VỤ QUA REST (HTTP REST CLIENTS)

### 4.1. Khai báo Interface tại Application Layer
Khi một service cần giao tiếp với service khác (ví dụ: `UserService` gọi `NotificationService` để gửi email OTP), interface giao tiếp được định nghĩa tại `Application/Interfaces/`:

```csharp
namespace User.Application.Interfaces;

public interface IEmailNotificationClient
{
    Task<bool> SendEmailAsync(string toEmail, string subject, string body, CancellationToken cancellationToken = default);
}
```

### 4.2. Hiện thực HttpClient tại Infrastructure Layer
Tầng Infrastructure hiện thực interface bằng `HttpClient` (sử dụng `IHttpClientFactory`), cấu hình BaseUrl và Timeout từ `IConfiguration`:

```csharp
namespace User.Infrastructure.Services.Notification;

public class EmailNotificationClient : IEmailNotificationClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<EmailNotificationClient> _logger;

    public EmailNotificationClient(HttpClient httpClient, ILogger<EmailNotificationClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<bool> SendEmailAsync(string toEmail, string subject, string body, CancellationToken cancellationToken = default)
    {
        // Gọi HTTP POST sang Notification Service
        // Fallback ghi log nếu service đích offline
    }
}
```

### 4.3. Đăng ký Typed HttpClient tại Infrastructure DI
```csharp
services.AddTransient<InternalServiceAuthHandler>();
services.AddHttpClient<IEmailNotificationClient, EmailNotificationClient>(client =>
{
    client.BaseAddress = new Uri(configuration["NotificationService:BaseUrl"] ?? "http://localhost:8007");
    client.Timeout = TimeSpan.FromSeconds(5);
}).AddHttpMessageHandler<InternalServiceAuthHandler>();
```

### 4.4. Tự Động Tiêm Khóa Bí Mật Nội Bộ Qua DelegatingHandler
Mọi HttpClient gọi sang Internal API của service khác bắt buộc phải đăng ký kèm `InternalServiceAuthHandler` (kế thừa `DelegatingHandler`) để tự động tiêm header `X-Internal-Service-Key`.

---

## 5. QUY CHUẨN CONTROLLER VÀ PHÂN TÁCH PUBLIC / INTERNAL TẠI TẦNG API

Mỗi Controller ở `{Service}.Api/Controllers/` thuộc 1 trong 2 nhóm phân lập:
1. **Public Controllers (`{Service}.Api/Controllers/Public/`)**:
   - Ghép cặp 1-to-1 với feature service tương ứng.
   - Nhận yêu cầu từ người dùng thông qua API Gateway.
   - Đường dẫn: `/api/v1/{resources}` sử dụng RFC 9110 HTTP Verbs.
   - Controller siêu mỏng, chỉ làm nhiệm vụ: (1) Nhận HTTP request, (2) Trích xuất claim/header nếu cần, (3) Gọi `I{Feature}Service`, (4) Trả về HTTP status code phù hợp.
2. **Internal Controllers (`{Service}.Api/Controllers/Internal/`)**:
   - Chỉ phục vụ các cuộc gọi trực tiếp từ backend microservice anh em.
   - Bắt buộc tiền tố: `/api/v1/internal/{resources}`.
   - Bắt buộc kiểm tra bảo mật qua `InternalServiceAuthMiddleware` với header `X-Internal-Service-Key`.
   - Tuyệt đối không khai báo route cho Gateway và Gateway chủ động chặn 404 với mọi request chứa `/api/v1/internal`.

---

## 6. QUY CHUẨN THÔNG BÁO LỖI VÀ MÃ LỖI TOÀN HỆ THỐNG

Toàn bộ 8 microservices bắt buộc tuân thủ 3 nguyên tắc bất di bất dịch về thông báo lỗi:
1. **Ngôn ngữ (100% English)**: Toàn bộ thông báo lỗi viết bằng tiếng Anh. Tuyệt đối không dùng tiếng Việt.
2. **Quy cách viết hoa (Sentence case)**: Viết hoa duy nhất chữ cái đầu câu. Ví dụ: `"Insufficient balance to complete the transaction."`
3. **Mã lỗi (SCREAMING_SNAKE_CASE)**: Viết hoa toàn bộ và nối bằng gạch dưới. Ví dụ: `INSUFFICIENT_BALANCE`, `USER_NOT_FOUND`.

---

## 7. QUY CHUẨN THAY ĐỔI & THAO TÁC CƠ SỞ DỮ LIỆU (DATABASE GOVERNANCE RULES)

Khi đụng tới hoặc thay đổi cơ sở dữ liệu ở bất kỳ microservice nào, tất cả kỹ sư và AI Coding Agent bắt buộc tuân thủ:

### 7.1. Lưu trữ và Ép kiểu Enum (Enum Persistence & Serialization)
- **Cơ sở dữ liệu PostgreSQL**: 100% Enum phải được lưu dưới dạng số nguyên `integer` (32-bit signed int). CẤM dùng `HasConversion<string>()` hoặc PostgreSQL Custom Enum Type.
- **Tầng Domain & Application**: 100% sử dụng C# Enum strongly-typed (kế thừa `int32`), gán giá trị số rõ ràng từ `0`. Cấm dùng số ma thuật (magic numbers) hay chuỗi thô để so sánh.
- **Đầu ra REST API (Outbound to Client)**: 100% phải được tuần tự hóa thành chuỗi PascalCase (`"Active"`, `"PendingVerification"`).
- **Đầu vào REST API (Inbound from Client)**:
  - JSON Body: Qua `PascalCaseJsonStringEnumConverter`, hỗ trợ case-insensitive và SCREAMING_SNAKE_CASE (tự động loại bỏ dấu gạch dưới). CẤM nhận số nguyên (`allowIntegerValues: false`).
  - Query Parameters / Route Data: Dùng `EnumExtensions.TryToEnum<TEnum>(out var result)` hoặc `ToEnum<TEnum>()`.

### 7.2. Quản lý Migration EF Core (Migration Lifecycle)
- **Plan-First**: Lập kế hoạch chi tiết trước khi tạo migration mới.
- **Đặt tên Migration**: `YYYYMMDDHHMMSS_DescriptiveAction` hoặc PascalCase rõ nghĩa.
- **Cấm Migration phá hủy (Zero Destructive Migrations)**: Tuyệt đối CẤM tự ý `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, hoặc `RENAME COLUMN` khi chưa có sự chấp thuận trực tiếp của Người dùng. Mọi thay đổi tuân theo nguyên tắc Additive.
- **Đồng bộ Snapshot**: Kiểm tra `AppDbContextModelSnapshot.cs` và file `.Designer.cs` khớp 100% với schema entity.
- **Khởi động An toàn**: Chỉ gọi `db.Database.Migrate()` khi `db.Database.IsRelational()` là true, bọc trong `try-catch` với log cảnh báo.

### 7.3. Cách ly Cơ sở dữ liệu Tuyệt đối (Database-per-Service Isolation)
- Mỗi microservice sở hữu cơ sở dữ liệu riêng biệt.
- CẤM truy vấn chéo giữa các DB (cấm dblink, foreign data wrapper, cross-database join).
- CẤM chia sẻ `DbContext` giữa các microservices.

### 7.4. Cấm Repository Pattern bọc ngoài EF Core
- Inject `I{Service}DbContext` và truy vấn `DbSet<T>` trực tiếp trong Application Layer. Cấm `IRepository<T>`, `GenericRepository`, `UnitOfWork`.

### 7.5. Cấu hình Thực thể (Entity Configuration Standards)
- **Tên bảng**: PascalCase theo tên Entity / DbSet.
- **Khóa chính**: `Guid` kế thừa `BaseEntity<Guid>` hoặc `AuditableEntity<Guid>`.
- **Foreign Keys**: Ưu tiên `DeleteBehavior.Restrict` hoặc `DeleteBehavior.SetNull`, tránh cascade cycle.
- **Soft Delete**: Mọi bảng nghiệp vụ phải có `IsDeleted` và `DeletedAt`. Bắt buộc cấu hình `builder.HasQueryFilter(x => !x.IsDeleted)`.
- **Chỉ mục**: Đánh index có filter cho các trường tìm kiếm thường xuyên và các trường unique nullable.
- **Độ chính xác tiền tệ**: Mọi trường tiền tệ, số dư dùng `decimal` với `HasPrecision(18, 2)`.

### 7.6. Dữ liệu Khởi tạo (Seed Data Standards)
- Khai báo qua `HasData()`. Khóa chính ID BẮT BUỘC dùng GUID cố định (`Guid.Parse("...")`), CẤM dùng `Guid.NewGuid()`.
- Mật khẩu tài khoản seed phải hash bằng BCrypt có salt trước, không lưu plain text.

### 7.7. Bảo mật Chuỗi kết nối
- CẤM commit mật khẩu thật, connection string thực tế lên Git. Mọi thông tin nạp qua biến môi trường.

