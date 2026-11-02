# [GET] /api/v1/admin/roles

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminRoles`  
> **Mã tham chiếu Excel:** `30`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên lấy danh mục các vai trò người dùng trong hệ thống.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/roles`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-roles-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminRolesController.cs` $\rightarrow$ `GetRoles()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `GetRolesAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `GetRolesAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/Role.cs` $\rightarrow$ Bảng `Roles` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

* Xác thực qua JWT Bearer token trên header `Authorization`.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<AdminRoleListResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Roles retrieved successfully.",
  "data": {
    "roles": [
      {
        "id": "1",
        "roleId": "1",
        "roleCode": "Buyer",
        "roleName": "Standard Buyer",
        "description": "Registered buyer capable of purchasing goods",
        "isSystemRole": true,
        "isActive": true,
        "permissionsCount": 5
      },
      {
        "id": "2",
        "roleId": "2",
        "roleCode": "Seller",
        "roleName": "Registered Merchant",
        "description": "Merchant operating a shop",
        "isSystemRole": true,
        "isActive": true,
        "permissionsCount": 12
      }
    ]
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
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-roles-route)
- [x] Status: COMPLETED
