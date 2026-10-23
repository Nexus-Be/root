# 00 — KIẾN TRÚC TỔNG THỂ HỆ THỐNG (MASTER SYSTEM ARCHITECTURE)

Tài liệu này cung cấp sơ đồ kiến trúc mức cao (System Architecture), ranh giới miền (Domain-Driven Design Bounded Contexts) và nguyên lý vận hành cốt lõi của hệ sinh thái Microservices **Nexus**.

---

## 1. TỔNG QUAN HỆ THỐNG & SƠ ĐỒ CONTAINER (C4 MODEL)

```
[ Frontend: Web Next.js / Mobile App ]
                   │
                   ▼ (HTTP/REST: /api/v1/... - Port 8000)
       ┌────────────────────────┐
       │       ApiGateway       │ ──(RateLimit Cache)──▶ [ Redis : 6379 ]
       └────────────────────────┘
                   │
                   ├── (gRPC Channel - Protobuf v3 - Synchronous Query/Command)
                   ▼
  ┌───────────────┬─┴─────────────┬───────────────┬───────────────┐
  ▼               ▼               ▼               ▼               ▼
UserService    CatalogService  CommerceService  LogService     AuctionService ... (+ Fulfillment, Notification, Wallet)
(Port 8001)    (Port 8002)     (Port 8003)      (Port 8004)    (Port 8005)        (Ports 8006, 8007, 8008)
  │               │               │               │               │                  │
  ▼               ▼               ▼               ▼               ▼                  ▼
[User DB]     [Catalog DB]    [Commerce DB]   [Log DB]        [Auction DB]      [Fulfillment DB, Notification DB...]
(Port 5433)   (Port 5434)     (Port 5435)     (Port 5436)     (Port 5437)       (Ports 5438, 5439, 5440)
  │               │               │               │               │                  │
  └───────────────┴───────────────┼───────────────┴───────────────┴──────────────────┘
                                  ▼ (Async Event Bus / Saga Coordination)
                        [ RabbitMQ Event Bus : 5672 ]
                        (MassTransit 8.4.1 - Outbox / Inbox)
```

---

## 2. NGUYÊN LÝ THIẾT KẾ BẤT DI BẤT DỊCH (CORE PRINCIPLES)

1. **Database-Per-Service (Cô Lập Tuyệt Đối Cơ Sở Dữ Liệu)**:
   - Mỗi microservice sở hữu cơ sở dữ liệu vật lý riêng biệt (PostgreSQL độc lập qua port khác nhau).
   - Tuyệt đối **KHÔNG** truy cập trực tiếp DB của service khác (kể cả cross-query hay foreign key sang DB khác).
   - Mọi chia sẻ dữ liệu liên service bắt buộc phải qua **gRPC Call** (đồng bộ) hoặc **RabbitMQ Event** (bất đồng bộ).

2. **Edge API Gateway Mỏng (Thin Edge Reverse Proxy)**:
   - Gateway là cổng vào duy nhất cho mọi Client, chịu trách nhiệm xác thực JWT, phân quyền RBAC, Rate Limiting và chuyển đổi REST $\rightarrow$ gRPC.
   - Gateway **KHÔNG** chứa database nghiệp vụ, không chứa in-memory DB hay logic tính toán phức tạp.

3. **Hai Trục Giao Tiếp Song Song**:
   - **Đồng bộ (Synchronous Query/Command)**: Dùng **gRPC Protobuf v3** cho các tác vụ cần kết quả tức thì (xác thực token, kiểm tra số dư, đọc chi tiết sản phẩm).
   - **Bất đồng bộ (Asynchronous Event-Driven)**: Dùng **RabbitMQ + MassTransit 8.4.1** cho các sự kiện trạng thái thay đổi (`OrderCreated`, `InventoryReserved`, `PaymentCompleted`, `LogRecorded`).

4. **Quản Lý Giao Dịch Phân Tán Bằng Saga State Machine**:
   - Không sử dụng Distributed Transaction / 2-Phase Commit (2PC).
   - Sử dụng **Choreography/Orchestration Saga** với cơ chế Bù Trừ (Compensating Transactions) khi có bước thất bại (ví dụ: Trừ ví thất bại $\rightarrow$ Nhả kho đã giữ $\rightarrow$ Hủy đơn hàng).

---

## 3. RANH GIỚI MIỀN NGHIỆP VỤ (BOUNDED CONTEXTS)

| Bounded Context | Tên Service | Trách Nhiệm Trọng Tâm | Dữ Liệu Sở Hữu Độc Quyền |
|:---|:---|:---|:---|
| **Identity & Access Management** | `UserService` | Định danh người dùng, xác thực, cấp token JWT, phân vai trò, phê duyệt seller. | Users, Roles, Permissions, Seller Registrations. |
| **Product & Inventory Catalog** | `CatalogService` | Quản lý cây danh mục, thuộc tính sản phẩm, hình ảnh, quản lý kho ảo của seller. | Categories, Products, Seller Inventory. |
| **Ordering & Commerce** | `CommerceService` | Quản lý giỏ hàng tạm thời, tạo đơn hàng checkout, theo dõi trạng thái vòng đời đơn hàng. | Carts, CartItems, Orders, OrderLines. |
| **Online Bidding & Auction** | `AuctionService` | Phòng đấu giá trực tuyến, bước giá, quy tắc đặt giá, thời gian đếm ngược, xác định người thắng. | Auctions, Bids, AuctionParticipants. |
| **Physical Fulfillment & Logistics**| `FulfillmentService` | Kho vật lý lưu trữ thực tế, quản lý vận đơn, tính cước vận chuyển, theo dõi hành trình giao nhận. | Warehouses, PhysicalStock, Shipments, Carriers. |
| **Customer Notifications** | `NotificationService` | Đa kênh thông báo (In-app, Push, Email), lưu lịch sử thông báo, cấu hình tùy chọn người dùng. | Notifications, NotificationPreferences. |
| **Centralized Logging & System Auditing** | `LogService` | Thu thập nhật ký tập trung và lưu vết bất biến mọi thay đổi trong hệ thống. | Logs, LogEventTypes. |
| **Digital Wallet & Payments** | `WalletService` | Tài khoản ví điện tử khách hàng, nạp tiền, rút tiền về tài khoản ngân hàng, chuyển tiền nội bộ. | Wallets, WalletTransactions, BankAccounts. |
