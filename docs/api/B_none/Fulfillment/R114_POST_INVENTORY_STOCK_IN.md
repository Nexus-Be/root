# [POST] /api/v1/inventories/batch-adjust

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Inventories`  
> **Mã tham chiếu Excel:** `FUL-02 + CAT-24`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Nhập hàng hoặc điều chỉnh số lượng tồn kho cho một danh sách nhiều mã sản phẩm/biến thể (SKU) trong một giao dịch nguyên tử (Atomic transaction).
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/inventories/batch-adjust` (Hỗ trợ cả endpoint đơn lẻ: `POST /api/v1/inventories/adjust`)
* **Đường dẫn gốc trong Excel:** `/api/v1/inventory/stock-in`
* **Quyền hạn truy cập (RBAC):** `Seller`, `Admin` (`[RequireRole("seller", "admin")]`)
* **Quy tắc sở hữu (Resource Ownership):** Seller chỉ được nhập/điều chỉnh tồn kho cho các sản phẩm tại kho hàng thuộc quyền sở hữu của mình.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `inventories-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/InventoriesController.cs` $\rightarrow$ `BatchAdjustInventory([FromBody] BatchAdjustInventoryRequest request)`
* **Application Interface:** `Fulfillment.Application/Services/Inventory/IInventoryAppService.Items.cs` $\rightarrow$ `BatchAdjustInventoryAsync()`
* **Thực thể & Bảng DB:** `InventoryItem.cs` (`inventory_items`), `InventoryLedger.cs` (`inventory_ledgers`)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body Record DTO
- **Vị trí file:** `Fulfillment.Application/Services/Inventory/InventoryItemDtos.cs`
- **Tên C# Record:** `BatchAdjustInventoryRequest`
```csharp
public sealed record BatchAdjustInventoryRequest(
    [Required(ErrorMessage = "Items list is required.")]
    [MinLength(1, ErrorMessage = "At least one inventory adjustment item is required.")]
    IReadOnlyList<BatchAdjustInventoryItemRequest> Items,

    string? Note = null,
    Guid? WarehouseId = null
);

public sealed record BatchAdjustInventoryItemRequest(
    [Required(ErrorMessage = "SKU ID is required.")]
    Guid SkuId,

    [Required(ErrorMessage = "Adjustment type is required.")]
    InventoryAdjustmentType Type, // Intake (1) hoặc Adjust (2)

    int Quantity,

    string? Note = null
);
```

### 3.2. JSON Request Body mẫu (camelCase)
```json
{
  "warehouseId": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
  "note": "Nhap kho lo hang dot 1",
  "items": [
    {
      "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "type": "Intake",
      "quantity": 50,
      "note": "Nhap them 50 ao thun"
    },
    {
      "skuId": "a2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
      "type": "Intake",
      "quantity": 30,
      "note": "Nhap them 30 quan jean"
    }
  ]
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<BatchAdjustInventoryResponse>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "warehouseId": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
    "totalItemsAdjusted": 2,
    "items": [
      {
        "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "totalQuantity": 150,
        "reservedQuantity": 10,
        "availableQuantity": 140,
        "adjustmentLedgerId": "f1a2b3c4-d5e6-4a7b-8c9d-0e1f2a3b4c5d"
      },
      {
        "skuId": "a2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
        "totalQuantity": 80,
        "reservedQuantity": 0,
        "availableQuantity": 80,
        "adjustmentLedgerId": "f2b3c4d5-e6a7-4b8c-9d0e-1f2a3b4c5d6e"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Items list is required." | Danh sách điều chỉnh rỗng hoặc số lượng không hợp lệ. |
| `400` | `INVALID_ADJUSTMENT` | "Total quantity cannot be negative." | Điều chỉnh làm tồn kho âm. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không sở hữu kho hàng. |
| `404` | `WAREHOUSE_NOT_FOUND` | "Warehouse not found." | Không tìm thấy kho tương ứng. |
| `404` | `INVENTORY_NOT_FOUND` | "Inventory item for SKU '{skuId}' was not found." | Chưa khởi tạo tồn kho cho SKU này. |

---

## 6. DANH MỤC ENUM LIÊN QUAN

### 6.1. Loại Điều chỉnh Tồn kho (`InventoryAdjustmentType`)
| Giá trị DB (int) | Giá trị API (PascalCase) | Ý nghĩa nghiệp vụ |
|:---:|:---|:---|
| `1` | `Intake` | Nhập thêm hàng vào kho (Cộng dồn số lượng) |
| `2` | `Adjust` | Điều chỉnh kiểm kê (Cập nhật trực tiếp số lượng lệch) |
