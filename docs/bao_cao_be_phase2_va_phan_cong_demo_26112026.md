# Backend Phase 2: tính năng đã triển khai và phân công demo

Ngày rà soát: 26/11/2026. Phạm vi: mã nguồn của chín repository backend trong `nexus-dev-be`; đối chiếu thêm báo cáo hồi quy trong `reports/`. Đây là báo cáo đọc mã, không phải biên bản chạy lại toàn bộ hệ thống trong lượt rà soát này.

## Kết luận để chuẩn bị demo

Tám luồng P2-01 đến P2-08 đều có đường xử lý trong backend. Các phần sửa quan trọng sau kế hoạch gốc cũng đã có mã: hoàn tiền đơn con có kiểm escrow, địa chỉ GHN ba cấp, phạt từ chối nhận theo vận đơn và quỹ hoàn sau giải ngân. Nhóm có thể dựng một buổi demo đi từ tạo voucher, mua hàng, giao hàng đến hậu mãi và đối soát. Mỗi màn được công bố là “đã demo” chỉ sau khi thao tác thật qua Gateway trên image đúng commit.

Phạm vi demo cần nói rõ: rút tiền hiện là yêu cầu, giữ tiền và duyệt/trừ ví; mã backend chưa tự chuyển khoản ngân hàng qua Stripe. Quỹ hoàn sau giải ngân mới bật ở QA, chưa bật trên dev dùng chung. GHN và Stripe trong lượt hồi quy QA dùng dịch vụ giả; ca Cloudinary thật của P2-06 còn bị bỏ qua. Sổ bóng phục vụ đối soát, không phải nguồn tiền chính. Kịch bản demo Phase 2 cũ trong `specs/` là tài liệu ý tưởng, không dùng những ví dụ về chuyển khoản tự động, phạt mọi ca giao thất bại hoặc mọi biến động có bút toán chính như khẳng định đã có.

## Tính năng và luồng hoạt động

