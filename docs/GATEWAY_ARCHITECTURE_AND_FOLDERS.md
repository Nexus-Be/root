# ĐẶC TẢ KIẾN TRÚC VÀ CẨM NANG CÁC THƯ MỤC CỦA NEXUS API GATEWAY
## (NEXUS EDGE API GATEWAY ARCHITECTURE & FOLDERS REFERENCE)

> **Mục tiêu tài liệu**: Cung cấp bức tranh toàn cảnh về kiến trúc **Edge API Gateway (.NET 8 LTS, C# 12, Microsoft YARP)** đặt tại `src/Services/Gateway/`, giải thích chi tiết cấu trúc thư mục, đường ống middleware phân lớp, cơ chế Active Anti-Header-Spoofing và cách chuyển tiếp lưu lượng HTTP tới 9 microservices nội bộ (`8001`-`8009`).
>
> **Trạng thái triển khai (2026-10-31):** ✅ Gateway là **Edge Reverse Proxy phi trạng thái** tại cổng `8080`, 0 Database, 0 Mock Engine, 0 Controller nghiệp vụ. Mock/Real switching, gRPC và message broker đã bị bãi bỏ hoàn toàn.
> **Nguồn sự thật:** `src/Services/Gateway/Gateway/Program.cs`, `appsettings.json`, `Middlewares/`, `Transforms/`.
> **Cập nhật lần cuối:** 2026-10-31.

---

## 1. TỔNG QUAN KIẾN TRÚC EDGE API GATEWAY

API Gateway là **điểm tiếp nhận duy nhất (single entry point)** cho lưu lượng từ Frontend, Mobile App và Postman:

```text
               CLIENT (Web Next.js / Mobile App / Postman)
                               │
                               ▼  (HTTP REST JSON, Port 8080)
┌────────────────────────────────────────────────────────────────────────┐
│                   NEXUS EDGE API GATEWAY (PORT 8080)                   │
│                                                                        │
│  [1. GlobalExceptionMiddleware]   --> Bọc lỗi không xử lý thành JSON   │
│  [2. ClientContextMiddleware]     --> Chặn header giả mạo (HTTP 403)   │
│                                       Gắn TraceId, ClientIp            │
│  [3. UseCors ("AllowFrontend")]   --> Xử lý CORS preflight             │
│  [4. UseAuthentication/Authz]     --> Xác thực chữ ký JWT Bearer       │
│  [5. SensitiveRateLimit]          --> Giới hạn OTP/Login qua Redis     │
│  [6. AdminAuthorizationGuard]     --> Chặn /api/v1/admin/**            │
│  [7. IdempotencyGuard]            --> Kiểm tra Idempotency-Key         │
│  [8. ResponseEnvelopeMiddleware]  --> Bọc JSON 2xx thành ApiResponse   │
│  [9. YARP ReverseProxy]           --> Tiêm header tin cậy, proxy       │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼  (Internal network)
┌────────────────────────────────────────────────────────────────────────┐
│                   9 BACKEND SERVICES (8001 - 8009)                     │
│  User(8001) · Catalog(8002) · Commerce(8003) · Log(8004)              │
│  Auction(8005) · Fulfillment(8006) · Notification(8007) · Wallet(8008)│
│  CheckHeal(8009)                                                       │
└────────────────────────────────────────────────────────────────────────┘
```

Gateway không có `DbContext`, không kết nối PostgreSQL, không tính phân trang và không giữ trạng thái nghiệp vụ. Redis chỉ dùng cho rate limit.

---

## 2. CẤU TRÚC THƯ MỤC CỦA `src/Services/Gateway/`

```text
src/Services/Gateway/
├── Dockerfile                         # Dockerfile đặt ở root repo Gateway
├── Gateway.sln                        # Solution gồm Gateway và Gateway.Tests
├── README.md
├── AGENTS.md                          # Quy chuẩn vận hành cho AI agents
├── CLAUDE.md
├── .agents/                           # Rule chi tiết cho agent
│   ├── AGENTS.md
│   └── rules/
├── Gateway/                           # Dự án API Gateway chính (.NET 8 LTS)
│   ├── Middlewares/
│   │   ├── Global/
│   │   │   ├── ClientContextMiddleware.cs    # Anti-spoofing, TraceId, ClientIp
│   │   │   ├── GlobalExceptionMiddleware.cs  # Lỗi không xử lý -> ApiErrorResponse
│   │   │   └── ResponseEnvelopeMiddleware.cs # Bọc JSON 2xx thành ApiResponse<T>
│   │   └── Features/
│   │       ├── AdminAuthorizationGuardMiddleware.cs
│   │       ├── IdempotencyGuardMiddleware.cs
│   │       └── SensitiveRateLimitMiddleware.cs
│   ├── Extensions/
│   │   └── SwaggerExtensions.cs       # Gộp Swagger downstream qua /swagger
│   ├── Models/
│   │   └── ApiResponse.cs             # ApiResponse<T>, ApiErrorResponse
│   ├── Transforms/
│   │   └── IdentityPropagationTransform.cs
│   ├── Properties/
│   │   └── launchSettings.json
│   ├── appsettings.json               # YARP Routes/Clusters, JWT, Redis
│   ├── appsettings.example.json
│   ├── appsettings.Development.json
│   ├── appsettings.Development.example.json
│   ├── Gateway.csproj
│   └── Program.cs                     # Composition root và pipeline
├── Gateway.Tests/                     # 58 test (Release), 10 file test
│   ├── AdminAuthorizationGuardTests.cs
│   ├── ArchitecturalContractInvariantTests.cs
│   ├── ClientContextMiddlewareTests.cs
│   ├── GatewayRootTests.cs
│   ├── GlobalExceptionMiddlewareTests.cs
│   ├── IdempotencyGuardMiddlewareTests.cs
│   ├── IdentityPropagationTransformTests.cs
│   ├── ResponseEnvelopeMiddlewareTests.cs
│   ├── SensitiveRateLimitMiddlewareTests.cs
│   └── SwaggerAggregationTests.cs
├── specs/
│   ├── 01_ARCHITECTURE.md
│   └── 02_ROUTING_CATALOG.md
└── docs/
    ├── HOW_TO_GUIDE.md
    └── EXPLANATION_ARCHITECTURE.md
```

Lưu ý:

- `Dockerfile` nằm ở `src/Services/Gateway/Dockerfile`, không nằm trong thư mục `Gateway/`.
- Không còn `Controllers/`, `Seeds/`, `gateway.runtime.json`, `MockEngineMiddleware` hay `PipelineExtensions.cs`.
- Gateway không cấu hình OpenTelemetry exporter; span trên Tempo đến từ backend service. Gateway trả `X-Trace-Id` và chuyển tiếp `x-trace-id` xuống downstream.

---

## 3. CÁC TÍNH NĂNG CỐT LÕI ĐANG VẬN HÀNH

1. **Active Anti-Header-Spoofing (`ClientContextMiddleware`)**:
   - Quét request bên ngoài, không phân biệt hoa thường.
   - Chặn ngay nếu client gửi một trong các header: `x-user-id`, `x-user-email`, `x-user-roles`, `x-user-role`, `x-user-permissions`, `x-user-permission`, `x-internal-service-key`.
   - Trả `403 Forbidden` với `errorCode = FORBIDDEN_HEADER_SPOOFING`.
2. **Cách ly API nội bộ (đang tạm khóa)**:
   - Thiết kế gốc từ chối `/api/v1/internal/*` bằng `404`, hiện đang tạm hoãn: khối chặn trong `ClientContextMiddleware` đã bị comment nên request đi qua như API thường.
   - Từ 2026-10-31, khối chặn này bị comment trong `ClientContextMiddleware`; các route liên service chuyển sang đường dẫn công khai.
   - Muốn bật lại phải khôi phục đồng bộ middleware, handler, route và tài liệu.
3. **Lan truyền danh tính (`IdentityPropagationTransform`)**:
   - Xác thực JWT Bearer tại biên, bóc tách `sub`, `email`, `role`, `permission`.
   - Tiêm downstream: `x-user-id`, `x-user-email`, `x-user-roles` (chữ thường), `x-user-permissions` (chữ in hoa), `x-client-ip`, `x-trace-id`.
4. **Đóng gói phản hồi (`ResponseEnvelopeMiddleware`)**:
   - Bọc JSON 2xx thô vào `ApiResponse<T>`.
   - Giữ nguyên `204 NoContent`, response phi JSON và response đã có đủ dấu hiệu envelope (`success` + một trong `statusCode`/`traceId`/`timestamp`/`errorCode`).
   - Không bọc response lỗi 4xx/5xx; lỗi service đi xuyên qua dưới dạng `application/problem+json`.
5. **Rate limit nhạy cảm (`SensitiveRateLimitMiddleware`)**:
   - Giới hạn `register`, `login`, `otp/verify`, `otp/resend` theo IP, lưu trên Redis `6379`, fallback in-memory khi Redis lỗi.
   - Trả `429 RATE_LIMIT_EXCEEDED` kèm `Retry-After`.
6. **Bảo vệ admin tại biên (`AdminAuthorizationGuardMiddleware`)**:
   - Chặn `/api/v1/admin/**` nếu chưa đăng nhập (`401`) hoặc thiếu role `admin`/`staff` (`403`).
7. **Phân trang phi trạng thái**:
   - Gateway không tính phân trang, không gom mảng thô. Service sở hữu DB trả `PagedData<T>`; Gateway chỉ bọc envelope.
8. **Health & Swagger**:
   - `GET /health` trả trạng thái process của Gateway.
   - Route `/health/{**catch-all}` được proxy sang CheckHeal `8009`.
   - Swagger gộp tại `/swagger`, tải tài liệu downstream qua `/swagger/downstream/{service}/swagger.json`.
