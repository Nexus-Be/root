# BẢN ĐẶC TẢ DANH MỤC ENTITY & ENUM CHUẨN FORM CHO FRONTEND
## (NEXUS MICROSERVICES ECOSYSTEM — FRONTEND INTEGRATION SPECIFICATION V2)

> **Dành cho Frontend Team (Next.js / React / Mobile App / QA / Backend Developers):**  
> Tài liệu này chuẩn hóa toàn bộ các trường dữ liệu Entity và danh mục **toàn bộ 78 Enums** thuộc 8 Microservices trong hệ thống.  
> 
> ⚡ **QUY ƯỚC GIAO TIẾP DỮ LIỆU BẮT BUỘC (REST JSON CONVENTION):**
> 1. **Dữ liệu Enum khi hiển thị (Chiều RA: BE ➔ FE):** Toàn bộ các trạng thái số nguyên trong Database (0, 1, 2...) đã được API Gateway / Backend tự động biên dịch thành **Chuỗi PascalCase** trực quan (ví dụ: `"PendingPayment"`, `"Active"`, `"Delivered"`). Frontend **không bao giờ phải nhớ số 0 hay 1 đại diện cho điều gì**.
> 2. **Dữ liệu Enum khi gửi lên (Chiều VÀO: FE ➔ BE):** Khi thực hiện các thao tác lọc (Query param) hoặc gửi body (POST/PUT), Frontend chỉ cần gửi đúng **Chuỗi PascalCase** tương ứng. Gateway / Backend tự động map về số nguyên tương ứng.
> 3. **Bắt lỗi tự động:** Nếu Frontend gửi sai tên enum (ví dụ gõ nhầm `"Pendingg"`), hệ thống sẽ lập tức trả về lỗi **HTTP 400 Bad Request (Problem Details)** kèm danh sách gợi ý chính xác toàn bộ các giá trị hợp lệ.

---

# MỤC LỤC 8 SERVICES

