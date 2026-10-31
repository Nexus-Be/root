# Catalog Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service danh mục và sản phẩm, cổng 8002, DB `category_db` 5434. Hiện mở 5 endpoint, chủ yếu là đọc.
Không có test, không có global query filter, chỉ 1 index.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Catalog.sln -c Release` | Pass, 0 warning, 0 error |
| Test | Không có project test |
| Endpoint hiện thực | 5 |
| Tài liệu `B_none` | 17 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 0 |
| `HasIndex` | 1 |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| CA-01 | HIGH | Thiếu 12 hợp đồng đã ghi: tạo, sửa, xóa danh mục, sửa và xóa sản phẩm, quản lý biến thể | So 5 endpoint với 17 file `docs/api/B_none/Catalog/` |
| CA-02 | HIGH | Không có kiểm thử cho nghiệp vụ sản phẩm và phân quyền seller | Không tồn tại `Catalog.Tests` |
| CA-03 | HIGH | Không có global query filter, sản phẩm đã xóa mềm vẫn trả ra | `Catalog.Infrastructure/Persistence/Configurations/`, không có `HasQueryFilter` |
| CA-04 | MEDIUM | Chỉ 1 index cho schema sản phẩm, thiếu index cho `CategoryId`, `SellerId`, `Status`, `Sku` | `rg HasIndex` trả 1 |
| CA-05 | MEDIUM | Controller trả DTO và `PagedData` thô, chưa chốt envelope | `Catalog.Api/Controllers/Public/ProductsController.cs:34-42` |

## 4. Checklist thực thi

### Phase A. Phân quyền

- [ ] A.1 Xác nhận `GET /api/v1/products` và `GET /api/v1/categories` được phép ẩn danh, ghi vào ADR.
- [ ] A.2 `POST /api/v1/products` đã có `RequireRole("seller", "admin")`, bổ sung test khẳng định buyer bị 403.
- [ ] A.3 Bổ sung kiểm tra `SellerId` lấy từ `HttpContext.GetUserId()`, không nhận từ body.
- [ ] A.4 Viết test khẳng định seller không sửa được sản phẩm của seller khác.

### Phase B. Bù hợp đồng còn thiếu

- [ ] B.1 Lập bảng trạng thái cho 17 tài liệu `B_none`.
- [ ] B.2 Triển khai tạo, sửa, xóa danh mục.
- [ ] B.3 Triển khai sửa, xóa sản phẩm.
- [ ] B.4 Triển khai quản lý biến thể sản phẩm.
- [ ] B.5 Mỗi feature mới đặt đúng `Catalog.Application/Services/{Feature}/` với 4 file chuẩn.
- [ ] B.6 Cập nhật tài liệu và chuyển `A_Active` khi test xanh.

### Phase C. Toàn vẹn dữ liệu

- [ ] C.1 Thêm `HasQueryFilter(x => !x.IsDeleted)` cho toàn bộ entity nghiệp vụ.
- [ ] C.2 Thêm index cho `Product.CategoryId`, `Product.SellerId`, `Product.Status`.
- [ ] C.3 Thêm unique index có filter cho `ProductVariant.Sku`.
- [ ] C.4 Xác nhận `Product.Price` và giá biến thể có `HasPrecision(18, 2)`.
- [ ] C.5 Tạo migration additive, kiểm tra snapshot đồng bộ.

### Phase D. Kiểm thử

- [ ] D.1 Tạo `Catalog.Tests`.
- [ ] D.2 Test tạo sản phẩm với giá âm trả `VAL_INVALID_INPUT`.
- [ ] D.3 Test tạo sản phẩm khi category không tồn tại trả `CATEGORY_NOT_FOUND`.
- [ ] D.4 Test phân trang và lọc theo category.
- [ ] D.5 Test sản phẩm đã xóa mềm không xuất hiện trong danh sách.

### Phase E. Tài liệu

- [ ] E.1 Đánh dấu `NOT_IMPLEMENTED` cho tài liệu chưa có code.
- [ ] E.2 Đồng bộ `docs/FRONTEND_API_ENDPOINT_MAPPING.md`.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Catalog
dotnet build Catalog.sln -c Release
dotnet test  Catalog.sln -c Release
```

## 6. Điều kiện hoàn thành

- Seller không thể thao tác sản phẩm ngoài quyền sở hữu, có test chứng minh.
- Bản ghi xóa mềm không rò rỉ ra API.
- Mỗi tài liệu có trạng thái rõ ràng.
- Build và test xanh.
