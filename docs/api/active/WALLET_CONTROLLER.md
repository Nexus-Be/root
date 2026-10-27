# 💳 ACTIVE APIS: WALLET CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua cURL trên Gateway cổng `8080` ngày 2026-10-28)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/WalletController.cs`  
> **Backend Service:** `Wallet.Api` (Cổng `8008`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`wallet_db` trên Neon DB), JWT Bearer Security, User Balance Ledger

---

## 1. XEM THÔNG TIN VÍ CỦA TÔI (GET MY WALLET)

- **Endpoint Gateway:** `GET /api/v1/wallets/me`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `GET http://wallet-service:8008/api/v1/wallets/me`
- **Cơ chế hoạt động:**
  1. Client gửi request kèm Bearer JWT Token trong header `Authorization`.
  2. Gateway thẩm định chữ ký JWT bằng Symmetric Key (`Jwt:Key`), trích xuất claim `sub` (UserId).
  3. Gateway gán header nội bộ:
     - `x-user-id: {sub}`
     - `x-user-roles: {role}`
     - `x-user-email: {email}`
  4. Gateway forward request xuống `Wallet.Api` tại cổng `8008`.
  5. `Wallet.Api` nhận header `x-user-id`, truy vấn sổ cái số dư ví của người dùng trong PostgreSQL (`wallet_db`). Nếu người dùng mới chưa có ví, service tự động khởi tạo ví mặc định với số dư 0 VND.
  6. Trả về thông tin số dư khả dụng (`balance`), số dư đóng băng (`frozenBalance`), loại tiền tệ (`currency`) và trạng thái ví (`status`).

### Request Headers
```http
GET /api/v1/wallets/me HTTP/1.1
Host: localhost:8080
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Gateway-Mode: Real
```

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "data": {
    "walletId": "73c683ee-c02a-43d9-95e2-2591605ec686",
    "userId": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "balance": 0.00,
    "frozenBalance": 0.00,
    "currency": "VND",
    "status": "Active",
    "createdAt": "2026-10-27T16:21:28Z",
    "updatedAt": "2026-10-27T16:21:28Z"
  },
  "timestamp": "2026-10-27T16:21:28Z",
  "traceId": "0HNPK8LRRV5Q0:00000001"
}
```

### Lệnh cURL Kiểm Chứng
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1MDFkMTFlNy1jM2M0LTQ0YTMtOGMwNy02ZWY3NDlkOWRjODYiLCJlbWFpbCI6InVzZXJfZ2F0ZXdheV9maW5hbEBleGFtcGxlLmNvbSIsIm5hbWUiOiJHYXRld2F5IEZpbmFsIiwianRpIjoiMjYwZGNlYWEtZmE0OS00ODY1LWI5ZTMtNWU4YzMzMmRmNWVlIiwicm9sZSI6ImJ1eWVyIiwibmJmIjoxNzkzMTE3ODI0LCJleHAiOjE3OTMxMjE0MjQsImlzcyI6Imh0dHA6Ly9sb2NhbGhvc3Q6ODAwMSIsImF1ZCI6InNob3BwaW5nY2FydC1hcGkifQ.igd-Nhh-mitjFoVMVozD-brhK421YEiDSrXgULS4G9M"

curl -s -X GET http://localhost:8080/api/v1/wallets/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Mode: Real"
```
