# Chuyen De 01: Bao Mat Bien, Anti-Spoofing & Lan Truyen Danh Tinh (Edge Security & Identity Architecture)

Chuyen de nay huong dan ve kien truc bao mat bien (Zero-Trust Edge Security), co che chan dung gia mao header chu dong (`ClientContextMiddleware`), quy trinh giai ma token JWT va lan truyen danh tinh tin cay xuong backend microservices thong qua `IdentityPropagationTransform`.

---

## 1. Xac Thuc Bien (Edge Authentication) vs Phan Quyen Dich Vu (Service Authorization)

Kien truc bao mat cua Nexus phan dinh ranh gioi trach nhiem ro rang:
- **Trach nhiem cua Gateway:** Xac thuc danh tinh tai bien (Edge Authentication). Gateway giai ma chu ky so cua JWT Bearer Token, kiem tra thoi han hieu luc, bao ve chong tan cong gia mao header tu ben ngoai, va kiem tra tho vai tro Admin/Staff tren cac route quan tri he thong.
- **Trach nhiem cua Backend Microservices:** Phan quyen chi tiet va bao ve quyen so huu tai nguyen (Fine-Grained Authorization & Resource Ownership). Tung microservice doc danh tinh do Gateway truyen xuong de kiem tra quyen so huu tren ban ghi CSDL (vi du: User A chi duoc sua don hang cua User A, khong duoc sua don hang cua User B).

---

## 2. Xac Thuc Chu Ky JWT Bearer Tai Bien

Trong file `Gateway/Program.cs`, Gateway thiet lap cau hinh xac thuc JWT chat che:

```csharp
var key = Encoding.UTF8.GetBytes(signature);
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = jwtConfig.GetValue<bool>("RequireHttpsMetadata");
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = !string.IsNullOrWhiteSpace(issuer),
        ValidIssuer = issuer,
        ValidateAudience = !string.IsNullOrWhiteSpace(audience),
        ValidAudience = audience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero // Không cho phép độ trễ lệch giờ quá hạn
    };
});
```

### Diem kien truc dac biet:
- **`ClockSkew = TimeSpan.Zero`:** Mac dinh, ASP.NET Core cho phep do lech gio toi 5 phut sau khi token het han. Gateway cua Nexus dat `ClockSkew` ve `0` de dam bao token het han la bi tu choi ngay lap tuc o mili-giay tiep theo, ngan ngua nguy co tan cong su dung token het han.

---

## 3. Co Che Active Anti-Header-Spoofing (`ClientContextMiddleware`)

Trong mo hinh Microservices su dung HTTP header de truyen danh tinh (`x-user-id`, `x-user-roles`), moi de doa lon nhat la **tan cong gia mao Header (Header Spoofing Attack)**:
- Tin tac tu gui request kem header `x-user-id: 00000000-0000-0000-0000-000000000001` (ID cua Admin) hoac `x-user-roles: admin`.
- Neu Gateway vo tinh chuyen tiep nguyen ven request nay xuong backend, backend se bi danh lua rang day la yeu cau tu mot quan tri vien toi cao.

### Chot chan phong thu chu dong trong `ClientContextMiddleware.cs`:

```csharp
private static readonly string[] ForbiddenSpoofedHeaders = new[]
{
    "x-user-id",
    "x-user-email",
    "x-user-roles",
    "x-user-role",
    "x-user-permissions",
    "x-user-permission",
    "x-internal-service-key"
};

public async Task InvokeAsync(HttpContext context)
{
    // Kiểm tra từng header nhạy cảm
    foreach (var headerKey in ForbiddenSpoofedHeaders)
    {
        if (context.Request.Headers.ContainsKey(headerKey))
        {
            _logger?.LogWarning(
                "[SECURITY VIOLATION] Blocked spoofed header '{HeaderKey}' from Client IP: '{ClientIp}', TraceId: '{TraceId}'",
                headerKey, clientIp, traceId);

            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/problem+json";

            var errorResponse = new ApiErrorResponse
            {
                Type = "https://tools.ietf.org/html/rfc9110#section-15.5.4",
                Title = "Forbidden",
                Status = StatusCodes.Status403Forbidden,
                ErrorCode = "FORBIDDEN_HEADER_SPOOFING",
                Detail = "Security violation: Untrusted identity header detected in external request.",
                TraceId = traceId,
                Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            };

            await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse));
            return; // Ngắt pipeline ngay lập tức
        }
    }

    await _next(context);
}
```

### Nguyen ly Zero-Tolerance:
Gateway khong am tham bo (strip) header ma **ngat pipeline ngay lap tuc va tra ve loi 403 Forbidden**. Dieu nay giup doi ngu an ninh mang phat hien som cac no luc tham do va ghi lai dia chi IP cua ke tan cong.

---

## 4. Lan Truyen Danh Tinh Tin Cay (`IdentityPropagationTransform`)

Sau khi request vuot qua bo loc anti-spoofing va duoc ASP.NET Core giai ma chu ky JWT thanh cong, YARP se goi den `IdentityPropagationTransform` ngay truoc khi ban goi tin sang downstream microservices.

File `Gateway/Transforms/IdentityPropagationTransform.cs` thuc hien quy trinh trich xuat va tiêm an toan:

