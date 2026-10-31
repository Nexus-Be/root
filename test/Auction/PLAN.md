# Auction Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service đấu giá, cổng 8005, DB `auction_db` 5437. Hiện chỉ mở 3 endpoint đọc trong khi tài liệu cam kết 21 endpoint.
Không có project test và không có global query filter cho xóa mềm.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Auction.sln -c Release` | Pass, 0 warning, 0 error |
| Test | Không có project test |
| Endpoint hiện thực | 3 |
| Tài liệu `B_none` | 21 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 0 |
| `HasIndex` | 1 |
| Cascade trong cấu hình viết tay | 0 |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| AU-01 | HIGH | Thiếu phần lớn hợp đồng đã ghi: tạo phiên, cập nhật, hủy, tạo lại, lịch sử trạng thái, phiên theo seller, admin force cancel, cấu hình đấu giá, kết quả phiên | So 3 endpoint tại `Auction.Api/Controllers/Public/` với 21 file `docs/api/B_none/Auction/` |
| AU-02 | HIGH | Không có kiểm thử tự động cho logic đặt giá và chốt phiên, là nghiệp vụ tiền tệ | Không tồn tại thư mục `Auction.Tests` |
| AU-03 | HIGH | Không có global query filter, phiên đã xóa mềm vẫn xuất hiện trong danh sách | `Auction.Infrastructure/Persistence/Configurations/AuctionConfiguration.cs`, không có `HasQueryFilter` |
| AU-04 | MEDIUM | Chỉ 1 index cho toàn bộ schema, thiếu index cho `Status`, `SellerId`, `EndTime` | `rg HasIndex` trả 1 |
| AU-05 | MEDIUM | Controller trả `PagedData<T>` thô, chưa chốt quy ước envelope ở tầng service | `Auction.Api/Controllers/Public/AuctionsController.cs:32-40` |
| AU-06 | LOW | Tài liệu `R148`, `R149` mô tả route `/api/v1/internal/...` đã bị tạm khóa, tài liệu chưa cập nhật | `docs/api/B_none/Auction/R148_*`, `R149_*` |

## 4. Checklist thực thi

### Phase A. Chốt hành vi công khai

- [ ] A.1 Ghi rõ endpoint nào được phép ẩn danh: danh sách phiên đang chạy và chi tiết phiên.
- [ ] A.2 Khẳng định bằng test rằng 2 endpoint đọc trên trả 200 khi không có token.
- [ ] A.3 Khẳng định mọi endpoint ghi trong tương lai phải có `RequireRole` seller hoặc admin.

### Phase B. Bù hợp đồng còn thiếu

- [ ] B.1 Liệt kê từng file `docs/api/B_none/Auction/R*.md` vào bảng trạng thái `IMPLEMENTED` hoặc `NOT_IMPLEMENTED`.
- [ ] B.2 Ưu tiên triển khai nhóm seller: tạo phiên, cập nhật phiên, hủy phiên, danh sách phiên của seller.
- [ ] B.3 Triển khai nhóm admin: force cancel, cấu hình đấu giá, xem trạng thái.
- [ ] B.4 Với mỗi endpoint mới, ghép 1 controller công khai và 1 feature service theo `Services/{Feature}/`.
- [ ] B.5 Với mỗi endpoint mới, thêm route tương ứng vào `Gateway/appsettings.json` nếu chưa phủ bởi `/api/v1/auctions/{**catch-all}`.
- [ ] B.6 Cập nhật tài liệu tương ứng và chuyển sang `A_Active` khi test xanh.

### Phase C. Toàn vẹn dữ liệu

- [ ] C.1 Thêm `builder.HasQueryFilter(x => !x.IsDeleted)` cho mọi entity kế thừa `AuditableEntity`.
- [ ] C.2 Thêm index cho `Auction.Status`, `Auction.SellerId`, `Auction.EndTime`.
- [ ] C.3 Thêm index cho `Bid.AuctionId`, `Bid.BidderId`, `Bid.Amount`.
- [ ] C.4 Kiểm tra `StartPriceAmount`, `BidStepAmount`, `Bid.Amount` đều có `HasPrecision(18, 2)`.
- [ ] C.5 Tạo migration additive và xác nhận `AppDbContextModelSnapshot` đồng bộ.
- [ ] C.6 Viết test khẳng định bản ghi `IsDeleted = true` không xuất hiện trong `ListActiveAuctionsAsync`.

### Phase D. Kiểm thử

- [ ] D.1 Tạo `Auction.Tests` tham chiếu `Auction.Application` và `Auction.Infrastructure`.
- [ ] D.2 Test đặt giá thấp hơn giá hiện tại phải trả lỗi `BID_AMOUNT_TOO_LOW`.
- [ ] D.3 Test đặt giá vào phiên đã kết thúc phải trả lỗi `AUCTION_ENDED`.
- [ ] D.4 Test phân trang biên: `page = 0`, `pageSize = 0`, `pageSize = 101`.
- [ ] D.5 Test enum trả về PascalCase, ví dụ `"Running"`, không trả số.

### Phase E. Dọn tài liệu

- [ ] E.1 Xóa hoặc đánh dấu `DEPRECATED` cho `R148`, `R149`.
- [ ] E.2 Cập nhật `docs/FRONTEND_API_ENDPOINT_MAPPING.md` theo danh sách endpoint thật.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Auction
dotnet build Auction.sln -c Release
dotnet test  Auction.sln -c Release
dotnet ef migrations has-pending-model-changes --project Auction.Infrastructure --startup-project Auction.Api
```

## 6. Điều kiện hoàn thành

- Mỗi tài liệu trong `docs/api/B_none/Auction` có trạng thái rõ ràng.
- Có test cho đặt giá và chốt phiên.
- Không còn endpoint đọc trả về bản ghi đã xóa mềm.
- `dotnet build` và `dotnet test` xanh.
