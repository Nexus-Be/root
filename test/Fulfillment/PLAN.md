# Fulfillment Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service kho bãi và vận đơn, cổng 8006, DB `fulfillment_db` 5438. Hiện mở 6 endpoint.
Cả 3 controller đều không có attribute xác thực, gồm cả endpoint khởi tạo tồn kho.
Không có test và không có global query filter.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Fulfillment.sln -c Release` | Pass, 0 warning, 0 error |
| Test | Không có project test |
| Endpoint hiện thực | 6 |
| Tài liệu `B_none` | 9 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 0 |
| `HasIndex` | 4 |
| Controller không có attribute xác thực | `WarehousesController`, `InventoriesController`, `ShipmentsController` |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| FU-01 | HIGH | `POST /api/v1/inventories/initialize` và `GET /api/v1/inventories/{skuId}` không yêu cầu xác thực. Bất kỳ ai qua Gateway cũng khởi tạo hoặc đọc tồn kho | `Fulfillment.Api/Controllers/Public/InventoriesController.cs:10-37` |
| FU-02 | HIGH | Hai endpoint vận đơn không giới hạn quyền sở hữu. Ai biết mã vận đơn hoặc mã đơn là đọc được chi tiết giao hàng | `Fulfillment.Api/Controllers/Public/ShipmentsController.cs:24-35` |
| FU-03 | HIGH | Không có project test cho logic giữ tồn kho, là nghiệp vụ dễ sai và ảnh hưởng trực tiếp tới bán hàng | Không tồn tại `Fulfillment.Tests` |
| FU-04 | HIGH | Không có global query filter, kho hoặc vận đơn đã xóa mềm vẫn trả ra | `Fulfillment.Infrastructure/Persistence/Configurations/`, 0 `HasQueryFilter` |
| FU-05 | MEDIUM | Chỉ 4 index cho schema kho vận, thiếu index cho `InventoryItem.SkuId`, `Shipment.OrderId`, `Shipment.TrackingNumber` | `rg HasIndex` trả 4 |
| FU-06 | MEDIUM | Controller trả DTO thô, chưa chốt envelope | `Fulfillment.Api/Controllers/Public/WarehousesController.cs:33-41` |

## 4. Checklist thực thi

### Phase A. Đóng endpoint tồn kho

- [ ] A.1 Quyết định `inventories/initialize` chỉ dành cho nội bộ hoặc chỉ dành cho admin.
- [ ] A.2 Thêm `[RequireRole("admin")]` cho `initialize`, hoặc bật lại cơ chế khóa nội bộ.
- [ ] A.3 `GET /api/v1/inventories/{skuId}` chỉ cho seller sở hữu SKU hoặc admin.
- [ ] A.4 Viết test khẳng định gọi ẩn danh trả 401, gọi sai quyền trả 403.

### Phase B. Bảo vệ dữ liệu vận đơn

- [ ] B.1 `GET /shipments/tracking/{trackingNumber}` kiểm tra người gọi là người mua, người bán của đơn, hoặc admin.
- [ ] B.2 `GET /shipments/order/{orderId}` áp dụng cùng quy tắc.
- [ ] B.3 Không trả địa chỉ đầy đủ cho người không liên quan.
- [ ] B.4 Test hai trường hợp âm: người ngoài nhận 403, người mua đúng nhận 200.

### Phase C. Kho bãi

- [ ] C.1 Rà `WarehousesController`, thêm quyền admin cho thao tác ghi nếu có.
- [ ] C.2 Bổ sung index cho `InventoryItem.SkuId`, `Shipment.OrderId`, `Shipment.TrackingNumber`.
- [ ] C.3 Thêm `HasQueryFilter(x => !x.IsDeleted)` cho toàn bộ entity nghiệp vụ.
- [ ] C.4 Kiểm tra cột số lượng và cước phí có kiểu số phù hợp.
- [ ] C.5 Tạo migration additive và kiểm tra snapshot.

### Phase D. Kiểm thử

- [ ] D.1 Tạo `Fulfillment.Tests`.
- [ ] D.2 Test khởi tạo tồn kho hai lần cho cùng SKU không tạo bản ghi trùng.
- [ ] D.3 Test khóa tồn kho vượt số lượng khả dụng phải trả lỗi.
- [ ] D.4 Test phân trang và lọc.
- [ ] D.5 Test bản ghi đã xóa mềm không xuất hiện.

### Phase E. Tài liệu

- [ ] E.1 Cập nhật tài liệu inventory theo quyết định phân quyền mới.
- [ ] E.2 Chuyển tài liệu đã xong sang `A_Active`.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Fulfillment
dotnet build Fulfillment.sln -c Release
dotnet test  Fulfillment.sln -c Release
```

## 6. Điều kiện hoàn thành

- Không còn endpoint tồn kho mở công khai.
- Vận đơn chỉ đọc được bởi người có quyền.
- Có test cho giữ tồn kho.
- Build và test xanh.
