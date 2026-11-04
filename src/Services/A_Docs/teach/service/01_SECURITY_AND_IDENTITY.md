# Chuyen De 01: Bao Mat & Quan Ly Danh Tinh (Security & Identity Architecture)

Chuyen de nay phan tich co che xac thuc Zero-Trust tai bien (Edge Authentication), quy trinh lan truyen danh tinh tin cay qua HTTP Headers, va cach thuc cac microservice backend (UserService lam mau) phan quyen ma khong can den he thong ASP.NET Identity co cong kenh.

---

## 1. Mo Hinh Zero-Trust Edge Authentication

Trong kien truc Nexus, he thong ap dung nguyen ly **Xac thuc tap trung tai Bien (Edge Authentication)** va **Phan quyen chi tiet tai Dich vu (Fine-Grained Service Authorization)**:

```text
[ External Client ]
        │ Gửi JWT Bearer Token
        ▼
[ Edge API Gateway (Port 8080) ]
        │ 1. Chống giả mạo: Kiểm tra và chặn đứng nếu request ngoài chứa x-user-id,...
        │ 2. Giải mã và kiểm tra chữ ký số của JWT Bearer Token
        │ 3. Bóc tách claims (sub, email, role, permission)
        │ 4. YARP tiêm an toàn vào downstream headers:
        │    - x-user-id: GUID của người dùng
        │    - x-user-roles: buyer, seller, admin...
        │    - x-user-email: email người dùng
        │    - x-user-permissions: CREATE_PRODUCT, BAN_USER...
        │    - x-client-ip: địa chỉ IP thực của người dùng cuối
        │    - x-trace-id: mã trace định danh giao dịch phân tán
        ▼ (Mạng nội bộ an toàn)
[ Backend Microservice: UserService (Port 8001) ]
```

### Nguyen ly Active Anti-Header-Spoofing
De ngan chan tin tac ben ngoai tu y gui header `x-user-id` gia mao nham chiem quyen tai khoan khac:
1. `ClientContextMiddleware` tai API Gateway chu dong kiem tra toan bo request ben ngoai.
2. Neu phat hien bat ky header nao trong danh sach: `x-user-id`, `x-user-roles`, `x-user-role`, `x-user-email`, `x-user-permissions`, `x-user-permission`, `x-internal-service-key`, Gateway se **ngat pipeline ngay lap tuc**, ghi log canh bao IP va tra ve HTTP `403 Forbidden` (`FORBIDDEN_HEADER_SPOOFING`).
3. Chi co cac header do chinh API Gateway tu trich xuat tu chu ky JWT hop le moi duoc chuyen tiep toi backend microservices.

---

## 2. Co Che Tiep Nhan Danh Tinh Tai Backend (`UserContextMiddleware`)

Khi goi tin den `UserService`, lop `UserContextMiddleware` se chuyen hoa cac headers tin cay tu Gateway thanh doi tuong `ClaimsPrincipal` chuan cua .NET:

```csharp
// src/Services/User/User.Api/Middleware/UserContextMiddleware.cs
public async Task InvokeAsync(HttpContext context)
{
    if (context.Request.Headers.TryGetValue("x-user-id", out var userIdHeader) &&
        Guid.TryParse(userIdHeader.ToString(), out var userId))
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new("sub", userId.ToString()),
            new("userId", userId.ToString())
        };

        // Bóc tách roles từ chuỗi ngăn cách bằng dấu phẩy
        if (context.Request.Headers.TryGetValue("x-user-roles", out var rolesHeader) &&
            !string.IsNullOrWhiteSpace(rolesHeader.ToString()))
        {
            var roles = rolesHeader.ToString()
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            foreach (var role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role.ToLowerInvariant()));
                claims.Add(new Claim("role", role.ToLowerInvariant()));
            }
        }

        // Bóc tách email và permissions...
        var identity = new ClaimsIdentity(claims, "NexusGatewayAuth");
        context.User = new ClaimsPrincipal(identity);
    }

    await _next(context);
}
```

### Loi ich kien truc:
- Khong can giai ma lai JWT: UserService khong phai ton CPU de parse token va kiem tra chu ky mot lan nua.
- Tuong thich hoan hao voi he sinh thai ASP.NET: `HttpContext.User` van giu day du cac Claim tieu chuan, giup lap trinh vien dung duoc cac ham co san nhu `User.IsInRole(...)`.

---

## 3. Phan Quyen Nhe Nhanh Qua `RequireRoleAttribute`

He thong khong su dung ASP.NET Core Identity (von di kem voi Entity Framework IdentityDbContext phuc tap va nhieu bang phu khong can thiet). Thay vao do, UserService su dung mot Filter tuy bien sieu nhe ke thua `IAuthorizationFilter`:

