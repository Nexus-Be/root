# 03 — Commerce Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ thương mại điện tử, giỏ hàng và đơn hàng.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Commerce Service (`Commerce`)
- **Vị trí thư mục:** `src/Services/Commerce/`
- **Solution:** `Commerce.sln`
- **Cổng lắng nghe HTTP REST:** `8003`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5435` (Container), Database: `commerce_db`
- **Giao tiếp liên dịch vụ:** Typed HTTP Client gọi sang `WalletService` (`POST /api/v1/internal/wallets/checkout/direct`) để thực hiện trừ tiền thanh toán đơn hàng trực tiếp
- **Bảo vệ quyền sở hữu:** Bắt buộc kiểm tra `currentUserId == buyerId` hoặc vai trò `admin`/`staff`

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Commerce/
├── Commerce.Domain/                   # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── Cart.cs                    # Giỏ hàng đang hoạt động của người mua
│   │   ├── CartItem.cs                # Mặt hàng trong giỏ (SKU, số lượng, giá tại thời điểm thêm)
│   │   ├── Order.cs                   # Đơn hàng tổng thể (Master Order)
│   │   ├── SubOrder.cs                # Đơn hàng phân tách theo từng Shop/Seller
│   │   ├── SubOrderItem.cs            # Chi tiết từng mặt hàng trong đơn hàng con
│   │   ├── OrderInvoice.cs            # Hóa đơn thanh toán đơn hàng
│   │   ├── OrderStatusHistory.cs      # Lịch sử biến động trạng thái đơn hàng
│   │   ├── OrderRefund.cs             # Yêu cầu và giao dịch hoàn tiền
│   │   ├── OrderCancellation.cs       # Ghi nhận lý do hủy đơn hàng
│   │   ├── AuctionOrder.cs            # Đơn hàng xuất phát từ phiên thắng đấu giá
│   │   ├── DiscountCode.cs            # Mã giảm giá (Voucher)
│   │   ├── DiscountCodeScope.cs       # Phạm vi áp dụng giảm giá (Toàn sàn, Shop, Sản phẩm)
│   │   ├── DiscountCodeUsage.cs       # Lịch sử sử dụng mã giảm giá của người dùng
│   │   ├── DailyOrderSequence.cs      # Bộ đếm sinh mã số đơn hàng tự tăng trong ngày
│   │   ├── SystemSetting.cs           # Cấu hình phí sàn và thời hạn thanh toán
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 18 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── CartStatus.cs              # Active, ConvertedToOrder, Abandoned
│   │   ├── OrderStatus.cs             # PendingPayment, Processing, Completed, Cancelled
│   │   ├── SubOrderStatus.cs          # Pending, Confirmed, Shipped, Delivered, Refunded
│   │   ├── PaymentMethod.cs           # Wallet, VnPay, Cod
│   │   ├── OrderActorRole.cs          # Buyer, Seller, Staff, System
│   │   ├── RefundStatus.cs            # Requested, Approved, Rejected, Processed
│   │   ├── RefundType.cs              # Full, Partial
│   │   ├── InvoiceStatus.cs           # Issued, Paid, Cancelled
│   │   ├── DiscountType.cs            # Percentage, FixedAmount
│   │   ├── DiscountScopeType.cs       # Global, Shop, Product
│   │   ├── DiscountStatus.cs          # Active, Inactive, Expired
│   │   ├── SequenceType.cs            # Order, Invoice, SubOrder
│   │   ├── CancellationReasonCode.cs  # BuyerChangedMind, OutOfStock, PaymentTimeout
│   │   └── AuditAction.cs             # Insert, Update, Delete
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Commerce.Application/              # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/Extensions/EnumExtensions.cs # Parse Enum an toàn
│   ├── Interfaces/
│   │   ├── ICommerceDbContext.cs      # Giao diện DbContext commerce_db
│   │   ├── IWalletClient.cs           # Hợp đồng gọi sang Wallet Service thanh toán
│   │   └── ICatalogClient.cs          # Hợp đồng gọi sang Catalog Service kiểm tra sản phẩm
│   ├── Services/
│   │   ├── Cart/                      # Tính năng Giỏ Hàng Mua Sắm
│   │   │   ├── ICartService.cs, CartService.cs, CartRequests.cs, CartResponses.cs, CartDtos.cs
│   │   └── Order/                     # Tính năng Quản Lý Đơn Hàng
│   │       ├── IOrderService.cs, OrderService.cs, OrderRequests.cs, OrderResponses.cs, OrderDtos.cs
│   └── DependencyInjection.cs         # Đăng ký CartService và OrderService
│
├── Commerce.Infrastructure/           # 3. TẦNG HẠ TẦNG (Persistence & Typed HTTP Client)
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Triển khai EF Core DbContext
│   │   ├── Configurations/            # 15 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054355_InitialCreate)
│   │   └── Seeds/CommerceSeedData.cs  # Dữ liệu khởi tạo đơn hàng và giỏ hàng mẫu
│   ├── Services/
│   │   ├── Common/InternalServiceAuthHandler.cs # Tự động tiêm X-Internal-Service-Key
│   │   ├── Wallet/WalletClient.cs     # Gọi POST /api/v1/internal/wallets/checkout/direct
│   │   └── Catalog/CatalogClient.cs   # Gọi sang Catalog Service
│   └── DependencyInjection.cs         # Đăng ký DbContext và Typed HttpClients
│
└── Commerce.Api/                      # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   ├── CartsController.cs     # /api/v1/carts (lấy giỏ hàng active)
    │   │   └── OrdersController.cs    # /api/v1/orders (chi tiết đơn, danh sách theo buyer)
    │   └── Internal/                  # Controllers nội bộ liên service
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Bảo vệ /internal/* bằng secret key
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Bảo vệ quyền sở hữu tài nguyên tuyệt đối (Resource Ownership):**
   - Trong `CartsController.cs`: Lấy `currentUserId = HttpContext.GetUserId()`. Cấm đọc giỏ hàng của người khác nếu không có quyền `admin` hoặc `staff`.
   - Trong `OrdersController.cs`: Kiểm tra `order.BuyerId == currentUserId`. Nếu không khớp, trả về HTTP 403 `FORBIDDEN`.
2. **Quy chuẩn 100% Số Nhiều:** Tuyệt đối dùng `/api/v1/carts`, `/api/v1/orders`, `/api/v1/sub-orders`, `/api/v1/checkouts`. Cấm dùng route số ít `/cart` hay `/order`.
3. **Thanh toán đồng bộ qua REST:** Bãi bỏ Saga state machine và RabbitMQ. `WalletClient` gọi trực tiếp endpoint nội bộ `POST /api/v1/internal/wallets/checkout/direct` kèm header `X-Internal-Service-Key` và `Idempotency-Key`.
4. **Không Repository Pattern:** Inject trực tiếp `ICommerceDbContext` vào `OrderService` và `CartService`.
