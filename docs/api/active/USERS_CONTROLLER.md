# 👤 ACTIVE APIS: USERS CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua cURL trên Gateway cổng `8080` ngày 2026-10-28)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/UsersController.cs`  
> **Backend Service:** `User.Api` (Cổng `8001`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (Neon DB), JWT Bearer Security

---

## 1. LẤY THÔNG TIN TÀI KHOẢN ĐANG ĐĂNG NHẬP (GET CURRENT PROFILE)

- **Endpoint Gateway:** `GET /api/v1/me`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `GET http://user-service:8001/api/v1/me`
- **Cơ chế hoạt động:**
  1. Client gửi request kèm Bearer JWT Token trong header `Authorization`.
  2. Gateway thẩm định chữ ký JWT bằng Symmetric Key nội bộ (`Jwt:Key`), kiểm tra thời hạn và các claims hợp lệ.
  3. Gateway trích xuất claim `sub` (chính là `UserId`) và gán vào header HTTP:
     - `x-user-id: {sub}`
     - `x-user-roles: {role}`
     - `x-user-email: {email}`
  4. Gateway forward request kèm các headers trên xuống `User.Api` tại cổng `8001`.
  5. `User.Api` đọc header `x-user-id`, truy vấn thông tin chi tiết người dùng từ CSDL PostgreSQL và trả về DTO hoàn chỉnh.

### Request Headers
```http
GET /api/v1/me HTTP/1.1
Host: localhost:8080
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Gateway-Mode: Real
```

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
    "address": null,
    "shopName": "",
    "status": "Active",
    "trustLevel": "Standard",
    "reputationScore": 50,
    "roles": [
      "buyer"
    ]
  },
  "timestamp": "2026-10-27T16:18:34Z",
  "traceId": "0HNPK8LRRV5PT:00000001"
}
```

### Lệnh cURL Kiểm Chứng
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1MDFkMTFlNy1jM2M0LTQ0YTMtOGMwNy02ZWY3NDlkOWRjODYiLCJlbWFpbCI6InVzZXJfZ2F0ZXdheV9maW5hbEBleGFtcGxlLmNvbSIsIm5hbWUiOiJHYXRld2F5IEZpbmFsIiwianRpIjoiMjYwZGNlYWEtZmE0OS00ODY1LWI5ZTMtNWU4YzMzMmRmNWVlIiwicm9sZSI6ImJ1eWVyIiwibmJmIjoxNzkzMTE3ODI0LCJleHAiOjE3OTMxMjE0MjQsImlzcyI6Imh0dHA6Ly9sb2NhbGhvc3Q6ODAwMSIsImF1ZCI6InNob3BwaW5nY2FydC1hcGkifQ.igd-Nhh-mitjFoVMVozD-brhK421YEiDSrXgULS4G9M"

curl -s -X GET http://localhost:8080/api/v1/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Mode: Real"
```
