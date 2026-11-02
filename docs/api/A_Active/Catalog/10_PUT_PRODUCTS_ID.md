# [PUT] /api/v1/products/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-02`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán sở hữu sản phẩm hoặc quản trị viên cập nhật thông tin chung của sản phẩm (hỗ trợ cả method `PUT` và `PATCH` tại `/api/v1/products/{id}`).
* **HTTP Method:** `PUT` (Hỗ trợ alias: `PATCH`)
* **Đường dẫn chuẩn:** `/api/v1/products/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Chỉ chủ sở hữu sản phẩm (`SellerId == currentUserId`) hoặc tài khoản có role `admin` mới có quyền chỉnh sửa.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `Update()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `UpdateAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `UpdateAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm cần cập nhật |

### 3.2. Request Body Schema (`UpdateProductRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `name` | `string` | Có | Tên sản phẩm, tối đa 250 ký tự |
| `description` | `string?` | Không | Mô tả chi tiết sản phẩm |
| `brand` | `string?` | Không | Thương hiệu |
| `categoryId` | `Guid?` | Không | Mã danh mục sản phẩm nếu muốn đổi danh mục |
| `saleType` | `SaleType?` | Không | `Regular`, `Auction` |
| `specifications` | `string?` | Không | Thông số kỹ thuật dạng JSON |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<ProductDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Product updated successfully.",
  "data": {
    "id": "88888888-8888-8888-8888-888888888888",
    "sellerId": "cccccccc-3333-3333-3333-333333333333",
    "categoryId": "10000000-0000-0000-0000-000000000001",
    "name": "Áo Thun Cotton Nexus Cao Cấp",
    "description": "Chất liệu 100% cotton thoáng mát, form rộng",
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product update request."` | Tên trống hoặc sai dữ liệu |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to modify this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
