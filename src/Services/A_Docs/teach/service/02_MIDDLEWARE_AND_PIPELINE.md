# Chuyen De 02: Pipeline & Xu Ly Ngoai Le Tap Trung (Pipeline & Exception Handling Architecture)

Chuyen de nay giai thich thu tu thuc thi cac Middleware trong pipeline cua ASP.NET Core, co che bat va chuyen hoa ngoai le sang chuan quoc te RFC 9110 Problem Details, va chinh sach giao tiep lien dich vu dang ap dung.

---

## 1. Thu Tu Thuc Thi Pipeline Trong ASP.NET Core

Thu tu dang ky middleware trong file `Program.cs` va `ServiceDefaultsExtensions.cs` quyet dinh chieu di cua request khi vao va response khi tra ve (Russian Doll Model):

```text
Request Đến
    │
    ▼
┌────────────────────────────────────────────────────────┐
│ 1. GlobalExceptionHandlerMiddleware                    │ <-- Bọc toàn bộ pipeline để bắt mọi ngoại lệ
│    │
│    ▼
│ 2. UserContextMiddleware                               │ <-- Giải mã headers x-user-id thành ClaimsPrincipal
│    │
│    ▼
│ 3. Swagger & SwaggerUI Middleware                      │ <-- Phục vụ tài liệu OpenAPI (nếu bật)
│    │
│    ▼
│ 4. Endpoint Routing & Controllers                      │ <-- Định tuyến và thực thi Action
│    │ (Ném Exception nếu có lỗi)                        │
│    ▲
│    │
│ Trả về Response
└────────────────────────────────────────────────────────┘
```

### Trien khai trong `Program.cs` va `ServiceDefaultsExtensions.cs`

Trong `Program.cs`:
```csharp
var app = builder.Build();

// 1. Kích hoạt toàn bộ middleware mặc định
app.UseServiceDefaults();

// 2. Tự động áp dụng Migration an toàn khi khởi động (nếu DB là relational)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        if (db.Database.IsRelational())
        {
            db.Database.Migrate();
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Database migration deferred on startup: {Message}", ex.Message);
    }
}

// 3. Đăng ký endpoints
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { status = "Healthy", service = "user-service" }));
app.Run();
```

Trong `ServiceDefaultsExtensions.cs`:
```csharp
public static WebApplication UseServiceDefaults(this WebApplication app)
{
    app.UseGlobalExceptionHandler();
    app.UseMiddleware<UserContextMiddleware>();

    if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
    {
        app.UseSwagger();
        app.UseSwaggerUI(c =>
        {
            c.SwaggerEndpoint("/swagger/v1/swagger.json", "v1");
            c.RoutePrefix = "swagger";
        });
        app.MapGet("/", () => Results.Redirect("/swagger"));
    }

    return app;
}
```

---

## 2. Co Che Xu Ly Ngoai Le Tap Trung Chuẩn RFC 9110

Thay vi su dung cac khoi `try-catch` rai rac trong tung Controller Action, toan bo ngoai le duoc day tu do len tang Middleware cao nhat: `GlobalExceptionHandlerMiddleware`.

### Phan loai ngoai le qua Pattern Matching

```csharp
// src/Services/User/User.Api/Middleware/GlobalExceptionHandlerMiddleware.cs
private async Task HandleExceptionAsync(HttpContext context, Exception exception)
{
    var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

    var (statusCode, errorCode, title, detail) = exception switch
    {
        BusinessRuleValidationException bve => (
            bve.StatusCode,
            bve.ErrorCode,
            GetStatusTitle(bve.StatusCode, "Business rule violation"),
            bve.Message),
        EntityNotFoundException nfe => (
            nfe.StatusCode,
            nfe.ErrorCode,
            GetStatusTitle(nfe.StatusCode, "Resource not found"),
            nfe.Message),
        DomainException dex => (
            dex.StatusCode,
            dex.ErrorCode,
            GetStatusTitle(dex.StatusCode, "Domain error"),
            dex.Message),
        ArgumentException aex => (
            StatusCodes.Status400BadRequest,
            "VAL_INVALID_ARGUMENT",
            GetStatusTitle(StatusCodes.Status400BadRequest, "Invalid argument"),
            aex.Message),
        _ => (
            StatusCodes.Status500InternalServerError,
            "INTERNAL_SERVER_ERROR",
            GetStatusTitle(StatusCodes.Status500InternalServerError, "An unexpected error occurred"),
            "An internal server error occurred. Please try again later.")
    };
```

### Nguyen tac ghi log theo cap do nghiem trong:
- **Loi he thong (`statusCode >= 500`):** Ghi log o muc `LogError` kem toan bo StackTrace de doi ngu ky thuat dieu tra:
  `_logger.LogError(exception, "[ERROR {ErrorCode}] {Title}: {Detail}. Trace: {TraceId}", ...);`
- **Loi nghiep vu (`statusCode < 500`):** Ghi log o muc `LogWarning` khong kem StackTrace (nhu 400 Bad Request, 404 Not Found, 409 Conflict), giup giu log server sach se va khong bi tran o nho (log flood).

### Cau truc phan hoi chuan RFC 9110 `application/problem+json`:
Moi phan hoi loi deu tra ve dinh dang JSON chuan sau:

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "Business rule violation",
  "status": 400,
  "errorCode": "EMAIL_ALREADY_EXISTS",
  "detail": "Email is already registered in the system.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-04T07:15:00Z"
}
```

- `type`: Link tham chieu truc tiep toi tieu chuan dac ta cua IETF RFC 9110 cho ma trang thai HTTP tuong ung.
- `errorCode`: Ma loi 100% `SCREAMING_SNAKE_CASE` giup Client / Frontend de dang nhan dien va quoc te hoa (i18n).
- `detail`: Thong diep tieng Anh viet hoa chu cai dau (Sentence case), khong chua tu ngu tieng Viet.
- `traceId`: Ma trace tap trung (W3C TraceId) dong bo voi OpenTelemetry va Tempo de tra cuu nhanh tren Dashboard.

---

## 3. Quy Che Giao Tiep Lien Dich Vu (Internal REST Policy)

Tu moc thoi gian 2026-10-31, toan bo he thong Nexus da chuyen doi sang mo hinh **Giao tiep REST dong bo qua cac tuyen duong tieu chuan**:

### 1. Tam dung xac thuc Internal Key
- Cac lop `InternalServiceAuthMiddleware.cs` (chan request khong co header `X-Internal-Service-Key`) va `InternalServiceAuthHandler.cs` (tu dong tiem `X-Internal-Service-Key` vao outbound request) **da duoc comment tam thoi**, khong dang ky vao DI container va pipeline.
- Ly do: Giam bot do phuc tap cau hinh giua cac container khi dev local, dong thoi giup cac vi dich vu giao tiep truc tiep qua HTTP/JSON binh thuong ma khong bi chan loi 403 noi bo.

### 2. Dung route cong khai thay cho route `/internal`
Cac hanh vi lien dich vu chuyen sang su dung cac tuyen duong nghiep vu thong thuong:
- Gui OTP Email: `POST /api/v1/notifications/email/otp`
- Khoi tao kho hang: `POST /api/v1/warehouses/initialize`
- Tru tien vi truc tiep: `POST /api/v1/wallets/checkout/direct`

### 3. Dieu kien tai kich hoat
Neu trong tuong lai can kich hoat lai co che bao mat noi bo nghiem ngat bang `X-Internal-Service-Key`, viec nay can duoc thuc hien dong bo tren toan bo 9 microservices, API Gateway va he thong test ma khong duoc bat le te tren mot dich vu don le.
