# 01 — User Service Reference

Tài liệu này đặc tả cấu trúc thư mục, các tầng Clean Architecture và chức năng nghiệp vụ của dịch vụ quản lý người dùng và định danh.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus User Management Service (`User`)
- **Vị trí thư mục:** `src/Services/User/`
- **Solution:** `User.sln`
- **Cổng lắng nghe HTTP REST:** `8001`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5433` (Container), Database: `usermanagement_db`
- **Hạ tầng Redis:** Cổng `6379`, key prefix `otp:*` và `user:*`
- **Giao tiếp liên dịch vụ:** Typed HTTP Client gọi sang `NotificationService` (`POST /api/v1/internal/notifications/email/otp`)
- **Kiểm thử tự động:** `User.Tests` với **216 unit và integration tests passed 100%**

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/User/
├── User.Domain/                       # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở chứa Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Giao diện theo dõi người tạo và ngày sửa đổi
│   │   └── ISoftDelete.cs             # Giao diện xóa mềm (IsDeleted, DeletedAt)
│   ├── Entities/
│   │   ├── User.cs                    # Thông tin tài khoản người dùng, email, hash mật khẩu
│   │   ├── Role.cs                    # Danh mục vai trò (Buyer, Seller, Staff, Admin)
│   │   ├── Permission.cs              # Quyền hạn chi tiết hệ thống
│   │   ├── UserRole.cs                # Bảng liên kết nhiều-nhiều User và Role
│   │   ├── RolePermission.cs          # Bảng liên kết nhiều-nhiều Role và Permission
│   │   ├── RefreshToken.cs            # Token làm mới JWT còn hiệu lực
│   │   ├── SellerProfile.cs           # Hồ sơ đăng ký gian hàng và thông tin shop của Seller
│   │   ├── UserPenalty.cs             # Lịch sử xử phạt và đình chỉ tài khoản
│   │   ├── UserReport.cs              # Báo cáo vi phạm từ cộng đồng
│   │   ├── UserReview.cs              # Đánh giá uy tín giữa các người dùng
│   │   ├── ReputationScore.cs         # Điểm tín nhiệm tổng hợp của người dùng
│   │   ├── ReputationLog.cs           # Lịch sử biến động điểm tín nhiệm
│   │   ├── SystemConfig.cs            # Cấu hình tham số hệ thống
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 16 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── UserStatus.cs              # Trạng thái tài khoản (PendingVerification, Active, Suspended, Banned)
│   │   ├── RoleType.cs                # Mã vai trò chuẩn hóa
│   │   ├── TrustLevel.cs              # Cấp độ uy tín tín nhiệm
│   │   ├── SellerProfileStatus.cs     # Trạng thái duyệt hồ sơ bán hàng
│   │   ├── PenaltyStatus.cs           # Trạng thái thi hành án phạt
│   │   ├── PenaltyType.cs             # Hình thức xử phạt (Warning, TemporaryBan, PermanentBan)
│   │   ├── PenaltyViolationType.cs    # Loại vi phạm quy tắc
│   │   ├── ReportStatus.cs            # Trạng thái xử lý tố cáo
│   │   ├── ReportViolationType.cs     # Hành vi bị tố cáo
│   │   ├── ReviewerRole.cs            # Vai trò người thực hiện đánh giá
│   │   ├── ReputationChangeReason.cs  # Lý do cộng/trừ điểm tín nhiệm
│   │   ├── ReferenceType.cs           # Loại thực thể tham chiếu
│   │   ├── OtpType.cs                 # Mục đích mã OTP (Registration, PasswordReset, SellerVerification)
│   │   ├── Gender.cs                  # Giới tính người dùng
│   │   ├── ConfigDataType.cs          # Kiểu dữ liệu cấu hình hệ thống
│   │   └── AuditAction.cs             # Hành động kiểm toán (Insert, Update, Delete)
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ chứa StatusCode và ErrorCode
│
├── User.Application/                  # 2. TẦNG CA SỬ DỤNG (Use Cases & Feature Co-location)
│   ├── Common/
│   │   ├── Extensions/EnumExtensions.cs   # Parse chuỗi Enum an toàn không phân biệt hoa thường
│   │   ├── Models/PagedResultDto.cs       # DTO kết quả phân trang chuẩn
│   │   └── PaginationConstants.cs         # Hạn mức phân trang mặc định
│   ├── Interfaces/
│   │   ├── IUserDbContext.cs          # Giao diện DbContext cấp quyền truy cập DbSet<T>
│   │   ├── IJwtTokenGenerator.cs      # Hợp đồng sinh mã Access Token và Refresh Token
│   │   ├── IRedisOtpService.cs        # Hợp đồng lưu trữ và thẩm định OTP qua Redis
│   │   └── IEmailNotificationClient.cs# Hợp đồng HTTP Client gọi sang NotificationService
│   ├── Services/
│   │   ├── Auth/                      # Tính năng Xác Thực (Đăng ký, OTP, Đăng nhập, Làm mới)
│   │   │   ├── IAuthService.cs, AuthService.cs, AuthRequests.cs, AuthResponses.cs, AuthDtos.cs
│   │   ├── Profile/                   # Tính năng Hồ Sơ Người Dùng (Xem hồ sơ cá nhân, cập nhật)
│   │   │   ├── IProfileService.cs, ProfileService.cs, ProfileRequests.cs, ProfileResponses.cs, ProfileDtos.cs
│   │   ├── Admin/                     # Tính năng Quản Trị Người Dùng (Danh sách, khóa, phân quyền)
│   │   │   ├── IAdminUserService.cs, AdminUserService.cs, AdminUserRequests.cs, AdminUserResponses.cs
│   │   └── Seller/                    # Tính năng Đăng Ký và Quản Lý Gian Hàng Seller
│   │       ├── ISellerService.cs, SellerService.cs, SellerRequests.cs, SellerResponses.cs, SellerDtos.cs
│   ├── Models/OtpEntry.cs             # Cấu trúc bản ghi OTP lưu tạm thời
│   └── DependencyInjection.cs         # Đăng ký các Feature Service vào ServiceCollection
│
├── User.Infrastructure/               # 3. TẦNG HẠ TẦNG (Database & External Integrations)
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Hiện thực EF Core DbContext, lưu trữ Enum integer
│   │   ├── Configurations/            # 13 Fluent API Configuration files
│   │   ├── Migrations/                # Lịch sử EF Core Migrations (20261030054250_InitialCreate)
│   │   └── Seeds/UserSeedData.cs      # Dữ liệu mẫu khởi tạo tài khoản cố định (GUID Deterministic)
│   ├── Services/
│   │   ├── Common/InternalServiceAuthHandler.cs # DelegatingHandler tự động tiêm X-Internal-Service-Key
│   │   ├── Jwt/JwtTokenGenerator.cs   # Ký số JWT HS256 với các claims sub, email, role, permission
│   │   ├── Notification/EmailNotificationClient.cs # Gọi POST /api/v1/internal/notifications/email/otp
│   │   └── Redis/RedisOtpService.cs   # Lưu mã OTP với thời gian sống TTL 5 phút
│   └── DependencyInjection.cs         # Đăng ký DbContext, RedisMultiplexer, HttpClient
│
├── User.Api/                          # 4. TẦNG GIAO DIỆN RESTful HTTP API
│   ├── Controllers/
│   │   ├── Public/                    # Controllers công khai phục vụ người dùng qua Gateway
│   │   │   ├── AuthController.cs      # /api/v1/auth (register, verify-otp, login, refresh, logout)
│   │   │   ├── UsersController.cs     # /api/v1/users và /api/v1/me
│   │   │   ├── AdminUsersController.cs# /api/v1/admin/users
│   │   │   └── SellerController.cs    # /api/v1/sellers (đăng ký gian hàng, hồ sơ shop)
│   │   └── Internal/                  # Controllers dành riêng cho giao tiếp liên service
│   ├── Common/Converters/
│   │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành chuỗi PascalCase
│   ├── Extensions/
│   │   ├── ServiceDefaultsExtensions.cs # Cấu hình Swagger đầy đủ headers và Security Requirements
│   │   ├── HttpContextExtensions.cs   # Trích xuất an toàn x-user-id, x-user-email, x-user-roles
│   │   └── ObservabilityExtensions.cs # Tích hợp OpenTelemetry tracing sang Tempo
│   ├── Middleware/
│   │   ├── InternalServiceAuthMiddleware.cs # Bảo vệ endpoint /api/v1/internal/* bằng secret key
│   │   └── GlobalExceptionHandlerMiddleware.cs # Xử lý ngoại lệ chuẩn RFC 9110 ProblemDetails
│   └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
│
└── User.Tests/                        # 5. TẦNG KIỂM THỬ TỰ ĐỘNG (216 Tests Passed)
    ├── AuthServiceTests.cs, ProfileServiceTests.cs, AdminUserServiceTests.cs, SellerServiceTests.cs
    ├── AuthControllerRestTests.cs, UsersControllerRestTests.cs, AdminUsersControllerRestTests.cs, SellerControllerRestTests.cs
    ├── JwtTokenGeneratorTests.cs, SwaggerGenerationTests.cs, EnumConversionTests.cs
    └── User.Tests.csproj
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Tuyệt đối không lưu mật khẩu dạng văn bản thô:** 100% mật khẩu được băm bằng thuật toán BCrypt có salt (`BCrypt.Net-Next 4.0.3`).
2. **Không Repository Pattern:** Tầng Application inject trực tiếp `IUserDbContext` và truy vấn trực tiếp trên `DbSet<T>`.
3. **Quy chuẩn Định danh Route 100% Số Nhiều:**
   - Người dùng: `/api/v1/users`, `/api/v1/admin/users`.
   - Người bán: `/api/v1/sellers`.
   - Ngoại lệ đơn lẻ: `/api/v1/me` (hồ sơ chính mình) và `/api/v1/auth` (xác thực).
4. **Bảo vệ quyền sở hữu tài nguyên:** Mọi thao tác xem hoặc chỉnh sửa hồ sơ nhạy cảm đều đọc `currentUserId` từ `this.GetUserId()` (tiêm từ Gateway), cấm tin tưởng tham số ID gửi từ client.
