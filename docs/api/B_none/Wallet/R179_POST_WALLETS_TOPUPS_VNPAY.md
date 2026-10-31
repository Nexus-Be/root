# [POST] /api/v1/wallets/topups/vnpay

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-03``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tạo yêu cầu nạp tiền vào ví qua cổng VNPay và lấy URL thanh toán
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/wallets/topups/vnpay`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/topups/vnpay` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `TopupVnPay()`
* **Command:** `Wallet.Application/Features/Topups/Commands/TopupVnPay/TopupVnPayCommand.cs` $\rightarrow$ `TopupVnPayCommand`
* **Command Handler:** `Wallet.Application/Features/Topups/Commands/TopupVnPay/TopupVnPayCommandHandler.cs` $\rightarrow$ `TopupVnPayCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Topups/Commands/TopupVnPay/TopupVnPayCommand.cs` $\rightarrow$ `TopupResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletTopup.cs` $\rightarrow$ Bảng `WalletTopups`; `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/AuditLog.cs` $\rightarrow$ Bảng `AuditLogs`
* **Typed HTTP Client (nếu có):** `Wallet.Infrastructure/Payments/VnPayService.cs` (`IVnPayService.CreatePaymentUrl`) sinh URL thanh toán VNPay
* **Hành vi nghiệp vụ:** Handler tạo bản ghi `WalletTopup` trạng thái `Pending` và ghi `AuditLog` (`AuditAction.TopupRequest`) trong cùng transaction, sau đó trả HTTP `201 Created`.

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
  "amount": 500000,
  "bankCode": "NCB",
  "returnUrl": "https://shop.example.com/wallet/callback"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "transactionId": "uuid",
    "paymentUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=50000000...",
    "amount": 500000.0,
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
| `400` | `VAL_INVALID_INPUT` | "Deposit amount must be between 10,000 and 100,000,000 VND." | `Amount` vi phạm `[Range(10000, 100000000)]`, bắt bởi `ValidationBehavior` (`RequestValidationException`). |
| `400` | `VAL_INVALID_ARGUMENT` | "User ID must be a valid UUID." | `x-user-id` không parse được thành `Guid` khác rỗng. |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole` không tìm thấy danh tính hợp lệ. |
| `404` | `WALLET_NOT_FOUND` | "Wallet for user '{userId}' was not found." | User chưa từng gọi `GET /api/v1/wallets/me` để hệ thống tạo ví 0 đồng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `TopupStatus` | `0` | `Pending` | **Chờ thanh toán**: Đã tạo `WalletTopup` và trả URL VNPay. Badge vàng (Warning). |
| `status` | `TopupStatus` | `1` | `Success` | **Nạp thành công**: IPN xác nhận `vnp_ResponseCode = "00"` và tiền đã cộng vào ví. Badge xanh lá (Success). |
| `status` | `TopupStatus` | `2` | `Failed` | **Nạp thất bại**: VNPay trả mã lỗi hoặc giao dịch bị hủy. Badge đỏ (Danger). |
| `status` | `TopupStatus` | `3` | `Expired` | **Hết hạn thanh toán**: Quá thời gian giữ giao dịch. Badge xám (Muted). |
| `currency` | `CurrencyCode` | `0` | `Vnd` | **Việt Nam Đồng**: Đơn vị tiền tệ của ví. |
| `currency` | `CurrencyCode` | `1` | `Usd` | **Đô la Mỹ**: Chỉ dùng khi ví cấu hình đa tiền tệ. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `TopupVnPayCommand.cs` và `TopupVnPayCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không còn lớp feature service cũ).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `[Range(10000, 100000000)]` trên `Amount` chặn biên qua model binding (`VAL_INVALID_INPUT` 400); `WalletNotFoundException` (`WALLET_NOT_FOUND` 404) và `RequireRole` (`UNAUTHORIZED` 401) đi qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `TopupStatus` và `CurrencyCode` lưu integer trong DB, serialize chuỗi PascalCase ở API (`topup.Status.ToString()`, `wallet.Currency.ToString()`).
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `TopupVnPay_CreatesPendingTopupAndAudit`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
