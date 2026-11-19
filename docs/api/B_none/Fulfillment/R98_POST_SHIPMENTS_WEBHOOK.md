# [POST] /api/v1/webhooks/ghn

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Webhooks`  
> **Mã tham chiếu Excel:** `FUL-14`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tiếp nhận webhook thông báo đổi trạng thái đơn hàng từ đối tác Giao Hàng Nhanh (GHN), ghi nhận lịch sử sự kiện, cập nhật trạng thái vận đơn, và kích hoạt Outbox đồng bộ sang Commerce Service.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/webhooks/ghn` (Route tương đương: `/webhooks/ghn`, `/api/v1/webhooks/carriers/ghn`, `/api/v1/fulfillment/webhook/ghn`)
* **Đường dẫn gốc trong Excel:** `/api/v1/shipments/webhook`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` kèm bộ lọc bảo mật bắt buộc `[RequireGhnWebhookSecret]`.
* **Cơ chế xác thực Webhook:** Yêu cầu bí mật `token` thông qua query string (`?token=ghn-webhook-secret-key`) hoặc header `X-Webhook-Token`.
* **Cơ chế chống lặp (Idempotency):** Kiểm tra bảng `WebhookAuditLogs` theo `OrderCode` và `Status`. Nếu đã xử lý, trả về HTTP 200 ngay lập tức mà không xử lý lại.
* **Cơ chế chịu lỗi (Outbox Pattern):** Khi trạng thái đạt các mốc quan trọng (`HandedOver`, `InTransit`, `Delivered`, `DeliveryFailed`, `Returned`, `Cancelled`), hệ thống xếp hàng Outbox và tự động thử lại tối đa 12 lần sang Commerce Service (`POST /api/v1/sub-orders/{subOrderId}/delivery-status`).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `webhooks-ghn-route`, cấu hình bypass response envelope)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/GhnWebhookController.cs` $\rightarrow$ `HandleGhnCallback([FromBody] GhnWebhookPayload payload)`
* **Filter bảo mật:** `Fulfillment.Api/Filters/RequireGhnWebhookSecretAttribute.cs`
* **Thực thể & Bảng DB:** `WebhookAuditLog.cs` (`webhook_audit_logs`), `Shipment.cs` (`shipments`), `ShipmentEvent.cs` (`shipment_events`)
* **Outbox Worker:** `Fulfillment.Api/Workers/CommerceDeliveryNotificationWorker.cs`

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Mô tả |
|:---|:---|:---:|:---|
| `token` | `string` | Có (hoặc qua header) | Token bí mật xác thực webhook từ GHN |

### 3.2. Request Header (Tùy chọn thay thế query)
```json
{
  "X-Webhook-Token": "ghn-webhook-secret-key",
  "Content-Type": "application/json"
}
```

### 3.3. Request Body (GHN Webhook Payload - PascalCase / camelCase)
```json
{
  "OrderCode": "GHN1029384",
  "Status": "delivered",
  "ClientOrderCode": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "Description": "Đã giao hàng thành công đến tay người nhận",
  "Fee": 28000,
  "TotalFee": 28000,
  "ReasonCode": null,
  "Reason": null,
  "ShipperName": "Bưu tá Nguyễn Văn A",
  "ShipperPhone": "0987654321",
  "Warehouse": "Bưu cục Quận 1",
  "POD": "https://cdn.ghn.vn/pod/sign_001.jpg",
  "ConvertedWeight": 500
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

> **LƯU Ý:** Do GHN Webhook yêu cầu phản hồi dạng JSON phẳng (Flat protocol payload) theo chuẩn của nhà vận chuyển, Gateway tự động bypass `ResponseEnvelopeMiddleware` cho route này.

### 4.1. Phản hồi Thành công (Flat JSON)
```json
// 200 OK
{
  "message": "Webhook processed successfully.",
  "status": "Delivered"
}
```

### 4.2. Phản hồi Khi Gặp Sự Kiện Trùng Lặp (Idempotent Acknowledged)
```json
// 200 OK
{
  "message": "Duplicate webhook event acknowledged.",
  "status": "delivered"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Invalid webhook payload." | Payload null hoặc thiếu trường `OrderCode`. |
| `401` | `WEBHOOK_UNAUTHORIZED` | "A valid webhook token is required." | Token bí mật không khớp với cấu hình. |
| `503` | `WEBHOOK_NOT_CONFIGURED` | "The carrier webhook secret is not configured." | Hệ thống chưa cấu hình secret cho webhook. |

---

## 6. DANH MỤC ENUM ÁNH XẠ TRẠNG THÁI GHN SANG HỆ THỐNG

| Trạng thái gốc GHN (`Status`) | Ánh xạ ShipmentStatus | Ánh xạ Commerce SubOrderStatus |
|:---|:---|:---|
| `ready_to_pick` | `ReadyToPick` | Giữ nguyên `Confirmed` |
| `picking` | `Picking` | Giữ nguyên `Confirmed` |
| `storing`, `packed` | `Packed` | Giữ nguyên `Confirmed` |
| `picked` | `HandedOver` | `Shipped` |
| `delivering`, `money_collect_delivering` | `InTransit` | `Shipped` |
| `delivered` | `Delivered` | `Delivered` |
| `delivery_fail` | `DeliveryFailed` | `DeliveryAttemptFailed` |
| `return`, `returning`, `returned` | `Returned` | `Returned` |
| `cancel` | `Cancelled` | `Cancelled` |
