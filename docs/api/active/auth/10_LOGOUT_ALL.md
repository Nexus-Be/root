# 10 — ĐĂNG XUẤT TOÀN BỘ PHIÊN (LOGOUT ALL SESSIONS)

> **Endpoint Gateway:** `POST /api/v1/auth/logout-all`  
> **Backend Service:** `User.Api` (Port `8001`) -> Forward `POST /api/v1/auth/logout-all`  
> **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)  
> **Yêu cầu Headers:** `Authorization: Bearer <accessToken>`  
> **Hạ tầng liên quan:** PostgreSQL (`RefreshTokens`)  

---

## 1. MÔ TẢ NGHIỆP VỤ & LUỒNG XỬ LÝ (BUSINESS FLOW)

1. Client gửi yêu cầu đăng xuất khỏi toàn bộ thiết bị lên Gateway kèm Bearer Token.
2. Gateway kiểm tra JWT hợp lệ, trích xuất `sub` từ claims gán vào header `x-user-id`.
3. Gateway chuyển tiếp yêu cầu xuống `User.Api`.
4. `User.Api` đọc `x-user-id`:
   - Nếu không có: Báo lỗi `VAL_INVALID_USER_ID` (HTTP 400).
5. `User.Api` tìm toàn bộ bản ghi Refresh Token đang hoạt động (`IsRevoked = false` và `ExpiresAt > DateTimeOffset.UtcNow`) thuộc về `UserId`:
   - Cập nhật toàn bộ thành `IsRevoked = true`, `RevokedAt = DateTimeOffset.UtcNow`.
   - Đếm số lượng phiên vừa thu hồi.
   - Lưu các thay đổi xuống CSDL PostgreSQL.
6. Toàn bộ các thiết bị khác sử dụng refresh token của người dùng này sẽ không thể làm mới token và buộc phải đăng nhập lại từ đầu.
7. Trả về số lượng phiên đã bị thu hồi trong phong bì `ApiResponse<LogoutAllResponseDto>`.

---

## 2. QUY CHUẨN VALIDATION (INPUT RULES)

| Trường | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Giới hạn |
|:---|:---:|:---:|:---|
| Không có body | - | - | Endpoint không yêu cầu body payload |

---

## 3. MA TRẬN MÃ LỖI XUYÊN SUỐT HỆ THỐNG (RFC 9110 ERROR MATRIX)

| Dịch vụ phát sinh | Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---|:---:|:---|:---|:---|
| Gateway / User | `400` | `VAL_INVALID_USER_ID` | "Missing or invalid x-user-id header." | Không trích xuất được định danh người dùng |
| Gateway | `401` | `UNAUTHORIZED` | "Unauthorized access. Bearer token missing or invalid." | Thiếu hoặc sai token JWT |
| Gateway | `503` | `SERVICE_UNAVAILABLE` | "Downstream service unavailable." | Không thể kết nối tới `User.Api` |

---

## 4. PAYLOAD MẪU (REQUEST / RESPONSE SAMPLES)

### 4.1 Request Payload
*(Không có body — Gửi kèm Header `Authorization: Bearer <accessToken>`)*

### 4.2 Response Payload (200 OK)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "All sessions have been revoked.",
  "data": {
    "countRevoked": 3
  },
  "timestamp": "2026-10-30T07:40:00Z",
  "traceId": "0HNPK8LRRV5PM:00000010"
}
```

---

## 5. CHECKLIST TRẠNG THÁI HOÀN THÀNH (COMPLETION CHECKLIST)

- [x] Application Service (`AuthService.LogoutAllAsync`) thu hồi hàng loạt Refresh Token trong CSDL.
- [x] Gateway Controller (`AuthController.LogoutAll`) gán quyền `GatewayPolicies.Authenticated` & truyền danh tính `x-user-id`.
- [x] Unit/Integration tests (`AuthServiceTests.cs`, `AuthControllerRestTests.cs`) vượt qua 100%.
- [x] Gateway Seed Fixture (`Seeds/users/logout-all.json`) đồng bộ.
- [x] Trạng thái chính thức: `✅ COMPLETED`
