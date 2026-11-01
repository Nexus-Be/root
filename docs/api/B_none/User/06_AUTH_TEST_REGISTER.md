# [POST] /api/v1/users/auth/test

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Auth`  
> **Mã tham chiếu:** `TEST-AUTH-REGISTER`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-01`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Endpoint kiểm thử đăng ký tài khoản nhanh (chỉ cần truyền `email` và `password`). Hệ thống tự động tạo người dùng ở trạng thái `PendingVerification`, gán vai trò `Buyer`, sinh mã OTP 6 số lưu vào Redis (hết hạn 5 phút), và gọi `NotificationService` qua Typed REST Client để gửi email OTP.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/users/auth/test`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi `Idempotency-Key: UUIDv4`)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/` (Cổng: `8001`)
* **Cổng Gateway điều phối:** `src/Services/Gateway/` (Cổng: `8080`, Route: `users-route` forward sang `user-cluster:8001`)
* **Controller Action:** `src/Services/User/User.Api/Controllers/Public/AuthController.cs` $\rightarrow$ `RegisterTest()`
* **Application Interface:** `src/Services/User/User.Application/Services/Auth/IAuthService.cs` $\rightarrow$ `RegisterTestUserAsync()`
* **Service Implementation:** `src/Services/User/User.Application/Services/Auth/AuthService.cs` $\rightarrow$ `RegisterTestUserAsync()` (tái sử dụng `RegisterAsync()`)
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL (`usermanagement_db:5433`)
* **Typed HTTP Client:** `src/Services/User/User.Application/Interfaces/IEmailNotificationClient.cs` $\rightarrow$ `POST /api/v1/notifications/email/otp` trên `NotificationService` (Cổng: `8007`)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
{
  "email": "string (required, email format)",
  "password": "string (required, tối thiểu 8 ký tự)"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### Phản hồi thành công (HTTP 201 Created)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Operation completed successfully.",
  "data": {
    "success": true,
    "message": "Test user registered with PendingVerification status and Buyer role. OTP dispatched.",
    "userId": "11111111-1111-1111-1111-000000000001",
    "email": "testuser@nexus.local",
    "status": "PendingVerification",
    "role": "Buyer",
    "otpSent": true,
    "otpExpiresIn": 300
  },
  "traceId": "0HNPGT7G285Q2",
  "timestamp": "2026-11-01T04:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Mã lỗi (`errorCode`) | Chuỗi thông báo (`message`) | Điều kiện kích hoạt |
| :--- | :--- | :--- | :--- |
| `400 Bad Request` | `VAL_INVALID_INPUT` | `Request payload cannot be empty.` | Request body bị rỗng |
| `400 Bad Request` | `VAL_INVALID_EMAIL` | `Email address is invalid.` | Email để trống hoặc sai định dạng regex |
| `400 Bad Request` | `VAL_INVALID_PASSWORD` | `Password must be at least 8 characters.` | Password ngắn hơn 8 ký tự |
| `409 Conflict` | `EMAIL_ALREADY_EXISTS` | `Email is already registered in the system.` | Email đã đăng ký và tài khoản đang ở trạng thái `Active` |
| `403 Forbidden` | `ACCOUNT_BANNED` | `Account has been locked or banned by an administrator.` | Tài khoản tương ứng với email đang bị khóa (`Banned`) |
| `500 Internal Server Error` | `INTERNAL_SERVER_ERROR` | `An internal server error occurred. Please try again later.` | Lỗi hệ thống hoặc kết nối cơ sở dữ liệu thất bại |

---

## 6. BẢNG DANH MỤC ENUM LIÊN QUAN

| Tên Enum | Giá trị Integer (DB) | Chuỗi JSON Output (PascalCase) | Ý nghĩa nghiệp vụ |
| :--- | :---: | :--- | :--- |
| `UserStatus` | `0` | `PendingVerification` | Tài khoản mới tạo, chờ xác thực mã OTP email |
| `UserStatus` | `1` | `Active` | Tài khoản đã kích hoạt thành công |
| `UserStatus` | `2` | `Banned` | Tài khoản bị khóa |
| `RoleType` | `0` | `Buyer` | Vai trò người mua hàng mặc định |

---

## 7. CHECKLIST HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Layer: `RegisterTestApiRequest`, `RegisterTestApiResponse`, `RegisterTestUserAsync`
- [x] API Layer: `AuthController.RegisterTest()` tại `POST /api/v1/users/auth/test`
- [x] Validation rules & Error handling active (100% English sentence-case)
- [x] Unit Tests Passed: `AuthServiceTests.RegisterTestUserAsync_creates_pending_buyer_and_dispatches_otp`
- [x] REST Controller Integration Tests Passed: `AuthControllerRestTests.RegisterTest_Returns_Created_With_Pending_Buyer_And_Otp_Dispatched`
- [x] Gateway routing aligned: `users-route` forward to `user-cluster:8001`
- [x] Trạng thái: `✅ COMPLETED`
