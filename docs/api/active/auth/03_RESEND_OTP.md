# 03 — GỬI LẠI MÃ OTP (RESEND OTP)

> **Endpoint Gateway:** `POST /api/v1/auth/otp/resend`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/otp/resend`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-strict` (5 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (`otp:registration:{email}`), Notification Service (`POST /api/v1/notifications/email/otp`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi yêu cầu gửi lại OTP kèm email tài khoản.
2. Gateway kiểm tra tính hợp lệ của email.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` tìm kiếm tài khoản trong CSDL:
   - Nếu không tìm thấy: Báo lỗi `USER_NOT_FOUND` (HTTP 404).
   - Nếu tài khoản đã `Active`: Vẫn cho phép sinh lại mã phục vụ các tình huống bảo mật.
5. Kiểm tra thời gian giãn cách (cooldown) để chống spam: Cooldown mặc định 60 giây.
6. Sinh mã OTP 6 chữ số mới và ghi đè vào Redis với thời hạn 5 phút.
7. Đẩy yêu cầu gửi email OTP tới Notification Service (thực hiện qua hàng đợi background non-blocking).
8. Trả về thông tin thời gian cooldown 60 giây cho client để hiển thị đồng hồ đếm ngược.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Định dạng email hợp lệ RFC 5322 |
| `type` | `string` | Không | Loại OTP cần gửi lại (`REGISTER` hoặc `PASSWORD_RESET`) |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Email address is required." | Email bị để trống hoặc sai định dạng |
| User Service | `404` | `USER_NOT_FOUND` | "User account not found." | Email không tồn tại trong hệ thống |
| Gateway | `429` | `TOO_MANY_REQUESTS` | "Rate limit exceeded. Please try again later." | Gửi yêu cầu quá 5 lần trong 1 phút |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "email": "tester01@nexus.local",
  "type": "REGISTER"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Verification code has been resent to your email.",
  "data": {
    "email": "tester01@nexus.local",
    "resendCooldown": 60
  },
  "timestamp": "2026-10-30T07:06:00Z",
  "traceId": "0HNPK8LRRV5PM:00000003"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.ResendOtpAsync`) sinh mã OTP mới & lưu trữ Redis.
- [x] Gửi yêu cầu email sang Notification Service qua cơ chế non-blocking.
- [x] Gateway Controller (`AuthController.ResendOtp`) ghép cặp 1-1.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/resend-otp.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
