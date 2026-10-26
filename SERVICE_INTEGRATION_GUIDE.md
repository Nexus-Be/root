# HƯỚNG DẪN CẦM TAY CHỈ VIỆC: GHÉP NỐI API & TÍCH HỢP LIÊN MICROSERVICE
## (END-TO-END SERVICE INTEGRATION PLAYBOOK FOR DEVELOPERS)

> **Mục tiêu tài liệu**: Tài liệu này là kim chỉ nam "cầm tay chỉ việc" (Step-by-step Hands-on Guide) dành cho các Developer và AI Coding Agents trong team. Khi mỗi thành viên đã code xong các chức năng, Controller, Service hoặc Entity riêng rẽ trong từng Microservice độc lập (`User`, `Notification`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Log`), tài liệu này hướng dẫn chi tiết cách **ghép nối chúng thành các luồng nghiệp vụ hoàn chỉnh (End-to-End Flow)** chạy thông suốt từ **ApiGateway** xuống các backend services.
>
> **Nguồn sự thật tham chiếu**: `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`, `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md`, `specs/04_SHARED_CONTRACTS_REGISTRY.md`, `AGENTS.md`.

---

## 📑 MỤC LỤC
1. [Bản Đồ Kiến Trúc Ghép Nối (Integration Architecture Overview)](#1-bản-đồ-kiến-trúc-ghép-nối)
2. [Phân Biệt 3 Mô Hình Ghép Luồng Kinh Điển](#2-phân-biệt-3-mô-hình-ghép-luồng-kinh-điển)
3. [Case Study 1: Luồng Bất Đồng Bộ 1 Chiều (Gateway ➔ User ➔ RabbitMQ ➔ Notification)](#3-case-study-1-luồng-bất-đồng-bộ-1-chiều)
4. [Case Study 2: Luồng Bắn Event Ngược Lại & Saga Bù Trừ (Commerce ⇄ Catalog ⇄ Wallet)](#4-case-study-2-luồng-bắn-event-ngược-lại--saga-bù-trừ)
5. [Case Study 3: Luồng Đồng Bộ 100% Qua gRPC (Gateway ➔ Service A ➔ Service B)](#5-case-study-3-luồng-đồng-bộ-100-qua-grpc)
6. [Cấu Hình Hạ Tầng: MassTransit, RabbitMQ, Outbox & gRPC](#6-cấu-hình-hạ-tầng-masstransit-rabbitmq-outbox--grpc)
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
│               API GATEWAY (Port 8000)                  │
│  - Xác thực JWT Bearer & RBAC                          │
│  - Gán TraceId (x-trace-id) & Caller Claims           │
│  - Input Validation & Rate Limiting                    │
│  - Dispatcher điều phối (Mock hoặc Real qua gRPC)      │
└────────────────────────────────────────────────────────┘
        │
        ├──[ Giao tiếp Đồng bộ (gRPC HTTP/2 Protobuf) ]──┐
        │                                                ▼
        │                                ┌───────────────────────────────┐
        │                                │    MICROSERVICE KHỞI TẠO      │
        │                                │    (Ví dụ: UserService)       │
        │                                │  - gRPC Server xử lý Request  │
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

| Tiêu Chí | Mô Hình 1: Đồng Bộ (Sync gRPC) | Mô Hình 2: Bất Đồng Bộ 1 Chiều (Async Pub-Sub) | Mô Hình 3: Hai Chiều / Saga (Async Choreography) |
|:---|:---|:---|:---|
| **Cơ chế** | Client gọi gRPC ➔ Server trả kết quả ngay. | Service A lưu DB, bắn Event ➔ Service B nhận và làm tiếp ngầm. | Service A bắn Event 1 ➔ Service B làm xong bắn Event 2 ngược lại ➔ Service A cập nhật. |
| **Giao thức** | gRPC (HTTP/2, Protobuf v3). | RabbitMQ (AMQP) qua MassTransit 8.3.0. | RabbitMQ (AMQP) qua MassTransit 8.3.0. |
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
   │                          │── 2. gRPC Register ───▶│                       │                       │
   │                          │                        │── 3. Lưu DB & Redis   │                       │
   │                          │                        │── 4. Publish Event ──▶│                       │
   │                          │◀── 5. gRPC Response ───│    (SendOtpEmailEvent)│                       │
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

#### 2.2. Điểm đón gRPC Server
Tại tầng API (`src/Services/User/User.Api/Services/UsersGrpcService.cs`):

```csharp
[Authorize]
public class UsersGrpcService : UsersApi.UsersApiBase
{
    private readonly IAuthService _authService;

    public UsersGrpcService(IAuthService authService) => _authService = authService;

    [AllowAnonymous]
    public override async Task<RegisterResponse> Register(RegisterRequest request, ServerCallContext context)
    {
        try
        {
            var dto = new RegisterDto(request.Email, request.Username, request.Password, request.DisplayName);
            var profile = await _authService.RegisterAsync(dto, context.CancellationToken);

            return new RegisterResponse
            {
                Success = true,
                User = profile.ToGrpcModel()
            };
        }
        catch (Exception ex)
        {
            // Trả lỗi theo chuẩn gRPC StatusCode
            throw new RpcException(new Status(StatusCode.InvalidArgument, ex.Message));
        }
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

#### 4.1. Đăng ký gRPC Client trong Gateway
Tại `src/Services/ApiGateway/Nexus.Gateway/Extensions/GrpcClientsExtension.cs`:

```csharp
public static IServiceCollection AddGatewayGrpcClients(this IServiceCollection services)
{
    // Đăng ký client gRPC kết nối tới UserService (cổng 8001)
    services.AddNamedGrpcClient<UsersApi.UsersApiClient>("users");
    return services;
}
```

#### 4.2. Viết Controller Action siêu mỏng (Thin Controller)
Tại `src/Services/ApiGateway/Nexus.Gateway/Controllers/AuthController.cs`:

```csharp
[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly IGatewayDispatcher _dispatcher;
    private readonly UsersApi.UsersApiClient _client;

    public AuthController(IGatewayDispatcher dispatcher, UsersApi.UsersApiClient client)
    {
        _dispatcher = dispatcher;
        _client = client;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public Task<IResult> Register([FromBody] RegisterRequestDto body)
    {
        // 1. Kiểm tra validation cơ bản tại Gateway
        if (string.IsNullOrWhiteSpace(body.Email) || string.IsNullOrWhiteSpace(body.Password))
            throw new GatewayInputException("Email and password are required.");

        // 2. Chuyển tiếp tới UserService qua Dispatcher
        // Dispatcher tự động xử lý chuyển đổi lỗi gRPC sang RFC 9110 ProblemDetails
        return _dispatcher.DispatchAsync(
            HttpContext,
            serviceName: "users",
            operation: "register",
            call: opt => _client.RegisterAsync(new RegisterRequest
            {
                Email = body.Email.Trim().ToLowerInvariant(),
                Password = body.Password,
                DisplayName = body.DisplayName
            }, opt),
            parser: UserProfile.Parser,
            successMessage: "User registered successfully."
        );
    }
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

## 5. CASE STUDY 3: LUỒNG ĐỒNG BỘ 100% QUA gRPC
### (ApiGateway ➔ FulfillmentService ➔ CatalogService)

Khi một service backend cần truy vấn dữ liệu tức thì từ service khác (ví dụ: `FulfillmentService` cần lấy kích thước/cân nặng của sản phẩm từ `CatalogService` để tính cước phí vận chuyển):

```
[ApiGateway]                   [FulfillmentService]               [CatalogService]
     │                                  │                                 │
     │── 1. POST /shipment/estimate ───▶│                                 │
     │                                  │── 2. gRPC GetProductDetails ───▶│
     │                                  │◀── 3. Trả cân nặng/kích thước ──│
     │                                  │── 4. Tính toán phí GHN/GHTK     │
     │◀── 5. Trả cước vận chuyển ───────│                                 │
```

### Cách triển khai:
1. **Khai báo RPC trong `Contracts/catalog.proto`**:
   ```protobuf
   service CatalogApi {
     rpc GetProduct (GetProductRequest) returns (ProductResponse);
   }
   ```
2. **Đăng ký gRPC Client bên trong `FulfillmentService`**:
   Tại `Fulfillment.Infrastructure/DependencyInjection.cs`:
   ```csharp
   services.AddGrpcClient<CatalogApi.CatalogApiClient>(o =>
   {
       o.Address = new Uri(configuration["Services:Catalog:Url"] ?? "http://localhost:8002");
   });
   ```
3. **Gọi trực tiếp trong Service**:
   ```csharp
   var catalogClient = _serviceProvider.GetRequiredService<CatalogApi.CatalogApiClient>();
   var productInfo = await catalogClient.GetProductAsync(new GetProductRequest { Id = productId.ToString() });
   ```

---

## 6. CẤU HÌNH HẠ TẦNG: MASSTRANSIT, RABBITMQ, OUTBOX & gRPC

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

### ❌ BẪY 4: Quên map Port gRPC hoặc giao thức HTTP/2
- **Hiện tượng**: Gateway gọi gRPC sang service báo lỗi `StatusCode.Unavailable` hoặc `Stream removed`.
- **Nguyên nhân**: gRPC yêu cầu giao thức HTTP/2 không mã hóa (H2C) trong môi trường nội bộ.
- **Khắc phục**: Kiểm tra `launchSettings.json` hoặc `appsettings.json` của service backend, cấu hình Kestrel lắng nghe đúng:
  ```json
  "Kestrel": {
    "EndpointDefaults": {
      "Protocols": "Http1AndHttp2"
    }
  }
  ```

### ❌ BẪY 5: Hardcode Port hoặc Chuỗi Kết Nối
- **Hiện tượng**: Code chạy trên máy dev cá nhân được nhưng khi ghép lên Docker Compose hoặc VPS thì chết hàng loạt.
- **Khắc phục**: Đọc cấu hình từ `IConfiguration`:
  - Port cố định từ `specs/01_SERVICE_CATALOG_PORT_MAP.md` (Gateway: `8000`, User: `8001`, Catalog: `8002`, Commerce: `8003`, Log: `8004`, Auction: `8005`, Fulfillment: `8006`, Notification: `8007`, Wallet: `8008`, CheckHeal: `8009`).
  - RabbitMQ: `RabbitMq:Host`, `RabbitMq:Port`.

### ❌ BẪY 6: Thông báo lỗi không tuân thủ Sentence Case
- **Hiện tượng**: Lỗi trả về tiếng Việt hoặc viết hoa tùy tiện (`VAL_INVALID_INPUT: Lỗi không tìm thấy`).
- **Khắc phục**: Tuân thủ triệt để **Nguyên tắc 5 trong `AGENTS.md`**: 100% tiếng Anh Sentence case (chữ thường, chỉ viết hoa chữ cái đầu), ErrorCode viết hoa `SCREAMING_SNAKE_CASE`. Ví dụ: `400 VAL_INVALID_INPUT: Email is already registered in the system.`

---

## 8. CHECKLIST NGHIỆM THU TÍCH HỢP DÀNH CHO DEVELOPER

Trước khi báo cáo hoàn thành việc ghép một API/luồng liên service, developer bắt buộc phải kiểm tra lần lượt danh sách sau:

- [ ] **Contract Đã Khớp**:
  - [ ] Proto file đã được đồng bộ giữa Gateway và Service backend.
  - [ ] Event class/record có tên trường, kiểu dữ liệu và namespace (`Nexus.Contracts.Events`) giống nhau 100%.
- [ ] **Hạ Tầng Sẵn Sàng**:
  - [ ] RabbitMQ đã khởi chạy và đăng nhập được Web Management (`http://localhost:15672`).
  - [ ] CSDL PostgreSQL của các service liên quan đã migrate đầy đủ các bảng nghiệp vụ + 3 bảng Outbox (`InboxStates`, `OutboxMessages`, `OutboxStates`).
- [ ] **Thực Thi Luồng**:
  - [ ] Gửi Request từ Client/Postman vào `http://localhost:8000/api/v1/...` của ApiGateway.
  - [ ] ApiGateway nhận request, log ra `traceId` và gọi gRPC thành công sang Service Khởi tạo.
  - [ ] Service Khởi tạo ghi DB và bảng `OutboxMessage` thành công.
  - [ ] RabbitMQ hiển thị message được publish lên Exchange và chuyển vào Queue của Consumer.
  - [ ] Service Lắng nghe consume message thành công, log ghi nhận xử lý trọn vẹn không ném unhandled exception.
  - [ ] Nếu là luồng 2 chiều: Service Khởi tạo nhận được event callback bắn ngược lại và cập nhật trạng thái cuối cùng thành công.
- [ ] **Kiểm Tra Lỗi (Negative Testing)**:
  - [ ] Thử tắt Service Lắng nghe: Service Khởi tạo vẫn phản hồi thành công; message được giữ an toàn trong RabbitMQ và được xử lý ngay khi Service Lắng nghe bật lại.
  - [ ] Test suite `dotnet test` của tất cả các service liên quan đạt **100% PASS**.
