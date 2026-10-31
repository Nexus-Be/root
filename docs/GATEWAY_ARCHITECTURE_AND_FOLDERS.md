# ĐẶC TẢ KIẾN TRÚC VÀ CẨM NANG CÁC THƯ MỤC CỦA NEXUS API GATEWAY
## (NEXUS EDGE API GATEWAY ARCHITECTURE & FOLDERS REFERENCE)

> **Mục tiêu tài liệu**: Cung cấp bức tranh toàn cảnh về kiến trúc **Edge API Gateway (.NET 8 LTS, C# 12, Microsoft YARP 2.3.0)** đặt tại `src/Services/Gateway/`, giải thích chi tiết cấu trúc thư mục, đường ống middleware phân lớp, cơ chế Active Anti-Header-Spoofing, và cách thức chuyển tiếp lưu lượng HTTP trực tiếp tới 9 microservices nội bộ (`8001`-`8009`).
>
> ⚠️ **Quy chuẩn chiến lược**: Toàn bộ kiến trúc chuyển tiếp Controller cũ (kèm mock engine cục bộ, gRPC và message broker) đã được bãi bỏ hoàn toàn. Gateway hiện tại là một **Edge Reverse Proxy phi trạng thái (Stateless Reverse Proxy)** độc lập tại cổng `8080`, 0 Database, 0 Mock Engine, đạt thông lượng cao và giảm thiểu tối đa độ trễ mạng.

---

## 1. TỔNG QUAN KIẾN TRÚC EDGE API GATEWAY

API Gateway là **vành đai phòng thủ và điểm tiếp nhận duy nhất (Single Entry Point)** cho toàn bộ lưu lượng truy cập từ các ứng dụng Frontend (Web Next.js, Mobile App, Postman) gọi vào hệ thống backend:

```text
               CLIENT (Web Next.js / Mobile App / Postman)
                               │
                               ▼  (HTTP REST JSON, Port 8080)
┌────────────────────────────────────────────────────────────────────────┐
│                   NEXUS EDGE API GATEWAY (PORT 8080)                   │
│                                                                        │
│  [1. GlobalExceptionMiddleware]   --> Bắt toàn bộ lỗi thành ApiError   │
│  [2. ClientContextMiddleware]     --> Chặn Header giả mạo (HTTP 403),  │
│                                       Chặn route nội bộ (HTTP 404)     │
│  [3. UseCors ("AllowFrontend")]   --> Xử lý CORS Preflight             │
│  [4. UseAuthentication & Authz]   --> Xác thực chữ ký số JWT Bearer    │
│  [5. SensitiveRateLimit]          --> Khống chế tần suất OTP qua Redis │
│  [6. AdminAuthorizationGuard]     --> Phân quyền Admin /api/v1/admin/**│
│  [7. IdempotencyGuard]            --> Kiểm tra khóa Idempotency-Key    │
│  [8. ResponseEnvelopeMiddleware]  --> Bọc tự động 200/201 ApiResponse  │
│  [9. YARP ReverseProxy Engine]    --> Tiêm Headers tin cậy & Streaming │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼  (Internal Mesh Network)
┌────────────────────────────────────────────────────────────────────────┐
│                   9 BACKEND MICROSERVICES (8001 - 8009)                │
│  User(8001) · Catalog(8002) · Commerce(8003) · Log(8004)              │
│  Auction(8005) · Fulfillment(8006) · Notification(8007) · Wallet(8008)│
│  CheckHeal Prober Daemon (8009)                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CẤU TRÚC THƯ MỤC CỦA `src/Services/Gateway/`

Gateway sở hữu cấu trúc thư mục phân tách rành mạch theo trách nhiệm:

```text
src/Services/Gateway/
├── Gateway/                           # Dự án API Gateway chính (.NET 8 LTS)
│   ├── Middlewares/                   # Đường ống Middleware phân lớp
│   │   ├── Global/                    # Middleware toàn cục (chạy cho mọi request)
│   │   │   ├── ClientContextMiddleware.cs    # Active Anti-Spoofing, chặn /internal/*, IP/TraceId
│   │   │   ├── GlobalExceptionMiddleware.cs  # Xử lý ngoại lệ tập trung chuẩn RFC 9110
│   │   │   └── ResponseEnvelopeMiddleware.cs # Tự động bọc phản hồi thô thành ApiResponse<T>
│   │   └── Features/                  # Middleware theo ngữ cảnh tính năng
│   │       ├── AdminAuthorizationGuardMiddleware.cs # Kiểm tra quyền Admin/Staff cho /admin/**
│   │       ├── IdempotencyGuardMiddleware.cs        # Kiểm tra độ dài & định dạng Idempotency-Key
│   │       └── SensitiveRateLimitMiddleware.cs      # Giới hạn tần suất OTP/Login qua Redis
│   ├── Models/                        # Cấu trúc Envelope chuẩn hóa
│   │   └── ApiResponse.cs             # Định nghĩa ApiResponse<T> và ApiErrorResponse
│   ├── Transforms/                    # YARP Request/Response Transforms
│   │   └── IdentityPropagationTransform.cs # Bóc tách JWT claims và tiêm an toàn downstream headers
│   ├── appsettings.json               # Cấu hình YARP Routes và Clusters tới 9 microservices
│   ├── appsettings.example.json       # File mẫu cấu hình môi trường chuẩn
│   ├── Dockerfile                     # Docker container build cho môi trường Production
│   ├── Gateway.csproj                 # Khai báo gói YARP, JWT, Serilog, StackExchange.Redis
│   └── Program.cs                     # Điểm khởi động và cấu hình đường ống Middleware
├── Gateway.Tests/                     # Bộ kiểm thử tích hợp (25 tests passed 100%)
│   ├── ArchitecturalContractInvariantTests.cs # Kiểm thử hợp đồng bất biến kiến trúc
│   ├── ClientContextMiddlewareTests.cs        # Kiểm thử chống giả mạo header và chặn /internal
│   ├── GlobalExceptionMiddlewareTests.cs      # Kiểm thử bắt lỗi không mong muốn
│   ├── IdempotencyGuardMiddlewareTests.cs     # Kiểm thử xác thực khóa Idempotency
│   ├── IdentityPropagationTransformTests.cs   # Kiểm thử tiêm claims x-user-* downstream
│   ├── ResponseEnvelopeMiddlewareTests.cs     # Kiểm thử đóng gói phong bì tự động
│   └── SensitiveRateLimitMiddlewareTests.cs   # Kiểm thử khống chế tần suất Redis & RAM fallback
├── specs/                             # Hồ sơ kiến trúc nội bộ của Gateway
│   ├── 01_ARCHITECTURE.md             # Đặc tả chi tiết đường ống và cơ chế bảo mật
│   └── 02_ROUTING_CATALOG.md          # Bảng ánh xạ route và phân bổ port dịch vụ
├── docs/                              # Tài liệu hướng dẫn vận hành theo Diátaxis
│   ├── HOW_TO_GUIDE.md                # Hướng dẫn khởi chạy, thêm route, debug
│   └── EXPLANATION_ARCHITECTURE.md    # Giải thích chuyên sâu lý do lựa chọn kiến trúc
├── AGENTS.md                          # Quy chuẩn vận hành nội bộ cho AI Coding Agents
└── Gateway.sln                        # Solution chứa Gateway và Gateway.Tests
```

---

## 3. CÁC TÍNH NĂNG CỐT LÕI ĐANG VẬN HÀNH TẠI GATEWAY

1. **Active Anti-Header-Spoofing (`ClientContextMiddleware`):**
   - Chủ động quét toàn bộ request bên ngoài gửi lên (không phân biệt hoa thường).
   - Nếu client gửi bất kỳ header nào trong danh sách cấm: `x-user-id`, `x-user-email`, `x-user-roles`, `x-user-role`, `x-user-permissions`, `x-user-permission`, `x-internal-service-key`, Gateway lập tức ngắt pipeline và trả về HTTP `403 Forbidden` (`FORBIDDEN_HEADER_SPOOFING`).
2. **Cách ly hoàn toàn các API nội bộ:**
   - Mọi request truy cập `/api/v1/internal/*` hoặc chứa `/internal/` đều bị Gateway từ chối ngay lập tức với HTTP `404 Not Found` (`NOT_FOUND`).
3. **Lan truyền danh tính Zero-Trust (`IdentityPropagationTransform`):**
   - Gateway xác thực JWT Bearer token tại biên, bóc tách `sub`, `email`, `role`, `permission` và tiêm an toàn vào downstream request headers (`x-user-id`, `x-user-email`, `x-user-roles`, `x-user-permissions`, `x-client-ip`, `x-trace-id`).
4. **Tự động đóng gói Phong bì phản hồi (`ResponseEnvelopeMiddleware`):**
   - Bắt các phản hồi JSON 200/201 thô từ microservice và bọc vào `ApiResponse<T>`.
   - Giữ nguyên luồng rỗng cho HTTP 204 NoContent, bỏ qua dữ liệu phi JSON hoặc dữ liệu đã có sẵn thuộc tính `success`.
5. **Khống chế tần suất nhạy cảm (`SensitiveRateLimitMiddleware`):**
   - Áp dụng hạn mức qua Redis 6379 trên các tuyến OTP và Login để chống vét cạn. Tự động chuyển đổi sang bộ nhớ trong nếu Redis gián đoạn.
6. **Bảo vệ quyền Admin tại biên (`AdminAuthorizationGuardMiddleware`):**
   - Chặn đứng mọi request vào `/api/v1/admin/**` nếu client chưa đăng nhập (HTTP 401) hoặc thiếu vai trò `admin`/`staff` (HTTP 403).
7. **Phân trang phi trạng thái (Stateless Pagination):**
   - Gateway tuyệt đối không tính toán phân trang hoặc gom mảng thô trong RAM. Toàn bộ tính toán phân trang thuộc trách nhiệm của microservice sở hữu cơ sở dữ liệu (`PagedData<T>`).
