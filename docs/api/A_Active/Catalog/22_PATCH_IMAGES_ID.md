# [PATCH] /api/v1/images/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Images`  
> **Mã tham chiếu Excel:** `CAT-14`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Cập nhật các thuộc tính của hình ảnh sản phẩm (cờ kích hoạt `isActive`, thứ tự sắp xếp `sortOrder`, mô tả `altText`).
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/images/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được cập nhật hình ảnh của sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `images-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ImagesController.cs` $\rightarrow$ `UpdateImage()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `UpdateImageAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `UpdateImageAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductImage.cs` $\rightarrow$ Bảng `ProductImages` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của hình ảnh |

### 3.2. Request Body Schema (`UpdateProductImageRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `isActive` | `bool?` | Không | Cờ kích hoạt hiển thị |
| `sortOrder` | `short?` | Không | Thứ tự hiển thị |
| `altText` | `string?` | Không | Mô tả văn bản cho hình ảnh |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<ProductImageDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Product image updated successfully.",
  "data": {
    "id": "77777777-7777-7777-7777-777777777771",
    "productId": "88888888-8888-8888-8888-888888888888",
    "variantId": null,
    "url": "https://res.cloudinary.com/.../front.jpg",
    "altText": "Áo thun cotton mặt trước màu đen",
    "isActive": true,
    "sortOrder": 1
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid image update request."` | GUID hoặc dữ liệu không hợp lệ |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to modify this image."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `IMAGE_NOT_FOUND` | `"Image not found with the specified ID."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (images-route)
- [x] Status: COMPLETED
