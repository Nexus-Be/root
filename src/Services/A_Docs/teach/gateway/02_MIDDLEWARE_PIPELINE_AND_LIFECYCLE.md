# Chuyen De 02: Pipeline 9 Tang & Vong Doi Request (Middleware Pipeline & Lifecycle)

Chuyen de nay giai thich ve thu tu thuc thi cua 9 lop Middleware trong `Gateway/Program.cs`, co che bat ngoai le toan cuc theo chuan RFC 9110 (`GlobalExceptionMiddleware`), cac header bao mat duoc tu dong tiem vao phan hoi, va quy che ve cac tuyen duong noi bo (Internal Routes).

---

## 1. Thu Tu 9 Tang Middleware Trong `Gateway/Program.cs`

Moi yeu cau HTTP khi gui toi cổng `8080` se phai di xuyen qua dung 9 tang Middleware duoc sap xep co chu dich truoc khi duoc chuyen tiep sang YARP Reverse Proxy:

```csharp
// src/Services/Gateway/Gateway/Program.cs
// =========================================================================
// 7. Middleware Pipeline Ordering (Thứ tự thực thi bất biến)
// =========================================================================
app.UseMiddleware<GlobalExceptionMiddleware>();       // Tầng 1: Bắt mọi ngoại lệ unhandled
app.UseMiddleware<ClientContextMiddleware>();         // Tầng 2: Gán TraceId, ClientIp & Chống giả mạo Header
app.UseCors("AllowFrontend");                         // Tầng 3: Kiểm soát chia sẻ tài nguyên nguồn gốc chéo
app.UseGatewaySwagger();                              // Tầng 4: Phục vụ tài liệu OpenAPI tổng hợp

app.UseAuthentication();                              // Tầng 5: Giải mã JWT Bearer Token
app.UseAuthorization();                               // Tầng 6: Khởi tạo bối cảnh ClaimsPrincipal

app.UseMiddleware<SensitiveRateLimitMiddleware>();     // Tầng 7: Bóp tần suất nghiêm ngặt qua Redis
app.UseMiddleware<AdminAuthorizationGuardMiddleware>(); // Tầng 8: Chốt chặn bảo vệ tuyến /api/v1/admin/**
app.UseMiddleware<IdempotencyGuardMiddleware>();       // Tầng 9A: Thẩm định định dạng Idempotency-Key
app.UseMiddleware<ResponseEnvelopeMiddleware>();       // Tầng 9B: Đệm stream và tự động bọc ApiResponse<T>

// Endpoint kết thúc
app.MapGatewaySwaggerProxies();
app.MapReverseProxy();                                // YARP Reverse Proxy Dispatcher
```

---

## 2. Phan Tich Chuc Nang Tung Tang Trong Pipeline

```text
Incoming Request ->
  │
  ├─ 1. GlobalExceptionMiddleware
  │     Bọc toàn bộ luồng trong try-catch. Bắt ngoại lệ và xóa buffer response nếu có lỗi 500.
  │
  ├─ 2. ClientContextMiddleware
  │     Trích xuất W3C TraceId và Client IP thực tế (từ X-Forwarded-For).
  │     Quét và chặn đứng các header bị cấm (x-user-id, x-user-roles, ...).
  │
  ├─ 3. UseCors ("AllowFrontend")
  │     Cho phép các trình duyệt Frontend gọi API, cấu hình ExposedHeaders: X-Trace-Id, Retry-After.
  │
  ├─ 4. UseGatewaySwagger
  │     Nếu đường dẫn là /swagger, phục vụ giao diện tài liệu mà không đi qua các tầng sau.
  │
  ├─ 5 & 6. UseAuthentication & UseAuthorization
  │     Kiểm tra chữ ký số HMAC-SHA256 của JWT Bearer token và nạp vào HttpContext.User.
  │
  ├─ 7. SensitiveRateLimitMiddleware
  │     Đếm số lần gọi của Client IP trên các route nhạy cảm (OTP, Login, Register) bằng Redis.
  │
  ├─ 8. AdminAuthorizationGuardMiddleware
  │     Chặn mọi request không có vai trò admin/staff khi gọi vào /api/v1/admin/**.
  │
  ├─ 9A. IdempotencyGuardMiddleware
  │     Kiểm tra độ dài và định dạng của Idempotency-Key trên các phương thức POST/PUT/PATCH.
  │
  ├─ 9B. ResponseEnvelopeMiddleware
  │     Hoán đổi Response.Body bằng MemoryStream để hứng kết quả từ backend microservices.
  │
  ▼
10. YARP Engine: Áp dụng IdentityPropagationTransform và stream dữ liệu tới Backend Cluster.
```

