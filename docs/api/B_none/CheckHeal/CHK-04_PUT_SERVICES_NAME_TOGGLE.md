# [PUT] /api/v1/healthcheck/services/{name}/toggle

> **Phân hệ thụ lý:** `CheckHealService`  
> **Tên tính năng:** `HealthCheck`  
> **Mã tham chiếu Excel:** `CHK-04`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Bật hoặc tắt giám sát định kỳ cho một dịch vụ cụ thể.
* **HTTP Method:** `PUT`
* **Đường dẫn chuẩn:** `/api/v1/healthcheck/services/{name}/toggle`
* **Đường dẫn gốc trong Excel:** `/api/v1/healthcheck/services/{name}/toggle` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/CheckHeal/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `checkheal-route`)
* **Controller Action:** `CheckHeal.Api/Controllers/HealthCheckController.cs` $\rightarrow$ `ToggleService()`
* **Application Interface:** `CheckHeal.Application/Services/HealthCheck/IHealthService.cs` $\rightarrow$ `ToggleServiceAsync()`
* **Service Implementation:** `CheckHeal.Application/Services/HealthCheck/HealthService.cs` $\rightarrow$ `ToggleServiceAsync()`
* **Thực thể & Bảng DB:** `CheckHeal.Domain/Entities/HealthTarget.cs` $\rightarrow$ Bảng `InMemoryHealthState` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `name` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
{
  "enabled": true,
  "url": "http://catalog-service:8002/health"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Service monitoring toggle updated successfully.",
  "data": {
    "name": "catalog",
    "enabled": true
  }
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `404` | `SERVICE_NOT_FOUND` | "Service target with the specified name was not found." | Điều kiện nghiệp vụ đặc thù: SERVICE_NOT_FOUND. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `HEALTHTARGET_NOT_FOUND` | "Healthtarget not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `HealthStatus` | `1` | `Healthy` | **Hoạt động tốt**: Độ trễ thấp, kết nối cơ sở dữ liệu và API ổn định. Badge xanh lá (Success). |
| `status` | `HealthStatus` | `2` | `Degraded` | **Bị suy giảm hiệu năng**: Độ trễ cao (>1000ms) hoặc một số probe phụ bị timeout. Badge vàng (Warning). |
| `status` | `HealthStatus` | `3` | `Unhealthy` | **Không phản hồi / Lỗi**: Service hoặc DB ngắt kết nối hoàn toàn. Badge đỏ (Danger). |
| `status` | `HealthStatus` | `4` | `Disabled` | **Tạm ngưng giám sát**: Mục tiêu bị tắt thủ công bởi quản trị viên. Badge xám (Muted). |
| `status` | `HealthStatus` | `5` | `Unknown` | **Chưa xác định**: Đang khởi động hoặc chưa thực hiện chu kỳ probe đầu tiên. Badge xanh dương (Info). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `IHealthService.cs` và `HealthService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `HealthCheckController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `HealthCheckTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `checkheal-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