1. [UserService (16 Enums)](#1-user-service-port-8001--usermanagement_db)
2. [CatalogService (7 Enums)](#2-catalog-service-port-8002--category_db)
3. [CommerceService (18 Enums)](#3-commerce-service-port-8003--commerce_db)
4. [AuctionService (4 Enums)](#4-auction-service-port-8005--auction_db)
5. [FulfillmentService (9 Enums)](#5-fulfillment-service-port-8006--fulfillment_db)
6. [NotificationService (11 Enums)](#6-notification-service-port-8007--notification_db)
7. [WalletService (7 Enums)](#7-wallet-service-port-8008--wallet_db)
8. [LogService (6 Enums)](#8-log-service-port-8004--log_db)

---

# 1. USER SERVICE (Port 8001 | `usermanagement_db`)

### 1.1 `UserStatus` — Trạng Thái Tài Khoản Người Dùng
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `User.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Mô Tả Ý Nghĩa Nghiệp Vụ | Hành Vi Frontend Khuyến Nghị |
| :---: | :--- | :--- | :--- |
| `0` | **`PendingVerification`** | Tài khoản mới tạo, chưa kích hoạt mã OTP email. | Chuyển hướng người dùng sang màn hình nhập mã OTP kích hoạt. |
| `1` | **`Active`** | Đã xác thực, tài khoản đang hoạt động bình thường. | Cho phép đăng nhập, mua hàng, nạp tiền và đấu giá bình thường. |
| `2` | **`Banned`** | Bị khóa vĩnh viễn hoặc tạm thời do vi phạm chính sách. | Đăng xuất người dùng, hiển thị thông báo liên hệ Support. |
| `3` | **`Deleted`** | Tài khoản đã bị xóa mềm (`is_deleted = true`). | Không cho phép đăng nhập lại bằng thông tin này. |

---

### 1.2 `RoleType` — 4 Vai Trò Cốt Lõi Hệ Thống
* **Thuộc tính JSON:** `roleCode` / `roles` (dạng mảng `string[]`)
* **Áp dụng:** `Role.RoleCode`, Phân quyền điều hướng Sidebar và bảo vệ Route (RBAC).

| Mã DB | Chuỗi Frontend (PascalCase) | Quyền Hạn Thực Tế |
| :---: | :--- | :--- |
| `0` | **`Buyer`** | Khách mua hàng thông thường, quản lý giỏ hàng, đặt cọc và tham gia đặt giá (Bid) đấu giá. |
| `1` | **`Seller`** | Người bán hàng: Đăng bán sản phẩm, mở kho hàng, quản lý đơn hàng của Shop, tạo phiên đấu giá. |
| `2` | **`SupportStaff`** | Nhân viên hỗ trợ: Thẩm định hồ sơ duyệt Seller, xử lý khiếu nại, duyệt đơn tố cáo. |
| `3` | **`Admin`** | Quản trị viên tối cao: Phân quyền nhân sự, khóa/mở tài khoản, cấu hình tham số hệ thống. |

---

### 1.3 `Gender` — Giới Tính
* **Thuộc tính JSON:** `gender`
* **Áp dụng:** `User.Gender`

| Mã DB | Chuỗi Frontend (PascalCase) | Hiển Thị Giao Diện |
| :---: | :--- | :--- |
| `0` | **`Unspecified`** | Không tiết lộ / Chưa cập nhật |
| `1` | **`Male`** | Nam |
| `2` | **`Female`** | Nữ |
| `3` | **`Other`** | Khác |

---

### 1.4 `SellerProfileStatus` — Trạng Thái Hồ Sơ Mở Shop
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `SellerProfile.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế | Hành Vi Frontend |
| :---: | :--- | :--- | :--- |
| `0` | **`Pending`** | Hồ sơ mở gian hàng đang chờ Staff xét duyệt. | Hiển thị badge vàng *"Đang chờ duyệt hồ sơ"*, khóa nút nộp lại. |
| `1` | **`Approved`** | Đã được duyệt lên Seller thành công. | Mở menu Seller Center trên thanh điều hướng. |
| `2` | **`Rejected`** | Bị từ chối mở gian hàng. | Hiển thị lý do từ chối (`rejectionReason`) và mở nút cho nộp lại. |

---

### 1.5 `TrustLevel` — Cấp Độ Tin Cậy Điểm Uy Tín (Reputation)
* **Thuộc tính JSON:** `trustLevel` (Điểm uy tín thang đo 0 – 100)
* **Áp dụng:** `ReputationScore.TrustLevel`

| Mã DB | Chuỗi Frontend (PascalCase) | Thang Điểm | Rào Chắn Nghiệp Vụ Trên Giao Diện |
| :---: | :--- | :---: | :--- |
| `0` | **`Untrusted`** | **0 – 39** | **Cấm tham gia đấu giá** (cấm đặt giá lẫn mở bán), chặn phương thức COD. |
| `1` | **`Probation`** | **40 – 49** | Được đặt giá đấu giá, nhưng **bị cấm mở bán đấu giá** (yêu cầu $\ge 50$). |
| `2` | **`Standard`** | **50 – 69** | Mức mặc định khi tạo tài khoản mới. Đủ quyền mua sắm và đấu giá cơ bản. |
| `3` | **`Good`** | **70 – 89** | Khách hàng/Shop uy tín, mở tối đa 5 phiên đấu giá đồng thời. |
| `4` | **`Excellent`** | **90 – 100** | Đối tác Vàng, có huy hiệu tín nhiệm (Verified Badge), ưu tiên hiển thị. |

---

### 1.6 `ReferenceType` — Loại Giao Dịch Tham Chiếu
* **Thuộc tính JSON:** `referenceType`
* **Áp dụng:** `ReputationLog.ReferenceType`, `UserReview.ReferenceType`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa |
| :---: | :--- | :--- |
| `0` | **`Order`** | Đơn hàng mua sắm thường từ Commerce Service |
| `1` | **`Auction`** | Phiên đấu giá từ Auction Service |
| `2` | **`Dispute`** | Tranh chấp / Khiếu nại |
| `3` | **`System`** | Can thiệp từ hệ thống hoặc Admin |

---

### 1.7 `ReputationChangeReason` — Lý Do Biến Động Điểm Uy Tín
* **Thuộc tính JSON:** `reason`
* **Áp dụng:** `ReputationLog.Reason`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa | Điểm Biến Động |
| :---: | :--- | :--- | :---: |
| `0` | **`PositiveReview`** | Nhận đánh giá tốt 4-5 sao | +1 |
| `1` | **`NegativeReview`** | Nhận đánh giá xấu 1-2 sao | -1 hoặc -2 |
| `2` | **`OrderCompleted`** | Hoàn thành đơn hàng | +1 |
| `3` | **`AuctionPaymentTimeout`** | Bùng kèo không thanh toán đấu giá sau 24h | -10 |
| `4` | **`DisputeCompensation`** | Đền bù sau khiếu nại thành công | Hoàn lại điểm |
| `5` | **`ManualAdjustment`** | Admin can thiệp điều chỉnh thủ công | Tùy quyết định |
| `6` | **`ViolationPenalty`** | Bị phạt do vi phạm quy chế sàn | Trừ điểm theo án phạt |

---

### 1.8 `ReviewerRole` — Vai Trò Người Viết Đánh Giá
* **Thuộc tính JSON:** `reviewerRole`
* **Áp dụng:** `UserReview.ReviewerRole`

| Mã DB | Chuỗi Frontend (PascalCase) | Mô Tả |
| :---: | :--- | :--- |
| `0` | **`Buyer`** | Người mua gửi đánh giá cho Shop sau đơn hàng |
| `1` | **`Seller`** | Người bán gửi đánh giá cho Người mua |

---

### 1.9 `ReportViolationType` — Phân Loại Tố Cáo Vi Phạm
* **Thuộc tính JSON:** `violationType`
* **Áp dụng:** `UserReport.ViolationType`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Hành Vi Vi Phạm |
| :---: | :--- | :--- |
| `0` | **`Fraud`** | Hành vi lừa đảo chiếm đoạt tài sản, gian lận tiền |
| `1` | **`Harassment`** | Quấy rối, xúc phạm danh dự nhân phẩm |
| `2` | **`Counterfeit`** | Bán hàng giả, hàng nhái, vi phạm bản quyền |
| `3` | **`Spam`** | Spam tin nhắn, đặt đơn ảo, phá hoại đấu giá |
| `4` | **`Other`** | Hành vi vi phạm quy chế sàn khác |

---

### 1.10 `ReportStatus` — Trạng Thái Hồ Sơ Tố Cáo
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `UserReport.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Tiến Trình |
| :---: | :--- | :--- |
| `0` | **`Pending`** | Tiếp nhận đơn tố cáo mới, chờ phân công xử lý |
| `1` | **`UnderReview`** | Nhân viên hỗ trợ đang điều tra xác minh chứng cứ |
| `2` | **`Resolved`** | Đã xử lý xong (kèm kết luận/án phạt nếu có) |
| `3` | **`Rejected`** | Từ chối tố cáo do bằng chứng không đủ hoặc sai sự thật |

---

### 1.11 `PenaltyViolationType` — Hành Vi Vi Phạm Dẫn Đến Phạt
* **Thuộc tính JSON:** `violationType`
* **Áp dụng:** `UserPenalty.ViolationType`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa |
| :---: | :--- | :--- |
| `0` | **`PaymentTimeout`** | Quá thời hạn thanh toán đơn hàng |
| `1` | **`AuctionNonPayment`** | Bùng kèo không thanh toán sau 24h thắng đấu giá |
| `2` | **`CancellationWithoutReason`** | Shop tự ý hủy đơn hàng không lý do chính đáng |
| `3` | **`Fraud`** | Gian lận giá thầu, tạo nick ảo hoặc bán hàng cấm |
| `4` | **`Other`** | Vi phạm các quy định vận hành khác |

---

### 1.12 `PenaltyType` — Hình Thức Chế Tài Xử Phạt
* **Thuộc tính JSON:** `penaltyApplied`
* **Áp dụng:** `UserPenalty.PenaltyApplied`

| Mã DB | Chuỗi Frontend (PascalCase) | Chế Tài Áp Dụng |
| :---: | :--- | :--- |
| `0` | **`Warning`** | Cảnh cáo tài khoản qua thông báo |
| `1` | **`DeductPoints`** | Trừ điểm uy tín sàn (kèm `pointsDeducted`) |
| `2` | **`SuspendBidding3Days`** | Đình chỉ quyền đấu giá trong 3 ngày |
| `3` | **`BanAccount`** | Khóa tài khoản vĩnh viễn |
| `4` | **`Other`** | Chế tài xử phạt khác |

---

### 1.13 `PenaltyStatus` — Hiệu Lực Án Phạt
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `UserPenalty.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Trạng Thái Hiệu Lực |
| :---: | :--- | :--- |
| `0` | **`Active`** | Đang có hiệu lực thi hành |
| `1` | **`Expired`** | Án phạt có thời hạn đã hết hiệu lực |
| `2` | **`Revoked`** | Đã được Admin hủy bỏ / ân xá |

---

### 1.14 `ConfigDataType` — Kiểu Dữ Liệu Tham Số Sàn
* **Thuộc tính JSON:** `dataType`
* **Áp dụng:** `SystemConfig.DataType` (`String = 0`, `Int = 1`, `Decimal = 2`, `Boolean = 3`, `Json = 4`)

---

### 1.15 `OtpType` — Mục Đích Mã Xác Thực OTP
* **Nơi lưu trữ:** Redis Cache (`Registration = 0`, `ForgotPassword = 1`)

---

### 1.16 `AuditAction` — Kiểm Toán Quản Trị User
* **Thuộc tính JSON:** `action` (`UserUpdate = 0` .. `SystemConfigUpdate = 9`)

---

# 2. CATALOG SERVICE (Port 8002 | `category_db`)

### 2.1 `ProductStatus` — Vòng Đời Trạng Thái Sản Phẩm
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `Product.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế | Ghi Chú Hiển Thị |
| :---: | :--- | :--- | :--- |
| `0` | **`Draft`** | Bản nháp đang soạn thảo. | Chỉ người bán (Seller) nhìn thấy trong mục quản lý sản phẩm. |
| `1` | **`Active`** | Đang mở bán công khai. | Hiển thị trên thanh tìm kiếm, trang chủ, cho phép mua. |
| `2` | **`Inactive`** | Tạm ngừng kinh doanh. | Ẩn khỏi tìm kiếm, kèm lý do tạm ngừng (`inactiveReason`). |

---

### 2.2 `SaleType` — Hình Thức Bán Hàng
* **Thuộc tính JSON:** `saleType`
* **Áp dụng:** `Product.SaleType`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế | Nút Bấm Tương Ứng Trên UI |
| :---: | :--- | :--- | :--- |
| `0` | **`Regular`** | Bán lẻ thương mại thông thường. | Hiển thị nút *"Thêm vào giỏ"* và *"Mua ngay"*. |
| `1` | **`Auction`** | Hàng hóa chỉ bán thông qua phòng đấu giá. | Ẩn nút mua ngay, hiển thị nút *"Tham gia đấu giá"*. |

---

### 2.3 `VariantStatus` — Trạng Thái Từng Biến Thể SKU
* **Thuộc tính JSON:** `status` trong danh sách `variants`
* **Áp dụng:** `ProductVariant.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế |
| :---: | :--- | :--- |
| `0` | **`Active`** | Biến thể (màu sắc/kích cỡ) này còn kinh doanh bình thường. |
| `1` | **`Inactive`** | Biến thể này tạm ngưng bán (vô hiệu hóa nút chọn biến thể trên UI). |

---

### 2.4 `ProductInactiveReason` — Lý Do Sản Phẩm Ngưng Bán
* **Thuộc tính JSON:** `inactiveReason` (`SellerPaused = 0`, `Discontinued = 1`, `AdminLocked = 2`, `Other = 3`)

---

### 2.5 `VariantInactiveReason` — Lý Do Biến Thể SKU Ngưng Bán
* **Thuộc tính JSON:** `inactiveReason` (`OutOfStock = 0`, `Discontinued = 1`, `Other = 2`)

---

### 2.6 `ReviewStatus` — Trạng Thái Đánh Giá Sản Phẩm
* **Thuộc tính JSON:** `status` (`Published = 0`, `Hidden = 1`)

---

### 2.7 `AuditAction` — Kiểm Toán Catalog (`ProductCreate = 0` ..)

---

# 3. COMMERCE SERVICE (Port 8003 | `commerce_db`)

### 3.1 `CartStatus` — Trạng Thái Giỏ Hàng
* **Thuộc tính JSON:** `status` trong `/api/v1/commerce/cart`
* **Áp dụng:** `Cart.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế |
| :---: | :--- | :--- |
| `0` | **`Active`** | Giỏ hàng đang sử dụng bình thường. |
| `1` | **`CheckedOut`** | Đã tiến hành thanh toán xong, giỏ hàng đã được làm trống. |
| `2` | **`Abandoned`** | Giỏ hàng bị bỏ quên quá lâu. |

---

### 3.2 `OrderStatus` — Đơn Hàng Tổng (Master Order)
* **Thuộc tính JSON:** `status` trong `/api/v1/commerce/orders`
* **Áp dụng:** `Order.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế | Trạng Thái Hiển Thị |
| :---: | :--- | :--- | :--- |
| `0` | **`PendingPayment`** | Đơn hàng vừa tạo, đang chờ thanh toán tiền. | Bật đồng hồ đếm ngược 15 phút thanh toán. |
| `1` | **`PaymentProcessing`** | Đang xử lý giao dịch qua cổng thanh toán/ví. | Hiển thị màn hình chờ xác nhận thanh toán. |
| `2` | **`Paid`** | Đã thanh toán tiền thành công. | Hiển thị màn hình *"Đặt hàng thành công"*. |
| `3` | **`Cancelled`** | Đã hủy đơn tổng. | Đóng đơn hàng. |
| `4` | **`Expired`** | Quá hạn thanh toán 15 phút. | Thông báo đơn hết hạn, gợi ý đặt lại giỏ hàng. |

---

### 3.3 `SubOrderStatus` — Vòng Đời Đơn Con Của Shop & Đơn Đấu Giá
* **Thuộc tính JSON:** `status` trong đơn hàng con hoặc đơn đấu giá
* **Áp dụng:** `SubOrder.Status`, `AuctionOrder.Status`, `OrderStatusHistory.*`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Thực Tế | Màu Sắc Badge UI Đề Xuất |
| :---: | :--- | :--- | :---: |
| `0` | **`PendingPayment`** | Chờ thanh toán tiền. | Cam (Warning) |
| `1` | **`Paid`** | Đã thanh toán, đang chờ Người bán xác nhận đơn. | Xanh dương (Info) |
| `2` | **`Confirmed`** | Người bán đã chấp nhận đơn, đang chuẩn bị gói hàng. | Tím (Processing) |
| `3` | **`Shipping`** | Đã bàn giao cho đơn vị vận chuyển, đang giao hàng. | Xanh lơ (In Transit) |
| `4` | **`Delivered`** | Đơn vị vận chuyển đã giao hàng thành công tới tay khách. | Xanh lá nhạt |
| `5` | **`Completed`** | Người mua bấm xác nhận hài lòng hoặc hết hạn khiếu nại. | Xanh lá đậm (Success) |
| `6` | **`Cancelled`** | Đơn hàng đã bị hủy (kèm mã lý do `cancellationReason`). | Xám |
| `7` | **`Refunded`** | Đã hoàn lại toàn bộ tiền về ví/tài khoản khách hàng. | Đỏ gạch |

---

### 3.4 `PaymentMethod` — Phương Thức Thanh Toán
* **Thuộc tính JSON:** `paymentMethod`
* **Áp dụng:** `SubOrder.PaymentMethod`, `AuctionOrder.PaymentMethod`

| Mã DB | Chuỗi Frontend (PascalCase) | Mô Tả |
| :---: | :--- | :--- |
| `0` | **`Wallet`** | Trừ tiền trực tiếp vào số dư Ví điện tử Nexus. |
| `1` | **`VnPay`** | Chuyển hướng thanh toán qua cổng VNPAY (QR Code/ATM). |
| `2` | **`Cod`** | Thanh toán tiền mặt khi nhận hàng (yêu cầu TrustLevel $\ge 40$). |

---

### 3.5 `RefundStatus` — Trạng Thái Yêu Cầu Hoàn Tiền
* **Thuộc tính JSON:** `status` trong `OrderRefund`
* **Áp dụng:** `OrderRefund.Status` (`Requested = 0`, `Completed = 1`, `Failed = 2`)

---

### 3.6 `RefundType` — Hình Thức Hoàn Tiền
* **Thuộc tính JSON:** `refundType` (`Full = 0`, `Partial = 1`)

---

### 3.7 `DiscountScopeType` — Phạm Vi Mã Giảm Giá
* **Thuộc tính JSON:** `scopeType` (`System = 0`, `Shop = 1`, `Product = 2`)

---

### 3.8 `DiscountType` — Hình Thức Giảm Giá
* **Thuộc tính JSON:** `discountType` (`Percent = 0`, `Fixed = 1`)

---

### 3.9 `DiscountStatus` — Vòng Đời Mã Giảm Giá
* **Thuộc tính JSON:** `status` (`Draft = 0`, `Active = 1`, `Inactive = 2`, `Expired = 3`)

---

### 3.10 `DiscountScopeRefType` — Loại Đối Tượng Phạm Vi Mã
* **Thuộc tính JSON:** `scopeRefType` (`Shop = 0`, `Product = 1`, `Sku = 2`, `Category = 3`, `All = 4`)

---

### 3.11 `DiscountUsageStatus` — Trạng Thái Lượt Dùng Mã
* **Thuộc tính JSON:** `status` (`Reserved = 0`, `Used = 1`, `Released = 2`)

---

### 3.12 `CancellationReasonCode` — Mã Lý Do Hủy Đơn
* **Thuộc tính JSON:** `reasonCode` (`BuyerChangedMind = 0`, `OutOfStock = 1`, `PaymentTimeout = 2`, `SellerRejected = 3`, `Other = 4`)

---

### 3.13 `OrderActorRole` — Tác Nhân Thay Đổi Đơn Hàng
* **Thuộc tính JSON:** `actorRole` (`Buyer = 0`, `Seller = 1`, `Admin = 2`, `SupportStaff = 3`, `System = 4`)

---

### 3.14 `InvoiceStatus` — Trạng Thái Hóa Đơn (`Generated = 0`, `Failed = 1`)
### 3.15 `SettingValueType` — Kiểu Dữ Liệu Config (`String = 0`, `Integer = 1`, `Decimal = 2`, `Boolean = 3`, `Json = 4`)
### 3.16 `SettingCategory` — Phân Nhóm Config (`Reputation = 0`, `Money = 1`, `Auction = 2`, `Timing = 3`, `System = 4`)
### 3.17 `SequenceType` — Loại Mã Thứ Tự (`OrderNo = 0`, `AuctionOrderNo = 1`, `InvoiceNo = 2`)
### 3.18 `AuditAction` — Kiểm Toán Thương Mại (`CartCheckout = 0` .. `InvoiceGenerate = 7`)

---

# 4. AUCTION SERVICE (Port 8005 | `auction_db`)

### 4.1 `AuctionStatus` — Vòng Đời Phiên Đấu Giá
* **Thuộc tính JSON:** `status` trong `/api/v1/auctions`
* **Áp dụng:** `Auction.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Trạng Thái Phiên | Hành Động Cho Phép Trên UI |
| :---: | :--- | :--- | :--- |
| `0` | **`Draft`** | Mới tạo, chờ giữ kho sản phẩm đấu giá. | Seller chỉnh sửa thông tin giá khởi điểm, bước giá. |
| `1` | **`Scheduled`** | Đã lên lịch, đếm ngược chờ bắt đầu. | Hiển thị đồng hồ đếm ngược, cho phép đặt cọc trước. |
| `2` | **`Running`** | Đang diễn ra trả giá trực tiếp (Live Bidding). | **Mở sàn đặt giá (Nút "Trả giá ngay")**, realtime WebSocket. |
| `3` | **`Ended`** | Hết giờ đấu giá, chốt người thắng phiên. | Khóa đặt giá, hiển thị thông tin người thắng cuộc. |
| `4` | **`Settled`** | Người thắng đã thanh toán thành công đơn hàng. | Chuyển phiên sang mục hoàn tất thành công. |
| `5` | **`Failed`** | Phiên thất bại (không có ai bid, hoặc quá hạn trả tiền). | Thông báo kết thúc không người mua, nhả hàng về kho. |
| `6` | **`Cancelled`** | Bị Quản trị viên hủy phiên do nghi vấn gian lận. | Hiển thị lý do hủy phiên, hoàn tiền cọc cho toàn bộ người bid. |

---

### 4.2 `IdempotencyScope` — Phạm Vi Khóa Chống Trùng Lặp
* **Thuộc tính JSON:** `scope` (`Bid = 0`, `Settlement = 1`)

---

### 4.3 `BidInvalidationReason` — Lý Do Hủy Lượt Bid
* **Thuộc tính JSON:** `reason` (`BidderBanned = 0`)

---

### 4.4 `AuditAction` — Kiểm Toán Đấu Giá (`AuctionCreate = 0` ..)

---

# 5. FULFILLMENT SERVICE (Port 8006 | `fulfillment_db`)

### 5.1 `WarehouseType` — Phân Loại Kho Hàng
* **Thuộc tính JSON:** `type`
* **Áp dụng:** `Warehouse.Type` (`SellerWarehouse = 0`, `PlatformWarehouse = 1`, `Consignment = 2`)

---

### 5.2 `ShipmentStatus` — Hành Trình Giao Nhận Kiện Hàng
* **Thuộc tính JSON:** `status` trong `/api/v1/fulfillment/shipments/{code}`
* **Áp dụng:** `Shipment.Status`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Chặng Vận Chuyển |
| :---: | :--- | :--- |
| `0` | **`ReadyToPick`** | Đơn hàng mới tạo, đang chờ nhân viên lấy hàng từ kệ kho. |
| `1` | **`Picking`** | Nhân viên kho đang gom sản phẩm vào giỏ đóng gói. |
| `2` | **`Packed`** | Đã đóng thùng niêm phong và in mã vận đơn (Awb Code). |
| `3` | **`HandedOver`** | Đã bàn giao kiện hàng cho bưu tá đơn vị vận chuyển. |
| `4` | **`InTransit`** | Kiện hàng đang luân chuyển giữa các bưu cục / trên đường giao. |
| `5` | **`Delivered`** | Giao hàng thành công đến tay người mua. |
| `6` | **`DeliveryFailed`**| Giao hàng không thành công (không liên lạc được, sai địa chỉ). |
| `7` | **`Returned`** | Kiện hàng đã được hoàn trả lại kho xuất phát. |
| `8` | **`Cancelled`** | Hủy kiện hàng trước khi bàn giao vận chuyển. |

---

### 5.3 `InventoryReservationStatus` — Giữ Tồn Kho (`Pending = 0`, `Confirmed = 1`, `Released = 2`, `Expired = 3`)
### 5.4 `InventoryMovementType` — Biến Động Kho (`Inbound = 0`, `Outbound = 1`, `Adjustment = 2`, `ReservationHold = 3`, `ReservationRelease = 4`)
### 5.5 `ShippingServiceType` — Gói Cước Vận Chuyển (`Standard = 0`, `Express = 1`, `SameDay = 2`)
### 5.6 `ShipmentEventStatus` — Mốc Sự Kiện Vận Chuyển (`ReadyToPick = 0` .. `Cancelled = 8`)
### 5.7 `AuditAction` — Kiểm Toán Kho Vận (`WarehouseCreate = 0` ..)

---

# 6. NOTIFICATION SERVICE (Port 8007 | `notification_db`)

### 6.1 `NotificationStatus` — Trạng Thái Thông Báo
* **Thuộc tính JSON:** `status` (`Pending = 0`, `Sent = 1`, `Failed = 2`, `Cancelled = 3`)

---

### 6.2 `DeliveryStatus` — Trạng Thái Chuyển Phát Đến Thiết Bị
* **Thuộc tính JSON:** `status` (`Pending = 0`, `Delivered = 1`, `Failed = 2`, `Read = 3`)

---

### 6.3 `ChannelType` — Kênh Nhận Thông Báo
* **Thuộc tính JSON:** `type` (`Email = 0`, `Sms = 1`, `PushNotification = 2`, `InApp = 3`)

---

### 6.4 `ChannelScope` — Mục Đích Gửi (`Transactional = 0`, `Marketing = 1`, `SystemAlert = 2`)
### 6.5 `NotificationType` — Loại Sự Kiện (`OrderUpdate = 0`, `AuctionOutbid = 1`, `AuctionWon = 2`, `WalletTopup = 3`, `SecurityAlert = 4`)
### 6.6 `DevicePlatform` — Nền Tảng Thiết Bị (`Ios = 0`, `Android = 1`, `Web = 2`)
### 6.7 `BrokerHealthStatus` — Sức Khỏe Broker (`Healthy = 0`, `Degraded = 1`, `Unhealthy = 2`)

---

# 7. WALLET SERVICE (Port 8008 | `wallet_db`)

### 7.1 `CurrencyCode` — Đơn Vị Tiền Tệ
* **Thuộc tính JSON:** `currency` (`Vnd = 0`, `Usd = 1`)

---

### 7.2 `WalletTransactionType` — Phân Loại Biến Động Số Dư Ví (Ledger)
* **Thuộc tính JSON:** `type` trong `/api/v1/wallet/transactions`
* **Áp dụng:** `WalletTransaction.Type`

| Mã DB | Chuỗi Frontend (PascalCase) | Ý Nghĩa Biến Động Số Dư | Dấu (+ / -) |
| :---: | :--- | :--- | :---: |
| `0` | **`TopupVnpay`** | Nạp tiền vào ví qua cổng VNPay thành công. | **+ (Cộng)** |
| `1` | **`PurchaseDebit`** | Thanh toán tiền mua đơn hàng thương mại. | **- (Trừ)** |
| `2` | **`RefundCredit`** | Hoàn tiền về ví do đơn hàng bị hủy/trả hàng. | **+ (Cộng)** |
| `3` | **`EscrowCredit`** | Tạm giữ tiền đặt cọc tham gia phiên đấu giá. | **- (Giữ cọc)** |
| `4` | **`EscrowRelease`** | Hoàn tiền cọc đấu giá (khi không trúng giá). | **+ (Giải tỏa)** |
| `5` | **`WithdrawalDebit`** | Trừ tiền khi tạo lệnh rút tiền về ngân hàng. | **- (Trừ)** |
| `6` | **`WithdrawalReversal`**| Hoàn lại tiền vào ví do lệnh rút ngân hàng bị từ chối/lỗi mạng. | **+ (Cộng lại)** |
| `7` | **`PlatformFeeCredit`** | Thu phí hoa hồng nền tảng từ doanh thu Shop. | **- (Trừ)** |
| `8` | **`AdjustmentCredit`** | Điều chỉnh cộng tiền từ Quản trị viên/Đối soát. | **+ (Cộng)** |
| `9` | **`AdjustmentDebit`** | Điều chỉnh trừ tiền từ Quản trị viên/Đối soát. | **- (Trừ)** |
| `10` | **`DirectVnpayDebit`** | Thanh toán trực tiếp đơn hàng qua VNPay (không qua ví). | **- (Thanh toán ngoài)** |

---

### 7.3 `TransactionStatus` — Trạng Thái Giao Dịch Ví
* **Thuộc tính JSON:** `status` (`Pending = 0`, `Success = 1`, `Failed = 2`, `Cancelled = 3`)

---

### 7.4 `TopupStatus` — Trạng Thái Nạp Tiền & Thanh Toán VNPay Trực Tiếp
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `WalletTopup.Status`, `DirectPaymentOrder.Status` (`Pending = 0`, `Success = 1`, `Failed = 2`, `Expired = 3`)

---

### 7.5 `WithdrawalStatus` — Tiến Trình Rút Tiền Về Ngân Hàng
* **Thuộc tính JSON:** `status`
* **Áp dụng:** `WithdrawalRequest.Status` (`Pending = 0`, `Approved = 1`, `Processing = 2`, `Completed = 3`, `Rejected = 4`, `Failed = 5`)

---

### 7.6 `IpnProcessingStatus` — Xử Lý Webhook VNPay IPN (`Processed = 0`, `Ignored = 1`, `Failed = 2`)

---

# 8. LOG SERVICE (Port 8004 | `log_db`)

### 8.1 `CentralAuditAction` — Hành Động Kiểm Toán Hệ Thống
* **Thuộc tính JSON:** `action` trong `/api/v1/log/logs` (`Create = 0`, `Update = 1`, `Delete = 2`, `Login = 3`, `Logout = 4`, `Approve = 5`, `Reject = 6`, `SoftDelete = 7`, `Export = 8`, `Other = 9`)

---

### 8.2 `AlertSeverity` — Mức Độ Cảnh Báo An Ninh
* **Thuộc tính JSON:** `severity` (`Low = 0`, `Medium = 1`, `High = 2`, `Critical = 3`)

---

### 8.3 `SecurityRuleType` — Quy Tắc Phát Hiện Bất Thường
* **Thuộc tính JSON:** `triggeredRule` (`BruteForce = 0`, `PrivilegeEscalation = 1`, `SuspiciousFinancialActivity = 2`, `UnauthorizedAccess = 3`)

---

### 8.4 `AlertStatus` — Tiến Trình Xử Lý Cảnh Báo
* **Thuộc tính JSON:** `status` (`Open = 0`, `Investigating = 1`, `Resolved = 2`, `Dismissed = 3`)

---

### 8.5 `AuditSyncStatus` — Đồng Bộ Log (`Pending = 0`, `InProgress = 1`, `Completed = 2`, `Failed = 3`)
### 8.6 `AppEnvironment` — Môi Trường Hệ Thống (`Development = 0`, `Staging = 1`, `Production = 2`)

---

# PHẦN II: BẢN ĐẶC TẢ CHI TIẾT ENTITIES CỦA 8 SERVICES CHO FRONTEND
## (CORE BUSINESS ENTITY SCHEMAS & FIELD SPECIFICATIONS)

> ⚡ **QUY TẮC MAPPING KIỂU DỮ LIỆU TỪ C# / DB SANG JSON CHO FRONTEND:**
> 1. `Guid / UUID` ➔ `string` (định dạng `36-ký tự` chuẩn UUID v4, ví dụ: `"3fa85f64-5717-4562-b3fc-2c963f66afa6"`).
> 2. `DateTimeOffset / Date` ➔ `string` (chuẩn RFC 3339 / ISO 8601 UTC, ví dụ: `"2026-10-23T08:30:00Z"`).
> 3. `decimal` ➔ `number` (hoặc chuỗi số khi tính toán tiền tệ chính xác).
> 4. `Enum` ➔ `string` (Chuỗi PascalCase trực quan theo danh mục ở Phần I).
> 5. Tất cả tên trường (JSON properties) trả về cho FE đều chuẩn hóa theo **camelCase** (ví dụ: `firstName`, `sellerProfile`, `totalAmount`).
> 6. Không sử dụng Value Object, toàn bộ dữ liệu phản ánh trực tiếp Entity nghiệp vụ đơn giản.

---

## 1. USER SERVICE (Port 8001 | `usermanagement_db`)

### 1.1 Danh Sách 14 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `User` | `Users` | Định danh tài khoản toàn sàn, thông tin cá nhân cơ bản và trạng thái xác thực. |
| `SellerProfile` | `SellerProfiles` | Hồ sơ gian hàng người bán: Tên shop, slug, logo, địa chỉ kinh doanh, trạng thái duyệt. |
| `Role` | `Roles` | Danh mục 4 vai trò cốt lõi (`Buyer`, `Seller`, `SupportStaff`, `Admin`). |
| `UserRole` | `UserRoles` | Phân quyền vai trò người dùng (Một user có thể vừa là Buyer, vừa là Seller). |
| `Permission` | `Permissions` | Danh mục đặc quyền phân tán theo tính năng. |
| `RolePermission` | `RolePermissions` | Gán đặc quyền theo vai trò. |
| `RefreshToken` | `RefreshTokens` | Quản lý phiên đăng nhập đa thiết bị và thu hồi phiên. |
| `ReputationScore` | `ReputationScores` | Điểm uy tín (0 - 100) và cấp bậc tin cậy (`TrustLevel`). |
| `ReputationLog` | `ReputationLogs` | Lịch sử cộng/trừ điểm uy tín kèm lý do và chứng từ tham chiếu. |
| `UserReview` | `UserReviews` | Đánh giá giữa người mua và người bán sau giao dịch. |
| `UserReport` | `UserReports` | Hồ sơ khiếu nại, tố cáo hành vi vi phạm gửi lên Staff xử lý. |
| `UserPenalty` | `UserPenalties` | Quyết định xử phạt, cấm quyền tạm thời hoặc vĩnh viễn. |
| `SystemConfig` | `SystemConfigs` | Cấu hình tham số động hệ thống. |
| `AuditLog` | `AuditLogs` | Vết kiểm toán thao tác quản trị trên dữ liệu User. |

### 1.2 Chi Tiết Các Trường Dữ Liệu Entity `User`:
| Thuộc Tính JSON | Kiểu Dữ Liệu | Nullable | Mô Tả & Ràng Buộc Nghiệp Vụ |
| :--- | :--- | :---: | :--- |
| `id` | `string` (UUID) | Không | Khóa chính duy nhất của người dùng. |
| `email` | `string` | Không | Địa chỉ email duy nhất, chữ thường, dùng đăng nhập. |
| `firstName` | `string` | Không | Họ và tên đệm (tối đa 100 ký tự). |
| `lastName` | `string` | Không | Tên chính (tối đa 100 ký tự). |
| `phoneNumber` | `string?` | Có | Số điện thoại liên lạc (tối đa 50 ký tự). |
| `identifyNumber` | `string?` | Có | Số CMND/CCCD/Hộ chiếu (yêu cầu khi nâng cấp Seller). |
| `avatarUrl` | `string?` | Có | URL ảnh đại diện người dùng. |
| `gender` | `string` (Enum) | Không | `Unspecified`, `Male`, `Female`, `Other`. Mặc định: `Unspecified`. |
| `dateOfBirth` | `string?` (Date) | Có | Ngày sinh (định dạng `YYYY-MM-DD`). |
| `address` | `string?` | Có | Địa chỉ liên lạc mặc định. |
| `status` | `string` (Enum) | Không | `PendingVerification`, `Active`, `Banned`, `Deleted`. Mặc định: `PendingVerification`. |
| `emailVerifiedAt`| `string?` (ISO) | Có | Thời điểm người dùng kích hoạt OTP thành công. |
| `bannedAt` | `string?` (ISO) | Có | Thời điểm bị khóa tài khoản (nếu có). |
| `banReason` | `string?` | Có | Lý do bị khóa tài khoản từ ban quản trị. |
| `createdAt` | `string` (ISO) | Không | Thời điểm tạo tài khoản (UTC). |
| `updatedAt` | `string` (ISO) | Không | Thời điểm cập nhật hồ sơ gần nhất (UTC). |

### 1.3 Chi Tiết Entity `SellerProfile`:
| Thuộc Tính JSON | Kiểu Dữ Liệu | Nullable | Mô Tả |
| :--- | :--- | :---: | :--- |
| `id` | `string` (UUID) | Không | Mã hồ sơ gian hàng. |
| `userId` | `string` (UUID) | Không | Mã định danh chủ shop. |
| `shopName` | `string` | Không | Tên hiển thị của gian hàng (tối đa 150 ký tự). |
| `shopSlug` | `string` | Không | Đường dẫn tĩnh thân thiện (URL Slug, duy nhất). |
| `shopDescription` | `string?` | Có | Giới thiệu gian hàng. |
| `shopLogoUrl` | `string?` | Có | URL logo gian hàng. |
| `businessEmail` | `string?` | Có | Email liên hệ kinh doanh. |
| `businessPhone` | `string?` | Có | Số điện thoại hỗ trợ của shop. |
| `businessAddress` | `string?` | Có | Địa chỉ kho hàng / văn phòng shop. |
| `status` | `string` (Enum) | Không | `Pending`, `Approved`, `Rejected`. |
| `rejectionReason`| `string?` | Có | Lý do từ chối hồ sơ mở shop (nếu bị reject). |
| `approvedAt` | `string?` (ISO) | Có | Thời điểm Staff phê duyệt mở shop thành công. |

---

## 2. CATALOG SERVICE (Port 8002 | `category_db`)

### 2.1 Danh Sách 9 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `Category` | `Categories` | Cây danh mục sản phẩm đa cấp (hỗ trợ phân cấp cha - con). |
| `Product` | `Products` | Thông tin gốc sản phẩm: Tên, mô tả, người bán, hình thức bán. |
| `ProductVariant` | `ProductVariants` | Biến thể hàng hóa cụ thể (SKU): Màu sắc, size, giá bán lẻ, tồn kho. |
| `ProductVariantAttribute` | `ProductVariantAttributes` | Giá trị thuộc tính động của từng biến thể (Color = Red, Size = XL). |
| `ProductImage` | `ProductImages` | Thư viện hình ảnh sản phẩm & biến thể. |
| `ProductRatingStats` | `ProductRatingStats` | Bảng tổng hợp thống kê số sao đánh giá (1-5 sao) và điểm trung bình. |
| `ProductReview` | `ProductReviews` | Đánh giá và nhận xét của khách hàng đối với sản phẩm. |
| `PurchaseRecord` | `PurchaseRecords` | Xác nhận đơn mua hợp lệ để cho phép người dùng viết đánh giá có huy hiệu "Đã mua hàng". |
| `AuditLog` | `AuditLogs` | Ghi vết thay đổi dữ liệu sản phẩm và danh mục. |

### 2.2 Chi Tiết Các Trường Dữ Liệu Entity `Product`:
| Thuộc Tính JSON | Kiểu Dữ Liệu | Nullable | Mô Tả |
| :--- | :--- | :---: | :--- |
| `id` | `string` (UUID) | Không | Mã định danh duy nhất của sản phẩm. |
| `sellerId` | `string` (UUID) | Không | Mã người bán sở hữu sản phẩm. |
| `categoryId` | `string` (UUID) | Không | Mã danh mục sản phẩm thuộc về. |
| `name` | `string` | Không | Tên hiển thị sản phẩm (tối đa 250 ký tự). |
| `slug` | `string` | Không | URL slug thân thiện duy nhất toàn sàn. |
| `description` | `string?` | Có | Nội dung mô tả chi tiết sản phẩm (hỗ trợ HTML/Markdown). |
| `thumbnailUrl` | `string?` | Có | Ảnh đại diện thu nhỏ chính của sản phẩm. |
| `saleType` | `string` (Enum) | Không | `FixedPrice` (Giá cố định), `Auction` (Đấu giá), `Both` (Cả hai). |
| `status` | `string` (Enum) | Không | `Draft` (Nháp), `Active` (Đang bán), `Inactive` (Ngừng bán). |
| `inactiveReason` | `string` (Enum) | Có | `OutOfStock`, `SuspendedByAdmin`, `SellerVoluntary`, `CounterfeitViolation`. |
| `basePrice` | `number` | Không | Giá niêm yết cơ bản (VNĐ). |
| `currency` | `string` | Không | Mặc định: `"VND"`. |
| `createdAt` | `string` (ISO) | Không | Thời điểm tạo sản phẩm (UTC). |

---

## 3. COMMERCE SERVICE (Port 8003 | `commerce_db`)

### 3.1 Danh Sách 16 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `Cart` | `Carts` | Giỏ hàng mua sắm theo từng người dùng. |
| `CartItem` | `CartItems` | Từng mặt hàng trong giỏ, lưu snapshot giá và tên tại thời điểm chọn. |
| `Order` | `Orders` | Đơn hàng tổng (Master Order) gom nhóm thanh toán từ nhiều shop. |
| `SubOrder` | `SubOrders` | Đơn hàng con theo từng Shop riêng biệt (đơn vị xử lý giao nhận thực tế). |
| `SubOrderItem` | `SubOrderItems` | Danh sách sản phẩm, số lượng, đơn giá trong từng đơn con. |
| `AuctionOrder` | `AuctionOrders` | Đơn hàng phát sinh đặc thù từ người thắng cuộc phiên đấu giá. |
| `DiscountCode` | `DiscountCodes` | Định nghĩa mã giảm giá (Voucher/Coupon): Giá trị, hạn mức, thời gian. |
| `DiscountCodeScope` | `DiscountCodeScopes` | Giới hạn áp dụng mã theo Shop, theo Danh mục hoặc Sản phẩm cụ thể. |
| `DiscountCodeUsage` | `DiscountCodeUsages` | Vết lịch sử từng lượt người dùng sử dụng mã voucher. |
| `OrderStatusHistory` | `OrderStatusHistories` | Nhật ký hành trình chuyển đổi trạng thái đơn hàng kèm tác nhân. |
| `OrderInvoice` | `OrderInvoices` | Hồ sơ hóa đơn điện tử phục vụ xuất chứng từ thanh toán. |
| `OrderCancellation` | `OrderCancellations` | Hồ sơ yêu cầu hủy đơn kèm mã lý do hủy. |
| `OrderRefund` | `OrderRefunds` | Hồ sơ yêu cầu hoàn tiền và tiến độ giải ngân hoàn tiền. |
| `SystemSetting` | `SystemSettings` | Tham số cấu hình chính sách thương mại và giới hạn đơn. |
| `DailyOrderSequence` | `DailyOrderSequences` | Bộ sinh mã số đơn hàng tự tăng theo ngày (chống trùng lặp mã đơn). |
| `AuditLog` | `AuditLogs` | Vết kiểm toán nghiệp vụ giỏ hàng và đặt đơn. |

### 3.2 Chi Tiết Các Trường Dữ Liệu Entity `Order` (Master Order):
| Thuộc Tính JSON | Kiểu Dữ Liệu | Nullable | Mô Tả |
| :--- | :--- | :---: | :--- |
| `id` | `string` (UUID) | Không | Mã định danh hệ thống của đơn hàng tổng. |
| `orderNo` | `string` | Không | Mã số đơn hiển thị (ví dụ: `"ORD-20261023-00012"`). |
| `buyerId` | `string` (UUID) | Không | Mã người mua hàng. |
| `status` | `string` (Enum) | Không | `PendingPayment`, `Processing`, `Completed`, `Cancelled`, `Disputed`. |
| `totalAmount` | `number` | Không | Tổng tiền nguyên giá trước khi giảm trừ. |
| `discountAmount` | `number` | Không | Tổng số tiền được giảm giá qua voucher sàn/shop. |
| `shippingAmount` | `number` | Không | Tổng cước phí vận chuyển toàn đơn. |
| `finalAmount` | `number` | Không | Số tiền thực trả cuối cùng của khách hàng. |
| `paymentMethod` | `string` (Enum) | Không | `Wallet`, `Vnpay`, `Cod`. |
| `shippingAddress` | `string` | Không | Địa chỉ nhận hàng đầy đủ của người mua. |
| `placedAt` | `string` (ISO) | Không | Thời điểm khách chốt đặt đơn hàng. |
| `paidAt` | `string?` (ISO) | Có | Thời điểm thanh toán thành công (nếu thanh toán trước). |

---

## 4. AUCTION SERVICE (Port 8005 | `auction_db`)

### 4.1 Danh Sách 13 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `Auction` | `Auctions` | Phòng đấu giá sản phẩm: Giá khởi điểm, bước giá, giá mua ngay, tiền cọc. |
| `AuctionState` | `AuctionStates` | Quản lý trạng thái vòng đời phiên và cơ chế gia hạn tự động (Anti-sniping). |
| `ProductOpenAuction` | `ProductOpenAuctions` | Khóa chống việc mở 2 phiên đấu giá đồng thời cho cùng 1 SKU sản phẩm. |
| `Bid` | `Bids` | Từng lượt đặt giá (Bid) của người tham gia. |
| `BidInvalidation` | `BidInvalidations` | Hồ sơ hủy lượt đặt giá vi phạm quy chế hoặc bị nghi ngờ gian lận. |
| `BidHistory` | `BidHistories` | Nhật ký thứ tự xếp hạng các mức giá cao nhất. |
| `AuctionExtension` | `AuctionExtensions` | Lịch sử các lần gia hạn thời gian (cộng thêm 2-5 phút khi có bid ở phút cuối). |
| `AuctionResult` | `AuctionResults` | Kết quả chốt hạ phiên đấu giá: Người thắng, mức giá trúng, hạn chót thanh toán. |
| `AuctionSettlement` | `AuctionSettlements` | Quyết toán tài chính phiên đấu: Tiền cọc, phí hoa hồng sàn, tiền trả về cho Seller. |
| `AuctionStatusHistory` | `AuctionStatusHistories` | Lịch sử chuyển trạng thái phiên đấu giá. |
| `AuctionConfig` | `AuctionConfigs` | Tham số giới hạn mức giá, bước giá tối thiểu và thời lượng tối đa. |
| `IdempotencyKey` | `IdempotencyKeys` | Khóa Idempotency chống đặt giá lặp do mạng giật. |
| `AuditLog` | `AuditLogs` | Vết kiểm toán phòng đấu giá. |

---

## 5. FULFILLMENT SERVICE (Port 8006 | `fulfillment_db`)

### 5.1 Danh Sách 10 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `Shipment` | `Shipments` | Kiện hàng vận chuyển: Mã vận đơn (`trackingNumber`), hãng vận chuyển, tiền cước. |
| `ShipmentItem` | `ShipmentItems` | Danh mục sản phẩm được đóng gói trong kiện hàng. |
| `ShipmentEvent` | `ShipmentEvents` | Mốc thời gian lộ trình kiện hàng (Lấy hàng ➔ Nhập kho ➔ Đang giao ➔ Giao thành công). |
| `Warehouse` | `Warehouses` | Danh mục kho hàng của Shop hoặc kho liên kết sàn. |
| `InventoryItem` | `InventoryItems` | Tồn kho thực tế của sản phẩm tại từng kho hàng vật lý. |
| `InventoryReservation` | `InventoryReservations` | Phiếu giữ tạm tồn kho trong quá trình khách đặt đơn và chờ thanh toán. |
| `InventoryReservationItem` | `InventoryReservationItems`| Chi tiết số lượng SKU giữ tạm theo đơn. |
| `InventoryLedger` | `InventoryLedgers` | Sổ cái biến động kho: Nhập, xuất, kiểm kê hao hụt, hoàn hàng. |
| `Carrier` | `Carriers` | Đối tác vận chuyển (Giao Hàng Nhanh, Viettel Post, Giao Hàng Tiết Kiệm...). |
| `AuditLog` | `AuditLogs` | Vết kiểm toán thao tác kho vận. |

---

## 6. NOTIFICATION SERVICE (Port 8007 | `notification_db`)

### 6.1 Danh Sách 10 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `NotificationRecord` | `Notifications` | Bản ghi thông báo trong ứng dụng (In-app Notification) cho người dùng. |
| `NotificationDelivery` | `NotificationDeliveries` | Lịch sử gửi thông báo đến các kênh (Email, Push Notification, SMS). |
| `NotificationChannel` | `NotificationChannels` | Cấu hình kênh gửi (FCM, MailKit SMTP, Twilio SMS). |
| `NotificationTemplate` | `NotificationTemplates` | Mẫu nội dung email / tin nhắn động theo mã template. |
| `NotificationPreference`| `NotificationPreferences`| Thiết lập nhận thông báo của người dùng (Bật/tắt email đơn hàng, push khuyến mãi). |
| `DeviceToken` | `DeviceTokens` | Quản lý FCM Push Token của thiết bị di động / trình duyệt Web. |
| `NotificationLog` | `NotificationLogs` | Nhật ký log chi tiết từng lượt gửi thông báo. |
| `EventLog` | `EventLogs` | Nhật ký tiếp nhận sự kiện từ RabbitMQ Message Bus. |
| `BrokerHealthCheck` | `BrokerHealthChecks` | Nhật ký kiểm tra độ sẵn sàng và kết nối tới Message Broker. |
| `AuditLog` | `AuditLogs` | Vết kiểm toán cấu hình thông báo. |

---

## 7. WALLET SERVICE (Port 8008 | `wallet_db`)

### 7.1 Danh Sách 9 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `Wallet` | `Wallets` | Ví tiền người dùng: Số dư khả dụng (`balance`), số dư đóng băng ký quỹ (`lockedBalance`). |
| `WalletAccount` | `WalletAccounts` | Tài khoản hạch toán chi tiết gắn liền với số dư ví. |
| `WalletTransaction` | `WalletTransactions` | Sổ cái giao dịch tiền tệ (Double-entry Ledger): Nạp tiền, trừ tiền mua hàng, hoàn tiền, nhận thanh toán. |
| `WalletTopup` | `WalletTopups` | Giao dịch nạp tiền vào ví qua cổng thanh toán VNPay. |
| `DirectPaymentOrder`| `DirectPaymentOrders`| Đơn thanh toán VNPay trực tiếp không cần qua nạp ví. |
| `WithdrawalRequest` | `WithdrawalRequests` | Yêu cầu rút tiền từ ví về tài khoản ngân hàng của người dùng / Shop. |
| `BankAccount` | `BankAccounts` | Danh sách tài khoản ngân hàng thụ hưởng đã liên kết của người dùng. |
| `VnpayIpnLog` | `VnpayIpnLogs` | Nhật ký nhận Webhook xác nhận thanh toán (IPN) từ VNPay để đối soát. |
| `AuditLog` | `AuditLogs` | Vết kiểm toán giao dịch tài chính nhạy cảm. |

---

## 8. LOG SERVICE (Port 8004 | `log_db`)

### 8.1 Danh Sách 6 Thực Thể Core:
| Tên Entity C# | Bảng CSDL | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- |
| `LogEntry` | `Logs` | Dữ liệu nhật ký tập trung từ toàn bộ 8 services gửi về. |
| `LogEventType` | `LogEventTypes` | Danh mục các mã loại sự kiện hệ thống kèm cờ bật/tắt ghi vết. |
| `CentralAuditLog` | `CentralAuditLogs` | Sổ cái kiểm toán tập trung cho các tác vụ nhạy cảm toàn sàn. |
| `AuditSyncBatch` | `AuditSyncBatches` | Lịch trình và trạng thái đồng bộ log từ các service con về trung tâm. |
| `AppLogFileCatalog` | `AppLogFileCatalogs` | Danh mục quản lý file lưu trữ log định kỳ trên hệ thống file/S3. |
| `SecurityAuditAlert`| `SecurityAuditAlerts` | Cảnh báo an ninh tự động khi phát hiện tấn công Brute-force hoặc bất thường. |