---

## 3. Co Che Bat Ngoai Le Tap Trung (`GlobalExceptionMiddleware`)

File `Gateway/Middlewares/Global/GlobalExceptionMiddleware.cs` dam bao rang Gateway se khong bao gio bi crash hoac tra ve trang loi HTML mac dinh cua may chu Kestrel:

```csharp
public async Task InvokeAsync(HttpContext context)
{
    try
    {
        await _next(context);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Unhandled exception occurred while processing request: {Message}", ex.Message);
        await HandleExceptionAsync(context, ex);
    }
}

private static async Task HandleExceptionAsync(HttpContext context, Exception ex)
{
    // Nếu phản hồi đã bắt đầu gửi về client (đang stream dở dang), không thể ghi đè headers
    if (context.Response.HasStarted)
    {
        return;
    }

    var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

    context.Response.Clear(); // Xóa sạch dữ liệu lỗi dở dang trong stream
    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    context.Response.ContentType = "application/problem+json";

    var errorResponse = new ApiErrorResponse
    {
        Type = "https://tools.ietf.org/html/rfc9110#section-15.6.1",
        Title = "An unexpected error occurred",
        Status = StatusCodes.Status500InternalServerError,
        ErrorCode = "INTERNAL_SERVER_ERROR",
        Detail = "An unexpected error occurred while processing your request.",
        TraceId = traceId,
        Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    };

    var json = JsonSerializer.Serialize(errorResponse);
    await context.Response.WriteAsync(json);
}
```

### Diem kien truc:
1. **Kiem tra `context.Response.HasStarted`:** Tranh gay ra ngoai le `InvalidOperationException: Headers are read-only, response has already started` khi loi xay ra trong luc dang streaming du lieu lon ve client.
2. **Xoa buffer qua `context.Response.Clear()`:** Xoa toan bo cac byte rac da nam trong bo dem truoc khi ghi cau truc loi JSON chuan.

---

## 4. Tu Dong Tiêm Header Bao Mat Phan Hoi (Security Response Headers)

Trong `ClientContextMiddleware.cs`, Gateway su dung hook `context.Response.OnStarting()` de tu dong tiêm cac header bao mat vao moi phan hoi HTTP tra ve cho Client:

```csharp
context.Response.OnStarting(() =>
{
    context.Response.Headers["X-Trace-Id"] = traceId;
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    return Task.CompletedTask;
});
```

### Y nghia bao mat:
- **`X-Trace-Id`:** Giup Client / Frontend doc duoc ma truy vet de cung cap cho doi ngu CSKH/Ky thuat khi gap su co.
- **`X-Content-Type-Options: nosniff`:** Ngan chan trinh duyet tu y suy doan kieu MIME cua tep (MIME-sniffing attack), tranh viec thuc thi ma doc duoi danh nghia file anh hoac van ban.
- **`X-Frame-Options: DENY`:** Cam trinh duyet nhung trang web nay vao `<frame>`, `<iframe>` hoac `<object>`, ngan chan hoan toan tan cong Clickjacking.

---

## 5. Chinh Sach Tuyến Đường Nội Bộ (Internal Routes Policy)

Theo quy chuan he thong tu ngay 2026-10-31:
1. **Tam hoan chot chan `/api/v1/internal`:**
   Khoi code kiem tra va chan cac duong dan `/api/v1/internal` trong `ClientContextMiddleware.cs` dang duoc tam thoi comment. Ly do la cac vi dich vu backend dang su dung truc tiep cac route REST thong thuong de giao tiep noi bo.
2. **Quy tac bat bien doi voi YARP Configuration:**
   Tuyet doi **khong duoc phep khai bao bat ky YARP route nao cho cac duong dan noi bo** (`/internal/*`) trong file `Gateway/appsettings.json`. Gateway chi mo cac route cong khai can thiet cho nguoi dung cuoi.
