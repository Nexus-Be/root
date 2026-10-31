# [POST] /api/v1/payments/webhook

> **⚠️ SUPERSEDED:** Endpoint `/api/v1/payments/webhook` không tồn tại trong mã nguồn WalletService (không có action `PaymentsWebhook` trong controller nào). Callback VNPay thật của hệ thống là `POST /api/v1/wallets/vnpay/ipn`, xem `R180_POST_WALLETS_VNPAY_IPN.md`. File này chỉ giữ lại để truy vết lịch sử, không dùng để triển khai hay kiểm thử.

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``PAY-01``  
> **Trạng thái tài liệu:** `SUPERSEDED`  
> **Trạng thái triển khai:** `SUPERSEDED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** thành công, chuyển
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/payments/webhook`
* **Đường dẫn gốc trong Excel:** `/api/v1/payments/webhook` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** Không có route YARP nào cho `/api/v1/payments/*` trong `src/Services/Gateway/Gateway/appsettings.json`
* **Controller Action:** Không tồn tại. Không controller nào của WalletService khai báo route `payments/webhook` hay action `PaymentsWebhook()`.
* **Command / Query:** Không tồn tại trong `Wallet.Application/Features/`.
* **Command / Query Handler:** Không tồn tại.
* **Thực thể & Bảng DB:** Không áp dụng (endpoint không được triển khai)
* **Typed HTTP Client (nếu có):** Không áp dụng
* **Thay thế:** `POST /api/v1/wallets/vnpay/ipn` $\rightarrow$ `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `VnPayIpn()` $\rightarrow$ `Wallet.Application/Features/VnPay/Commands/ProcessVnPayIpn/ProcessVnPayIpnCommandHandler.Handle()`. Xem `R180_POST_WALLETS_VNPAY_IPN.md`.

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
  "orderId": "uuid",
  "transactionId": "uuid",
  "amount": 480000,
  "status": "SUCCESS|FAILED",
  "paymentMethod": "VNPAY",
  "paidAt": "2026-10-26T00:00:00Z"
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
  "message": "Payment webhook processed successfully.",
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
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `404` | `ORDER_NOT_FOUND` | "Order not found." | Điều kiện nghiệp vụ đặc thù: ORDER_NOT_FOUND. |
| `400` | `INVALID_SIGNATURE` | "Invalid webhook signature." | Điều kiện nghiệp vụ đặc thù: INVALID_SIGNATURE. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `WALLET_NOT_FOUND` | "Wallet not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
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

- [ ] **1. Tầng Application:** Không có command/query nào được triển khai cho endpoint này.
- [ ] **2. Tầng Api:** Không có controller action nào được triển khai cho endpoint này.
- [ ] **3. Bắt lỗi & Validation:** Không áp dụng (endpoint không tồn tại).
- [ ] **4. Enum Mapping:** Không áp dụng (endpoint không tồn tại).
- [ ] **5. Kiểm thử tự động:** Không áp dụng (endpoint không tồn tại).
- [ ] **6. Định tuyến Gateway:** Không có route YARP cho `/api/v1/payments/webhook`.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Không áp dụng, tài liệu đã bị thay thế bởi `R180_POST_WALLETS_VNPAY_IPN.md`.

> **Trạng thái nghiệm thu:** `[ 🚫 SUPERSEDED (Không triển khai, thay thế bởi R180) ]`
