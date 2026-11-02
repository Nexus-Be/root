# [GET] /api/v1/sellers/profile

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `19`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin hồ sơ gian hàng người bán của chính mình.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/sellers/profile`
* **Quyền hạn truy cập (RBAC):** `RequireRole("seller", "admin")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `GetSellerOwnProfile()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `GetSellerOwnProfileAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `GetSellerOwnProfileAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerProfile.cs` $\rightarrow$ Bảng `SellerProfiles` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

* Xác thực qua JWT Bearer token trên header `Authorization`.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<SellerOwnProfileResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller profile retrieved successfully.",
  "data": {
    "sellerId": "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
    "shopId": "SHOP-001",
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "shopName": "TechZone Store",
    "avatarUrl": "https://cdn.example.com/shops/logo.png",
    "businessEmail": "contact@techzone.vn",
    "hotline": "19001234",
    "description": "Official electronics store",
    "pickupAddress": "123 Nguyen Van Linh, District 7, HCMC",
    "provinceId": 201,
    "districtId": 1442,
    "wardCode": "20101",
    "status": "Active",
    "ratingAvg": 4.8,
    "reputationScore": 250,
    "trustLevel": "Verified"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User is not an active seller."` | Tài khoản chưa phải là người bán |
| `404 NotFound` | `SELLER_NOT_FOUND` | `"Seller profile not found."` | Không tìm thấy hồ sơ gian hàng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
