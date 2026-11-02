# [POST] /api/v1/sellers/otp/verify

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `16`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xác minh mã OTP email doanh nghiệp và chuyển hồ sơ đăng ký người bán sang trạng thái Chờ duyệt (Pending).
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/sellers/otp/verify`
* **Quyền hạn truy cập (RBAC):** `RequireRole (Authenticated)`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `VerifySellerOtp()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `VerifySellerRegistrationOtpAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `VerifySellerRegistrationOtpAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "businessEmail": "contact@techzone.vn",
  "otpCode": "123456"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<VerifySellerOtpResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Business email verified successfully. Registration pending review.",
  "data": {
    "sellerId": "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "status": "Pending",
    "businessEmail": "contact@techzone.vn",
    "shopName": "TechZone Store",
    "verifiedAt": "2026-11-01T10:35:00Z",
    "message": "Seller registration verified and submitted for review."
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"OTP code is required."` | Thiếu mã OTP |
| `400 BadRequest` | `OTP_INVALID` | `"Invalid verification code."` | Mã OTP không đúng |
| `400 BadRequest` | `OTP_EXPIRED` | `"Verification code has expired."` | Mã OTP đã quá hạn |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Chưa đăng nhập |
| `404 NotFound` | `REGISTRATION_NOT_FOUND` | `"Seller registration application not found."` | Không tìm thấy hồ sơ |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
