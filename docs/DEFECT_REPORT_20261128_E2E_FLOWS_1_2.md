# Báo cáo Kiểm thử E2E & Ghi nhận Lỗi ngày 28/11/2026 (Luồng 1, Luồng 2 & Tiền đề Luồng 3)

Tài liệu này tổng hợp kết quả kiểm thử thực tế trên môi trường triển khai `https://nexus.yuikiri.id.vn` (API Gateway `https://nexus.yuikiri.id.vn/api/gateway`, backend trên Render, GHN Staging `dev-online-gateway.ghn.vn`) và các lỗi đã xác minh nguyên nhân gốc rễ trong mã nguồn Backend (`Nexus-Be`) và Frontend (`Nexus-Fe`).

- Báo cáo chi tiết theo từng service (bao gồm các bản sửa lỗi Backend đã hoàn tất ngày 28/11/2026): `.agents/docs/SERVICE_DEFECTS_AND_FIXES_20261128.md`.
- Các thay đổi đã sửa trước khi chạy kiểm thử của `CommerceService` được ghi riêng tại `docs/CHANGELOG_20261128_BE_COMMERCE_FIXES.md`.

---

## 1. Phạm vi đã kiểm chứng

1. **Luồng 1 — Mua bán thường đa shop, GHN Staging & Giải ngân Ví (Hoàn tất):**
   - Tạo mới gian hàng thứ 2 (`sellerf1_14031` / `Flow1 Electronics Store`, kho `WH_ACDE906D` tại Ba Đình, Hà Nội) song song với gian hàng sẵn có (`seller` / `Nexus Official Store`, kho `WH-OFFICIAL-01` tại Quận 1, TP.HCM).
   - Đặt đơn đa shop `ORD-20261128-838B12` thanh toán bằng Ví Nexus (`541.800 ₫`), tách 2 đơn con độc lập:
     - `SUB-20261128-B061CC` (Shop 1): hàng `200.000 ₫` + ship `20.900 ₫` = `220.900 ₫`, mã vận đơn GHN `LYV3NW`, phí sàn `30%` (`60.000 ₫`), thực nhận Seller 1 `140.000 ₫` (`204.378.477 ₫ → 204.518.477 ₫`).
     - `SUB-20261128-F5C25D` (Shop 2): hàng `300.000 ₫` + ship `20.900 ₫` = `320.900 ₫`, mã vận đơn GHN `LYV3NM`, phí sàn `30%` (`90.000 ₫`), thực nhận Seller 2 `210.000 ₫` (`0 ₫ → 210.000 ₫`).
   - Báo cáo chi tiết và ảnh chụp: `.agents/tests/flow-1/REPORT_FLOW_1.md`.

2. **Luồng 2 — Đánh giá, Uy tín, Nạp ví Stripe & Rút tiền Seller (Hoàn tất):**
   - Gửi 2 đánh giá sản phẩm (`Catalog`) và 2 đánh giá người bán (`User`) cho đơn `ORD-20261128-838B12`; đối soát API lịch sử uy tín của cả Seller 1 (`39 → 40`) và Seller 2 (`50 → 51 → 52`).
   - Kiểm thử nạp ví qua Stripe tại `/buyer/wallet/top-up` (phát hiện lỗi HTTP 500).
   - Liên kết ngân hàng `Vietcombank / 012345678901` cho Seller 2, tạo 2 lệnh rút (`100.000 ₫` và `50.000 ₫`): Staff duyệt hoàn tất lệnh `100.000 ₫` (`transferReference: VCB-E2E-20261128`) và từ chối lệnh `50.000 ₫` (hoàn tiền khóa về khả dụng). Số dư cuối kỳ khớp `110.000 ₫` khả dụng, `0 ₫` đang khóa.
   - Báo cáo chi tiết và ảnh chụp: `.agents/tests/flow-2/REPORT_FLOW_2.md`.

