# [GET] /api/v1/seller/products/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products / Seller Detail`  
> **Mã tham chiếu Excel:** `CAT-45`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-03 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin chi tiết toàn diện của một sản phẩm dành cho người bán (bao gồm tất cả biến thể SKU, tình trạng đơn hàng `hasOrder`, danh sách hình ảnh và lý do trạng thái).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/seller/products/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Bắt buộc sản phẩm phải thuộc quyền sở hữu của người bán đang đăng nhập (`product.SellerId == currentUserId`). Tài khoản có vai trò `admin` hoặc `staff` có quyền can thiệp kiểm tra.
* **Yêu cầu Idempotency:** Không áp dụng

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `seller-products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/SellerProductsController.cs` $\rightarrow$ `GetSellerProductDetail()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `GetSellerProductDetailAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `GetSellerProductDetailAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs`, `ProductVariant.cs`, `ProductImage.cs` $\rightarrow$ Bảng `Products`, `ProductVariants`, `ProductImages` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Vị trí | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Ghi chú |
|:---|:---:|:---:|:---:|:---|
| `id` | Route | `Guid` | Có | Định dạng UUIDv4, khóa chính của sản phẩm cần tra cứu |

### 3.2. Query Parameters / Request Body
* Endpoint `GET` không sử dụng Query Parameters hay Request Body.

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<SellerProductDetailDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Seller product details retrieved successfully.",
  "data": {
    "productId": "77777777-7777-7777-7777-777777777777",
    "sellerId": "11111111-1111-1111-1111-111111111111",
    "categoryId": "22222222-2222-2222-2222-222222222222",
    "categoryName": "Bàn Phím Cơ",
    "name": "Bàn Phím Cơ Không Dây Nexus RGB",
    "description": "Bàn phím cơ Bluetooth 5.1 hotswap 3 modes kết nối.",
    "brand": "Nexus Tech",
    "specifications": "{\"switch\": \"Gateron Yellow\", \"battery\": \"4000mAh\"}",
    "saleType": "Regular",
    "status": "Active",
    "statusReason": null,
    "hasOrder": true,
    "createdAt": "2026-11-01T08:00:00Z",
    "updatedAt": "2026-11-01T09:30:00Z",
    "publishedAt": "2026-11-01T10:00:00Z",
    "images": [
      {
        "id": "44444444-4444-4444-4444-444444444444",
        "productId": "77777777-7777-7777-7777-777777777777",
        "variantId": null,
        "url": "https://res.cloudinary.com/nexus/image/upload/v1/products/kb-primary.webp",
        "altText": "Ảnh bìa chính",
        "isActive": true,
        "sortOrder": 0
      }
    ],
    "variants": [
      {
        "variantId": "33333333-3333-3333-3333-333333333333",
        "skuCode": "KB-NEXUS-01-WHITE",
        "name": "Màu Trắng - Gateron Yellow",
        "price": 1250000,
        "currency": "VND",
        "status": "Active",
        "statusReason": null,
        "isActive": true,
        "hasOrder": true,
        "attributes": [
          { "attrName": "Color", "attrValue": "White" }
        ],
        "images": []
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-03T00:15:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product identifier format."` | Chuỗi `id` trong route không đúng định dạng UUIDv4 |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Không có Bearer token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to view details of this product."` | Người bán không sở hữu sản phẩm này và không có quyền admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found with the specified identifier."` | Sản phẩm không tồn tại hoặc đã bị xóa mềm |
| `500 InternalServerError` | `INTERNAL_SERVER_ERROR` | `"An unexpected error occurred while processing the request."` | Lỗi máy chủ không mong muốn |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất (`SellerProductsController.cs` $\rightarrow$ `GetSellerProductDetail`)
- [x] Service Logic Hoàn tất (`ProductService.cs` $\rightarrow$ `GetSellerProductDetailAsync`)
- [x] Gateway Aligned (`seller-products-route` tại `/api/v1/seller/products/{**catch-all}`)
- [x] Status: COMPLETED
