# Chuyen De 03: Phong Bi Du Lieu & Ky Luat Phan Trang (Response Envelope & Pagination Discipline)

Chuyen de nay huong dan chi tiet ve co che tu dong boc phong bi du lieu `ApiResponse<T>` bang ky thuat dem luong phan hoi (`ResponseEnvelopeMiddleware`), cac dieu kien bo qua khong boc long (Pass-through), va quy tac kien truc bat bien Zero-Pagination Calculation tai Gateway.

---

## 1. Co Che Tu Dong Boc Phong Bi Du Lieu (`ResponseEnvelopeMiddleware`)

Trong he thong Nexus, de dam bao tinh dong nhat tuyet doi cho Frontend va cac Client ben ngoai, moi ket qua tra ve thanh cong deu phai duoc nam trong phong bi chuan `ApiResponse<T>` gom: `success`, `statusCode`, `message`, `data`, `traceId`, `timestamp`.

Tuy nhien, cac backend microservices chi can tra ve du lieu thuan tuy (**Pure DTO**) ma khong can tu boc `ApiResponse<T>`. Lop `ResponseEnvelopeMiddleware` tai Gateway se tu dong dam nhan viec nay.

### Ky thuat dem luong qua `MemoryStream` (Stream Buffering)

Trong ASP.NET Core, luong `context.Response.Body` mac dinh la luong mot chieu chi ghi (Write-only network stream). Gateway khong the doc nguoc lai du lieu ma backend tra ve neu khong hoan doi luong:

```csharp
// src/Services/Gateway/Gateway/Middlewares/Global/ResponseEnvelopeMiddleware.cs
public async Task InvokeAsync(HttpContext context)
{
    // 1. Bỏ qua nếu là tài liệu Swagger
    if (context.Request.Path.StartsWithSegments("/swagger", StringComparison.OrdinalIgnoreCase))
    {
        await _next(context);
        return;
    }

    var originalBodyStream = context.Response.Body;
    await using var memoryStream = new MemoryStream();
    context.Response.Body = memoryStream; // Tạm thời hoán đổi stream sang MemoryStream

    try
    {
        await _next(context); // Chờ backend microservice xử lý và ghi dữ liệu vào memoryStream

        memoryStream.Position = 0; // Tua lại đầu stream để đọc nội dung

        // ... kiểm tra điều kiện bọc phong bì ...
    }
    finally
    {
        context.Response.Body = originalBodyStream; // Luôn trả lại stream gốc cho Kestrel
    }
}
```

---

## 2. Cac Dieu Kien Bo Qua Khong Boc Phong Bi (Pass-Through Rules)

Khong phai moi phan hoi deu duoc phep bọc phong bi. `ResponseEnvelopeMiddleware` ap dung 4 bo loc nghiem ngat de tranh lam hong du lieu cua client:

### Dieu kien 1: Ma trang thai khong phai thanh cong hoac rong
```csharp
if (context.Response.StatusCode == StatusCodes.Status204NoContent ||
    context.Response.StatusCode < 200 ||
    context.Response.StatusCode >= 300 ||
    memoryStream.Length == 0)
{
    await memoryStream.CopyToAsync(originalBodyStream);
    return;
}
```
- **HTTP 204 NoContent:** Khong chua body. Neu bọc JSON vao se vi pham giao thuc HTTP RFC 9110.
- **Loi 4xx, 5xx:** Da duoc `GlobalExceptionMiddleware` hoac microservice bọc theo chuan RFC 9110 `application/problem+json`.

### Dieu kien 2: Khong phai kieu noi dung JSON
```csharp
var contentType = context.Response.ContentType;
if (string.IsNullOrWhiteSpace(contentType) ||
    !contentType.Contains("application/json", StringComparison.OrdinalIgnoreCase))
{
    await memoryStream.CopyToAsync(originalBodyStream);
    return;
}
```
- Cac phan hoi tai file, anh, stream video, PDF hoac van ban thuan tuy (`text/plain`, `application/octet-stream`) duoc chuyen tiep nguyen ven ra client.

