# Chuyen De 05: Tich Hop Ngoai & Giao Tiep Lien Dich Vu (Integrations & Inter-Service Architecture)

Chuyen de nay phan tich co che giao tiep lien vi dich vu bang Typed REST HttpClients, bo xu ly tu dong lan truyen danh tinh (`IdentityPropagationHandler`), co che tu phuc hoi cua Redis OTP, va ky thuat chuan hoa chuoi ket noi Cloud PostgreSQL.

---

## 1. 100% Giao Tiep REST Dong Bo (Bai Bo Message Broker)

Trong he thong Nexus, toan bo kien truc cu su dung RabbitMQ, MassTransit, Saga State Machine va bang Outbox/Inbox da duoc **bai bo hoan toan** nham giam thieu su phuc tap van hanh, loai bo do tre bat dong bo khong can thiet va tranh ton that du lieu do loi dong bo transaction.

Thay vao do, cac vi dich vu giao tiep truc tiep voi nhau thong qua **Typed HTTP REST Clients** duoc quan ly boi `IHttpClientFactory`:

```text
[ UserService ]
      │
      ├── IEmailNotificationClient  --> [ NotificationService (Port 8007) ] (Gửi Email OTP)
      ├── IFulfillmentServiceClient --> [ FulfillmentService  (Port 8006) ] (Tạo kho hàng Seller)
      └── IWalletServiceClient      --> [ WalletService       (Port 8008) ] (Khởi tạo ví điện tử)
```

### Nguyen ly tach biet Interface va Implementation
1. **Tang Application chi giu Interface:**
   - File `User.Application/Interfaces/IEmailNotificationClient.cs` chi khai bao ham:
     `Task<bool> SendOtpEmailAsync(string email, string fullName, string otpCode, ...);`
   - Tang Application hoan toan khong biet du lieu duoc gui qua REST, gRPC hay bat ky thu vien nao.
2. **Tang Infrastructure thuc thi HttpClient:**
   - File `User.Infrastructure/Services/Notification/EmailNotificationClient.cs` su dung `HttpClient` de goi `PostAsJsonAsync("api/v1/notifications/email/otp", payload)`.

### Dang ky trong `User.Infrastructure/DependencyInjection.cs`:
```csharp
services.AddHttpClient<IEmailNotificationClient, EmailNotificationClient>(client =>
{
    client.BaseAddress = new Uri(notificationBaseUrl.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(10); // Hạn mức timeout 10 giây
}).AddHttpMessageHandler<Services.Common.IdentityPropagationHandler>();
```

### Xu ly loi mem deo (Graceful Fallback):
Khi vi dich vu downstream bi offline hoac gap loi mang, Typed Client khong nem ra Unhandled Exception gay crash luong nghiep vu chinh. Client se bat loi, ghi log warning va tra ve `false`. Tinh nang van co the tiep tuc hoac dua ra thong bao phu hop cho nguoi dung.

---

## 2. Co Che Lan Truyen Danh Tinh Tu Dong (`IdentityPropagationHandler`)

Khi nguoi dung gui mot request da xac thuc toi `UserService`, va `UserService` can goi tiep sang `FulfillmentService` hoac `NotificationService`, lam the nao de vi dich vu tiep theo biet duoc ai la nguoi khoi xuong request ban dau?

### Giai phap: DelegatingHandler tu dong
Lop `IdentityPropagationHandler` ke thua `DelegatingHandler` trong HTTP Pipeline cua .NET, duoc gan vao moi Typed HttpClient:

