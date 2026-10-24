# 04 — ĐĂNG KÝ HỢP ĐỒNG GIAO TIẾP DÙNG CHUNG (SHARED CONTRACTS REGISTRY)

> **Trạng thái triển khai (2026-10-24):** ❌ Không đạt — không có "single source of truth" trên thực tế: có **4 bản `shop.proto` với 3 hash khác nhau**, bản được tài liệu này tuyên bố là nguồn sự thật (bản trong Gateway) lại là **bản thiếu nhất** (66 dòng, chỉ 1 service). Trong 8 gRPC service được liệt kê, **chỉ 3 service có server thật** và **chỉ 1 service có client ở Gateway**.
> **Nguồn sự thật:** code (các file `Contracts/shop.proto`, `MapGrpcService<…>()`, `AddNamedGrpcClient<…>()`, `Publish(...)`, `AddConsumer<…>()`).
> **Cập nhật lần cuối:** 2026-10-24.

Tài liệu này xác định vị trí nguồn sự thật duy nhất (Single Source of Truth) của các bản hợp đồng dữ liệu gRPC Protobuf và các sự kiện dùng chung (Domain Events) qua RabbitMQ.

---

## 1. HỢP ĐỒNG PROTOBUF — HIỆN TRẠNG THỰC TẾ

### 1.1 Bốn bản `shop.proto` đang tồn tại (⚠️ chưa có nguồn sự thật duy nhất)

| # | Đường dẫn | Dòng | Số service | Số rpc | `UsersApi` có bao nhiêu rpc | Ghi chú |
|:--|:---|--:|--:|--:|--:|:---|
| 1 | `src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto` | 66 | 1 | 5 | 5 (`Register`, `Login`, `VerifyOtp`, `ResendOtp`, `GetProfile`) | ❌ Thiếu 7 service so với tài liệu; **không** có comment `SchemaVersion`; **không** có `CreateUser` |
| 2 | `src/Services/User/User.Api/Contracts/shop.proto` | 390 | 9 | 63 | 13 | ✅ Đầy đủ nhất |
| 3 | `src/Services/Log/Log.Api/Contracts/shop.proto` | 364 | 9 | 61 | 11 (thiếu `VerifyOtp`, `ResendOtp`) | ⚠️ Lệch bản User |
| 4 | `src/Services/Wallet/Wallet.Api/Contracts/shop.proto` | 364 | 9 | 61 | 11 | ⚠️ **Giống hệt bản Log** (cùng md5 `8a7d8698…`) |

Hash thực tế: Gateway `af77ca6b…`, User `af331777…`, Log + Wallet `8a7d8698…` ⇒ **3 nội dung khác nhau**, không bản nào khớp cả 3.

### 1.2 Danh sách gRPC service **được khai báo** trong bản đầy đủ (9 service)

1. `UsersApi` — 13 rpc (bản User): tài khoản, auth, profile, roles, permissions, seller upgrade, OTP, `CreateUser`.
2. `CatalogApi` — 15 rpc: categories, products, seller products, inventory.
3. `CommerceApi` — 10 rpc: cart, order, order cá nhân/seller/admin.
4. `AuctionApi` — 5 rpc: phiên đấu giá, bid, danh sách bids.
5. `FulfillmentApi` — 3 rpc: tồn kho kho bãi, cước vận chuyển, theo dõi vận đơn.
6. `NotificationApi` — 4 rpc: thông báo, đánh dấu đã đọc, tùy chọn nhận.
7. `LogApi` — 4 rpc: nhật ký, danh mục event type.
8. `WalletApi` — 5 rpc: số dư, nạp, rút, chuyển, lịch sử giao dịch.
9. `AuditApi` — 4 rpc — ⚠️ **hợp đồng ma**: không có repo `src/Services/Audit`, không có trong `specs/01`, không có trong `docker-compose.yml`. Có trong 3 bản proto nhưng không tồn tại trong hệ thống.

### 1.3 Mức độ triển khai thật (đối chiếu khai báo ↔ code)

