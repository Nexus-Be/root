# [GET] /api/v1/admin/seller-registrations

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminSellerRegistrations`  
> **Mã tham chiếu Excel:** `31`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên tra cứu danh sách đơn đăng ký người bán đang chờ duyệt với phân trang.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/seller-registrations`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-seller-registrations-route`)
* **Controller Action:** `User.Api/Controllers/Public/AdminSellerRegistrationsController.cs` $\rightarrow$ `ListRegistrations()`
* **Application Interface:** `User.Application/Services/Seller/ISellerService.cs` $\rightarrow$ `ListSellerRegistrationsAsync()`
* **Service Implementation:** `User.Application/Services/Seller/SellerService.cs` $\rightarrow$ `ListSellerRegistrationsAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/SellerRegistration.cs` $\rightarrow$ Bảng `SellerRegistrations` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số nguyên dương $\ge 1$ |
| `pageSize` | `integer` | `20` | Số nguyên dương trong khoảng $1 \le pageSize \le 100$ |
| `status` | `string?` | null | Lọc theo trạng thái (`Pending`, `Approved`, `Rejected`) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<AdminSellerRegistrationItemDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller registrations retrieved successfully.",
  "data": {
    "items": [
      {
        "registrationId": "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
        "userId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
        "shopName": "TechZone Store",
        "businessEmail": "contact@techzone.vn",
        "hotline": "19001234",
        "identityCardNumber": "012345678901",
        "warehouseAddress": "123 Nguyen Van Linh, District 7",
        "pickupAddress": "123 Nguyen Van Linh, District 7",
        "reputationScore": 100,
        "status": "Pending",
        "createdAt": "2026-11-01T10:30:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 5,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (admin-seller-registrations-route)
- [x] Status: COMPLETED
