# 00 — Edge API Gateway Service Reference

Tài liệu này đặc tả cấu trúc thư mục thực tế, đường ống xử lý middleware và ranh giới bảo mật của dịch vụ Edge API Gateway.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus API Gateway (`Nexus.Gateway`)
- **Vị trí thư mục:** `src/Services/Gateway/`
- **Solution:** `Gateway.sln`
- **Cổng lắng nghe HTTP:** `8080`
- **Cơ sở dữ liệu:** Không có (Stateless Edge Proxy, 0 Database)
- **Hạ tầng phụ trợ:** Kết nối Redis `6379` (bộ đếm Rate Limiting phân tán)
- **Công nghệ cốt lõi:** .NET 8 LTS, Microsoft YARP 2.3.0, Serilog, StackExchange.Redis

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Gateway/
├── Gateway/                           # Dự án API Gateway thực thi
│   ├── Middlewares/                   # Đường ống Middleware phân lớp
│   │   ├── Global/                    # Middleware toàn cục (chạy với mọi request)
│   │   │   ├── ClientContextMiddleware.cs    # Active Anti-Spoofing, chặn /internal/*, IP & TraceId
│   │   │   ├── GlobalExceptionMiddleware.cs  # Xử lý ngoại lệ tập trung chuẩn RFC 9110
│   │   │   └── ResponseEnvelopeMiddleware.cs # Đệm stream và bọc 200/201 thô vào ApiResponse<T>
│   │   └── Features/                  # Middleware theo ngữ cảnh tính năng
│   │       ├── AdminAuthorizationGuardMiddleware.cs # Phân quyền Admin/Staff cho /api/v1/admin/**
│   │       ├── IdempotencyGuardMiddleware.cs        # Kiểm tra tính hợp lệ của Idempotency-Key
│   │       └── SensitiveRateLimitMiddleware.cs      # Giới hạn tần suất OTP/Login qua Redis
│   ├── Models/                        # Cấu trúc Envelope chuẩn hóa
│   │   └── ApiResponse.cs             # Định nghĩa ApiResponse<T> và ApiErrorResponse
│   ├── Transforms/                    # YARP Request Transforms
│   │   └── IdentityPropagationTransform.cs # Bóc tách JWT claims và tiêm an toàn downstream headers
│   ├── Properties/
│   │   └── launchSettings.json        # Cấu hình cổng khởi chạy local
│   ├── appsettings.json               # Cấu hình YARP Routes và Clusters tới 9 microservices
│   ├── appsettings.example.json       # File mẫu cấu hình production
│   ├── appsettings.Development.json   # Cấu hình môi trường dev
│   ├── Dockerfile                     # Multi-stage Docker container build
│   ├── Gateway.csproj                 # Khai báo NuGet packages (Yarp.ReverseProxy 2.3.0)
│   └── Program.cs                     # Điểm cấu hình DI container và Middleware Pipeline
│
├── Gateway.Tests/                     # Dự án kiểm thử tích hợp (25 tests passed 100%)
│   ├── ArchitecturalContractInvariantTests.cs # Kiểm thử hợp đồng bất biến hệ thống
│   ├── ClientContextMiddlewareTests.cs        # Kiểm thử chống giả mạo header và chặn /internal/*
│   ├── GlobalExceptionMiddlewareTests.cs      # Kiểm thử bắt lỗi tập trung và phong bì lỗi
│   ├── IdempotencyGuardMiddlewareTests.cs     # Kiểm thử kiểm tra độ dài và định dạng Idempotency-Key
│   ├── IdentityPropagationTransformTests.cs   # Kiểm thử tiêm claims x-user-* downstream
│   ├── ResponseEnvelopeMiddlewareTests.cs     # Kiểm thử bọc tự động ApiResponse và xử lý 204
│   ├── SensitiveRateLimitMiddlewareTests.cs   # Kiểm thử giới hạn tần suất Redis & fallback RAM
│   ├── AdminAuthorizationGuardTests.cs        # Kiểm thử phân quyền admin/staff tại biên
│   └── Gateway.Tests.csproj                   # Khai báo xUnit, FluentAssertions, Mvc.Testing
│
├── specs/                             # Hồ sơ kiến trúc nội bộ
│   ├── 01_ARCHITECTURE.md             # Đặc tả chi tiết đường ống và cơ chế bảo mật
│   └── 02_ROUTING_CATALOG.md          # Bảng ánh xạ route và phân bổ port dịch vụ
│
├── docs/                              # Tài liệu vận hành theo chuẩn Diátaxis
│   ├── HOW_TO_GUIDE.md                # Hướng dẫn khởi chạy, khai báo route, debug
│   └── EXPLANATION_ARCHITECTURE.md    # Giải thích chuyên sâu lý do lựa chọn thiết kế
│
├── AGENTS.md                          # Quy chuẩn vận hành dành cho AI Coding Agents
└── Gateway.sln                        # Visual Studio Solution
```

---

## 3. Chi Tiết Chức Năng Từng Thành Phần

### 3.1. Thư mục `Gateway/Middlewares/Global/`
- `ClientContextMiddleware.cs`: 
  - Khởi tạo mã truy vết W3C `TraceId` và lấy địa chỉ `ClientIp` thực tế.
  - Quét case-insensitive 7 header cấm kỵ (`x-user-id`, `x-user-email`, `x-user-roles`, `x-user-role`, `x-user-permissions`, `x-user-permission`, `x-internal-service-key`). Nếu client bên ngoài gửi lên, ngắt pipeline ngay lập tức và trả về HTTP 403 `FORBIDDEN_HEADER_SPOOFING`.
  - Khối chặn path `/api/v1/internal` và `/internal/` đang tạm hoãn: khối lệnh đã bị comment, request đi qua như API thường. Khôi phục cần phê duyệt rõ ràng.
- `GlobalExceptionMiddleware.cs`: Bắt toàn bộ lỗi chưa xử lý từ mọi tầng, ghi log và trả về cấu trúc lỗi `ApiErrorResponse` chuẩn RFC 9110.
- `ResponseEnvelopeMiddleware.cs`: Đệm luồng kết quả (buffer body stream) từ downstream microservice. Nếu phản hồi là JSON có mã HTTP 200/201 thô, tự động bọc vào vỏ `ApiResponse<T>`. Nếu là HTTP 204 `NoContent` hoặc phản hồi đã có thuộc tính `success`, chuyển tiếp trực tiếp mà không bọc lồng.

### 3.2. Thư mục `Gateway/Middlewares/Features/`
- `AdminAuthorizationGuardMiddleware.cs`: Kiểm tra vai trò trên toàn bộ đường dẫn `/api/v1/admin/**`. Trả về HTTP 401 nếu chưa đăng nhập; trả về HTTP 403 nếu thiếu vai trò `admin`, `staff`, hoặc `administrator`.
- `IdempotencyGuardMiddleware.cs`: Xác thực sự hiện diện và độ dài của header `Idempotency-Key` (tối đa 128 ký tự) trên các phương thức POST, PUT, PATCH trước khi lưu tạm vào `HttpContext.Items`.
- `SensitiveRateLimitMiddleware.cs`: Giới hạn tần suất gọi API qua bộ đếm nguyên tử của Redis (`INCR`) trên các tuyến nhạy cảm (`resend-otp`, `verify-otp`, `register`, `login`). Tự động kích hoạt cơ chế dự phòng bộ nhớ trong (`ConcurrentDictionary`) nếu Redis tạm ngắt kết nối.

### 3.3. Thư mục `Gateway/Transforms/`
- `IdentityPropagationTransform.cs`: Hook vào YARP request transformation pipeline. Khi yêu cầu đã xác thực chữ ký JWT Bearer token hợp lệ, trích xuất claims và tiêm an toàn vào downstream headers:
  * `x-user-id`: GUID định danh duy nhất của người dùng.
  * `x-user-email`: Email của người dùng.
  * `x-user-roles`: Chuỗi danh sách vai trò viết thường, phân tách bằng dấu phẩy.
  * `x-user-permissions`: Chuỗi danh sách quyền hạn viết hoa, phân tách bằng dấu phẩy.
  * `x-client-ip`: IP kết nối thực tế của client.
  * `x-trace-id`: Mã truy vết phân tán W3C.

### 3.4. Thư mục `Gateway/Models/`
- `ApiResponse.cs`: Định nghĩa C# records chuẩn cho phong bì dữ liệu:
  * `ApiResponse<T>`: Chứa `success` (true), `statusCode`, `message`, `data`, `traceId`, `timestamp`.
  * `ApiErrorResponse`: Chứa `success` (false), `statusCode`, `errorCode`, `message`, `traceId`, `timestamp`.

---

## 4. Các Bất Biến Kiến Trúc (Architecture Invariants)

1. **Cổng 8080 là bất biến:** Gateway lắng nghe cố định tại cổng `8080`.
2. **Không phân trang tại Gateway:** Gateway không nhận dữ liệu thô lớn để tự cắt trang. Trách nhiệm phân trang thuộc 100% về microservice cơ sở dữ liệu (`PagedData<T>`).
3. **Chống giả mạo danh tính chủ động:** Bất kỳ request nào từ bên ngoài chứa header `x-user-*` hoặc `x-internal-service-key` đều bị tiêu diệt ngay lập tức với HTTP 403.
4. **Không route cho Internal API:** Không khai báo YARP route cho bất kỳ đường dẫn nào chứa `/internal/`.