```csharp
context.AddRequestTransform(transformContext =>
{
    var httpContext = transformContext.HttpContext;
    var proxyRequest = transformContext.ProxyRequest;

    // 1. Lan truyền Client IP thực tế
    var clientIp = httpContext.Items[ClientContextMiddleware.ItemKeyClientIp]?.ToString() ?? "127.0.0.1";
    proxyRequest.Headers.Remove("x-client-ip");
    proxyRequest.Headers.TryAddWithoutValidation("x-client-ip", clientIp);

    // 2. Lan truyền Trace Identifier & W3C TraceContext
    var traceId = httpContext.Items[ClientContextMiddleware.ItemKeyTraceId]?.ToString() ?? httpContext.TraceIdentifier;
    proxyRequest.Headers.Remove("x-trace-id");
    proxyRequest.Headers.TryAddWithoutValidation("x-trace-id", traceId);

    if (Activity.Current != null && !string.IsNullOrWhiteSpace(Activity.Current.Id))
    {
        proxyRequest.Headers.Remove("traceparent");
        proxyRequest.Headers.TryAddWithoutValidation("traceparent", Activity.Current.Id);
    }

    // 3. Nếu người dùng đã xác thực, trích xuất Claims từ JWT và tiêm vào Headers
    if (httpContext.User.Identity?.IsAuthenticated == true)
    {
        var user = httpContext.User;

        // Trích xuất UserId
        var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? user.FindFirst("sub")?.Value
            ?? user.FindFirst("id")?.Value;

        if (!string.IsNullOrWhiteSpace(userId))
        {
            proxyRequest.Headers.Remove("x-user-id");
            proxyRequest.Headers.TryAddWithoutValidation("x-user-id", userId);
        }

        // Trích xuất Email
        var email = user.FindFirst(ClaimTypes.Email)?.Value ?? user.FindFirst("email")?.Value;
        if (!string.IsNullOrWhiteSpace(email))
        {
            proxyRequest.Headers.Remove("x-user-email");
            proxyRequest.Headers.TryAddWithoutValidation("x-user-email", email);
        }

        // Trích xuất Roles (chuỗi chữ thường cách nhau dấu phẩy)
        var roles = user.FindAll(ClaimTypes.Role)
            .Concat(user.FindAll("role"))
            .Concat(user.FindAll("roles"))
            .Select(c => c.Value.ToLowerInvariant())
            .Distinct()
            .ToList();

        if (roles.Count > 0)
        {
            proxyRequest.Headers.Remove("x-user-roles");
            proxyRequest.Headers.TryAddWithoutValidation("x-user-roles", string.Join(",", roles));
        }

        // Trích xuất Permissions (chuỗi chữ hoa cách nhau dấu phẩy)
        var permissions = user.FindAll("permission")
            .Concat(user.FindAll("permissions"))
            .Select(c => c.Value.ToUpperInvariant())
            .Distinct()
            .ToList();

        if (permissions.Count > 0)
        {
            proxyRequest.Headers.Remove("x-user-permissions");
            proxyRequest.Headers.TryAddWithoutValidation("x-user-permissions", string.Join(",", permissions));
        }
    }

    return ValueTask.CompletedTask;
});
```

### Danh sach cac Header downstream tin cay:
1. `x-user-id`: Dinh danh nguoi dung (GUID).
2. `x-user-roles`: Danh sach vai tro (`buyer,seller,admin...`).
3. `x-user-email`: Email nguoi dung.
4. `x-user-permissions`: Quyen han chi tiet (`BAN_USER,CREATE_PRODUCT...`).
5. `x-client-ip`: IP goc cua client de phuc vu ghi nhat ky kiem toan tai CSDL downstream.
6. `x-trace-id` & `traceparent`: Ket noi luong distributed trace xuyen suot giua Gateway va cac microservices.

---

## 5. Chot Chan Phan Quyen Admin Tai Bien (`AdminAuthorizationGuardMiddleware`)

Ngoai viec backend tu kiem tra quyen, Gateway bo tri mot chot chan so cap cho toan bo cac route bat dau bang `/api/v1/admin/**`:

```csharp
// src/Services/Gateway/Gateway/Middlewares/Features/AdminAuthorizationGuardMiddleware.cs
public async Task InvokeAsync(HttpContext context)
{
    if (context.Request.Path.StartsWithSegments("/api/v1/admin"))
    {
        var user = context.User;

        // 1. Phải đăng nhập
        if (user.Identity?.IsAuthenticated != true)
        {
            await WriteErrorAsync(context, StatusCodes.Status401Unauthorized, "UNAUTHORIZED", "Authentication is required to access administrative endpoints.");
            return;
        }

        // 2. Phải có ít nhất một trong các vai trò quản trị
        var hasAdminRole = user.FindAll(ClaimTypes.Role)
            .Concat(user.FindAll("role"))
            .Concat(user.FindAll("roles"))
            .Select(c => c.Value.ToLowerInvariant())
            .Any(r => r == "admin" || r == "staff" || r == "administrator");

        if (!hasAdminRole)
        {
            await WriteErrorAsync(context, StatusCodes.Status403Forbidden, "FORBIDDEN", "You do not have permission to access administrative endpoints.");
            return;
        }
    }

    await _next(context);
}
```

Nho co chot chan nay, moi yeu cau khong hop le vao khu vuc quan tri se bi chan ngay tai bien ma khong lam tieu ton bang thong mang hay tai nguyen xu ly cua cum backend microservices phia sau.
