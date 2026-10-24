# AUDIT — Hợp đồng dùng chung (proto, event, dbml)

**Câu hỏi:** “các file trong từng folder đều chính xác, và nếu có liên kết tới service khác thì phải đồng nhất”.

## 0. Kết luận

**Không đồng nhất.** Ba loại hợp đồng dùng chung (Protobuf, Integration Events, DBML) đều có **nhiều bản sao chép tay** và **đã trôi khỏi nhau**:

- Protobuf: 4 file, **3 hash**, và bản “nguồn sự thật” theo spec lại là bản **thiếu nhiều nhất** (1/9 service).
- Event: 8 event được khai trong `specs/04`, **chỉ 4 tồn tại trong code**; 1 event (`SendOtpEmailIntegrationEvent`) được khai **2 lần ở 2 repo** và chạy được **nhờ may mắn** namespace trùng.
- DBML: 8 file service nhưng chỉ 5 file enum; 1 bảng trong dbml không có trong code; tên bảng số nhiều vs entity số ít không có tài liệu ánh xạ (chỉ suy ra từ `ToTable`).

## 1. Protobuf

| Bản | Đường dẫn | md5 | Nội dung |
|---|---|---|---|
| 1 | `src/Services/ApiGateway/Nexus.Gateway/Contracts/shop.proto` | `af77ca6bc36cad04bf0c0ce4feb80bc9` | **chỉ `UsersApi`, 5 rpc** (`Register, Login, VerifyOtp, ResendOtp, GetProfile`) |
| 2 | `src/Services/User/User.Api/Contracts/shop.proto` | `af3317770a3ed87f15da6f4ff5fa4fdc` | 9 service, ~60 rpc, có `CreateUser`, `ListRoles`, `ApproveSeller`… |
| 3 | `src/Services/Log/Log.Api/Contracts/shop.proto` | `8a7d8698a0607cfb8a41c30a7d7b4492` | giống bản 4 |
| 4 | `src/Services/Wallet/Wallet.Api/Contracts/shop.proto` | `8a7d8698a0607cfb8a41c30a7d7b4492` | 9 service, ~60 rpc |

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| CT-01 | **P0** | Nguồn sự thật bị đảo: `specs/04` chỉ định Gateway proto, nhưng file đó thiếu 8/9 service → quy trình “sửa Gateway rồi copy” sẽ xoá ~55 rpc | so sánh 4 bản | Đưa proto lên **root** (`contracts/proto/shop.proto`) + script `sync-proto.sh` copy xuống 4 chỗ, CI check hash |
| CT-02 | **P0** | `CreateUser` có trong bản 2/3/4 nhưng không có trong bản Gateway → client Gateway không gọi được | grep `CreateUser` | Chốt danh sách rpc user (xem `US-02`) |
| CT-03 | **P1** | `SchemaVersion: v3 … additive only` ghi trong file nhưng không có cơ chế chặn phá vỡ (không có buf/breaking-change check) | dòng 7 mỗi proto | Thêm `buf breaking` vào CI hoặc script so sánh field number |
| CT-04 | **P1** | Chỉ 3/8 service build proto (User/Log/Wallet); 5 service còn lại không có proto trong `Api/Contracts/` → không thể sinh server stub | ls `*/Api/Contracts/` | Mỗi service phải có proto riêng (subset) khi implement surface |

## 2. Integration Events