| Luồng | Đường đi để trình diễn | Trạng thái xác nhận từ mã |
| --- | --- | --- |
| P2-01 Voucher sàn và shop | Admin/seller tạo mã → buyer xem mã khả dụng → Commerce kiểm điều kiện trong báo giá → giữ lượt dùng khi đặt đơn → chốt khi thanh toán, nhả khi đơn chưa trả bị hủy/hết hạn. Mã sàn dùng ngân sách trợ giá; COD không dùng voucher sàn. | Có API tạo, sửa, bật/tắt, kiểm và gợi ý tại [DiscountsController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Public/DiscountsController.cs); luồng báo giá/đặt đơn ở [OrdersController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Public/OrdersController.cs). |
| P2-02 Đánh giá và uy tín hai phía | Buyer đánh giá sản phẩm sau khi đủ điều kiện; buyer đánh giá seller và seller đánh giá buyer theo đơn; admin có thể kiểm duyệt đánh giá. UserService cập nhật điểm uy tín và lưu lịch sử. | [ProductReviewsController.cs](../nexus-dev-be/CatalogService/Catalog.Api/Controllers/Public/ProductReviewsController.cs), [ReviewsController.cs](../nexus-dev-be/UserService/User.Api/Controllers/Public/ReviewsController.cs), [ReviewService.cs](../nexus-dev-be/UserService/User.Application/Services/Review/ReviewService.cs). Không dùng mức cộng/trừ ví dụ của kịch bản cũ làm dữ liệu thật. |
| P2-03 Ví và rút tiền | Người dùng lưu tài khoản ngân hàng, tạo yêu cầu rút → Wallet giữ số dư khả dụng → admin xem và duyệt/từ chối → duyệt thì ghi giao dịch trừ ví, từ chối thì nhả giữ. Có nạp ví qua Stripe webhook. | [WalletsController.cs](../nexus-dev-be/WalletService/Wallet.Api/Controllers/Public/WalletsController.cs), [AdminWalletsController.cs](../nexus-dev-be/WalletService/Wallet.Api/Controllers/Public/AdminWalletsController.cs). Chưa có bằng chứng mã chuyển khoản ngân hàng tự động. |
| P2-04 Sổ bóng và đối soát | Giao dịch ví tạo sự kiện sổ → admin xem journal, bảng cân đối thử, chạy đối soát → xem finding I1–I12 và xử lý trạng thái. Khoản hoàn và giải ngân V2 được kiểm để phát hiện escrow lệch. | [AdminWalletsController.cs](../nexus-dev-be/WalletService/Wallet.Api/Controllers/Public/AdminWalletsController.cs), [RECONCILIATION_CATALOG.md](../nexus-dev-be/WalletService/docs/RECONCILIATION_CATALOG.md). Catalog có khối phê duyệt; I12 không phát hiện sửa SQL trực tiếp ngoài ứng dụng. |
| P2-05 Khiếu nại và hoàn tiền | Buyer mở báo cáo/đề nghị hoàn → staff/admin xem và quyết định → Commerce chỉ chuyển yêu cầu đã duyệt sang hàng chờ Wallet → Wallet kiểm mã đơn cha và escrow trước khi ghi có → Commerce xác nhận kết quả. Với đơn đã giải ngân, admin có thể xử lý ca bằng quỹ hoàn, thu hồi tối đa số dư khả dụng của seller và đưa phần thiếu vào `NeedsFinance`. | [AdminReportsController.cs](../nexus-dev-be/UserService/User.Api/Controllers/Public/AdminReportsController.cs), [RefundsController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Public/RefundsController.cs), [AdminRefundFundCasesController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Admin/AdminRefundFundCasesController.cs). Quỹ hoàn mặc định tắt ngoài QA. |
| P2-06 Tố cáo và kiểm duyệt sản phẩm | Buyer gửi báo cáo sản phẩm → staff/admin đọc hàng đợi → quyết định xử lý → Catalog thay trạng thái hiển thị sản phẩm; người liên quan nhận thông báo. | [ProductReportsController.cs](../nexus-dev-be/CatalogService/Catalog.Api/Controllers/Public/ProductReportsController.cs), [AdminProductReportsController.cs](../nexus-dev-be/CatalogService/Catalog.Api/Controllers/Public/AdminProductReportsController.cs), [AdminProductsController.cs](../nexus-dev-be/CatalogService/Catalog.Api/Controllers/Public/AdminProductsController.cs). Bài kiểm tải ảnh Cloudinary thật chưa đạt trong QA kín. |
| P2-07 Giao hàng, hoàn kho và từ chối nhận | Seller tiếp nhận đơn → Fulfillment tạo vận đơn → GHN gửi webhook → Commerce cập nhật trạng thái. Nếu hàng trả về, seller xác nhận đã nhận thì Fulfillment hoàn tồn. Với từ chối nhận, Commerce đối chiếu từng lần giao thất bại theo mã vận đơn, thời gian và bảng mã được duyệt rồi mới phạt buyer; admin có đường thu hồi phạt. Thiếu bằng chứng thì `Unknown`, không phạt. | [ShipmentsController.cs](../nexus-dev-be/FulfillmentService/Fulfillment.Api/Controllers/Public/ShipmentsController.cs), [AdminBuyerRefusalPenaltiesController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Admin/AdminBuyerRefusalPenaltiesController.cs), [DeliveryFailureAttempts migration](../nexus-dev-be/CommerceService/Commerce.Infrastructure/Persistence/Migrations/20261126100000_AddDeliveryFailureAttempts.cs). Chưa có payload từ chuyến giao GHN thật. |
| P2-08 Quản trị vận hành và nhật ký | Các service ghi sự kiện, LogService gom nhật ký → admin tra cứu, xem cảnh báo bảo mật, kiểm tra sức khỏe hệ thống và cấu hình. Notification phát thông báo cho các sự kiện nghiệp vụ. | [AdminAuditController.cs](../nexus-dev-be/LogService/Log.Api/Controllers/Public/AdminAuditController.cs), [AuctionActivityController.cs](../nexus-dev-be/NotificationService/Notification.Api/Controllers/Public/AuctionActivityController.cs), [AdminConfigsController.cs](../nexus-dev-be/UserService/User.Api/Controllers/Public/AdminConfigsController.cs). |

Hai luồng liên kết nên đưa vào demo vì nối các phân hệ trên:

