# [PATCH] /api/v1/variants/{id}/status

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Variants`  
> **Mã tham chiếu Excel:** `CAT-09`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thay đổi trạng thái của biến thể SKU (`Active` hoặc `Inactive` kèm lý do).
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/variants/{id}/status`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được đổi trạng thái biến thể thuộc sản phẩm của mình.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `variants-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/VariantsController.cs` $\rightarrow$ `ChangeVariantStatus()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `ChangeVariantStatusAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `ChangeVariantStatusAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của biến thể |

### 3.2. Request Body Schema (`ChangeVariantStatusRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `status` | `string` | Có | Chuỗi PascalCase (`"Active"`, `"Inactive"`) |
| `statusReason` | `string?` | Không | Lý do thay đổi trạng thái |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<VariantDetailDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Variant status updated successfully.",
  "data": {
    "id": "99999999-9999-9999-9999-999999999991",
    "productId": "88888888-8888-8888-8888-888888888888",
    "skuCode": "TSHIRT-BLK-M",
    "name": "Size M - Màu Đen",
    "price": 180000,
    "currency": "VND",
    "isActive": false,
    "hasOrder": false,
    "status": "Inactive",
    "statusReason": "Temporarily out of raw materials",
    "attributes": [
      { "attrName": "Size", "attrValue": "M" },
      { "attrName": "Color", "attrValue": "Black" }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid variant status transition."` | Trạng thái không hợp lệ |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token xác thực |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to modify this variant."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `VARIANT_NOT_FOUND` | `"Variant not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (variants-route)
- [x] Status: COMPLETED
