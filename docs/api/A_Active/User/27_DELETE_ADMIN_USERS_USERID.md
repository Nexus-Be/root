# [DELETE] /api/v1/admin/users/{userId}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `27`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên xóa mềm tài khoản người dùng và thu hồi toàn bộ phiên đăng nhập đang hoạt động.
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/admin/users/{userId}`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminUsersController.cs` $\rightarrow$ `DeleteUser()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `DeleteUserAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `DeleteUserAsync()`
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
  "reason": "Account closure requested by user"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

* **HTTP Status Code:** `204 NoContent`
* Không trả về dữ liệu body (theo RFC 9110 và quy chuẩn Nexus Zero Body on Delete).

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `USER_NOT_FOUND` | `"User account not found with the specified identifier."` | Không tìm thấy người dùng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-users-route)
- [x] Status: COMPLETED
