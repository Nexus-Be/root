# [POST] /api/v1/categories

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Categories`  
> **Mã tham chiếu Excel:** `CAT-15`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên hoặc nhân viên tạo danh mục hàng hóa mới trong hệ thống.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/categories`
* **Quyền hạn truy cập (RBAC):** `RequireRole("admin", "staff")`
* **Yêu cầu Idempotency:** Tùy chọn

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `categories-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/CategoriesController.cs` $\rightarrow$ `Create()`
* **Application Interface:** `Catalog.Application/Services/Category/ICategoryService.cs` $\rightarrow$ `CreateAsync()`
* **Service Implementation:** `Catalog.Application/Services/Category/CategoryService.cs` $\rightarrow$ `CreateAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Category.cs` $\rightarrow$ Bảng `Categories` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body (JSON Payload)
```json
{
  "name": "Thời Trang Trẻ Em",
  "description": "Quần áo thời trang dành cho trẻ em",
  "parentId": "10000000-0000-0000-0000-000000000000",
  "sortOrder": 3
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<CategoryDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Category created successfully.",
  "data": {
    "id": "10000000-0000-0000-0000-000000000005",
    "name": "Thời Trang Trẻ Em",
    "description": "Quần áo thời trang dành cho trẻ em",
    "parentId": "10000000-0000-0000-0000-000000000000",
    "level": 2,
    "sortOrder": 3,
    "isDisabled": false,
    "createdAt": "2026-11-02T12:00:00Z",
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Category name is required."` | Thiếu tên danh mục |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access administrative endpoints."` | Chưa đăng nhập |
| `403 Forbidden` | `FORBIDDEN` | `"User does not possess administrative privileges."` | Không có quyền admin/staff |
| `404 NotFound` | `CATEGORY_NOT_FOUND` | `"Parent category not found."` | Không tìm thấy danh mục cha |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (categories-route)
- [x] Status: COMPLETED
