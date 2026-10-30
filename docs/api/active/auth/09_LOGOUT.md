# 09 — ĐĂNG XUẤT PHIÊN ĐĂNG NHẬP (LOGOUT)

> **Endpoint Gateway:** `POST /api/v1/auth/logout`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/logout`  
> **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)  
> **Yêu cầu Headers:** `Authorization: Bearer <accessToken>`  
> **Hạ tầng liên quan:** PostgreSQL (`RefreshTokens`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi yêu cầu đăng xuất kèm `refreshToken` trong body (tùy chọn) và Bearer token trên header `Authorization`.
2. Gateway kiểm tra JWT hợp lệ và chuyển tiếp yêu cầu xuống `User.Api`.
3. `User.Api` kiểm tra `refreshToken`:
   - Nếu có truyền token: Băm SHA-256 chuỗi token và tìm trong bảng `RefreshTokens`.
   - Nếu tìm thấy bản ghi: Đánh dấu `IsRevoked = true`, `RevokedAt = DateTimeOffset.UtcNow`.
4. Phiên đăng nhập tương ứng bị vô hiệu hóa hoàn toàn, không thể dùng token này để làm mới `accessToken` được nữa.
5. Trả về kết quả thành công trong phong bì `ApiResponse<LogoutResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| `refreshToken` | `string` | Không | Chuỗi refresh token cần thu hồi |
| `deviceInfo` | `string` | Không | Thông tin thiết bị đăng xuất |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway | `401` | `UNAUTHORIZED` | "Unauthorized access. Bearer token missing or invalid." | Thiếu hoặc token JWT không hợp lệ |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
```json
{
  "refreshToken": "7f8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b..."
}
```

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Logged out successfully.",
  "data": {
    "success": true
  },
  "timestamp": "2026-10-30T07:35:00Z",
  "traceId": "0HNPK8LRRV5PM:00000009"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.LogoutAsync`) thu hồi token trong CSDL PostgreSQL.
- [x] Gateway Controller (`AuthController.Logout`) gán quyền `GatewayPolicies.Authenticated`.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/logout.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
