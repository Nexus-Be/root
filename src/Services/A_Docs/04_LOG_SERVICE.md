# 04 — Log Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ thu thập và truy vấn nhật ký kiểm toán tập trung.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Centralized Log Service (`Log`)
- **Vị trí thư mục:** `src/Services/Log/`
- **Solution:** `Log.sln`
- **Cổng lắng nghe HTTP REST:** `8004`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5436` (Container), Database: `log_db`
- **Nguyên tắc dữ liệu bất biến:** Append-only (chỉ INSERT và SELECT, tuyệt đối không UPDATE hay DELETE bản ghi log)
- **Quy chuẩn Route:** Đã chuẩn hóa 100% số nhiều `[Route("api/v1/logs")]`, loại bỏ route lệch `/log/logs`

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Log/
├── Log.Domain/                        # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt
│   │   ├── IAuditable.cs              # Giao diện theo dõi người ghi log
│   │   └── ISoftDelete.cs             # Giữ tính tương thích cơ sở
│   ├── Entities/
│   │   ├── LogEntry.cs                # Bản ghi nhật ký hệ thống chính (Timestamp, Level, Message, Payload)
│   │   ├── LogEventType.cs            # Danh mục các loại sự kiện hệ thống (Code, Name, IsEnabled)
│   │   ├── CentralAuditLog.cs         # Bản ghi kiểm toán nghiệp vụ nhạy cảm liên dịch vụ
│   │   ├── SecurityAuditAlert.cs      # Cảnh báo vi phạm bảo mật được kích hoạt
│   │   ├── AppLogFileCatalog.cs       # Danh mục các tệp log luân phiên
│   │   └── AuditSyncBatch.cs          # Bản ghi theo dõi đợt đồng bộ nhật ký từ các node
│   ├── Enums/                         # 6 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── CentralAuditAction.cs      # Hành động kiểm toán (Login, PasswordChange, Transfer, GrantRole)
│   │   ├── AuditSyncStatus.cs         # Pending, InProgress, Completed, Failed
│   │   ├── AppEnvironment.cs          # Development, Staging, Production
│   │   ├── AlertSeverity.cs           # Low, Medium, High, Critical
│   │   ├── AlertStatus.cs             # New, Acknowledged, Resolved, Dismissed
│   │   └── SecurityRuleType.cs        # RateLimitViolation, HeaderSpoofing, UnauthorizedInternalCall
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Log.Application/                   # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/Extensions/EnumExtensions.cs # Parse Enum an toàn
│   ├── Interfaces/
│   │   └── IApplicationDbContext.cs   # Giao diện DbContext log_db (DbSet<LogEntry>, DbSet<LogEventType>...)
│   ├── Services/
│   │   └── Log/                       # Tính năng Quản Lý Nhật Ký Tập Trung
│   │       ├── ILogService.cs         # Hợp đồng truy vấn log, bật/tắt event type, nạp batch
│   │       ├── LogService.cs          # Triển khai truy vấn phân trang và nạp log bất đồng bộ
│   │       ├── LogRequests.cs         # QueryLogsRequest, SetLogEventTypeEnabledRequest
│   │       └── LogResponses.cs        # LogEntryResponse, LogPageResponse, LogEventTypeResponse
│   └── DependencyInjection.cs         # Đăng ký ILogService vào DI Container
│
├── Log.Infrastructure/                # 3. TẦNG HẠ TẦNG (Persistence & Seed Data)
│   ├── Persistence/
│   │   ├── LogDbContext.cs            # Hiện thực EF Core DbContext, mapping bảng Logs và LogEventTypes
│   │   ├── Configurations/            # 6 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054421_InitialCreate)
│   │   └── Seeds/LogSeedData.cs       # Dữ liệu hạt giống cho các loại sự kiện hệ thống mặc định
│   └── DependencyInjection.cs         # Đăng ký LogDbContext
│
└── Log.Api/                           # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ Admin và người dùng qua Gateway
    │   │   └── LogController.cs       # [Route("api/v1/logs")]
    │   │                              # GET  /api/v1/logs            (Query logs phân trang)
    │   │                              # GET  /api/v1/logs/{id}       (Chi tiết bản ghi theo GUID)
    │   │                              # GET  /api/v1/logs/event-types (Danh mục loại sự kiện)
    │   │                              # PUT  /api/v1/logs/event-types/{code} (Bật/tắt loại sự kiện)
    │                                  # POST /api/v1/logs/batch (Nạp lô nhật ký nội bộ)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Chưa đăng ký: Internal API tạm khóa
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Tuyệt đối không sửa đổi hoặc xóa bản ghi log (Append-only):** Bảng `Logs` chỉ chấp nhận thao tác `INSERT` và `SELECT`. Tuyệt đối cấm tạo API sửa (`PUT/PATCH`) hay xóa (`DELETE`) bản ghi log.
2. **Quy chuẩn 100% Số Nhiều:** Route chính thức là `/api/v1/logs`. Cấm khai báo route trùng lặp `admin/logs` trên cùng một action.
3. **Bảo vệ API nạp log liên service:** Endpoint `POST /api/v1/logs/batch` hiện không đi qua `InternalServiceAuthMiddleware` và không yêu cầu header `X-Internal-Service-Key`, vì Internal API tạm khóa. Cần bổ sung xác thực thật trước khi dùng cho lưu lượng thật.
4. **Phân trang tại Database:** `LogService.QueryLogsAsync` tính toán phân trang qua `.Skip((page - 1) * pageSize).Take(pageSize)` và `.CountAsync()` trực tiếp trên PostgreSQL.
