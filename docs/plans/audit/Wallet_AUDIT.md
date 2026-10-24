# AUDIT — Wallet (`src/Services/Wallet`)

- **Branch:** `dev` · **Commit:** `4ab32a0` · **Dirty:** 5 (`Migrations` ×3 `D` + 1 `??`, `AGENTS.md`, `CLAUDE.md`)
- **Quy mô:** 46 file `.cs` / 1.755 LOC · Application 595 · Infrastructure 432 · Domain 366 · Api 362 · **Tests 0**
- **Port:** HTTP/gRPC `8008` ✅ · **DB:** `5440` `wallet_db` ✅
- **Index:** 68 file / 474 symbol / 755 edge / 11 flow

## 1. Kết luận nhanh

Wallet là service **khớp hợp đồng tốt nhất**: `specs/02` hứa 5 rpc và code implement **đủ 5** (`GetWallet, Deposit, Withdraw, Transfer, ListTransactions` — `Wallet.Api/Services/WalletGrpcService.cs`), có CQRS thật (MediatR `IRequestHandler`), có consumer `IStockReservedEvent` + publisher `IPaymentCompletedEvent/IPaymentFailedEvent`, có OTel.

Ba vấn đề chặn nó trở thành “chuẩn để nhân bản”:

1. **13 thông báo lỗi tiếng Việt** — nhiều nhất hệ thống (`StockReservedConsumer.cs:32,49,93`, `WalletAccount.cs:23,32,44`, `WalletGrpcService.cs:31,51,61,71,89,99,117`). Đây là service **vi phạm Nguyên tắc 5 nặng nhất**.
2. **0 test** — service tài chính (trừ tiền, cộng tiền, hoàn tiền) không có một `[Fact]` nào.
3. **Style CQRS khác 4 service còn lại** (Auction/Catalog/Commerce/Fulfillment dùng `Application/Services/IXxxService`) → cùng hệ thống nhưng 3 format Application layer khác nhau.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ✅ | `Application/Features/{Deposit,Withdraw,Transfer,GetWallet,ListTransactions}` mỗi feature 1 folder = 1 use case; `Common/`, `Consumers/`, `DTOs/` tách rõ |
| C2 | Dễ sửa, ít phụ thuộc | ✅ | Handler phụ thuộc `DbContext` + interface; 0 ref chéo service |
| C3 | File đúng folder | ⚠️ | Contract event đặt ở `Domain/Events/` (khác Log cũng `Domain/Events`, nhưng User/Notification đặt ở `Application/Contracts/`) → cùng loại artifact, 2 vị trí |
| C4 | Test/chạy độc lập | ❌ | Không có `Wallet.Tests`; `dotnet test` không có gì để chạy |
| C5 | Theo dõi request | ✅ | `AddOpenTelemetry` có; publish event kèm trace (cần verify header khi consume — xem `13`) |
| C6 | Doc là sự thật | ✅ | `specs/02` 5 rpc ↔ code 5 rpc; `04_DATA_PERSISTENCE` 8 bảng ↔ 8 DbSet |
| C7 | Luật đúng | ❌ | 13 chuỗi tiếng Việt trong ngữ cảnh lỗi (Nguyên tắc 5) |
| C8 | Format đồng nhất | ⚠️ | CQRS/MediatR + `Features/` — khác 4 service dùng `Services/`; package `FluentValidation` chỉ có ở Wallet/Log |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| WA-01 | **P0** | 13 thông báo lỗi tiếng Việt trả về client | `Wallet.Api/Services/WalletGrpcService.cs:31,51,61,71,89,99,117`; `Wallet.Domain/.../WalletAccount.cs:23,32,44`; `Wallet.Application/Consumers/StockReservedConsumer.cs:32,49,93` | Dịch English sentence case + error code SCREAMING_SNAKE (`WALLET_NOT_FOUND`, `INSUFFICIENT_BALANCE`, …) |
| WA-02 | **P0** | 0 test cho service tài chính | không có project `.Tests` | Thêm `Wallet.Tests` (xUnit + EF InMemory đã có sẵn package) phủ: deposit, withdraw thiếu số dư, transfer, consumer stock-reserved, idempotency |
| WA-03 | **P1** | Logic trừ/cộng tiền nằm trong entity (`WalletAccount.Decrease`) nhưng consumer gọi trực tiếp — không có transaction boundary rõ ràng | `Wallet.Domain/.../WalletAccount.cs:23-44`; `StockReservedConsumer.cs:32-93` | Rà soát: 1 handler = 1 transaction + idempotency key (đã có entity `IdempotencyKey`? kiểm tra lại) |
| WA-04 | **P1** | Event contract đặt ở `Domain/Events/` trong khi User/Notification đặt `Application/Contracts/` | so sánh 8 repo | Chốt 1 vị trí (đề xuất `Application/Contracts/`) và di chuyển |
| WA-05 | **P2** | `specs/03` chưa mô tả `IPaymentCompletedEvent`/`IPaymentFailedEvent` phát khi nào (Saga nào tiêu thụ?) | `specs/03_EVENT_MESSAGING.md` | Bổ sung bảng “event → ai consume → khi nào” |
| WA-06 | **P2** | Migration gộp thành 1 `InitialWalletSchema` chưa commit | `git status` | Commit khi đã review |

## 4. Điểm mạnh

- **Là service duy nhất khớp 100% hợp đồng gRPC đã hứa** → dùng làm “reference implementation” cho 5 service chưa có gRPC.
- CQRS + `Features/` giúp thêm use case mới không đụng code cũ (đúng tiêu chí C2).
- Có consumer cho Saga (`IStockReservedEvent`) — đầu mối duy nhất của luồng đặt hàng → trừ tiền.

## 5. Việc phải làm trước khi coi Wallet “xong”

1. `WA-01` (dịch lỗi) — nhanh, và là điều kiện của Definition of Done.
2. `WA-02` (test) — chặn mọi thay đổi tiếp theo vì không có lưới an toàn.
3. `WA-04` (vị trí event contract) — quyết định trước khi có thêm 3 event mới.
