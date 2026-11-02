# [GET] /api/v1/categories

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Categories`  
> **Mã tham chiếu Excel:** `CAT-18`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy danh sách danh mục hàng hóa (hỗ trợ phân trang, lọc theo danh mục cha, tìm kiếm từ khóa, và dựng cây danh mục đa cấp).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/categories`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `categories-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/CategoriesController.cs` $\rightarrow$ `List()`
* **Application Interface:** `Catalog.Application/Services/Category/ICategoryService.cs` $\rightarrow$ `GetCategoriesAsync()`
* **Service Implementation:** `Catalog.Application/Services/Category/CategoryService.cs` $\rightarrow$ `GetCategoriesAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Category.cs` $\rightarrow$ Bảng `Categories` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số trang (tối thiểu 1) |
| `pageSize` | `integer` | `10` | Số phần tử trên 1 trang (1 - 100) |
| `sortBy` | `string?` | `"sortOrder"` | `sortOrder`, `name`, `level`, `createdAt` |
| `sortDirection` | `string?` | `"asc"` | `asc` hoặc `desc` |
| `parentId` | `Guid?` | null | ID danh mục cha nếu muốn lọc nhánh con |
| `tree` | `boolean` | `false` | `true` để dựng cây lồng nhau, `false` trả về danh sách phẳng |
| `keyword` | `string?` | null | Từ khóa tìm kiếm theo tên |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<CategoryItemDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Categories retrieved successfully.",
  "data": {
    "items": [
      {
        "categoryId": "10000000-0000-0000-0000-000000000001",
        "parentId": null,
        "name": "Thời Trang",
        "description": "Quần áo thời trang nam nữ",
        "level": 1,
        "sortOrder": 1,
        "children": []
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 10,
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid category query parameters."` | Tham số lọc sai định dạng |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (categories-route)
- [x] Status: COMPLETED