3. **Luồng 3 — Tiền đề Coupon cho COD, Voucher & Hoàn trả (Đã chuẩn bị xong dữ liệu):**
   - Đã tạo mã shop `F3SHOP2` (`FixedAmount` `20.000 ₫`, đơn tối thiểu `100.000 ₫`) và mã sàn `F3SYSTEM` (`FixedAmount` `30.000 ₫`, đơn tối thiểu `100.000 ₫`). Chưa chạy bước checkout đơn COD và hoàn hàng.

4. **Kiểm tra trạng thái repository cục bộ (`Nexus-Be`):**
   - Toàn bộ các submodule đều sạch (không có file sửa dở chưa commit). Ba submodule `src/Services/Fulfillment` (`383e333`), `src/Services/Gateway` (`cbc9f56`) và `src/Services/Log` (`a0d237a`) đang có commit mới hơn con trỏ submodule ở repo gốc.

---

## 2. Danh sách Lỗi Lớn (Major / Blocker)

| Mã lỗi | Dịch vụ / Phạm vi | Hiện tượng thực tế & Bằng chứng | Nguyên nhân gốc rễ (đã đối chiếu mã nguồn) | Hướng khắc phục đề xuất |
| :--- | :--- | :--- | :--- | :--- |
| **`BUG-F1-01`** | `User` → `Notification` | Khi đăng ký tài khoản hoặc xác thực OTP seller, `NotificationService` trả về HTTP `400 VAL_INVALID_INPUT`: `"OTP purpose must be registration, password_reset, or seller_registration."`. Email OTP không gửi được, phải đọc OTP từ log Render. | `User.Application/Services/Auth/AuthService.cs:199,465` truyền `purpose: "email_verification"`, không nằm trong danh sách hợp lệ của `Notification.Application/Services/Email/EmailRequests.cs:15`. | Sửa `purpose` từ `"email_verification"` thành `"registration"` tại `AuthService.cs:199` và `:465`. |
| **`BUG-F1-02`** | `Wallet` (Thiết kế sổ cái) | Đơn `ORD-20261128-838B12` trừ Buyer `541.800 ₫`, trả 2 Seller `350.000 ₫`. Phần phí nền tảng (`150.000 ₫`) và phí ship (`41.800 ₫`) không tạo `WalletTransaction` vào ví hệ thống nào; do Shadow Ledger đang tắt nên `/admin/ledger/journal` ghi `Nợ 0 ₫ / Có 0 ₫`. | `SettleOrderPayoutCommandHandler.cs` chỉ trừ từ `OrderEscrow` và lưu số liệu trên `OrderSettlement`; hạch toán `PLATFORM_REVENUE` phụ thuộc vào Shadow Ledger đang tắt trên môi trường deploy. | Chốt với nhóm sản phẩm: bật Shadow Ledger trên môi trường deploy hoặc bổ sung giao dịch cộng hoa hồng vào ví hệ thống. |
| **`BUG-F1-03`** | `Commerce` → `Fulfillment` | Lúc `13:08:28Z`, Seller 1 bấm xác nhận đơn lần đầu nhận HTTP `503 FULFILLMENT_SERVICE_UNAVAILABLE`, dù GHN đã tạo vận đơn `LYV3NW` và bắn webhook `create` lúc `13:08:49Z` (bị log `isProcessed: false`, `"Shipment not found in database."`). Bấm lại lần 2 mới đồng bộ. | `Commerce.Infrastructure/Services/Fulfillment/FulfillmentClient.cs:553` timeout trước khi `Fulfillment` lưu xong bản ghi `Shipment` hoặc lúc service cold-start trên Render. | Tăng timeout và thêm retry có idempotency theo `ClientOrderCode` khi `Commerce` gọi `POST /api/v1/internal/shipments`, hoặc lưu trạng thái chờ đồng bộ để xử lý webhook đến sớm. |
| **`BUG-F2-01`** | `Wallet` (Stripe Top-up) | Trên `/buyer/wallet/top-up`, gửi `POST /api/v1/wallets/topups/stripe` (`100.000 ₫`) trả về **HTTP `500 INTERNAL_SERVER_ERROR`** (`traceId: 00-e264de15ae0c22fd1a078b832496b2a5-2841fce4e9465fdf-01`). | `StripeSettings.Validate` (`Wallet.Infrastructure/Payments/StripeSettings.cs:40-44`) chỉ log cảnh báo và trả `false` khi thiếu `Stripe:SecretKey` & `Stripe:WebhookSecret`, nên `Wallet.Api/Program.cs:30` vẫn cho khởi chạy. Khi có request tạo phiên Stripe, constructor `StripeCheckoutClient` (`Wallet.Infrastructure/Payments/StripeCheckoutClient.cs:23-26`) ném `InvalidOperationException`, rơi vào nhánh `500` mặc định của `GlobalExceptionHandlerMiddleware.cs:91-96`. | Bổ sung cấu hình `Stripe:SecretKey`, `Stripe:WebhookSecret`, `Stripe:SuccessUrl`, `Stripe:CancelUrl` trên Render cho `WalletService`; đồng thời trả HTTP `503 PAYMENT_PROVIDER_UNAVAILABLE` hoặc `400 STRIPE_NOT_CONFIGURED` nếu chưa cấu hình thay vì `500`. |
| **`BUG-F2-02`** | `Wallet` + `Nexus-Fe` (Rút tiền) | Trên `/seller/withdrawals`, bấm `"Dùng để rút"` trên tài khoản ngân hàng đã lưu khiến `POST /api/v1/wallets/withdrawals` lỗi **HTTP `400 VAL_INVALID_INPUT`**: `"Account number must be between 4 and 100 ASCII letters or digits."`. | `GET /api/v1/wallets/bank-accounts` (`BankAccountResponse.cs:19`) trả về `accountNumber` đã che (`"********8901"`). `BankAccountsPanel.tsx:65` truyền object này vào `onPick(account)` → `SellerWithdrawalForm.tsx:96` gán thẳng chuỗi có dấu `*` vào input, trong khi `WithdrawalWorkflow.cs:135` chỉ nhận số tài khoản thô và chưa nhận `bankAccountId`. | Cho phép truyền `bankAccountId` tùy chọn trong `CreateWithdrawalCommand` để BE tự lấy số tài khoản thật từ DB theo chủ ví, và cập nhật FE gửi `bankAccountId` thay vì chuỗi che mặt nạ. |
| **`BUG-F2-03`** | `User` + `Catalog` (Uy tín & Đánh giá) | 1) Lần đầu `buyer1` đánh giá Seller 2 qua `POST /api/v1/reviews`, API trả `"scoreImpact": 0, "revieweeNewScore": 52`, làm FE hiện thông báo sai rằng đã có đánh giá tích cực gần đây.<br>2) `buyer1` đánh giá sản phẩm của Seller 1 vẫn cộng `+1` (`39 → 40`) dù mới đánh giá tích cực Seller 1 ngày `2026-11-27`. | 1) `User.Application/Services/Review/ReviewService.cs:159-168` kiểm tra cooldown 7 ngày chỉ lọc `PartnerUserId == reviewerId && ChangeAmount > 0` mà **không lọc `Reason == ReputationChangeReason.PositiveReview`**, nên đụng nhầm log `OrderCompleted` do `Commerce` (`OrderService.cs:2346`) ghi ngay trước đó.<br>2) `Catalog.Infrastructure/Services/User/UserClient.cs:189-203` gọi `reputation-adjust` với `Reason = "PositiveReview"` nhưng **không truyền `partnerUserId`**, bỏ qua hoàn toàn cơ chế cooldown 7 ngày ở `InternalUserService.cs:817`. | 1) Thêm điều kiện `l.Reason == ReputationChangeReason.PositiveReview` vào truy vấn cooldown trong `ReviewService.cs:159-168`.<br>2) Truyền `PartnerUserId = currentUserId` từ `ProductReviewService` → `UserClient.AdjustReputationAsync` (hoặc tách rõ quy tắc cộng điểm giữa đánh giá sản phẩm và đánh giá người bán). |

