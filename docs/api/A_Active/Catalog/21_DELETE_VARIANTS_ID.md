# [DELETE] /api/v1/variants/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Variants`  
> **Mã tham chiếu Excel:** `CAT-11`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xóa mềm biến thể SKU nếu biến thể chưa có đơn hàng liên kết và không phải là biến thể mặc định duy nhất của sản phẩm.
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/variants/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được xóa biến thể của sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `variants-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/VariantsController.cs` $\rightarrow$ `DeleteVariant()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `SoftDeleteVariantAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `SoftDeleteVariantAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của biến thể cần xóa |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`204 NoContent`)
* Không có Response Body.

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid variant identifier format."` | GUID sai định dạng |
| `400 BadRequest` | `VARIANT_HAS_ORDERS` | `"Cannot delete variant that has associated orders."` | Biến thể đã có đơn hàng |
| `400 BadRequest` | `VARIANT_CANNOT_DELETE_LAST` | `"Cannot delete the only or default variant of a product."` | Biến thể duy nhất hoặc mặc định |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to delete this variant."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `VARIANT_NOT_FOUND` | `"Variant not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (variants-route)
- [x] Status: COMPLETED
