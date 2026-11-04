# Chuyen De 04: Bop Tan Suat Redis & Tinh Idempotency (Rate Limiting & Idempotency Architecture)

Chuyen de nay huong dan chi tiet ve co che gioi han tan suat goi phan tan qua Redis (`SensitiveRateLimitMiddleware`), ky thuat tu phuc hoi qua bo nho cuc bo (In-Memory Fallback), va co che tham dinh tinh bat bien idempotency (`IdempotencyGuardMiddleware`).

---

## 1. Bop Tan Suat Phan Tan Qua Redis (`SensitiveRateLimitMiddleware`)

Cac endpoint nhu gui lai OTP, xac thuc OTP, dang ky va dang nhap la muc tieu hang dau cua cac cuoc tan cong DoS, brute-force do mat khau hoac spam SMS/Email gay thiet hai tai chinh.

Do he thong Gateway co the duoc trien khai thanh nhieu ban sao (multiple instances/replicas) chay song song sau Load Balancer, viec chi dem request trong bo nho RAM cua tung container la khong du. Gateway su dung **Redis tap trung (Port 6379)** lam bo dem phan tan.

### Thuat toan Fixed-Window voi bo dem nguyen tu tren Redis

```csharp
// src/Services/Gateway/Gateway/Middlewares/Features/SensitiveRateLimitMiddleware.cs
public sealed class SensitiveRateLimitMiddleware
{
    public record RateLimitRule(int MaxRequests, int WindowSeconds);

    private static readonly Dictionary<string, RateLimitRule> SensitiveRules = new(StringComparer.OrdinalIgnoreCase)
    {
        { "POST:/api/v1/auth/otp/resend", new RateLimitRule(MaxRequests: 3, WindowSeconds: 60) },   // Tối đa 3 lần / 1 phút
        { "POST:/api/v1/auth/otp/verify", new RateLimitRule(MaxRequests: 5, WindowSeconds: 60) },   // Tối đa 5 lần / 1 phút
        { "POST:/api/v1/auth/register",   new RateLimitRule(MaxRequests: 5, WindowSeconds: 300) },  // Tối đa 5 lần / 5 phút
        { "POST:/api/v1/auth/login",      new RateLimitRule(MaxRequests: 10, WindowSeconds: 60) }   // Tối đa 10 lần / 1 phút
    };
```

### Quy trinh dem nguyen tu (`StringIncrementAsync`):
1. **Xac dinh Cua so Thoi gian (Window Calculation):**
   `var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();`
   `var currentWindow = now / rule.WindowSeconds;`
2. **Tao khoa Redis duy nhat:**
   `var redisKey = $"nexus:gateway:rate:strict:{routeKey}:{clientIp}:{currentWindow}";`
3. **Tang bo dem nguyen tu (`INCR`):**
   `currentCount = await db.StringIncrementAsync(redisKey);`
   Neu la request dau tien trong cua so (`currentCount == 1`), dat thoi gian het han tu dong cho khoa:
   `await db.KeyExpireAsync(redisKey, TimeSpan.FromSeconds(rule.WindowSeconds + 2));`

---

## 2. Phan Hoi Khi Vuot Nguong (HTTP 429 Too Many Requests)

Khi so luot goi vuot qua gioi han cho phep (`currentCount > rule.MaxRequests`), Gateway ngat pipeline ngay lap tuc va tra ve loi chuan RFC 9110:

```csharp
var remainingSeconds = rule.WindowSeconds - (now % rule.WindowSeconds);

context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
context.Response.ContentType = "application/problem+json";
context.Response.Headers.RetryAfter = Math.Max(1, remainingSeconds).ToString(); // Báo cho client số giây cần đợi

var errorResponse = new ApiErrorResponse
{
    Type = "https://tools.ietf.org/html/rfc9110#section-15.5.21",
    Title = "Too many requests",
    Status = StatusCodes.Status429TooManyRequests,
    ErrorCode = "RATE_LIMIT_EXCEEDED",
    Detail = "Too many requests. Please slow down and try again later.",
    TraceId = traceId,
    Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
};

await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse));
```

