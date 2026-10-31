# 00 — KIẾN TRÚC TỔNG THỂ HỆ THỐNG (MASTER SYSTEM ARCHITECTURE)

> **Trạng thái triển khai (2026-10-30):** ✅ Đã chuyển dịch toàn diện sang **100% RESTful HTTP/JSON** cho toàn bộ giao tiếp đồng bộ từ Gateway $\rightarrow$ Backend Microservices và giữa các Microservices với nhau. **CẤM TUYỆT ĐỐI gRPC**. Đã loại bỏ hoàn toàn RabbitMQ, MassTransit, Saga và Outbox/Inbox để tối ưu hiệu năng và độ ổn định.
> **Nguồn sự thật:** code và cấu hình Gateway/Microservices (`PLAN-20261030-0335-DECOMMISSION-SAGA-RABBITMQ-AND-OUTBOX-INBOX.md`).
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này cung cấp sơ đồ kiến trúc mức cao (System Architecture), ranh giới miền (Domain-Driven Design Bounded Contexts) và nguyên lý vận hành cốt lõi của hệ sinh thái Microservices **Nexus**.

---

## 1. TỔNG QUAN HỆ THỐNG & SƠ ĐỒ CONTAINER (C4 MODEL)

```
[ Frontend: Web Next.js / Mobile App ]
                   │
                   ▼ (HTTP/REST: /api/v1/... - Port 8080)
       ┌────────────────────────────────────────────────────────┐
       │   Gateway (Microsoft YARP Reverse Proxy - Port 8080)   │ ──(RateLimit Cache)──▶ [ Redis : 6379 ]
       └────────────────────────────────────────────────────────┘
                   │
                   ├── (RESTful HTTP/JSON Downstream - Synchronous Query/Command — CẤM gRPC)
                   ▼
  ┌───────────────┬─┴─────────────┬───────────────┬───────────────┬───────────────┐
  ▼               ▼               ▼               ▼               ▼               ▼
UserService    CatalogService  CommerceService  LogService     AuctionService  Fulfillment, Notification, Wallet, CheckHeal
(Port 8001)    (Port 8002)     (Port 8003)      (Port 8004)    (Port 8005)     (Ports 8006, 8007, 8008, 8009)
  │               │               │               │               │               │
  ▼               ▼               ▼               ▼               ▼               ▼
[User DB]     [Catalog DB]    [Commerce DB]   [Log DB]        [Auction DB]    [Fulfillment, Notification, Wallet DBs...]
(Port 5433)   (Port 5434)     (Port 5435)     (Port 5436)     (Port 5437)     (Ports 5438, 5439, 5440)
```

> **Đặc tả bất biến kiến trúc chi tiết:** Xem `specs/06_ARCHITECTURAL_INVARIANTS_AND_CONTRACT_SPECIFICATION.md` về Responsibility Boundary, Header Trust Matrix, và Response Envelope Contract.

---

## 2. NGUYÊN LÝ THIẾT KẾ BẤT DI BẤT DỊCH (CORE PRINCIPLES)

1. **Database-Per-Service (Cô Lập Tuyệt Đối Cơ Sở Dữ Liệu)**:
   - Mỗi microservice sở hữu cơ sở dữ liệu vật lý riêng biệt (PostgreSQL độc lập qua port khác nhau).
   - Tuyệt đối **KHÔNG** truy cập trực tiếp DB của service khác (kể cả cross-query hay foreign key sang DB khác).
   - Mọi chia sẻ dữ liệu liên service bắt buộc phải qua **REST API Call** (đồng bộ qua HttpClient / REST client).

2. **Edge API Gateway Mỏng (Thin Edge Reverse Proxy - YARP 2.3.0)**:
   - Gateway là cổng vào duy nhất cho mọi Client, chịu trách nhiệm xác thực JWT tại biên, Anti-Spoofing, Rate Limiting, Identity Propagation, đóng gói phong bì tự động và chuyển tiếp REST streaming downstream sang các backend microservices qua HTTP/JSON.
   - Gateway **KHÔNG** chứa database nghiệp vụ, không chứa in-memory DB hay logic tính toán phức tạp.

