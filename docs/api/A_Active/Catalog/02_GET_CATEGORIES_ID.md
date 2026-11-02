# [GET] /api/v1/categories/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Categories`  
> **Mã tham chiếu Excel:** `CAT-19`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin chi tiết của một danh mục theo mã định danh `id`.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/categories/{id}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `categories-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/CategoriesController.cs` $\rightarrow$ `GetById()`
* **Application Interface:** `Catalog.Application/Services/Category/ICategoryService.cs` $\rightarrow$ `GetByIdAsync()`
* **Service Implementation:** `Catalog.Application/Services/Category/CategoryService.cs` $\rightarrow$ `GetByIdAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Category.cs` $\rightarrow$ Bảng `Categories` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<CategoryDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Category retrieved successfully.",
  "data": {
    "id": "10000000-0000-0000-0000-000000000001",
    "name": "Thời Trang Nam",
    "description": "Các mặt hàng thời trang dành cho nam giới",
    "parentId": "10000000-0000-0000-0000-000000000000",
    "level": 2,
    "sortOrder": 1,
    "isDisabled": false,
    "createdAt": "2026-01-01T00:00:00Z",
    "subcategories": []
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid category identifier format."` | GUID sai định dạng |
| `404 NotFound` | `CATEGORY_NOT_FOUND` | `"Category not found with the specified ID."` | Danh mục không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (categories-route)
- [x] Status: COMPLETED
