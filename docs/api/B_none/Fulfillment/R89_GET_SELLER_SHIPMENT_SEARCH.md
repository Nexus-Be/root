# [GET] /api/v1/shipments (Tìm kiếm & Bộ lọc nâng cao)

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-09`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tìm kiếm và lọc danh sách vận đơn theo nhiều tiêu chí kết hợp (Mã vận đơn, Trạng thái, Kho hàng, Khoảng thời gian) cho Người bán và Quản trị viên.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/shipments`
* **Đường dẫn gốc trong Excel:** `/api/v1/seller/shipment/search` (Hợp nhất vào endpoint chuẩn RESTful `/api/v1/shipments` có truyền query filter `ShipmentFilterRequest`).
* **Quyền hạn truy cập (RBAC):** `Seller`, `Admin`, `Staff` (`[RequireRole("buyer", "seller", "admin", "staff")]`)
* **Quy tắc sở hữu (Resource Ownership):** Seller chỉ tìm kiếm trong phạm vi các kho của mình; Admin/Staff tìm kiếm toàn sàn.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShipmentsController.cs` $\rightarrow$ `ListShipments([FromQuery] ShipmentFilterRequest request)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow$ `ListShipmentsAsync()`
* **Service Implementation:** `Fulfillment.Application/Services/Shipment/ShipmentService.cs` $\rightarrow$ `ListShipmentsAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs` $\rightarrow$ Bảng `shipments` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters (Tham số lọc)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Khoảng giá trị | Ghi chú |
|:---|:---|:---:|:---|:---|
| `trackingNumber` | `string` | Không | Tối đa 50 ký tự | Tìm chính xác theo mã vận đơn GHN |
| `status` | `string` | Không | PascalCase string | `ReadyToPick`, `InTransit`, `Delivered`... |
| `warehouseId` | `Guid` | Không | UUIDv4 format | Giới hạn tìm trong một kho hàng cụ thể |
| `orderId` | `Guid` | Không | UUIDv4 format | Tìm vận đơn của đơn hàng con |
| `fromDate` | `DateTimeOffset` | Không | ISO 8601 | Lọc vận đơn tạo từ mốc thời gian |
| `toDate` | `DateTimeOffset` | Không | ISO 8601 | Lọc vận đơn tạo đến mốc thời gian |
| `page` | `integer` | Không | Mặc định: 1, Min: 1 | Số trang |
| `pageSize` | `integer` | Không | Mặc định: 20, Range: 1 - 100 | Số phần tử mỗi trang |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<ShipmentDto>>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
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
        "events": []
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
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
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Định dạng ngày hoặc phân trang sai. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu Bearer token. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không có vai trò hợp lệ. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống nội bộ. |
