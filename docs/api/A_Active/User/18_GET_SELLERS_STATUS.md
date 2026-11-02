# [GET] /api/v1/sellers/status

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Seller`  
> **Mã tham chiếu Excel:** `18`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu tiến trình và trạng thái đăng ký người bán của người dùng hiện tại.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/sellers/status`
* **Quyền hạn truy cập (RBAC):** `RequireRole (Authenticated)`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `sellers-route`)
* **Controller Action:** `User.Api/Controllers/Public/SellerController.cs` $\rightarrow$ `GetSellerRegistrationStatus()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `GetSellerRegistrationStatusAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `GetSellerRegistrationStatusAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

* Xác thực qua JWT Bearer token trên header `Authorization`.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<SellerRegistrationStatusResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller registration status retrieved successfully.",
  "data": {
    "status": "Pending",
    "rejectionReason": null,
    "nextStep": "WaitForAdminApproval",
    "businessEmail": "contact@techzone.vn"
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
| `404 NotFound` | `REGISTRATION_NOT_FOUND` | `"Seller registration application not found."` | Người dùng chưa nộp hồ sơ |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (sellers-route)
- [x] Status: COMPLETED
