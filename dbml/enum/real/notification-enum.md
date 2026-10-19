# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — NOTIFICATION SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `NotificationStatus` | `Notifications.Status` | `Pending (0)` | Trạng thái tổng thể của thông báo mẹ (Logic Record) |
| 2 | `DeliveryStatus` | `NotificationDeliveries.Status` | `Pending (0)` | Trạng thái của từng lượt chuyển phát vật lý độc lập |
| 3 | `ChannelType` | `NotificationChannels.Code`, `NotificationTemplates.ChannelCode`, `NotificationPreferences.ChannelCode`, `NotificationDeliveries.ChannelCode` | — | Phân loại kênh chuyển phát thông báo |
| 4 | `ChannelProvider` | `NotificationChannels.Provider` | — | Hạ tầng / Nhà cung cấp dịch vụ gửi tin |
| 5 | `ChannelScope` | `Notifications.ChannelScope` | `All (0)` | Phạm vi phát tán tin theo kênh |
| 6 | `NotificationType` | `NotificationTemplates.NotificationType`, `NotificationPreferences.NotificationType`, `Notifications.NotificationType` | — | Phân loại nghiệp vụ của thông báo |
| 7 | `DevicePlatform` | `DeviceTokens.Platform` | — | Nền tảng thiết bị cài đặt ứng dụng |
| 8 | `LogAction` | `NotificationLogs.Action` | — | Hành động ghi vết kỹ thuật chuyển phát tin |
| 9 | `LogLevel` | `NotificationLogs.Level` | `Info (0)` | Mức độ nghiêm trọng của log |
| 10 | `BrokerHealthStatus` | `BrokerHealthChecks.Status` | `Up (0)` | Tình trạng hoạt động của RabbitMQ Broker |
| 11 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác hệ thống thông báo |

---

## 2. Chi Tiết Từng Enum

### 2.1 NotificationStatus – Trạng Thái Thông Báo Mẹ
* **Bảng CSDL:** `Notifications.Status`
* **Kiểu dữ liệu:** `Enum NotificationStatus`
* **Mô tả:** Quản lý vòng đời tổng thể của một bản ghi thông báo hiển thị trên ứng dụng.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Khởi tạo xong, đang chờ phân luồng hoặc đang trong tiến trình gửi |
| `1` | `Completed` | Toàn bộ các kênh phân phối con (`deliveries`) đều gửi thành công |
| `2` | `Partial` | Gửi thành công một phần (có kênh thành công, có kênh thất bại hoàn toàn) |
| `3` | `Failed` | Toàn bộ các kênh phân bổ con đều gửi thất bại |

---

### 2.2 DeliveryStatus – Trạng Thái Lượt Giao Tin Vật Lý
* **Bảng CSDL:** `NotificationDeliveries.Status`
* **Kiểu dữ liệu:** `Enum DeliveryStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Chờ worker xử lý hoặc chờ đến mốc `NextRetryAt` |
| `1` | `Sending` | Worker đang gọi API đối tác hạ tầng bên thứ ba |
| `2` | `Sent` | Nhà cung cấp dịch vụ xác nhận tiếp nhận thông điệp thành công |
| `3` | `Failed` | Gặp sự cố không thể khắc phục hoặc đã thử lại quá số lần quy định (>= 3) |
| `4` | `Skipped` | Bỏ qua gửi do người dùng đã chủ động tắt nhận tin trong tùy chọn cá nhân |

---

### 2.3 ChannelType – Danh Mục Kênh Vận Chuyển
* **Bảng CSDL:** `NotificationChannels.Code`, `NotificationTemplates.ChannelCode`, `NotificationPreferences.ChannelCode`, `NotificationDeliveries.ChannelCode`
* **Kiểu dữ liệu:** `Enum ChannelType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Email` | Gửi thư điện tử qua máy chủ SMTP hoặc SendGrid |
| `1` | `Push` | Gửi thông báo đẩy đến di động/trình duyệt qua FCM hoặc APNs |
| `2` | `InApp` | Hiển thị trực tiếp trong Trung tâm thông báo (Notification Center) ứng dụng |
| `3` | `Sms` | Gửi tin nhắn thương hiệu viễn thông (SMS Brandname) |

---

### 2.4 ChannelProvider – Đơn Vị Cung Cấp Hạ Tầng Gửi Tin
* **Bảng CSDL:** `NotificationChannels.Provider`
* **Kiểu dữ liệu:** `Enum ChannelProvider`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Smtp` | Máy chủ gửi mail chuẩn giao thức SMTP |
| `1` | `Sendgrid` | Dịch vụ đám mây Twilio SendGrid |
| `2` | `Fcm` | Google Firebase Cloud Messaging |
| `3` | `Apns` | Apple Push Notification service |

