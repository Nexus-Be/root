# [GET] /api/v1/products/{id}/images

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-40`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy danh sách toàn bộ hình ảnh của một sản phẩm, sắp xếp theo thứ tự hiển thị (`sortOrder`).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}/images`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` (Public)
* **Quy tắc sở hữu (Resource Ownership):** Công khai cho tất cả người dùng
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `GetImages()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `GetProductImagesAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `GetProductImagesAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductImage.cs` $\rightarrow$ Bảng `ProductImages` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<IReadOnlyList<ProductImageDto>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Product images retrieved successfully.",
  "data": [
    {
      "id": "77777777-7777-7777-7777-777777777771",
      "productId": "88888888-8888-8888-8888-888888888888",
      "variantId": null,
      "url": "https://res.cloudinary.com/.../front.jpg",
      "altText": "Áo thun mặt trước",
      "isActive": true,
      "sortOrder": 1
    },
    {
      "id": "77777777-7777-7777-7777-777777777772",
      "productId": "88888888-8888-8888-8888-888888888888",
      "variantId": null,
      "url": "https://res.cloudinary.com/.../back.jpg",
      "altText": "Áo thun mặt sau",
      "isActive": true,
      "sortOrder": 2
    }
  ],
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product identifier format."` | GUID sai định dạng |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
