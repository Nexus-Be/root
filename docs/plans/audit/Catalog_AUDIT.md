# AUDIT — Catalog (`src/Services/Catalog`)

- **Branch:** `dev` · **Commit:** `4c74107` · **Dirty:** 5
- **Quy mô:** 42 file `.cs` / 1.343 LOC · Infrastructure 709 · Domain 283 · Application **196** · Api 155 · **Tests 0**
- **Port:** Dockerfile `8002` ✅ · **`launchSettings.json` `http=5272`, `https=7232`** ❌ · **DB:** `5434` `catalog_db` ✅
- **Index:** 63 file / 384 symbol / 490 edge / **4 flow**

## 1. Kết luận nhanh

Catalog là service **bị “hứa” nhiều nhất nhưng làm được ít nhất**: `specs/02` hứa **13 rpc** (gồm cả `AdjustInventory/GetInventory`), code có **0**. Không gRPC, không controller, không event, không test, không OTel.

Ngoài ra có **xung đột bounded context** với Fulfillment: `specs/02` của Catalog nhận `AdjustInventory/GetInventory`, nhưng entity kho (`InventoryItem`, `Warehouse`, `InventoryLedger`, `InventoryReservation`) nằm ở **Fulfillment.Domain**, còn Catalog chỉ có `PurchaseRecord`, `ProductRatingStats`. Hai spec cùng nhận một nghiệp vụ.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ❌ | `Application/Services/{ProductService,CategoryService}` (196 LOC) gộp CRUD; ranh giới “Catalog quản lý kho” vs Fulfillment mơ hồ |
| C2 | Dễ sửa, ít phụ thuộc | ⚠️ | 0 ref chéo service; nhưng `IProductService` gộp nhiều use case |
| C3 | File đúng folder | ✅ | 9 DbSet ↔ 9 bảng `catalog-service.dbml` (khớp tên số nhiều qua `ToTable`) |
| C4 | Test/chạy độc lập | ❌ | 0 test, 0 bề mặt |
| C5 | Theo dõi request | ❌ | không OTel, không trace header |
| C6 | Doc là sự thật | ❌❌ | 13 rpc hứa / 0 impl; `specs/03` nói Catalog publish `IStockReservedEvent` + `IStockReservationFailedEvent` — **cả 2 không tồn tại trong repo Catalog** (interface `IStockReservedEvent` lại được định nghĩa trong *Wallet* — `Wallet.Domain/Events/WalletEvents.cs`) |
| C7 | Luật đúng | ⚠️ | Port lệch; còn lại OK |
| C8 | Format đồng nhất | ⚠️ | Application style `Services/`; BOM trong launchSettings |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| CA-01 | **P0** | 0/13 rpc được implement, không bề mặt | `Catalog.Api/Program.cs:60` chỉ `MapGet("/health")` | Ưu tiên 4 rpc lõi: `GetProduct, ListProducts, CreateProduct, UpdateProduct` |
| CA-02 | **P0** | Không phát event `IStockReservedEvent` dù spec khai là publisher | grep `Event` trong Catalog = 0; interface định nghĩa trong Wallet | Đưa contract về 1 nơi dùng chung, implement publisher sau khi có luồng đặt hàng |
| CA-03 | **P0** | Xung đột sở hữu nghiệp vụ kho với Fulfillment | `Catalog/specs/02` có `AdjustInventory/GetInventory`; `Fulfillment.Domain/Entities/{InventoryItem,Warehouse,InventoryLedger,InventoryReservation}` | Chốt: kho thuộc **Fulfillment** (đúng code hiện tại) → sửa `Catalog/specs/02` bỏ 2 rpc kho |
| CA-04 | **P0** | 0 test | không có `Catalog.Tests` | Test `ProductService` (giá, trạng thái, variant) |
| CA-05 | **P1** | Port launchSettings `5272/7232` | `Catalog.Api/Properties/launchSettings.json` | Về `8002` |
| CA-06 | **P1** | Không OTel / trace | `Program.cs` | Thêm như Wallet |
| CA-07 | **P2** | `ProductRatingStats` là bảng tổng hợp — cập nhật ở đâu? (không thấy command nào ghi) | entity + DbSet, 0 chỗ ghi | Ghi rõ luồng cập nhật (event `IReviewCreated`?) hoặc bỏ |

## 4. Ghi chú kiến trúc

Catalog là **service mẫu tốt nhất để chứng minh toàn bộ pattern** vì: ít entity (9), nghiệp vụ dễ hiểu, gateway đã có sẵn `ProductsController`/`CategoriesController` (stub). Khuyến nghị chọn Catalog làm **service đầu tiên nối end-to-end** (gRPC + gateway action + test + trace) thay vì làm rộng 8 service.
