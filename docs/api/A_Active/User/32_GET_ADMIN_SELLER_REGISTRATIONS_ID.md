# [GET] /api/v1/admin/seller-registrations/{registrationId}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminSellerRegistrations`  
> **Mã tham chiếu Excel:** `32`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên xem toàn bộ chi tiết hồ sơ đăng ký người bán kèm tài liệu KYC để kiểm duyệt.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/seller-registrations/{registrationId}`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-seller-registrations-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminSellerRegistrationsController.cs` $\rightarrow$ `GetRegistrationDetail()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `GetSellerRegistrationDetailsAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `GetSellerRegistrationDetailsAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `registrationId` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<SellerRegistrationDetailsDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller registration details retrieved successfully.",
  "data": {
    "registrationId": "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "applicantName": "John Doe",
    "applicantEmail": "buyer01@example.com",
    "applicantPhone": "0912345678",
    "shopName": "TechZone Store",
    "avatarUrl": "https://cdn.example.com/shops/logo.png",
    "businessEmail": "contact@techzone.vn",
    "hotline": "19001234",
    "identityCardNumber": "012345678901",
    "idCardFrontUrl": "https://cdn.example.com/kyc/front.jpg",
    "idCardBackUrl": "https://cdn.example.com/kyc/back.jpg",
    "businessLicenseUrl": "https://cdn.example.com/kyc/license.pdf",
    "status": "Pending",
    "submittedAt": "2026-11-01T10:30:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid registration identifier format."` | Định dạng GUID sai |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `REGISTRATION_NOT_FOUND` | `"Seller registration application not found."` | Không tìm thấy đơn đăng ký |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-seller-registrations-route)
- [x] Status: COMPLETED
