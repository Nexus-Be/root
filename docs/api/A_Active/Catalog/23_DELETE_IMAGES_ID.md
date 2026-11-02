# [DELETE] /api/v1/images/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Images`  
> **Mã tham chiếu Excel:** `CAT-13`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xóa trực tiếp một hình ảnh sản phẩm theo mã `id` hình ảnh, tự động chuyển cờ ảnh chính nếu cần thiết.
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/images/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được xóa hình ảnh thuộc sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `images-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ImagesController.cs` $\rightarrow$ `DeleteImage()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `DeleteImageByIdAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `DeleteImageByIdAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductImage.cs` $\rightarrow$ Bảng `ProductImages` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của hình ảnh cần xóa |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`204 NoContent`)
* Không có Response Body.

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid image identifier format."` | GUID sai định dạng |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to delete this image."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `IMAGE_NOT_FOUND` | `"Image not found with the specified ID."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (images-route)
- [x] Status: COMPLETED
