# Chuyen De 05: Tong Hop Swagger & Giam Sat Phan Tan (Swagger Aggregation & Observability)

Chuyen de nay huong dan chi tiet ve co che tong hop tai lieu API tap trung cua toan bo he sinh thai microservices qua Swagger UI (`SwaggerExtensions`), va kien truc giam sat vet truy vet phan tan (Distributed Tracing) tich hop OpenTelemetry va Tempo (`ObservabilityExtensions`).

---

## 1. Tong Hop Swagger Da Dich Vu (Multi-Service Swagger Aggregation)

Trong he thong microservices gom 9 dich vu chay o cac cong khac nhau, viec phai mo 9 tab trinh duyet rieng biet de doc Swagger rat bat tien.

Edge API Gateway giai quyet van de nay bang cach dong vai tro la **Diem tong hop Swagger duy nhat (Single Swagger Portal)** tai dia chi `http://localhost:8080/swagger`.

### Co che Proxy doc tai lieu OpenAPI tu cac dich vu Downstream

File `Gateway/Extensions/SwaggerExtensions.cs` cau hinh endpoint proxy dac biet:
`/swagger/downstream/{service}/swagger.json`

```csharp
// src/Services/Gateway/Gateway/Extensions/SwaggerExtensions.cs
public static readonly IReadOnlyDictionary<string, string> ServiceClusters =
    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["user"] = "user-cluster",
        ["catalog"] = "catalog-cluster",
        ["commerce"] = "commerce-cluster",
        ["log"] = "log-cluster",
        ["auction"] = "auction-cluster",
        ["fulfillment"] = "fulfillment-cluster",
        ["notification"] = "notification-cluster",
        ["wallet"] = "wallet-cluster",
        ["checkheal"] = "checkheal-cluster"
    };

public static readonly IReadOnlyDictionary<string, string> DownstreamDisplayNames =
    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["user"] = "User Service",
        ["catalog"] = "Catalog Service",
        ["commerce"] = "Commerce Service",
        ["log"] = "Log Service",
        ["auction"] = "Auction Service",
        ["fulfillment"] = "Fulfillment Service",
        ["notification"] = "Notification Service",
        ["wallet"] = "Wallet Service",
        ["checkheal"] = "CheckHeal Service"
    };
```

Khi trinh duyet yeu cau tai lieu cua User Service tai `/swagger/downstream/user/swagger.json`, Gateway se:
1. Tra cuu dia chi cluster dich tuong ung (`http://localhost:8001`).
2. Dung HttpClient goi sang `http://localhost:8001/swagger/v1/swagger.json`.
3. Nhan ve tai lieu JSON va tien hanh lam sach bao mat truoc khi tra ve cho nguoi dung.

---

## 2. Loc Bo Cac Security Schemes Noi Bo Tren Swagger UI

Cac backend microservice co the khai bao cac header noi bo nhu `x-user-id`, `x-user-roles`, `x-internal-service-key` trong Swagger cua rieng chung de phuc vu test cuc bo.

Tuy nhien, khi di qua Gateway, client **khong duoc phep** nhap cac header nay vi se vi pham quy tac chong gia mao danh tinh (Active Anti-Spoofing).

Do do, ham proxy tai Gateway chu dong loc bo cac scheme nay khoi file OpenAPI JSON:

```csharp
private static readonly string[] StrippedSecuritySchemes =
{
    "x-user-id",
    "x-user-roles",
    "x-user-email",
    "x-user-permissions",
    "X-Internal-Service-Key"
};

// Loại bỏ khỏi components/securitySchemes
if (root["components"]?["securitySchemes"] is JsonObject securitySchemes)
{
    foreach (var scheme in StrippedSecuritySchemes)
    {
        securitySchemes.Remove(scheme);
    }
}
```

Nho co bo loc nay, lap trinh vien thao tac tren Swagger cua Gateway chi can nhap duy nhat `Bearer {JWT_TOKEN}` vao nut **Authorize**. Gateway se tu dong giai ma va tiêm cac header noi bo hop le xuong backend.

---

## 3. Giam Sat Phan Tan (OpenTelemetry & Distributed Tracing)

Trong mot luong request di qua Gateway toi Backend Service va goi tiep sang CSDL, neu he thong bi cham 3 giay, lam sao biet thoi gian bi nghen o dau?

Gateway tich hop chuan quoc te **OpenTelemetry (OTel)** de theo doi chinh xac tung buoc xu ly.

### Cau hinh trong `Gateway/Extensions/ObservabilityExtensions.cs`:

```csharp
public static IServiceCollection AddGatewayObservability(this IServiceCollection services, IConfiguration configuration)
{
    var otlpEndpoint = configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] 
        ?? configuration["Otel:Endpoint"] 
        ?? "http://localhost:4317";

    services.AddOpenTelemetry()
        .ConfigureResource(r => r.AddService("Nexus.Gateway"))
        .WithTracing(t =>
        {
            // 1. Lắng nghe các sự kiện Trace sinh ra bởi YARP Reverse Proxy
            t.AddSource("Yarp.ReverseProxy")
            
            // 2. Tự động đo đạc thời gian của ASP.NET Core Kestrel
            .AddAspNetCoreInstrumentation(o =>
            {
                // Bộ lọc chống nhiễu (Noise Filtering): Bỏ qua health probes và swagger assets
                o.Filter = httpContext =>
                {
                    var path = httpContext.Request.Path.Value;
                    return path != null && !path.StartsWith("/health") && !path.StartsWith("/swagger");
                };
            })
            
            // 3. Tự động đo đạc các cuộc gọi HTTP ra bên ngoài
            .AddHttpClientInstrumentation();

            // 4. Xuất toàn bộ Spans sang Grafana Tempo qua OTLP gRPC
            if (!string.IsNullOrEmpty(otlpEndpoint))
            {
                t.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
            }
        });

    return services;
}
```

### Nguyen ly Distributed Tracing xuyen suot:
1. Khi request cham vao Gateway, OTel tao Root Span voi ma `TraceId` theo chuan W3C.
2. `IdentityPropagationTransform` tu dong chen `traceparent` vao header goi tin chuyen tiep xuong backend microservices.
3. Backend microservices nhan duoc header nay se tao cac Child Spans gan lien vao cung TraceId do.
4. Toan bo du lieu trace duoc day ve Grafana Tempo tren cong `4317`. Nguoi van hanh co the xem duoc bieu do thoi gian truc quan (Flame Graph) ghi ro so mili-giay ma request da dung o Gateway, thoi gian mang noi bo va thoi gian microservice thuc thi truy van CSDL.
