# [GET] /api/v1/admin/users

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `23`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên tra cứu danh sách người dùng với phân trang cấp cơ sở dữ liệu, tìm kiếm theo từ khóa và bộ lọc.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/users`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminUsersController.cs` $\rightarrow$ `ListUsers()`
* **Application Interface:** `User.Application/Services/Admin/IAdminUserService.cs` $\rightarrow$ `ListUsersAsync()`
* **Service Implementation:** `User.Application/Services/Admin/AdminUserService.cs` $\rightarrow$ `ListUsersAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số nguyên dương $\ge 1$ |
| `pageSize` | `integer` | `20` | Số nguyên dương trong khoảng $1 \le pageSize \le 100$ |
| `keyword` | `string?` | null | Tìm kiếm theo email, họ tên, hoặc username |
| `role` | `string?` | null | Lọc theo mã vai trò (`Buyer`, `Seller`, `Admin`) |
| `status` | `string?` | null | Lọc theo trạng thái (`Active`, `PendingVerification`, `Banned`) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<AdminUserListItemDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User list retrieved successfully.",
  "data": {
    "items": [
      {
        "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
        "email": "buyer01@example.com",
        "username": "buyer01",
        "firstName": "John",
        "lastName": "Doe",
        "phoneNumber": "0912345678",
        "status": "Active",
        "roles": ["Buyer"],
        "createdAt": "2026-01-15T08:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 150,
      "totalPages": 8,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
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
- [x] Gateway Aligned (admin-users-route)
- [x] Status: COMPLETED
