# [POST] /api/v1/shipments/{id}/sync-status

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-11`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Kích hoạt đồng bộ trạng thái mới nhất của vận đơn trực tiếp từ máy chủ GHN Carrier Gateway về hệ thống.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/shipments/{id}/sync-status`
* **Đường dẫn gốc trong Excel:** `/api/v1/shipments/{shipmentId}/tracking`
* **Quyền hạn truy cập (RBAC):** `Seller`, `Admin`, `Staff` (`[RequireRole("seller", "admin", "staff")]`)
* **Quy tắc sở hữu (Resource Ownership):** Seller chỉ đồng bộ vận đơn kho mình xuất; Admin/Staff đồng bộ bất kỳ vận đơn nào.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShipmentsController.cs` $\rightarrow$ `SyncStatus([FromRoute] Guid id)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow$ `SyncStatusAsync()`
* **Service Implementation:** `Fulfillment.Application/Services/Shipment/ShipmentService.cs` $\rightarrow$ `SyncStatusAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs` $\rightarrow$ Bảng `shipments` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng | Ghi chú |
|:---|:---|:---:|:---|:---|
| `id` | `Guid (UUID)` | Có | UUIDv4 format | Mã định danh vận đơn |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<ShipmentDto>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": "e0b1c2d3-e4f5-4a6b-8c9d-0e1f2a3b4c5d",
    "orderId": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
    "warehouseId": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
    "carrierId": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
    "trackingNumber": "GHN1029384",
    "status": "InTransit",
    "receiverName": "Nguyen Van A",
    "receiverPhone": "0912345678",
    "receiverAddress": "123 Le Loi, Ben Nghe, Quan 1, TP.HCM",
    "shippingFee": 28000.0,
    "printToken": "mock_ghn_token_xyz",
    "ghnOrderCode": "GHN1029384",
    "deliveredAt": null,
    "items": [],
    "events": [
      {
        "id": "f1a2b3c4-d5e6-4a7b-8c9d-0e1f2a3b4c5d",
        "carrierStatus": "delivering",
        "status": "InTransit",
        "description": "Status: delivering",
        "occurredAt": "2026-11-19T08:30:00Z"
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
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không sở hữu vận đơn. |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found with ID {id}." | Không tìm thấy vận đơn. |
| `502` | `CARRIER_ERROR` | "Failed to query order status from GHN." | GHN Gateway phản hồi lỗi kết nối. |
