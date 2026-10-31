# [POST] /api/v1/products/{productId}/variants

> **Phân hệ thụ lý:** `CatalogService`  
> **Tên tính năng:** `Products`  
> **Mã tham chiếu Excel:** ``CAT-07``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thêm biến thể cho sản phẩm
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/products/{productId}/variants`
* **Đường dẫn gốc trong Excel:** `/api/v1/product/{productId}/variants` (Chuẩn hóa từ '/api/v1/product/{productId}/variants' sang chuẩn 100% số nhiều '/api/v1/products/{productId}/variants'.)
* **Quyền hạn truy cập (RBAC):** `Seller`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Catalog/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `catalog-variants-route`)
* **Controller Action:** `Catalog.Api/Controllers/ProductsController.cs` $\rightarrow$ `CreateProduct()`
* **Application Interface:** `Catalog.Application/Services/Products/IProductService.cs` $\rightarrow$ `CreateProductAsync()`
* **Service Implementation:** `Catalog.Application/Services/Products/ProductService.cs` $\rightarrow$ `CreateProductAsync()`
* **Thực thể & Bảng DB:** `Catalog.Domain/Entities/ProductVariant.cs` $\rightarrow$ Bảng `ProductVariants` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `productId` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Body:
{
"skuCode": "string",
"name": "string",
"price": "decimal (> 0)",
"currency": "string (mặc định VND)",
"attributes": [
{
"attrName": "string",
"attrValue": "string"
}
]
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "variantId": "uuid",
    "skuCode": "string",
    "status": "ACTIVE|INACTIVE"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `409` | `AUCTION_PRODUCT_SINGLE_VARIANT` | "Auction products cannot have additional variants." | Điều kiện nghiệp vụ đặc thù: AUCTION_PRODUCT_SINGLE_VARIANT. |
| `409` | `SKU_CODE_DUPLICATED` | "Skucode already exists on an active variant." | Điều kiện nghiệp vụ đặc thù: SKU_CODE_DUPLICATED. |
| `404` | `PRODUCT_NOT_FOUND` | "Product was not found or has been deleted." | Điều kiện nghiệp vụ đặc thù: PRODUCT_NOT_FOUND. |
| `403` | `FORBIDDEN` | "You are not the owner of this product and not an administrator." | Điều kiện nghiệp vụ đặc thù: FORBIDDEN. |
| `401` | `UNAUTHORIZED` | "Token is missing, expired, or invalid." | Điều kiện nghiệp vụ đặc thù: UNAUTHORIZED. |
| `400` | `VALIDATION_ERROR` | "Price must be > 0, attribute names mismatch with existing variants, or invalid productid." | Điều kiện nghiệp vụ đặc thù: VALIDATION_ERROR. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `PRODUCTVARIANT_NOT_FOUND` | "Productvariant not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `VariantStatus` | `0` | `Active` | **Còn hoạt động**: Biến thể SKU có thể chọn và mua được. Badge xanh lá. |
| `status` | `VariantStatus` | `1` | `Inactive` | **Ngưng hoạt động**: Biến thể SKU bị vô hiệu hóa hoặc hết hàng. Badge xám. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `IProductService.cs` và `ProductService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `ProductsController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `ProductsTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `catalog-variants-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
