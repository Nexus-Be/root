# [PUT] /api/v1/products/{id}/default-variant

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products / Variants`  
> **Mã tham chiếu Excel:** `CAT-10`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thiết lập một biến thể SKU làm biến thể mặc định (`isDefault = true`) cho sản phẩm.
* **HTTP Method:** `PUT`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}/default-variant`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được đổi biến thể mặc định cho sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `SetDefaultVariant()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `SetDefaultVariantAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `SetDefaultVariantAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm |

### 3.2. Request Body Schema (`SetDefaultVariantRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `variantId` | `Guid` | Có | Định dạng UUIDv4 của biến thể muốn đặt làm mặc định |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<object>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Default variant updated successfully.",
  "data": {
    "defaultVariantId": "99999999-9999-9999-9999-999999999992"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid variant identifier format."` | GUID sai định dạng |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to modify this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `VARIANT_NOT_FOUND` | `"Variant not found for this product."` | `variantId` không thuộc về sản phẩm |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
