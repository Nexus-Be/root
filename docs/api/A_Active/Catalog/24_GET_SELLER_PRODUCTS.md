# [GET] /api/v1/seller/products

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products / Seller`  
> **Mã tham chiếu Excel:** `CAT-44`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán xem và tìm kiếm danh sách toàn bộ sản phẩm thuộc quyền sở hữu của shop mình (bao gồm các trạng thái `Draft`, `Active`, `Inactive`, `Suspended`), có hỗ trợ lọc và phân trang.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/seller/products`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Tự động lọc theo `currentUserId` từ header danh tính xác thực do Gateway tiêm vào (`x-user-id`).
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `seller-products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/SellerProductsController.cs` $\rightarrow$ `SearchSellerProducts()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `SearchSellerProductsAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `SearchSellerProductsAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Thuộc tính | Kiểu dữ liệu | Mặc định | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `page` | `int` | `1` | Số trang (tối thiểu 1) |
| `pageSize` | `int` | `20` | Kích thước trang ($1 \le pageSize \le 100$) |
| `keyword` | `string?` | null | Tìm kiếm theo tên sản phẩm, thương hiệu |
| `status` | `ProductStatus?` | null | `Draft`, `Active`, `Inactive`, `Suspended` |
| `categoryId` | `Guid?` | null | Lọc theo danh mục |
| `saleType` | `SaleType?` | null | `Regular`, `Auction` |
| `sortBy` | `string?` | null | `createdAt`, `name`, `price`, `status` |
| `sortDirection` | `string?` | `"asc"` | `"asc"` hoặc `"desc"` |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang Thành công (`200 OK` - `ApiResponse<PagedData<SellerProductListItemDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller products retrieved successfully.",
  "data": {
    "items": [
      {
        "productId": "88888888-8888-8888-8888-888888888888",
        "name": "Áo Thun Cotton Nexus",
        "brand": "Nexus Fashion",
        "categoryId": "10000000-0000-0000-0000-000000000001",
        "categoryName": "Thời Trang Nam",
        "saleType": "Regular",
        "status": "Active",
        "statusReason": null,
        "minPrice": 150000,
        "maxPrice": 200000,
        "primaryImageUrl": "https://res.cloudinary.com/.../front.jpg",
        "variantCount": 2,
        "hasOrder": false,
        "createdAt": "2026-11-01T10:00:00Z",
        "publishedAt": "2026-11-01T10:30:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid seller product query parameters."` | Phân trang hoặc dữ liệu sai |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hoặc token không hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to access seller products."` | Không có role seller hoặc admin |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (seller-products-route)
- [x] Status: COMPLETED
