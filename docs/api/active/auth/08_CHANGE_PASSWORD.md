# 08 — ĐỔI MẬT KHẨU TÀI KHOẢN (CHANGE PASSWORD)

> **Endpoint Gateway:** `PATCH /api/v1/auth/password`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `PATCH /api/v1/auth/password`  
> **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)  
> **Yêu cầu Headers:** `Authorization: Bearer <accessToken>`  
> **Hạ tầng liên quan:** PostgreSQL (`Users`, `RefreshTokens`), BCrypt Password Hash  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client đã đăng nhập gửi `oldPassword`, `newPassword`, và `confirmPassword` kèm Bearer Token lên Gateway.
2. Gateway kiểm tra token JWT hợp lệ và validate:
   - `oldPassword` không được rỗng.
   - `newPassword` tối thiểu 8 ký tự.
   - `newPassword` và `confirmPassword` phải trùng khớp.
3. Gateway trích xuất `sub` từ JWT, gán vào header `x-user-id` và chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` đọc `x-user-id`:
   - Nếu không có: Báo lỗi `VAL_INVALID_USER_ID` (HTTP 400).
5. `User.Api` truy vấn tài khoản người dùng trong CSDL:
   - Nếu không tìm thấy: Báo lỗi `USER_NOT_FOUND` (HTTP 404).
   - Nếu tài khoản bị cấm (`Banned`): Báo lỗi `ACCOUNT_INACTIVE` (HTTP 403).
6. So sánh `oldPassword` với mật khẩu hiện tại bằng BCrypt:
   - Nếu không khớp: Báo lỗi `ERR_INVALID_OLD_PASSWORD` (HTTP 400).
   - Nếu `newPassword` trùng với mật khẩu cũ: Báo lỗi `ERR_PASSWORD_SAME_AS_OLD` (HTTP 400).
7. Cập nhật `PasswordHash` mới băm bằng BCrypt có Salt.
8. Thu hồi toàn bộ Refresh Token cũ của người dùng trong bảng `RefreshTokens` để bảo vệ an toàn tài khoản.
9. Trả về thông báo đổi mật khẩu thành công trong phong bì `ApiResponse<ChangePasswordResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `oldPassword` | `string` | Có | Mật khẩu hiện tại của người dùng |
| `newPassword` | `string` | Có | Tối thiểu 8 ký tự, phải khác `oldPassword` |
| `confirmPassword` | `string` | Có | Phải trùng khớp 100% với `newPassword` |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Password confirmation does not match." | Mật khẩu xác nhận không khớp |
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Password must be at least 8 characters long." | Mật khẩu mới quá ngắn |
| User Service | `400` | `ERR_INVALID_OLD_PASSWORD` | "Old password is incorrect." | Nhập sai mật khẩu hiện tại |
| User Service | `400` | `ERR_PASSWORD_SAME_AS_OLD` | "New password must be different from the old password." | Mật khẩu mới trùng mật khẩu cũ |
| Gateway | `401` | `UNAUTHORIZED` | "Unauthorized access. Bearer token missing or invalid." | Thiếu hoặc sai access token |
| User Service | `404` | `USER_NOT_FOUND` | "User account not found." | Người dùng không tồn tại |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "oldPassword": "Password123!",
  "newPassword": "FinalPassword123!",
  "confirmPassword": "FinalPassword123!"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Password changed successfully.",
  "data": {
    "success": true
  },
  "timestamp": "2026-10-30T07:30:00Z",
  "traceId": "0HNPK8LRRV5PM:00000008"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.ChangePasswordAsync`) xác thực BCrypt & thu hồi Refresh Token.
- [x] Gateway Controller (`AuthController.ChangePassword`) gán quyền `GatewayPolicies.Authenticated` & truyền danh tính `x-user-id`.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/password-change.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
