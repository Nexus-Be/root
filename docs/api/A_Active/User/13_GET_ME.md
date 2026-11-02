# [GET] /api/v1/me

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Me`  
> **Mã tham chiếu Excel:** `13`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin hồ sơ đầy đủ của chính người dùng hiện tại đang đăng nhập.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/me`
* **Quyền hạn truy cập (RBAC):** `RequireRole (Authenticated)`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `user-me-route`)
* **Controller Action:** `User.Api/Controllers/Public/MeController.cs` $\rightarrow$ `GetMe()`
* **Application Interface:** `User.Application/Services/Profile/IProfileService.cs` $\rightarrow$ `GetProfileAsync()`
* **Service Implementation:** `User.Application/Services/Profile/ProfileService.cs` $\rightarrow$ `GetProfileAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

* Xác thực qua JWT Bearer token trên header `Authorization`.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<UserProfileDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User profile retrieved successfully.",
  "data": {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "email": "buyer@example.com",
    "username": "buyer01",
    "firstName": "John",
    "lastName": "Doe",
    "displayName": "John Doe",
    "phoneNumber": "0912345678",
    "address": "123 Nguyen Hue, District 1, Ho Chi Minh City",
    "avatarUrl": "https://cdn.example.com/avatars/user1.png",
    "status": "Active",
    "roles": ["Buyer"],
    "permissions": ["READ_PROFILE"],
    "isSeller": false,
    "shopName": null,
    "reputationScore": 100,
    "trustLevel": "Standard",
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
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu hoặc token không hợp lệ |
| `404 NotFound` | `USER_NOT_FOUND` | `"User account not found with the specified identifier."` | Tài khoản không tồn tại hoặc đã bị xóa |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (user-me-route)
- [x] Status: COMPLETED
