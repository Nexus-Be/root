# [GET] /api/v1/admin/health/broker

> **Phân hệ thụ lý:** `NotificationService`  
> **Tên tính năng:** `Health`  
> **Mã tham chiếu Excel:** `NOTI-10`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu chuyển Active)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên và nhân viên kiểm tra trạng thái sức khỏe, độ trễ và độ sâu hàng đợi của message broker / queue
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/admin/health/broker`
* **Đường dẫn gốc trong Excel:** `/api/v1/admin/health/broker`
* **Quyền hạn truy cập (RBAC):** `admin`, `staff`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Notification/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-notifications-health-route`)
* **Controller Action:** `Notification.Api/Controllers/Public/AdminHealthController.cs` $\rightarrow$ `GetBrokerHealth()`
* **Application Interface:** `Notification.Application/Services/Notifications/IUserNotificationService.cs` $\rightarrow$ `GetBrokerHealthAsync(int limit, CancellationToken cancellationToken)`
* **Service Implementation:** `Notification.Application/Services/Notifications/UserNotificationService.cs` $\rightarrow$ `GetBrokerHealthAsync(int limit, CancellationToken cancellationToken)`
* **Thực thể & Bảng DB:** `Notification.Domain/Entities/BrokerHealthCheck.cs` $\rightarrow$ Bảng `BrokerHealthChecks` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn bắt buộc (mặc định lấy 50 bản ghi gần nhất).*

### 3.3. Request Body (JSON Payload)
*Không có request body (HTTP GET).*

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Danh sách Bản ghi Sức Khỏe (`ApiResponse<IReadOnlyList<BrokerHealthCheckResponse>>`)
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "brokerName": "rabbitmq",
      "status": "Up",
      "latencyMs": 15,
      "queueDepth": 0,
      "detail": "Queue connection responsive",
      "checkedAt": "2026-11-02T02:00:00Z"
    }
  ],
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-02T02:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Không có thông tin xác thực JWT. |
| `403` | `FORBIDDEN` | "You do not have permission to access or modify this resource." | Người dùng không mang vai trò `admin` hoặc `staff`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An internal server error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ |
|:---|:---|:---:|:---|:---|
| `status` | `BrokerHealthStatus` | `0` | `Up` | Broker hoạt động bình thường |
| `status` | `BrokerHealthStatus` | `1` | `Degraded` | Hoạt động chập chờn, độ trễ cao |
| `status` | `BrokerHealthStatus` | `2` | `Down` | Mất kết nối tới broker |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `IUserNotificationService.cs` và `UserNotificationService.cs` đã được triển khai hoàn chỉnh.
- [x] **2. Tầng Api:** `AdminHealthController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [x] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `AdminControllersTests.cs`, `UserNotificationServiceTests.cs`).
- [x] **6. Định tuyến Gateway:** Route YARP `admin-notifications-health-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ CHỜ NGHIỆM THU (Lưu tại B_none) ]`
