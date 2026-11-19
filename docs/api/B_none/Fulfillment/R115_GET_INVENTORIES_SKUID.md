# [GET] /api/v1/inventories/{skuId}

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Inventories`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu số lượng tồn kho khả dụng (`availableQuantity`), tổng số lượng (`totalQuantity`), số lượng đang bị giữ chỗ (`reservedQuantity`) của một mã biến thể (SKU).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/inventories/{skuId}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` / Public (Phục vụ tra cứu kiểm tra tồn hàng trên PDP và Checkout).
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo chuẩn HTTP GET).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `inventories-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/InventoriesController.cs` $\rightarrow$ `GetBySkuId([FromRoute] Guid skuId)`
* **Application Interface:** `Fulfillment.Application/Services/Inventory/IInventoryAppService.Items.cs` $\rightarrow$ `GetBySkuIdAsync()`
* **Thực thể & Bảng DB:** `InventoryItem.cs` $\rightarrow$ Bảng `inventory_items` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng | Ghi chú |
|:---|:---|:---:|:---|:---|
| `skuId` | `Guid (UUID)` | Có | UUIDv4 format | Mã định danh biến thể sản phẩm |

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
    "totalQuantity": 150,
    "reservedQuantity": 10,
    "availableQuantity": 140,
    "soldQuantity": 25,
    "minStockThreshold": 10,
    "isLowStockAlertEnabled": true,
    "isLowStock": false,
    "lastMovementAt": "2026-11-19T08:00:00Z",
    "updatedAt": "2026-11-19T08:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `404` | `NOT_FOUND` | "Inventory not found for SKU '{skuId}'." | Chưa có bản ghi tồn kho cho SKU này. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống. |
