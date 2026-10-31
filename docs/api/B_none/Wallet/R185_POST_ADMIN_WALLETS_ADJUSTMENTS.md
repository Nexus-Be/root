# [POST] /api/v1/admin/wallets/{walletId}/adjustments

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-10``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Admin điều chỉnh số dư ví thủ công (Cộng/Trừ tiền kèm kiểm toán)
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/admin/wallets/{walletId}/adjustments`
* **Đường dẫn gốc trong Excel:** `/api/v1/admin/wallets/{walletId}/adjustments` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/AdminWalletsController.cs` $\rightarrow$ `AdjustBalance()`
* **Command:** `Wallet.Application/Features/AdminWallets/Commands/AdjustWalletBalance/AdjustWalletBalanceCommand.cs` $\rightarrow$ `AdjustWalletBalanceCommand`
* **Command Handler:** `Wallet.Application/Features/AdminWallets/Commands/AdjustWalletBalance/AdjustWalletBalanceCommandHandler.cs` $\rightarrow$ `AdjustWalletBalanceCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/AdminWallets/Commands/AdjustWalletBalance/AdjustWalletBalanceCommand.cs` $\rightarrow$ `BalanceAdjustmentResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions`; `Wallet.Domain/Entities/AuditLog.cs` $\rightarrow$ Bảng `AuditLogs`
* **Typed HTTP Client (nếu có):** N/A (Handler inject trực tiếp `IWalletDbContext`)
* **Hành vi nghiệp vụ:** `WalletId` lấy từ route, `AdminUserId` lấy từ claims/header `x-user-id` (qua `HttpContext.GetUserId()`). `AdjustmentType` parse qua `EnumExtensions.TryToEnum<BalanceAdjustmentType>` (chỉ chấp nhận `Credit`/`Debit`, không phân biệt hoa thường, từ chối số nguyên thô và giá trị lạ); `Credit` cộng tiền, `Debit` trừ tiền. Mỗi lần điều chỉnh ghi một `WalletTransaction` (`AdjustmentCredit` / `AdjustmentDebit`) và một `AuditLog` (`AuditAction.BalanceAdjustment`) trong cùng transaction.

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `walletId` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

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
  "walletId": "uuid"
}

