# [POST] /api/v1/wallets/vnpay/ipn

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-04``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Webhook nhận kết quả IPN từ VNPay (Nạp ví hoặc Thanh toán đơn trực tiếp)
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/wallets/vnpay/ipn`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/vnpay/ipn` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `VnPayIpn()` (đọc form hoặc JSON body thành `Dictionary<string, string>`)
* **Command:** `Wallet.Application/Features/VnPay/Commands/ProcessVnPayIpn/ProcessVnPayIpnCommand.cs` $\rightarrow$ `ProcessVnPayIpnCommand`
* **Command Handler:** `Wallet.Application/Features/VnPay/Commands/ProcessVnPayIpn/ProcessVnPayIpnCommandHandler.cs` $\rightarrow$ `ProcessVnPayIpnCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/VnPay/Commands/ProcessVnPayIpn/ProcessVnPayIpnCommand.cs` $\rightarrow$ `VnPayIpnResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletTopup.cs` $\rightarrow$ Bảng `WalletTopups`; `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions`
* **Typed HTTP Client (nếu có):** `Wallet.Infrastructure/Payments/VnPayService.cs` (`IVnPayService.ValidateSignature`) xác thực checksum
* **Hành vi nghiệp vụ:** Endpoint trả HTTP `200` kèm cặp `ResponseCode`/`Message` theo quy ước VNPay (`00` thành công, `01` không tìm thấy đơn, `02` đơn đã xử lý, `04` sai số tiền, `97` sai chữ ký, `99` thiếu tham số). Handler khóa dòng `WalletTopup` (`SELECT ... FOR UPDATE`) trước khi kiểm tra trạng thái để chống cộng tiền hai lần khi VNPay gửi IPN trùng. Khi `vnp_ResponseCode = "00"`, Handler khóa `WalletAccount`, cộng tiền, ghi một `WalletTransaction` loại `TopupVnpay` và một `AuditLog` (`TopupSuccess`); nếu không tìm thấy ví tương ứng, Handler trả `"01"` và giữ nguyên `WalletTopup` ở trạng thái `Pending` (không đánh dấu thành công, không mất tiền).

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
  "vnp_TmnCode": "NEXUS001",
  "vnp_Amount": "50000000",
  "vnp_BankCode": "NCB",
  "vnp_BankTranNo": "VNP14072026",
  "vnp_CardType": "ATM",
  "vnp_OrderInfo": "Topup wallet",
  "vnp_PayDate": "20261026103000",
  "vnp_ResponseCode": "00",
  "vnp_TransactionNo": "14072026",
  "vnp_TransactionStatus": "00",
  "vnp_TxnRef": "TOPUP-20261026-1234",
  "vnp_SecureHash": "abcdef123456..."
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
200 OK:
{
  "RspCode": "00",
  "Message": "Confirm success."
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

Endpoint luôn trả HTTP `200 OK` theo quy ước VNPay; kết quả nghiệp vụ nằm trong cặp `responseCode` / `message` của body.

| HTTP Status | responseCode | message | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `200` | `00` | "Success" | Xử lý thành công (đã cộng tiền hoặc đã ghi nhận thất bại). |
| `200` | `01` | "Order not found" | Không tìm thấy `WalletTopup` theo `vnp_TxnRef`. |
| `200` | `01` | "Wallet not found for topup" | Tìm thấy topup nhưng `WalletAccount` tương ứng không còn tồn tại; topup giữ `Pending`. |
| `200` | `02` | "Order already processed" | `WalletTopup.Status != Pending` (IPN gửi lặp). |
| `200` | `04` | "Invalid amount" | `vnp_Amount` không parse được hoặc `topup.Amount * 100 != vnp_Amount`. |
| `200` | `97` | "Invalid signature" | `IVnPayService.ValidateSignature` trả `false`. |
| `200` | `99` | "Missing parameters" | Thiếu `vnp_TxnRef` hoặc `vnp_ResponseCode`. |
| `400` | Không có (problem+json) | "The request body is not valid." | Body/IPN payload không đọc được hoặc sai kiểu; `ApiValidationProblemFactory` trả `errorCode = VAL_INVALID_INPUT` trước khi vào handler. |
| `500` | Không có | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý (problem details). |

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

- [x] **1. Tầng Application:** `ProcessVnPayIpnCommand.cs` và `ProcessVnPayIpnCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không còn lớp feature service cũ).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Sai chữ ký trả `ResponseCode = "97"`, thiếu tham số trả `"99"`, không tìm thấy topup trả `"01"`, đơn đã xử lý trả `"02"`, sai số tiền trả `"04"`; toàn bộ đi qua `ProcessVnPayIpnCommandHandler`.
- [x] **4. Enum Mapping:** `TopupStatus`, `TransactionStatus`, `WalletTransactionType`, `CurrencyCode` lưu integer trong DB và serialize chuỗi PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `ProcessVnPayIpn_InvalidSignature_Returns97`, `ProcessVnPayIpn_Success_DepositsAndMarksTopupSuccess`; `WalletContractRegressionTests.cs` - `ProcessVnPayIpn_UnknownTopup_Returns01`, `ProcessVnPayIpn_MissingWallet_DoesNotMarkTopupSuccessful`, `ProcessVnPayIpn_AmountMismatch_Returns04AndKeepsTopupPending`, `ProcessVnPayIpn_FailedPayment_MarksTopupFailedAndAudits`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
