# [GET] /api/v1/admin/users/{userId}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `24`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên xem thông tin chi tiết đầy đủ của một tài khoản người dùng.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/users/{userId}`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminUsersController.cs` $\rightarrow$ `GetUserDetail()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `GetUserDetailAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `GetUserDetailAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `userId` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<AdminUserDetailDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User detail retrieved successfully.",
  "data": {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "email": "buyer01@example.com",
    "username": "buyer01",
    "displayName": "John Doe",
    "firstName": "John",
    "lastName": "Doe",
    "phoneNumber": "0912345678",
    "identifyNumber": "012345678901",
    "avatarUrl": "https://cdn.example.com/avatars/user1.png",
    "gender": "Male",
    "status": "Active",
    "roles": ["Buyer"],
    "createdAt": "2026-01-15T08:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid user identifier format."` | Định dạng GUID sai |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `USER_NOT_FOUND` | `"User account not found with the specified identifier."` | Không tìm thấy người dùng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-users-route)
- [x] Status: COMPLETED
