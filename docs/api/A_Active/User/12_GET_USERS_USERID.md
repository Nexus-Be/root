# [GET] /api/v1/users/{userId}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Users`  
> **Mã tham chiếu Excel:** `12`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin hồ sơ an toàn công khai của người dùng (USER-07).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/users/{userId}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `users-route`)
* **Controller Action:** `User.Api/Controllers/Public/UsersController.cs` $\rightarrow$ `GetUserPublicProfile()`
* **Application Interface:** `User.Application/Services/Profile/IProfileService.cs` $\rightarrow$ `GetPublicProfileAsync()`
* **Service Implementation:** `User.Application/Services/Profile/ProfileService.cs` $\rightarrow$ `GetPublicProfileAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `userId` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<PublicUserProfileDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User profile retrieved successfully.",
  "data": {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "username": "johndoe",
    "firstName": "John",
    "lastName": "Doe",
    "avatarUrl": "https://cdn.example.com/avatars/user1.png",
    "reputationScore": 120,
    "trustLevel": "Standard",
    "badges": ["VerifiedBuyer"],
    "isSeller": true,
    "joinedAt": "2026-01-15T08:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid user identifier format."` | Định dạng GUID không hợp lệ |
| `404 NotFound` | `USER_NOT_FOUND` | `"User account not found with the specified identifier."` | Người dùng không tồn tại hoặc đã bị xóa |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (users-route)
- [x] Status: COMPLETED
