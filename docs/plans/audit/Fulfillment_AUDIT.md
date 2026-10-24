# AUDIT — Fulfillment (`src/Services/Fulfillment`)

- **Branch:** `dev` · **Commit:** `1702ffc` · **Dirty:** 5
- **Quy mô:** 46 file `.cs` / 1.184 LOC · Infrastructure 492 · Domain 334 · Application **204** · Api 154 · **Tests 0**
- **Port:** Dockerfile `8006` ✅ · **`launchSettings.json` `http=5228`, `https=7014`** ❌ · **DB:** `5438` `fulfillment_db` ✅
- **Index:** 67 file / 404 symbol / 514 edge / **4 flow**

## 1. Kết luận nhanh

Fulfillment nắm **nghiệp vụ kho + vận chuyển** (10 bảng: `Warehouse`, `InventoryItem`, `InventoryLedger`, `InventoryReservation`, `Shipment`, `ShipmentItem`, `ShipmentEvent`, `Carrier`), nhưng:

- **0/3 rpc** (`CalculateShippingFee`, `GetInventory`, `GetShipmentTracking`) → không bề mặt.
- **Không consume `IPaymentCompletedEvent`** dù `specs/04` nói Fulfillment là consumer → không có gì kích hoạt việc tạo shipment.
- **Không publish `IShipmentCreatedEvent`** dù spec gán là publisher.
- 0 test, không OTel.

Nghĩa là: **kho không có API để giữ/giải phóng tồn kho**, dù Wallet đã có consumer `IStockReservedEvent` chờ tín hiệu từ kho. Chuỗi này đứt ở Fulfillment.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ❌ | `ShipmentService`, `WarehouseService` (204 LOC) gộp; kho và ship lẽ ra 2 bounded context riêng biệt trong cùng service |
| C2 | Dễ sửa, ít phụ thuộc | ⚠️ | 0 ref chéo; service class gộp |
| C3 | File đúng folder | ✅ | 10 DbSet ↔ 10 bảng `fulfillment.dbml` |
| C4 | Test/chạy độc lập | ❌ | 0 test |
| C5 | Theo dõi request | ❌ | không OTel |
| C6 | Doc là sự thật | ❌ | `specs/02` 3 rpc / 0 impl; `specs/03` consumer+publisher đều không tồn tại |
| C7 | Luật đúng | ⚠️ | Port lệch |
| C8 | Format đồng nhất | ⚠️ | Application style `Services/`; launchSettings có BOM |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| FU-01 | **P0** | 0/3 rpc, không bề mặt | `Fulfillment.Api/Program.cs` chỉ `/health` | Ưu tiên `GetInventory` + `CalculateShippingFee` |
| FU-02 | **P0** | Không consume `IPaymentCompletedEvent` → shipment không bao giờ được tạo tự động | grep `IConsumer` trong Fulfillment = 0 | Thêm consumer tạo `Shipment` từ order đã thanh toán |
| FU-03 | **P0** | Không publish `IShipmentCreatedEvent` | grep `Event` = 0 | Publish sau khi tạo shipment (kèm `TrackingCode`) |
| FU-04 | **P0** | 0 test cho reservation tồn kho (nghiệp vụ dễ sai nhất: double-reserve, oversell) | không có `Fulfillment.Tests` | Test reserve/release + concurrent |
| FU-05 | **P1** | Port `5228/7014` | launchSettings | Về `8006` |
| FU-06 | **P1** | `InventoryReservation` không có cơ chế hết hạn (TTL) — reservation treo sẽ khoá tồn kho vĩnh viễn | entity `InventoryReservation` | Thêm `ExpiresAt` + job/consumer giải phóng |
| FU-07 | **P2** | Không OTel | `Program.cs` | Thêm |

## 4. Quan hệ với Catalog

`specs/02` của **Catalog** cũng nhận `AdjustInventory/GetInventory`, trong khi entity kho nằm ở Fulfillment. Đề xuất chốt: **Fulfillment sở hữu kho**, Catalog chỉ sở hữu product/category; sửa spec Catalog (xem `Catalog_AUDIT.md` CA-03).
