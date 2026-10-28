# 01 — KIẾN TRÚC VI DỊCH VỤ CHUẨN HÓA (UNIFIED MICROSERVICE ARCHITECTURE BLUEPRINT)

> **Trạng thái triển khai (2026-10-29):** 🎯 CHUẨN THIẾT KẾ ĐÍCH TOÀN HỆ THỐNG — Áp dụng đồng nhất cho 8 microservices backend (`User`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Notification`, `Log`).
> **Nguyên tắc cốt lõi:** 100% RESTful HTTP/JSON (bãi bỏ gRPC đồng bộ) · MassTransit 8.3.0 + RabbitMQ Outbox/Inbox (bất đồng bộ) · No-Repository pattern over EF Core · Feature Co-location · 1-to-1 Controller.
> **Cập nhật lần cuối:** 2026-10-29.

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
2. **`{Service}.Application`**: Chứa toàn bộ nghiệp vụ ứng dụng, định nghĩa interface `I{Service}DbContext`, Feature Services, DTOs, Event Consumers, và Integration Event Contracts.
3. **`{Service}.Infrastructure`**: Hiện thực `I{Service}DbContext`, cấu hình EF Core (Fluent API), PostgreSQL Migrations, cấu hình RabbitMQ TCP transport, và adapters bên ngoài (MailKit, VNPay, Redis).
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
│   │   ├── Interfaces/
│   │   │   └── I{Service}DbContext.cs          # Interface trừu tượng hóa EF Core context
│   │   └── Models/
│   │       ├── ApiResponse.cs                  # Phong bì dữ liệu chuẩn
│   │       └── PagedResultDto.cs               # Phong bì phân trang
│   ├── Contracts/                              # Định nghĩa Integration Events
│   │   ├── {SourceServiceA}/                   # Event nhận từ Service A
│   │   │   └── I{EventName}Event.cs
│   │   └── {Service}/                          # Event do chính service này phát ra
│   │       └── I{ThisServiceEvent}Event.cs
│   ├── Consumers/                              # Inbound Event Handlers (RabbitMQ)
│   │   ├── ConsumerExtensions.cs               # DI Extension đăng ký tất cả consumer
│   │   ├── {SourceServiceA}/                   # Consumer nghe event từ Service A
│   │   │   └── {EventName}Consumer.cs
│   │   └── {SourceServiceB}/
│   │       └── {OtherEventName}Consumer.cs
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
│   │   └── {Service}DbContext.cs               # Triển khai I{Service}DbContext + Outbox tables
│   ├── Services/                               # Adapters hạ tầng (Email, Payment, Cache)
│   └── DependencyInjection.cs                  # Cấu hình DB, MassTransit Bus, Outbox/Inbox
│
└── {Service}.Api/
    ├── Controllers/                            # REST Controllers (1-to-1 với Feature)
    │   ├── {FeatureA}Controller.cs             # Chỉ inject I{FeatureA}Service
    │   └── {FeatureB}Controller.cs             # Chỉ inject I{FeatureB}Service
    ├── Middlewares/
    │   └── GlobalExceptionHandlerMiddleware.cs
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

## 4. QUY CHUẨN XỬ LÝ EVENT MESSAGING (CONSUMERS & CONTRACTS)

### 4.1. Cấu trúc thư mục Consumer phân theo nguồn phát (Source Service)
Khi một service lắng nghe sự kiện, vị trí các Consumer được đặt tại `Application/Consumers/{SourceService}/`:
- Giúp kỹ sư xác định ngay lập tức nguồn gốc sự kiện xuất phát từ service nào trong hệ thống.
- Tuyệt đối không để consumer tại tầng `Api` hay lẫn lộn trong `Infrastructure`.

### 4.2. Đóng gói DI Extension cho Consumer (`ConsumerExtensions.cs`)
Mỗi tầng Application tự quản lý danh sách Consumer cần đăng ký thông qua file `{Service}.Application/Consumers/ConsumerExtensions.cs`:

```csharp
namespace {Service}.Application.Consumers;

using MassTransit;

public static class ConsumerExtensions
{
    public static IBusRegistrationConfigurator AddApplicationConsumers(this IBusRegistrationConfigurator configurator)
    {
        // Nhóm sự kiện đến từ Service A
        // configurator.AddConsumer<EventFromServiceAConsumer>();

        // Nhóm sự kiện đến từ Service B
        // configurator.AddConsumer<EventFromServiceBConsumer>();

        return configurator;
    }
}
```

### 4.3. Cấu hình tại Infrastructure (`Infrastructure/DependencyInjection.cs`)
File cấu hình hạ tầng chỉ cần gọi extension trên, kết hợp Outbox và RabbitMQ endpoints:

```csharp
services.AddMassTransit(x =>
{
    x.SetKebabCaseEndpointNameFormatter();

    // 1. Đăng ký toàn bộ Consumers của Application
    x.AddApplicationConsumers();

    // 2. Kích hoạt Transactional Outbox & Inbox deduplication
    x.AddEntityFrameworkOutbox<{Service}DbContext>(o =>
    {
        o.UsePostgres();
        o.UseBusOutbox();
    });

    // 3. Cấu hình kết nối RabbitMQ
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(configuration["RabbitMq:Host"] ?? "localhost", 
                 ushort.Parse(configuration["RabbitMq:Port"] ?? "5672"), "/", h =>
        {
            h.Username(configuration["RabbitMq:User"] ?? "guest");
            h.Password(configuration["RabbitMq:Password"] ?? "guest");
        });

        // Tự động bind exchange -> queue cho mọi consumer đã đăng ký
        cfg.ConfigureEndpoints(context);
    });
});
```

---

## 5. QUY CHUẨN 1-TO-1 CONTROLLER TẠI TẦNG API

Mỗi Controller ở `{Service}.Api/Controllers/{Feature}Controller.cs` ghép cặp 1-to-1 với một feature tương ứng tại tầng Application:
- Controller siêu mỏng, chỉ làm nhiệm vụ: (1) Nhận HTTP request, (2) Trích xuất claim/header nếu cần, (3) Gọi `I{Feature}Service`, (4) Trả về HTTP status code phù hợp.
- Cấm đưa logic nghiệp vụ, tính toán, kiểm tra điều kiện phức tạp vào Controller.
- Đường dẫn chuẩn RESTful: `/api/v1/{resources}` sử dụng RFC 9110 HTTP Verbs.

---

## 6. QUY CHUẨN THÔNG BÁO LỖI VÀ MÃ LỖI TOÀN HỆ THỐNG

Toàn bộ 8 microservices bắt buộc tuân thủ 3 nguyên tắc bất di bất dịch về thông báo lỗi:
1. **Ngôn ngữ (100% English)**: Toàn bộ thông báo lỗi viết bằng tiếng Anh. Tuyệt đối không dùng tiếng Việt.
2. **Quy cách viết hoa (Sentence case)**: Viết hoa duy nhất chữ cái đầu câu. Ví dụ: `"Insufficient balance to complete the transaction."`
3. **Mã lỗi (SCREAMING_SNAKE_CASE)**: Viết hoa toàn bộ và nối bằng gạch dưới. Ví dụ: `INSUFFICIENT_BALANCE`, `USER_NOT_FOUND`.
