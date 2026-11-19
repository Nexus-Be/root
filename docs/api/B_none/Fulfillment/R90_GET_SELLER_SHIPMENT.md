# [GET] /api/v1/shipments/tracking/{trackingNumber}

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-10`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu thông tin chi tiết và dòng thời gian các sự kiện vận chuyển theo mã vận đơn hãng GHN (`trackingNumber`).
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/shipments/tracking/{trackingNumber}`
* **Đường dẫn gốc trong Excel:** `/api/v1/seller/shipment/{shipmentId}` (Chuẩn hóa sang tra cứu theo mã vận đơn công khai cho cả Seller và Buyer).
* **Quyền hạn truy cập (RBAC):** `Buyer`, `Seller`, `Admin`, `Staff` (`[RequireRole("buyer", "seller", "admin", "staff")]`)
* **Quy tắc sở hữu (Resource Ownership):** Buyer chỉ tra cứu vận đơn đơn hàng của mình; Seller chỉ tra cứu vận đơn xuất từ kho của mình; Admin/Staff tra cứu toàn bộ.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShipmentsController.cs` $\rightarrow$ `GetByTrackingNumber([FromRoute] string trackingNumber)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow$ `GetByTrackingNumberAsync()`
* **Service Implementation:** `Fulfillment.Application/Services/Shipment/ShipmentService.cs` $\rightarrow$ `GetByTrackingNumberAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs` $\rightarrow$ Bảng `shipments` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `trackingNumber` | `string` | Có | Chuỗi mã vận đơn GHN (VD: `GHN1029384`) |

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
    "estimatedDeliveryAt": "2026-11-21T10:00:00Z",
    "deliveredAt": null,
    "items": [],
    "events": [
      {
        "id": "f1a2b3c4-d5e6-4a7b-8c9d-0e1f2a3b4c5d",
        "carrierStatus": "delivering",
        "status": "InTransit",
        "description": "Shipper dang giao kien hang",
        "occurredAt": "2026-11-19T08:30:00Z",
        "shipperName": "Nguyen Van B",
        "shipperPhone": "0987654321",
        "podUrl": null,
        "warehouseName": "Buu cuc Tan Binh"
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
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Người dùng không sở hữu vận đơn. |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found with tracking number '{trackingNumber}'." | Không tìm thấy mã vận đơn. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống nội bộ. |
