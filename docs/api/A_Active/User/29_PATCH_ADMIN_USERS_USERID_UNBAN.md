# [PATCH] /api/v1/admin/users/{userId}/unban

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `29`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên mở khóa tài khoản người dùng đã bị đình chỉ trước đó (ADMIN-06).
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/admin/users/{userId}/unban`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminUsersController.cs` $\rightarrow$ `UnbanUser()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `UnbanUserAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `UnbanUserAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `userId` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

### 3.2. Request Body (JSON Payload - Tùy chọn)
```json
{
  "reason": "Appeal accepted after verification"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<AdminUserUnbannedResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User account unbanned successfully.",
  "data": {
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "status": "Active",
    "unbannedAt": "2026-11-01T12:00:00Z",
    "unbannedBy": "admin-id",
    "message": "User unbanned successfully."
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"Only administrators can unban user accounts."` | Không có quyền admin |
| `404 NotFound` | `USER_NOT_FOUND` | `"User account not found with the specified identifier."` | Không tìm thấy người dùng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-users-route)
- [x] Status: COMPLETED
