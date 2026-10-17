# 04 — ĐĂNG KÝ HỢP ĐỒNG GIAO TIẾP DÙNG CHUNG (SHARED CONTRACTS REGISTRY)

Tài liệu này xác định vị trí nguồn sự thật duy nhất (Single Source of Truth) của các bản hợp đồng dữ liệu gRPC Protobuf và các sự kiện dùng chung (Domain Events) qua RabbitMQ.

---

## 1. NGUỒN SỰ THẬT DUY NHẤT (SINGLE SOURCE OF TRUTH): `Contracts/shop.proto`

Toàn bộ 8 Microservices và ApiGateway đều tuân theo bản định nghĩa hợp đồng gRPC duy nhất đặt tại:
`src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto`

### Danh Sách 8 gRPC Services Trong Contract:
1. `UsersApi`: Quản lý tài khoản, auth, profile, roles, permissions, seller upgrade.
2. `CatalogApi`: Quản lý categories, products, seller products, inventory.
3. `CommerceApi`: Quản lý giỏ hàng, đặt đơn, lấy đơn hàng cá nhân/seller/admin.
4. `AuctionApi`: Quản lý phiên đấu giá, đặt giá bid, danh sách bids.
5. `FulfillmentApi`: Tra cứu tồn kho kho bãi, tính cước vận chuyển, theo dõi vận đơn.
6. `NotificationApi`: Quản lý danh sách thông báo, đánh dấu đã đọc, tùy chọn nhận thông báo.
7. `LogApi`: Tra cứu nhật ký hệ thống, quản lý danh mục event type log.
8. `WalletApi`: Quản lý số dư ví, nạp tiền, rút tiền, chuyển tiền, lịch sử giao dịch.

---

## 2. QUY TRÌNH NÂNG CẤP VÀ ĐỒNG BỘ CONTRACT (CONTRACT EVOLUTION)

Khi có nhu cầu thêm API hoặc bổ sung trường dữ liệu:

```
[ Developer / AI Agent ]
           │
           ▼ (Bước 1) Sửa đổi tại: src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto
           │         (Tuân thủ quy tắc Backward Compatibility của Protobuf)
           │
           ▼ (Bước 2) Cập nhật Seed JSON tương ứng trong Seeds/{service}/{operation}.json
           │         (Chạy dotnet test để Protobuf MessageParser thẩm định schema)
           │
           ▼ (Bước 3) Sao chép file shop.proto sang thư mục Contracts/ của Microservice backend đích
           │
           ▼ (Bước 4) Biên dịch service backend (protoc tự động sinh C# gRPC Base Class)
           │
           ▼ (Bước 5) Triển khai Server Implementation kế thừa từ ServiceApiBase
```

### Nguyên Tắc An Toàn Tương Thích Ngược (Backward Compatibility):
- **KHÔNG BAO GIỜ** thay đổi hoặc xóa bỏ số thứ tự trường (Field Tag Number) đã có trong `.proto`.
- Khi cần deprecate một trường: Đánh dấu `[deprecated = true]` hoặc thêm trường mới với field tag tiếp theo.
- Không đổi kiểu dữ liệu của trường đã tồn tại (ví dụ `int32` thành `string`).

---

## 3. DANH MỤC EVENT DÙNG CHUNG QUA RABBITMQ (MASSTRANSIT EVENTS)

Các sự kiện bất đồng bộ được chia sẻ qua namespace `Nexus.Contracts.Events`:

| Tên Event Interface / Record | Service Phát Hành (Publisher) | Services Tiêu Thụ (Consumers) | Payload Chính |
|:---|:---:|:---:|:---|
| `IOrderSubmittedEvent` | `CommerceService` | `CatalogService`, `NotificationService`, `LogService` | `OrderId`, `UserId`, `Items: [{ ProductId, Quantity }]`, `TotalAmount` |
| `IStockReservedEvent` | `CatalogService` | `CommerceService`, `WalletService`, `LogService` | `OrderId`, `ReservationId`, `Timestamp` |
| `IStockReservationFailedEvent` | `CatalogService` | `CommerceService`, `NotificationService` | `OrderId`, `Reason`, `Timestamp` |
| `IPaymentCompletedEvent` | `WalletService` | `CommerceService`, `FulfillmentService`, `NotificationService` | `OrderId`, `TransactionId`, `Amount`, `Timestamp` |
| `IPaymentFailedEvent` | `WalletService` | `CommerceService`, `CatalogService` *(Bù trừ)* | `OrderId`, `Reason`, `Timestamp` |
| `IShipmentCreatedEvent` | `FulfillmentService` | `CommerceService`, `NotificationService`, `LogService` | `OrderId`, `TrackingCode`, `EstimatedDelivery` |
| `IAuctionEndedEvent` | `AuctionService` | `CommerceService`, `NotificationService`, `LogService` | `AuctionId`, `WinnerUserId`, `WinningAmount` |
| `ILogEventOccurred` | Mọi service | `LogService` | `ServiceName`, `EventType`, `ActorUserId`, `EntityName`, `EntityId`, `DetailsJson` |
