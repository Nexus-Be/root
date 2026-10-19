# 📑 HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — NOTIFICATION SERVICE

## 1. NotificationStatus - Trạng Thái Thông Báo Mẹ (Logic Record)
* **Bảng CSDL:** `notifications.status`
* **Kiểu lưu trữ:** `VARCHAR(30) / INT`
* **Mục đích / Ghi chú:** Quản lý vòng đời tổng thể của một thông báo logic hiển thị trên ứng dụng.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Pending | Vừa khởi tạo và render xong nội dung, đang chờ phân nhánh gửi hoặc đang trong tiến trình gửi. |
| 1 | Completed | Toàn bộ các kênh phân phối vật lý con (deliveries) đều đã được gửi đi thành công. |
| 2 | Partial | Có ít nhất một kênh gửi thành công, nhưng có ít nhất một kênh bị thất bại hoàn toàn sau khi đã thử lại hết lượt. |
| 3 | Failed | Toàn bộ các kênh phân bổ vật lý con đều gửi thất bại. |

---

## 2. DeliveryStatus - Trạng Thái Lượt Giao Tin Vật Lý
* **Bảng CSDL:** `notification_deliveries.status`
* **Kiểu lưu trữ:** `VARCHAR(30) / INT`
* **Mục đích / Ghi chú:** Kiểm soát từng lần chuyển phát vật lý độc lập qua SMTP, FCM, APNs.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Pending | Đang trong hàng đợi chờ worker nhặt tác vụ xử lý hoặc đang chờ đến mốc next_retry_at. |
| 1 | Sending | Worker đã nhận quyền xử lý (đã cập nhật row_version), đang trong quá trình gọi API bên thứ ba. |
| 2 | Sent | Nhà cung cấp dịch vụ hạ tầng (FCM/SMTP) đã xác nhận tiếp nhận thông điệp thành công. |
| 3 | Failed | Gặp sự cố không thể khắc phục hoặc đã thử lại vượt quá số lần quy định (attempt_count >= 3). |
| 4 | Skipped | Bỏ qua không gửi do người dùng đã chủ động tắt nhận tin trong notification_preferences. |

---

## 3. ChannelType - Danh Mục Kênh Vận Chuyển Thông Báo
* **Bảng CSDL:** `notification_channels.code`, `notification_templates.channel_code`, `notification_deliveries.channel_code`
* **Kiểu lưu trữ:** `VARCHAR(50)`
* **Mục đích / Ghi chú:** Xác định hạ tầng kỹ thuật và driver gửi tin được sử dụng.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 1 | Email | Gửi thư điện tử thông qua máy chủ SMTP hoặc dịch vụ SendGrid. |
| 2 | Push | Gửi thông báo đẩy đến ứng dụng di động/trình duyệt qua Firebase Cloud Messaging (FCM) hoặc Apple APNs. |
| 3 | InApp | Hiển thị trực tiếp trong Notification Center (Quả chuông) của ứng dụng người dùng. |
| 4 | Sms | Gửi tin nhắn thương hiệu viễn thông (SMS Brandname) cho các tin bảo mật khẩn cấp. |

---

## 4. NotificationType - Phân Loại Nghiệp Vụ Của Thông Báo
* **Bảng CSDL:** `notifications.notification_type`, `notification_templates.notification_type`, `notification_preferences.notification_type`
* **Kiểu lưu trữ:** `VARCHAR(50)`
* **Mục đích / Ghi chú:** Phân nhóm nghiệp vụ để người dùng lọc tin, cho phép thiết lập quyền nhận tin và chọn icon hiển thị trên client.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 1 | OrderPaid | Đơn hàng mua sắm đã được thanh toán thành công. |
| 2 | OrderShipped | Đơn hàng đã được bàn giao cho đối tác vận chuyển giao hàng. |
| 3 | AuctionOutbid | Có người trả giá cao hơn trong phiên đấu giá đang tham gia. |
| 4 | AuctionWon | Khách hàng đã thắng phiên đấu giá sản phẩm. |
| 5 | ReputationPenalty | Thông báo bị trừ điểm uy tín do vi phạm quy chế sàn. |
| 6 | SecurityAlert | Cảnh báo bảo mật tài khoản (đăng nhập lạ, đổi mật khẩu). |
| 7 | Otp | Mã xác thực giao dịch hoặc đăng nhập gửi trực tiếp. |
| 8 | Promotion | Tin tức chương trình khuyến mại, giảm giá sàn. |

---

## 5. DevicePlatform - Nền Tảng Thiết Bị Cài Đặt Ứng Dụng
* **Bảng CSDL:** `device_tokens.platform`
* **Kiểu lưu trữ:** `VARCHAR(20)`
* **Mục đích / Ghi chú:** Phân loại thiết bị client để nạp payload và cấu hình thông báo đẩy tương thích.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Web | Trình duyệt máy tính/di động hỗ trợ Web Push Notification. |
| 1 | Ios | Ứng dụng chạy trên hệ điều hành iOS (Apple APNs). |
| 2 | Android | Ứng dụng chạy trên hệ điều hành Android (Google FCM). |

