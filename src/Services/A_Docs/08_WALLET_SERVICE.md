# 08 — Wallet Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ quản lý ví điện tử, số dư, nạp tiền VNPay, chuyển tiền và thanh toán đơn hàng nội bộ.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Wallet & Financial Service (`Wallet`)
- **Vị trí thư mục:** `src/Services/Wallet/`
- **Solution:** `Wallet.sln`
- **Cổng lắng nghe HTTP REST:** `8008`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5440` (Container), Database: `wallet_db`
- **Giao tiếp liên dịch vụ nội bộ (Inbound):** Tiếp nhận yêu cầu thanh toán trực tiếp từ `CommerceService` qua `POST /api/v1/wallets/checkout/direct`, hiện không yêu cầu header nội bộ vì Internal API tạm khóa
- **Tích hợp cổng thanh toán:** VNPay Gateway (`TopupVnPayAsync`, webhook `ProcessVnPayIpnAsync`)
- **Kiểm thử tự động:** `Wallet.Tests` với **19 unit tests passed 100%**

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Wallet/
├── Wallet.Domain/                     # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── WalletAccount.cs           # Tài khoản ví người dùng (UserId, Balance, LockedBalance, Status)
│   │   ├── WalletTransaction.cs       # Bản ghi giao dịch biến động số dư (Type, Amount, BalanceBefore, BalanceAfter)
│   │   ├── WalletTopup.cs             # Giao dịch nạp tiền qua cổng thanh toán (VNPay, TransactionId, Status)
│   │   ├── WithdrawalRequest.cs       # Yêu cầu rút tiền về ngân hàng (Số tiền, Ngân hàng, Trạng thái duyệt)
│   │   ├── BankAccount.cs             # Tài khoản ngân hàng liên kết của người dùng
│   │   ├── DirectPaymentOrder.cs      # Lịch sử đơn hàng thanh toán trực tiếp từ ví
│   │   ├── VnpayIpnLog.cs             # Nhật ký nhận phản hồi callback IPN từ VNPay
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 7 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── CurrencyCode.cs            # VND, USD
│   │   ├── WalletTransactionType.cs   # Topup, Withdrawal, TransferIn, TransferOut, OrderPayment, OrderRefund
│   │   ├── TransactionStatus.cs       # Pending, Success, Failed, Cancelled
│   │   ├── TopupStatus.cs             # Pending, Completed, Failed, Expired
│   │   ├── WithdrawalStatus.cs        # PendingApproval, Approved, Rejected, Processing, Completed
│   │   ├── IpnProcessingStatus.cs     # Received, Processed, SignatureInvalid, DuplicateIgnored
│   │   └── AuditAction.cs             # Insert, Update, Delete
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Wallet.Application/                # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/Extensions/EnumExtensions.cs # Parse Enum an toàn
│   ├── Interfaces/
│   │   ├── IWalletDbContext.cs        # Giao diện DbContext wallet_db
│   │   ├── IVnPayService.cs           # Giao diện sinh URL thanh toán VNPay và kiểm tra chữ ký
│   │   └── IDirectPaymentGateway.cs   # Hợp đồng cổng thanh toán trực tiếp
│   ├── Services/
│   │   ├── Wallet/                    # Tính năng Nghiệp Vụ Ví Người Dùng
│   │   │   ├── IWalletService.cs      # Hợp đồng xem số dư, nạp, rút, chuyển và checkout trực tiếp
│   │   │   ├── WalletService.cs       # Triển khai trừ tiền ví có kiểm tra số dư và ghi sổ giao dịch
│   │   │   ├── WalletRequests.cs      # TopupVnPayRequest, WithdrawalRequest, TransferRequest, DirectPaymentRequest
│   │   │   └── WalletResponses.cs     # WalletResponse, TopupResponse, TransferResponse, DirectPaymentResponse
│   │   └── Admin/                     # Tính năng Quản Trị Ví
│   │       ├── IAdminWalletService.cs # Duyệt/từ chối rút tiền, điều chỉnh số dư
│   │       ├── AdminWalletService.cs  # Triển khai nghiệp vụ admin có ghi audit log
│   │       ├── AdminWalletRequests.cs # ProcessWithdrawalRequest, BalanceAdjustmentRequest
│   │       └── AdminWalletResponses.cs# ProcessWithdrawalResponse, BalanceAdjustmentResponse
│   └── DependencyInjection.cs         # Đăng ký dịch vụ tầng Application
│
├── Wallet.Infrastructure/             # 3. TẦNG HẠ TẦNG (Persistence & VNPay Gateway)
│   ├── Payments/
│   │   ├── VnPayService.cs            # Triển khai sinh chuỗi băm HMAC-SHA512 và query string VNPay
│   │   └── ConfiguredDirectPaymentGateway.cs # Cổng thanh toán trực tiếp cấu hình sẵn
│   ├── Persistence/
│   │   ├── WalletDbContext.cs         # Triển khai EF Core DbContext
│   │   ├── Configurations/            # 8 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030055807_InitialCreate)
│   │   └── Seeds/WalletSeedData.cs    # Dữ liệu tài khoản ví mẫu
│   └── DependencyInjection.cs         # Đăng ký WalletDbContext và VnPayService
│
└── Wallet.Api/                        # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   ├── WalletsController.cs   # [Route("api/v1/wallets")]
    │   │   │   # GET  /me             (Xem số dư ví và trạng thái tài khoản)
    │   │   │   # POST /topups/vnpay   (Tạo URL giao dịch nạp tiền qua VNPay)
    │   │   │   # POST /withdrawals    (Yêu cầu rút tiền về tài khoản ngân hàng)
    │   │   │   # POST /transfers      (Chuyển tiền sang ví người dùng khác)
    │   │   │   # GET  /transactions   (Lịch sử biến động số dư có phân trang)
    │   │   │   # POST /vnpay/ipn      (Xử lý webhook IPN tự động từ VNPay)
    │   │   └── AdminWalletsController.cs # [Route("api/v1/admin/wallets")]
    │   │       # PATCH /withdrawals/{id:guid} (Quản trị viên duyệt hoặc từ chối rút tiền)
    │   │       # POST  /{walletId:guid}/adjustments (Điều chỉnh số dư ví thủ công)
    │           # POST /checkout/direct (Trừ tiền ví thanh toán đơn hàng từ CommerceService)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Chưa đăng ký: Internal API tạm khóa
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Quy chuẩn 100% Số Nhiều:** Tuyệt đối sử dụng route collections số nhiều `/api/v1/wallets`, `/api/v1/wallets/transactions`, `/api/v1/admin/wallets`.
2. **Không Repository Pattern:** Inject trực tiếp `IWalletDbContext` vào `WalletService` và `AdminWalletService`.
3. **Cấm Để Số Dư Âm (Zero Negative Balance):** Mọi thao tác rút tiền, chuyển tiền hoặc trừ tiền thanh toán đơn hàng bắt buộc kiểm tra `Balance >= Amount`. Trường hợp số dư không đủ phải lập tức ném ngoại lệ với mã lỗi `INSUFFICIENT_BALANCE`.
4. **Trạng Thái Public API và Internal API (Internal API tạm khóa từ 2026-10-31):**
   - Xem số dư, nạp tiền VNPay, rút tiền và `checkout/direct` đều đặt trong `Controllers/Public/WalletsController.cs`.
   - Không còn `Controllers/Internal/` và không yêu cầu header `X-Internal-Service-Key`, vì `InternalServiceAuthMiddleware` chưa đăng ký.
   - Hệ quả cần kiểm soát: `POST /api/v1/wallets/checkout/direct` hiện đi qua Gateway như API thường. Phải bổ sung xác thực thật trước khi dùng cho lưu lượng thật.
5. **Độ Chính Xác Tiền Tệ (Precision 18,2):** Toàn bộ trường số tiền `Amount`, `Balance`, `LockedBalance` đều định dạng kiểu `decimal(18, 2)` trong PostgreSQL.
