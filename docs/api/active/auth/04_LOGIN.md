# 04 — ĐĂNG NHẬP HỆ THỐNG (LOGIN)

> **Endpoint Gateway:** `POST /api/v1/auth/login`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/login`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-login` (10 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (Khóa tài khoản chống brute force), JWT Symmetric Key  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi tên định danh (Username hoặc Email) và mật khẩu lên API Gateway.
2. Gateway kiểm tra thông tin đầu vào cơ bản và chuyển tiếp yêu cầu xuống `User.Api`.
3. `User.Api` kiểm tra khóa tài khoản tạm thời trong Redis:
   - Nếu tài khoản đang bị khóa do 5 lần nhập sai liên tiếp: Báo lỗi `ERR_ACCOUNT_LOCKED_TEMPORARY` (HTTP 423 Locked).
4. `User.Api` truy vấn thông tin người dùng trong PostgreSQL:
   - Nếu không tìm thấy tài khoản hoặc tài khoản đã bị xóa mềm (`IsDeleted = true`): Tăng số lần thử sai trong Redis, nếu đạt 5 lần thì khóa 30 phút; báo lỗi `ERR_INVALID_CREDENTIALS` (HTTP 401).
   - Nếu tài khoản ở trạng thái `PendingVerification`: Báo lỗi `ERR_ACCOUNT_NOT_VERIFIED` (HTTP 403 Forbidden).
   - Nếu tài khoản bị khóa vĩnh viễn (`Banned`): Báo lỗi `ERR_ACCOUNT_BANNED` (HTTP 403 Forbidden).
5. Xác thực mật khẩu qua BCrypt (`BCrypt.Net.BCrypt.Verify`):
   - Nếu sai mật khẩu: Tăng số lần nhập sai, báo lỗi `ERR_INVALID_CREDENTIALS` (HTTP 401).
6. Khi xác thực thành công:
   - Xóa lịch sử số lần thử sai trong Redis.
   - Cấp phát JWT Access Token với thời hạn 60 phút, chứa các claims: `sub` (UserId), `email`, `role`, `jti`, `exp`.
   - Cấp phát Refresh Token dài hạn (7 ngày), lưu hash SHA-256 vào bảng `RefreshTokens`.
7. Gateway thiết lập header `Cache-Control: no-store` và trả về phong bì `ApiResponse<LoginResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `username` / `identifier` | `string` | Có | Tên người dùng hoặc Email tài khoản |
| `password` | `string` | Có | Mật khẩu tài khoản |
| `deviceInfo` | `string` | Không | Thông tin thiết bị đăng nhập |
| `ipAddress` | `string` | Không | Địa chỉ IP của client |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Username and password are required." | Thiếu tên đăng nhập hoặc mật khẩu |
| User Service | `401` | `ERR_INVALID_CREDENTIALS` | "Invalid username, email, or password." | Sai thông tin tài khoản hoặc mật khẩu |
| User Service | `403` | `ERR_ACCOUNT_NOT_VERIFIED` | "Account has not been verified with OTP." | Tài khoản chưa hoàn tất xác thực OTP |
| User Service | `403` | `ERR_ACCOUNT_BANNED` | "Account has been locked or banned by an administrator." | Tài khoản bị cấm hoạt động |
| User Service | `423` | `ERR_ACCOUNT_LOCKED_TEMPORARY` | "Account is temporarily locked for 30 minutes due to 5 consecutive failed login attempts." | Nhập sai mật khẩu 5 lần liên tiếp |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "identifier": "tester01@nexus.local",
  "password": "Password123!"
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Login successful.",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "7f8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b...",
    "tokenType": "Bearer",
    "expiresIn": 3600,
    "user": {
      "id": "e43b1853-bc2a-4b68-b789-9e8c459a1234",
      "email": "tester01@nexus.local",
      "username": "tester01",
      "firstName": "Nguyen",
      "lastName": "Van A",
      "roles": ["buyer"],
      "permissions": []
    }
  },
  "timestamp": "2026-10-30T07:10:00Z",
  "traceId": "0HNPK8LRRV5PM:00000004"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.LoginAsync`) kiểm tra BCrypt, Redis lockout và cấp token.
- [x] Lưu trữ Refresh Token vào PostgreSQL với SHA-256 hash.
- [x] Gateway Controller (`AuthController.Login`) ghép cặp 1-1, gắn header `Cache-Control: no-store`.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/login.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
