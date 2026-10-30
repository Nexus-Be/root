# 👤 ACTIVE APIS: USERS CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế 100% qua Unit/Integration tests trên Gateway cổng `8080` và UserService `8001`)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/UsersController.cs`  
> **Backend Service:** `User.Api` (Cổng `8001`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`usermanagement_db`), JWT Bearer Identity Propagation (`x-user-id`)

---

## 1. LẤY THÔNG TIN TÀI KHOẢN CỦA TÔI (GET CURRENT PROFILE)

- **Endpoint Gateway:** `GET /api/v1/me`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `GET http://user-service:8001/api/v1/me`
- **Luồng xử lý:**
  1. Client gửi request kèm Bearer JWT Token.
  2. Gateway thẩm định chữ ký JWT, trích xuất `sub` (UserId) và gán header `x-user-id: {sub}`.
  3. Gateway forward request xuống `User.Api`.
  4. `User.Api` đọc `x-user-id`, truy vấn thông tin người dùng từ PostgreSQL (`usermanagement_db`) và trả về `UserProfileDto`.

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `x-user-id` | Header | Có | Định dạng UUID hợp lệ từ Gateway |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_USER_ID` | "Missing or invalid x-user-id header." | Header `x-user-id` rỗng hoặc sai format UUID |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Không có token hoặc token không hợp lệ |
| `404` | `USER_NOT_FOUND` | "User profile not found." | Không tìm thấy người dùng trong CSDL |

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "User profile retrieved successfully.",
  "data": {
    "id": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "username": "user_gateway_final",
    "email": "user_gateway_final@example.com",
    "displayName": "Gateway Final",
    "firstName": "Gateway",
    "lastName": "Final",
    "phoneNumber": "0987654321",
    "avatarUrl": null,
    "status": "Active",
    "trustLevel": "Standard",
    "reputationScore": 50,
    "roles": ["buyer"]
  }
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ProfileService.cs`) triển khai & truy vấn DB.
- [x] Thin Controller (`UsersController.cs`) ghép cặp 1-to-1, route chuẩn hóa `/api/v1/me`.
- [x] Unit test (`ProfileServiceTests.cs`) & REST test (`UsersControllerRestTests.cs`) pass 100%.
- [x] Gateway routing & Seed fixture (`Seeds/users/me.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. CẬP NHẬT THÔNG TIN HỒ SƠ (UPDATE PROFILE)

- **Endpoint Gateway:** `PATCH /api/v1/me`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `PATCH http://user-service:8001/api/v1/me`
- **Luồng xử lý:**
  1. Client gửi request PATCH kèm header Bearer JWT và body chứa các trường cần cập nhật.
  2. Gateway thẩm định và truyền `x-user-id`.
  3. `User.Api` cập nhật thông tin cá nhân (`FirstName`, `LastName`, `PhoneNumber`, `AvatarUrl`) trong PostgreSQL.

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `firstName` | `string` | Không | Tối đa 100 ký tự |
| `lastName` | `string` | Không | Tối đa 100 ký tự |
| `phoneNumber` | `string` | Không | Định dạng số điện thoại hợp lệ |
| `avatarUrl` | `string` | Không | Định dạng URI hợp lệ |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Invalid profile data provided." | Dữ liệu cập nhật không hợp lệ |
| `404` | `USER_NOT_FOUND` | "User account not found." | Không tìm thấy người dùng cần cập nhật |

### Request Body
```json
{
  "firstName": "UpdatedFirst",
  "lastName": "UpdatedLast",
  "phoneNumber": "0912345678"
}
```

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Profile updated successfully.",
  "data": {
    "id": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "firstName": "UpdatedFirst",
    "lastName": "UpdatedLast",
    "phoneNumber": "0912345678"
  }
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ProfileService.cs`) cập nhật `User` entity.
- [x] Thin Controller (`UsersController.cs`) ghép cặp 1-to-1, route chuẩn hóa `/api/v1/me`.
- [x] Unit test & REST controller test pass 100%.
- [x] Gateway routing & Seed fixture (`Seeds/users/profile-update.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 3. TRA CỨU HỒ SƠ CÔNG KHAI (GET PUBLIC PROFILE)

- **Endpoint Gateway:** `GET /api/v1/user/{userId}`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://user-service:8001/api/v1/user/{userId}`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `userId` | Route | Có | Định dạng UUIDv4 hợp lệ |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_USER_ID` | "Invalid user identifier format." | Route parameter không phải UUID |
| `404` | `USER_NOT_FOUND` | "User not found with the specified ID." | Không tìm thấy người dùng |

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "data": {
    "id": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "username": "user_gateway_final",
    "displayName": "Gateway Final",
    "trustLevel": "Standard",
    "reputationScore": 50
  }
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ProfileService.cs`) truy vấn công khai.
- [x] Thin Controller (`UsersController.cs`) ghép cặp 1-to-1.
- [x] Unit test pass 100%.
- [x] Gateway routing & Seed fixture (`Seeds/users/user-detail.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
