# [POST] /api/v1/shipments/webhook

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipments`  
> **Mã tham chiếu Excel:** ``FUL-14``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** nhận thông tin từ ghn.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/shipments/webhook`
* **Đường dẫn gốc trong Excel:** `/api/v1/shipments/webhook` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Fulfillment/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `fulfillment-shipments-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/ShipmentsController.cs` $\rightarrow$ `Webhook()`
* **Application Interface:** `Fulfillment.Application/Services/Shipments/IShipmentService.cs` $\rightarrow$ `WebhookAsync()`
* **Service Implementation:** `Fulfillment.Application/Services/Shipments/ShipmentService.cs` $\rightarrow$ `WebhookAsync()`
* **Thực thể & Bảng DB:** `Fulfillment.Domain/Entities/Shipment.cs` $\rightarrow$ Bảng `Shipments` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "trackingNumber": "GHN1029384756",
  "status": "Delivered",
  "location": "Quan 1, TP.HCM",
  "note": "Delivered to recipient.",
  "timestamp": "2026-10-26T16:00:00Z"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Webhook event processed.",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `404` | `SHIPMENT_NOT_FOUND` | "Tracking number does not match any existing shipment." | Điều kiện nghiệp vụ đặc thù: SHIPMENT_NOT_FOUND. |
| `400` | `CARRIER_WEBHOOK_INVALID_SIGNATURE` | "Invalid webhook signature from shipping provider." | Điều kiện nghiệp vụ đặc thù: CARRIER_WEBHOOK_INVALID_SIGNATURE. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `ShipmentStatus` | `0` | `ReadyToPick` | **Chờ lấy hàng**: Đã tạo mã vận đơn GHN, chờ bưu tá tới lấy kiện hàng. Badge vàng (Warning). |
| `status` | `ShipmentStatus` | `1` | `Picking` | **Đang lấy hàng**: Bưu tá đang trên đường đến kho Seller lấy hàng. Badge xanh dương nhạt (Info). |
| `status` | `ShipmentStatus` | `2` | `Packed` | **Đã đóng gói xong**: Kiện hàng đã đóng gói sẵn sàng bàn giao. Badge xanh dương (Info). |
| `status` | `ShipmentStatus` | `3` | `HandedOver` | **Đã bàn giao cho vận chuyển**: Kiện hàng đã vào bưu cục trung chuyển. Badge xanh lá nhạt (Primary). |
| `status` | `ShipmentStatus` | `4` | `InTransit` | **Đang luân chuyển trên đường**: Đang vận chuyển giữa các kho bưu cục. Badge xanh dương (Info). |
| `status` | `ShipmentStatus` | `5` | `Delivered` | **Giao hàng thành công**: Khách hàng đã ký nhận đơn hàng. Badge xanh lá (Success). |
| `status` | `ShipmentStatus` | `6` | `DeliveryFailed` | **Giao hàng thất bại**: Không liên lạc được với khách hoặc sai địa chỉ (giao lại sau). Badge đỏ (Danger). |
| `status` | `ShipmentStatus` | `7` | `Returned` | **Chuyển hoàn về kho Shop**: Đơn hàng giao không thành công 3 lần, hoàn về người gửi. Badge cam (Warning). |
| `status` | `ShipmentStatus` | `8` | `Cancelled` | **Vận đơn bị hủy**: Hủy trước khi bưu tá đến lấy. Badge xám (Muted). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `IShipmentService.cs` và `ShipmentService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `ShipmentsController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `ShipmentsTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `fulfillment-shipments-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
