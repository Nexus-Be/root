# [GET] /api/v1/shipments/{id}

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-06`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xem thông tin chi tiết một vận đơn theo ID, bao gồm danh sách kiện hàng và lịch sử hành trình vận chuyển.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/shipments/{id}`
* **Đường dẫn gốc trong Excel:** `/api/v1/shipments/{shipmentId}`
* **Quyền hạn truy cập (RBAC):** `Buyer`, `Seller`, `Admin`, `Staff` (`[RequireRole("buyer", "seller", "admin", "staff")]`)
* **Quy tắc sở hữu (Resource Ownership):**
  * Buyer chỉ được xem vận đơn gắn với đơn hàng của mình (`buyerId == currentUserId`).
  * Seller chỉ được xem vận đơn xuất từ kho của mình (`warehouse.SellerId == currentUserId`).
  * Admin / Staff được xem toàn bộ vận đơn trên hệ thống.
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo chuẩn HTTP GET).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShipmentsController.cs` $\rightarrow$ `GetById([FromRoute] Guid id)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow$ `GetByIdAsync(Guid id, Guid currentUserId, bool isAdminOrStaff, CancellationToken ct)`
* **Service Implementation:** `Fulfillment.Application/Services/Shipment/ShipmentService.cs` $\rightarrow$ `GetByIdAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs` $\rightarrow$ Bảng `shipments` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `id` | `Guid (UUID)` | Có | UUIDv4 format hợp lệ |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Header
```json
{
  "Authorization": "Bearer <JWT_TOKEN>"
}
```

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
    "receiverAddress": "123 Le Loi, Phuong Ben Nghe, Quan 1, TP. Ho Chi Minh",
    "buyerId": "d1e2f3a4-b5c6-4d7e-8f9a-0b1c2d3e4f5a",
    "toProvinceName": "TP. Ho Chi Minh",
    "toDistrictId": 1442,
    "toWardCode": "20101",
    "weight": 500,
    "length": 20,
    "width": 15,
    "height": 10,
    "shippingFee": 28000.0,
    "codAmount": 0,
    "insuranceValue": 0,
    "printToken": "mock_ghn_token_xyz",
    "ghnOrderCode": "GHN1029384",
    "estimatedDeliveryAt": "2026-11-21T10:00:00Z",
    "deliveredAt": null,
    "items": [
      {
        "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "quantity": 2,
        "name": "Ao Thun Cotton",
        "price": 150000.0,
        "weight": 250,
        "length": 10,
        "width": 10,
        "height": 5
      }
    ],
    "events": [
      {
        "id": "f1a2b3c4-d5e6-4a7b-8c9d-0e1f2a3b4c5d",
        "carrierStatus": "in_transit",
        "status": "InTransit",
        "description": "Kien hang dang tren duong van chuyen",
        "occurredAt": "2026-11-19T08:30:00Z",
        "shipperName": "Nguyen Van B",
        "shipperPhone": "0987654321",
        "podUrl": null,
        "warehouseName": "Kho Tong Tan Binh"
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
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token hoặc token không hợp lệ. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không sở hữu vận đơn và không phải Admin/Staff. |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found with ID {id}." | Không tìm thấy bản ghi vận đơn trong database. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống nội bộ. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

### 6.1. Trạng thái Vận đơn (`ShipmentStatus`)
| Giá trị DB (int) | Giá trị API (PascalCase) | Ý nghĩa nghiệp vụ |
|:---:|:---|:---|
| `0` | `ReadyToPick` | Đã tạo đơn, chờ shipper tới kho lấy hàng |
| `1` | `Picking` | Shipper đang đến kho lấy hàng |
| `2` | `Packed` | Đơn hàng đã đóng gói lưu kho |
| `3` | `HandedOver` | Đã bàn giao kiện hàng cho shipper |
| `4` | `InTransit` | Kiện hàng đang luân chuyển giữa các bưu cục |
| `5` | `Delivered` | Đã giao hàng thành công tới người nhận |
| `6` | `DeliveryFailed` | Giao hàng thất bại, chờ phát lại |
| `7` | `Returned` | Kiện hàng hoàn về lại kho gửi |
| `8` | `Cancelled` | Vận đơn đã bị hủy |
