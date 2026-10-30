# HƯỚNG DẪN CẦM TAY CHỈ VIỆC: GHÉP NỐI API & TÍCH HỢP LIÊN MICROSERVICE
## (END-TO-END SERVICE INTEGRATION PLAYBOOK FOR DEVELOPERS)

> **Trạng thái triển khai (2026-10-30):** ✅ ĐÃ CHUẨN HÓA TOÀN BỘ SANG 100% RESTFUL HTTP/JSON & TYPED REST CLIENTS.  
> **CẤM TUYỆT ĐỐI gRPC & BÃI BỎ HOÀN TOÀN MESSAGE BROKER**: Toàn bộ kiến trúc RabbitMQ, MassTransit 8.3.0, Saga State Machine và Outbox/Inbox tables đã chính thức bị **gỡ bỏ hoàn toàn (decommissioned & deleted)** khỏi hệ thống.  
> **Chuẩn giao tiếp liên service mới**: Toàn bộ tương tác giữa các service (`User` ➔ `Notification`, `Commerce` ➔ `Catalog` / `Wallet`) được triển khai thông qua **Typed REST Clients** (`IHttpClientFactory`) đồng bộ với timeout, retry và graceful fallback theo Nguyên tắc 4.9 trong `AGENTS.md`.

> **Mục tiêu tài liệu**: Tài liệu này là kim chỉ nam "cầm tay chỉ việc" (Step-by-step Hands-on Guide) dành cho các Developer và AI Coding Agents trong team. Khi mỗi thành viên đã code xong các chức năng, Controller, Service hoặc Entity riêng rẽ trong từng Microservice độc lập (`User`, `Notification`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Log`), tài liệu này hướng dẫn chi tiết cách **ghép nối chúng thành các luồng nghiệp vụ hoàn chỉnh (End-to-End Flow)** chạy thông suốt từ **ApiGateway** xuống các backend services.
>
> **Nguồn sự thật tham chiếu**: `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`, `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md`, `specs/04_SHARED_CONTRACTS_REGISTRY.md`, `AGENTS.md`.

---

## 📑 MỤC LỤC
1. [Bản Đồ Kiến Trúc Ghép Nối (Integration Architecture Overview)](#1-bản-đồ-kiến-trúc-ghép-nối)
2. [Phân Biệt 3 Mô Hình Ghép Luồng Kinh Điển](#2-phân-biệt-3-mô-hình-ghép-luồng-kinh-điển)
3. [Case Study 1: Luồng Bất Đồng Bộ 1 Chiều (Gateway ➔ User ➔ RabbitMQ ➔ Notification)](#3-case-study-1-luồng-bất-đồng-bộ-1-chiều)
4. [Case Study 2: Luồng Bắn Event Ngược Lại & Saga Bù Trừ (Commerce ⇄ Catalog ⇄ Wallet)](#4-case-study-2-luồng-bắn-event-ngược-lại--saga-bù-trừ)
5. [Case Study 3: Luồng Đồng Bộ 100% RESTful (Gateway ➔ Service A ➔ Service B)](#5-case-study-3-luồng-đồng-bộ-100-restful)
6. [Cấu Hình Hạ Tầng: MassTransit, RabbitMQ, Outbox & REST Downstream](#6-cấu-hình-hạ-tầng-masstransit-rabbitmq-outbox--rest-downstream)
7. [6 Bẫy Kỹ Thuật Thường Gặp & Cách Khắc Phục (Pitfalls & Best Practices)](#7-6-bẫy-kỹ-thuật-thường-gặp--cách-khắc-phục)
8. [Checklist Nghiệm Thu Tích Hợp Dành Cho Developer](#8-checklist-nghiệm-thu-tích-hợp-dành-cho-developer)

---

## 1. BẢN ĐỒ KIẾN TRÚC GHÉP NỐI

Khi Client (Web/Mobile) gửi một HTTP Request đến hệ thống, luồng dữ liệu sẽ di chuyển theo quy chuẩn:

```
[ Client / Frontend ]
        │  HTTP REST (JSON camelCase)
        ▼
┌────────────────────────────────────────────────────────┐
│               API GATEWAY (Port 8080)                  │
│  - Xác thực JWT Bearer & RBAC                          │
│  - Gán TraceId (x-trace-id) & Caller Claims           │
│  - Input Validation & Rate Limiting                    │
│  - GatewayBaseController.ForwardAsync (Mock / Real)    │
└────────────────────────────────────────────────────────┘
        │
        ├──[ Giao tiếp Đồng bộ (RESTful HTTP/JSON) ]─────┐
        │                                                ▼
        │                                ┌───────────────────────────────┐
        │                                │    MICROSERVICE KHỞI TẠO      │
        │                                │    (Ví dụ: UserService)       │
        │                                │  - REST Controller xử lý Req  │
        │                                │  - Ghi CSDL qua DbContext     │
        │                                │  - Lưu Event vào Outbox Table │
        │                                └───────────────────────────────┘
        │                                                │
        │                                                ▼ [ Publish Event ]
        │                                ┌───────────────────────────────┐
        │                                │   RABBITMQ EVENT BUS          │
        │                                │   (Exchange & Topic Routing)  │
        │                                └───────────────────────────────┘
        │                                                │
        │                     ┌──────────────────────────┴──────────────────────────┐
        │                     ▼ [ Consume Event ]                                   ▼ [ Consume Event ]
        │     ┌───────────────────────────────┐                     ┌───────────────────────────────┐
        │     │    MICROSERVICE LẮNG NGHE     │                     │      CENTRAL LOG SERVICE      │
        │     │   (Ví dụ: NotificationService)│                     │     (Audit & Trace Logging)   │
        │     │  - Nhận Event từ Queue        │                     │  - Ghi nhận hành vi hệ thống  │
        │     │  - Gửi Mail / Push Noti       │                     └───────────────────────────────┘
        │     │  - Bắn Event ngược lại (nếu có)
        │     └───────────────────────────────┘
```

---

## 2. PHÂN BIỆT 3 MÔ HÌNH GHÉP LUỒNG KINH ĐIỂN

| Tiêu Chí | Mô Hình 1: Đồng Bộ (Sync RESTful) | Mô Hình 2: Bất Đồng Bộ 1 Chiều (Async Pub-Sub) | Mô Hình 3: Hai Chiều / Saga (Async Choreography) |
|:---|:---|:---|:---|
| **Cơ chế** | Client gọi REST qua Gateway ➔ Service đích trả kết quả ngay. | Service A lưu DB, bắn Event ➔ Service B nhận và làm tiếp ngầm. | Service A bắn Event 1 ➔ Service B làm xong bắn Event 2 ngược lại ➔ Service A cập nhật. |
| **Giao thức** | RESTful HTTP/JSON (Port 8001-8008). | RabbitMQ (AMQP) qua MassTransit 8.3.0. | RabbitMQ (AMQP) qua MassTransit 8.3.0. |
| **Khi nào dùng?** | Lấy dữ liệu (Query), kiểm tra tài khoản, đăng nhập, tính giá tức thì. | Gửi email, SMS, push notification, ghi audit log, cập nhật cache. | Đặt hàng - giữ kho - trừ tiền ví, thanh toán đơn hàng nhiều bước. |
| **Trải nghiệm Client** | Chờ vài milliseconds để có đủ dữ liệu hiển thị. | Nhận ngay `200 OK` hoặc `202 Accepted`, công việc nặng chạy nền. | Nhận `200 OK` (trạng thái `PENDING`), nhận kết quả cuối qua WebSocket/SSE hoặc Polling. |

---

## 3. CASE STUDY 1: LUỒNG BẤT ĐỒNG BỘ 1 CHIỀU
### (Gateway ➔ UserService ➔ RabbitMQ ➔ NotificationService)

Đây là trường hợp thực tế đang chạy chuẩn 100% trong hệ thống: **Khách hàng đăng ký tài khoản ➔ Hệ thống lưu thông tin và tự động gửi email chứa mã OTP xác thực**.

```
[Client]                [ApiGateway]             [UserService]            [RabbitMQ]         [NotificationService]
   │                          │                        │                       │                       │
   │── 1. POST /auth/register ─▶                       │                       │                       │
   │                          │── 2. POST /auth/register ─▶                    │                       │
   │                          │                        │── 3. Lưu DB & Redis   │                       │
   │                          │                        │── 4. Publish Event ──▶│                       │
   │                          │◀── 5. 200/201 JSON ────│    (SendOtpEmailEvent)│                       │
   │◀── 6. 200 OK (Profile) ──│                        │                       │── 7. Push to Queue ──▶│
   │                          │                        │                       │                       │── 8. Gửi Mail SMTP
```

---

### BƯỚC 1: ĐỊNH NGHĨA CONTRACT DÙNG CHUNG (SHARED CONTRACT)

Vì mỗi Microservice nằm trong một Git Submodule độc lập (Nguyên tắc Inward-Only), hai service giao tiếp qua RabbitMQ cần một **Contract Event có cấu trúc và namespace giống hệt nhau**.

Tại `src/Services/User/User.Application/Contracts/SendOtpEmailIntegrationEvent.cs` VÀ `src/Services/Notification/...`:

```csharp
namespace Nexus.Contracts.Events;

/// <summary>
/// Sự kiện yêu cầu gửi email chứa mã OTP xác thực người dùng.
/// Quy ước: Dùng C# record immutable, namespace bắt buộc là 'Nexus.Contracts.Events'.
/// </summary>
public sealed record SendOtpEmailIntegrationEvent(
    string Email,
    string FullName,
    string Otp,
    int ExpiresInMinutes = 5);
```

> ⚠️ **Quy tắc vàng của MassTransit**: MassTransit ánh xạ Message Type dựa trên **Full Type Name (gồm cả Namespace)**. Do đó, cả bên gửi (`UserService`) và bên nhận (`NotificationService`) **BẮT BUỘC** phải đặt class/record trong cùng namespace `Nexus.Contracts.Events`.

---

### BƯỚC 2: TẠI SERVICE KHỞI TẠO (USER SERVICE - BÊN PHÁT EVENT)

#### 2.1. Triển khai Use Case & Bắn Event lên Event Bus
Tại tầng Application (`src/Services/User/User.Application/Services/Auth/AuthService.cs`):

```csharp
using MassTransit;
using Nexus.Contracts.Events;

public class AuthService : IAuthService
{
    private readonly IUserDbContext _dbContext;
    private readonly IPublishEndpoint _publishEndpoint; // <-- Inject từ MassTransit
    private readonly IRedisOtpService _redisOtpService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IUserDbContext dbContext,
        IPublishEndpoint _publishEndpoint,
        IRedisOtpService redisOtpService,
        ILogger<AuthService> logger)
    {
        _dbContext = dbContext;
        _publishEndpoint = _publishEndpoint;
        _redisOtpService = redisOtpService;
        _logger = logger;
    }

    public async Task<UserProfileDto> RegisterAsync(RegisterDto request, CancellationToken ct)
    {
        // 1. Kiểm tra nghiệp vụ & Hash mật khẩu
        // ...
        
        // 2. Tạo Entity & Lưu vào PostgreSQL
        var user = new User(request.Email, request.Username, passwordHash, ...);
        _dbContext.Users.Add(user);
        
        // Sinh OTP & lưu Redis (TTL 5 phút)
        var otpCode = Random.Shared.Next(100000, 999999).ToString();
        await _redisOtpService.SaveOtpAsync(user.Email, otpCode, TimeSpan.FromMinutes(5));

        // 3. BẮN EVENT LÊN RABBITMQ (Được bảo vệ bởi Outbox Pattern)
        // Khi gọi _publishEndpoint.Publish trước khi SaveChangesAsync, 
        // MassTransit Outbox sẽ lưu message vào bảng OutboxMessage cùng transaction của DB!
        await _publishEndpoint.Publish(new SendOtpEmailIntegrationEvent(
            Email: user.Email,
            FullName: user.FullName,
            Otp: otpCode,
            ExpiresInMinutes: 5
        ), ct);

        // 4. Commit Transaction xuống Database
        await _dbContext.SaveChangesAsync(ct);
        
        _logger.LogInformation("User {UserId} registered. SendOtpEmailIntegrationEvent published.", user.Id);

        return user.ToDto();
    }
}
```

#### 2.2. Điểm đón REST Controller Backend
Tại tầng API (`src/Services/User/User.Api/Controllers/AuthController.cs`):

```csharp
[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService) => _authService = authService;

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register([FromBody] RegisterRequestDto request, CancellationToken ct)
    {
        var dto = new RegisterDto(request.Email, request.Username, request.Password, request.DisplayName);
        var profile = await _authService.RegisterAsync(dto, ct);

        return StatusCode(StatusCodes.Status201Created, new ApiResponse<UserProfileDto>
        {
            Success = true,
            Code = StatusCodes.Status201Created,
            Message = "User registered successfully.",
            Data = profile
        });
    }
}
```

---

### BƯỚC 3: TẠI SERVICE LẮNG NGHE (NOTIFICATION SERVICE - BÊN NHẬN EVENT)

#### 3.1. Tạo Consumer kế thừa `IConsumer<T>`
Tạo file tại tầng Infrastructure (`src/Services/Notification/Notification.Infrastructure/Consumers/SendOtpEmailConsumer.cs`):

```csharp
namespace Notification.Infrastructure.Consumers;