```csharp
// src/Services/User/User.Infrastructure/Services/Common/IdentityPropagationHandler.cs
public sealed class IdentityPropagationHandler : DelegatingHandler
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public IdentityPropagationHandler(IHttpContextAccessor httpContextAccessor, ...)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var httpContext = _httpContextAccessor.HttpContext;
        if (httpContext != null)
        {
            // 1. Lan truyền x-user-id
            if (!request.Headers.Contains("x-user-id"))
            {
                var userId = httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                    ?? httpContext.User.FindFirst("sub")?.Value
                    ?? (httpContext.Request.Headers.TryGetValue("x-user-id", out var hVal) ? hVal.ToString() : null);

                if (!string.IsNullOrWhiteSpace(userId))
                {
                    request.Headers.TryAddWithoutValidation("x-user-id", userId);
                }
            }

            // 2. Lan truyền x-user-roles (chuỗi ngăn cách dấu phẩy, chữ thường)
            if (!request.Headers.Contains("x-user-roles"))
            {
                var roles = httpContext.User.FindAll(ClaimTypes.Role)
                    .Concat(httpContext.User.FindAll("role"))
                    .Select(c => c.Value.ToLowerInvariant())
                    .Distinct()
                    .ToList();
                // ...
            }

            // 3. Lan truyền x-user-email
            if (!request.Headers.Contains("x-user-email"))
            {
                var email = httpContext.User.FindFirst(ClaimTypes.Email)?.Value
                    ?? (httpContext.Request.Headers.TryGetValue("x-user-email", out var hEmail) ? hEmail.ToString() : null);

                if (!string.IsNullOrWhiteSpace(email))
                {
                    request.Headers.TryAddWithoutValidation("x-user-email", email);
                }
            }

            // 4. Lan truyền x-user-permissions (mảng quyền hạn chữ hoa)
            if (!request.Headers.Contains("x-user-permissions"))
            {
                var perms = httpContext.User.FindAll("permission")
                    .Select(c => c.Value.ToUpperInvariant())
                    .Distinct()
                    .ToList();
                // ...
            }

            // 5. Lan truyền x-client-ip (IP thực tế của client bên ngoài)
            if (!request.Headers.Contains("x-client-ip"))
            {
                var clientIp = (httpContext.Request.Headers.TryGetValue("x-client-ip", out var hIp) && !string.IsNullOrWhiteSpace(hIp.ToString()))
                    ? hIp.ToString().Trim()
                    : httpContext.Connection.RemoteIpAddress?.ToString();

                if (!string.IsNullOrWhiteSpace(clientIp))
                {
                    request.Headers.TryAddWithoutValidation("x-client-ip", clientIp);
                }
            }

            // 6. Lan truyền x-trace-id (W3C Distributed TraceId)
            if (!request.Headers.Contains("x-trace-id"))
            {
                var traceId = Activity.Current?.Id ?? httpContext.TraceIdentifier;
                if (!string.IsNullOrWhiteSpace(traceId))
                {
                    request.Headers.TryAddWithoutValidation("x-trace-id", traceId);
                }
            }
        }

        return base.SendAsync(request, cancellationToken);
    }
}
```

### Danh sach 6 headers duoc tu dong lan truyen:
1. `x-user-id`: Dinh danh GUID cua nguoi dung goc.
2. `x-user-roles`: Danh sach vai tro (`buyer,seller,admin...`).
3. `x-user-email`: Email nguoi dung.
4. `x-user-permissions`: Danh sach ma quyen (`CREATE_PRODUCT,BAN_USER...`).
5. `x-client-ip`: Dia chi IP thuc te cua client de downstream service co the ghi audit log chinh xac.
6. `x-trace-id`: Ma trace phan tan de he thong Tempo/Grafana noi lien cac span thanh mot duong trace hoan chinh.

### Loi ich kien truc:
- **Zero Boilerplate:** Lap trinh vien tai tang Service khong can phai truyen thu cong `userId`, `clientIp` hay token vao tung cuoc goi `_httpClient.SendAsync(...)`.
- **Lien mach phan quyen (Identity Continuity):** Downstream service co the kiem tra quyen han cua nguoi dung goc y nhu khi nhan request truc tiep tu Gateway.

---

## 3. Kha Nang Tu Phuc Hoi Cua Redis OTP (In-Memory Fallback Pattern)

