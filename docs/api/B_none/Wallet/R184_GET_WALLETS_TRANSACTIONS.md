# [GET] /api/v1/wallets/transactions

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-09``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu lịch sử biến động sổ cái (wallet_transactions) cá nhân
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/wallets/transactions`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/transactions` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `ListTransactions()`
* **Query:** `Wallet.Application/Features/Wallets/Queries/ListTransactions/ListTransactionsQuery.cs` $\rightarrow$ `ListTransactionsQuery`
* **Query Handler:** `Wallet.Application/Features/Wallets/Queries/ListTransactions/ListTransactionsQueryHandler.cs` $\rightarrow$ `ListTransactionsQueryHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Wallets/Queries/ListTransactions/ListTransactionsQuery.cs` $\rightarrow$ `WalletTransactionPageResponse` (gồm `Items`, `TotalItems`, `PageNumber`, `PageSize`, `TotalPages`) và `WalletTransactionResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Handler inject trực tiếp `IWalletDbContext`, không dùng Repository)
* **Hành vi nghiệp vụ:** Handler lọc theo `UserId` lấy từ `x-user-id`; tham số `type` nhận alias `ALL`/`DEPOSIT`/`WITHDRAWAL`/`PAYMENT`/`REFUND` hoặc tên `WalletTransactionType`; phân trang tại DB bằng `.Skip().Take()` kèm `.CountAsync()`, sắp xếp mới nhất trước.

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số trang, tối thiểu `1` (`[Range(1, int.MaxValue)]`). |
| `pageSize` | `integer` | `10` | Kích thước trang, `1 .. 100` (`[Range(1, 100)]`). |
| `type` | `string` | `null` | Alias `ALL`/`DEPOSIT`/`WITHDRAWAL`/`PAYMENT`/`REFUND` (không phân biệt hoa thường) hoặc tên `WalletTransactionType`. |
| `fromDate` | `DateTimeOffset` | `null` | Lọc `CreatedAt >= fromDate`. |
| `toDate` | `DateTimeOffset` | `null` | Lọc `CreatedAt <= toDate`. |

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": 1,
  "pageSize": 10,
  "type": "ALL|DEPOSIT|WITHDRAWAL|PAYMENT|REFUND",
  "fromDate": "2026-10-01",
  "toDate": "2026-10-26"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<WalletTransactionPageResponse>`)
Service trả trực tiếp `WalletTransactionPageResponse`; Gateway bọc thành `ApiResponse<T>`. Bộ trang nằm phẳng trong `data`, không dùng object `pagination`.
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "walletId": "uuid",
        "userId": "uuid",
        "type": "PurchaseDebit",
        "amount": 480000,
        "currency": "Vnd",
        "balanceAfter": 1020000,
        "status": "Success",
        "note": "Payment for order #SUB-01",
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "totalItems": 1,
    "pageNumber": 1,
    "pageSize": 10,
    "totalPages": 1
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
| `400` | `VAL_INVALID_INPUT` | "Page must be greater than or equal to 1." | `page < 1` (DataAnnotations trên `ListTransactionsQuery`, chặn bởi `ValidationBehavior`). |
| `400` | `VAL_INVALID_INPUT` | "Page size must be between 1 and 100." | `pageSize < 1` hoặc `pageSize > 100`. |
| `400` | `VAL_INVALID_ARGUMENT` | "Transaction type is invalid." | `type` không khớp alias và không parse được thành `WalletTransactionType`. |
| `400` | `VAL_INVALID_ARGUMENT` | "User ID must be a valid UUID." | `x-user-id` không parse được thành `Guid` khác rỗng. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole` không tìm thấy danh tính hợp lệ. |
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

- [x] **1. Tầng Application:** `ListTransactionsQuery.cs` và `ListTransactionsQueryHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không còn lớp feature service cũ).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `[Range(1, int.MaxValue)]`/`[Range(1, 100)]` trên `Page`/`PageSize`, `ArgumentException` (`VAL_INVALID_ARGUMENT` 400) khi `type` không hợp lệ, và `UNAUTHORIZED` 401 khi thiếu danh tính.
- [x] **4. Enum Mapping:** `WalletTransactionType`, `TransactionStatus`, `CurrencyCode` lưu integer trong DB và serialize chuỗi PascalCase ở API (`t.Type.ToString()`, `t.Status.ToString()`).
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `ListTransactions_FiltersByAliasAndPaginatesNewestFirst`; `WalletContractRegressionTests.cs` - `ListTransactions_InvalidTypeAlias_IsRejected`, `ListTransactions_DateRange_FiltersRows`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
