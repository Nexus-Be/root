# [GET] /api/v1/products

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-05 / CAT-20 / CAT-21`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tìm kiếm và duyệt danh sách sản phẩm công khai với bộ lọc phân loại, khoảng giá, rating, hình thức bán, phân trang và sắp xếp (hỗ trợ cả route gốc `/api/v1/products` và alias `/api/v1/products/search`).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/products` (Alias: `/api/v1/products/search`)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `Search()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `SearchAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `SearchAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `keyword` | `string?` | null | Tìm kiếm theo tên sản phẩm hoặc thương hiệu |
| `categoryId` | `Guid?` | null | Lọc theo mã danh mục |
| `sellerId` | `Guid?` | null | Lọc theo ID người bán |
| `saleType` | `SaleType?` | null | `Regular`, `Auction` |
| `minPrice` | `decimal?` | null | Giá thấp nhất |
| `maxPrice` | `decimal?` | null | Giá cao nhất |
| `sortBy` | `string?` | null | `name`, `price`, `rating`, `createdAt` |
| `sortDirection` | `string?` | `"asc"` | `asc` hoặc `desc` |
| `page` | `integer` | `1` | Số trang (tối thiểu 1) |
| `pageSize` | `integer` | `20` | Kích thước trang ($1 \le pageSize \le 100$) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<ProductListItemDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Products retrieved successfully.",
  "data": {
    "items": [
      {
        "productId": "88888888-8888-8888-8888-888888888888",
        "name": "Áo Thun Cotton Nexus",
        "brand": "Nexus Fashion",
        "saleType": "Regular",
        "status": "Active",
        "minPrice": 150000,
        "maxPrice": 200000,
        "primaryImageUrl": "https://res.cloudinary.com/.../ao-thun.jpg",
        "avgRating": 4.8
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 42,
      "totalPages": 3,
      "hasPreviousPage": false,
      "hasNextPage": true
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid search parameters."` | Khoảng giá min > max hoặc page < 1 |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
