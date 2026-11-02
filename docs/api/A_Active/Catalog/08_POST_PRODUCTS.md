# [POST] /api/v1/products

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-01`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán hoặc quản trị viên tạo sản phẩm thông thường mới (Regular) ở trạng thái ban đầu `Draft`, có thể kèm danh sách biến thể SKU khởi tạo.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/products`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** `SellerId` tự động lấy từ danh tính người dùng đăng nhập (`x-user-id`). Seller không được tạo sản phẩm thay cho seller khác.
* **Yêu cầu Idempotency:** Không bắt buộc

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `Create()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `CreateAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `CreateAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body Schema (`CreateProductRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `categoryId` | `Guid` | Có | Danh mục sản phẩm hợp lệ, tồn tại trong hệ thống |
| `name` | `string` | Có | Tên sản phẩm, tối đa 250 ký tự |
| `description` | `string?` | Không | Mô tả chi tiết sản phẩm |
| `brand` | `string?` | Không | Tên thương hiệu |
| `saleType` | `SaleType` | Không | Mặc định `Regular` (1) |
| `specifications` | `string?` | Không | Chuỗi JSON chứa thông số kỹ thuật |
| `variants` | `List<CreateVariantRequest>?` | Không | Danh sách biến thể SKU ban đầu (tối đa 10) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`201 Created` - `ApiResponse<ProductDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Product created successfully.",
  "data": {
    "id": "88888888-8888-8888-8888-888888888888",
    "sellerId": "cccccccc-3333-3333-3333-333333333333",
    "categoryId": "10000000-0000-0000-0000-000000000001",
    "name": "Áo Thun Cotton Nexus",
    "description": "Chất liệu 100% cotton thoáng mát",
    "brand": "Nexus Fashion",
    "status": "Draft"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product creation request."` | Tên trống, categoryId không hợp lệ |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hoặc token không hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You cannot create products on behalf of another seller."` | `SellerId` không khớp người đăng nhập |
| `404 NotFound` | `CATEGORY_NOT_FOUND` | `"Category not found with the specified ID."` | `categoryId` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
