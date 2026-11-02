# [POST] /api/v1/sellers/otp/resend

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `17`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Gửi lại mã OTP xác minh cho hồ sơ đăng ký người bán đang ở trạng thái nháp / chờ xác minh email.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/sellers/otp/resend`
* **Quyền hạn truy cập (RBAC):** `RequireRole (Authenticated)`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `ResendSellerOtp()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `ResendSellerOtpAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `ResendSellerOtpAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "businessEmail": "contact@techzone.vn"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<object>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Verification code resent successfully.",
  "data": {
    "message": "Verification code resent successfully."
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Business email is required."` | Thiếu email doanh nghiệp |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Chưa đăng nhập |
| `404 NotFound` | `REGISTRATION_NOT_FOUND` | `"Seller registration application not found."` | Không tìm thấy hồ sơ |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