Trong quy trinh dang ky va doi mat khau, ma OTP duoc luu tam thoi tren Redis cluster (Port `6379`) voi thoi gian song TTL (Time-to-Live) 5 phut:
- Prefix cach ly: `otp:registration:{email}` hoac `otp:password_reset:{email}`.

### Thach thuc thuc te:
Khi dev local, Redis co the chua duoc bat. Hoac tren Production, Redis cluster co the gap su co ket noi tam thoi trong vai giay. Neu viet code thong thuong, toan bo tinh nang dang ky va quen mat khau se chet hoan toan.

### Thiet ke kien cuong (Resilient Fallback) trong `RedisOtpService`:

```csharp
// src/Services/User/User.Infrastructure/Services/Redis/RedisOtpService.cs
public sealed class RedisOtpService : IRedisOtpService
{
    private readonly IConnectionMultiplexer? _redis;
    private readonly ConcurrentDictionary<string, OtpEntry> _inMemoryFallback = new(StringComparer.OrdinalIgnoreCase);

    public async Task SaveOtpAsync(string email, string code, TimeSpan validityDuration, ...)
    {
        var key = FormatKey(email, purpose);
        var entry = new OtpEntry { Code = code, Email = email, ExpiresAt = ... };

        // 1. Nếu Redis đang hoạt động bình thường: lưu vào Redis
        if (_redis != null && _redis.IsConnected)
        {
            var db = _redis.GetDatabase();
            await db.StringSetAsync(key, JsonSerializer.Serialize(entry), retentionDuration);
            _logger.LogInformation("[REDIS] Stored OTP in Redis for '{Email}'", email);
        }
        else
        {
            // 2. Nếu Redis Offline: tự động fallback sang ConcurrentDictionary trong RAM
            _inMemoryFallback[key] = entry;
            _logger.LogWarning("[REDIS OFFLINE - IN-MEMORY FALLBACK] Stored OTP in memory for '{Email}'", email);
        }
    }
}
```

- **De dang chay local:** Lap trinh vien co the clone source code ve va test ngay tinh nang Auth/OTP ma khong nhat thiet phai khoi dong container Redis.
- **Tu dong phuc hoi:** Khi ket noi Redis tro lai binh thuong, service se tu dong uu tien ghi doc tu Redis ma khong can khoi dong lai ung dung.

---

## 4. Chuan Hoa Chuoi Ket Noi Cloud PostgreSQL (URI Parsing)

Cac nen tang Cloud Database hien dai nhu Neon, Supabase, Render thuong cung cap chuoi ket noi duoi dang URI:
`postgres://user:password@ep-sample-123.ap-southeast-1.aws.neon.tech:5432/usermanagement_db?sslmode=require`

Tuy nhien, thu vien `Npgsql` cua .NET doi hoi chuoi ket noi dinh dang Key-Value truyen thong:
`Host=...;Port=...;Database=...;Username=...;Password=...;SSL Mode=Require;Trust Server Certificate=true`

### Ham tu dong chuan hoa trong `DependencyInjection.cs`:

```csharp
private static string NormalizeConnectionString(string? connStr)
{
    if (string.IsNullOrWhiteSpace(connStr)) return string.Empty;
    if (connStr.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) || 
        connStr.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        var uri = new Uri(connStr);
        var userInfo = uri.UserInfo.Split(':');
        var user = userInfo.Length > 0 ? Uri.UnescapeDataString(userInfo[0]) : "";
        var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
        var host = uri.Host;
        var port = uri.Port > 0 ? uri.Port : 5432;
        var db = uri.AbsolutePath.TrimStart('/');
        return $"Host={host};Port={port};Database={db};Username={user};Password={pass};SSL Mode=Require;Trust Server Certificate=true";
    }
    return connStr;
}
```

Nho co ham nay, service co the nhan linh hoat bat ky dinh dang connection string nao tu file `.env`, Kubernetes Secret hay Docker Compose ma khong bao gio bi loi parse.
