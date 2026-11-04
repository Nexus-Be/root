# Chuyen De 06: Tien Ich Cat Ngang & Quan Tri He Thong (Cross-Cutting & Governance Architecture)

Chuyen de nay huong dan chi tiet ve ba quan quyen kien truc cat ngang (Cross-Cutting Concerns) bat bien trong he sinh thai Nexus: ghi nhat ky kiem toan bat bien (Centralized Audit Logging), he thong giam sat phan tan (OpenTelemetry Distributed Tracing), va quy chuan phan trang he thong (System Pagination Governance).

---

## 1. Kien Truc Ghi Nhat Ky Kiem Toan Bat Bien (Centralized Audit Logging)

Moi hanh dong nhay cam nhu phan quyen, khoa tai khoan, duyet ho so nguoi ban, cap nhat thong tin ca nhan deu bat buoc phai luu lai dau vet kiem toan khong the tay xoa vao bang `AuditLogs`.

### Rang buoc bat bien cua Audit Log:
1. **Append-Only (Chi ghi va doc):** Ban ghi `AuditLog` chi duoc phep `INSERT` va `SELECT`. Tuyet doi cam viet API sua hoac xoa nhat ky kiem toan.
2. **Commit cung Transaction:** Ban ghi audit duoc dua vao Change Tracker cua `AppDbContext` va duoc luu cung mot luc voi hanh dong nghiep vu thong qua `await _dbContext.SaveChangesAsync()`. Neu nghiep vu that bai va rollback, nhat ky kiem toan cung khong duoc sinh ra rac.
3. **Cam thay the bang Console Log:** Tuyet doi cam dung `_logger.LogInformation` de thay the cho Audit Log nghiep vu.

### Thuc hien qua Extension Method tap trung (`AuditLogExtensions.cs`):
De ngan ngua viec moi lap trinh vien tu khoi tao `new AuditLog { ... }` mot kieu gay sai lech du lieu, tang Application cung cap phuong thuc mo rong:

```csharp
// src/Services/User/User.Application/Common/Extensions/AuditLogExtensions.cs
public static class AuditLogExtensions
{
    public static AuditLog AddAuditLog(
        this IUserDbContext dbContext,
        AuditAction action,
        string entityName,
        string entityId,
        object? oldValues = null,
        object? newValues = null,
        string? userId = null,
        string? userName = null,
        object? changedColumns = null,
        string? ipAddress = null,
        string? userAgent = null,
        string? traceId = null,
        string serviceName = "user-service")
    {
        var log = new AuditLog
        {
            Id = Guid.NewGuid(),
            ServiceName = serviceName,
            Action = action,
            EntityName = entityName,
            EntityId = entityId,
            UserId = userId,
            UserName = userName,
            OldValues = SerializePayload(oldValues),
            NewValues = SerializePayload(newValues),
            ChangedColumns = SerializePayload(changedColumns),
            IpAddress = ipAddress,
            UserAgent = userAgent,
            TraceId = traceId,
            CreatedAt = DateTimeOffset.UtcNow,
            IsSynced = false
        };

        dbContext.AuditLogs.Add(log);
        return log;
    }

    private static string? SerializePayload(object? value)
    {
        if (value is null) return null;
        if (value is string str) return str; // Tránh double-serialize nếu đã là JSON string
        return JsonSerializer.Serialize(value);
    }
}
```

### Vi du su dung trong Service:
```csharp
// Khi khóa tài khoản người dùng:
_dbContext.AddAuditLog(
    action: AuditAction.Update,
    entityName: nameof(User),
    entityId: user.Id.ToString(),
    oldValues: new { user.Status, user.BanReason },
    newValues: new { Status = UserStatus.Banned, BanReason = reason },
    userId: adminId.ToString(),
    traceId: _httpContextAccessor.HttpContext?.GetTraceId()
);

await _dbContext.SaveChangesAsync(cancellationToken);
```

---

## 2. Giam Sat Phan Tan (OpenTelemetry & Distributed Tracing)

Trong kien truc Microservices gom nhieu dich vu ket noi voi nhau, khi mot request bi cham hoac loi, rat kho de xac dinh nguyen nhan nam o API Gateway, UserService hay CSDL neu khong co he thong **Distributed Tracing**.