---

## 3. Danh sách Lỗi Nhỏ và Bất tiện UX (Minor)

| Mã lỗi | Phạm vi | Mô tả & Nguyên nhân xác minh từ mã nguồn |
| :--- | :--- | :--- |
| **`BUG-F1-04`** | `Nexus-Fe` (`/register`, `/buyer/become-seller`) | Đăng ký Seller từ `/register` chuyển sang `/buyer/become-seller` không tự submit bản nháp; sau khi xác thực OTP seller, màn `PENDING_APPROVAL` đọc state local rỗng nên hiển thị `Tên gian hàng: —` và `Kho lấy hàng GHN: —`. |
| **`BUG-F1-05`** | `Nexus-Fe` (Định tuyến) | Truy cập `/seller` hoặc `/admin/ledger/reconciliation` trả `404` (route thật là `/seller/products`..., `/admin/reconciliation`); `/seller/reputation` cũng trả `404` (route thật là `/seller/reviews`). |
| **`BUG-F1-06`** | `User` / `Fulfillment` (Seed data) | Các tài khoản seed `seller2`–`seller5` có kho hàng bị `provinceId = null`, `districtId = null`, `wardCode = null` nên không tạo được vận đơn GHN. |
| **`BUG-F2-04`** | `Nexus-Fe` + `Wallet` (Hiển thị rút tiền) | `WithdrawalReadModels.cs:17,33` trả JSON field `createdAt`, còn FE (`src/features/wallet/types/index.ts:73,90,109`, `SellerWithdrawalForm.tsx:131,150`, `StaffWithdrawalsScreen.tsx:63`) đọc `item.requestedAt` (`undefined`), khiến cột `"Gửi lúc"` luôn hiện `"Chưa có dữ liệu"`. Ngoài ra chuỗi số tài khoản che và tên chủ tài khoản hiển thị thiếu khoảng trắng (`"••••••••8901FLOW1 SELLER 14031"`). |
| **`BUG-F2-05`** | `Nexus-Fe` (`PartnerReviewCard.tsx`) | `PartnerReviewCard.tsx:59-62` gọi `setBusy(false)` trong `finally` trước khi `eligibility.reload()` hoàn tất (~300ms), nên bấm gửi lại ngay lập tức vẫn gửi request trùng gây HTTP `409 REVIEW_ALREADY_EXISTS`. |
| **`UX-F3-01`** | `Nexus-Fe` (`/admin/coupons`) | `VoucherManager.tsx:14` và `:141` đặt mặc định `blank.scopeType = "Shop"`, nên khi Admin mở modal tạo mã ở `/admin/coupons`, trường `"Phạm vi"` mặc định chọn `"Gian hàng"` (bắt nhập `ownerSellerId` UUID) thay vì `"Toàn sàn"` (`System`). |

---

## 4. Đề xuất Thứ tự Xử lý Tiếp theo

1. **Xử lý ngay trước khi tiếp tục demo nạp/rút và uy tín:** Sửa `BUG-F2-01` (cấu hình Stripe trên Render + map lỗi cấu hình sang `503`), `BUG-F2-02` (`bankAccountId` khi rút tiền), `BUG-F2-03` (lọc `PositiveReview` trong cooldown của `ReviewService.cs` + truyền `PartnerUserId` từ `Catalog`), và `BUG-F2-04` (sửa `requestedAt` → `createdAt` trên FE).
2. **Xử lý đồng bộ đăng ký & vận đơn:** Sửa `BUG-F1-01` (`"registration"` trong `AuthService.cs`) và `BUG-F1-03` (timeout/retry `CreateShipment`).
3. **Tiếp tục kiểm thử E2E còn lại:** Chạy tiếp Luồng 3 (checkout đơn COD, áp mã `F3SHOP2`/`F3SYSTEM`, hủy đơn con, giao thất bại & hoàn hàng), Luồng 4 (Đấu giá) và Luồng 5 (Báo cáo & Xử phạt).
