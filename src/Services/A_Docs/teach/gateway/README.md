# Giao Trinh Kien Truc Nexus Edge API Gateway (Nexus Edge Gateway Architecture Blueprint)

Thu muc nay chua bo tai lieu giang day va tham chieu kien truc phan mem chuyen sau cho **Nexus Edge API Gateway** (`src/Services/Gateway/`), duoc xay dung tren nen tang Microsoft YARP (Yet Another Reverse Proxy) 2.3.0 va .NET 8 LTS.

Trong he sinh thai Nexus, API Gateway la thanh phan duy nhat tiep xuc truc tiep voi mang Internet cong cong, dong vai tro la la chan phong thu bien, diem xac thuc JWT tap trung, bo loc chong gia mao danh tinh, he thong bop tan suat, va bo dong goi phong bi phan hoi tu dong `ApiResponse<T>`.

---

## 1. Thong So Kien Truc Co Ban (Gateway Core Invariants)

- **Vi tri ma nguon:** `src/Services/Gateway/`
- **Solution:** `Gateway.sln`
- **Cong HTTP duy nhat:** `8080` (tranh xung dot voi cac cong 8000 cua Portainer/Dev tools)
- **Co so du lieu:** Khong co CSDL (Stateless Edge Proxy, 0 Database)
- **Kien truc Controllers:** Khong su dung Controller (Zero-Controller Invariant). Toan bo luong di do YARP Reverse Proxy va Middleware xu ly.
- **Cong nghe cot loi:** .NET 8 Web API, Microsoft YARP 2.3.0, StackExchange.Redis 2.8.24, Serilog, OpenTelemetry OTLP.

---

## 2. Muc Luc Cac Chuyen De Kien Truc Gateway

Bo tai lieu duoc phan tach thanh 6 chuyen de kien truc doc lap:

| STT | Chuyen De | File Tai Lieu | Noi Dung Trong Tam |
|:---:|:---|:---|:---|
| 00 | **Kien Truc Edge Proxy & YARP Engine** | [`00_OVERVIEW_AND_EDGE_ARCHITECTURE.md`](00_OVERVIEW_AND_EDGE_ARCHITECTURE.md) | Nguyen ly Edge Reverse Proxy, cau hinh YARP Routes & Clusters, Zero-Controller Invariant, danh muc 9 clusters downstream. |
| 01 | **Bao Mat Bien, Anti-Spoofing & Lan Truyen Danh Tinh** | [`01_SECURITY_ANTISPOOFING_AND_IDENTITY.md`](01_SECURITY_ANTISPOOFING_AND_IDENTITY.md) | Xac thuc JWT tap trung, Active Anti-Header-Spoofing, `IdentityPropagationTransform`, chot chan phan quyen admin. |
| 02 | **Pipeline 9 Tang & Vong Doi Request** | [`02_MIDDLEWARE_PIPELINE_AND_LIFECYCLE.md`](02_MIDDLEWARE_PIPELINE_AND_LIFECYCLE.md) | Thu tu Pipeline trong `Program.cs`, `GlobalExceptionMiddleware` chuan RFC 9110, Security Headers tu dong. |
| 03 | **Phong Bi Du Lieu & Ky Luat Phan Trang** | [`03_ENVELOPE_AND_PAGINATION_DISCIPLINE.md`](03_ENVELOPE_AND_PAGINATION_DISCIPLINE.md) | Dem stream bo qua `ResponseEnvelopeMiddleware`, bọc `ApiResponse<T>`, quy chuan Zero-Pagination Calculation tai Gateway. |
| 04 | **Bop Tan Suat Redis & Tinh Idempotency** | [`04_RATE_LIMITING_AND_IDEMPOTENCY.md`](04_RATE_LIMITING_AND_IDEMPOTENCY.md) | Fixed-window rate limiting qua Redis, co che tu phuc hoi In-Memory Fallback, tham dinh `Idempotency-Key`. |
| 05 | **Tong Hop Swagger & Giam Sat Phan Tan** | [`05_SWAGGER_AGGREGATION_AND_OBSERVABILITY.md`](05_SWAGGER_AGGREGATION_AND_OBSERVABILITY.md) | OpenAPI proxy `/swagger/downstream/{service}`, an security schemes noi bo, OpenTelemetry tracing xuat Tempo. |

---

## 3. So Do Tong Quan Luong Xu Ly Cua Gateway

```text
[ External Client / Web Frontend ]
        │
        ▼ (HTTPS / Bearer Token / Port 8080)
┌────────────────────────────────────────────────────────────────────────┐
│ NEXUS EDGE API GATEWAY PIPELINE                                        │
│                                                                        │
│ 1. GlobalExceptionMiddleware: Bắt mọi ngoại lệ unhandled -> RFC 9110   │
│ 2. ClientContextMiddleware:                                            │
│    - Gán TraceId W3C và lấy Client IP thực tế                          │
│    - Active Anti-Spoofing: Chặn đứng nếu chứa x-user-id,... -> HTTP 403│
│ 3. UseCors: Chính sách AllowFrontend (ExposedHeaders: X-Trace-Id...)  │
│ 4. UseAuthentication & UseAuthorization: Xác thực chữ ký số JWT Bearer │
│ 5. SensitiveRateLimitMiddleware: Bóp tần suất OTP/Login qua Redis      │
│ 6. AdminAuthorizationGuardMiddleware: Kiểm tra role admin/staff        │
│ 7. IdempotencyGuardMiddleware: Thẩm định định dạng Idempotency-Key     │
│ 8. ResponseEnvelopeMiddleware: Đệm stream, tự bọc ApiResponse<T>       │
│ 9. YARP Reverse Proxy Engine:                                          │
│    - Định tuyến theo Path Match                                        │
│    - IdentityPropagationTransform: Tiêm an toàn claims vào headers     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Forwarded HTTP REST + Safe Headers
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 9 DOWNSTREAM MICROSERVICES CLUSTERS                                    │
│                                                                        │
│ - user-cluster        (Port 8001): /api/v1/auth, /api/v1/users, ...    │
│ - catalog-cluster     (Port 8002): /api/v1/products, /api/v1/categories│
│ - commerce-cluster    (Port 8003): /api/v1/carts, /api/v1/orders       │
│ - log-cluster         (Port 8004): /api/v1/logs                        │
│ - auction-cluster     (Port 8005): /api/v1/auctions                    │
│ - fulfillment-cluster (Port 8006): /api/v1/warehouses, /shipments      │
│ - notification-cluster(Port 8007): /api/v1/notifications               │
│ - wallet-cluster      (Port 8008): /api/v1/wallets                     │
│ - checkheal-cluster   (Port 8009): /api/v1/healthcheck, /health        │
└────────────────────────────────────────────────────────────────────────┘
```
