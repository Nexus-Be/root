# AUDIT — Auction (`src/Services/Auction`)

- **Branch:** `dev` · **Commit:** `37895fa` · **Dirty:** 5
- **Quy mô:** 47 file `.cs` / 1.182 LOC · Infrastructure 502 · Application **198** · Domain 327 · Api 154 · **Tests 0**
- **Port:** Dockerfile `8005` ✅ · **`launchSettings.json` chỉ có `http=5230`, `https=7202`** ❌ · **DB:** `5437` `auction_db` ✅
- **Index:** 68 file / 445 symbol / 565 edge / **4 flow**

## 1. Kết luận nhanh

Auction là **thư viện nghiệp vụ chứ chưa phải service**: 13 entity, 2 service class (`AuctionService`, `BidService`), migration đầy đủ, nhưng **bề mặt mạng = 0** (`/health` + `/`), **không gRPC**, **không controller**, **không event**, **không test**, **không OTel**.

Nghĩa là: không ai gọi được Auction. Gateway có `AuctionController.cs` (10 dòng, 0 action) nên cũng chưa nối. Spec hứa 5 rpc (`CreateAuction, GetAuction, ListAuctions, ListBids, PlaceBid`) — **0/5 tồn tại**.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ❌ | Application chỉ 198 LOC cho toàn bộ nghiệp vụ đấu giá + bid; không có `Features/`, không có handler — thêm 1 use case mới phải sửa `AuctionService` (đúng chỗ C2 cấm) |
| C2 | Dễ sửa, ít phụ thuộc | ⚠️ | Vẫn 0 ref chéo service (tốt), nhưng `IAuctionService` gộp nhiều việc |
| C3 | File đúng folder | ✅ | 13 DbSet ↔ entity; `Auction.Domain/Base`, `Enums`, `Exceptions` đúng chuẩn 8 repo |
| C4 | Test/chạy độc lập | ❌ | 0 test; không có bề mặt để test bằng Postman/gRPC |
| C5 | Theo dõi request | ❌ | Không `AddOpenTelemetry`, không đọc `x-trace-id` |
| C6 | Doc là sự thật | ❌ | `specs/02` 5 rpc (0 impl); `specs/03` nói publish `IAuctionEndedEvent` — không tồn tại trong code |
| C7 | Luật đúng | ⚠️ | Không Repository pattern ✅, error English ✅, nhưng port launchSettings lệch ❌ |
| C8 | Format đồng nhất | ⚠️ | Application style `Services/` (giống Catalog/Commerce/Fulfillment) — nhưng có BOM trong `Auction.Api/Properties/launchSettings.json` |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| AU-01 | **P0** | Không có bề mặt gRPC/REST → service không dùng được | `Auction.Api/Program.cs` chỉ `MapGet("/health")`; 0 class kế thừa gRPC base | Thêm `AuctionGrpcService` implement 5 rpc theo `specs/02` |
| AU-02 | **P0** | 0 test | không có `Auction.Tests` | Thêm test cho `PlaceBid` (đấu giá: race condition, giá thấp hơn, hết hạn) |
| AU-03 | **P0** | `specs/03` khai báo publish `IAuctionEndedEvent` nhưng code không có event nào | grep `Event` trong Auction = 0 | Implement event + publisher (MassTransit) hoặc cắt khỏi spec |
| AU-04 | **P1** | `dbml/service/auction-db.dbml:299` có bảng `SagaStates` **không tồn tại trong code** (13 DbSet ≠ 14 bảng) | `dbml/service/auction-db.dbml` | Hoặc xoá khỏi dbml, hoặc implement saga state |
| AU-05 | **P1** | `launchSettings.json` port `5230/7202`, không có profile `8005` | `Auction.Api/Properties/launchSettings.json` | Đổi `applicationUrl` về `http://localhost:8005` |
| AU-06 | **P1** | Nghiệp vụ auction gói trong 2 service class | `Auction.Application/Services/` (198 LOC) | Tách `Features/{CreateAuction,PlaceBid,CloseAuction}` như Wallet/Log để dễ test |
| AU-07 | **P2** | Không OTel | `Auction.Api/Program.cs` | Thêm `AddOpenTelemetry` như Wallet |
| AU-08 | **P2** | `ProductOpenAuction` là bảng riêng — ranh giới với Catalog/Fulfillment chưa rõ ai sở hữu “sản phẩm trong phiên” | entity `ProductOpenAuction` | Ghi rõ trong `specs/00` |

## 4. Việc phải làm trước khi coi Auction “xong”

1. `AU-01` — dựng gRPC surface (5 rpc) → mở đường cho Gateway.
2. `AU-02` — test `PlaceBid` trước khi mở endpoint (nghiệp vụ tiền).
3. `AU-03`/`AU-04` — đồng bộ event + dbml.