### Dieu kien 3: Du lieu da duoc bọc phong bi san (Avoid Double-Enveloping)
```csharp
var isAlreadyEnveloped = root.ValueKind == JsonValueKind.Object &&
    root.TryGetProperty("success", out var successElement) &&
    (successElement.ValueKind == JsonValueKind.True || successElement.ValueKind == JsonValueKind.False) &&
    (root.TryGetProperty("statusCode", out _) ||
     root.TryGetProperty("traceId", out _) ||
     root.TryGetProperty("timestamp", out _) ||
     root.TryGetProperty("errorCode", out _));

if (isAlreadyEnveloped)
{
    memoryStream.Position = 0;
    await memoryStream.CopyToAsync(originalBodyStream);
    return;
}
```
- Neu backend service da tu dong tra ve cau truc phong bi, Gateway se khong bao gio bọc long thanh `ApiResponse<ApiResponse<T>>`.

---

## 3. Dong Goi Phong Bi Du Lieu Chuan `ApiResponse<T>`

Khi du dieu kien, Gateway bọc du lieu goc tu backend thanh cau truc:

```csharp
var traceId = Activity.Current?.Id ?? context.TraceIdentifier;
var envelopeMessage = "Operation completed successfully.";

// Nếu backend có trả về trường message riêng, trích xuất làm thông điệp chính
if (root.ValueKind == JsonValueKind.Object &&
    root.TryGetProperty("message", out var msgElement) &&
    msgElement.ValueKind == JsonValueKind.String)
{
    var customMsg = msgElement.GetString();
    if (!string.IsNullOrWhiteSpace(customMsg))
    {
        envelopeMessage = customMsg.Trim();
    }
}

var wrapped = new ApiResponse<JsonElement>
{
    Success = true,
    StatusCode = context.Response.StatusCode,
    Message = envelopeMessage,
    Data = root.Clone(),
    TraceId = traceId,
    Timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
};

var wrappedBytes = JsonSerializer.SerializeToUtf8Bytes(wrapped);
context.Response.ContentType = "application/json; charset=utf-8";
context.Response.ContentLength = wrappedBytes.Length;

await originalBodyStream.WriteAsync(wrappedBytes);
```

### Vi du ket qua tra ve cho Client:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "userId": "11111111-1111-1111-1111-111111111111",
    "email": "user@nexus.local"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-04T08:00:00Z"
}
```

---

## 4. Ky Luat Bat Bien: Zero-Pagination Calculation Tai Gateway

Trong mot so he thong thiet ke sai lam, lap trinh vien thuong de backend tra ve toan bo 10.000 ban ghi, sau do de API Gateway tu dem `page` va `pageSize` de cat danh sach tra ve cho client.

Tai he sinh thai Nexus, viec nay bi **CAM TUYET DOI** boi quy tac **Zero-Pagination Calculation Invariant**:

### 1. Trach nhiem thuoc 100% ve Backend Microservice
- Chi co vi dich vu so huu CSDL moi co quyen tinh toan phan trang.
- Thao tac phan trang phai duoc thuc hien truc tiep bang cau lenh SQL `OFFSET/LIMIT` (`.Skip().Take()`) va dem so luong `COUNT(*)` tren PostgreSQL.
- Backend dong goi danh sach vao cau truc chuan `PagedData<T>` (`items` va `pagination: { pageIndex, pageSize, totalCount, totalPages, hasPreviousPage, hasNextPage }`).

### 2. Gateway la Edge Proxy phi trang thai (Stateless)
- Gateway **khong ket noi co so du lieu** va **khong nhan tap du lieu tho khong gioi han ve bo nho**.
- Neu Gateway nhan 10.000 ban ghi tu 10 request dong thoi vao RAM chi de cat trang, bo nho cua Gateway se lap tuc bi tran (OOM), lam sap toan bo he thong.
- Gateway chi nhan payload phan trang da duoc backend cat san, bọc vo phong bi thanh `ApiResponse<PagedData<T>>`, va stream tra ve cho Client.
