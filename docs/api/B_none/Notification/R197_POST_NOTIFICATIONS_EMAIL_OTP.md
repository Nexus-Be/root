# [POST] /api/v1/notifications/email/otp

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Email`  
> **Mã tham chiếu Excel:** `NOTI-07`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Gửi email chứa mã xác thực OTP phục vụ quy trình đăng ký, đăng nhập, hoặc quên mật khẩu
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/notifications/email/otp`
* **Quyền hạn truy cập (RBAC):** Công khai / Liên dịch vụ (gọi trực tiếp từ `UserService` hoặc các client đăng ký)
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `notifications-route`)
* **Controller Action:** `Notification.Api/Controllers/Public/EmailController.cs` $\rightarrow$ `SendOtpEmail()`
* **Application Interface:** `Notification.Application/Services/Email/IEmailNotificationService.cs` $\rightarrow$ `SendOtpEmailAsync()`
* **Service Implementation:** `Notification.Application/Services/Email/EmailNotificationService.cs` $\rightarrow$ `SendOtpEmailAsync()`
* **Infrastructure Sender:** `Notification.Infrastructure/Services/MailKitEmailSenderService.cs`

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters & Query Parameters
*Không có tham số route hoặc query.*

### 3.2. Request Body (JSON Payload)
```json
{
  "email": "buyer@example.com",
  "fullName": "Nguyen Van A",
  "otpCode": "123456",
  "expiresInMinutes": 5
}
```

* **Quy chuẩn Validation:**
  - `email`: Bắt buộc, chuỗi email hợp lệ chứa ký tự `@`.
  - `otpCode`: Bắt buộc, không được để trống.
  - `fullName`: Tùy chọn, mặc định "Customer" nếu để trống.
  - `expiresInMinutes`: Tùy chọn, mặc định 5 phút nếu không truyền hoặc $\le 0$.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK`)
```json
{
  "success": true,
  "message": "OTP verification email dispatched successfully.",
  "data": {
    "recipient": "buyer@example.com",
    "fullName": "Nguyen Van A",
    "expiresInMinutes": 5,
    "dispatchedAt": "2026-11-02T02:30:00Z"
  }
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_EMAIL` | "Recipient email is required and must be a valid email address." | Email rỗng, thiếu hoặc không chứa ký tự `@`. |
| `400` | `VAL_INVALID_OTP` | "OTP code cannot be empty." | Mã OTP rỗng hoặc thiếu. |
| `500` | `EMAIL_SEND_FAILED` | "Failed to deliver OTP email via notification provider." | MailKit SMTP provider ném ngoại lệ khi gửi mail. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. CHECKLIST HOÀN THÀNH & NGHIỆM THU

- [x] **1. Tầng Application:** `IEmailNotificationService.cs` và `EmailNotificationService.cs` đã được triển khai hoàn chỉnh.
- [x] **2. Tầng Api:** `EmailController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [x] **4. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (`EmailControllerTests.cs`).
- [x] **5. Định tuyến Gateway:** Đi qua YARP `notifications-route` tại Gateway.
