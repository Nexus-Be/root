# 02 — MA TRẬN GIAO TIẾP & ĐIỀU PHỐI SAGA (INTER-SERVICE COMMUNICATION)

Tài liệu này xác định ranh giới giữa giao tiếp **đồng bộ (gRPC)** và **bất đồng bộ (RabbitMQ MassTransit)**, đồng thời mô tả chi tiết luồng giao dịch phân tán **Checkout Saga**.

---

## 1. NGUYÊN TẮC LỰA CHỌN GIAO TIẾP

| Tiêu Chí | Giao Tiếp Đồng Bộ (gRPC) | Giao Tiếp Bất Đồng Bộ (RabbitMQ) |
|:---|:---|:---|
| **Mục đích** | Truy vấn dữ liệu tức thì (Query) hoặc Command cần xác nhận ngay lập tức từ 1 service. | Thông báo trạng thái thay đổi (Event) hoặc kích hoạt quy trình phức tạp qua nhiều service (Saga). |
| **Giao thức** | HTTP/2 trên nền Protobuf v3 (`Contracts/shop.proto`). | AMQP 0-9-1 qua thư viện **MassTransit 8.4.1**. |
| **Tính phụ thuộc** | Tight coupling tại thời điểm gọi (Caller phải đợi Callee phản hồi hoặc timeout). | Decoupled (Publisher phát event và tiếp tục, Subscribers nhận xử lý độc lập). |
| **Độ trễ** | Cực thấp (< 5ms trong mạng nội bộ). | Bất đồng bộ (vài chục ms qua hàng đợi). |
| **Độ bền dữ liệu** | Phụ thuộc availability của callee (xử lý qua timeout / retry). | Bền vững (Durable Queues, Message Persistence, Outbox/Inbox Pattern). |

---

## 2. MA TRẬN GIAO TIẾP LIÊN SERVICE (COMMUNICATION MATRIX)

| Nguồn Gọi (Caller) | Đích Đến (Callee) | Giao Thức | Tên Phương Thức / Event | Mục Đích Nghiệp Vụ |
|:---|:---|:---:|:---|:---|
| **ApiGateway** | `UserService` | gRPC | `Register`, `Login`, `GetProfile`, `CreateUser` | Quản lý người dùng và xác thực tài khoản |
| **ApiGateway** | `CatalogService` | gRPC | `ListProducts`, `GetProduct`, `AdjustInventory` | Truy vấn và cập nhật danh mục, sản phẩm |
| **ApiGateway** | `CommerceService` | gRPC | `GetCart`, `AddCartItem`, `CreateOrder` | Thao tác giỏ hàng và đặt hàng |
| **ApiGateway** | `AuctionService` | gRPC | `ListAuctions`, `CreateAuction`, `PlaceBid` | Tham gia và tạo phòng đấu giá |
| **ApiGateway** | `FulfillmentService`| gRPC | `CalculateShippingFee`, `GetShipmentTracking` | Tra cước và vận đơn |
| **ApiGateway** | `LogService` | gRPC | `QueryLogs`, `ListLogEventTypes` | Xem nhật ký hệ thống |
| **ApiGateway** | `WalletService` | gRPC | `GetWallet`, `Deposit`, `Withdraw`, `Transfer` | Tra cứu số dư và giao dịch ví |
| **CommerceService**| RabbitMQ | Event | `OrderSubmittedEvent` | Bắn tin nhắn đơn hàng mới được tạo |
| `CatalogService` | RabbitMQ | Event | `StockReservedEvent` / `StockReservationFailedEvent` | Giữ kho ảo cho sản phẩm trong đơn |
| `WalletService` | RabbitMQ | Event | `PaymentCompletedEvent` / `PaymentFailedEvent` | Trừ số dư tiền trong ví người mua |
| `FulfillmentService`| RabbitMQ | Event | `ShipmentCreatedEvent` | Tạo phiếu xuất kho và đóng gói hàng |
| `NotificationService`| RabbitMQ | Consumer | Nghe mọi sự kiện trạng thái đơn, ví, đấu giá | Gửi email / push thông báo cho user |
| `LogService` | RabbitMQ | Consumer | Nghe toàn bộ Domain Events trên Event Bus | Ghi chép nhật ký hệ thống tập trung |

---

## 3. ĐIỀU PHỐI GIAO DỊCH PHÂN TÁN: CHECKOUT SAGA

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

1. **Transactional Outbox Pattern**:
   - Mọi service khi ghi dữ liệu vào DB bắt buộc lưu Event vào bảng `OutboxMessage` trong cùng một Database Transaction.
   - Background worker của MassTransit định kỳ đọc bảng outbox và đẩy lên RabbitMQ $\rightarrow$ Đảm bảo không bao giờ bị mất event dù crash ứng dụng.
2. **Idempotent Consumer (Chống xử lý trùng)**:
   - Mọi event mang `MessageId` hoặc `CorrelationId`.
   - Consumer lưu `MessageId` vào bảng `InboxMessage`. Nếu event đến lần thứ 2 $\rightarrow$ Bỏ qua, không trừ tiền hay giữ kho 2 lần.