| Service | rpc khai báo | rpc có server | Client ở Gateway | Trạng thái |
|:---|--:|--:|:--:|:---|
| `UsersApi` | 13 | **4** (`Register`, `VerifyOtp`, `ResendOtp`, `GetProfile`) | ✅ `users` | ⚠️ `Login` khai báo nhưng **không implement**; `CreateUser` không có trong proto Gateway |
| `LogApi` | 4 | **4** ✅ | ❌ | ⚠️ Server đủ nhưng Gateway không có client ⇒ không gọi được |
| `WalletApi` | 5 | **5** ✅ | ❌ | ⚠️ Server đủ nhưng Gateway không có client |
| `CatalogApi` | 15 | **0** | ❌ | ❌ Không có điểm vào gRPC (chỉ REST mock) |
| `CommerceApi` | 10 | **0** | ❌ | ❌ |
| `AuctionApi` | 5 | **0** | ❌ | ❌ |
| `FulfillmentApi` | 3 | **0** | ❌ | ❌ |
| `NotificationApi` | 4 | **0** | ❌ | ❌ |
| `AuditApi` | 4 | — | — | ❌ Không tồn tại repo |

Bằng chứng: `ApiGateway/Nexus.Gateway/Extensions/GrpcClientsExtension.cs:12` đăng ký **duy nhất** `AddNamedGrpcClient<UsersApi.UsersApiClient>("users")`; `MapGrpcService<…>()` chỉ có ở `User/User.Api/Program.cs:64`, `Log/Log.Api/Program.cs:47`, `Wallet/Wallet.Api/Program.cs:47`; `MapGrpcReflectionService()` cũng chỉ 3 service này (trong `IsDevelopment()`).

---

## 2. QUY TRÌNH NÂNG CẤP VÀ ĐỒNG BỘ CONTRACT (CONTRACT EVOLUTION)

> **Trạng thái (2026-10-24): ❌ Nguyên nhân gốc của drift.** Quy trình hiện tại là **sao chép thủ công** (Bước 3), và đã được thực thi không đồng bộ ⇒ 4 bản / 3 hash. Không có script đồng bộ, không có CI kiểm hash.

Quy trình **đang được mô tả** (chưa thực thi đúng):

```
[ Developer / AI Agent ]
           │
           ▼ (Bước 1) Sửa đổi tại: src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto
           │         ⚠️ Bản này chỉ có UsersApi (66 dòng) ⇒ sửa ở đây sẽ MẤT 8 service còn lại
           │
           ▼ (Bước 2) Cập nhật Seed JSON tương ứng trong Seeds/{service}/{operation}.json
           │         ⚠️ Gateway chỉ có Seeds/auth/* và Seeds/users/* (9 file), không có seed cho 7 service khác
           │
           ▼ (Bước 3) Sao chép file shop.proto sang thư mục Contracts/ của Microservice backend đích
           │         ❌ Copy tay ⇒ nguồn drift; 5/8 service không có thư mục Contracts/
           │
           ▼ (Bước 4) Biên dịch service backend (protoc tự động sinh C# gRPC Base Class)
           │
           ▼ (Bước 5) Triển khai Server Implementation kế thừa từ ServiceApiBase
           │         ⚠️ Chỉ 3/8 service làm bước này
```

**Đề xuất sửa quy trình (chưa thực hiện):** đặt proto canonical ở **root** (`contracts/proto/shop.proto`), thêm script `scripts/sync-proto.sh` copy vào từng service, và thêm bước CI so sánh hash để chặn lệch. Xem `docs/plans/FIX_BACKLOG.md` mục `FIX-002`.

### Nguyên Tắc An Toàn Tương Thích Ngược (Backward Compatibility):
- **KHÔNG BAO GIỜ** thay đổi hoặc xóa bỏ số thứ tự trường (Field Tag Number) đã có trong `.proto`.
- Khi cần deprecate một trường: Đánh dấu `[deprecated = true]` hoặc thêm trường mới với field tag tiếp theo.
- Không đổi kiểu dữ liệu của trường đã tồn tại (ví dụ `int32` thành `string`).
- Mọi thay đổi phải **ADDITIVE** (bản User/Log/Wallet có ghi chú `SchemaVersion: v3`; bản Gateway **không có** ghi chú này).

---

## 3. DANH MỤC EVENT DÙNG CHUNG QUA RABBITMQ (MASSTRANSIT EVENTS)