using System.Threading.Tasks;
using MassTransit;
using Microsoft.Extensions.Logging;
using Nexus.Contracts.Events; // <-- Namespace Event dùng chung
using Notification.Application.Common.Interfaces;

public sealed class SendOtpEmailConsumer : IConsumer<SendOtpEmailIntegrationEvent>
{
    private readonly IEmailSenderService _emailSender;
    private readonly ILogger<SendOtpEmailConsumer> _logger;

    public SendOtpEmailConsumer(
        IEmailSenderService emailSender,
        ILogger<SendOtpEmailConsumer> logger)
    {
        _emailSender = emailSender;
        _logger = logger;
    }

    public async Task Consume(ConsumeContext<SendOtpEmailIntegrationEvent> context)
    {
        // 1. Lấy dữ liệu Payload từ context.Message
        var message = context.Message;
        
        _logger.LogInformation(
            "Consuming SendOtpEmailIntegrationEvent for {Email} (CorrelationId: {CorrId})",
            message.Email,
            context.CorrelationId);

        // 2. Kích hoạt logic nghiệp vụ (Gửi email qua SMTP)
        var success = await _emailSender.SendOtpRegistrationEmailAsync(
            toEmail: message.Email,
            fullName: message.FullName,
            otp: message.Otp,
            expiresInMinutes: message.ExpiresInMinutes,
            cancellationToken: context.CancellationToken);

        if (!success)
        {
            _logger.LogWarning("Failed to deliver OTP email to {Email}", message.Email);
            // Nếu muốn MassTransit tự động Retry khi lỗi mạng, hãy ném Exception ra ngoài:
            // throw new InvalidOperationException($"SMTP relay failed for {message.Email}");
        }
    }
}
```

#### 3.2. Đăng ký Consumer trong DI Container
Tại `src/Services/Notification/Notification.Infrastructure/DependencyInjection.cs`:

```csharp
services.AddMassTransit(x =>
{
    // Đăng ký Consumer để MassTransit tự động tạo hàng đợi và lắng nghe
    x.AddConsumer<SendOtpEmailConsumer>();

    // Chuẩn hóa tên Exchange/Queue dạng kebab-case (ví dụ: send-otp-email)
    x.SetKebabCaseEndpointNameFormatter();

    // Cấu hình kết nối RabbitMQ
    x.UsingRabbitMq((context, cfg) =>
    {
        var host = configuration["RabbitMq:Host"] ?? "localhost";
        var port = ushort.Parse(configuration["RabbitMq:Port"] ?? "5672");

        cfg.Host(host, port, "/", h =>
        {
            h.Username(configuration["RabbitMq:User"] ?? "guest");
            h.Password(configuration["RabbitMq:Password"] ?? "guest");
        });

        // Tự động bind consumer vào queue tương ứng
        cfg.ConfigureEndpoints(context);
    });
});
```

---

### BƯỚC 4: TẠI API GATEWAY (ĐIỂM VÀO DUY NHẤT CỦA CLIENT)

#### 4.1. Đăng ký Named HttpClient trong Gateway
Tại `src/Services/ApiGateway/Nexus.Gateway/Extensions/CoreServicesExtension.cs`:

```csharp
public static IServiceCollection AddGatewayHttpClients(this IServiceCollection services, IConfiguration configuration)
{
    // Đăng ký Named HttpClient cho 8 microservices backend (đọc base address từ Gateway:Services:{name}:Address)
    services.AddHttpClient("users", (sp, client) =>
    {
        var options = sp.GetRequiredService<IOptions<GatewayOptions>>().Value;
        if (options.Services.TryGetValue("users", out var svc) && !string.IsNullOrWhiteSpace(svc.Address))
        {
            client.BaseAddress = new Uri(svc.Address);
        }
    });
    return services;
}
```

#### 4.2. Viết Controller Action siêu mỏng qua `ForwardAsync` (Thin Controller)
Tại `src/Services/ApiGateway/Nexus.Gateway/Controllers/AuthController.cs`:

```csharp
[ApiController]
[Route("api/v1/auth")]
public class AuthController : GatewayBaseController
{
    public AuthController(IGatewayDispatcher dispatcher) : base(dispatcher)
    {
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public Task<IResult> Register([FromBody] RegisterRequestDto body)
    {
        // 1. Kiểm tra validation cơ bản tại Gateway (nếu cần)
        if (string.IsNullOrWhiteSpace(body.Email) || string.IsNullOrWhiteSpace(body.Password))
            throw new GatewayInputException("Email and password are required.");

        // 2. Chuyển tiếp tới UserService qua ForwardAsync (1 dòng duy nhất!)
        // Hàm tự động check Mock vs Real, bọc ApiResponse<T>, và forward context headers (x-trace-id, etc.)
        return ForwardAsync<RegisterRequestDto, UserProfileResponse>(new()
        {
            Service = "users",
            DownstreamPath = "/api/v1/auth/register",
            Method = HttpMethod.Post,
            Body = body,
            MockSeed = "register",
            SuccessMessage = "User registered successfully.",
            SuccessStatusCode = StatusCodes.Status201Created
        });
    }
}
```
}
```

---

## 4. CASE STUDY 2: LUỒNG BẮN EVENT NGƯỢC LẠI & SAGA BÙ TRỪ
### (CommerceService ⇄ CatalogService ⇄ WalletService)

Đây là bài toán kinh điển: **Khách tạo đơn hàng ➔ Commerce bắn Event yêu cầu giữ kho ➔ Catalog giữ kho xong BẮN EVENT NGƯỢC LẠI để Commerce cập nhật trạng thái**.

```
[CommerceService]               [RabbitMQ]                [CatalogService]
       │                            │                             │
       │── 1. Tạo Order (PENDING)   │                             │
       │── 2. Publish Event ───────▶│                             │
       │   (OrderSubmittedEvent)    │                             │
       │                            │── 3. Consume Event ────────▶│
       │                            │                             │── 4. Kiểm tra kho:
       │                            │                             │      NẾU ĐỦ: Trừ kho tạm
       │                            │◀── 5. BẮN EVENT NGƯỢC LẠI ──│      NẾU THIẾU: Báo lỗi
       │                            │   (StockReservedEvent HOẶC  │
       │                            │    StockFailedEvent)        │
       │◀── 6. Consume Callback ────│                             │
       │── 7. Cập nhật Order:       │                             │
       │      - Nếu OK ➔ PAID/WAIT  │                             │
       │      - Nếu FAIL ➔ CANCEL   │                             │
```

---

### BƯỚC 1: ĐỊNH NGHĨA CẶP CONTRACT SỰ KIỆN (XUÔI & NGƯỢC)

Tạo file Contract tại cả 2 service:
```csharp
namespace Nexus.Contracts.Events;

// 1. Event Xuôi: Commerce gửi yêu cầu giữ kho
public sealed record OrderSubmittedEvent(
    Guid OrderId,
    Guid BuyerId,
    List<OrderItemDto> Items,
    decimal TotalAmount);

public sealed record OrderItemDto(Guid SkuId, int Quantity);

// 2. Event Ngược (Thành công): Catalog thông báo đã giữ kho xong
public sealed record StockReservedEvent(
    Guid OrderId,
    Guid BuyerId,
    decimal TotalAmount);

// 3. Event Ngược (Thất bại): Catalog thông báo không đủ hàng
public sealed record StockReservationFailedEvent(
    Guid OrderId,
    string FailureReason);
```

---

### BƯỚC 2: TẠI SERVICE B (CATALOG SERVICE - NHẬN VÀ BẮN NGƯỢC LẠI)

Trong Consumer của Catalog (`src/Services/Catalog/.../Consumers/OrderSubmittedConsumer.cs`):

```csharp
using MassTransit;
using Nexus.Contracts.Events;

public sealed class OrderSubmittedConsumer : IConsumer<OrderSubmittedEvent>
{
    private readonly ICatalogDbContext _dbContext;
    private readonly ILogger<OrderSubmittedConsumer> _logger;

    public OrderSubmittedConsumer(ICatalogDbContext dbContext, ILogger<OrderSubmittedConsumer> logger)
    {
        _dbContext = dbContext;
        _logger = logger;
    }

    public async Task Consume(ConsumeContext<OrderSubmittedEvent> context)
    {
        var msg = context.Message;
        _logger.LogInformation("Processing stock reservation for Order {OrderId}", msg.OrderId);

        // 1. Kiểm tra tồn kho của từng mặt hàng
        bool isStockAvailable = true;
        foreach (var item in msg.Items)
        {
            var product = await _dbContext.Products.FindAsync(item.SkuId);
            if (product == null || product.StockQuantity < item.Quantity)
            {
                isStockAvailable = false;
                break;
            }
        }

        if (isStockAvailable)
        {
            // Trừ kho tạm
            foreach (var item in msg.Items)
            {
                var product = await _dbContext.Products.FindAsync(item.SkuId);
                product.DeductStock(item.Quantity);
            }
            await _dbContext.SaveChangesAsync();

            // 2. BẮN EVENT NGƯỢC LẠI BÁO THÀNH CÔNG: Dùng context.Publish!
            await context.Publish(new StockReservedEvent(
                OrderId: msg.OrderId,
                BuyerId: msg.BuyerId,
                TotalAmount: msg.TotalAmount
            ));

            _logger.LogInformation("Stock reserved successfully for Order {OrderId}", msg.OrderId);
        }
        else
        {
            // 3. BẮN EVENT NGƯỢC LẠI BÁO THẤT BẠI
            await context.Publish(new StockReservationFailedEvent(
                OrderId: msg.OrderId,
                FailureReason: "One or more items are out of stock."
            ));

            _logger.LogWarning("Insufficient stock for Order {OrderId}. Published failure event.", msg.OrderId);
        }
    }
}
```

---

### BƯỚC 3: TẠI SERVICE A (COMMERCE SERVICE - ĐÓN EVENT BẮN NGƯỢC LẠI)

Tạo Consumer để nghe kết quả trả về (`src/Services/Commerce/.../Consumers/StockReservedConsumer.cs`):

```csharp
using MassTransit;
using Nexus.Contracts.Events;

public sealed class StockReservedConsumer : IConsumer<StockReservedEvent>
{
    private readonly ICommerceDbContext _dbContext;
    private readonly ILogger<StockReservedConsumer> _logger;

    public StockReservedConsumer(ICommerceDbContext dbContext, ILogger<StockReservedConsumer> logger)
    {
        _dbContext = dbContext;
        _logger = logger;
    }

    public async Task Consume(ConsumeContext<StockReservedEvent> context)
    {
        var msg = context.Message;
        
        // 1. Tìm Order trong Database theo OrderId
        var order = await _dbContext.Orders.FindAsync(msg.OrderId);
        if (order == null) return;

        // 2. Chuyển trạng thái Order sang bước tiếp theo (ví dụ: Chờ thanh toán ví)
        order.MarkStockReserved();
        await _dbContext.SaveChangesAsync();

        _logger.LogInformation("Order {OrderId} updated to STOCK_RESERVED state.", msg.OrderId);
    }
}
```

Và một Consumer xử lý khi hết hàng (`StockReservationFailedConsumer.cs`):

```csharp
public sealed class StockReservationFailedConsumer : IConsumer<StockReservationFailedEvent>
{
    private readonly ICommerceDbContext _dbContext;

    public StockReservationFailedConsumer(ICommerceDbContext dbContext) => _dbContext = dbContext;

    public async Task Consume(ConsumeContext<StockReservationFailedEvent> context)
    {
        var order = await _dbContext.Orders.FindAsync(context.Message.OrderId);
        if (order != null)
        {
            // Huỷ đơn hàng vì giữ kho thất bại (Compensating action)
            order.CancelOrder(context.Message.FailureReason);
            await _dbContext.SaveChangesAsync();
        }
    }
}
```

---

## 5. CASE STUDY 3: LUỒNG ĐỒNG BỘ 100% RESTful
### (ApiGateway ➔ FulfillmentService ➔ CatalogService)

Khi một service backend cần truy vấn dữ liệu tức thì từ service khác (ví dụ: `FulfillmentService` cần lấy kích thước/cân nặng của sản phẩm từ `CatalogService` để tính cước phí vận chuyển):

```
[ApiGateway]                   [FulfillmentService]               [CatalogService]
     │                                  │                                 │
     │── 1. POST /shipment/estimate ───▶│                                 │
     │                                  │── 2. GET /api/v1/products/{id} ─▶│
     │                                  │◀── 3. Trả cân nặng/kích thước ──│
     │                                  │── 4. Tính toán phí GHN/GHTK     │
     │◀── 5. Trả cước vận chuyển ───────│                                 │
```

### Cách triển khai:
1. **Endpoint REST tại `CatalogService`**:
   `Catalog.Api/Controllers/ProductsController.cs`:
   ```csharp
   [HttpGet("products/{id:guid}")]
   public async Task<IActionResult> GetProduct(Guid id)
   {
       var product = await _sender.Send(new GetProductDetailQuery(id));
       return Ok(product);
   }
   ```
2. **Đăng ký HttpClient bên trong `FulfillmentService`**:
   Tại `Fulfillment.Infrastructure/DependencyInjection.cs`:
   ```csharp
   services.AddHttpClient("CatalogClient", client =>
   {
       client.BaseAddress = new Uri(configuration["Services:Catalog:Url"] ?? "http://localhost:8002");
       client.Timeout = TimeSpan.FromSeconds(5);
   });
   ```
3. **Gọi trực tiếp qua IHttpClientFactory**:
   ```csharp
   var client = _httpClientFactory.CreateClient("CatalogClient");
   var response = await client.GetFromJsonAsync<ProductDetailDto>($"/api/v1/products/{productId}");
   ```
   ```

---

## 6. CẤU HÌNH HẠ TẦNG: MASSTRANSIT, RABBITMQ, OUTBOX & REST DOWNSTREAM

### 6.1. Cấu hình Chuẩn MassTransit Outbox (Bắt buộc cho mọi Service có Publish)
Mọi service backend có chức năng Publish Event lên RabbitMQ **BẮT BUỘC** phải bật Transactional Outbox để chống mất dữ liệu khi mất điện hoặc crash ứng dụng:

```csharp
services.AddMassTransit(x =>
{
    // Đăng ký toàn bộ Consumer trong Assembly hiện tại
    x.AddConsumers(typeof(DependencyInjection).Assembly);

    x.SetKebabCaseEndpointNameFormatter();

    // BẬT TRANSACTIONAL OUTBOX VỚI EF CORE & POSTGRESQL
    x.AddEntityFrameworkOutbox<AppDbContext>(o =>
    {
        o.UsePostgres();
        o.UseBusOutbox(); // Tự động gom message cùng transaction SaveChangesAsync
        o.DuplicateDetectionWindow = TimeSpan.FromMinutes(30);
    });

    x.UsingRabbitMq((context, cfg) =>
    {
        var host = configuration["RabbitMq:Host"] ?? "localhost";
        var port = ushort.Parse(configuration["RabbitMq:Port"] ?? "5672");
        var user = configuration["RabbitMq:User"] ?? "guest";
        var pass = configuration["RabbitMq:Password"] ?? "guest";

        cfg.Host(host, port, "/", h =>
        {
            h.Username(user);
            h.Password(pass);
        });

        // Retry Policy khi gặp lỗi mạng/DB tạm thời
        cfg.UseMessageRetry(r => r.Interval(3, TimeSpan.FromSeconds(5)));

        cfg.ConfigureEndpoints(context);
    });
});
```

### 6.2. Cấu hình bảng Outbox trong Entity Framework Core
Trong `AppDbContext.cs`:

```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    base.OnModelCreating(modelBuilder);

