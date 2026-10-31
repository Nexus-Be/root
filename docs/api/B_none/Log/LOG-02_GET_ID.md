# [GET] /api/v1/logs/{id}

> **Phân hệ thụ lý:** `LogService`  
> **Tên tính năng:** `Log`  
> **Mã tham chiếu Excel:** `LOG-02`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu chi tiết một bản ghi nhật ký hệ thống theo mã định danh UUID.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/logs/{id}`
* **Đường dẫn gốc trong Excel:** `/api/v1/logs/{id}` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Log/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `log-route`)
* **Controller Action:** `Log.Api/Controllers/LogController.cs` $\rightarrow$ `GetLogById()`
* **Application Interface:** `Log.Application/Services/Log/ILogService.cs` $\rightarrow$ `GetLogByIdAsync()`
* **Service Implementation:** `Log.Application/Services/Log/LogService.cs` $\rightarrow$ `GetLogByIdAsync()`
* **Thực thể & Bảng DB:** `Log.Domain/Entities/LogEntry.cs` $\rightarrow$ Bảng `Logs` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `id` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
*Không yêu cầu Request Body (Body rỗng).*


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Log entry retrieved successfully.",
  "data": {
    "id": "11111111-1111-1111-1111-000000000001",
    "level": "Info",
    "service": "CatalogService",
    "message": "Product created successfully",
    "payload": "{\"productId\": \"uuid\"}",
    "timestamp": "2026-10-30T10:00:00Z"
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
| `404` | `LOG_NOT_FOUND` | "Log entry not found with the specified ID." | Điều kiện nghiệp vụ đặc thù: LOG_NOT_FOUND. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `LOGENTRY_NOT_FOUND` | "Logentry not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `severity` | `AlertSeverity` | `0` | `Low` | **Mức độ Thấp**: Cảnh báo thông tin thông thường. Badge xám/xanh dương. |
| `severity` | `AlertSeverity` | `1` | `Medium` | **Mức độ Trung bình**: Cảnh báo cần chú ý nhưng chưa gây nghẽn dịch vụ. Badge vàng. |
| `severity` | `AlertSeverity` | `2` | `High` | **Mức độ Cao**: Lỗi ảnh hưởng tới trải nghiệm người dùng, cần kiểm tra sớm. Badge cam. |
| `severity` | `AlertSeverity` | `3` | `Critical` | **Mức độ Nghiêm trọng**: Sập dịch vụ, lỗi thanh toán hoặc xâm nhập bảo mật. Badge đỏ nhấp nháy. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `ILogService.cs` và `LogService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `LogController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `LogTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `log-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
