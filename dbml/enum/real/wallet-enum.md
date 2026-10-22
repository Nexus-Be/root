# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — WALLET SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `CurrencyCode` | `Wallets.Currency` | `Vnd (0)` | Đơn vị tiền tệ hỗ trợ trên ví |
| 2 | `WalletTransactionType` | `WalletTransactions.Type` | — | Phân loại biến động số dư sổ cái ví (Ledger) |
| 3 | `TransactionStatus` | `WalletTransactions.Status` | `Pending (0)` | Trạng thái giao dịch biến động ví |
| 4 | `TopupStatus` | `WalletTopups.Status`, `DirectPaymentOrders.Status` | `Pending (0)` | Trạng thái lệnh nạp tiền & đơn thanh toán trực tiếp qua cổng thanh toán |
| 5 | `WithdrawalStatus` | `WithdrawalRequests.Status` | `Pending (0)` | Vòng đời yêu cầu rút tiền về tài khoản ngân hàng |
| 6 | `IpnProcessingStatus` | `VnpayIpnLogs.ProcessingStatus` | `Processed (0)` | Kết quả xử lý Webhook IPN từ cổng thanh toán |
| 7 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác tài chính |

---

## 2. Chi Tiết Từng Enum

### 2.1 CurrencyCode – Mã Tiền Tệ
* **Bảng CSDL:** `Wallets.Currency`
* **Kiểu dữ liệu:** `Enum CurrencyCode`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Vnd` | Việt Nam Đồng (tiền tệ chính thức toàn sàn) |
| `1` | `Usd` | Đô la Mỹ |

---

### 2.2 WalletTransactionType – Loại Giao Dịch Số Dư Ví (Ledger)
* **Bảng CSDL:** `WalletTransactions.Type`
* **Kiểu dữ liệu:** `Enum WalletTransactionType`
* **Ghi chú:** Ưu tiên theo định nghĩa chi tiết của tài liệu kỹ thuật Wallet Service.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `TopupVnpay` | Nạp tiền vào ví qua cổng thanh toán VNPay |
| `1` | `PurchaseDebit` | Trừ tiền thanh toán đơn hàng thông thường |
| `2` | `RefundCredit` | Hoàn tiền vào ví do hủy đơn hoặc trả hàng |
| `3` | `EscrowCredit` | Giữ tiền cọc / tạm giữ ký quỹ phiên đấu giá |
| `4` | `EscrowRelease` | Giải tỏa tiền ký quỹ đấu giá (hoàn tiền hoặc giải ngân) |
| `5` | `WithdrawalDebit` | Trừ tiền khi thực hiện lệnh rút về ngân hàng |
| `6` | `WithdrawalReversal` | Hoàn lại tiền vào ví khi lệnh rút tiền bị từ chối / lỗi mạng |
| `7` | `PlatformFeeCredit` | Thu phí nền tảng từ doanh thu người bán |
| `8` | `AdjustmentCredit` | Điều chỉnh cộng tiền thủ công từ Admin / đối soát |
| `9` | `AdjustmentDebit` | Điều chỉnh trừ tiền thủ công từ Admin / đối soát |
| `10` | `DirectVnpayDebit` | Thanh toán trực tiếp đơn hàng qua cổng VNPay (không qua ví) |

---

### 2.3 TransactionStatus – Trạng Thái Giao Dịch Số Dư
* **Bảng CSDL:** `WalletTransactions.Status`
* **Kiểu dữ liệu:** `Enum TransactionStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Đang chờ xử lý hoàn tất bút toán |
| `1` | `Success` | Bút toán thành công, số dư khả dụng đã thay đổi |
| `2` | `Failed` | Bút toán thất bại do lỗi kỹ thuật hoặc thiếu số dư |
| `3` | `Cancelled` | Giao dịch bị hủy bỏ trước khi hoàn tất |

---

### 2.4 TopupStatus – Trạng Thái Lệnh Nạp Tiền & Đơn Thanh Toán Trực Tiếp
* **Bảng CSDL:** `WalletTopups.Status`, `DirectPaymentOrders.Status`
* **Kiểu dữ liệu:** `Enum TopupStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Đã tạo URL thanh toán, chờ người dùng thanh toán trên cổng VNPay |
| `1` | `Success` | Cổng VNPay xác nhận thành công, tiền đã nạp vào ví |
| `2` | `Failed` | Thanh toán thất bại hoặc người dùng hủy giao dịch tại cổng |
| `3` | `Expired` | Quá thời hạn thanh toán (thường sau 15 phút) |

---

### 2.5 WithdrawalStatus – Trạng Thái Yêu Cầu Rút Tiền
* **Bảng CSDL:** `WithdrawalRequests.Status`
* **Kiểu dữ liệu:** `Enum WithdrawalStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Yêu cầu mới tạo, đang chờ xét duyệt thủ công / tự động |
| `1` | `Approved` | Đã được kế toán/hệ thống phê duyệt, sẵn sàng chuyển khoản |
| `2` | `Processing` | Lệnh chuyển tiền đang được thực thi qua cổng/ngân hàng |
| `3` | `Completed` | Chuyển khoản thành công, tiền đã về tài khoản ngân hàng của user |
| `4` | `Rejected` | Bị từ chối rút (sai số tài khoản, nghi vấn rửa tiền...) |
| `5` | `Failed` | Lỗi đường truyền liên ngân hàng, tự động hoàn tiền lại ví |

---

### 2.6 IpnProcessingStatus – Trạng Thái Xử Lý Webhook IPN
* **Bảng CSDL:** `VnpayIpnLogs.ProcessingStatus`
* **Kiểu dữ liệu:** `Enum IpnProcessingStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Processed` | Xử lý hợp lệ và đã cập nhật giao dịch thành công |
| `1` | `Duplicate` | Webhook gửi trùng lặp (đã xử lý trước đó - Idempotent) |
| `2` | `InvalidSignature` | Sai chữ ký bảo mật Checksum SHA-512 |
| `3` | `OrderNotFound` | Không tìm thấy mã đơn hàng giao dịch tham chiếu |
| `4` | `InvalidAmount` | Số tiền thanh toán không khớp với số tiền đã tạo lệnh |
| `5` | `SystemError` | Lỗi nội bộ hệ thống trong quá trình xử lý Webhook |

---

### 2.7 AuditAction – Hành Động Kiểm Toán Tài Chính
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `WalletCreate` | Tạo mới ví điện tử cho người dùng |
| `1` | `TopupRequest` | Khởi tạo yêu cầu nạp tiền |
| `2` | `TopupSuccess` | Ghi nhận nạp tiền thành công |
| `3` | `TopupFail` | Ghi nhận nạp tiền thất bại |
| `4` | `WithdrawalRequest` | Gửi yêu cầu rút tiền |
| `5` | `WithdrawalApprove` | Duyệt lệnh rút tiền |
| `6` | `WithdrawalReject` | Từ chối lệnh rút tiền |
| `7` | `WithdrawalComplete` | Hoàn thành chuyển khoản rút tiền |
| `8` | `BalanceAdjustment` | Admin can thiệp điều chỉnh số dư |