3. **Chuẩn Giao Tiếp 100% RESTful HTTP/JSON (CẤM gRPC & BÃI BỎ MESSAGE BROKER)**:
   - Toàn bộ giao tiếp giữa API Gateway $\rightarrow$ Microservices và giữa các Microservices với nhau sử dụng **RESTful Web API** (JSON qua HTTP/1.1 hoặc HTTP/2).
   - Cấm gRPC cho các dịch vụ đồng bộ.
   - Bãi bỏ RabbitMQ message broker và MassTransit; các tương tác phụ trợ (như gửi OTP email từ User sang Notification) được thực hiện trực tiếp qua REST endpoint nội bộ (`POST /api/v1/internal/notifications/email/otp`).

4. **Đơn Giản Hóa Luồng Nghiệp Vụ Liên Dịch Vụ**:
   - Loại bỏ cơ chế Saga State Machine phức tạp và Transactional Outbox/Inbox tables.
   - Các thao tác liên service được thiết kế theo hướng idempotent REST calls hoặc direct downstream invocations có timeout và retry an toàn.

5. **Chuẩn Hóa Cấu Trúc Toàn Bộ Microservices (`specs/01_UNIFIED_MICROSERVICE_ARCHITECTURE_BLUEPRINT.md`)**:
   - Toàn bộ 8 microservices backend bắt buộc tuân theo kiến trúc 4 tầng chuẩn hóa:
   - **Feature Co-location**: Mọi use case đồng bộ đặt tại `{Service}.Application/Services/{Feature}/` gồm `I{Feature}Service.cs`, `{Feature}Service.cs`, `{Feature}Requests.cs`, `{Feature}Responses.cs`.
   - **No-Repository Pattern**: `DbContext` được inject trực tiếp trong tầng Application qua `I{Service}DbContext`.
   - **1-to-1 Controller**: Mỗi Feature folder tương ứng duy nhất một thin controller tại `{Service}.Api/Controllers/{Feature}Controller.cs`.

---

## 3. RANH GIỚI MIỀN NGHIỆP VỤ (BOUNDED CONTEXTS)

| Bounded Context | Tên Service | Trách Nhiệm Trọng Tâm | Dữ Liệu Sở Hữu Độc Quyền |
|:---|:---|:---|:---|
| **Identity & Access Management** | `UserService` | Định danh người dùng, xác thực, cấp token JWT, phân vai trò, phê duyệt seller. | Users, Roles, Permissions, Seller Registrations. |
| **Product & Inventory Catalog** | `CatalogService` | Quản lý cây danh mục, thuộc tính sản phẩm, hình ảnh, quản lý kho ảo của seller. | Categories, Products, Seller Inventory. |
| **Ordering & Commerce** | `CommerceService` | Quản lý giỏ hàng tạm thời, tạo đơn hàng checkout, theo dõi trạng thái vòng đời đơn hàng. | Carts, CartItems, Orders, OrderLines. |
| **Online Bidding & Auction** | `AuctionService` | Phòng đấu giá trực tuyến, bước giá, quy tắc đặt giá, thời gian đếm ngược, xác định người thắng. | Auctions, Bids, AuctionParticipants. |
| **Physical Fulfillment & Logistics**| `FulfillmentService` | Kho vật lý lưu trữ thực tế, quản lý vận đơn, tính cước vận chuyển, theo dõi hành trình giao nhận. | Warehouses, PhysicalStock, Shipments, Carriers. |
| **Customer Notifications** | `NotificationService` | Đa kênh thông báo (In-app, Push, Email), lưu lịch sử thông báo, cấu hình tùy chọn người dùng, gửi email OTP. | Notifications, NotificationPreferences. |
| **Centralized Logging & System Auditing** | `LogService` | Thu thập nhật ký tập trung và lưu vết bất biến mọi thay đổi trong hệ thống. | Logs, LogEventTypes. |
| **Digital Wallet & Payments** | `WalletService` | Tài khoản ví điện tử khách hàng, nạp tiền, rút tiền về tài khoản ngân hàng, chuyển tiền nội bộ. | Wallets, WalletTransactions, BankAccounts. |
