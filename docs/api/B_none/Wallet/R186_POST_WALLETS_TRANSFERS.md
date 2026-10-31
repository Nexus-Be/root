# [POST] /api/v1/wallets/transfers

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Transfers`  
> **Mã tham chiếu Excel:** `N/A (không có trong Excel mapping; bổ sung sau)`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Chuyển tiền nội bộ giữa hai ví Nexus trong cùng một transaction cơ sở dữ liệu. Ví gửi bị trừ tiền, ví nhận được cộng tiền, mỗi bên có một bản ghi sổ cái riêng.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/wallets/transfers`
* **Đường dẫn gốc trong Excel:** `N/A (không có trong Excel mapping)` (Đường dẫn tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer` / `Seller` (mọi tài khoản đã đăng nhập; controller gắn `[RequireRole]` không tham số)
* **Yêu cầu Idempotency:** Tùy chọn (Handler chưa triển khai khóa `Idempotency-Key`, client vẫn nên gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `Transfer()`
* **Command:** `Wallet.Application/Features/Transfers/Commands/Transfer/TransferCommand.cs` $\rightarrow$ `TransferCommand`
* **Command Handler:** `Wallet.Application/Features/Transfers/Commands/Transfer/TransferCommandHandler.cs` $\rightarrow$ `TransferCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Transfers/Commands/Transfer/TransferCommand.cs` $\rightarrow$ `TransferResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions`
* **Typed HTTP Client (nếu có):** N/A (Handler inject trực tiếp `IWalletDbContext`)
* **Hành vi nghiệp vụ:** `SenderUserId` do controller lấy từ `x-user-id` và ghi đè vào command; Handler khóa hai ví theo thứ tự GUID tăng dần để tránh deadlock, gọi `Deduct()` trên ví gửi và `Deposit()` trên ví nhận, rồi thêm hai `WalletTransaction` (`TransferOut` cho người gửi, `TransferIn` cho người nhận).

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
*Không có tham số đường dẫn.*

### 3.2. Query Parameters
*Không có tham số truy vấn.*

### 3.3. Header bắt buộc
| Tên header | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `Authorization` | `string` | Có | `Bearer <JWT>` hợp lệ; Gateway tiêm `x-user-id` sau khi xác thực. |

### 3.4. Request Body (JSON Payload)
| Trường | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `recipientUserId` | `string (UUID)` | Có | `[Required]`; phải parse được thành `Guid` khác `Guid.Empty`, khác người gửi. |
| `amount` | `decimal` | Có | `[Range(1000, 100000000)]`, đơn vị VND. |
| `note` | `string` | Không | Tối đa theo cột DB; rỗng thì hệ thống tự sinh ghi chú `Transfer out/in {userId}`. |

```json
{
  "recipientUserId": "22222222-2222-2222-2222-222222222222",
  "amount": 25000,
  "note": "rent"
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "transactionId": "11111111-1111-1111-1111-000000000001",
    "amount": 25000,
    "currency": "Vnd",
    "status": "Success",
    "createdAt": "2026-10-30T15:30:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-30T15:30:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | `recipientUserId` thiếu hoặc `amount` ngoài khoảng 1.000 - 100.000.000 (DataAnnotations + `[ApiController]`). |
| `400` | `VAL_INVALID_ARGUMENT` | "Sender user ID is invalid." | `SenderUserId` từ `x-user-id` không parse được thành `Guid`. |
| `400` | `VAL_INVALID_ARGUMENT` | "Recipient user ID is invalid." | `recipientUserId` không parse được thành `Guid` khác rỗng. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Cannot transfer funds to yourself." | `senderGuid == recipientGuid`. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Wallet currencies do not match." | Ví gửi và ví nhận khác `Currency`. |
| `400` | `INSUFFICIENT_BALANCE` | "Insufficient wallet balance. Current: {balance}, requested: {amount}" | `WalletAccount.Deduct()` phát hiện số dư khả dụng nhỏ hơn số tiền chuyển. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole` hoặc `TryGetUserId()` không tìm thấy danh tính hợp lệ. |
| `404` | `WALLET_NOT_FOUND` | "Wallet for user '{userId}' was not found." | Không tìm thấy ví của người gửi hoặc người nhận. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `TransactionStatus` | `1` | `Success` | **Thành công**: Giao dịch đã ghi sổ xong trong transaction. Badge xanh lá. |
| `status` | `TransactionStatus` | `0` | `Pending` | **Đang xử lý**: Chưa áp dụng cho luồng chuyển khoản nội bộ, giữ để đối chiếu. Badge vàng. |
| `status` | `TransactionStatus` | `2` | `Failed` | **Thất bại**: Chưa áp dụng cho luồng chuyển khoản nội bộ, giữ để đối chiếu. Badge đỏ. |
| `status` | `TransactionStatus` | `3` | `Cancelled` | **Đã hủy**: Chưa áp dụng cho luồng chuyển khoản nội bộ, giữ để đối chiếu. Badge xám. |
| `type` (bản ghi người gửi) | `WalletTransactionType` | `12` | `TransferOut` | **Chuyển khoản nội bộ**: Tiền rời ví người gửi (-). Badge đỏ. |
| `type` (bản ghi người nhận) | `WalletTransactionType` | `11` | `TransferIn` | **Nhận chuyển khoản nội bộ**: Tiền vào ví người nhận (+). Badge xanh lá. |
| `currency` | `CurrencyCode` | `0` | `Vnd` | **Việt Nam đồng**: Đơn vị tiền tệ mặc định của ví. |
| `currency` | `CurrencyCode` | `1` | `Usd` | **Đô la Mỹ**: Chỉ dùng khi cả hai ví cùng `Usd`, nếu khác sẽ trả `BUSINESS_RULE_VIOLATION`. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `TransferCommand.cs` và `TransferCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không dùng Repository).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code và đi qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `TransactionStatus`, `WalletTransactionType`, `CurrencyCode` lưu integer trong DB và serialize PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `Transfer_MovesFundsOnBothSides`, `Transfer_InsufficientBalance_Throws`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