Body:
{
  "amount": 50000,
  "reason": "Compensation for dispute resolution #SUB-01",
  "adjustmentType": "Credit|Debit"
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
    "adjustmentId": "uuid",
    "walletId": "uuid",
    "amount": 50000,
    "balanceAfter": 1070000,
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
| `400` | `VAL_INVALID_INPUT` | "Amount must be greater than zero." | `Amount < 0.01` (DataAnnotations qua `ValidationBehavior`). |
| `400` | `VAL_INVALID_INPUT` | "Adjustment type is required." | `AdjustmentType` rỗng (`[Required]`). |
| `400` | `VAL_INVALID_INPUT` | "Reason is required." | `Reason` rỗng (`[Required]`). |
| `400` | `VAL_INVALID_ADJUSTMENT_TYPE` | "Adjustment type must be either 'Credit' or 'Debit'." | `AdjustmentType` không parse được thành `BalanceAdjustmentType` (ví dụ `"HACK"` hoặc `"0"`). |
| `400` | `VAL_INVALID_ARGUMENT` | "Admin user ID is invalid." | `x-user-id` không parse được thành `Guid` khác rỗng. |
| `400` | `INSUFFICIENT_BALANCE` | "Insufficient wallet balance. Current: {balance}, requested: {amount}" | `Debit` vượt quá số dư khả dụng (`WalletAccount.Deduct()`). |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole("admin","staff")` không tìm thấy danh tính hợp lệ. |
| `403` | `FORBIDDEN` | "Access denied. Required roles: [admin, staff]." | Danh tính hợp lệ nhưng không có role `admin`/`staff`. |
| `404` | `WALLET_NOT_FOUND` | "Wallet for user '{walletId}' was not found." | `LockWalletByIdAsync` không tìm thấy ví. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `TransactionStatus` | `0` | `Pending` | **Đang xử lý**: Giao dịch đang chờ ngân hàng/cổng thanh toán phản hồi. Badge vàng (Warning). |
| `status` | `TransactionStatus` | `1` | `Success` | **Thành công**: Tiền đã ghi có/ghi nợ thành công vào số dư ví. Badge xanh lá (Success). |
| `status` | `TransactionStatus` | `2` | `Failed` | **Thất bại**: Giao dịch bị lỗi hoặc tài khoản không đủ điều kiện. Badge đỏ (Danger). |
| `status` | `TransactionStatus` | `3` | `Cancelled` | **Đã hủy**: Giao dịch bị người dùng hoặc hệ thống hủy bỏ. Badge xám (Muted). |
| `type` | `WalletTransactionType` | `0` | `TopupVnpay` | **Nạp tiền ví VNPay**: Nạp tiền từ tài khoản ngân hàng qua VNPay (+). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `1` | `PurchaseDebit` | **Thanh toán đơn hàng**: Trừ tiền mua sản phẩm (-). Badge đỏ (-). |
| `type` | `WalletTransactionType` | `2` | `RefundCredit` | **Hoàn tiền đơn hàng**: Nhận lại tiền từ đơn hủy hoặc trả hàng (+). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `3` | `EscrowCredit` | **Tạm giữ tiền bán hàng**: Tiền khách mua hàng được đưa vào số dư đóng băng (+ Escrow). Badge xanh dương. |
| `type` | `WalletTransactionType` | `4` | `EscrowRelease` | **Giải phóng tiền bán hàng**: Chuyển từ đóng băng sang số dư khả dụng khi hoàn tất (+ Available). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `5` | `WithdrawalDebit` | **Rút tiền về ngân hàng**: Trừ số dư khả dụng để chuyển khoản về ngân hàng (-). Badge đỏ (-). |
| `type` | `WalletTransactionType` | `6` | `WithdrawalReversal` | **Hoàn lại tiền rút**: Yêu cầu rút tiền bị từ chối, hoàn lại tiền vào ví (+). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `7` | `PlatformFeeCredit` | **Khấu trừ phí sàn**: Trừ phí dịch vụ sàn thương mại điện tử (-). Badge cam (-). |
| `type` | `WalletTransactionType` | `8` | `AdjustmentCredit` | **Admin cộng tiền điều chỉnh**: Bù tiền hoặc thưởng kiểm toán (+). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `9` | `AdjustmentDebit` | **Admin trừ tiền điều chỉnh**: Thu hồi tiền gian lận hoặc phạt vi phạm (-). Badge đỏ (-). |
| `type` | `WalletTransactionType` | `10` | `DirectGatewayPayment` | **Thanh toán trực tiếp qua cổng**: Thanh toán thẳng từ VNPay cho đơn hàng. Badge xanh dương (Info). |
| `type` | `WalletTransactionType` | `11` | `TransferIn` | **Nhận chuyển khoản nội bộ**: Tiền nhận từ ví thành viên khác (+). Badge xanh lá (+). |
| `type` | `WalletTransactionType` | `12` | `TransferOut` | **Chuyển khoản nội bộ**: Chuyển tiền sang ví thành viên khác (-). Badge đỏ (-). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `AdjustWalletBalanceCommand.cs` và `AdjustWalletBalanceCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không còn lớp feature service cũ).
- [x] **2. Tầng Api:** `AdminWalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `[Range(0.01, ...)]` trên `Amount` và `[Required]` trên `AdjustmentType`/`Reason` trả `VAL_INVALID_INPUT` 400; `WalletNotFoundException` (`WALLET_NOT_FOUND` 404), `InsufficientBalanceException` (`INSUFFICIENT_BALANCE` 400) và `ArgumentException` (`VAL_INVALID_ARGUMENT` 400) đi qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `WalletTransactionType`, `TransactionStatus`, `AuditAction` lưu integer trong DB; giá trị trả API dùng `walletTransaction.Type`/`Status` qua `ToString()`.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `AdjustBalance_Debit_ReducesBalance`; `WalletContractRegressionTests.cs` - `AdjustBalance_UnknownType_IsRejectedWithoutSideEffects`, `AdjustBalance_NumericType_IsRejected`).
- [x] **6. Định tuyến Gateway:** Route YARP `admin-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
