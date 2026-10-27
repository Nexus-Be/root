# 02 — MA TRẬN GIAO TIẾP & ĐIỀU PHỐI SAGA (INTER-SERVICE COMMUNICATION)

> **Trạng thái triển khai (2026-10-27):** ✅ Đã chuyển dịch toàn diện sang **100% RESTful (JSON over HTTP)** cho toàn bộ giao tiếp đồng bộ từ Gateway $\rightarrow$ Backend Microservices và giữa các Microservices với nhau. **CẤM TUYỆT ĐỐI gRPC**. Giao tiếp sự kiện phân tán sử dụng **RabbitMQ MassTransit 8.3.0**.
> **Nguồn sự thật:** code 9 repo (`PLAN-20261027-1400-GLOBAL-RESTFUL-PIVOT-AND-GATEWAY-DECOUPLING.md`).
> **Cập nhật lần cuối:** 2026-10-27.

Tài liệu này xác định ranh giới giữa giao tiếp **đồng bộ (RESTful HTTP/JSON)** và **bất đồng bộ (RabbitMQ MassTransit)**, đồng thời mô tả chi tiết ma trận gọi liên service và luồng giao dịch phân tán **Checkout Saga**.

---

## 1. NGUYÊN TẮC LỰA CHỌN GIAO TIẾP

| Tiêu Chí | Giao Tiếp Đồng Bộ (RESTful HTTP/JSON) — DUY NHẤT | Giao Tiếp Bất Đồng Bộ (RabbitMQ) |
|:---|:---|:---|
| **Mục đích** | Truy vấn dữ liệu tức thì (Query) hoặc Command cần xác nhận ngay lập tức từ 1 service. | Thông báo trạng thái thay đổi (Event) hoặc kích hoạt quy trình phức tạp qua nhiều service (Saga). |
| **Giao thức** | HTTP/1.1 hoặc HTTP/2 (Keep-Alive Pooling) trên nền chuẩn JSON (`camelCase`). **CẤM gRPC**. | AMQP 0-9-1 qua thư viện **MassTransit 8.3.0**. |
| **Tính phụ thuộc** | Tight coupling tại thời điểm gọi (Caller đợi Callee phản hồi hoặc timeout). | Decoupled (Publisher phát event và tiếp tục, Subscribers nhận xử lý độc lập). |
| **Độ trễ** | Rất thấp (< 5-10ms trong mạng nội bộ Docker/VPS). | Bất đồng bộ (vài chục ms qua hàng đợi). |
| **Độ bền dữ liệu** | Phụ thuộc availability của callee (xử lý qua timeout / retry / circuit breaker). | Bền vững (Durable Queues, Message Persistence, Outbox/Inbox Pattern). |

---

## 2. MA TRẬN GIAO TIẾP LIÊN SERVICE (COMMUNICATION MATRIX)

| Nguồn Gọi (Caller) | Đích Đến (Callee) | Giao Thức | Tên Phương Thức / Route | Mục Đích Nghiệp Vụ | Trạng thái triển khai |
|:---|:---|:---:|:---|:---|:---|
| **ApiGateway** | `UserService` | REST | `/api/v1/auth/*`, `/api/v1/users/*`, `/api/v1/admin/users/*` | Quản lý người dùng, đăng ký, đăng nhập và hồ sơ | ✅ Gateway hỗ trợ Mock/Real qua `ForwardAsync` |
| **ApiGateway** | `CatalogService` | REST | `/api/v1/products/*`, `/api/v1/categories/*`, `/api/v1/inventory/*` | Truy vấn và cập nhật danh mục, sản phẩm, tồn kho | ✅ Catalog có 13 REST Controllers, Gateway hỗ trợ `ForwardAsync` |
| **ApiGateway** | `CommerceService` | REST | `/api/v1/cart/*`, `/api/v1/orders/*` | Thao tác giỏ hàng và đặt hàng | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `AuctionService` | REST | `/api/v1/auctions/*` | Tham gia và tạo phòng đấu giá | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `FulfillmentService`| REST | `/api/v1/shipments/*` | Tra cước và vận đơn | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `NotificationService`| REST | `/api/v1/notifications/*`, `/api/v1/notifications/email/*` | Quản lý thông báo người dùng, gửi email OTP/alert | ✅ Notification có `NotificationsController` & `EmailController`, Gateway hỗ trợ `ForwardAsync` |
| **ApiGateway** | `LogService` | REST | `/api/v1/logs/*`, `/api/v1/log/batch` | Ghi log, truy vấn nhật ký hệ thống | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `WalletService` | REST | `/api/v1/wallet/*` | Tra cứu số dư, nạp, rút và giao dịch ví | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **CommerceService**| RabbitMQ | Event | `OrderSubmittedEvent` | Bắn tin nhắn đơn hàng mới được tạo | ❌ 0 publisher, 0 consumer |
| `CatalogService` | RabbitMQ | Event | `StockReservedEvent` / `StockReservationFailedEvent` | Giữ kho ảo cho sản phẩm trong đơn | ❌ 0 publisher |
| `WalletService` | RabbitMQ | Event | `PaymentCompletedEvent` / `PaymentFailedEvent` | Trừ số dư tiền trong ví người mua | ❌ Contract có nhưng 0 lời gọi publish |
| `FulfillmentService`| RabbitMQ | Event | `ShipmentCreatedEvent` | Tạo phiếu xuất kho và đóng gói hàng | ❌ 0 publisher, 0 consumer |
| `NotificationService`| RabbitMQ | Consumer | Nghe mọi sự kiện trạng thái đơn, ví, đấu giá | Gửi email / push thông báo cho user | ⚠️ Có `SendOtpEmailConsumer` (1 event OTP từ User) |
| `LogService` | RabbitMQ | Consumer | Nghe toàn bộ Domain Events trên Event Bus | Ghi chép nhật ký hệ thống tập trung | ⚠️ `GlobalLogConsumer.cs` tồn tại |

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