1. **Đấu giá:** seller đưa sản phẩm đủ điều kiện lên phiên → buyer giữ cọc, đặt giá hoặc mua ngay → Auction chốt người thắng/Second Chance → Commerce tạo đơn đấu giá → buyer cung cấp địa chỉ GHN, trả phần phí giao hàng còn thiếu → seller tiếp nhận, giao hàng → hoàn cọc hoặc giải ngân theo kết quả. `Buy Now` khóa tiền hàng trong ví, không đồng nghĩa toàn bộ đơn đã trả xong. Căn cứ: [AuctionsController.cs](../nexus-dev-be/AuctionService/Auction.Api/Controllers/Public/AuctionsController.cs), [DepositsController.cs](../nexus-dev-be/AuctionService/Auction.Api/Controllers/Public/DepositsController.cs), [AuctionOrdersController.cs](../nexus-dev-be/CommerceService/Commerce.Api/Controllers/Public/AuctionOrdersController.cs).
2. **Địa chỉ và giải ngân:** buyer/seller chọn tỉnh, huyện, xã từ GHN hoặc cache GHN có nguồn → User/Fulfillment/Commerce xác minh bộ mã trước khi lưu hoặc báo giá → đơn lưu tên đã xác nhận → tiền đơn được giữ trong escrow → khi hoàn tất, Wallet phân bổ seller, phí và khoản thu hộ vận chuyển. Không có nguồn địa chỉ đáng tin cậy thì trả 503 và không lưu địa chỉ giả. Căn cứ: [ShippingController.cs](../nexus-dev-be/FulfillmentService/Fulfillment.Api/Controllers/Public/ShippingController.cs), [ShippingChain.cs](../nexus-dev-be/CommerceService/Commerce.Application/Services/Common/ShippingChain.cs), [WalletsController.cs](../nexus-dev-be/WalletService/Wallet.Api/Controllers/Public/WalletsController.cs).

## Phân công chuẩn bị và trình diễn

Chủ dự án đã xác nhận ba người phụ trách: Thịnh ở Commerce, Trí ở Wallet và Minh ở Fulfillment. Tên ở các service khác mới dựa trên lịch sử tác giả Git, nên phần phân vai của họ là đề xuất và cần xác nhận trước khi chốt lịch demo. Tác giả commit không nhất thiết là người đang phụ trách service.

| Người | Chuẩn bị trước buổi demo | Phần trình diễn / điểm bàn giao |
| --- | --- | --- |
| **Thịnh** (Commerce, đã xác nhận) | Chuẩn bị buyer, seller, báo giá, đơn ví/COD, voucher, hoàn tiền và đơn đấu giá; kiểm trạng thái đơn trước/sau từng thao tác. | Dẫn checkout, đơn thường và đơn đấu giá, quyết định hoàn tiền và bàn giao mã đơn cho Trí, Minh. |
| **Trí** (Wallet, đã xác nhận) | Chuẩn bị ví buyer/seller, cọc, escrow, yêu cầu rút, finding đối soát và cờ hoàn tiền/quỹ hoàn trên stack demo. | Giải thích dòng tiền: giữ cọc, thanh toán, hoàn tiền, giải ngân, rút ví và đối soát. Chỉ bật quỹ hoàn trên QA cô lập. |
| **Minh** (Fulfillment, đã xác nhận) | Chuẩn bị địa chỉ GHN hợp lệ, kho đủ mã tỉnh/huyện/xã, vận đơn và tình huống giao trả. | Demo báo giá ship, tạo vận đơn sau khi seller tiếp nhận, cập nhật giao hàng và xác nhận hoàn kho; bàn giao sự kiện cho Thịnh. |
| **Phạm Nguyễn Hùng Anh** (Auction, đề xuất từ Git) | Tạo phiên, buyer có cọc, trạng thái phiên và một kết quả Second Chance; kiểm thời gian đủ cho demo. | Demo đặt giá, mua ngay, người thắng; bàn giao kết quả phiên cho Thịnh. |
| **Phạm Mạnh Quỳnh** (Catalog) | Chuẩn bị sản phẩm có biến thể/ảnh, đánh giá hợp lệ, một báo cáo vi phạm đang chờ và tài khoản staff. | Demo đánh giá, tố cáo và quyết định kiểm duyệt; bàn giao trạng thái sản phẩm cho phần buyer. |
| **Trần Hiển Vinh** (User, Gateway, đề xuất từ Git) | Kiểm role buyer/seller/staff/admin, đường qua Gateway, hồ sơ shop và dữ liệu uy tín. | Demo đăng ký seller, quyền truy cập và thay đổi uy tín/thu hồi phạt. |
| **Duy Trương** (Notification, đề xuất từ Git) | Kiểm worker và một mẫu thông báo về đơn/đấu giá/báo cáo. | Chỉ ra thông báo phát sinh ở các mốc đã demo. |
| **Tác giả Git `Yuikiri`** (LogService, Gateway, đề xuất từ Git) | Kiểm nhật ký tập trung, cảnh báo và trang sức khỏe; chuẩn bị một sự kiện tra theo mã đơn. | Demo dấu vết kiểm toán và sức khỏe service ở cuối; cần xác nhận tên người trình bày. |

