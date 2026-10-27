# 🔐 ACTIVE APIS: AUTH CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua cURL trên Gateway cổng `8080` ngày 2026-10-28)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/AuthController.cs`  
> **Backend Service:** `User.Api` (Cổng `8001`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (Neon DB), Redis (`nexus-shared-redis:6379`), RabbitMQ (`nexus-shared-rabbitmq:5672`), Notification Service (`nexus-notification-service:8007`)

---

## 1. ĐĂNG KÝ TÀI KHOẢN MỚI (REGISTER)

- **Endpoint Gateway:** `POST /api/v1/auth/register`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/register`
- **Luồng xử lý ngầm:**
  1. `User.Api` kiểm tra trùng lặp email và username trong PostgreSQL.
  2. Băm mật khẩu bằng BCrypt có Salt.
  3. Tạo bản ghi người dùng với trạng thái `PendingVerification`.
  4. Sinh mã OTP 6 số lưu vào Redis với key `otp:registration:{email}` (TTL 5 phút).
  5. Phát sự kiện `SendOtpEmailIntegrationEvent` qua MassTransit Outbox lên RabbitMQ exchange `user.events`.
  6. `Notification.Api` lắng nghe sự kiện qua `SendOtpEmailConsumer` và gửi email OTP.

### Request Headers
```http
POST /api/v1/auth/register HTTP/1.1
Host: localhost:8080
Content-Type: application/json
X-Gateway-Mode: Real
```

### Request Body
```json
{
  "username": "user_gateway_final",
  "email": "user_gateway_final@example.com",
  "password": "Password123@",
  "firstName": "Gateway",
  "lastName": "Final",
  "phoneNumber": "0987654321"
}
```

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "User registered successfully.",
  "data": {
    "id": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "email": "user_gateway_final@example.com",
    "displayName": "Gateway Final",
    "shopName": "",
    "status": "PendingVerification",
    "roles": [
      "buyer"
    ]
  },
  "timestamp": "2026-10-27T16:16:02Z",
  "traceId": "0HNPK8LRRV5PM:00000001"
}
```

### Lệnh cURL Kiểm Chứng
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d '{
    "username": "user_gateway_final",
    "email": "user_gateway_final@example.com",
    "password": "Password123@",
    "firstName": "Gateway",
    "lastName": "Final",
    "phoneNumber": "0987654321"
  }'
```

---

## 2. XÁC THỰC MÃ OTP (VERIFY OTP)

- **Endpoint Gateway:** `POST /api/v1/auth/otp/verify`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/otp/verify`
- **Luồng xử lý ngầm:**
  1. `User.Api` lấy mã OTP từ Redis key `otp:registration:{email}`.
  2. So sánh mã OTP gửi lên và kiểm tra thời hạn (TTL 5 phút).
  3. Cập nhật trạng thái người dùng trong CSDL PostgreSQL thành `Active`.
  4. Xóa mã OTP đã tiêu thụ khỏi Redis.

### Request Headers
```http
POST /api/v1/auth/otp/verify HTTP/1.1
Host: localhost:8080
Content-Type: application/json
X-Gateway-Mode: Real
```

### Request Body
```json
{
  "email": "user_gateway_final@example.com",
  "otp": "794126"
}
```
*(Ghi chú: Gateway chấp nhận cả trường `otp` và `otp_code`)*

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Account verified successfully.",
  "data": {
    "id": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "username": "user_gateway_final",
    "email": "user_gateway_final@example.com",
    "displayName": "Gateway Final",
    "firstName": "Gateway",
    "lastName": "Final",
    "phoneNumber": "0987654321",
    "avatarUrl": null,
    "address": null,
    "shopName": "",
    "status": "Active",
    "trustLevel": "Standard",
    "reputationScore": 50,
    "roles": [
      "buyer"
    ]
  },
  "timestamp": "2026-10-27T16:16:59Z",
  "traceId": "0HNPK8LRRV5PP:00000001"
}
```

### Lệnh cURL Kiểm Chứng
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/otp/verify \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d '{"email":"user_gateway_final@example.com","otp":"794126"}'
```

---

## 3. GỬI LẠI MÃ OTP (RESEND OTP)

- **Endpoint Gateway:** `POST /api/v1/auth/otp/resend`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/otp/resend`
- **Luồng xử lý ngầm:**
  1. Kiểm tra tài khoản tồn tại trong PostgreSQL.
  2. Sinh mã OTP mới, gia hạn TTL 5 phút trong Redis.
  3. Bắn event `SendOtpEmailIntegrationEvent` qua RabbitMQ để `Notification.Api` gửi email mới.

### Request Body
```json
{
  "email": "user_gateway_final@example.com"
}
```

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "OTP code has been resent successfully.",
  "data": {
    "email": "user_gateway_final@example.com",
    "expiresInSeconds": 300
  }
}
```

### Lệnh cURL Kiểm Chứng
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/otp/resend \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d '{"email":"user_gateway_final@example.com"}'
```

---

## 4. ĐĂNG NHẬP (LOGIN)

- **Endpoint Gateway:** `POST /api/v1/auth/login`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/login`
- **Luồng xử lý ngầm:**
  1. Kiểm tra thông tin đăng nhập (Username / Email và Password) trong PostgreSQL.
  2. Xác thực mật khẩu qua BCrypt.
  3. Cấp phát JWT Access Token mang các claims chuẩn:
     - `sub`: ID người dùng (UUID).
     - `email`: Địa chỉ email.
     - `role`: Danh sách vai trò (`buyer`, `seller`, `admin`...).
     - `jti`: Token identifier ngẫu nhiên.
     - `exp`: Thời hạn token (1 giờ).
  4. Cấp phát Refresh Token dài hạn.

### Request Body
```json
{
  "username": "user_gateway_final",
  "password": "Password123@"
}
```
*(Ghi chú: Có thể truyền email vào trường `username` hoặc `identifier`)*

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Login successful.",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1MDFkMTFlNy1jM2M0LTQ0YTMtOGMwNy02ZWY3NDlkOWRjODYiLCJlbWFpbCI6InVzZXJfZ2F0ZXdheV9maW5hbEBleGFtcGxlLmNvbSIsIm5hbWUiOiJHYXRld2F5IEZpbmFsIiwianRpIjoiMjYwZGNlYWEtZmE0OS00ODY1LWI5ZTMtNWU4YzMzMmRmNWVlIiwicm9sZSI6ImJ1eWVyIiwibmJmIjoxNzkzMTE3ODI0LCJleHAiOjE3OTMxMjE0MjQsImlzcyI6Imh0dHA6Ly9sb2NhbGhvc3Q6ODAwMSIsImF1ZCI6InNob3BwaW5nY2FydC1hcGkifQ.igd-Nhh-mitjFoVMVozD-brhK421YEiDSrXgULS4G9M",
    "refreshToken": "BYOCFnPJ9iKhsISOPYTpi9fRufmFQx9ZlaLtFdH1D3zWllS1WBJyudEY40_wsgk2WO1CO8Isz_EVsVnivAaT5Q",
    "userId": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "roles": [
      "buyer"
    ],
    "expiresAt": "2026-10-27T17:17:04.6354821Z"
  },
  "timestamp": "2026-10-27T16:17:04Z",
  "traceId": "0HNPK8LRRV5PQ:00000001"
}
```

### Lệnh cURL Kiểm Chứng
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Mode: Real" \
  -d '{"username":"user_gateway_final","password":"Password123@"}'
```
