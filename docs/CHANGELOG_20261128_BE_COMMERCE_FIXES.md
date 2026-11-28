# Ghi nhận sửa lỗi Backend Commerce ngày 28/11/2026

Trước khi chạy kiểm thử luồng mua bán đa shop trên `https://nexus.yuikiri.id.vn/`, các thay đổi và lỗi đang tồn đọng tại `src/Services/Commerce` đã được xử lý và kiểm chứng ở chế độ Release.

## Các thay đổi đã thực hiện tại CommerceService

1. Gỡ bỏ endpoint hủy đơn cha (`/api/v1/orders/{orderId}/cancel`) trong `Commerce.Api/Controllers/Public/OrdersController.cs`, giữ lại luồng hủy riêng từng đơn con qua `POST /api/v1/sub-orders/{subOrderId}/cancel` trước khi người bán xác nhận và trước khi có mã vận đơn.
2. Sửa `DiscountService.ValidateVoucherAsync` tại `src/Services/Commerce/Commerce.Application/Services/Discount/DiscountService.cs` để trả về `ValidateVoucherResponse(IsValid = false)` kèm mã lý do cụ thể (`VOUCHER_EXPIRED`, `VOUCHER_NOT_STARTED`, `VOUCHER_MIN_ORDER_NOT_MET`, `VOUCHER_OUT_OF_STOCK`, `VOUCHER_SCOPE_MISMATCH`) thay vì ném ngoại lệ `VOUCHER_NOT_APPLICABLE`.
3. Sửa `CartService.GetGroupedCartAsync` tại `src/Services/Commerce/Commerce.Application/Services/Cart/CartService.cs` để lấy tên gian hàng thực tế từ `IUserClient.GetSellerShopAsync`, chỉ dùng tên rút gọn `Shop {ID}` khi không tra cứu được.
4. Sửa `OrderService.CreateOrderAsync` tại `src/Services/Commerce/Commerce.Application/Services/Order/OrderService.cs` ở hai điểm:
   - Ánh xạ `DiscountCodeUsage.SubOrderId` theo `DiscountCodeId` thay vì vị trí mảng, tránh gán nhầm voucher giữa các gian hàng khi thứ tự GUID khác thứ tự phân bổ.
   - Làm mới `UnitPriceSnapshot` và `SubtotalAmount` trong giỏ hàng trước khi trả về `VOUCHER_NO_LONGER_VALID` khi giá sản phẩm giảm làm mất điều kiện giá trị đơn tối thiểu của voucher.

## Kết quả build và kiểm thử

- `dotnet build src/Services/Commerce/Commerce.sln -c Release`: thành công, 0 lỗi, 0 cảnh báo.
- `dotnet test src/Services/Commerce/Commerce.sln -c Release`: 716 passed, 0 failed, 13 skipped (tổng 729).

Chi tiết đầy đủ trong phạm vi service được lưu tại `src/Services/Commerce/docs/CHANGELOG_20261128_COMMERCE_FIXES.md`.
