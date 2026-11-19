# [GET] /api/v1/shipments

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** `FUL-08`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy danh sách vận đơn phân trang, hỗ trợ lọc theo trạng thái, kho hàng, mã vận đơn và khoảng thời gian.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/shipments`
* **Đường dẫn gốc trong Excel:** `/api/v1/seller/shipment` (Quy về route chuẩn hệ thống `/api/v1/shipments` có cách ly theo quyền người dùng).
* **Quyền hạn truy cập (RBAC):** `Buyer`, `Seller`, `Admin`, `Staff` (`[RequireRole("buyer", "seller", "admin", "staff")]`)
* **Quy tắc sở hữu (Resource Ownership):**
  * Với Seller: Hệ thống tự động lọc các vận đơn xuất phát từ kho hàng thuộc quyền sở hữu của Seller đó.
  * Với Buyer: Hệ thống lọc các vận đơn mà người dùng là người mua (`buyerId == currentUserId`).
  * Với Admin / Staff: Truy cập danh sách vận đơn của toàn bộ hệ sinh thái.
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo chuẩn HTTP GET).

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

### 3.1. Query Parameters (Tham số truy vấn)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị | Ghi chú |
|:---|:---|:---:|:---|:---|
| `page` | `integer` | `1` | $\ge 1$ | Số trang |
| `pageSize` | `integer` | `20` | $1 \le pageSize \le 100$ | Kích thước trang |
| `status` | `string` | `null` | PascalCase enum | Lọc trạng thái (`InTransit`, `Delivered`...) |
| `trackingNumber` | `string` | `null` | Tối đa 50 ký tự | Tìm theo mã vận đơn |
| `orderId` | `Guid` | `null` | UUIDv4 format | Lọc theo đơn hàng con |
| `warehouseId` | `Guid` | `null` | UUIDv4 format | Lọc theo kho xuất |
| `fromDate` | `DateTimeOffset` | `null` | ISO 8601 | Thời gian tạo từ ngày |
| `toDate` | `DateTimeOffset` | `null` | ISO 8601 | Thời gian tạo đến ngày |

### 3.2. Request Header
```json
{
  "Authorization": "Bearer <JWT_TOKEN>"
}
```

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
        "buyerId": "d1e2f3a4-b5c6-4d7e-8f9a-0b1c2d3e4f5a",
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
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Tham số phân trang hoặc filter không hợp lệ. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Người dùng chưa đăng nhập hoặc token hết hạn. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Không có vai trò phù hợp trong JWT claims. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống nội bộ. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)
* `ShipmentStatus`: `ReadyToPick (0)`, `Picking (1)`, `Packed (2)`, `HandedOver (3)`, `InTransit (4)`, `Delivered (5)`, `DeliveryFailed (6)`, `Returned (7)`, `Cancelled (8)`.
