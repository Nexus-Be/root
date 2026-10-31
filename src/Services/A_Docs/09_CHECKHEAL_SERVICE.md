# 09 — CheckHeal Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc phân tầng và cơ chế giám sát sức khỏe, keep-alive chống ngủ đông cho 8 microservices và 8 cơ sở dữ liệu PostgreSQL.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus System Health Check & Keep-Alive Service (`CheckHeal`)
- **Vị trí thư mục:** `src/Services/CheckHeal/`
- **Solution:** `CheckHeal.sln`
- **Cổng lắng nghe HTTP REST:** `8009`
- **Cơ sở dữ liệu cục bộ:** Không có (0 Local Database, phi trạng thái in-memory qua `IHealthStateManager`)
- **Đối tượng giám sát ngoại vi:**
  - 8 Microservices qua HTTP GET `/health`
  - 8 Database PostgreSQL qua truy vấn nhẹ `SELECT 1;` (`NpgsqlConnection`)
- **Cơ chế chống ngủ đông (Keep-Alive):** `KeepAliveBackgroundWorker` chạy chu kỳ định kỳ 60 giây gửi lệnh giữ kết nối cơ sở dữ liệu (Neon, Supabase, Render)
- **Bảo mật truy cập:** Xác thực qua header `X-Api-Key` (`ApiKeyAuthMiddleware`) và `X-Internal-Service-Key` (`InternalServiceAuthMiddleware`)
- **Kiểm thử tự động:** `CheckHeal.Tests` với **20 unit và integration tests passed 100%**

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/CheckHeal/
├── CheckHeal.Domain/                  # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Enums/                         # Strongly-typed C# Enums
│   │   ├── HealthStatus.cs            # Healthy, Degraded, Unhealthy, Unknown
│   │   └── TargetKind.cs              # Service, Database
│   ├── Models/                        # Mô hình dữ liệu in-memory thread-safe
│   │   ├── HealthSample.cs            # Mẫu đo độ trễ LatencyMs, trạng thái và lỗi
│   │   ├── TargetHealthState.cs       # Trạng thái mục tiêu (Url, IsEnabled, CurrentStatus, Samples)
│   │   └── IncidentRecord.cs          # Bản ghi sự cố chuyển đổi trạng thái sức khỏe
│   └── CheckHeal.Domain.csproj
│
├── CheckHeal.Application/             # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── DTOs/
│   │   ├── HealthDashboardResponse.cs # Tổng quan sức khỏe hệ thống (Summary, Services, Databases)
│   │   ├── TargetHealthDto.cs         # DTO trạng thái một mục tiêu kiểm tra
│   │   └── ToggleRequests.cs          # ServiceToggleRequest, DatabaseToggleRequest, BulkToggleRequest, ManualCheckResultDto
│   ├── Interfaces/
│   │   ├── IHealthStateManager.cs     # Hợp đồng quản lý trạng thái, lấy dashboard, kích hoạt check thủ công
│   │   ├── IServiceProber.cs          # Hợp đồng probe HTTP tới các microservices
│   │   ├── IDatabaseProber.cs         # Hợp đồng probe SQL SELECT 1; tới các PostgreSQL databases
│   │   └── IIncidentLogger.cs         # Hợp đồng ghi nhận và tra cứu lịch sử sự cố
│   └── CheckHeal.Application.csproj
│
├── CheckHeal.Infrastructure/          # 3. TẦNG HẠ TẦNG (Probers, State Manager & Cron Worker)
│   ├── Options/
│   │   └── HealthCheckOptions.cs      # Cấu hình interval, danh sách 8 services và 8 connection strings
│   ├── Probers/
│   │   ├── HttpServiceProber.cs       # Gửi HTTP GET /health với timeout 5s qua HttpClient
│   │   └── NpgsqlDatabaseProber.cs    # Mở NpgsqlConnection thực thi SELECT 1; với timeout 5s, giải phóng kết nối ngay
│   ├── Services/
│   │   ├── InMemoryHealthStateManager.cs # Quản lý trạng thái luồng an toàn qua ConcurrentDictionary
│   │   └── FileRollingIncidentLogger.cs # Ghi log sự cố dạng file xoay vòng và bộ nhớ
│   ├── Workers/
│   │   └── KeepAliveBackgroundWorker.cs # BackgroundService chạy định kỳ kiểm tra và gửi keep-alive
│   ├── InfrastructureDependencyInjection.cs # Đăng ký probers, state manager và background worker
│   └── CheckHeal.Infrastructure.csproj
│
└── CheckHeal.Api/                     # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ dashboard và điều khiển
    │   │   └── HealthCheckController.cs # [Route("api/v1/[controller]")]
    │   │       # GET  /status                     (Dashboard tổng quan toàn bộ hệ thống)
    │   │       # GET  /services                   (Danh sách trạng thái 8 backend services)
    │   │       # GET  /services/{serviceName}     (Chi tiết trạng thái 1 backend service)
    │   │       # PUT  /services/{serviceName}/toggle (Bật/tắt giám sát tự động 1 service)
    │   │       # POST /services/{serviceName}/check  (Kích hoạt probe thủ công 1 service)
    │   │       # GET  /databases                  (Danh sách trạng thái 8 databases)
    │   │       # GET  /databases/{serviceName}    (Chi tiết trạng thái 1 database)
    │   │       # PUT  /databases/{serviceName}/toggle(Bật/tắt keep-alive 1 database)
    │   │       # POST /databases/{serviceName}/check (Kích hoạt truy vấn SELECT 1; thủ công)
    │   │       # PUT  /bulk-toggle                (Bật/tắt giám sát hàng loạt theo nhóm hoặc tất cả)
    │   │       # GET  /incidents                  (Tra cứu lịch sử sự cố gần nhất)
    │   └── Internal/                  # Controllers nội bộ liên service
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Middleware/
    │   ├── ApiKeyAuthMiddleware.cs    # Xác thực header X-Api-Key cho các endpoint điều khiển
    │   ├── InternalServiceAuthMiddleware.cs # Bảo vệ /internal/* bằng secret key
    │   └── ExceptionHandlingMiddleware.cs # Xử lý ngoại lệ tập trung chuẩn ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8, map probes /health, /health/live, /health/ready
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Không Có Database Cục Bộ:** CheckHeal quản lý trạng thái hoàn toàn in-memory qua `IHealthStateManager` (`ConcurrentDictionary`), không tạo EF Core DbContext hay bảng CSDL riêng.
2. **Truy Vấn Keep-Alive Siêu Nhẹ:** Probe cơ sở dữ liệu chỉ sử dụng duy nhất câu lệnh `SELECT 1;` với thời gian chờ kết nối (timeout) tối đa 5 giây và giải phóng kết nối ngay lập tức (`await using`).
3. **Mặc Định An Toàn (Default Disabled):** Tất cả các mục tiêu dịch vụ và cơ sở dữ liệu mặc định ở trạng thái tắt (`IsEnabled = false`) cho đến khi được bật chủ động qua API hoặc cấu hình môi trường.
4. **Bảo Mật Bằng API Key:** Toàn bộ endpoint điều khiển, dashboard và kích hoạt kiểm tra bắt buộc cung cấp header `X-Api-Key` hợp lệ. Riêng các probe chuẩn `/health`, `/health/live`, `/health/ready` được phép bỏ qua xác thực để phục vụ bộ giám sát hạ tầng container.
5. **Định Dạng Phản Hồi Chuẩn:** Dữ liệu enum trả về luôn tuần tự hóa dạng PascalCase (`Healthy`, `Degraded`, `Unhealthy`). Ngoại lệ hệ thống chuyển đổi thành RFC 9110 `ProblemDetails` với mã lỗi `SCREAMING_SNAKE_CASE`.
