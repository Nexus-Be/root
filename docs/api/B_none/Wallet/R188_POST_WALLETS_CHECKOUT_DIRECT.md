# [POST] /api/v1/wallets/checkout/direct

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Checkout`  
> **Mã tham chiếu Excel:** `WAL-10`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  
> **Trạng thái bảo mật (2026-10-31):** Internal API tạm khóa. Endpoint dùng route công khai, không yêu cầu `X-Internal-Service-Key`.  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** CommerceService gọi nội bộ để tạo giao dịch thanh toán trực tiếp cho một đơn hàng từ ví người mua; trả URL thanh toán của cổng được chọn và idempotent theo `orderId`.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/wallets/checkout/direct`
* **Quyền hạn truy cập (RBAC):** `ServiceCaller` — hiện không kiểm tra header nội bộ vì `InternalServiceAuthMiddleware` đang tắt. Route `/api/v1/wallets/checkout/direct` đi qua Gateway như API thường và cần được bảo vệ bằng xác thực thật trước khi dùng cho lưu lượng thật.
* **Yêu cầu Idempotency:** Có — khóa tự nhiên là `orderId`; nếu đã tồn tại `WalletTransaction` loại `DirectGatewayPayment` cùng `ReferenceId = orderId`, Handler trả lại giao dịch cũ thay vì tạo mới.
* **Danh tính người mua:** `x-user-id` do service gọi (Commerce) truyền vào; Handler ghi đè `UserId` của command bằng header này và không tin `userId` trong body.

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** Route `/api/v1/wallets/{**catch-all}` chuyển tiếp sang Wallet. Khối chặn path `/internal/*` tại `ClientContextMiddleware` đang bị comment.
* **Middleware bảo vệ:** Không áp dụng. `Wallet.Api/Middleware/InternalServiceAuthMiddleware.cs` chỉ còn file, chưa đăng ký pipeline.
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `CheckoutDirect()`
* **Command:** `Wallet.Application/Features/Checkout/Commands/CheckoutDirect/CheckoutDirectCommand.cs` $\rightarrow$ `CheckoutDirectCommand`
* **Command Handler:** `Wallet.Application/Features/Checkout/Commands/CheckoutDirect/CheckoutDirectCommandHandler.cs` $\rightarrow$ `CheckoutDirectCommandHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Checkout/Commands/CheckoutDirect/CheckoutDirectCommand.cs` $\rightarrow$ `DirectPaymentResponse`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets`; `Wallet.Domain/Entities/WalletTransaction.cs` $\rightarrow$ Bảng `WalletTransactions`
* **Typed HTTP Client (phía gọi):** CommerceService `WalletClient`, không kèm header nội bộ.
* **Hành vi nghiệp vụ:** Mở transaction, khóa ví người mua bằng `LockWalletByUserIdAsync` (`SELECT ... FOR UPDATE`). Nếu chưa có giao dịch cho `orderId`, tạo `WalletTransaction` `DirectGatewayPayment` với `Status = Pending` và **không trừ số dư** (tiền chỉ bị trừ khi cổng thanh toán xác nhận). Nếu đã có, kiểm tra khớp `WalletId`/`Amount`/`Note`/`Status` rồi trả lại `paymentUrl` cũ; lệch dữ liệu thì trả `BUSINESS_RULE_VIOLATION`.

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
  "x-user-id": "11111111-1111-1111-1111-111111111111"
}

Body:
{
  "orderId": "22222222-2222-2222-2222-222222222222",
  "amount": 480000,
  "gateway": "VNPAY",
  "bankCode": "NCB",
  "returnUrl": "https://nexus.example.com/api/v1/payments/return"
}
```