| Event | `specs/04` khai | Thực tế | Trạng thái |
|---|---|---|---|
| `SendOtpEmailIntegrationEvent` | (không có trong spec) | **2 bản**: `User/User.Application/Contracts/` + `Notification/Notification.Application/Contracts/` (cùng `namespace Nexus.Contracts.Events`, record `(Email, FullName, Otp, ExpiresInMinutes=5)`) | ✅ **Chạy thật** (MessageUrn khớp) |
| `IStockReservedEvent` | Catalog → Commerce/Wallet/Log | interface ở `Wallet.Domain/Events/WalletEvents.cs`; consumer `StockReservedConsumer.cs:13`; **0 publisher** | ❌ Consumer chết (không ai phát) |
| `IPaymentCompletedEvent` | Wallet → Commerce/Fulfillment/Notification | **có publisher**: `StockReservedConsumer.cs:83` `context.Publish<IPaymentCompletedEvent>`; **0 consumer** | ⚠️ Phát được nhưng không ai nghe; và bản thân consumer chứa nó không bao giờ chạy |
| `IPaymentFailedEvent` | Wallet → Commerce/Catalog | **có publisher**: `StockReservedConsumer.cs:33/50/95`; **0 consumer** | ⚠️ Như trên |
| `IOrderSubmittedEvent` | Commerce → Catalog/Notification/Log | không tồn tại | ❌ |
| `IStockReservationFailedEvent` | Catalog → Commerce/Notification | không tồn tại | ❌ |
| `IShipmentCreatedEvent` | Fulfillment → Commerce/Notification/Log | không tồn tại | ❌ |
| `IAuctionEndedEvent` | Auction → Commerce/Notification/Log | không tồn tại | ❌ |
| `ILogEventOccurred` | mọi service → Log | interface có (`Log.Domain/Events/LogEvents.cs:3`), **0 publisher** | ❌ |
| `ServiceUnhealthyIntegrationEvent` | (không có trong spec) | `Nexus.Gateway/HealthProber/SagaRollbackPublisher.cs:8`; publish **đang bị comment** (`:27`) → không bao giờ phát | ⚠️ Ngoài spec + code chết |

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| CT-05 | **P0** | 6/8 event trong registry không tồn tại → “Saga checkout” chỉ là sơ đồ | bảng trên | Hoặc implement, hoặc đánh dấu `Status: planned` trong `specs/04` **ngay hôm nay** |
| CT-06 | **P0** | Event contract không có nơi ở chung: 1 event khai 2 lần ở 2 repo, khớp nhờ namespace trùng | `User.Application/Contracts/` + `Notification.Application/Contracts/` | Tạo shared package `Nexus.Contracts` (project hoặc submodule) — không copy tay |
| CT-07 | **P1** | `specs/04` gán publisher cho các event không tồn tại → không ai biết ai phải làm | `specs/04` bảng event | Bảng phải có cột `Publisher repo` + `Trạng thái` |
| CT-08 | **P2** | `ServiceUnhealthyIntegrationEvent` nằm ở Gateway (`HealthProber/`) — Gateway đang tự định nghĩa domain event | `SagaRollbackPublisher.cs:8` | Chuyển vào contracts chung hoặc đổi tên cho đúng vai trò hạ tầng |

## 3. DBML

| Service | Bảng trong dbml | DbSet | Khớp? | Ghi chú |
|---|---|---|---|---|
| User | 14 | 14 | ✅ | |
| Catalog | 9 | 9 | ✅ | |
| Commerce | 16 | 16 | ✅ | |
| Log | 6 | 6 | ✅ | dbml `Logs` ↔ entity `LogEntry` |
| Notification | 10 | 10 | ✅ | dbml `Notifications` ↔ entity `NotificationRecord` |
| Wallet | 8 | 8 | ✅ | dbml `Wallets` ↔ entity `WalletAccount` |
| Fulfillment | 10 | 10 | ✅ | |
| Auction | **14** | **13** | ❌ | `SagaStates` (`dbml/service/auction-db.dbml:299`) không có trong code |

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| CT-09 | **P1** | `auction-db.dbml` có bảng `SagaStates` (7 cột, `StateData jsonb`) mà code không dùng | `dbml/service/auction-db.dbml:299` | Xoá khỏi dbml (không có saga ở Auction) |
| CT-10 | **P1** | `dbml/enum/` chỉ có 5 service (thiếu Commerce, Fulfillment, Log) nhưng code có 78 enum | `ls dbml/enum` | Sinh enum doc tự động từ `*.Domain/Enums` |
| CT-11 | **P2** | Tên bảng số nhiều ↔ entity số ít không có tài liệu ánh xạ, phải đọc `ToTable(...)` | `AuditLogs`/`Categories`/`Wallets`… | Thêm bảng mapping vào `specs/04` hoặc `dbml/README` |

## 4. Việc phải làm trước khi coi hợp đồng “đồng nhất”

1. `CT-01` + `CT-06` — dựng **một** nguồn cho proto và **một** nguồn cho events (root `contracts/` hoặc shared package), có script sync + CI hash check.
2. `CT-05` — cập nhật `specs/04` đúng hiện trạng trước khi ai đó code theo nó.
3. `CT-02` + `CT-09` — dọn 2 chỗ sai cụ thể (rpc `CreateUser`, bảng `SagaStates`).
