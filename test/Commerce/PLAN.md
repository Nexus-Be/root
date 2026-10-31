# Commerce Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service giỏ hàng và đơn hàng, cổng 8003, DB `commerce_db` 5435. Hiện mở 3 endpoint trong khi tài liệu cam kết 17.
Không có test. Đã có global query filter và kiểm tra quyền sở hữu đơn hàng.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Commerce.sln -c Release` | Pass, 0 warning, 0 error |
| Test | Không có project test |
| Endpoint hiện thực | 3 |
| Tài liệu `B_none` | 17 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 14 |
| `HasIndex` | 7 |
| Timeout gọi Wallet | 10 giây, không có retry |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| CO-01 | HIGH | Thiếu toàn bộ thao tác ghi giỏ hàng và checkout: thêm món, sửa số lượng, xóa món, tạo đơn, sub-order | So 3 endpoint với 17 file `docs/api/B_none/Commerce/` |
| CO-02 | HIGH | Không có test cho luồng checkout, luồng tiền tệ quan trọng nhất của hệ thống | Không tồn tại `Commerce.Tests` |
| CO-03 | MEDIUM | `WalletClient` chỉ đặt timeout, không có retry, không có circuit breaker, không có fallback khi Wallet chết | `Commerce.Infrastructure/DependencyInjection.cs:46`, `:59` |
| CO-04 | MEDIUM | Route `GET /api/v1/orders/buyer/{buyerId}` nhận `buyerId` từ path, dễ bị hiểu là tin client. Code có `EnsureOwnership` nên chưa phải lỗ hổng, nhưng nên dùng `/api/v1/me/orders` | `Commerce.Api/Controllers/Public/OrdersController.cs:34-48` |
| CO-05 | LOW | Chưa có tài liệu nào được nghiệm thu, 17 tài liệu còn ở `B_none` | `docs/api/B_none/Commerce/` |

## 4. Checklist thực thi

### Phase A. Hợp đồng giỏ hàng

- [ ] A.1 Lập bảng trạng thái 17 tài liệu `B_none`.
- [ ] A.2 Triển khai thêm món vào giỏ.
- [ ] A.3 Triển khai cập nhật số lượng món.
- [ ] A.4 Triển khai xóa món khỏi giỏ.
- [ ] A.5 Triển khai xem giỏ hiện tại đầy đủ dòng hàng.
- [ ] A.6 Mọi thao tác giỏ lấy `buyerId` từ `HttpContext.GetUserId()`, không nhận từ body.

### Phase B. Hợp đồng đơn hàng

- [ ] B.1 Triển khai tạo đơn từ giỏ.
- [ ] B.2 Triển khai hủy đơn kèm kiểm tra trạng thái hợp lệ.
- [ ] B.3 Triển khai danh sách sub-order theo seller.
- [ ] B.4 Triển khai checkout, gọi Wallet qua typed client.
- [ ] B.5 Thêm hỗ trợ header `Idempotency-Key` cho checkout để tránh trừ tiền hai lần.
- [ ] B.6 Cân nhắc thay `orders/buyer/{buyerId}` bằng `me/orders`, cập nhật Gateway và tài liệu.

### Phase C. Khả năng chịu lỗi khi gọi Wallet

- [ ] C.1 Thêm retry có backoff cho lỗi mạng và 5xx.
- [ ] C.2 Thêm circuit breaker.
- [ ] C.3 Định nghĩa hành vi khi Wallet không phản hồi: giữ đơn ở `PendingPayment` thay vì 500.
- [ ] C.4 Ghi log tương quan gồm mã đơn và mã giao dịch ví.
- [ ] C.5 Test giả lập Wallet trả 503, khẳng định đơn không bị đánh dấu đã thanh toán.

### Phase D. Kiểm thử

- [ ] D.1 Tạo `Commerce.Tests`.
- [ ] D.2 Test người dùng A không xem được đơn của người dùng B, nhận 403 `FORBIDDEN`.
- [ ] D.3 Test hủy đơn ở trạng thái không cho phép trả lỗi nghiệp vụ đúng mã.
- [ ] D.4 Test thêm món vượt tồn kho trả lỗi.
- [ ] D.5 Test idempotency: gọi checkout hai lần cùng key chỉ trừ tiền một lần.

### Phase E. Tài liệu

- [ ] E.1 Chuyển tài liệu đã có code và test sang `A_Active`.
- [ ] E.2 Ghi rõ mã lỗi mới nếu bổ sung.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Commerce
dotnet build Commerce.sln -c Release
dotnet test  Commerce.sln -c Release
```

## 6. Điều kiện hoàn thành

- Luồng checkout có test và có bảo vệ idempotency.
- Không có đường nào để người dùng thao tác giỏ hoặc đơn của người khác.
- Build và test xanh.
