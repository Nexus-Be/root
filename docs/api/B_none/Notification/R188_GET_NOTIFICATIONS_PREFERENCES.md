# [GET] /api/v1/notifications/preferences

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Notifications`  
> **Mã tham chiếu Excel:** ``NOTI-03``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy danh sách cấu hình bật/tắt nhận thông báo của người dùng
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/notifications/preferences`
* **Đường dẫn gốc trong Excel:** `/api/v1/notifications/preferences` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `notification-notifications-route`)
* **Controller Action:** `Notification.Api/Controllers/NotificationsController.cs` $\rightarrow$ `GetPreferences()`
* **Application Interface:** `Notification.Application/Services/Notifications/INotificationService.cs` $\rightarrow$ `GetPreferencesAsync()`
* **Service Implementation:** `Notification.Application/Services/Notifications/NotificationService.cs` $\rightarrow$ `GetPreferencesAsync()`
* **Thực thể & Bảng DB:** `Notification.Domain/Entities/Notification.cs` $\rightarrow$ Bảng `Notifications` trong PostgreSQL
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
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<T>>`)
Áp dụng cho API tra cứu danh sách có phân trang:
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "notificationType": "ORDER_PAID|AUCTION_OUTBID|PROMOTION",
        "channelCode": "EMAIL|PUSH|IN_APP",
        "isEnabled": true,
        "isMandatory": true
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
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
| `401` | `UNAUTHORIZED` | "Token is missing, expired, or invalid." | Điều kiện nghiệp vụ đặc thù: UNAUTHORIZED. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `NOTIFICATION_NOT_FOUND` | "Notification not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `type` | `NotificationType` | `0` | `OrderPaid` | **Đơn hàng đã thanh toán**: Thông báo cho Shop chuẩn bị hàng và khách đã trừ tiền. |
| `type` | `NotificationType` | `1` | `OrderShipped` | **Đơn hàng đang giao**: Thông báo mã vận đơn và lộ trình giao hàng cho khách. |
| `type` | `NotificationType` | `2` | `AuctionOutbid` | **Bị trả giá cao hơn**: Thông báo cho người mua khi có người trả giá cao hơn trong phiên đấu giá. |
| `type` | `NotificationType` | `3` | `AuctionWon` | **Chúc mừng thắng đấu giá**: Thông báo kết quả và đường dẫn thanh toán đơn đấu giá. |
| `type` | `NotificationType` | `4` | `ReputationPenalty` | **Xử phạt điểm uy tín**: Thông báo chế tài kỷ luật hoặc trừ điểm do vi phạm. |
| `type` | `NotificationType` | `5` | `SecurityAlert` | **Cảnh báo bảo mật**: Đăng nhập từ thiết bị lạ hoặc phát hiện hành vi bất thường. |
| `type` | `NotificationType` | `6` | `Otp` | **Mã xác thực OTP**: Gửi mã xác nhận đăng ký / quên mật khẩu qua email. |
| `type` | `NotificationType` | `7` | `Promotion` | **Khuyến mãi & Voucher**: Thông báo chương trình ưu đãi, flash sale mới. |
| `channelType` | `ChannelType` | `0` | `Email` | **Thư điện tử (Email)**: Gửi qua dịch vụ SMTP / SendGrid. |
| `channelType` | `ChannelType` | `1` | `Push` | **Thông báo đẩy (Push Notification)**: Gửi qua Firebase Cloud Messaging (FCM) / Apple APNs. |
| `channelType` | `ChannelType` | `2` | `InApp` | **Thông báo trong ứng dụng (In-App)**: Hiển thị tại biểu tượng quả chuông của người dùng. |
| `channelType` | `ChannelType` | `3` | `Sms` | **Tin nhắn SMS**: Gửi qua nhà mạng viễn thông. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `INotificationService.cs` và `NotificationService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `NotificationsController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `NotificationsTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `notification-notifications-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
