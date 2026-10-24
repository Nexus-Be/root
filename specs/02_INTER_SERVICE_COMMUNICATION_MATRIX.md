# 02 — MA TRẬN GIAO TIẾP & ĐIỀU PHỐI SAGA (INTER-SERVICE COMMUNICATION)

> **Trạng thái triển khai (2026-10-24):** ❌ Phần lớn là đặc tả. Thực tế: **1/8** service có gRPC client ở Gateway, **3/8** service có gRPC server, **1 đường publish còn sống** trên toàn hệ thống (User → Notification; 4 lời gọi `Publish` trong Wallet nằm trong consumer không bao giờ chạy), **0** Saga/StateMachine.
> **Nguồn sự thật:** code 9 repo. Báo cáo kiểm chứng: `docs/plans/audit/ROOT_CONTRACTS_AUDIT.md`, `ROOT_SPECS_AUDIT.md`.
> **Cập nhật lần cuối:** 2026-10-24.

Tài liệu này xác định ranh giới giữa giao tiếp **đồng bộ (gRPC)** và **bất đồng bộ (RabbitMQ MassTransit)**, đồng thời mô tả chi tiết luồng giao dịch phân tán **Checkout Saga**.

---

## 1. NGUYÊN TẮC LỰA CHỌN GIAO TIẾP

| Tiêu Chí | Giao Tiếp Đồng Bộ (gRPC) | Giao Tiếp Bất Đồng Bộ (RabbitMQ) |
|:---|:---|:---|
| **Mục đích** | Truy vấn dữ liệu tức thì (Query) hoặc Command cần xác nhận ngay lập tức từ 1 service. | Thông báo trạng thái thay đổi (Event) hoặc kích hoạt quy trình phức tạp qua nhiều service (Saga). |
| **Giao thức** | HTTP/2 trên nền Protobuf v3 (`Contracts/shop.proto`). | AMQP 0-9-1 qua thư viện **MassTransit 8.3.0** (thực tế trong `*.csproj`; tài liệu cũ ghi 8.4.1 là **sai**). |
| **Tính phụ thuộc** | Tight coupling tại thời điểm gọi (Caller phải đợi Callee phản hồi hoặc timeout). | Decoupled (Publisher phát event và tiếp tục, Subscribers nhận xử lý độc lập). |
| **Độ trễ** | Cực thấp (< 5ms trong mạng nội bộ). | Bất đồng bộ (vài chục ms qua hàng đợi). |
| **Độ bền dữ liệu** | Phụ thuộc availability của callee (xử lý qua timeout / retry). | Bền vững (Durable Queues, Message Persistence, Outbox/Inbox Pattern). |

---

## 2. MA TRẬN GIAO TIẾP LIÊN SERVICE (COMMUNICATION MATRIX)

| Nguồn Gọi (Caller) | Đích Đến (Callee) | Giao Thức | Tên Phương Thức / Event | Mục Đích Nghiệp Vụ | Trạng thái (2026-10-24) |
|:---|:---|:---:|:---|:---|:---|
| **ApiGateway** | `UserService` | gRPC | `Register`, `Login`, `GetProfile`, `CreateUser` | Quản lý người dùng và xác thực tài khoản | ⚠️ 1 client `users` (`Extensions/GrpcClientsExtension.cs:12`). Thật: `Register`/`VerifyOtp`/`ResendOtp`/`GetProfile` ✅; `Login` ❌ server không override (`UsersGrpcService.cs`) ⇒ `UNIMPLEMENTED`; `CreateUser` ❌ không có trong proto Gateway |
| **ApiGateway** | `CatalogService` | gRPC | `ListProducts`, `GetProduct`, `AdjustInventory` | Truy vấn và cập nhật danh mục, sản phẩm | ❌ 0 gRPC — Catalog chỉ có REST mock (`Catalog.Api/Controllers/*`), Gateway chưa có client `catalog` |
| **ApiGateway** | `CommerceService` | gRPC | `GetCart`, `AddCartItem`, `CreateOrder` | Thao tác giỏ hàng và đặt hàng | ❌ 0 gRPC (Commerce khai h2c nhưng 0 service map) |
| **ApiGateway** | `AuctionService` | gRPC | `ListAuctions`, `CreateAuction`, `PlaceBid` | Tham gia và tạo phòng đấu giá | ❌ 0 gRPC |
| **ApiGateway** | `FulfillmentService`| gRPC | `CalculateShippingFee`, `GetShipmentTracking` | Tra cước và vận đơn | ❌ 0 gRPC |
| **ApiGateway** | `LogService` | gRPC | `QueryLogs`, `ListLogEventTypes` | Xem nhật ký hệ thống | ⚠️ Log có server 4/4 rpc (`Log.Api/Program.cs:47`) nhưng Gateway **không** có client `log` ⇒ chưa gọi được |
| **ApiGateway** | `WalletService` | gRPC | `GetWallet`, `Deposit`, `Withdraw`, `Transfer` | Tra cứu số dư và giao dịch ví | ⚠️ Wallet có server 5/5 rpc (`Wallet.Api/Program.cs:47`) nhưng Gateway **không** có client `wallet` ⇒ chưa gọi được |
| **CommerceService**| RabbitMQ | Event | `OrderSubmittedEvent` | Bắn tin nhắn đơn hàng mới được tạo | ❌ 0 publisher, 0 consumer |
| `CatalogService` | RabbitMQ | Event | `StockReservedEvent` / `StockReservationFailedEvent` | Giữ kho ảo cho sản phẩm trong đơn | ❌ 0 publisher. Chỉ có consumer `Wallet.Application/Consumers/StockReservedConsumer.cs:13` chờ event không bao giờ tới |
| `WalletService` | RabbitMQ | Event | `PaymentCompletedEvent` / `PaymentFailedEvent` | Trừ số dư tiền trong ví người mua | ❌ Contract có (`Wallet.Domain/Events/WalletEvents.cs`) nhưng **0 lời gọi publish** |
| `FulfillmentService`| RabbitMQ | Event | `ShipmentCreatedEvent` | Tạo phiếu xuất kho và đóng gói hàng | ❌ 0 publisher, 0 consumer |
| `NotificationService`| RabbitMQ | Consumer | Nghe mọi sự kiện trạng thái đơn, ví, đấu giá | Gửi email / push thông báo cho user | ⚠️ Chỉ có `SendOtpEmailConsumer` (1 event OTP từ User), không phải event đơn hàng/ví/đấu giá |
| `LogService` | RabbitMQ | Consumer | Nghe toàn bộ Domain Events trên Event Bus | Ghi chép nhật ký hệ thống tập trung | ⚠️ `GlobalLogConsumer.cs:10` tồn tại nhưng `ILogEventOccurred` có **0 publisher** trong 9 repo |

