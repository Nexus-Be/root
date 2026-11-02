# [DELETE] /api/v1/categories/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Categories`  
> **Mã tham chiếu Excel:** `CAT-17`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên xóa mềm danh mục hàng hóa (nếu không có danh mục con hoặc sản phẩm trực thuộc).
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/categories/{id}`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `categories-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/CategoriesController.cs` $\rightarrow$ `Delete()`
* **Application Interface:** `Catalog.Application/Services/Category/ICategoryService.cs` $\rightarrow$ `DeleteAsync()`
* **Service Implementation:** `Catalog.Application/Services/Category/CategoryService.cs` $\rightarrow$ `DeleteAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Category.cs` $\rightarrow$ Bảng `Categories` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

* **HTTP Status Code:** `204 NoContent`
* Không trả về dữ liệu body (theo RFC 9110 và quy chuẩn Nexus Zero Body on Delete).

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `CATEGORY_HAS_CHILDREN` | `"Cannot delete category containing subcategories."` | Danh mục còn chứa nhánh con |
| `400 BadRequest` | `CATEGORY_HAS_PRODUCTS` | `"Cannot delete category containing active products."` | Danh mục còn chứa sản phẩm |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `CATEGORY_NOT_FOUND` | `"Category not found with the specified ID."` | Không tìm thấy danh mục |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (categories-route)
- [x] Status: COMPLETED
