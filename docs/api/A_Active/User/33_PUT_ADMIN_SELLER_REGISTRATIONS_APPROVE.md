# [PUT] /api/v1/admin/seller-registrations/{id}/approve

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminSellerRegistrations`  
> **Mã tham chiếu Excel:** `33`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên duyệt đơn đăng ký người bán, tự động gán vai trò Seller và kích hoạt gian hàng.
* **HTTP Method:** `PUT`
* **Đường dẫn chuẩn:** `/api/v1/admin/seller-registrations/{id}/approve`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-seller-registrations-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminSellerRegistrationsController.cs` $\rightarrow$ `ApproveRegistration()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `ApproveSellerRegistrationAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `ApproveSellerRegistrationAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

### 3.2. Request Body (JSON Payload - Tùy chọn)
```json
{
  "note": "KYC documentation verified successfully."
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<ApproveSellerRegistrationResponseDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller registration approved successfully.",
  "data": {
    "registrationId": "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
    "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "status": "Approved",
    "approvedAt": "2026-11-01T14:00:00Z"
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
| `400 BadRequest` | `INVALID_OPERATION` | `"Only pending applications can be approved."` | Đơn không ở trạng thái Pending |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `REGISTRATION_NOT_FOUND` | `"Seller registration application not found."` | Không tìm thấy đơn |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-seller-registrations-route)
- [x] Status: COMPLETED
