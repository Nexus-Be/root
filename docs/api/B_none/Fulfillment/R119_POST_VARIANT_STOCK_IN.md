# [POST] /api/v1/inventories/initialize

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Inventories`  
> **Mã tham chiếu Excel:** `FUL-02 + CAT-23`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Khai báo và khởi tạo số dư tồn kho ban đầu cho một mã biến thể sản phẩm (SKU) tại một kho hàng cụ thể.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/inventories/initialize`
* **Đường dẫn gốc trong Excel:** `/api/v1/variant/{variantId}/stock-in` (Chuẩn hóa sang endpoint khai báo tồn kho theo SKU ID trong phân hệ Fulfillment).
* **Quyền hạn truy cập (RBAC):** `Seller`, `Admin`, `Staff` (`[RequireRole("seller", "admin", "staff")]`)
* **Quy tắc đặc thù:**
  * Seller chỉ được khởi tạo tồn kho cho kho hàng do mình sở hữu.
  * Nhân viên Staff chỉ được phép khởi tạo tồn kho với số lượng ban đầu bằng `0`. Khởi tạo số lượng khác 0 yêu cầu quyền Seller hoặc Admin.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `inventories-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/InventoriesController.cs` $\rightarrow$ `InitializeInventory([FromBody] DeclareInventoryRequest request)`
* **Application Interface:** `Fulfillment.Application/Services/Inventory/IInventoryAppService.Items.cs` $\rightarrow$ `DeclareInventoryAsync()`
* **Thực thể & Bảng DB:** `InventoryItem.cs` (`inventory_items`), `InventoryLedger.cs` (`inventory_ledgers`)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body Record DTO
- **Vị trí file:** `Fulfillment.Application/Services/Inventory/InventoryItemDtos.cs`
- **Tên C# Record:** `DeclareInventoryRequest`
```csharp
public sealed record DeclareInventoryRequest(
    [Required(ErrorMessage = "SKU ID is required.")]
    Guid SkuId,

    [Required(ErrorMessage = "Warehouse ID is required.")]
    Guid WarehouseId,

    [Range(0, int.MaxValue, ErrorMessage = "Quantity must be greater than or equal to 0.")]
    int Quantity,

    string? Note = null
);
```

### 3.2. JSON Request Body mẫu (camelCase)
```json
{
  "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "warehouseId": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
  "quantity": 100,
  "note": "Khoi tao ton kho ban dau khi tao san pham"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<InventoryItemResponse>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": "e0b1c2d3-e4f5-4a6b-8c9d-0e1f2a3b4c5d",
    "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "warehouseId": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
    "totalQuantity": 100,
    "reservedQuantity": 0,
    "availableQuantity": 100,
    "soldQuantity": 0,
    "minStockThreshold": 10,
    "isLowStockAlertEnabled": true,
    "isLowStock": false,
    "lastMovementAt": "2026-11-19T09:00:00Z",
    "updatedAt": "2026-11-19T09:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "SKU ID is required." | Thiếu skuId hoặc warehouseId. |
| `400` | `VAL_INVALID_INPUT` | "Staff may initialize inventory with quantity 0 only." | Nhân viên Staff khai báo số lượng khác 0. |
| `400` | `INVENTORY_ALREADY_INITIALIZED` | "Inventory for SKU '{skuId}' already initialized in this warehouse." | SKU đã được khởi tạo trong kho này trước đó. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không sở hữu kho hàng. |
| `404` | `WAREHOUSE_NOT_FOUND` | "Warehouse not found." | Không tìm thấy kho tương ứng. |