### Diem kien truc dac biet: Header `Retry-After`
Gateway tinh toan chinh xac so giay con lai cua cua so hien tai (`rule.WindowSeconds - (now % rule.WindowSeconds)`) va tra ve qua header `Retry-After`. Frontend co the doc header nay de hien thi bo dem nguoc tren giao dien nguoi dung (vi du: "Vui long thu lai sau 42 giay").

---

## 3. Co Che Tu Phuc Hoi Khi Redis Offline (In-Memory Fallback)

Neu Redis gap su co mat mang hoac chua duoc khoi dong o may dev cuc bo, kien truc Gateway ap dung nguyen ly **Kien cuong chiu loi (Fault Tolerance)**:

```csharp
private static readonly ConcurrentDictionary<string, (long Count, long Window)> MemoryStore = new();

// Trong InvokeAsync:
if (redis != null && redis.IsConnected)
{
    try
    {
        // Thử ghi nhận trên Redis...
    }
    catch (Exception ex)
    {
        _logger.LogWarning(ex, "Redis rate limiting failed, falling back to in-memory tracking.");
        currentCount = IncrementInMemory(routeKey, clientIp, currentWindow);
    }
}
else
{
    currentCount = IncrementInMemory(routeKey, clientIp, currentWindow);
}
```

Nho co `ConcurrentDictionary`, Gateway khong bao gio bi crash vi loi ket noi Redis, dong thoi van duy tri duoc kha nang bao ve tren tung instance doc lap.

---

## 4. Kiem Soat Tinh Idempotency (`IdempotencyGuardMiddleware`)

Trong thuong mai dien tu va he thong thanh toan, mang chap chon co the khien client bam nut "Thanh toan" hoac "Tao don hang" 2 lan lien tiep do khong nhan duoc phan hoi cua request dau tien.

De bao ve he thong khoi viec tao trung lap ban ghi, Gateway ap dung chot chan `IdempotencyGuardMiddleware`:

```csharp
// src/Services/Gateway/Gateway/Middlewares/Features/IdempotencyGuardMiddleware.cs
public async Task InvokeAsync(HttpContext context)
{
    // Chỉ kiểm tra các phương thức thay đổi trạng thái
    if (HttpMethods.IsPost(context.Request.Method) ||
        HttpMethods.IsPut(context.Request.Method) ||
        HttpMethods.IsPatch(context.Request.Method))
    {
        if (context.Request.Headers.TryGetValue("Idempotency-Key", out var rawKey))
        {
            var keyValue = rawKey.ToString().Trim();

            // Thẩm định tính hợp lệ: Không được rỗng và không dài quá 128 ký tự
            if (string.IsNullOrWhiteSpace(keyValue) || keyValue.Length > 128)
            {
                context.Response.StatusCode = StatusCodes.Status400BadRequest;
                context.Response.ContentType = "application/problem+json";

                var errorResponse = new ApiErrorResponse
                {
                    Type = "https://tools.ietf.org/html/rfc9110#section-15.5.1",
                    Title = "Validation error",
                    Status = StatusCodes.Status400BadRequest,
                    ErrorCode = "VAL_INVALID_INPUT",
                    Detail = "Idempotency-Key header value is invalid or exceeds maximum length.",
                    TraceId = Activity.Current?.Id ?? context.TraceIdentifier,
                    Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
                };

                await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse));
                return;
            }

            // Lưu vào context.Items để YARP Transform chuyển tiếp an toàn xuống downstream
            context.Items["Idempotency-Key"] = keyValue;
        }
    }

    await _next(context);
}
```

### Nguyen ly phoi hop voi `IdentityPropagationTransform`:
Sau khi `IdempotencyGuardMiddleware` tham dinh header hop le, `IdentityPropagationTransform` se tu dong chuyen tiep header `Idempotency-Key` nay xuong backend microservices (nhu `WalletService` hay `CommerceService`). Backend service se su dung khoa nay de thuc hien kiem tra duplicate transaction trong CSDL.