UserService su dung tieu chuan quoc te **OpenTelemetry (OTel)** de thu thap va xuat trace ve he thong luu tru tap trung (Tempo / Jaeger).

### Cau hinh trong `User.Api/Extensions/ObservabilityExtensions.cs`:

```csharp
public static IServiceCollection AddServiceObservability(this IServiceCollection services, IConfiguration configuration, string serviceName)
{
    var otlpEndpoint = configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] 
        ?? configuration["Otel:Endpoint"] 
        ?? "http://localhost:4317";

    services.AddOpenTelemetry()
        .ConfigureResource(r => r.AddService(serviceName))
        .WithTracing(t =>
        {
            t.AddAspNetCoreInstrumentation() // Tự động đo thời gian xử lý HTTP Incoming Requests
             .AddHttpClientInstrumentation(); // Tự động đo thời gian các cuộc gọi HTTP Outgoing (tới Notification, Fulfillment)

            if (!string.IsNullOrEmpty(otlpEndpoint))
            {
                t.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
            }
        });

    return services;
}
```

### Nguyen ly hoat dong W3C TraceContext:
1. Khi request tu ngoai di qua API Gateway, Gateway khoi tao mot **W3C TraceId** duy nhat (vi du: `4bf92f3577b34da6a3ce929d0e0e4736`) va gui kem header `traceparent`.
2. `User.Api` nhan duoc header nay, OTel tu dong tao mot Span con gan voi TraceId do.
3. Khi UserService goi tiep sang NotificationService qua `HttpClient`, `IdentityPropagationHandler` tiep tuc gui TraceId nay di.
4. Tren he thong Grafana / Tempo, nguoi van hanh co the nhin thay mot cay thoi gian truc quan (Flame Graph) ghi ro tung mili-giay da tieu ton o Gateway, UserService va CSDL.

---

## 3. Quy Chuan Phan Trang He Thong (System Pagination Governance)

De tranh nguy co qua tai bo nho RAM va nghen bang thong mang, he thong Nexus quy dinh ngat ngheo ve phan chia trach nhiem phan trang:

### 1. Trach nhiem thuoc 100% ve Backend Microservice
- **Chi microservice so huu CSDL moi duoc phep thuc hien phan trang:**
  Su dung truc tiep cau lenh SQL `OFFSET / LIMIT` thong qua EF Core LINQ:
  ```csharp
  var totalCount = await query.CountAsync(cancellationToken);
  var items = await query
      .Skip((pageIndex - 1) * pageSize)
      .Take(pageSize)
      .ToListAsync(cancellationToken);
  ```
- **Gateway tuyet doi khong tinh toan phan trang:**
  API Gateway la mot Edge Reverse Proxy phi trang thai (Stateless). Gateway tuyet doi **khong nhan tap du lieu tho khong gioi han ve bo nho de tu cat trang**.

### 2. Dong goi cau truc chuan `PagedData<T>`
Moi endpoint danh sach phan trang deu tra ve cau truc dong nhat tai `User.Application/Common/Models/PagedData.cs`:

```csharp
public sealed record PagedData<T>(
    IReadOnlyList<T> Items,
    PaginationMetadata Pagination);

public sealed record PaginationMetadata(
    int PageIndex,
    int PageSize,
    int TotalCount,
    int TotalPages,
    bool HasPreviousPage,
    bool HasNextPage);
```

### Vi du Response JSON chuan:
```json
{
  "items": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "email": "buyer@nexus.local",
      "fullName": "Nexus Buyer",
      "status": "Active"
    }
  ],
  "pagination": {
    "pageIndex": 1,
    "pageSize": 20,
    "totalCount": 150,
    "totalPages": 8,
    "hasPreviousPage": false,
    "hasNextPage": true
  }
}
```

### 3. Gioi han an toan (`PaginationConstants.cs`):
- `DefaultPageSize = 20`: Mac dinh neu client khong truyen tham so `limit`.
- `MaxPageSize = 100`: Gioi han tran toi da. Neu client co tinh gui `limit = 10000`, he thong se tu dong kẹp ve `100` de ngan chan tan cong lam dung tai nguyen (Denial of Service - DoS).
