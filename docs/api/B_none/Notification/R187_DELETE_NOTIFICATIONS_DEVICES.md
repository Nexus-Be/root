# [DELETE] /api/v1/notifications/devices/{token}

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Notifications`  
> **Mã tham chiếu Excel:** `NOTI-02`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu chuyển Active)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Thu hồi hoặc vô hiệu hóa device token khi logout hoặc tắt quyền push
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/notifications/devices/{token}`
* **Đường dẫn gốc trong Excel:** `/api/v1/notifications/devices` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`, `User`, `Seller`, `Admin`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `notifications-route`)
* **Controller Action:** `Notification.Api/Controllers/Public/NotificationsController.cs` $\rightarrow$ `RevokeDevice([FromRoute] string token)`
* **Application Interface:** `Notification.Application/Services/Notifications/IUserNotificationService.cs` $\rightarrow$ `RevokeDeviceAsync(string token, CancellationToken cancellationToken)`
* **Service Implementation:** `Notification.Application/Services/Notifications/UserNotificationService.cs` $\rightarrow$ `RevokeDeviceAsync(string token, CancellationToken cancellationToken)`
* **Thực thể & Bảng DB:** `Notification.Domain/Entities/DeviceToken.cs` $\rightarrow$ Bảng `DeviceTokens` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `token` | `string` | Có | Chuỗi token thiết bị cần thu hồi |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
*Không có request body (HTTP DELETE).*

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Không có Body (`204 NoContent`)
Áp dụng cho thao tác xóa hoặc cập nhật không cần trả payload dữ liệu:
```http
HTTP/1.1 204 No Content
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Không có thông tin xác thực hợp lệ. |
| `500` | `INTERNAL_SERVER_ERROR` | "An internal server error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ |
|:---|:---|:---:|:---|:---|
| `platform` | `DevicePlatform` | `0` | `Web` | Thiết bị Web browser |
| `platform` | `DevicePlatform` | `1` | `Ios` | Thiết bị iOS |
| `platform` | `DevicePlatform` | `2` | `Android` | Thiết bị Android |

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
