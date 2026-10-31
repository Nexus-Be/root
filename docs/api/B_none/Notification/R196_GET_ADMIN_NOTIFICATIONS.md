# [GET] /api/v1/admin/notifications

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Notifications`  
> **Mã tham chiếu Excel:** ``NOTI-09``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Admin/Staff tra cứu lịch sử gửi thông báo và nhật ký lỗi delivery
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/notifications`
* **Đường dẫn gốc trong Excel:** `/api/v1/admin/notifications` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-notifications-route`)
* **Controller Action:** `Notification.Api/Controllers/NotificationsController.cs` $\rightarrow$ `AdminGetNotifications()`
* **Application Interface:** `Notification.Application/Services/Notifications/INotificationService.cs` $\rightarrow$ `AdminGetNotificationsAsync()`
* **Service Implementation:** `Notification.Application/Services/Notifications/NotificationService.cs` $\rightarrow$ `AdminGetNotificationsAsync()`
* **Thực thể & Bảng DB:** `Notification.Domain/Entities/Notification.cs` $\rightarrow$ Bảng `Notifications` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số trang (tối thiểu 1) |
| `pageSize` | `integer` | `20` | Kích thước trang ($1 \le pageSize \le 100$) |

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "userId": "uuid",
  "notificationType": "OrderPaid",
  "status": "COMPLETED|PENDING|FAILED",
  "pageIndex": 1,
  "pageSize": 20
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
        "notificationId": "uuid",
        "userId": "uuid",
        "notificationType": "OrderPaid",
        "status": "Completed",
        "createdAt": "2026-10-26T00:00:00Z",
        "deliveries": [
          {
            "deliveryId": "uuid",
            "channelCode": "EMAIL",
            "destination": "u***@gmail.com",
            "status": "Sent",
            "attemptCount": 1
          }
        ]
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
| `403` | `FORBIDDEN` | "User does not have administrative permissions." | Điều kiện nghiệp vụ đặc thù: FORBIDDEN. |
| `401` | `UNAUTHORIZED` | "Token is missing, expired, or invalid." | Điều kiện nghiệp vụ đặc thù: UNAUTHORIZED. |
| `400` | `VAL_INVALID_FILTER` | "Query filter parameters are invalid." | Điều kiện nghiệp vụ đặc thù: VAL_INVALID_FILTER. |
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
- [ ] **6. Định tuyến Gateway:** Route YARP `admin-notifications-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
