# [PATCH] /api/v1/auth/password

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `Auth`  
> **Mã tham chiếu Excel:** `8`  
> **Trạng thái tài liệu:** `A_Active (Đã nghiệm thu)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Cập nhật lần cuối:** `2026-10-31 (đối chiếu code)`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Cập nhật lại mật khẩu(Đổi mật khẩu)
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/auth/password`
* **Đường dẫn gốc trong Excel:** `/api/v1/auth/password` (Contextual Singleton giữ nguyên theo chuẩn RFC 9110.)
* **Quyền hạn truy cập (RBAC):** `Authenticated user` (`[RequireRole]` không truyền role, nên mọi vai trò đã xác thực đều gọi được, không riêng Buyer)
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `auth-route`)
* **Controller Action:** `User.Api/Controllers/Public/AuthController.cs` $\rightarrow$ `ChangePassword()`
* **Application Interface:** `User.Application/Services/Auth/IAuthService.cs` $\rightarrow$ `ChangePasswordAsync()`
* **Service Implementation:** `User.Application/Services/Auth/AuthService.cs` $\rightarrow$ `ChangePasswordAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
**Header bắt buộc**

```http
Authorization: Bearer <JWT>
x-user-id: <uuid>
```

**Body**

```json
{
  "oldPassword": "string",
  "newPassword": "string",
  "confirmPassword": "string"
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
    "success": true
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
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Không có JWT hợp lệ tại `RequireRole`. |
| `400` | `VAL_INVALID_INPUT` | "Change password payload is required." | Body rỗng hoặc model binding thất bại. |
| `400` | `VAL_INVALID_PASSWORD` | "Old password is required." | Thiếu `oldPassword`. |
| `400` | `VAL_INVALID_PASSWORD` | "Password must be at least 8 characters long." | Mật khẩu mới ngắn hơn 8 ký tự. |
| `400` | `VAL_PASSWORD_MISMATCH` | "New password and confirmation password do not match." | `newPassword` khác `confirmPassword`. |
| `400` | `VAL_SAME_PASSWORD` | "New password cannot be the same as the old password." | Mật khẩu mới trùng mật khẩu cũ. |
| `400` | `INVALID_CREDENTIALS` | "Old password is incorrect." | `oldPassword` không đúng. |
| `400` | `USER_NOT_FOUND` | "User account not found." | Không tìm thấy tài khoản theo `x-user-id`. |
| `400` | `USER_BANNED` | "User account is banned." | Tài khoản đang bị ban. |
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
