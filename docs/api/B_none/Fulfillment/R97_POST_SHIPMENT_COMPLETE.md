# [POST] /api/v1/shipments/orders/{orderId}/confirm-return

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-13`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán xác nhận đã nhận lại kiện hàng bị hoàn trả, hệ thống cập nhật trạng thái vận đơn sang `Returned` và tự động hoàn trả số lượng hàng vào kho tồn (`Restock`).
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/shipments/orders/{orderId}/confirm-return` (hoặc `/api/v1/seller/orders/{orderId}/confirm-return`)
* **Đường dẫn gốc trong Excel:** `/api/v1/shipment/{shipmentId}/complete` (Lưu ý: Luồng người mua bấm xác nhận đã nhận hàng thành công thuộc trách nhiệm của Commerce Service; phía Fulfillment xử lý xác nhận hoàn tất nhận hàng hoàn).
* **Quyền hạn truy cập (RBAC):** `Seller`, `Admin` (`[RequireRole("seller", "admin")]`)
* **Quy tắc sở hữu (Resource Ownership):** Seller chỉ xác nhận hàng hoàn của đơn xuất từ kho của mình.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShipmentsController.cs` $\rightarrow$ `ConfirmReturn([FromRoute] Guid orderId)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow$ `ConfirmReturnAsync()`
* **Service Implementation:** `Fulfillment.Application/Services/Shipment/ShipmentService.cs` $\rightarrow$ `ConfirmReturnAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs`, `InventoryItem.cs`, `InventoryLedger.cs`

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng | Ghi chú |
|:---|:---|:---:|:---|:---|
| `orderId` | `Guid (UUID)` | Có | UUIDv4 format | Mã định danh đơn hàng con (`subOrderId`) |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<ConfirmReturnResponse>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "success": true,
    "code": "RETURN_CONFIRMED",
    "message": "Returned package confirmed and inventory restored successfully.",
    "data": {
      "orderId": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
      "restoredStock": 2
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `INVALID_SHIPMENT_STATUS` | "Shipment is not in returnable status." | Vận đơn chưa ở trạng thái hoàn hàng. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không sở hữu kho xuất hàng. |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found for Order ID {orderId}." | Không tìm thấy vận đơn. |
