# [POST] /api/v1/users/auth/test

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Auth`  
> **Mã tham chiếu Excel:** `11`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Đăng ký tài khoản kiểm thử và gửi mã OTP kích hoạt tức thì.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/users/auth/test`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AuthController.cs` $\rightarrow$ `RegisterTest()`
* **Application Interface:** `User.Application/Services/Auth/IAuthService.cs` $\rightarrow$ `RegisterTestUserAsync()`
* **Service Implementation:** `User.Application/Services/Auth/AuthService.cs` $\rightarrow$ `RegisterTestUserAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "email": "testuser@example.com",
  "password": "Password123!"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<RegisterTestApiResponse>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "User registered successfully for testing.",
  "data": {
    "success": true,
    "message": "User registered successfully for testing.",
    "userId": "11111111-1111-1111-1111-111111111111",
    "email": "testuser@example.com",
    "status": "PendingVerification",
    "role": "Buyer"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Email is required."` | Thiếu trường email |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid email format."` | Định dạng email sai |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Password is required."` | Thiếu trường password |
| `409 Conflict` | `EMAIL_ALREADY_EXISTS` | `"Email is already registered in the system."` | Email đã tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (users-route)
- [x] Status: COMPLETED
