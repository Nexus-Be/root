# [GET] /api/v1/wallets/me

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `Wallets`  
> **Mã tham chiếu Excel:** ``WAL-02``  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin ví và số dư khả dụng/bị khóa của cá nhân
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/wallets/me`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/me` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `Buyer`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `GetMyWallet()`
* **Query:** `Wallet.Application/Features/Wallets/Queries/GetMyWallet/GetMyWalletQuery.cs` $\rightarrow$ `GetMyWalletQuery`
* **Query Handler:** `Wallet.Application/Features/Wallets/Queries/GetMyWallet/GetMyWalletQueryHandler.cs` $\rightarrow$ `GetMyWalletQueryHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/Wallets/Queries/GetMyWallet/WalletResponse.cs` $\rightarrow$ `WalletResponse`
* **Command (khởi tạo ví):** `Wallet.Application/Features/Wallets/Commands/EnsureWallet/EnsureWalletCommand.cs` $\rightarrow$ `EnsureWalletCommand`
* **Command Handler (khởi tạo ví):** `Wallet.Application/Features/Wallets/Commands/EnsureWallet/EnsureWalletCommandHandler.cs` $\rightarrow$ `EnsureWalletCommandHandler.Handle()`
* **Thực thể & Bảng DB:** `Wallet.Domain/Entities/WalletAccount.cs` $\rightarrow$ Bảng `Wallets` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Handler inject trực tiếp `IWalletDbContext`, không dùng Repository)
* **Hành vi nghiệp vụ:** Query chỉ đọc (`AsNoTracking`). Nếu user chưa có ví, Query Handler gửi `EnsureWalletCommand` để tạo mới `WalletAccount` (`Balance = 0`, `LockedBalance = 0`, `Currency = Vnd`) kèm `AuditLog` (`AuditAction.WalletCreate`), rồi trả về kết quả của Command. Trạng thái được chuẩn hóa PascalCase ở biên API (`"ACTIVE"` $\rightarrow$ `"Active"`).

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
    "walletId": "uuid",
    "userId": "uuid",
    "balance": 1500000.0,
    "lockedBalance": 200000.0,
    "availableBalance": 1300000.0,
    "currency": "Vnd",
    "status": "Active",
    "updatedAt": "2026-10-26T00:00:00Z"
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
| `400` | `VAL_INVALID_ARGUMENT` | "User ID must be a valid UUID." | Phòng vệ tại `GetMyWalletQueryHandler`: `x-user-id` không parse được thành `Guid` khác rỗng (thực tế `TryGetUserId()` đã chặn trước đó với 401). |
| `401` | `UNAUTHORIZED` | "Authentication is required to access this resource." | `RequireRole` không tìm thấy danh tính hợp lệ trong claims hoặc header `x-user-id`. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

Không có `404 WALLET_NOT_FOUND`: endpoint tự tạo ví 0 đồng qua `EnsureWalletCommand`, nên mọi user hợp lệ đều nhận được ví.

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `currency` | `CurrencyCode` | `0` | `Vnd` | **Việt Nam Đồng**: Đơn vị tiền tệ mặc định của ví. Badge trung tính. |
| `currency` | `CurrencyCode` | `1` | `Usd` | **Đô la Mỹ**: Chỉ dùng khi ví được cấu hình đa tiền tệ. Badge trung tính. |
| `status` | `WalletAccount.Status` (`varchar(30)`) | Chuỗi `"ACTIVE"` (lưu dạng chuỗi) | `Active` | **Đang hoạt động**: Ví sẵn sàng giao dịch. Handler chuẩn hóa `"ACTIVE"` $
ightarrow$ `"Active"` tại biên API. Badge xanh lá (Success). |

> Ghi chú: `status` của `WalletAccount` đang lưu dạng chuỗi trong cột `varchar(30)`, khác với các enum nghiệp vụ khác lưu `integer`. Giá trị API luôn được chuẩn hóa PascalCase qua `StatusTextExtensions.ToApiStatus()`; Frontend không được kỳ vọng chuỗi `"ACTIVE"`.

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `GetMyWalletQuery.cs` (query read-only) + `EnsureWalletCommand.cs`/`EnsureWalletCommandHandler.cs` (tạo ví + audit) đã được triển khai hoàn chỉnh theo CQRS + MediatR.
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** `Guid.TryParse` trong Handler ném `ArgumentException` (`VAL_INVALID_ARGUMENT` 400), `WalletNotFoundException` (`WALLET_NOT_FOUND` 404) và `RequireRole` (`UNAUTHORIZED` 401) đều đi qua `GlobalExceptionHandlerMiddleware`.
- [x] **4. Enum Mapping:** `CurrencyCode` lưu integer trong DB và serialize chuỗi PascalCase ở API (`wallet.Currency.ToString()`).
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (`WalletUseCaseBehaviorTests.cs` - `GetWallet_Existing_ReturnsBalances`, `GetWallet_Missing_CreatesZeroBalanceWallet`; `WalletContractRegressionTests.cs` - `GetWallet_Missing_CreatesWalletWithPascalCaseStatusAndAudit`, `StatusText_NormalizesToPascalCase`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