| Trường | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `orderId` | `string (UUID)` | Có | `[Required]`; Handler `Guid.TryParse` — sai định dạng trả `VAL_INVALID_ORDER_ID` (400). |
| `amount` | `decimal` | Có | `[Range(0.01, double.MaxValue)]` — phải lớn hơn 0. |
| `gateway` | `string` | Có | `[Required]`; tên cổng có trong `PaymentGateways` cấu hình. |
| `bankCode` | `string?` | Không | Mã ngân hàng tùy chọn của cổng thanh toán. |
| `returnUrl` | `string` | Có | `[Required]`; URL quay về sau khi thanh toán. |
| `x-user-id` (header) | `string (UUID)` | Có | Header do service gọi truyền; rỗng/sai định dạng trả `VAL_INVALID_USER_ID` (400). |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ
Endpoint liên service trả DTO trực tiếp cho service gọi (không đi qua `ResponseEnvelopeMiddleware` của Gateway):
```json
200 OK:
{
  "transactionId": "uuid",
  "orderId": "22222222-2222-2222-2222-222222222222",
  "amount": 480000,
  "paymentUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=48000000...",
  "status": "Pending",
  "createdAt": "2026-10-31T00:00:00Z"
}
```

### 4.2. Phản hồi Phân trang
*Không áp dụng.*

### 4.3. Phản hồi Không có Body (`204 NoContent`)
*Không áp dụng.*

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend không gọi endpoint này; CommerceService bắt buộc dựa vào `errorCode` để quyết định retry hay rollback đơn hàng.

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | `orderId`/`gateway`/`returnUrl` rỗng hoặc `amount <= 0` (DataAnnotations qua `ValidationBehavior`). |
| `400` | `VAL_INVALID_USER_ID` | "Missing or empty x-user-id header." | Header `x-user-id` rỗng hoặc không parse được thành `Guid`. |
| `400` | `VAL_INVALID_ORDER_ID` | "Order ID must be a valid UUID." | `orderId` không parse được thành `Guid` khác rỗng. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Order already has a direct payment transaction." | Đã có giao dịch `DirectGatewayPayment` cho `orderId` nhưng lệch ví/số tiền/trạng thái/ghi chú. |
| `400` | `BUSINESS_RULE_VIOLATION` | "Payment gateway is currently unavailable." | `IDirectPaymentGateway.CreatePaymentUrl` ném `InvalidOperationException` (cổng chưa cấu hình). |
| `404` | `WALLET_NOT_FOUND` | "Wallet for user '{userId}' was not found." | Người mua chưa có `WalletAccount`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `TransactionStatus` | `0` | `Pending` | **Chờ cổng thanh toán xác nhận**: Giao dịch đã tạo, chưa trừ số dư ví. |
| `status` | `TransactionStatus` | `1` | `Success` | **Thành công**: Cổng đã xác nhận thanh toán. |
| `status` | `TransactionStatus` | `2` | `Failed` | **Thất bại**: Cổng từ chối hoặc hết hạn. |
| `status` | `TransactionStatus` | `3` | `Cancelled` | **Đã hủy**: Đơn hàng hoặc giao dịch bị hủy. |
| `type` | `WalletTransactionType` | `10` | `DirectGatewayPayment` | **Thanh toán trực tiếp qua cổng**: Loại bút toán do endpoint này tạo. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `CheckoutDirectCommand.cs` và `CheckoutDirectCommandHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, inject trực tiếp `IWalletDbContext`).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`; route công khai `/api/v1/wallets/checkout/direct`, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `VAL_INVALID_USER_ID`, `VAL_INVALID_ORDER_ID`, `BUSINESS_RULE_VIOLATION`, `WALLET_NOT_FOUND` đều đi qua `GlobalExceptionHandlerMiddleware`. Không còn nhánh `FORBIDDEN` từ middleware nội bộ vì middleware đang tắt.
- [x] **4. Enum Mapping:** `TransactionStatus` và `WalletTransactionType` lưu integer trong DB, serialize PascalCase ở API (`Status.ToString()`), không còn `ToUpperInvariant()`.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (`WalletUseCaseBehaviorTests.cs` - `CheckoutDirect_ExistingPendingTransaction_IsIdempotent`, `CheckoutDirect_NewOrder_CreatesPendingTransaction`; `WalletContractRegressionTests.cs` - `Checkout_MalformedOrderId_Returns400ValidationError`, `Checkout_NewOrder_ReturnsPascalCaseStatus`).
- [x] **6. Định tuyến Gateway:** Route công khai `/api/v1/wallets/{**catch-all}` chuyển tiếp sang Wallet; không khai báo route YARP cho `/internal/*`. Khối chặn path nội bộ tại `ClientContextMiddleware` đang bị comment — đã đối chiếu `Gateway/appsettings.json`.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
