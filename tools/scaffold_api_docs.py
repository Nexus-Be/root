#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scaffold_api_docs.py
Tự động chuẩn hóa và sinh toàn bộ hồ sơ tài liệu API độc lập vào docs/api/B_none/{Service}/
Tuân thủ 100% template docs/api/API_DOC_TEMPLATE.md và đặc tả chi tiết Enum cho Frontend.
"""

import os
import re
import json

SERVICES = [
    'User', 'Catalog', 'Commerce', 'Auction', 'Fulfillment', 
    'Wallet', 'Notification', 'Log', 'CheckHeal', 'Gateway'
]

BASE_DIR = 'docs/api/B_none'
for s in SERVICES:
    os.makedirs(os.path.join(BASE_DIR, s), exist_ok=True)

ENUM_SPECS = {
    'UserStatus': {
        'field': 'status',
        'type': 'UserStatus',
        'values': [
            (0, 'PendingVerification', '**Chờ xác thực OTP**: Tài khoản mới đăng ký, chưa kích hoạt email/SĐT. Badge vàng (Warning).'),
            (1, 'Active', '**Đang hoạt động**: Tài khoản đã kích hoạt, đầy đủ quyền mua/bán theo role. Badge xanh lá (Success).'),
            (2, 'Banned', '**Bị cấm / Khóa**: Tài khoản vi phạm quy định, bị Admin khóa. Badge đỏ (Danger).'),
            (3, 'Deleted', '**Đã xóa mềm**: Tài khoản đã hủy hoặc xóa khỏi hệ thống. Badge xám (Muted).')
        ]
    },
    'SellerProfileStatus': {
        'field': 'status',
        'type': 'SellerProfileStatus',
        'values': [
            (0, 'Pending', '**Chờ duyệt hồ sơ**: Seller nộp đơn đăng ký mở Shop, chờ Staff/Admin xét duyệt. Badge vàng (Warning).'),
            (1, 'Approved', '**Đã duyệt mở Shop**: Hồ sơ hợp lệ, người dùng chính thức trở thành Seller. Badge xanh lá (Success).'),
            (2, 'Rejected', '**Bị từ chối**: Hồ sơ bị từ chối do thiếu giấy tờ hoặc thông tin không hợp lệ. Badge đỏ (Danger).')
        ]
    },
    'Gender': {
        'field': 'gender',
        'type': 'Gender',
        'values': [
            (0, 'Unspecified', '**Chưa xác định / Không tiết lộ**: Người dùng chưa chọn giới tính.'),
            (1, 'Male', '**Nam**: Giới tính nam.'),
            (2, 'Female', '**Nữ**: Giới tính nữ.'),
            (3, 'Other', '**Khác**: Giới tính khác.')
        ]
    },
    'TrustLevel': {
        'field': 'trustLevel',
        'type': 'TrustLevel',
        'values': [
            (0, 'Untrusted', '**Không đáng tin cậy** (<50 điểm): Bị hạn chế đấu giá và đăng bài. Badge đỏ (Danger).'),
            (1, 'Probation', '**Thời gian thử thách** (50-70 điểm): Cần theo dõi thêm, giới hạn số phiên đấu giá. Badge cam (Warning).'),
            (2, 'Standard', '**Tiêu chuẩn** (70-85 điểm): Uy tín bình thường, tham gia mọi tính năng sàn. Badge xanh dương (Info).'),
            (3, 'Good', '**Tốt** (85-95 điểm): Uy tín cao, ưu tiên hiển thị và hỗ trợ. Badge xanh lá (Success).'),
            (4, 'Excellent', '**Xuất sắc** (>95 điểm): Huy hiệu Người bán uy tín / Người mua tin cậy. Badge tím / vàng kim (Gold/Vip).')
        ]
    },
    'ReportStatus': {
        'field': 'status',
        'type': 'ReportStatus',
        'values': [
            (0, 'Pending', '**Chờ tiếp nhận**: Đơn tố cáo mới gửi, đang chờ Staff phân công thụ lý. Badge vàng (Warning).'),
            (1, 'UnderReview', '**Đang xác minh**: Staff đang kiểm tra bằng chứng và đối chất. Badge xanh dương (Info).'),
            (2, 'Resolved', '**Đã xử lý**: Đã có kết luận và áp dụng chế tài kỷ luật. Badge xanh lá (Success).'),
            (3, 'Rejected', '**Bác bỏ**: Đơn tố cáo không đủ chứng cứ hoặc sai sự thật. Badge xám (Muted).')
        ]
    },
    'ReportViolationType': {
        'field': 'violationType',
        'type': 'ReportViolationType',
        'values': [
            (0, 'Fraud', '**Lừa đảo**: Gian lận tiền bạc, không giao hàng hoặc hàng giả. Badge đỏ (Danger).'),
            (1, 'Harassment', '**Quấy rối / Xúc phạm**: Ngôn từ đe dọa, xúc phạm danh dự đối tác. Badge cam (Warning).'),
            (2, 'Counterfeit', '**Hàng giả / Nhái**: Bán hàng vi phạm sở hữu trí tuệ. Badge đỏ (Danger).'),
            (3, 'Spam', '**Spam / Rác**: Đăng bài rác, gửi tin nhắn quảng cáo phiền toái. Badge vàng (Warning).'),
            (4, 'Other', '**Vi phạm khác**: Các lý do vi phạm khác quy chế sàn. Badge xám (Secondary).')
        ]
    },
    'PenaltyStatus': {
        'field': 'status',
        'type': 'PenaltyStatus',
        'values': [
            (0, 'Active', '**Đang hiệu lực**: Chế tài đang được thi hành trên tài khoản. Badge đỏ (Danger).'),
            (1, 'Expired', '**Đã hết hạn**: Thời gian phạt đã kết thúc, quyền lợi tự động phục hồi. Badge xám (Muted).'),
            (2, 'Revoked', '**Đã hủy bỏ / Ân xá**: Ban quản trị xem xét khiếu nại và gỡ bỏ án phạt. Badge xanh lá (Success).')
        ]
    },
    'PenaltyType': {
        'field': 'penaltyType',
        'type': 'PenaltyType',
        'values': [
            (0, 'Warning', '**Cảnh cáo**: Nhắc nhở người dùng bằng thông báo hệ thống. Badge vàng (Warning).'),
            (1, 'DeductPoints', '**Trừ điểm uy tín**: Khấu trừ điểm uy tín theo mức độ vi phạm. Badge cam (Warning).'),
            (2, 'SuspendBidding3Days', '**Tạm đình chỉ đấu giá 3 ngày**: Khóa quyền đặt giá và tạo phiên trong 72 giờ. Badge đỏ (Danger).'),
            (3, 'BanAccount', '**Khóa tài khoản vĩnh viễn**: Cấm đăng nhập và truy cập toàn bộ dịch vụ. Badge đỏ đậm (Dark Danger).'),
            (4, 'Other', '**Chế tài khác**: Hình thức phạt tùy chỉnh của ban quản trị. Badge xám (Secondary).')
        ]
    },
    'PenaltyViolationType': {
        'field': 'violationType',
        'type': 'PenaltyViolationType',
        'values': [
            (0, 'PaymentTimeout', '**Quá hạn thanh toán**: Người mua thắng phiên nhưng không thanh toán đơn đúng hạn.'),
            (1, 'AuctionNonPayment', '**Bùng hàng đấu giá**: Cố tình không trả tiền phiên đấu giá giá trị cao.'),
            (2, 'CancellationWithoutReason', '**Hủy đơn không lý do chính đáng**: Seller/Buyer tự ý hủy giao dịch gây thiệt hại.'),
            (3, 'Fraud', '**Hành vi gian lận**: Tạo nick ảo thổi giá (shill bidding) hoặc lừa đảo.'),
            (4, 'Other', '**Lý do khác**: Các vi phạm điều khoản dịch vụ khác.')
        ]
    },
    'ReputationChangeReason': {
        'field': 'reason',
        'type': 'ReputationChangeReason',
        'values': [
            (0, 'PositiveReview', '**Đánh giá tích cực (+ điểm)**: Nhận đánh giá 4-5 sao từ đối tác. Badge xanh lá (+).'),
            (1, 'NegativeReview', '**Đánh giá tiêu cực (- điểm)**: Nhận đánh giá 1-2 sao từ đối tác. Badge đỏ (-).'),
            (2, 'OrderCompleted', '**Giao dịch hoàn tất thành công (+ điểm)**: Đơn hàng giao nhận trọn vẹn. Badge xanh lá (+).'),
            (3, 'AuctionPaymentTimeout', '**Quá hạn thanh toán đấu giá (- điểm)**: Không thanh toán đơn đấu giá đúng hạn. Badge đỏ (-).'),
            (4, 'DisputeCompensation', '**Bồi hoàn sau khiếu nại (+/- điểm)**: Điều chỉnh điểm sau giải quyết tranh chấp. Badge cam.'),
            (5, 'ManualAdjustment', '**Điều chỉnh thủ công từ Admin**: Quản trị viên can thiệp trực tiếp điểm uy tín. Badge xanh dương (Info).'),
            (6, 'ViolationPenalty', '**Phạt vi phạm quy chế sàn (- điểm)**: Bị xử phạt từ đơn tố cáo đã duyệt. Badge đỏ (-).')
        ]
    },
    'ReviewerRole': {
        'field': 'reviewerRole',
        'type': 'ReviewerRole',
        'values': [
            (0, 'Buyer', '**Người mua đánh giá**: Buyer chấm điểm và nhận xét Shop / Seller. Badge xanh dương.'),
            (1, 'Seller', '**Người bán đánh giá**: Seller nhận xét về thái độ thanh toán của Buyer. Badge cam.')
        ]
    },
    'RoleType': {
        'field': 'role',
        'type': 'RoleType',
        'values': [
            (0, 'Buyer', '**Khách hàng / Người mua**: Mua sắm, tham gia đấu giá, quản lý ví cá nhân.'),
            (1, 'Seller', '**Chủ cửa hàng / Người bán**: Đăng bán sản phẩm, mở phiên đấu giá, giao hàng.'),
            (2, 'SupportStaff', '**Nhân viên vận hành**: Hỗ trợ khách hàng, duyệt hồ sơ Seller, xử lý báo cáo.'),
            (3, 'Admin', '**Quản trị viên**: Quản lý toàn bộ hệ sinh thái, phân quyền, cấu hình hệ thống.')
        ]
    },
    'ProductStatus': {
        'field': 'status',
        'type': 'ProductStatus',
        'values': [
            (0, 'Draft', '**Bản nháp**: Sản phẩm đang tạo dở, chưa công khai lên sàn. Badge xám (Secondary).'),
            (1, 'Active', '**Đang mở bán**: Hiển thị trên sàn, người mua có thể xem và đặt hàng. Badge xanh lá (Success).'),
            (2, 'Inactive', '**Tạm ngưng bán / Ẩn**: Seller tạm ẩn hoặc Admin khóa sản phẩm. Badge cam/đỏ (Danger).')
        ]
    },
    'VariantStatus': {
        'field': 'status',
        'type': 'VariantStatus',
        'values': [
            (0, 'Active', '**Còn hoạt động**: Biến thể SKU có thể chọn và mua được. Badge xanh lá.'),
            (1, 'Inactive', '**Ngưng hoạt động**: Biến thể SKU bị vô hiệu hóa hoặc hết hàng. Badge xám.')
        ]
    },
    'CartStatus': {
        'field': 'status',
        'type': 'CartStatus',
        'values': [
            (0, 'Active', '**Giỏ hàng đang sử dụng**: Chứa các mặt hàng người dùng đang chọn. Badge xanh lá.'),
            (1, 'CheckedOut', '**Đã thanh toán**: Toàn bộ món hàng đã chuyển thành đơn hàng. Badge xanh dương.'),
            (2, 'Abandoned', '**Bỏ quên / Hết hạn**: Giỏ hàng không hoạt động trong thời gian dài. Badge xám.')
        ]
    },
    'OrderStatus': {
        'field': 'status',
        'type': 'OrderStatus',
        'values': [
            (0, 'PendingPayment', '**Chờ thanh toán**: Đơn hàng vừa tạo, chờ quét QR hoặc thanh toán ví/VNPay. Badge vàng (Warning).'),
            (1, 'PaymentProcessing', '**Đang xử lý giao dịch**: Cổng thanh toán đang đối soát tiền. Badge xanh dương (Info).'),
            (2, 'Paid', '**Đã thanh toán thành công**: Tiền đã ghi nhận, chuyển sang các đơn con (SubOrders) cho Shop chuẩn bị hàng. Badge xanh lá (Success).'),
            (3, 'Cancelled', '**Đã hủy đơn**: Người mua hủy hoặc quá hạn thanh toán. Badge đỏ (Danger).'),
            (4, 'Expired', '**Hết hạn thanh toán**: Quá thời gian quy định (15-30 phút) mà không thanh toán. Badge xám (Muted).')
        ]
    },
    'SubOrderStatus': {
        'field': 'status',
        'type': 'SubOrderStatus',
        'values': [
            (0, 'PendingPayment', '**Chờ thanh toán chung**: Đơn cha chưa thanh toán. Badge vàng (Warning).'),
            (1, 'Paid', '**Đã thanh toán**: Đang chờ Seller xác nhận đơn (trong vòng 24h). Badge xanh dương (Info).'),
            (2, 'Confirmed', '**Shop đã tiếp nhận**: Seller bấm xác nhận chuẩn bị gói hàng. Badge xanh lá nhạt (Primary).'),
            (3, 'Shipping', '**Đang giao hàng**: Đơn vị vận chuyển đã lấy hàng và đang chuyển phát. Badge xanh dương đậm (Info).'),
            (4, 'Delivered', '**Đã giao hàng**: Khách đã nhận được kiện hàng từ bưu tá. Badge tím (Purple).'),
            (5, 'Completed', '**Đã hoàn tất trọn vẹn**: Khách bấm hoàn tất hoặc hết thời gian khiếu nại, tiền mở khóa cho Seller. Badge xanh lá (Success).'),
            (6, 'Cancelled', '**Đã hủy**: Shop từ chối hoặc người mua yêu cầu hủy hợp lệ. Badge đỏ (Danger).'),
            (7, 'Refunded', '**Đã hoàn tiền**: Tiền hàng đã hoàn trả về ví cho người mua. Badge cam (Warning).')
        ]
    },
    'PaymentMethod': {
        'field': 'paymentMethod',
        'type': 'PaymentMethod',
        'values': [
            (0, 'Wallet', '**Ví tiền Nexus**: Trừ tiền trực tiếp vào số dư ví khả dụng của tài khoản.'),
            (1, 'VnPay', '**Cổng thanh toán VNPay**: Quét mã QR VNPAY-QR hoặc thẻ ATM / Visa / Mastercard.'),
            (2, 'Cod', '**Thanh toán khi nhận hàng (COD)**: Trả tiền mặt cho shipper khi nhận kiện hàng.')
        ]
    },
    'AuctionStatus': {
        'field': 'status',
        'type': 'AuctionStatus',
        'values': [
            (0, 'Draft', '**Bản nháp**: Phiên đấu giá đang cấu hình, chưa lên lịch. Badge xám (Secondary).'),
            (1, 'Scheduled', '**Đã lên lịch bắt đầu**: Đã công bố, đếm ngược tới giờ mở phiên. Badge xanh dương (Info).'),
            (2, 'Running', '**Đang diễn ra sôi động**: Đang mở cổng cho người mua vào đấu giá (Bid). Badge đỏ nhấp nháy / xanh lá (Live).'),
            (3, 'Ended', '**Đã kết thúc phiên**: Đã dừng nhận giá, đang chốt người thắng cuộc. Badge cam (Warning).'),
            (4, 'Settled', '**Đã thanh toán & Tạo đơn**: Người thắng đã thanh toán đơn đấu giá thành công. Badge xanh lá (Success).'),
            (5, 'Failed', '**Đấu giá thất bại**: Không có ai tham gia đặt giá hoặc không đạt giá sàn. Badge xám (Muted).'),
            (6, 'Cancelled', '**Bị hủy bỏ**: Seller hủy trước giờ G hoặc Admin cưỡng chế hủy. Badge đỏ (Danger).')
        ]
    },
    'ShipmentStatus': {
        'field': 'status',
        'type': 'ShipmentStatus',
        'values': [
            (0, 'ReadyToPick', '**Chờ lấy hàng**: Đã tạo mã vận đơn GHN, chờ bưu tá tới lấy kiện hàng. Badge vàng (Warning).'),
            (1, 'Picking', '**Đang lấy hàng**: Bưu tá đang trên đường đến kho Seller lấy hàng. Badge xanh dương nhạt (Info).'),
            (2, 'Packed', '**Đã đóng gói xong**: Kiện hàng đã đóng gói sẵn sàng bàn giao. Badge xanh dương (Info).'),
            (3, 'HandedOver', '**Đã bàn giao cho vận chuyển**: Kiện hàng đã vào bưu cục trung chuyển. Badge xanh lá nhạt (Primary).'),
            (4, 'InTransit', '**Đang luân chuyển trên đường**: Đang vận chuyển giữa các kho bưu cục. Badge xanh dương (Info).'),
            (5, 'Delivered', '**Giao hàng thành công**: Khách hàng đã ký nhận đơn hàng. Badge xanh lá (Success).'),
            (6, 'DeliveryFailed', '**Giao hàng thất bại**: Không liên lạc được với khách hoặc sai địa chỉ (giao lại sau). Badge đỏ (Danger).'),
            (7, 'Returned', '**Chuyển hoàn về kho Shop**: Đơn hàng giao không thành công 3 lần, hoàn về người gửi. Badge cam (Warning).'),
            (8, 'Cancelled', '**Vận đơn bị hủy**: Hủy trước khi bưu tá đến lấy. Badge xám (Muted).')
        ]
    },
    'TransactionStatus': {
        'field': 'status',
        'type': 'TransactionStatus',
        'values': [
            (0, 'Pending', '**Đang xử lý**: Giao dịch đang chờ ngân hàng/cổng thanh toán phản hồi. Badge vàng (Warning).'),
            (1, 'Success', '**Thành công**: Tiền đã ghi có/ghi nợ thành công vào số dư ví. Badge xanh lá (Success).'),
            (2, 'Failed', '**Thất bại**: Giao dịch bị lỗi hoặc tài khoản không đủ điều kiện. Badge đỏ (Danger).'),
            (3, 'Cancelled', '**Đã hủy**: Giao dịch bị người dùng hoặc hệ thống hủy bỏ. Badge xám (Muted).')
        ]
    },
    'WalletTransactionType': {
        'field': 'type',
        'type': 'WalletTransactionType',
        'values': [
            (0, 'TopupVnpay', '**Nạp tiền ví VNPay**: Nạp tiền từ tài khoản ngân hàng qua VNPay (+). Badge xanh lá (+).'),
            (1, 'PurchaseDebit', '**Thanh toán đơn hàng**: Trừ tiền mua sản phẩm (-). Badge đỏ (-).'),
            (2, 'RefundCredit', '**Hoàn tiền đơn hàng**: Nhận lại tiền từ đơn hủy hoặc trả hàng (+). Badge xanh lá (+).'),
            (3, 'EscrowCredit', '**Tạm giữ tiền bán hàng**: Tiền khách mua hàng được đưa vào số dư đóng băng (+ Escrow). Badge xanh dương.'),
            (4, 'EscrowRelease', '**Giải phóng tiền bán hàng**: Chuyển từ đóng băng sang số dư khả dụng khi hoàn tất (+ Available). Badge xanh lá (+).'),
            (5, 'WithdrawalDebit', '**Rút tiền về ngân hàng**: Trừ số dư khả dụng để chuyển khoản về ngân hàng (-). Badge đỏ (-).'),
            (6, 'WithdrawalReversal', '**Hoàn lại tiền rút**: Yêu cầu rút tiền bị từ chối, hoàn lại tiền vào ví (+). Badge xanh lá (+).'),
            (7, 'PlatformFeeCredit', '**Khấu trừ phí sàn**: Trừ phí dịch vụ sàn thương mại điện tử (-). Badge cam (-).'),
            (8, 'AdjustmentCredit', '**Admin cộng tiền điều chỉnh**: Bù tiền hoặc thưởng kiểm toán (+). Badge xanh lá (+).'),
            (9, 'AdjustmentDebit', '**Admin trừ tiền điều chỉnh**: Thu hồi tiền gian lận hoặc phạt vi phạm (-). Badge đỏ (-).'),
            (10, 'DirectGatewayPayment', '**Thanh toán trực tiếp qua cổng**: Thanh toán thẳng từ VNPay cho đơn hàng. Badge xanh dương (Info).'),
            (11, 'TransferIn', '**Nhận chuyển khoản nội bộ**: Tiền nhận từ ví thành viên khác (+). Badge xanh lá (+).'),
            (12, 'TransferOut', '**Chuyển khoản nội bộ**: Chuyển tiền sang ví thành viên khác (-). Badge đỏ (-).')
        ]
    },
    'WithdrawalStatus': {
        'field': 'status',
        'type': 'WithdrawalStatus',
        'values': [
            (0, 'Pending', '**Chờ duyệt rút tiền**: Seller gửi yêu cầu rút tiền, chờ Admin phê duyệt. Badge vàng (Warning).'),
            (1, 'Approved', '**Đã phê duyệt**: Kế toán đã ký duyệt lệnh chuyển khoản. Badge xanh lá nhạt (Primary).'),
            (2, 'Processing', '**Đang chuyển khoản liên ngân hàng**: Hệ thống đang chuyển tiền qua Napas/VietQR. Badge xanh dương (Info).'),
            (3, 'Completed', '**Rút tiền thành công**: Tiền đã về tài khoản ngân hàng của Seller. Badge xanh lá (Success).'),
            (4, 'Rejected', '**Bị từ chối**: Thông tin ngân hàng không khớp hoặc số dư bị nghi vấn. Badge đỏ (Danger).'),
            (5, 'Failed', '**Lỗi chuyển khoản**: Lỗi kỹ thuật từ cổng Napas/ngân hàng thụ hưởng. Badge đỏ (Danger).')
        ]
    },
    'NotificationType': {
        'field': 'type',
        'type': 'NotificationType',
        'values': [
            (0, 'OrderPaid', '**Đơn hàng đã thanh toán**: Thông báo cho Shop chuẩn bị hàng và khách đã trừ tiền.'),
            (1, 'OrderShipped', '**Đơn hàng đang giao**: Thông báo mã vận đơn và lộ trình giao hàng cho khách.'),
            (2, 'AuctionOutbid', '**Bị trả giá cao hơn**: Thông báo cho người mua khi có người trả giá cao hơn trong phiên đấu giá.'),
            (3, 'AuctionWon', '**Chúc mừng thắng đấu giá**: Thông báo kết quả và đường dẫn thanh toán đơn đấu giá.'),
            (4, 'ReputationPenalty', '**Xử phạt điểm uy tín**: Thông báo chế tài kỷ luật hoặc trừ điểm do vi phạm.'),
            (5, 'SecurityAlert', '**Cảnh báo bảo mật**: Đăng nhập từ thiết bị lạ hoặc phát hiện hành vi bất thường.'),
            (6, 'Otp', '**Mã xác thực OTP**: Gửi mã xác nhận đăng ký / quên mật khẩu qua email.'),
            (7, 'Promotion', '**Khuyến mãi & Voucher**: Thông báo chương trình ưu đãi, flash sale mới.')
        ]
    },
    'ChannelType': {
        'field': 'channelType',
        'type': 'ChannelType',
        'values': [
            (0, 'Email', '**Thư điện tử (Email)**: Gửi qua dịch vụ SMTP / SendGrid.'),
            (1, 'Push', '**Thông báo đẩy (Push Notification)**: Gửi qua Firebase Cloud Messaging (FCM) / Apple APNs.'),
            (2, 'InApp', '**Thông báo trong ứng dụng (In-App)**: Hiển thị tại biểu tượng quả chuông của người dùng.'),
            (3, 'Sms', '**Tin nhắn SMS**: Gửi qua nhà mạng viễn thông.')
        ]
    },
    'DeliveryStatus': {
        'field': 'deliveryStatus',
        'type': 'DeliveryStatus',
        'values': [
            (0, 'Pending', '**Chờ gửi tin**: Tin nhắn nằm trong hàng đợi chờ xử lý. Badge vàng.'),
            (1, 'Sending', '**Đang gửi**: Đang kết nối tới FCM / SendGrid / SMTP. Badge xanh dương.'),
            (2, 'Sent', '**Đã gửi thành công**: Nhà mạng / Firebase đã xác nhận nhận thông điệp. Badge xanh lá.'),
            (3, 'Failed', '**Gửi thất bại**: Lỗi token hết hạn, email sai hoặc sự cố mạng. Badge đỏ.'),
            (4, 'Skipped', '**Bỏ qua**: Người dùng đã tắt kênh thông báo này trong tùy chọn cá nhân. Badge xám.')
        ]
    },
    'AlertSeverity': {
        'field': 'severity',
        'type': 'AlertSeverity',
        'values': [
            (0, 'Low', '**Mức độ Thấp**: Cảnh báo thông tin thông thường. Badge xám/xanh dương.'),
            (1, 'Medium', '**Mức độ Trung bình**: Cảnh báo cần chú ý nhưng chưa gây nghẽn dịch vụ. Badge vàng.'),
            (2, 'High', '**Mức độ Cao**: Lỗi ảnh hưởng tới trải nghiệm người dùng, cần kiểm tra sớm. Badge cam.'),
            (3, 'Critical', '**Mức độ Nghiêm trọng**: Sập dịch vụ, lỗi thanh toán hoặc xâm nhập bảo mật. Badge đỏ nhấp nháy.')
        ]
    },
    'HealthStatus': {
        'field': 'status',
        'type': 'HealthStatus',
        'values': [
            (1, 'Healthy', '**Hoạt động tốt**: Độ trễ thấp, kết nối cơ sở dữ liệu và API ổn định. Badge xanh lá (Success).'),
            (2, 'Degraded', '**Bị suy giảm hiệu năng**: Độ trễ cao (>1000ms) hoặc một số probe phụ bị timeout. Badge vàng (Warning).'),
            (3, 'Unhealthy', '**Không phản hồi / Lỗi**: Service hoặc DB ngắt kết nối hoàn toàn. Badge đỏ (Danger).'),
            (4, 'Disabled', '**Tạm ngưng giám sát**: Mục tiêu bị tắt thủ công bởi quản trị viên. Badge xám (Muted).'),
            (5, 'Unknown', '**Chưa xác định**: Đang khởi động hoặc chưa thực hiện chu kỳ probe đầu tiên. Badge xanh dương (Info).')
        ]
    }
}

def generate_enum_section(enum_keys):
    if not enum_keys:
        return "*Endpoint này không sử dụng enum trực tiếp trong tham số đầu vào (Request) hoặc dữ liệu trả về (Response).*"
    
    table_lines = [
        "Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:\n",
        "| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |",
        "|:---|:---|:---:|:---|:---|"
    ]
    for k in enum_keys:
        if k in ENUM_SPECS:
            spec = ENUM_SPECS[k]
            field = spec['field']
            etype = spec['type']
            for val_int, val_str, desc in spec['values']:
                table_lines.append(f"| `{field}` | `{etype}` | `{val_int}` | `{val_str}` | {desc} |")
    return "\n".join(table_lines)


def standardize_endpoint(raw_path, service):
    p = raw_path.strip()
    
    # Preserve singletons
    if p.startswith('/api/v1/me') or p.startswith('/api/v1/auth'):
        return p, "Contextual Singleton giữ nguyên theo chuẩn RFC 9110."
    
    orig = p
    # Handle specific oddities first
    p = re.sub(r'/api/v1/product/\{productId\}pics', '/api/v1/products/{productId}/pictures', p)
    p = re.sub(r'/api/v1/subOrder/\{subOrderId\}', '/api/v1/sub-orders/{subOrderId}', p)
    p = re.sub(r'/api/v1/checkout/quote', '/api/v1/checkouts/quote', p)
    p = re.sub(r'/api/v1/inventory/stock-in', '/api/v1/inventories/stock-in', p)
    p = re.sub(r'/api/v1/variant/\{variantId\}', '/api/v1/variants/{variantId}', p)
    p = re.sub(r'/api/v1/seller/shipment', '/api/v1/sellers/shipments', p)
    p = re.sub(r'/api/v1/seller/auctions', '/api/v1/sellers/auctions', p)
    p = re.sub(r'/api/v1/shipment/\{shipmentId\}', '/api/v1/shipments/{shipmentId}', p)
    p = re.sub(r'/api/v1/shipment/webhook', '/api/v1/shipments/webhook', p)
    p = re.sub(r'/api/v1/admin/user(?=[/?]|$)', '/api/v1/admin/users', p)
    
    # General plural replacements
    p = re.sub(r'^/api/v1/orders?(?=[/?]|$)', '/api/v1/orders', p)
    p = re.sub(r'^/api/v1/products?(?=[/?]|$)', '/api/v1/products', p)
    p = re.sub(r'^/api/v1/users?(?=[/?]|$)', '/api/v1/users', p)
    p = re.sub(r'^/api/v1/sellers?(?=[/?]|$)', '/api/v1/sellers', p)
    p = re.sub(r'^/api/v1/carts?(?=[/?]|$)', '/api/v1/carts', p)
    p = re.sub(r'^/api/v1/variants?(?=[/?]|$)', '/api/v1/variants', p)
    p = re.sub(r'^/api/v1/shipments?(?=[/?]|$)', '/api/v1/shipments', p)
    p = re.sub(r'^/api/v1/inventories?(?=[/?]|$)', '/api/v1/inventories', p)
    
    # Clean any accidental double-slashes or double-plural
    p = re.sub(r'//+', '/', p)
    
    if p != orig:
        return p, f"Chuẩn hóa từ '{orig}' sang chuẩn 100% số nhiều '{p}'."
    return p, "Đường dẫn đã tuân thủ chuẩn 100% số nhiều."


def get_rbac(method, path):
    p = path.lower()
    
    # 1. AllowAnonymous (Public endpoints)
    if '/auth/register' in p or '/auth/login' in p or '/auth/otp' in p or '/auth/password/forgot' in p or '/auth/password/reset' in p:
        return 'AllowAnonymous'
    if '/vnpay/ipn' in p or '/payments/webhook' in p or ('/shipments/' in p and 'webhook' in p):
        return 'AllowAnonymous'
    if p.endswith('/health') or p.endswith('/healthcheck/status') or p.endswith('/healthcheck/services'):
        return 'AllowAnonymous'
    if method == 'GET':
        if p.endswith('/products') or '/products/search' in p or p.endswith('/categories') or re.search(r'/categories/[^/]+$', p):
            return 'AllowAnonymous'
        if p.endswith('/auctions') or re.search(r'/auctions/[^/]+$', p) or p.endswith('/bids'):
            return 'AllowAnonymous'
        if re.search(r'/products/[^/]+$', p) or '/products/' in p and 'pictures' in p:
            return 'AllowAnonymous'

    # 2. StaffOrAdmin (Moderation & Staff operations)
    if '/admin/seller-registrations' in p or '/admin/reports' in p or '/admin/reviews' in p:
        return 'StaffOrAdmin'

    # 3. Admin (System administrator only)
    if '/admin/' in p:
        return 'Admin'
    if '/logs' in p or '/healthcheck' in p:
        return 'Admin'

    # 4. Seller (Shop owners)
    if '/sellers/' in p or '/seller/' in p:
        return 'Seller'
    if '/stock-in' in p:
        return 'Seller'
    if method in ['POST', 'PUT', 'PATCH', 'DELETE'] and ('/products' in p or '/variants' in p):
        return 'Seller'
    if method in ['POST', 'PUT'] and p.endswith('/auctions') or '/auctions/' in p and any(x in p for x in ['cancel', 'recreate']):
        return 'Seller'
    if '/orders/' in p and any(x in p for x in ['accept', 'reject']):
        return 'Seller'
    if p.endswith('/wallets/withdrawals') and method == 'POST':
        return 'Seller'
    if '/shipments/' in p and 'tracking' in p:
        return 'Seller'

    # 5. Buyer (Default authenticated user)
    return 'Buyer'

def get_idempotency(method):
    if method in ['POST', 'PUT', 'PATCH']:
        return 'Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)'
    return 'Không áp dụng (Idempotent theo HTTP spec)'

print("Scaffold helpers initialized.")
