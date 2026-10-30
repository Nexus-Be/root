# 🔔 ACTIVE APIS: NOTIFICATION CONTROLLERS (EMAIL & NOTIFICATIONS)

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua 12 unit/integration tests trên NotificationService `8007` ngày 2026-10-30)  
> **Gateway Controller:** `Nexus.Gateway/Controllers/NotificationController.cs`  
> **Backend Service:** `Notification.Api` (Cổng `8007`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`notification_db`), MailKit/MimeKit `4.18.2` (SMTP), In-App Notifications

---

## 1. GỬI EMAIL CHỨA MÃ OTP (SEND OTP EMAIL)

- **Endpoint Microservice:** `POST /api/v1/notifications/email/otp`
- **Quyền truy cập:** Nội bộ / Không yêu cầu JWT
- **Được gọi bởi:** `UserService.Infrastructure/Services/Notification/EmailNotificationClient.cs`

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Địa chỉ email hợp lệ |
| `otp` | `string` | Có | Mã OTP xác thực |
| `type` | `string` | Không | Loại OTP ("Registration", "PasswordReset") |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Valid recipient email is required." | Email rỗng hoặc sai format |
| `500` | `EMAIL_SEND_FAILED` | "Failed to dispatch email notification." | Lỗi kết nối SMTP server |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`EmailNotificationService.cs`) định dạng template email.
- [x] Infrastructure Service (`MailKitEmailSenderService.cs`) gửi qua SMTP.
- [x] Unit test (`EmailNotificationServiceTests.cs`, `EmailControllerTests.cs`, `EmailSenderTests.cs`) pass 100%.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. ĐĂNG KÝ DEVICE TOKEN (REGISTER DEVICE)

- **Endpoint Gateway:** `POST /api/v1/notifications/devices`
- **Endpoint Microservice:** `POST /api/v1/notifications/devices`
- **Quyền truy cập:** Đã xác thực (`[Authorize(GatewayPolicies.Authenticated)]`)

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `token` | `string` | Có | Device Token FCM / APNS |
| `platform` | `string` | Có | WEB, IOS, hoặc ANDROID |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Device token cannot be empty." | Token rỗng |
| `400` | `VAL_INVALID_INPUT` | "Platform must be WEB, IOS, or ANDROID." | Platform sai enum |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`UserNotificationService.cs`) upsert `DeviceToken`.
- [x] Thin Controller (`NotificationsController.cs`) ghép cặp 1-to-1, không query DB trực tiếp.
- [x] Gateway routing & Seed fixture (`Seeds/notification/device-register.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 3. THU HỒI DEVICE TOKEN KHI LOGOUT (REVOKE DEVICE)

- **Endpoint Gateway:** `DELETE /api/v1/notifications/devices/{token}`
- **Endpoint Microservice:** `DELETE /api/v1/notifications/devices/{token}`
- **Quyền truy cập:** Đã xác thực (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Phản hồi:** HTTP `204 NoContent`

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`UserNotificationService.cs`) đánh dấu `IsActive = false`.
- [x] Thin Controller (`NotificationsController.cs`) trả về `204 NoContent`.
- [x] Trạng thái: `✅ COMPLETED`

---

## 4. TÙY CHỌN NHẬN THÔNG BÁO (GET / UPDATE PREFERENCES)

- **Endpoint Gateway:** `GET /api/v1/notifications/preferences` và `PUT /api/v1/notifications/preferences`
- **Quyền truy cập:** Đã xác thực (`[Authorize(GatewayPolicies.Authenticated)]`)

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`UserNotificationService.cs`) quản lý tùy chọn thông báo.
- [x] Thin Controller (`NotificationsController.cs`) ghép cặp 1-to-1.
- [x] Trạng thái: `✅ COMPLETED`

---

## 5. THÔNG BÁO IN-APP CỦA TÔI (GET NOTIFICATIONS & MARK AS READ)

- **Endpoint Gateway:** `GET /api/v1/notifications/me` và `PATCH /api/v1/notifications/me/read`
- **Quyền truy cập:** Đã xác thực (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Ghi chú Route:** Đã xóa sạch duplicate alias `notifications/read-all`, chỉ giữ route chính thức duy nhất `PATCH /api/v1/notifications/me/read`.

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`UserNotificationService.cs`) query phân trang và đánh dấu đọc.
- [x] Thin Controller (`NotificationsController.cs`) ghép cặp 1-to-1, route chính thức duy nhất.
- [x] Trạng thái: `✅ COMPLETED`