Các vai Auction, Catalog, User/Gateway, Notification và LogService cần xác nhận với nhóm. Nếu người phụ trách không có mặt, Thịnh nhận bàn giao đầu ra Auction/Catalog, Trí trình bày đối soát, Minh trình bày vận chuyển; người dẫn giao diện được phân riêng theo lịch FE.

## Thứ tự chạy buổi demo và cổng kiểm trước giờ bắt đầu

| Chặng | Người dẫn | Kết quả phải nhìn thấy |
| --- | --- | --- |
| 1. Mở shop, kho, sản phẩm | Minh; Vinh và Quỳnh nếu xác nhận tham gia | Seller được duyệt, địa chỉ GHN hợp lệ, sản phẩm hiển thị đúng trạng thái. |
| 2. Voucher và đơn thường | Thịnh, Minh, Trí | Báo giá có giảm giá/ship; đơn được tạo; seller tiếp nhận rồi có vận đơn. |
| 3. Đấu giá | Thịnh, Trí; Hùng Anh nếu xác nhận tham gia | Cọc, giá, kết quả thắng/Second Chance và đơn đấu giá có bước phí giao hàng riêng. |
| 4. Hậu mãi | Thịnh, Minh, Trí | Báo cáo/hoàn được quyết định trước khi trả tiền; hoàn kho và phạt chỉ khi đủ chứng cứ; có đường thu hồi phạt. |
| 5. Tiền và quản trị | Trí; Yuikiri và Duy nếu xác nhận tham gia | Yêu cầu rút giữ tiền rồi admin quyết định; journal/finding, audit log và thông báo tra được theo mã tham chiếu. |

Trước khi bắt đầu, người phụ trách stack ghi lại HEAD và image ID của chín service, kiểm Gateway/DB/worker khỏe, chuẩn bị dữ liệu mới cho từng chặng và chạy một lượt rehearsal đúng thứ tự trên stack demo. Ghi rõ ca nào dùng GHN/Stripe giả; ca Cloudinary thật chưa chạy thì bỏ khỏi lời tuyên bố đã nghiệm thu. Không dùng endpoint tua thời gian hoặc tạo tài khoản thử trên môi trường production. Chuẩn bị ảnh chụp/truy vấn chỉ đọc làm phương án dự phòng khi webhook đến muộn; không sửa tay số dư ví để “đẹp” kết quả.

## Còn mở trước khi gọi là demo đầy đủ trên môi trường thật

- T26: chứng cứ tích hợp Cloudinary, Stripe và GHN sandbox thật còn thiếu; ca `p206` Cloudinary có 1 SKIP trong [báo cáo hồi quy gần nhất](ket_qua_hoi_quy_qa_final_full4.md).
- T30: cần chốt ngân sách/quỹ thật và rà I3–I5/G8 trước khi bật ngoài QA. T17 đã có quy tắc và cờ ở dev nhưng chưa có payload vận chuyển thật để đối chiếu.
- Rút tiền hiện chưa chuyển khoản ngân hàng tự động; việc gỡ route giải ngân V1 và kiểm cấu hình Gateway ở môi trường dùng chung nằm ngoài phạm vi kỹ thuật cục bộ đã chốt.
- Backend có API không đồng nghĩa frontend đã nghiệm thu. Buổi demo cần chạy qua giao diện và Gateway đúng phiên bản, ghi lại thao tác, role, kết quả và lỗi thực tế.

Nguồn trạng thái chạy thử: [báo cáo BE ngày 26/11](bao_cao_cuoi_cung_phase2_26112026.md), [hồi quy QA](ket_qua_hoi_quy_qa_final_full4.md). Những số liệu test trong hai tài liệu này được dẫn lại, không được chạy lại trong lượt lập báo cáo này.
