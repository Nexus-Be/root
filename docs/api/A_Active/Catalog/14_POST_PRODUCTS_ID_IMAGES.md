# [POST] /api/v1/products/{id}/images

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-12`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán tải lên hình ảnh cho sản phẩm qua Cloudinary, giới hạn dung lượng tối đa 5MB, hỗ trợ định dạng `.jpg`, `.jpeg`, `.png`, `.webp`.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}/images`
* **Content-Type:** `multipart/form-data`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được tải ảnh cho sản phẩm thuộc quyền sở hữu của mình.
* **Yêu cầu Idempotency:** Không bắt buộc

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `UploadImage()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `AddProductImageAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `AddProductImageAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductImage.cs` $\rightarrow$ Bảng `ProductImages` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm |

### 3.2. Form Data Parameters (`multipart/form-data`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `file` | `IFormFile` | Có | File ảnh, kích thước $\le$ 5MB, định dạng: .jpg, .jpeg, .png, .webp |
| `variantId` | `Guid?` | Không | Gắn ảnh với biến thể SKU cụ thể |
| `altText` | `string?` | Không | Văn bản thay thế mô tả ảnh |
| `sortOrder` | `short` | Không | Thứ tự hiển thị, mặc định: `0` |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`201 Created` - `ApiResponse<ProductImageDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Product image uploaded successfully.",
  "data": {
    "id": "77777777-7777-7777-7777-777777777773",
    "productId": "88888888-8888-8888-8888-888888888888",
    "variantId": null,
    "url": "https://res.cloudinary.com/.../new-image.jpg",
    "altText": "Hình ảnh góc nghiêng",
    "isActive": true,
    "sortOrder": 3
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_FILE` | `"Please select an image file to upload."` | File trống hoặc không tồn tại |
| `400 BadRequest` | `VAL_LIMIT_EXCEEDED` | `"Image file size exceeds the 5MB limit."` | File vượt quá 5MB |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid image format. Supported formats: .jpg, .jpeg, .png, .webp."` | Đuôi file không được hỗ trợ |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to upload images for this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
