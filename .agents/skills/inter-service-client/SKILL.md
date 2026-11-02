---
name: inter-service-client
description: Procedure for adding or modifying synchronous inter-service REST clients across Nexus backend microservices. Use when a service needs to query data from or trigger actions in another service without using message brokers or direct database access.
---

# Inter-Service REST Client

This skill defines the canonical architecture and procedure for inter-service communication across the Nexus backend.

## 1. When to use

Use this skill when:
- A service use case requires synchronous data from another bounded context (e.g., Commerce checking product inventory or price from Catalog).
- A service use case triggers a mutating action in another service (e.g., Commerce charging a buyer wallet via WalletService, UserService sending OTP via NotificationService).
- Adding, updating, or testing an inter-service `HttpClient` implementation.

Do not use this skill for internal intra-service calls or external public third-party gateways (such as VNPay).

## 2. Architectural Invariants

Every inter-service client must strictly adhere to the following 6 rules:

1. **100% RESTful HTTP/JSON (No Brokers, No gRPC):** All inter-service communication uses typed `HttpClient` instances. RabbitMQ, MassTransit, Saga, and Outbox/Inbox tables are decommissioned. gRPC is strictly prohibited.
2. **Strict Project Isolation (Zero Cross-References):** The caller service must never add a project reference to the callee service, never share entity classes, and never query the callee database directly.
3. **Internal API Model Disabled (Current Policy):** Do not prefix paths with `/api/v1/internal/`. Call standard public endpoints (e.g., `POST /api/v1/notifications/email/otp`, `POST /api/v1/wallets/checkout/direct`). Do not require or transmit `X-Internal-Service-Key`.
4. **Identity & Ownership Propagation:** When acting on behalf of an authenticated user, the client must inject the caller identity into the downstream request header `x-user-id`.
5. **Mandatory Idempotency Keys:** For any mutating financial, payment, or stock reservation operation, the client must transmit an `Idempotency-Key` header with a unique UUIDv4 string.
6. **Defensive Timeout & Resilience:** Every HTTP client must enforce a strict timeout (5 to 10 seconds). Calls must be wrapped in `try-catch` blocks, logging the response status and error body on failure without crashing the host process.
7. **Distributed Tracing Continuity (W3C TraceContext Propagation):** When making inter-service HTTP requests, the client must ensure the W3C `traceparent` header (`00-{traceId}-{spanId}-01`) is preserved across boundaries. While ASP.NET Core `AddHttpClientInstrumentation()` automatically propagates `Activity.Current` during active HTTP request contexts, background workers/queues lose this context. For background queues, capture `Activity.Current?.Id` (or `HttpContext.Request.Headers["traceparent"]`) in the payload, and inject `request.Headers.TryAddWithoutValidation("traceparent", payload.TraceParent)` before dispatch.

## 3. Service Port & URL Matrix

| Service | HTTP Port | Configuration Key | Default URL |
| :--- | :---: | :--- | :--- |
| **UserService** | `8001` | `USER_SERVICE_URL` | `http://localhost:8001/` |
| **CatalogService** | `8002` | `CATALOG_SERVICE_URL` | `http://localhost:8002/` |
| **CommerceService** | `8003` | `COMMERCE_SERVICE_URL` | `http://localhost:8003/` |
| **LogService** | `8004` | `LOG_SERVICE_URL` | `http://localhost:8004/` |
| **AuctionService** | `8005` | `AUCTION_SERVICE_URL` | `http://localhost:8005/` |
| **FulfillmentService** | `8006` | `FULFILLMENT_SERVICE_URL` | `http://localhost:8006/` |
| **NotificationService** | `8007` | `NOTIFICATION_SERVICE_URL` | `http://localhost:8007/` |
| **WalletService** | `8008` | `WALLET_SERVICE_URL` | `http://localhost:8008/` |
| **CheckHealService** | `8009` | `CHECKHEAL_SERVICE_URL` | `http://localhost:8009/` |

## 4. Step-by-Step Implementation Workflow

### Step 1: Define the Client Interface (Application Layer)
Create `{Caller}.Application/Interfaces/I{Target}Client.cs`.
- The interface must only use primitive types (`Guid`, `string`, `decimal`) or local request/response DTOs owned by the caller.
- Methods must accept a `CancellationToken` defaulting to `default`.

```csharp
namespace Caller.Application.Interfaces;

public interface IWalletClient
{
    Task<bool> CheckoutDirectPaymentAsync(
        Guid orderId,
        string userId,
        decimal amount,
        string? idempotencyKey = null,
        CancellationToken cancellationToken = default);
}
```

### Step 2: Implement the Typed Client (Infrastructure Layer)
Create `{Caller}.Infrastructure/Services/{Target}/{Target}Client.cs`.
- Inject `HttpClient` and `ILogger<{Target}Client>`.
- Build requests via `HttpRequestMessage`.
- Conditionally append `x-user-id` and `Idempotency-Key` headers.
- Handle non-success status codes by reading response details and logging structured warnings.

```csharp
namespace Caller.Infrastructure.Services.Wallet;

public sealed class WalletClient : IWalletClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<WalletClient> _logger;

    public WalletClient(HttpClient httpClient, ILogger<WalletClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<bool> CheckoutDirectPaymentAsync(
        Guid orderId,
        string userId,
        decimal amount,
        string? idempotencyKey = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var payload = new { orderId, userId, amount };
            using var request = new HttpRequestMessage(HttpMethod.Post, "api/v1/wallets/checkout/direct")
            {
                Content = JsonContent.Create(payload)
            };

            if (!string.IsNullOrWhiteSpace(userId))
            {
                request.Headers.TryAddWithoutValidation("x-user-id", userId);
            }

            if (!string.IsNullOrWhiteSpace(idempotencyKey))
            {
                request.Headers.TryAddWithoutValidation("Idempotency-Key", idempotencyKey);
            }

            var response = await _httpClient.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                return true;
            }

            var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning("[REST Client] Target call failed. Status: {StatusCode}, Body: {Details}",
                response.StatusCode, errorBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "[REST Client] Connection error during invocation.");
            return false;
        }
    }
}
```

### Step 3: Register in Dependency Injection (Infrastructure Layer)
In `{Caller}.Infrastructure/DependencyInjection.cs`:
- Resolve the target base URL using environment variable first, configuration section second, localhost fallback last.
- Register via `services.AddHttpClient<I{Target}Client, {Target}Client>(...)`.
- Set `BaseAddress` and a strict `Timeout` (10 seconds maximum).

```csharp
var walletBaseUrl = Environment.GetEnvironmentVariable("WALLET_SERVICE_URL")
    ?? configuration["WALLET_SERVICE_URL"]
    ?? configuration["Services:Wallet:BaseUrl"]
    ?? "http://localhost:8008/";

services.AddHttpClient<IWalletClient, WalletClient>(client =>
{
    client.BaseAddress = new Uri(walletBaseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(10);
});
```

### Step 4: Inject into Application Feature Service
Inject `I{Target}Client` into `{Caller}.Application/Services/{Feature}/{Feature}Service.cs`. Handle both success and failure cases gracefully.

## 5. Verification Checklist

- [ ] Interface located in `{Caller}.Application/Interfaces/`.
- [ ] Implementation located in `{Caller}.Infrastructure/Services/{Target}/`.
- [ ] Registered via `AddHttpClient` with strict timeout ($\le 10$s).
- [ ] No project references or database links to the callee service.
- [ ] Outward mutating calls transmit `Idempotency-Key`.
- [ ] User actions transmit `x-user-id`.
- [ ] Environment variable added to `.env.example` and `docker-compose.yml`.
