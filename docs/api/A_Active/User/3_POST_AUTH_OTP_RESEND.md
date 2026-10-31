# [POST] /api/v1/auth/otp/resend

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Auth`  
> **Mã tham chiếu Excel:** `3`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-10-31 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Gửi lại OTP xác thực đăng ký cho tài khoản đang chờ xác thực. Endpoint không dùng cho luồng quên mật khẩu vì tài khoản đã Active sẽ bị từ chối với `USER_ALREADY_VERIFIED`.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/auth/otp/resend`
* **Đường dẫn gốc trong Excel:** `/api/v1/auth/otp/resend` (Contextual Singleton giữ nguyên theo chuẩn RFC 9110.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `auth-route`)
* **Controller Action:** `User.Api/Controllers/Public/AuthController.cs` $\rightarrow$ `ResendOtp()`
* **Application Interface:** `User.Application/Services/Auth/IAuthService.cs` $\rightarrow$ `ResendOtpAsync()`
* **Service Implementation:** `User.Application/Services/Auth/AuthService.cs` $\rightarrow$ `ResendOtpAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
{
  "email": "string (required)"
}
```

`ResendOtpApiRequest` còn khai báo trường `type` tùy chọn, nhưng controller chỉ đọc `email` và service bỏ qua `type`. Không truyền `type` cũng không ảnh hưởng hành vi.


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "email": "string",
    "resendCooldown": "int: 60"
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
| `400` | `VAL_INVALID_EMAIL` | "Email address is required." | Thiếu `email`. |
| `400` | `USER_NOT_FOUND` | "User account not found." | Không có tài khoản theo email gửi lên. |
| `400` | `USER_ALREADY_VERIFIED` | "User account has already been verified." | Tài khoản đã Active, không cần gửi lại OTP đăng ký. |
| `403` | `ACCOUNT_BANNED` | "Account has been locked or banned by an administrator." | Tài khoản đang ở trạng thái Banned. |
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Model binding thất bại hoặc `Idempotency-Key` không hợp lệ. |
| `429` | `RATE_LIMIT_EXCEEDED` | "Too many requests. Please slow down and try again later." | Vượt 3 request trong 60 giây tại Gateway, kèm header `Retry-After`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống chưa được xử lý. |

> Lỗi nghiệp vụ từ service trả `application/problem+json` (`type`/`title`/`status`/`errorCode`/`detail`/`traceId`). Lỗi tại Gateway (429, Idempotency-Key) trả envelope `success`/`statusCode`/`errorCode`/`message`/`traceId`/`timestamp`.

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

*Endpoint này không sử dụng enum trực tiếp trong tham số đầu vào (Request) hoặc dữ liệu trả về (Response).*

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `IAuthService.cs` và `AuthService.cs` đã được triển khai hoàn chỉnh.
- [x] **2. Tầng Api:** `AuthController.cs` ghép cặp 1-to-1 trong `Controllers/Public/`, route đúng chuẩn, summary XML một dòng.
- [x] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [x] **4. Enum Mapping:** Payload Auth không chứa enum; mọi enum liên quan vẫn lưu integer trong DB và serialize PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test User.sln -c Release` xanh (233 test tại thời điểm nghiệm thu). E2E `tools/auth_e2e_test.sh` phủ case của endpoint này.
- [x] **6. Định tuyến Gateway:** Route YARP `auth-route` (`/api/v1/auth/{**catch-all}`) đã test thông suốt qua `:8080`.
- [x] **7. Xác nhận của Sếp (Human Approval):** Sếp đã yêu cầu nghiệm thu thực tế ngày 2026-10-31 và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ✅ COMPLETED (Lưu tại A_Active) ]`
