# [GET] /api/v1/sellers/{id}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `21`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin công khai của gian hàng người bán theo Shop ID hoặc Seller User ID.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/sellers/{id}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `GetSellerPublicProfile()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `GetPublicSellerProfileAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `GetPublicSellerProfileAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerProfile.cs` $\rightarrow$ Bảng `SellerProfiles` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 hợp lệ (ShopId hoặc Seller UserId) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<PublicSellerProfileResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller public profile retrieved successfully.",
  "data": {
    "shopId": "SHOP-001",
    "sellerId": "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
    "shopName": "TechZone Store",
    "logoUrl": "https://cdn.example.com/shops/logo.png",
    "description": "Official electronics store",
    "hotline": "19001234",
    "ratingAvg": 4.8,
    "totalProducts": 150,
    "createdAt": "2026-01-20T10:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid seller identifier format."` | Định dạng GUID không hợp lệ |
| `404 NotFound` | `SELLER_NOT_FOUND` | `"Seller profile not found."` | Không tìm thấy hồ sơ gian hàng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