> **Trạng thái (2026-10-24):** ❌ **6/8 event trong bảng dưới đây không tồn tại trong code.** Toàn hệ thống chỉ có **1 đường publish còn sống** (`User.Application/Services/Auth/AuthService.cs:147,253` phát `SendOtpEmailIntegrationEvent`); `Wallet` có 4 lời gọi `Publish` (`Wallet.Application/Consumers/StockReservedConsumer.cs:33,50,83,95`) nhưng **nằm trong consumer chưa từng chạy** nên không tính là publisher sống. Có **3 consumer** (Notification nhận OTP, Log nhận `ILogEventOccurred`, Wallet nhận `IStockReservedEvent`). Hai interface event còn lại chỉ được **khai báo**, không ai publish.

| Tên Event | Publisher (khai báo) | Consumers (khai báo) | Trạng thái thực tế (2026-10-24) |
|:---|:---|:---|:---|
| `IOrderSubmittedEvent` | `Commerce` | `Catalog`, `Notification`, `Log` | ❌ Không tồn tại trong code (0 interface, 0 publisher) |
| `IStockReservedEvent` | `Catalog` | `Commerce`, `Wallet`, `Log` | ⚠️ **Chỉ có consumer** `Wallet/.../StockReservedConsumer.cs:13`; **0 publisher** (Catalog chưa có code publish) |
| `IStockReservationFailedEvent` | `Catalog` | `Commerce`, `Notification` | ❌ Không tồn tại |
| `IPaymentCompletedEvent` | `Wallet` | `Commerce`, `Fulfillment`, `Notification` | ⚠️ Interface được khai báo (`Wallet/Wallet.Domain/Events/WalletEvents.cs`), **0 lời gọi publish** |
| `IPaymentFailedEvent` | `Wallet` | `Commerce`, `Catalog` | ⚠️ Khai báo, **0 lời gọi publish** |
| `IShipmentCreatedEvent` | `Fulfillment` | `Commerce`, `Notification`, `Log` | ❌ Không tồn tại |
| `IAuctionEndedEvent` | `Auction` | `Commerce`, `Notification`, `Log` | ❌ Không tồn tại |
| `ILogEventOccurred` | Mọi service | `Log` | ⚠️ Consumer có (`Log.Application/Consumers/GlobalLogConsumer.cs:10`), **0 publisher** trong 9 repo |
| `SendOtpEmailIntegrationEvent` *(không có trong bảng gốc)* | `User` (`AuthService.cs:147`, `:253`) | `Notification` (`SendOtpEmailConsumer.cs:9`) | ✅ **Hoạt động thật** — 2 bản khai báo giống hệt nhau, cùng namespace `Nexus.Contracts.Events` ⇒ MassTransit MessageUrn khớp |
| `ServiceUnhealthyIntegrationEvent` *(không có trong bảng gốc)* | `ApiGateway` (`HealthProber/SagaRollbackPublisher.cs:8`) | (không có) | ⚠️ Được khai báo; publisher **không publish gì** (chỉ log, `return Task.CompletedTask`) |

### 3.1 Payload của các event còn tồn tại

```csharp
// User/User.Application/Contracts/SendOtpEmailIntegrationEvent.cs
// Notification/Notification.Application/Contracts/SendOtpEmailIntegrationEvent.cs  (byte-identical)
namespace Nexus.Contracts.Events;
public record SendOtpEmailIntegrationEvent(
    string Email, string FullName, string Otp, int ExpiresInMinutes = 5);

// Wallet/Wallet.Domain/Events/WalletEvents.cs
public interface IStockReservedEvent { Guid OrderId; Guid ReservationId; DateTimeOffset Timestamp; }
public interface IPaymentCompletedEvent { Guid OrderId; Guid TransactionId; decimal Amount; DateTimeOffset Timestamp; }
public interface IPaymentFailedEvent { Guid OrderId; string Reason; DateTimeOffset Timestamp; }

// Log/Log.Domain/Events/LogEvents.cs:3
public interface ILogEventOccurred { /* ServiceName, EventType, ActorUserId, EntityName, EntityId, DetailsJson */ }
```

**Ghi chú thiết kế:** event record khai báo **2 lần ở 2 repo** (`User` và `Notification`) là cách duy nhất hiện tại để giữ tính self-contained của submodule. Đây là điểm cần quyết định: hoặc chấp nhận trùng lặp có kiểm soát (kèm test so khớp schema), hoặc tách `Nexus.Contracts` thành NuGet package dùng chung.