    // Bắt buộc thêm 3 dòng này để MassTransit quản lý bảng Outbox/Inbox
    modelBuilder.AddInboxStateEntity();
    modelBuilder.AddOutboxMessageEntity();
    modelBuilder.AddOutboxStateEntity();
}
```

---

## 7. 6 BẪY KỸ THUẬT THƯỜNG GẶP & CÁCH KHẮC PHỤC

### ❌ BẪY 1: Sai lệch Namespace của Event giữa Publisher và Consumer
- **Hiện tượng**: Bên A báo đã publish thành công, nhưng bên B không bao giờ nhận được tin nhắn, RabbitMQ tạo ra queue `_skipped`.
- **Nguyên nhân**: Bên A để namespace `User.Contracts.Events`, bên B để `Notification.Events`. MassTransit coi đây là 2 kiểu dữ liệu khác nhau.
- **Khắc phục**: 100% Event dùng chung phải đặt đúng namespace `Nexus.Contracts.Events`.

### ❌ BẪY 2: Bắn Event SAU KHI gọi `SaveChangesAsync()`
- **Hiện tượng**: Nếu service bị crash hoặc mất kết nối RabbitMQ đúng lúc vừa lưu DB xong, Event sẽ bị mất vĩnh viễn, luồng bị gãy.
- **Khắc phục**: Luôn gọi `await _publishEndpoint.Publish(...)` **TRƯỚC** khi gọi `await _dbContext.SaveChangesAsync()`. Nhờ có `UseBusOutbox()`, Event sẽ được lưu vào bảng `OutboxMessage` cùng lúc với dữ liệu nghiệp vụ trong một Transaction an toàn tuyệt đối.

### ❌ BẪY 3: Không xử lý Idempotency (Xử lý lặp tin nhắn)
- **Hiện tượng**: Do cơ chế mạng, RabbitMQ có thể gửi 1 event đến 2 lần (At-least-once Delivery). Ví dụ: Đơn hàng bị trừ tiền 2 lần trong ví.
- **Khắc phục**:
  - Dùng Outbox/Inbox của MassTransit (`modelBuilder.AddInboxStateEntity()`).
  - Trong logic nghiệp vụ: Luôn kiểm tra trạng thái trước khi thay đổi (ví dụ: `if (order.Status == OrderStatus.Paid) return;`).

### ❌ BẪY 4: Quên map đúng Port downstream hoặc thiếu BaseAddress trong Gateway
- **Hiện tượng**: Gateway gọi downstream sang service báo lỗi 502/503 hoặc `Connection refused`.
- **Nguyên nhân**: Service backend chưa khởi chạy đúng cổng quy định hoặc `appsettings.json` của Gateway chưa khai báo `Address` cho service đó.
- **Khắc phục**: Kiểm tra bảng cổng trong `specs/01_SERVICE_CATALOG_PORT_MAP.md` và `launchSettings.json` của backend service:
  ```json
  "applicationUrl": "http://localhost:8001"
  ```
  Và đảm bảo `Gateway:Services:{serviceName}:Address` trong `appsettings.json` của ApiGateway trỏ đúng URL này.

### ❌ BẪY 5: Hardcode Port hoặc Chuỗi Kết Nối
- **Hiện tượng**: Code chạy trên máy dev cá nhân được nhưng khi ghép lên Docker Compose hoặc VPS thì chết hàng loạt.
- **Khắc phục**: Đọc cấu hình từ `IConfiguration`:
  - Port cố định từ `specs/01_SERVICE_CATALOG_PORT_MAP.md` (Gateway: `8080`, User: `8001`, Catalog: `8002`, Commerce: `8003`, Log: `8004`, Auction: `8005`, Fulfillment: `8006`, Notification: `8007`, Wallet: `8008`, CheckHeal: `8009`).
  - RabbitMQ: `RabbitMq:Host`, `RabbitMq:Port`.

### ❌ BẪY 6: Thông báo lỗi không tuân thủ Sentence Case
- **Hiện tượng**: Lỗi trả về tiếng Việt hoặc viết hoa tùy tiện (`VAL_INVALID_INPUT: Lỗi không tìm thấy`).
- **Khắc phục**: Tuân thủ triệt để **Nguyên tắc 5 trong `AGENTS.md`**: 100% tiếng Anh Sentence case (chữ thường, chỉ viết hoa chữ cái đầu), ErrorCode viết hoa `SCREAMING_SNAKE_CASE`. Ví dụ: `400 VAL_INVALID_INPUT: Email is already registered in the system.`

---

## 8. CHECKLIST NGHIỆM THU TÍCH HỢP DÀNH CHO DEVELOPER

Trước khi báo cáo hoàn thành việc ghép một API/luồng liên service, developer bắt buộc phải kiểm tra lần lượt danh sách sau:

- [ ] **Contract Đã Khớp**:
  - [ ] REST DTOs / Endpoint route đã được đồng bộ giữa Gateway và Service backend.
  - [ ] Event class/record có tên trường, kiểu dữ liệu và namespace (`Nexus.Contracts.Events`) giống nhau 100%.
- [ ] **Hạ Tầng Sẵn Sàng**:
  - [ ] RabbitMQ đã khởi chạy và đăng nhập được Web Management (`http://localhost:15672`).
  - [ ] CSDL PostgreSQL của các service liên quan đã migrate đầy đủ các bảng nghiệp vụ + 3 bảng Outbox (`InboxStates`, `OutboxMessages`, `OutboxStates`).
- [ ] **Thực Thi Luồng**:
  - [ ] Gửi Request từ Client/Postman vào `http://localhost:8080/api/v1/...` của ApiGateway.
  - [ ] ApiGateway nhận request, log ra `traceId` và gọi REST downstream thành công sang Service Khởi tạo.
  - [ ] Service Khởi tạo ghi DB và bảng `OutboxMessage` thành công.
  - [ ] RabbitMQ hiển thị message được publish lên Exchange và chuyển vào Queue của Consumer.
  - [ ] Service Lắng nghe consume message thành công, log ghi nhận xử lý trọn vẹn không ném unhandled exception.
  - [ ] Nếu là luồng 2 chiều: Service Khởi tạo nhận được event callback bắn ngược lại và cập nhật trạng thái cuối cùng thành công.
- [ ] **Kiểm Tra Lỗi (Negative Testing)**:
  - [ ] Thử tắt Service Lắng nghe: Service Khởi tạo vẫn phản hồi thành công; message được giữ an toàn trong RabbitMQ và được xử lý ngay khi Service Lắng nghe bật lại.
  - [ ] Test suite `dotnet test` của tất cả các service liên quan đạt **100% PASS**.