---

## 3. ĐIỀU PHỐI GIAO DỊCH PHÂN TÁN: CHECKOUT SAGA

> **Trạng thái (2026-10-24): ❌ CHƯA TRIỂN KHAI.** Không tồn tại `StateMachine`, `SagaState`, `MassTransitStateMachine` nào trong 9 repo (grep `StateMachine|SagaState|MassTransitStateMachine` = 0 hit). Toàn bộ sơ đồ dưới đây là **đặc tả mục tiêu**, không phải mô tả hệ thống đang chạy. Sáu event trong sơ đồ (`OrderSubmittedEvent`, `StockReservedEvent`, `StockReservationFailedEvent`, `PaymentCompletedEvent`, `PaymentFailedEvent`, `ShipmentCreatedEvent`) **không có publisher** nào trong code.

Quy trình đặt hàng nhiều bước được điều phối bởi **Commerce Saga State Machine** với cơ chế Bù Trừ (Compensating Transactions):

```
[ Khách hàng đặt hàng ]
       │
       ▼ (1) POST /api/v1/commerce/orders
[ CommerceService ] ──▶ Tạo đơn trạng thái: PENDING
       │
       ▼ (2) Bắn OrderSubmittedEvent lên RabbitMQ
┌─────────────────────────────────────────────────────────────┐
│ (3) CatalogService lắng nghe:                               │
│     - Kiểm tra tồn kho ảo của các sản phẩm trong đơn.       │
│     - NẾU ĐỦ: Giữ hàng ──▶ Bắn StockReservedEvent           │
│     - NẾU THIẾU: ────────▶ Bắn StockReservationFailedEvent  │
└─────────────────────────────────────────────────────────────┘
       │
       ├──[Nếu StockReservationFailed] ──▶ CommerceService đổi trạng thái: CANCELLED (Lý do: Hết hàng).
       │
       ▼ (4) [Nếu StockReserved] ──▶ WalletService lắng nghe:
┌─────────────────────────────────────────────────────────────┐
│     - Kiểm tra số dư ví của khách hàng.                     │
│     - NẾU ĐỦ: Trừ tiền ví ──▶ Bắn PaymentCompletedEvent     │
│     - NẾU THIẾU: ───────────▶ Bắn PaymentFailedEvent        │
└─────────────────────────────────────────────────────────────┘
       │
       ├──[Nếu PaymentCompleted] ─────────────────────────────┐
       │   - CommerceService đổi trạng thái: CONFIRMED / PAID │
       │   - FulfillmentService tạo vận đơn: PREPARING        │
       │   - NotificationService gửi thông báo: Đặt hàng ok   │
       │                                                      │
       └──[NẾU BÙ TRỪ: PaymentFailed - Không đủ tiền] ────────┘
           │
           ├── (A) CommerceService đổi trạng thái: CANCELLED (Lý do: Thanh toán thất bại).
           └── (B) CatalogService lắng nghe PaymentFailed: Nhả lại kho ảo đã giữ (ReleaseStock).
```

---

## 4. QUY TẮC ĐẢM BẢO TÍNH TOÀN VẸN VÀ CHỐNG TRÙNG LẶP (IDEMPOTENCY)

> **Trạng thái (2026-10-24):** ⚠️ Một phần — Outbox/Inbox đã bật ở 8/8 service (`AppDbContext` có `OutboxMessage`/`InboxState`, DI gọi `AddEntityFrameworkOutbox`) nhưng **chỉ 1 service có message thật để đẩy** (User). 7 service còn lại có hạ tầng outbox rỗng. Chưa service nào cấu hình `UseMessageRetry`/error queue.

1. **Transactional Outbox Pattern**:
   - Mọi service khi ghi dữ liệu vào DB bắt buộc lưu Event vào bảng `OutboxMessage` trong cùng một Database Transaction.
   - Background worker của MassTransit định kỳ đọc bảng outbox và đẩy lên RabbitMQ $\rightarrow$ Đảm bảo không bao giờ bị mất event dù crash ứng dụng.
2. **Idempotent Consumer (Chống xử lý trùng)**:
   - Mọi event mang `MessageId` hoặc `CorrelationId`.
   - Consumer lưu `MessageId` vào bảng `InboxMessage`. Nếu event đến lần thứ 2 $\rightarrow$ Bỏ qua, không trừ tiền hay giữ kho 2 lần.
