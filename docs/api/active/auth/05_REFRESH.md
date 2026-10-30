# 05 — LÀM MỚI ACCESS TOKEN (REFRESH TOKEN ROTATION)

> **Endpoint Gateway:** `POST /api/v1/auth/refresh`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/refresh`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-login` (10 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`RefreshTokens`), JWT Symmetric Key  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi `refreshToken` lên Gateway khi `accessToken` sắp hết hạn hoặc đã hết hạn.
2. Gateway kiểm tra `refreshToken` không được rỗng thông qua `UserValidation`.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` băm SHA-256 chuỗi refresh token gửi lên và tìm kiếm trong bảng `RefreshTokens`:
   - Nếu không tìm thấy: Báo lỗi `REFRESH_TOKEN_INVALID` (HTTP 401).
   - Nếu token đã bị thu hồi (`IsRevoked = true`): Báo lỗi `REFRESH_TOKEN_REVOKED` (HTTP 401).
   - Nếu token đã quá hạn (`ExpiresAt < DateTimeOffset.UtcNow`): Báo lỗi `REFRESH_TOKEN_EXPIRED` (HTTP 401).
5. Kiểm tra trạng thái tài khoản người dùng tương ứng:
   - Nếu người dùng bị xóa mềm hoặc bị cấm (`Banned`): Lập tức thu hồi token và báo lỗi `ACCOUNT_INACTIVE` (HTTP 403).
6. Áp dụng cơ chế **Refresh Token Rotation (RTR)**:
   - Đánh dấu token cũ đã bị thu hồi (`IsRevoked = true`, `RevokedAt = DateTimeOffset.UtcNow`).
   - Cấp phát một Refresh Token hoàn toàn mới và lưu hash SHA-256 vào CSDL.
   - Cấp phát Access Token mới có thời hạn 60 phút.
7. Gateway thiết lập header `Cache-Control: no-store` và trả về phong bì `ApiResponse<RefreshTokenResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `refreshToken` | `string` | Có | Chuỗi refresh token hợp lệ |
| `deviceInfo` | `string` | Không | Thông tin thiết bị thực hiện làm mới |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Refresh token is required." | Trường `refreshToken` bị để trống |
| User Service | `401` | `REFRESH_TOKEN_INVALID` | "Refresh token is invalid or does not exist." | Không tìm thấy token trong CSDL |
| User Service | `401` | `REFRESH_TOKEN_EXPIRED` | "Refresh token has expired." | Token đã quá hạn 7 ngày |
| User Service | `401` | `REFRESH_TOKEN_REVOKED` | "Refresh token has been revoked." | Token đã bị thu hồi hoặc đã từng sử dụng |
| User Service | `403` | `ACCOUNT_INACTIVE` | "User account is suspended or no longer active." | Tài khoản người dùng bị cấm hoạt động |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "refreshToken": "7f8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b..."
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Token refreshed successfully.",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b...",
    "expiresIn": 3600
  },
  "timestamp": "2026-10-30T07:15:00Z",
  "traceId": "0HNPK8LRRV5PM:00000005"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.RefreshTokenAsync`) thực hiện Refresh Token Rotation (RTR).
- [x] Thu hồi token cũ và phát hành cặp token mới.
- [x] Gateway Controller (`AuthController.Refresh`) ghép cặp 1-1, gắn header `Cache-Control: no-store`.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/refresh.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
