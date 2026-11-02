# [PUT] /api/v1/notifications/preferences

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Notifications`  
> **Mã tham chiếu Excel:** `NOTI-04`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu chuyển Active)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Cập nhật tùy chọn bật/tắt nhận thông báo theo loại sự kiện và kênh gửi
* **HTTP Method:** `PUT`
* **Đường dẫn chuẩn:** `/api/v1/notifications/preferences`
* **Đường dẫn gốc trong Excel:** `/api/v1/notifications/preferences` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`, `User`, `Seller`, `Admin`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `notifications-route`)
* **Controller Action:** `Notification.Api/Controllers/Public/NotificationsController.cs` $\rightarrow$ `UpdatePreferences()`
* **Application Interface:** `Notification.Application/Services/Notifications/IUserNotificationService.cs` $\rightarrow$ `UpdatePreferencesAsync(Guid userId, UpdatePreferencesRequest request, CancellationToken cancellationToken)`
* **Service Implementation:** `Notification.Application/Services/Notifications/UserNotificationService.cs` $\rightarrow$ `UpdatePreferencesAsync(Guid userId, UpdatePreferencesRequest request, CancellationToken cancellationToken)`
* **Thực thể & Bảng DB:** `Notification.Domain/Entities/NotificationPreference.cs` $\rightarrow$ Bảng `NotificationPreferences` trong PostgreSQL
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
  "preferences": [
    {
      "notificationType": "OrderPaid",
      "channelCode": "Email",
      "isDisabled": false
    }
  ]
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Kết quả Cập nhật (`ApiResponse<UpdatePreferencesResult>`)
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "updatedCount": 1
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T02:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_ARGUMENT` | "At least one preference must be provided." | Danh sách `preferences` rỗng hoặc null. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Không có thông tin xác thực `x-user-id` hợp lệ. |
| `500` | `INTERNAL_SERVER_ERROR` | "An internal server error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ |
|:---|:---|:---:|:---|:---|
| `notificationType` | `NotificationType` | `0` | `OrderPaid` | Đơn hàng đã thanh toán |
| `notificationType` | `NotificationType` | `1` | `OrderShipped` | Đơn hàng đang giao |
| `notificationType` | `NotificationType` | `2` | `AuctionOutbid` | Bị trả giá cao hơn |
| `notificationType` | `NotificationType` | `3` | `AuctionWon` | Thắng đấu giá |
| `notificationType` | `NotificationType` | `4` | `ReputationPenalty` | Xử phạt điểm uy tín |
| `notificationType` | `NotificationType` | `5` | `SecurityAlert` | Cảnh báo bảo mật |
| `notificationType` | `NotificationType` | `6` | `Otp` | Mã xác thực OTP |
| `notificationType` | `NotificationType` | `7` | `Promotion` | Khuyến mãi & Voucher |
| `channelCode` | `ChannelType` | `0` | `Email` | Thư điện tử (Email) |
| `channelCode` | `ChannelType` | `1` | `Push` | Thông báo đẩy thiết bị |
| `channelCode` | `ChannelType` | `2` | `InApp` | Thông báo trong ứng dụng |
| `channelCode` | `ChannelType` | `3` | `Sms` | Tin nhắn SMS |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `IUserNotificationService.cs` và `UserNotificationService.cs` đã được triển khai hoàn chỉnh.
- [x] **2. Tầng Api:** `NotificationsController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [x] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `NotificationsControllerTests.cs`, `UserNotificationServiceTests.cs`).
- [x] **6. Định tuyến Gateway:** Route YARP `notifications-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ CHỜ NGHIỆM THU (Lưu tại B_none) ]`
