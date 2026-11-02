# [DELETE] /api/v1/products/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-04`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xóa mềm sản phẩm (`IsDeleted = true`, `DeletedAt = UtcNow`) và tất cả các biến thể SKU trực thuộc.
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Chỉ người bán sở hữu sản phẩm hoặc tài khoản admin mới có quyền xóa.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `Delete()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `SoftDeleteAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `SoftDeleteAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm cần xóa |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`204 NoContent`)
* Không có Response Body.

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product identifier format."` | GUID sai định dạng |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token xác thực |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to delete this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại hoặc đã bị xóa |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
