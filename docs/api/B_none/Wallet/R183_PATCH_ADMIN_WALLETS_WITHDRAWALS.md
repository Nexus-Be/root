# [PATCH] /api/v1/admin/wallets/withdrawals/{id}

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-08``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Quản trị viên duyệt hoặc từ chối yêu cầu rút tiền của Seller
* **HTTP Method:** `PATCH`
* **Đường dẫn chuẩn:** `/api/v1/admin/wallets/withdrawals/{id}`
* **Đường dẫn gốc trong Excel:** `/api/v1/admin/wallets/withdrawals/{id}` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/AdminWalletsController.cs` $\rightarrow$ `ProcessWithdrawal()`
* **Command:** `Wallet.Application/Features/AdminWallets/Commands/ProcessWithdrawal/ProcessWithdrawalCommand.cs` $\rightarrow$ `ProcessWithdrawalCommand`
* **Command Handler:** `Wallet.Application/Features/AdminWallets/Commands/ProcessWithdrawal/ProcessWithdrawalCommandHandler.cs` $\rightarrow$ `ProcessWithdrawalCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/AdminWallets/Commands/ProcessWithdrawal/ProcessWithdrawalCommand.cs` $\rightarrow$ `ProcessWithdrawalResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WithdrawalRequest.cs` $\rightarrow$ Bảng `WithdrawalRequests`; `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions`; `Wallet.Domain/Entities/AuditLog.cs` $\rightarrow$ Bảng `AuditLogs`
* **Typed HTTP Client (nếu có):** N/A (Handler inject trực tiếp `IWalletDbContext`)
* **Hành vi nghiệp vụ:** `AdminUserId` lấy từ claims/header `x-user-id` do Gateway tiêm (qua `HttpContext.GetUserId()`); `WithdrawalId` lấy từ route. `Action` được parse qua `EnumExtensions.TryToEnum<WithdrawalDecision>` (chấp nhận `Approve`/`Reject`, không phân biệt hoa thường, từ chối số nguyên thô). `Approve` chuyển tiền khóa sang trừ thật và ghi `WalletTransaction` loại `WithdrawalDebit`; `Reject` hoàn tiền khóa. Mỗi lần xử lý đều ghi `AuditLog` (`AuditAction.WithdrawalApprove` / `WithdrawalReject`) và trả `status` PascalCase (`Approved` / `Rejected`).

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `id` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "id": "uuid"
}

Body:
{
  "action": "Approve|Reject",
  "adminNote": "Approved by finance department."
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
  "data": {
    "withdrawalId": "uuid",
    "status": "Approved",
    "processedAt": "2026-10-26T00:00:00Z",
    "transactionId": "uuid"
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
| `400` | `VAL_INVALID_INPUT` | "Action is required." | `Action` rỗng (DataAnnotations `[Required]` qua `ValidationBehavior`). |
| `400` | `VAL_INVALID_ACTION` | "Action must be either 'Approve' or 'Reject'." | `Action` không parse được thành `WithdrawalDecision` (ví dụ `"HACK"` hoặc `"0"`). |
| `400` | `VAL_INVALID_ARGUMENT` | "Admin user ID is invalid." | `x-user-id` không parse được thành `Guid` khác rỗng. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Withdrawal request has already been processed." | `WithdrawalRequest.Status != Pending`. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole("admin","staff")` không tìm thấy danh tính hợp lệ. |
| `403` | `FORBIDDEN` | "Access denied. Required roles: [admin, staff]." | Danh tính hợp lệ nhưng không có role `admin` hoặc `staff`. |
| `404` | `NOT_FOUND` | "Entity 'WithdrawalRequest' with key '{id}' was not found." | `LockWithdrawalRequestAsync` không tìm thấy yêu cầu rút tiền. |
| `404` | `WALLET_NOT_FOUND` | "Wallet for user '{userId}' was not found." | `WalletId` của yêu cầu rút tiền không còn tồn tại. |
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

- [x] **1. Tầng Application:** `ProcessWithdrawalCommand.cs` và `ProcessWithdrawalCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không còn lớp feature service cũ).
- [x] **2. Tầng Api:** `AdminWalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `EntityNotFoundException` (`NOT_FOUND` 404), `BusinessRuleValidationException` (`BUSINESS_RULE_VIOLATION` 400 khi yêu cầu đã xử lý), `WalletNotFoundException` (`WALLET_NOT_FOUND` 404) và `ArgumentException` (`VAL_INVALID_ARGUMENT` 400) đều đi qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `WithdrawalStatus` và `AuditAction` lưu integer trong DB; `WithdrawalStatus` serialize PascalCase qua `withdrawal.Status.ToString()`.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `ProcessWithdrawal_Approve_DeductsLockedFunds`; `WalletContractRegressionTests.cs` - `ProcessWithdrawal_Approve_ReturnsPascalCaseStatus`, `ProcessWithdrawal_UnknownAction_IsRejectedWithoutSideEffects`).
- [x] **6. Định tuyến Gateway:** Route YARP `admin-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
