# Chuyen De 01: OpenTelemetry & Giam Sat Phan Tan (OpenTelemetry & Distributed Tracing)

Chuyen de nay huong dan chi tiet ve cach thuc he thong Nexus thu thap cac vet truy vet phan tan (Distributed Traces) su dung tieu chuan quoc te OpenTelemetry trong .NET 8, giao thuc OTLP, va co che lan truyen boi canh W3C TraceContext.

---

## 1. Tieu Chuan Quoc Te OpenTelemetry Trong .NET 8

Trong qua khu, moi hang phan mem giam sat thuong cung cap mot bo SDK rieng (vi du Datadog SDK, Dynatrace OneAgent, NewRelic Agent). Khi muon doi nha cung cap, doi ngu ky thuat phai go bo va viet lai toan bo code thu thap du lieu.

He thong Nexus ap dung tieu chuan trung lap **OpenTelemetry (OTel)** do Cloud Native Computing Foundation (CNCF) quan ly:
- **Trung lap voi nha cung cap (Vendor-Neutral):** Ma nguon .NET chi giao tiep voi OpenTelemetry API. Du lieu trace co the duoc chuyen den Tempo, Jaeger, Zipkin hoac Datadog ma khong can thay doi bat ky dong code C# nao.
- **Tich hop sau vao .NET Runtime:** OpenTelemetry su dung truc tiep lop `System.Diagnostics.Activity` co san trong .NET Runtime, giup viec sinh trace span tieu ton cuc ky it CPU va khong gay cap phat bo nho rac (zero-allocation spans).

---

## 2. Giao Thuc OTLP (OpenTelemetry Protocol)

Moi vi dich vu trong Nexus xuat du lieu trace sang Tempo thong qua chuan **OTLP (OpenTelemetry Protocol)**:
- **Cong mac dinh:** `4317` (gRPC) va `4318` (HTTP Protobuf / JSON).
- **Uu the cua OTLP gRPC:** Du lieu duoc nen nhe bang Protobuf va truyen tai tren ket noi HTTP/2 multiplexing, giup ban hang ngan spans moi giay ma khong gay nghen bang thong mang giua ung dung va container Tempo.

---

## 3. Phuong Thuc Mo Rong `AddServiceObservability`

Trong toan bo 9 microservices backend, viec dang ky OTel duoc dong goi thong nhat tai file `Extensions/ObservabilityExtensions.cs`:

```csharp
// src/Services/User/User.Api/Extensions/ObservabilityExtensions.cs
public static class ObservabilityExtensions
{
    public static IServiceCollection AddServiceObservability(
        this IServiceCollection services, 
        IConfiguration configuration, 
        string serviceName)
    {
        var otlpEndpoint = configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] 
            ?? configuration["Otel:Endpoint"] 
            ?? "http://localhost:4317";

        services.AddOpenTelemetry()
            .ConfigureResource(r => r.AddService(serviceName))
            .WithTracing(t =>
            {
                // 1. Tự động thu thập incoming HTTP requests
                t.AddAspNetCoreInstrumentation()
                
                // 2. Tự động thu thập outgoing HTTP calls (HttpClient)
                 .AddHttpClientInstrumentation();

                // 3. Xuất spans qua OTLP sang Tempo
                if (!string.IsNullOrEmpty(otlpEndpoint))
                {
                    t.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
                }
            });

        return services;
    }
}
```

### Bo loc chong nhieu (Noise Filtering) tai Gateway:
Rieng tai API Gateway, cac request goi toi `/health` (do Kubernetes hoac Docker kiem tra dinh ky) va cac asset tinh cua `/swagger` neu duoc ghi trace se tao ra hang tram ngan spans vo nghia, lam tran o dia cua Tempo.

Do do, file `Gateway/Extensions/ObservabilityExtensions.cs` cai dat bo loc bo qua:

```csharp
.AddAspNetCoreInstrumentation(o =>
{
    o.Filter = httpContext =>
    {
        var path = httpContext.Request.Path.Value;
        // Loại bỏ hoàn toàn health probes và swagger assets khỏi root traces
        return path != null && !path.StartsWith("/health") && !path.StartsWith("/swagger");
    };
})
```

---

## 4. Tieu Chuan W3C TraceContext & Chuoi `traceparent`

De ket noi mot request duy nhat di tu Gateway xuong UserService va goi tiep sang NotificationService, he thong su dung tieu chuan quoc te **W3C TraceContext**.

Moi khi goi HTTP ra ben ngoai, `IdentityPropagationTransform` hoac `HttpClient` se tu dong tiêm header `traceparent` vao request:

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
              │  └──────────────┬───────────────┘ └───────┬────────┘ └─┬┘
              │                 │                         │            │
           Version           TraceId                    SpanId       Flags (01 = Sampled)
```

### Y nghia tung phan:
- **Version (`00`):** Phien ban tieu chuan W3C hien hanh.
- **TraceId (`4bf92f3577b34da6a3ce929d0e0e4736`):** Chuoi hexa 16-byte duy nhat dai dien cho toan bo cuoc hanh trinh cua request xuyen suot tat ca cac vi dich vu.
- **SpanId (`00f067aa0ba902b7`):** Chuoi hexa 8-byte dai dien cho buoc xu ly hien tai trong dich vu do.
- **Flags (`01`):** `01` nghia la span nay duoc danh dau de luu tru (Sampled).

Nho co tieu chuan nay, khi mo Grafana Tempo, nguoi quan tri chi can nhap chuoi `TraceId` la co the xem duoc toan bo cay thoi gian thuc thi cua request tren toan he thong.
