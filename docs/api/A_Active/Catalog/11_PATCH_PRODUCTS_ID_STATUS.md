# [PATCH] /api/v1/products/{id}/status

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** `CAT-03`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-11-02 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thay đổi trạng thái vòng đời của sản phẩm (`Draft`, `Active`, `Inactive`, `Suspended`).
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/products/{id}/status`
* **Quyền hạn truy cập (RBAC):** `seller`, `admin`
* **Quy tắc sở hữu (Resource Ownership):** Người bán chỉ được đổi trạng thái sản phẩm của chính mình; trạng thái `Suspended` chỉ do `admin` can thiệp.
* **Yêu cầu Idempotency:** Idempotent

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `products-route`)
* **Controller Action:** `Catalog.Api/Controllers/Public/ProductsController.cs` $\rightarrow$ `ChangeStatus()`
* **Application Interface:** `Catalog.Application/Services/Product/IProductService.cs` $\rightarrow$ `ChangeStatusAsync()`
* **Service Implementation:** `Catalog.Application/Services/Product/ProductService.cs` $\rightarrow$ `ChangeStatusAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/Product.cs` $\rightarrow$ Bảng `Products` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc |
|:---|:---|:---:|:---|
| `id` | `Guid` | Có | Định dạng UUIDv4 của sản phẩm |

### 3.2. Request Body Schema (`ChangeProductStatusRequest`)
| Thuộc tính | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Ghi chú |
|:---|:---|:---:|:---|
| `status` | `string` | Có | Chuỗi PascalCase (`"Draft"`, `"Active"`, `"Inactive"`) |
| `statusReason` | `string?` | Không | Lý do thay đổi trạng thái |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công (`200 OK` - `ApiResponse<ProductDto>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Product status updated successfully.",
  "data": {
    "id": "88888888-8888-8888-8888-888888888888",
    "sellerId": "cccccccc-3333-3333-3333-333333333333",
    "categoryId": "10000000-0000-0000-0000-000000000001",
    "name": "Áo Thun Cotton Nexus",
    "description": "Chất liệu 100% cotton thoáng mát",
    "brand": "Nexus Fashion",
    "status": "Active"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T12:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | Error Code | Error Message (Sentence case) | Điều kiện kích hoạt |
| :---: | :--- | :--- | :--- |
| `400 BadRequest` | `VAL_INVALID_INPUT` | `"Invalid product status transition."` | Trạng thái không hợp lệ |
| `401 Unauthorized` | `UNAUTHORIZED` | `"Authentication is required to access this resource."` | Thiếu token xác thực |
| `403 Forbidden` | `FORBIDDEN` | `"You do not have permission to change status for this product."` | Không phải chủ sở hữu hoặc admin |
| `404 NotFound` | `PRODUCT_NOT_FOUND` | `"Product not found in the system."` | `id` không tồn tại |

---

## 6. CHECKLIST NGHIỆM THU (COMPLETION CHECKLIST)
- [x] Implementation Hoàn tất
- [x] Tests Passed (100%)
- [x] Gateway Aligned (products-route)
- [x] Status: COMPLETED
