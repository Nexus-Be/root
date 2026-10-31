# 07 — Notification Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ quản lý thông báo in-app, đăng ký thiết bị và gửi email OTP/hệ thống.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Notification & Email Dispatcher Service (`Notification`)
- **Vị trí thư mục:** `src/Services/Notification/`
- **Solution:** `Notification.sln`
- **Cổng lắng nghe HTTP REST:** `8007`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5439` (Container), Database: `notification_db`
- **Giao tiếp liên dịch vụ nội bộ (Inbound):** Tiếp nhận yêu cầu gửi email OTP từ `UserService` qua `POST /api/v1/notifications/email/otp` và email hệ thống qua `POST /api/v1/notifications/email/send`, hiện không yêu cầu header nội bộ vì Internal API tạm khóa
- **Xử lý nền (Background Processing):** `EmailBackgroundWorker` xử lý hàng đợi email bất đồng bộ qua `IEmailBackgroundQueue` (System.Threading.Channels)
- **Kiểm thử tự động:** `Notification.Tests` với **13 unit và integration tests passed 100%**

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Notification/
├── Notification.Domain/               # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── DeviceToken.cs             # Token thiết bị FCM/APNS nhận push notification
│   │   ├── NotificationChannel.cs     # Kênh phát thông báo (Email, Push, InApp, SMS)
│   │   ├── NotificationPreference.cs  # Cài đặt nhận thông báo của người dùng
│   │   ├── NotificationRecord.cs      # Bản ghi thông báo in-app gửi tới người dùng
│   │   ├── NotificationDelivery.cs    # Lịch sử gửi và trạng thái phát qua từng kênh
│   │   ├── NotificationTemplate.cs    # Mẫu email/nội dung thông báo hệ thống
│   │   ├── NotificationLog.cs         # Nhật ký ghi nhận sự kiện thông báo
│   │   ├── EventLog.cs                # Nhật ký kiểm toán sự kiện nội bộ
│   │   ├── BrokerHealthCheck.cs       # Bản ghi kiểm tra sức khỏe của Message Broker/Hàng đợi
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 11 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── ChannelType.cs             # Email, PushNotification, InApp, Sms
│   │   ├── ChannelProvider.cs         # Smtp, FirebaseFcm, AppleApns, Twilio
│   │   ├── ChannelScope.cs            # Global, UserSpecific, SystemOnly
│   │   ├── NotificationType.cs        # OrderPlaced, OrderPaid, ShipmentDelivered, SecurityAlert
│   │   ├── NotificationStatus.cs      # Pending, Sent, Read, Failed, Cancelled
│   │   ├── DeliveryStatus.cs          # Queued, Delivered, Bounced, Rejected
│   │   ├── DevicePlatform.cs          # Android, Ios, Web
│   │   ├── LogAction.cs               # Dispatch, Retry, Fail, Suppress
│   │   ├── LogLevel.cs                # Information, Warning, Error
│   │   ├── BrokerHealthStatus.cs      # Healthy, Degraded, Unreachable
│   │   └── AuditAction.cs             # Insert, Update, Delete
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Notification.Application/          # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/Extensions/EnumExtensions.cs # Parse Enum an toàn
│   ├── Interfaces/
│   │   ├── INotificationDbContext.cs  # Giao diện DbContext notification_db
│   │   ├── IEmailSenderService.cs     # Hợp đồng gửi email qua SMTP MailKit
│   │   └── IEmailBackgroundQueue.cs   # Hàng đợi Channel cho email nền
│   ├── Services/
│   │   ├── Notifications/             # Tính năng Thông Báo In-App & Thiết Bị
│   │   │   ├── IUserNotificationService.cs, UserNotificationService.cs
│   │   │   ├── NotificationRequests.cs, NotificationResponses.cs, NotificationDtos.cs
│   │   └── Email/                     # Tính năng Gửi Email Trực Tiếp & OTP
│   │       ├── IEmailNotificationService.cs, EmailNotificationService.cs
│   │       ├── EmailRequests.cs, EmailResponses.cs, EmailNotificationDtos.cs
│   └── DependencyInjection.cs         # Đăng ký dịch vụ tầng Application
│
├── Notification.Infrastructure/       # 3. TẦNG HẠ TẦNG (Persistence, SMTP & Background Worker)
│   ├── BackgroundWorkers/
│   │   └── EmailBackgroundWorker.cs   # BackgroundService tiêu thụ hàng đợi email Channel
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Triển khai EF Core DbContext
│   │   ├── Configurations/            # 10 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054922_InitialCreate)
│   │   └── Seeds/NotificationSeedData.cs # Cấu hình kênh thông báo mẫu
│   ├── Services/Email/
│   │   ├── EmailBackgroundQueue.cs    # Triển khai hàng đợi bộ nhớ Channel<EmailWorkItem>
│   │   ├── IEmailService.cs           # Giao diện dịch vụ gửi mail
│   │   ├── MailKitEmailSenderService.cs # Triển khai SMTP qua thư viện MailKit
│   │   └── SmtpOptions.cs             # Cấu hình Host, Port, Username, Password, Ssl
│   └── DependencyInjection.cs         # Đăng ký AppDbContext, Smtp, Background Queue & Worker
│
└── Notification.Api/                  # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   └── NotificationsController.cs
    │   │       # POST   /api/v1/notifications/devices         (Đăng ký device token)
    │   │       # DELETE /api/v1/notifications/devices/{token} (Hủy device token khi logout)
    │   │       # GET    /api/v1/notifications/preferences    (Xem cấu hình nhận thông báo)
    │   │       # PUT    /api/v1/notifications/preferences    (Cập nhật cấu hình nhận tin)
    │   │       # GET    /api/v1/notifications/me             (Xem danh sách thông báo in-app)
    │   │       # PATCH  /api/v1/notifications/me/read         (Đánh dấu đã đọc hàng loạt)
    │   │       # GET    /api/v1/admin/notifications           (Quản trị viên tra cứu lịch sử)
    │   │       # GET    /api/v1/admin/health/broker           (Kiểm tra trạng thái broker/hàng đợi)
    │           # POST /otp  (Gửi email mã OTP xác thực đồng bộ)
    │           # POST /send (Gửi email HTML chung đồng bộ)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── AuthenticationExtensions.cs# Cấu hình JWT Bearer và Claims
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   ├── ObservabilityExtensions.cs # OpenTelemetry tracing
    │   └── SwaggerExtensions.cs       # Đăng ký bảo mật và tài liệu Swagger
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Chưa đăng ký: Internal API tạm khóa
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Quy chuẩn 100% Số Nhiều:** Endpoint collections sử dụng danh từ số nhiều `/api/v1/notifications`, `/api/v1/notifications/devices`, `/api/v1/notifications/preferences`.
2. **Không Dùng Repository Pattern:** Inject trực tiếp `INotificationDbContext` vào `UserNotificationService` và `EmailNotificationService`.
3. **Trạng Thái Public API và Internal API (Internal API tạm khóa từ 2026-10-31):**
   - Xem thông báo, quản lý thiết bị và cài đặt thông báo đặt trong `Controllers/Public/NotificationsController.cs`.
   - Gửi email OTP và email hệ thống đặt trong `Controllers/Public/EmailController.cs`. Không còn `Controllers/Internal/` và không yêu cầu header `X-Internal-Service-Key`, vì `InternalServiceAuthMiddleware` chưa đăng ký.
   - Hệ quả cần kiểm soát: route gửi email hiện đi qua Gateway như API thường. Phải bổ sung xác thực thật hoặc giới hạn tần suất trước khi mở lưu lượng thật để tránh lạm dụng thư điện tử.
4. **Bảo Vệ Danh Tính Người Nhận:** Lấy danh sách thông báo và cập nhật tùy chọn nhận tin bắt buộc trích xuất `userId` từ `HttpContext.GetUserId()`. Cấm truyền `userId` qua query hoặc body.
5. **Định Dạng Email Tiêu Chuẩn:** Mọi nội dung email OTP đều bao gồm mã OTP rõ ràng, thời hạn hiệu lực tính bằng phút và tên người nhận.
