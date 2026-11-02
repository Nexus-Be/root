# [POST] /api/v1/products/{id}/variants

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products / Variants`  
> **Mã tham chiếu Excel:** `CAT-07`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thêm một biến thể SKU mới vào sản phẩm đã có (tối đa 10 biến thể cho mỗi sản phẩm).
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}/variants`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được thêm biến thể cho sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Không bắt buộc

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `AddVariant()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `AddVariantAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `AddVariantAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm cha |

### 3.2. Request Body Schema (`CreateVariantRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `skuCode` | `string` | Có | Mã SKU duy nhất trong hệ thống |
| `name` | `string` | Có | Tên biến thể (ví dụ: Size L - Đen) |
| `price` | `decimal?` | Không | Giá bán (bắt buộc đối với Regular product) |
| `currency` | `string?` | Không | Mặc định `"VND"` |
| `attributes` | `List<CreateVariantAttributeRequest>?` | Không | Cặp thuộc tính (`attrName`, `attrValue`) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`201 Created` - `ApiResponse<VariantDetailDto>`)
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Variant created successfully.",
  "data": {
    "id": "99999999-9999-9999-9999-999999999992",
    "productId": "88888888-8888-8888-8888-888888888888",
    "skuCode": "TSHIRT-BLK-L",
    "name": "Size L - Màu Đen",
    "price": 190000,
    "currency": "VND",
    "isActive": true,
    "hasOrder": false,
    "status": "Active",
    "statusReason": null,
    "attributes": [
      { "attrName": "Size", "attrValue": "L" },
      { "attrName": "Color", "attrValue": "Black" }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid variant creation request."` | SKUCode hoặc tên trống |
| `400 BadRequest` | `VAL_LIMIT_EXCEEDED` | `"A product can have a maximum of 10 variants."` | Đã đạt giới hạn 10 biến thể |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to add variants for this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại |
| `409 Conflict` | `SKU_ALREADY_EXISTS` | `"SKU code already exists in the catalog."` | `skuCode` bị trùng lặp |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
