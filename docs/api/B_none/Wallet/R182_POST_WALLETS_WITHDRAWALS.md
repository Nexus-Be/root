# [POST] /api/v1/wallets/withdrawals

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-07``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `⚠️ PARTIAL — Luồng tạo yêu cầu rút tiền đang bị vô hiệu hóa`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Người bán (Seller) tạo yêu cầu rút tiền từ ví về tài khoản ngân hàng
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/wallets/withdrawals`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/withdrawals` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Seller`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `Withdraw()`
* **Command:** `Wallet.Application/Features/Withdrawals/Commands/RequestWithdrawal/RequestWithdrawalCommand.cs` $\rightarrow$ `RequestWithdrawalCommand`
* **Command Handler:** `Wallet.Application/Features/Withdrawals/Commands/RequestWithdrawal/RequestWithdrawalCommandHandler.cs` $\rightarrow$ `RequestWithdrawalCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Withdrawals/Commands/RequestWithdrawal/RequestWithdrawalCommand.cs` $\rightarrow$ `WithdrawalResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WithdrawalRequest.cs` $\rightarrow$ Bảng `WithdrawalRequests` (hiện chưa ghi bản ghi nào vì Handler luôn ném lỗi)
* **Typed HTTP Client (nếu có):** N/A (Handler hiện không inject `IWalletDbContext`)
* **Hành vi nghiệp vụ hiện tại:** `RequestWithdrawalCommandHandler.Handle()` **luôn ném** `BusinessRuleValidationException` với message `"Direct wallet withdrawal is disabled. Submit a withdrawal request for staff approval."`, nên endpoint trả HTTP `400` với `errorCode = BUSINESS_RULE_VIOLATION`. Luồng tạo yêu cầu rút tiền chưa được bật; không có bản ghi DB nào được tạo.

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "amount": 200000,
  "bankCode": "MB",
  "accountNumber": "0987654321",
  "accountHolderName": "NGUYEN VAN A"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi hiện tại (`400 Bad Request`)
Handler luôn ném `BusinessRuleValidationException`, nên endpoint hiện chỉ trả về problem details:
```json
400 Bad Request:
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "Business rule violation",
  "status": 400,
  "errorCode": "BUSINESS_RULE_VIOLATION",
  "detail": "Direct wallet withdrawal is disabled. Submit a withdrawal request for staff approval.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
}
```

### 4.2. Phản hồi thành công dự kiến (`ApiResponse<T>`)
Mẫu dưới đây chỉ áp dụng khi luồng tạo yêu cầu rút tiền được bật lại trong Handler:
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "transactionId": "uuid",
    "amount": 200000,
    "currency": "Vnd",
    "status": "Pending",
    "createdAt": "2026-10-26T00:00:00Z"
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
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm DataAnnotations (`[Range(50000, 500000000)]` trên `Amount`, `[Required]` trên `BankCode`/`AccountNumber`) hoặc model binding. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Direct wallet withdrawal is disabled. Submit a withdrawal request for staff approval." | `RequestWithdrawalCommandHandler.Handle()` luôn ném `BusinessRuleValidationException` ở mọi request. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | Thiếu `x-user-id` hợp lệ hoặc JWT không hợp lệ; chặn bởi `RequireRole` và `TryGetUserId()`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `WithdrawalStatus` | `0` | `Pending` | **Chờ duyệt rút tiền**: Seller gửi yêu cầu rút tiền, chờ Admin phê duyệt. Badge vàng (Warning). |
| `status` | `WithdrawalStatus` | `1` | `Approved` | **Đã phê duyệt**: Kế toán đã ký duyệt lệnh chuyển khoản. Badge xanh lá nhạt (Primary). |
| `status` | `WithdrawalStatus` | `2` | `Processing` | **Đang chuyển khoản liên ngân hàng**: Hệ thống đang chuyển tiền qua Napas/VietQR. Badge xanh dương (Info). |
| `status` | `WithdrawalStatus` | `3` | `Completed` | **Rút tiền thành công**: Tiền đã về tài khoản ngân hàng của Seller. Badge xanh lá (Success). |
| `status` | `WithdrawalStatus` | `4` | `Rejected` | **Bị từ chối**: Thông tin ngân hàng không khớp hoặc số dư bị nghi vấn. Badge đỏ (Danger). |
| `status` | `WithdrawalStatus` | `5` | `Failed` | **Lỗi chuyển khoản**: Lỗi kỹ thuật từ cổng Napas/ngân hàng thụ hưởng. Badge đỏ (Danger). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `RequestWithdrawalCommand.cs` và `RequestWithdrawalCommandHandler.cs` mới chỉ là stub (CQRS + MediatR) và **luôn ném** `BusinessRuleValidationException`; luồng tạo `WithdrawalRequest` + khóa tiền (`LockFunds`) chưa được triển khai. Cần Sếp quyết định bật lại hay bỏ endpoint.
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** DataAnnotations trên command chặn biên (`VAL_INVALID_INPUT` 400); lỗi nghiệp vụ trả `BUSINESS_RULE_VIOLATION` 400 qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `WithdrawalStatus` lưu integer trong DB và serialize chuỗi PascalCase ở API (`withdrawal.Status.ToString()`).
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `RequestWithdrawal_IsDisabled`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
