# [POST] /api/v1/sellers/registration

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `15`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Nộp hồ sơ đăng ký trở thành người bán (onboarding) và gửi mã OTP xác minh email doanh nghiệp.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/sellers/registration`
* **Quyền hạn truy cập (RBAC):** `RequireRole (Authenticated)`
* **Yêu cầu Idempotency:** Tùy chọn

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `RegisterSeller()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `RegisterSellerAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `RegisterSellerAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "shopName": "TechZone Store",
  "businessEmail": "contact@techzone.vn",
  "hotline": "19001234",
  "identityCardNumber": "012345678901",
  "idCardFrontUrl": "https://cdn.example.com/kyc/front.jpg",
  "idCardBackUrl": "https://cdn.example.com/kyc/back.jpg",
  "businessLicenseUrl": "https://cdn.example.com/kyc/license.pdf",
  "warehouseAddress": {
    "provinceId": 201,
    "districtId": 1442,
    "wardCode": "20101",
    "streetAddress": "123 Nguyen Van Linh, District 7"
  }
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<SellerRegistrationResponseDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Seller registration submitted successfully.",
  "data": {
    "businessEmail": "contact@techzone.vn",
    "status": "PendingVerification",
    "otpExpiresInSeconds": 300,
    "nextStep": "VerifyBusinessEmailOtp",
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"One or more seller registration fields are invalid."` | Dữ liệu đầu vào thiếu hoặc sai định dạng |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Chưa đăng nhập |
| `409 Conflict` | `SELLER_ALREADY_EXISTS` | `"User is already registered as a seller or has pending registration."` | Đã là người bán hoặc có đơn chờ duyệt |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
