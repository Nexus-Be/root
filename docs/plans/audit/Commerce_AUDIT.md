# AUDIT — Commerce (`src/Services/Commerce`)

- **Branch:** `dev` · **Commit:** `44616e1` · **Dirty:** 5
- **Quy mô:** 67 file `.cs` / 1.856 LOC · Infrastructure 894 · Domain 608 · Application **199** · Api 155 · **Tests 0**
- **Port:** Dockerfile `8003` ✅ · **`launchSettings.json` `http=5105`, `https=7035`** ❌ · **DB:** `5435` `commerce_db` ✅
- **Index:** 88 file / 636 symbol / 799 edge / **7 flow** (cao thứ 3 backend)

## 1. Kết luận nhanh

Commerce là **domain lớn nhất backend** (16 bảng: `Order`, `SubOrder`, `OrderInvoice`, `OrderRefund`, `OrderCancellation`, `OrderStatusHistory`, `Cart`, `DiscountCode*`, `DailyOrderSequence`…) nhưng **Application layer chỉ 199 LOC** cho 2 service (`CartService`, `OrderService`) — tức là mỗi use case chỉ vài dòng, không đủ chỗ cho nghiệp vụ thật (tính tiền, voucher, hoàn tiền, huỷ đơn).

Không gRPC, không controller, **không publish `IOrderSubmittedEvent`** dù spec nói Commerce là publisher chính của Saga đặt hàng, không test, không OTel.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ❌ | 16 entity ↔ 199 LOC Application; thêm use case “huỷ đơn hoàn tiền” sẽ dồn vào `OrderService` |
| C2 | Dễ sửa, ít phụ thuộc | ⚠️ | 0 ref chéo service; nhưng service class to dần |
| C3 | File đúng folder | ✅ | 16 DbSet ↔ 16 bảng `commerce.dbml` |
| C4 | Test/chạy độc lập | ❌ | 0 test, 0 bề mặt |
| C5 | Theo dõi request | ❌ | không OTel |
| C6 | Doc là sự thật | ❌ | 10 rpc hứa / 0 impl; `IOrderSubmittedEvent` (publisher = Commerce theo `specs/04`) không tồn tại |
| C7 | Luật đúng | ⚠️ | Port lệch |
| C8 | Format đồng nhất | ⚠️ | Application style `Services/` (khác Wallet/Log CQRS); BOM launchSettings |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| CO-01 | **P0** | 0/10 rpc, không bề mặt | `Commerce.Api/Program.cs` chỉ `/health` | Ưu tiên `CreateOrder`, `GetOrder`, `ListOrders` |
| CO-02 | **P0** | Không publish `IOrderSubmittedEvent` → **Saga đặt hàng không có điểm khởi đầu** | grep `Event` trong Commerce = 0; `specs/04` gán Commerce là publisher | Implement event + publish trong `OrderService.CreateOrder` (sau khi lưu DB, qua Outbox — hạ tầng Outbox đã có trong migration User, cần bổ sung cho Commerce) |
| CO-03 | **P0** | 0 test cho domain tiền/đơn | không có `Commerce.Tests` | Test tổng tiền, voucher, trạng thái đơn |
| CO-04 | **P1** | `DailyOrderSequence` sinh mã đơn — không thấy cơ chế an toàn khi concurrent | entity `DailyOrderSequence` | Dùng `UPDATE ... RETURNING` hoặc sequence PG, viết test song song |
| CO-05 | **P1** | Port `5105/7035` | launchSettings | Về `8003` |
| CO-06 | **P1** | Không OTel | `Program.cs` | Thêm |
| CO-07 | **P2** | `AuctionOrder` (đơn từ đấu giá) nằm trong Commerce nhưng Auction chưa phát event kết thúc → bảng không có nguồn ghi | entity `AuctionOrder` | Chờ `IAuctionEndedEvent` hoặc bỏ |

## 4. Rủi ro lớn nhất

Commerce là **mắt xích trung tâm của Saga** (đặt hàng → giữ kho → trừ tiền → giao hàng) nhưng hiện **không phát và không nhận một event nào**. Toàn bộ luồng nghiệp vụ chính của hệ thống (mua hàng) chưa tồn tại ở tầng giao tiếp, chỉ tồn tại ở tầng bảng.
