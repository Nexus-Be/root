# 02 — XÁC THỰC MÃ OTP (VERIFY OTP)

> **Endpoint Gateway:** `POST /api/v1/auth/otp/verify`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/otp/verify`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-strict` (5 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (`otp:registration:{email}`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi email và mã OTP 6 số lên Gateway.
2. Gateway kiểm tra tính hợp lệ cơ bản của dữ liệu qua `UserValidation`.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` tìm kiếm tài khoản theo email trong CSDL PostgreSQL:
   - Nếu tài khoản không tồn tại: Báo lỗi `USER_NOT_FOUND` (HTTP 404).
   - Nếu tài khoản đã `Active`: Bỏ qua xác thực, trả về trạng thái hợp lệ.
5. `User.Api` truy xuất mã OTP lưu trong Redis với key `otp:registration:{email}`:
   - Nếu không tìm thấy hoặc đã hết hạn: Báo lỗi `OTP_EXPIRED` (HTTP 400).
   - Nếu mã OTP đã tiêu thụ trước đó: Báo lỗi `OTP_ALREADY_USED` (HTTP 400).
   - Nếu mã gửi lên không khớp: Báo lỗi `OTP_INVALID` (HTTP 400).
6. Khi mã khớp chính xác:
   - Đánh dấu OTP đã tiêu thụ (`MarkOtpConsumedAsync`).
   - Cập nhật trạng thái người dùng thành `Active`.
   - Ghi nhận thời điểm xác thực email `EmailVerifiedAt = DateTimeOffset.UtcNow`.
   - Lưu các thay đổi xuống CSDL PostgreSQL.
7. Trả về kết quả xác thực thành công trong phong bì `ApiResponse<VerifyOtpResponseDto>` kèm HTTP `200 OK`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Định dạng email hợp lệ, tối đa 255 ký tự |
| `otp` | `string` | Có | Đúng 6 ký tự số |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Email and OTP code are required." | Thiếu trường email hoặc OTP |
| User Service | `400` | `OTP_EXPIRED` | "OTP code has expired or does not exist." | Mã OTP hết hạn hoặc chưa từng sinh |
| User Service | `400` | `OTP_ALREADY_USED` | "This OTP code has already been used." | Mã OTP đã được sử dụng trước đó |
| User Service | `400` | `OTP_INVALID` | "OTP code is invalid." | Nhập sai mã 6 chữ số |
| User Service | `404` | `USER_NOT_FOUND` | "User account not found." | Email không khớp với bất kỳ tài khoản nào |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "email": "tester01@nexus.local",
  "otp": "654321"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Account verified successfully.",
  "data": {
    "isVerified": true,
    "email": "tester01@nexus.local"
  },
  "timestamp": "2026-10-30T07:05:00Z",
  "traceId": "0HNPK8LRRV5PM:00000002"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.VerifyOtpAsync`) kiểm tra Redis TTL & đối soát mã.
- [x] Cập nhật trạng thái người dùng thành `Active` và thời điểm xác thực.
- [x] Gateway Controller (`AuthController.VerifyOtp`) ghép cặp 1-1.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/verify-otp.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
