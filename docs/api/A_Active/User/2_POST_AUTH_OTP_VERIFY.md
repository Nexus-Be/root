# [POST] /api/v1/auth/otp/verify

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Auth`  
> **Mã tham chiếu Excel:** `2`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-10-31 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xác thực tài khoản người dùng
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/auth/otp/verify`
* **Đường dẫn gốc trong Excel:** `/api/v1/auth/otp/verify` (Contextual Singleton giữ nguyên theo chuẩn RFC 9110.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `auth-route`)
* **Controller Action:** `User.Api/Controllers/Public/AuthController.cs` $\rightarrow$ `VerifyOtp()`
* **Application Interface:** `User.Application/Services/Auth/IAuthService.cs` $\rightarrow$ `VerifyUserOtpAsync()`
* **Service Implementation:** `User.Application/Services/Auth/AuthService.cs` $\rightarrow$ `VerifyUserOtpAsync()` (gọi tiếp `VerifyOtpAsync()` nội bộ)
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
Body:
{
  "email": "user@example.com",
  "otp": "123456"
}
```


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
    "isVerified": true,
    "email": "string",
    "userId": "uuid",
    "role": "buyer",
    "roles": ["buyer"],
    "permissions": ["CART.VIEW", "CART.UPDATE", "ORDER.VIEW", "CHECKOUT.START"]
  },
  "traceId": "00-7e0d046765aedca41856a4c0ed1a6c40-00bf7f75f5a78c89-00",
  "timestamp": "2026-10-31T00:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Email and OTP code are required." | Thiếu `email` hoặc `otp` tại `VerifyUserOtpAsync`. Lỗi này chặn trước mọi kiểm tra khác nên hai mã `VAL_INVALID_EMAIL` và `VAL_INVALID_OTP` không thể trả ra qua HTTP. |
| `400` | `USER_NOT_FOUND` | "User account not found." | Không có tài khoản theo email gửi lên. |
| `403` | `ACCOUNT_BANNED` | "Account has been locked or banned by an administrator." | Tài khoản đang ở trạng thái Banned. |
| `400` | `OTP_ALREADY_USED` | "This OTP code has already been used." | OTP đã được dùng để kích hoạt và bị gửi lại lần hai. |
| `400` | `OTP_EXPIRED` | "OTP code has expired or does not exist." | Không tìm thấy OTP trong Redis hoặc OTP đã bị vô hiệu hóa. |
| `400` | `OTP_EXPIRED` | "OTP code has expired. Please request a new code." | OTP còn trong Redis nhưng `Status = Expired` hoặc `ExpiresAt` đã qua. |
| `400` | `OTP_INVALID` | "OTP code is invalid." | Mã OTP gửi lên không khớp mã đã lưu. |
| `429` | `RATE_LIMIT_EXCEEDED` | "Too many requests. Please slow down and try again later." | Vượt 5 request trong 60 giây tại Gateway, kèm header `Retry-After`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống chưa được xử lý. |

> Lỗi nghiệp vụ từ service trả `application/problem+json` (`type`/`title`/`status`/`errorCode`/`detail`/`traceId`). Lỗi tại Gateway (429, Idempotency-Key) trả envelope `success`/`statusCode`/`errorCode`/`message`/`traceId`/`timestamp`.

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

*Response của endpoint này không chứa trường enum. Trạng thái tài khoản (`UserStatus`) chỉ xuất hiện trong payload của các endpoint quản trị user.*

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