```csharp
// src/Services/User/User.Api/Filters/RequireRoleAttribute.cs
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
public sealed class RequireRoleAttribute : Attribute, IAuthorizationFilter
{
    private readonly string[] _allowedRoles;

    public RequireRoleAttribute(params string[] allowedRoles)
    {
        _allowedRoles = allowedRoles ?? Array.Empty<string>();
    }

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var httpContext = context.HttpContext;
        var userId = httpContext.GetUserId();

        // 1. Kiểm tra xác thực (Authentication Check)
        if (userId == null || userId == Guid.Empty)
        {
            context.Result = new ObjectResult(new
            {
                type = "https://tools.ietf.org/html/rfc9110#section-15.5.2",
                title = "Unauthorized",
                status = StatusCodes.Status401Unauthorized,
                errorCode = "UNAUTHORIZED",
                detail = "Authentication is required to access this resource.",
                traceId = httpContext.GetTraceId()
            })
            {
                StatusCode = StatusCodes.Status401Unauthorized,
                ContentTypes = { "application/problem+json" }
            };
            return;
        }

        // 2. Kiểm tra vai trò (Role-Based Authorization)
        if (_allowedRoles.Length > 0)
        {
            var userRoles = httpContext.GetUserRoles();
            var isAuthorized = _allowedRoles.Any(role =>
            {
                var target = role.Trim().ToLowerInvariant();
                return userRoles.Contains(target, StringComparer.OrdinalIgnoreCase);
            });

            if (!isAuthorized)
            {
                context.Result = new ObjectResult(new
                {
                    type = "https://tools.ietf.org/html/rfc9110#section-15.5.4",
                    title = "Forbidden",
                    status = StatusCodes.Status403Forbidden,
                    errorCode = "FORBIDDEN",
                    detail = $"Access denied. Required roles: [{string.Join(", ", _allowedRoles)}].",
                    traceId = httpContext.GetTraceId()
                })
                {
                    StatusCode = StatusCodes.Status403Forbidden,
                    ContentTypes = { "application/problem+json" }
                };
            }
        }
    }
}
```

### Cach su dung tren Controller:
- `[RequireRole]` khong tham so: Yeu cau bat ky nguoi dung nao da xac thuc (HTTP 401 neu chua dang nhap).
- `[RequireRole("admin", "staff")]`: Yeu cau nguoi dung phai co vai tro `admin` hoac `staff` (HTTP 403 neu khong du quyen).

---

## 4. Bao Ve Mat Khau Bang BCrypt Co Salt

Moi mat khau nguoi dung khi dang ky hoac doi mat khau deu duoc bam thong qua thu vien `BCrypt.Net-Next 4.0.3`:

- **Chi phi tinh toan (Work Factor 11):** Thuat toan BCrypt co chu ky tinh toan tre co chu dich (khoang 100ms - 200ms tren server), lam cham hoan toan cac no luc tan cong brute-force offline.
- **Tu dong sinh Salt ngau nhien:** Moi mat khau bam co 1 chuoi salt 128-bit rieng biet duoc nhung thang vao chuoi hash ket qua (`$2a$11$...`). Cung mot mat khau cua 2 nguoi dung khac nhau se sinh ra 2 hash hoan toan khac nhau, vo hieu hoa tan cong Rainbow Table.
- **So sanh an toan:** Kiem tra dang nhap su dung `BCrypt.Net.BCrypt.Verify(password, user.PasswordHash)`.
- **Ly do thiet ke thuc dung (Why no IPasswordHasher abstraction?):**
  Trong du an, `AuthService` tai tang Application goi truc tiep `BCrypt.Net.BCrypt.HashPassword` va `Verify` thay vi tao them mot interface trung gian `IPasswordHasher`. Ly do: thu vien `BCrypt.Net-Next` la mot thu vien utility thuan C#, khong co side-effects I/O, khong phu thuoc phan cung hay he dieu hanh. Viec goi truc tiep giup code don gian, de test (co the test verify hash truc tiep trong Unit Test) va loai bo boilerplate abstraction khong can thiet.

---

## 5. Sinh Chuoi JWT Bearer Token (`JwtTokenGenerator`)

Lop `JwtTokenGenerator` tai tang `User.Infrastructure` chiu trach nhiem dong goi thong tin nguoi dung thanh chuoi JWT:
- **Thuat toan ky:** HMAC-SHA256 (`SecurityAlgorithms.HmacSha256`).
- **Khoa bi mat:** Doc tu bien moi truong `JWT_SIGNATURE` (bat buoc co do dai toi thieu 32 bytes / 256 bits).
- **Thoi gian song (TTL):** Mac dinh 60 phut (`Jwt:ExpirationInMinutes`), ket hop voi `RefreshToken` luu trong PostgreSQL co thoi han 7 - 30 ngay de thuc hien co che lam moi phien lam viec.
- **Claims chuan:**
  - `sub` / `userId` / `id`: GUID nguoi dung.
  - `email`: Dia chi email.
  - `name`: Ho va ten ghep.
  - `jti`: GUID duy nhat cho moi token (phuc vu chong replay attack).
  - `role`: Mang cac vai tro nguoi dung nam giu.
  - `permission`: Mang cac quyen han he thong duoc cap.

---

## 6. Quy Tac Bao Ve Quyen So Huu Tai Nguyen (Resource Ownership)

Mot lo hong pho bien trong kien truc REST la loi **IDOR (Insecure Direct Object Reference)**, khi nguoi dung A co the sua du lieu cua nguoi dung B bang cach thay doi tham so `userId` tren URL.

Tai UserService, quy tac kien truc bat bien quy dinh:
1. **Khong tin tuong tham so tu Client:** Tuyet doi khong dung tham so `userId` tu query hay route de dai dien cho nguoi dang thuc hien.
2. **Lay `currentUserId` tu HttpContext:** Luon dung `HttpContext.GetUserId()` de xac dinh nguoi dang thao tac.
3. **So sanh so huu:**
   - Neu truy cap tai nguyen ca nhan: Endpoint `/api/v1/me` chi doc tu `currentUserId`.
   - Neu truy cap theo `userId` tren route: Phai kiem tra `if (currentUserId != targetUserId && !httpContext.IsAdmin()) return Forbid();`.