---

### 2.5 ChannelScope – Phạm Vi Kênh Gửi
* **Bảng CSDL:** `Notifications.ChannelScope`
* **Kiểu dữ liệu:** `Enum ChannelScope`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `All` | Gửi qua toàn bộ các kênh hợp lệ được cấu hình cho loại tin |
| `1` | `Specific` | Chỉ gửi qua kênh cụ thể được chỉ định trong tác vụ |

---

### 2.6 NotificationType – Phân Loại Nghiệp Vụ Của Thông Báo
* **Bảng CSDL:** `NotificationTemplates.NotificationType`, `NotificationPreferences.NotificationType`, `Notifications.NotificationType`
* **Kiểu dữ liệu:** `Enum NotificationType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `OrderPaid` | Đơn hàng mua sắm đã thanh toán thành công |
| `1` | `OrderShipped` | Đơn hàng đã được bàn giao vận chuyển |
| `2` | `AuctionOutbid` | Có người trả giá cao hơn trong phiên đấu giá |
| `3` | `AuctionWon` | Khách hàng đã thắng phiên đấu giá |
| `4` | `ReputationPenalty` | Thông báo bị trừ điểm uy tín do vi phạm |
| `5` | `SecurityAlert` | Cảnh báo an ninh tài khoản (đăng nhập lạ, đổi mật khẩu) |
| `6` | `Otp` | Mã xác thực giao dịch hoặc đăng nhập |
| `7` | `Promotion` | Tin tức khuyến mại sàn |

---

### 2.7 DevicePlatform – Nền Tảng Thiết Bị
* **Bảng CSDL:** `DeviceTokens.Platform`
* **Kiểu dữ liệu:** `Enum DevicePlatform`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Web` | Trình duyệt Web (hỗ trợ Web Push API) |
| `1` | `Ios` | Ứng dụng chạy trên Apple iOS |
| `2` | `Android` | Ứng dụng chạy trên Google Android |

---

### 2.8 LogAction – Hành Động Ghi Vết Chuyển Phát Tin
* **Bảng CSDL:** `NotificationLogs.Action`
* **Kiểu dữ liệu:** `Enum LogAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Created` | Bản ghi thông báo vừa được tạo vào CSDL |
| `1` | `Rendered` | Biên dịch template với dữ liệu payload thành công |
| `2` | `Dispatching` | Bắt đầu gọi API gửi tin sang bên thứ ba |
| `3` | `Sent` | Nhà cung cấp phản hồi chấp nhận thông điệp thành công |
| `4` | `Failed` | Gửi tin thất bại |
| `5` | `Retry` | Tác vụ chuyển phát được lập lịch gửi lại |
| `6` | `Suppressed` | Hủy bỏ do token chết hoặc người dùng chặn nhận tin |

---

### 2.9 LogLevel – Cấp Độ Nghiêm Trọng Của Nhật Ký
* **Bảng CSDL:** `NotificationLogs.Level`
* **Kiểu dữ liệu:** `Enum LogLevel`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Info` | Luồng xử lý bình thường, ghi nhận các mốc thành công |
| `1` | `Warn` | Gặp lỗi tạm thời, đưa vào cơ chế tự động thử lại |
| `2` | `Error` | Lỗi nghiêm trọng khiến tác vụ thất bại vĩnh viễn |

---

### 2.10 BrokerHealthStatus – Tình Trạng Hoạt Động Message Broker
* **Bảng CSDL:** `BrokerHealthChecks.Status`
* **Kiểu dữ liệu:** `Enum BrokerHealthStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Up` | Kết nối trơn tru, hàng đợi an toàn |
| `1` | `Degraded` | Kết nối chập chờn hoặc hàng đợi vượt ngưỡng cảnh báo |
| `2` | `Down` | Mất hoàn toàn kết nối với cụm RabbitMQ |

---

### 2.11 AuditAction – Hành Động Kiểm Toán Hệ Thống
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `ChannelCreate` | Khởi tạo cấu hình kênh thông báo mới |
| `1` | `ChannelUpdate` | Cập nhật cấu hình kênh thông báo |
| `2` | `TemplateCreate` | Tạo mới mẫu thông báo |
| `3` | `TemplateUpdate` | Chỉnh sửa nội dung mẫu thông báo |
| `4` | `PreferenceUpdate` | Cập nhật tùy chọn nhận tin của người dùng |
| `5` | `DeviceRegister` | Đăng ký hoặc làm mới token thiết bị |
