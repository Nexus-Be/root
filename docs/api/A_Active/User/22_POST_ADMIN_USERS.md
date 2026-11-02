# [POST] /api/v1/admin/users

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `22`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên hoặc nhân viên tạo tài khoản người dùng mới trong hệ thống.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/admin/users`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Tùy chọn

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminUsersController.cs` $\rightarrow$ `CreateUser()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `CreateUserAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `CreateUserAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "email": "staff.member@company.com",
  "password": "StaffPassword123!",
  "firstName": "Alice",
  "lastName": "Smith",
  "phoneNumber": "0911223344",
  "username": "alicesmith",
  "roleCodes": ["SupportStaff"]
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<AdminUserDetailDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "User account created successfully by administrator.",
  "data": {
    "id": "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
    "email": "staff.member@company.com",
    "username": "alicesmith",
    "firstName": "Alice",
    "lastName": "Smith",
    "phoneNumber": "0911223344",
    "status": "Active",
    "roles": ["SupportStaff"],
    "createdAt": "2026-11-01T11:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Valid email address is required."` | Thiếu hoặc sai định dạng email |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `409 Conflict` | `EMAIL_ALREADY_EXISTS` | `"Email is already registered in the system."` | Email đã tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-users-route)
- [x] Status: COMPLETED
