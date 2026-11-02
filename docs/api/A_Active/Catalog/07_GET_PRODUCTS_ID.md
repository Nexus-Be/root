# [GET] /api/v1/products/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-06`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin chi tiết đầy đủ của sản phẩm theo mã `id` (bao gồm các biến thể SKU, hình ảnh, chỉ số đánh giá).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `GetById()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `GetDetailAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `GetDetailAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 hợp lệ |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<ProductDetailDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Product retrieved successfully.",
  "data": {
    "productId": "88888888-8888-8888-8888-888888888888",
    "sellerId": "cccccccc-3333-3333-3333-333333333333",
    "categoryId": "10000000-0000-0000-0000-000000000001",
    "name": "Áo Thun Cotton Nexus",
    "description": "Chất liệu 100% cotton thoáng mát",
    "brand": "Nexus Fashion",
    "saleType": "Regular",
    "status": "Active",
    "variants": [
      {
        "variantId": "99999999-9999-9999-9999-999999999991",
        "sku": "TSHIRT-BLK-M",
        "price": 180000,
        "isDefault": true,
        "status": "Active",
        "attributes": [
          { "name": "Size", "value": "M" },
          { "name": "Color", "value": "Black" }
        ]
      }
    ],
    "images": [
      {
        "imageId": "77777777-7777-7777-7777-777777777771",
        "imageUrl": "https://res.cloudinary.com/.../front.jpg",
        "isPrimary": true,
        "sortOrder": 1
      }
    ],
    "rating": {
      "avgRating": 4.8,
      "totalReviews": 25
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product identifier format."` | GUID sai định dạng |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | Không tìm thấy sản phẩm |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
