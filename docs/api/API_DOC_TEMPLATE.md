# [HTTP_METHOD] /api/v1/[plural-resource-endpoint]

> **Phân hệ thụ lý:** `[ServiceName]`  
> **Tên tính năng:** `[FeatureName]`  
> **Mã tham chiếu Excel:** `[REF-ID]`  
> **Trạng thái tài liệu:** `[B_none / A_Active]`  
> **Trạng thái triển khai:** `[IN_PROGRESS / COMPLETED]`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** [Mô tả chi tiết mục đích nghiệp vụ của endpoint này]
* **HTTP Method:** `[GET / POST / PUT / PATCH / DELETE]`
* **Đường dẫn chuẩn:** `/api/v1/[plural-collection-path]`
* **Quyền hạn truy cập (RBAC):** `[AllowAnonymous / Buyer / Seller / StaffOrAdmin / Admin]`
* **Yêu cầu Idempotency:** `[Bắt buộc / Tùy chọn / Không áp dụng]` (Truyền header `Idempotency-Key: UUIDv4` nếu là mutation mutating request)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/[Service]/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `[route-id]`)
* **Controller Action:** `[Service].Api/Controllers/[Feature]Controller.cs` $\rightarrow$ `[MethodName]()`
* **Application Interface:** `[Service].Application/Services/[Feature]/I[Feature]Service.cs` $\rightarrow$ `[MethodNameAsync]()`
* **Service Implementation:** `[Service].Application/Services/[Feature]/[Feature]Service.cs` $\rightarrow$ `[MethodNameAsync]()`
* **Thực thể & Bảng DB:** `[Service].Domain/Entities/[Entity].cs` $\rightarrow$ Bảng `[TableName]` trong PostgreSQL
* **Typed HTTP Client (nếu có):** `[Service].Infrastructure/Services/[Client].cs` $\rightarrow$ Gọi sang `[DownstreamService]`

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Nếu có)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `id` | `Guid (UUID)` | Có | UUIDv4 hợp lệ, ví dụ `11111111-1111-1111-1111-111111111111` |

### 3.2. Query Parameters (Nếu có phân trang hoặc bộ lọc)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` (hoặc `pageIndex`) | `integer` | `1` | Số nguyên dương $\ge 1$ |
| `pageSize` (hoặc `limit`) | `integer` | `20` | Số nguyên dương trong khoảng $1 \le pageSize \le 100$ |

### 3.3. Request Body (JSON Payload)
```json
{
  "field1": "string",
  "field2": 100000.00
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc thao tác tạo/sửa thành công:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "id": "11111111-1111-1111-1111-000000000001"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-30T15:30:00Z"
}
```

### 4.2. Phản hồi Phân trang (`ApiResponse<PagedData<T>>`)
Áp dụng cho API tra cứu danh sách có phân trang:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "items": [
      {
        "id": "11111111-1111-1111-1111-000000000001"
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
  "timestamp": "2026-10-30T15:30:00Z"
}
```

### 4.3. Phản hồi Không có Body (`204 NoContent`)
Áp dụng cho thao tác xóa hoặc cập nhật không cần trả payload.

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `[RESOURCE]_NOT_FOUND` | "[Resource] not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `409` | `[CONFLICT_CODE]` | "[Conflict message in sentence case]." | Vi phạm ràng buộc duy nhất hoặc xung đột trạng thái domain. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống không xử lý được. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `[EntityStatus]` | `0` | `Pending` | **Chờ xử lý ban đầu**: Bản ghi vừa tạo, đang chờ xét duyệt hoặc xác thực. Hiển thị badge màu vàng (Warning/Pending). |
| `status` | `[EntityStatus]` | `1` | `Active` | **Đang hoạt động**: Đã được kích hoạt, hoạt động bình thường trên hệ thống. Hiển thị badge màu xanh lá (Success/Active). |
| `status` | `[EntityStatus]` | `2` | `Suspended` | **Bị tạm khóa**: Vi phạm chính sách hoặc bị tạm ngưng giao dịch. Hiển thị badge màu cam/đỏ (Danger/Suspended). |
| `status` | `[EntityStatus]` | `3` | `Terminated` | **Đã chấm dứt**: Bị xóa mềm hoặc đóng vĩnh viễn. Hiển thị badge màu xám (Muted/Inactive). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `I[Feature]Service.cs` và `[Feature]Service.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `[Feature]Controller.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `[Feature]Tests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) / ✅ COMPLETED (Lưu tại A_Active) ]`
