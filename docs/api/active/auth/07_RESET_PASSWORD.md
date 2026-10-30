# 07 — ĐẶT LẠI MẬT KHẨU BẰNG OTP (RESET PASSWORD)

> **Endpoint Gateway:** `PUT /api/v1/auth/password/reset`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `PUT /api/v1/auth/password/reset`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-strict` (5 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (`otp:password_reset:{email}`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi thông tin đặt lại mật khẩu gồm `email`, `otpCode`, `newPassword` và `confirmPassword` lên Gateway.
2. Gateway thực hiện validate:
   - Email hợp lệ.
   - OTP đúng 6 ký tự số.
   - Mật khẩu mới tối thiểu 8 ký tự.
   - `newPassword` và `confirmPassword` phải trùng khớp tuyệt đối.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` xác minh thông tin tài khoản và mã OTP trong Redis:
   - Kiểm tra mã OTP trong Redis key `otp:password_reset:{email}`: nếu không tồn tại hoặc hết hạn -> Báo lỗi `OTP_EXPIRED` (HTTP 400).
   - Nếu mã OTP gửi lên không khớp -> Báo lỗi `OTP_INVALID` (HTTP 400).
   - Nếu OTP đã từng tiêu thụ -> Báo lỗi `OTP_ALREADY_USED` (HTTP 400).
5. Khi mã hợp lệ:
   - Đánh dấu mã OTP đã tiêu thụ trong Redis.
   - Băm mật khẩu mới bằng BCrypt có Salt.
   - Cập nhật `PasswordHash` của người dùng và `UpdatedAt = DateTimeOffset.UtcNow`.
   - **Bảo mật phiên**: Thu hồi toàn bộ Refresh Token hiện có của người dùng trong bảng `RefreshTokens` để đăng xuất mọi phiên đăng nhập trên các thiết bị cũ.
6. Trả về thông báo hoàn tất đặt lại mật khẩu trong phong bì `ApiResponse<ResetPasswordResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Định dạng email hợp lệ RFC 5322 |
| `otpCode` | `string` | Có | Đúng 6 ký tự số |
| `newPassword` | `string` | Có | Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số |
| `confirmPassword` | `string` | Có | Phải trùng khớp 100% với `newPassword` |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Password confirmation does not match." | Mật khẩu xác nhận không khớp |
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "OTP code must be exactly 6 digits." | Mã OTP không đủ 6 chữ số |
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Password must be at least 8 characters long." | Mật khẩu mới quá ngắn |
| User Service | `400` | `OTP_EXPIRED` | "OTP code has expired or does not exist." | Mã OTP hết hạn 5 phút |
| User Service | `400` | `OTP_INVALID` | "OTP code is invalid." | Nhập sai mã OTP |
| User Service | `404` | `USER_NOT_FOUND` | "User account not found." | Không tìm thấy tài khoản người dùng |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "email": "tester01@nexus.local",
  "otpCode": "654321",
  "newPassword": "NewPassword123!",
  "confirmPassword": "NewPassword123!"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Password has been reset successfully.",
  "data": {
    "success": true
  },
  "timestamp": "2026-10-30T07:25:00Z",
  "traceId": "0HNPK8LRRV5PM:00000007"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.ResetPasswordAsync`) kiểm tra OTP Redis & cập nhật BCrypt hash.
- [x] Tự động thu hồi mọi phiên Refresh Token cũ khi đổi mật khẩu thành công.
- [x] Gateway Controller (`AuthController.ResetPassword`) ghép cặp 1-1, kiểm tra khớp mật khẩu xác nhận.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/password-reset.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
