# 01 — ĐĂNG KÝ TÀI KHOẢN MỚI (REGISTER)

> **Endpoint Gateway:** `POST /api/v1/auth/register`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/register`  
> **Quyền truy cập:** Công khai (`AllowAnonymous`)  
> **Tốc độ giới hạn:** `auth-strict` (5 requests / phút)  
> **Hạ tầng liên quan:** PostgreSQL (`usermanagement_db`), Redis (`otp:registration:{email}`), Notification Service (`POST /api/v1/notifications/email/otp`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi yêu cầu đăng ký qua API Gateway tại cổng `8080`.
2. Gateway thực hiện validate dữ liệu đầu vào cơ bản (`UserValidation`).
3. Gateway chuyển tiếp yêu cầu xuống `User.Api` tại cổng `8001`.
4. `User.Api` kiểm tra tính hợp lệ của email và username trong PostgreSQL:
   - Nếu email đã tồn tại và đang `Active`: Báo lỗi trùng lặp `EMAIL_ALREADY_EXISTS` (HTTP 409).
   - Nếu username đã tồn tại: Báo lỗi `USERNAME_ALREADY_EXISTS` (HTTP 409).
   - Nếu email đã đăng ký nhưng chưa xác thực (`PendingVerification`): Ghi đè thông tin mới và hủy OTP cũ.
5. Băm mật khẩu bằng BCrypt có Salt (`BCrypt.Net-Next`).
6. Tạo người dùng với vai trò mặc định `Buyer`, điểm uy tín khởi tạo `50` (TrustLevel: `Standard`).
7. Sinh mã OTP ngẫu nhiên 6 chữ số và lưu vào Redis:
   - Key: `otp:registration:{email}`
   - Thời hạn hiệu lực: 5 phút.
8. Gửi yêu cầu dispatch email OTP tới Notification Service (`POST /api/v1/notifications/email/otp`).
   - Notification Service đưa công việc vào Background Queue và phản hồi HTTP 200 ngay lập tức, không làm tắc nghẽn luồng đăng ký của UserService.
9. Trả về thông tin người dùng vừa đăng ký trong phong bì `ApiResponse<RegisterResponseDto>` kèm HTTP `201 Created`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `email` | `string` | Có | Định dạng email hợp lệ RFC 5322, tối đa 255 ký tự |
| `password` | `string` | Có | Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường và số |
| `username` | `string` | Không | 3 - 50 ký tự chữ và số, không chứa ký tự đặc biệt |
| `firstName` | `string` | Có | Tối đa 100 ký tự |
| `lastName` | `string` | Có | Tối đa 100 ký tự |
| `phoneNumber` | `string` | Không | Định dạng số điện thoại chuẩn quốc tế hoặc nội địa |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_INPUT` | "Username, valid email, and password with at least 8 characters are required." | Thiếu trường bắt buộc hoặc độ dài không hợp lệ |
| User Service | `400` | `VAL_INVALID_EMAIL` | "Email address is invalid." | Email không đúng định dạng RFC 5322 |
| User Service | `400` | `VAL_INVALID_PASSWORD` | "Password must be at least 8 characters." | Mật khẩu ngắn hơn 8 ký tự |
| User Service | `409` | `EMAIL_ALREADY_EXISTS` | "Email is already registered in the system." | Email đã thuộc về tài khoản đang hoạt động |
| User Service | `409` | `USERNAME_ALREADY_EXISTS` | "Username is already taken by another account." | Tên người dùng đã được sử dụng |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "username": "tester01",
  "email": "tester01@nexus.local",
  "password": "Password123!",
  "firstName": "Nguyen",
  "lastName": "Van A",
  "phoneNumber": "0912345678"
}
```

### 4.2 Response Payload (201 Created)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "User registered successfully.",
  "data": {
    "userId": "e43b1853-bc2a-4b68-b789-9e8c459a1234",
    "email": "tester01@nexus.local",
    "otpExpiresIn": 300
  },
  "timestamp": "2026-10-30T07:00:00Z",
  "traceId": "0HNPK8LRRV5PM:00000001"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.RegisterAsync`) băm mật khẩu BCrypt & tạo record DB.
- [x] Sinh mã OTP và lưu trữ Redis TTL 5 phút (`IRedisOtpService.SaveOtpAsync`).
- [x] Gọi Notification Service gửi email OTP qua background worker non-blocking.
- [x] Gateway Controller (`AuthController.Register`) ghép cặp 1-1, định tuyến downstream.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/register.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