---

## 6. LogAction - Hành Động Ghi Vết Kiểm Toán Kỹ Thuật
* **Bảng CSDL:** `notification_logs.action`
* **Kiểu lưu trữ:** `VARCHAR(50)`
* **Mục đích / Ghi chú:** Định danh các mốc trạng thái kỹ thuật trong vòng đời phân phối tin.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 1 | Created | Thông báo mẹ hoặc bản ghi lượt gửi vật lý vừa được khởi tạo vào CSDL. |
| 2 | Rendered | Quá trình biên dịch mẫu template với payload nghiệp vụ hoàn tất. |
| 3 | Dispatching | Bắt đầu gọi API gửi tin tới nhà cung cấp bên thứ ba. |
| 4 | Sent | Nhà cung cấp phản hồi chấp nhận thông điệp thành công (HTTP 200/202). |
| 5 | Failed | Gửi tin thất bại (lỗi kết nối, token không hợp lệ, timeout). |
| 6 | Retry | Tác vụ chuyển phát được lập lịch để chạy lại vào thời điểm tiếp theo. |
| 7 | Suppressed | Tác vụ bị hủy bỏ do phát hiện token thiết bị đã chết hoặc người dùng từ chối nhận tin. |

---

## 7. LogLevel - Cấp Độ Nghiêm Trọng Của Nhật Ký
* **Bảng CSDL:** `notification_logs.level`
* **Kiểu lưu trữ:** `VARCHAR(20)`
* **Mục đích / Ghi chú:** Chuẩn hóa cấp độ cảnh báo để tích hợp với hệ thống tập trung (ELK / Grafana Loki).

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Info | Luồng xử lý bình thường, ghi nhận các mốc thành công. |
| 1 | Warn | Gặp lỗi tạm thời, hệ thống tự động đưa vào quy trình retry. |
| 2 | Error | Lỗi nghiêm trọng khiến tác vụ thất bại vĩnh viễn hoặc sai sót cấu hình. |

---

## 8. BrokerHealthStatus - Tình Trạng Hoạt Động Của Message Broker
* **Bảng CSDL:** `broker_health_checks.status`
* **Kiểu lưu trữ:** `VARCHAR(30)`
* **Mục đích / Ghi chú:** Báo cáo định kỳ tình trạng kết nối RabbitMQ phục vụ cảnh báo hạ tầng SRE/DevOps.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Up | Kết nối hoạt động trơn tru, độ trễ và số lượng hàng đợi trong ngưỡng an toàn. |
| 1 | Degraded | Kết nối chập chờn, độ trễ mạng cao hoặc độ sâu hàng đợi (queue_depth) vượt định mức cảnh báo. |
| 2 | Down | Mất hoàn toàn kết nối với RabbitMQ cluster. |

---

## 9. OutboxStatus - Trạng Thái Xuất Bản Sự Kiện Ra Ngoài
* **Bảng CSDL:** `outbox_messages.status`
* **Kiểu lưu trữ:** `VARCHAR(30)`
* **Mục đích / Ghi chú:** Kiểm soát tiến trình xuất bản sự kiện theo Transactional Outbox Pattern.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Pending | Sự kiện đã lưu bền vững trong DB Transaction, đang chờ Background Publisher đẩy lên RabbitMQ. |
| 1 | Published | Đã xuất bản thành công vào Message Exchange của RabbitMQ. |
| 2 | Failed | Đẩy lên broker gặp lỗi kết nối tạm thời, đang đợi thử lại. |
| 3 | Dead | Thử lại nhiều lần thất bại, đưa vào Dead Letter để kỹ thuật viên can thiệp thủ công. |

---

## 10. InboxStatus - Trạng Thái Tiêu Thụ Sự Kiện Đầu Vào
* **Bảng CSDL:** `inbox_messages.status`
* **Kiểu lưu trữ:** `VARCHAR(30)`
* **Mục đích / Ghi chú:** Đảm bảo nguyên lý Idempotent Consumer — chỉ tiêu thụ và xử lý đúng một lần duy nhất.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| 0 | Received | Nhận được sự kiện từ RabbitMQ, đã lưu đệm vào bảng Inbox để chuẩn bị xử lý. |
| 1 | Processed | Đã tiêu thụ và tạo thông báo nghiệp vụ thành công, đánh dấu hoàn tất. |
| 2 | Failed | Quá trình biên dịch thông báo hoặc logic gặp sự cố, cho phép bộ quét tự động chạy lại. |
| 3 | Skipped | Bỏ qua thông điệp do phiên bản cũ hoặc cấu trúc payload không còn phù hợp. |