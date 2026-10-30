# 06 — YÊU CẦU QUÊN MẬT KHẨU (FORGOT PASSWORD)

> **Endpoint Gateway:** `POST /api/v1/auth/password/forgot`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/password/forgot`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-strict` (5 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (`otp:password_reset:{email}`), Notification Service (`POST /api/v1/notifications/email/otp`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi email tài khoản cần khôi phục mật khẩu lên Gateway.
2. Gateway kiểm tra định dạng email hợp lệ qua `UserValidation.EnsureEmail`.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` tìm kiếm tài khoản người dùng theo email:
   - Theo nguyên tắc bảo mật chống dò quét tài khoản (User Enumeration Defense): Nếu email không tồn tại hoặc bị cấm, hệ thống vẫn trả về HTTP 200 thành công giả định mà không sinh OTP hay gửi email.
   - Nếu tài khoản tồn tại và hợp lệ: Sinh mã OTP khôi phục 6 chữ số ngẫu nhiên.
5. Lưu mã OTP vào Redis:
   - Key: `otp:password_reset:{email}`
   - Thời hạn hiệu lực: 5 phút.
6. Gửi yêu cầu email tới Notification Service qua cơ chế background queue không đồng bộ.
7. Trả về thông báo hướng dẫn đã gửi mã về hòm thư người dùng trong phong bì `ApiResponse<ForgotPasswordResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Định dạng email hợp lệ RFC 5322, tối đa 255 ký tự |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Email address is invalid." | Email rỗng hoặc sai định dạng RFC 5322 |
| Gateway | `429` | `TOO_MANY_REQUESTS` | "Rate limit exceeded. Please try again later." | Gửi yêu cầu quá 5 lần trong 1 phút |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "email": "tester01@nexus.local"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Password reset instructions have been sent to your email.",
  "data": {
    "email": "tester01@nexus.local"
  },
  "timestamp": "2026-10-30T07:20:00Z",
  "traceId": "0HNPK8LRRV5PM:00000006"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.ForgotPasswordAsync`) sinh mã OTP và lưu Redis key `otp:password_reset:{email}`.
- [x] Áp dụng cơ chế User Enumeration Defense không lộ sự tồn tại của email.
- [x] Gửi email qua Notification Service background queue.
- [x] Gateway Controller (`AuthController.ForgotPassword`) ghép cặp 1-1.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/password-forgot.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
