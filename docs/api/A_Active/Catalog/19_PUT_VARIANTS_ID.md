# [PUT] /api/v1/variants/{id}

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Variants`  
> **Mã tham chiếu Excel:** `CAT-08`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Cập nhật thông tin chi tiết của một biến thể SKU (tên, giá bán, thuộc tính); hỗ trợ cả method `PUT` và `PATCH` tại `/api/v1/variants/{id}`.
* **HTTP Method:** `PUT` (Hỗ trợ alias: `PATCH`)
* **Đường dẫn chuẩn:** `/api/v1/variants/{id}`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được cập nhật biến thể của sản phẩm mình sở hữu.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `variants-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/VariantsController.cs` $\rightarrow$ `UpdateVariant()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `UpdateVariantAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `UpdateVariantAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của biến thể |

### 3.2. Request Body Schema (`UpdateVariantRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `name` | `string` | Có | Tên biến thể mới |
| `price` | `decimal` | Có | Giá bán mới (phải $\ge 0$) |
| `currency` | `string?` | Không | Mặc định `"VND"` |
| `attributes` | `List<CreateVariantAttributeRequest>?` | Không | Danh sách thuộc tính cập nhật |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<VariantDetailDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Variant updated successfully.",
  "data": {
    "id": "99999999-9999-9999-9999-999999999991",
    "productId": "88888888-8888-8888-8888-888888888888",
    "skuCode": "TSHIRT-BLK-M",
    "name": "Size M - Màu Đen Nhám",
    "price": 185000,
    "currency": "VND",
    "isActive": true,
    "hasOrder": false,
    "status": "Active",
    "statusReason": null,
    "attributes": [
      { "attrName": "Size", "attrValue": "M" },
      { "attrName": "Color", "attrValue": "Matte Black" }
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
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid variant update request."` | Giá âm hoặc tên trống |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token hợp lệ |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to modify this variant."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `VARIANT_NOT_FOUND` | `"Variant not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (variants-route)
- [x] Status: COMPLETED
