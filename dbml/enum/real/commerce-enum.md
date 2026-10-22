# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — COMMERCE SERVICE (V2)

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `CartStatus` | `Carts.Status` | `Active (0)` | Trạng thái giỏ hàng của người mua |
| 2 | `OrderStatus` | `Orders.Status` | `PendingPayment (0)` | Trạng thái đơn hàng tổng (Master Order) |
| 3 | `SubOrderStatus` | `SubOrders.Status`, `AuctionOrders.Status`, `OrderStatusHistories.*` | `PendingPayment (0)` | Vòng đời đơn hàng con từng Shop & đơn đấu giá |
| 4 | `PaymentMethod` | `SubOrders.PaymentMethod`, `AuctionOrders.PaymentMethod` | `Wallet (0)` | Phương thức thanh toán đơn hàng |
| 5 | `OrderActorRole` | `OrderStatusHistories.ActorRole`, `OrderCancellations.ActorRole`, `OrderRefunds.ActorRole` | `System (4)` | Vai trò tác nhân can thiệp đơn |
| 6 | `RefundStatus` | `OrderRefunds.Status` | `Requested (0)` | Trạng thái yêu cầu hoàn tiền |
| 7 | `RefundType` | `OrderRefunds.RefundType` | `Full (0)` | Hình thức hoàn tiền (toàn bộ hoặc một phần) |
| 8 | `InvoiceStatus` | `OrderInvoices.Status` | `Generated (0)` | Trạng thái hóa đơn điện tử |
| 9 | `DiscountScopeType` | `DiscountCodes.ScopeType` | — | Phạm vi áp dụng của mã giảm giá |
| 10 | `DiscountType` | `DiscountCodes.DiscountType` | — | Hình thức giảm giá (phần trăm hoặc cố định) |
| 11 | `DiscountStatus` | `DiscountCodes.Status` | `Draft (0)` | Vòng đời mã giảm giá |
| 12 | `DiscountScopeRefType` | `DiscountCodeScopes.ScopeRefType` | — | Loại đối tượng liên kết phạm vi giảm giá |
| 13 | `DiscountUsageStatus` | `DiscountCodeUsages.Status` | `Reserved (0)` | Trạng thái sử dụng/giữ chỗ mã giảm giá |
| 14 | `SettingValueType` | `SystemSettings.ValueType` | `String (0)` | Kiểu dữ liệu cấu hình hệ thống |
| 15 | `SettingCategory` | `SystemSettings.Category` | — | Danh mục nhóm cấu hình hệ thống |
| 16 | `SequenceType` | `DailyOrderSequences.SeqType` | — | Loại chuỗi sinh mã đơn/hóa đơn theo ngày |
| 17 | `CancellationReasonCode`| `OrderCancellations.ReasonCode` | — | Mã lý do hủy đơn hàng |
| 18 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác thương mại |

---

## 2. Chi Tiết Từng Enum

### 2.1 CartStatus – Trạng Thái Giỏ Hàng
* **Bảng CSDL:** `Carts.Status`
* **Kiểu dữ liệu:** `Enum CartStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Active` | Giỏ hàng đang hoạt động, người mua thêm/bớt mặt hàng |
| `1` | `CheckedOut` | Đã hoàn tất gom hàng và chuyển sang tiến trình thanh toán |
| `2` | `Abandoned` | Giỏ hàng quá hạn tương tác (tự động chuyển qua worker) |

---

### 2.2 OrderStatus – Trạng Thái Đơn Hàng Tổng (Master Order)
* **Bảng CSDL:** `Orders.Status`
* **Kiểu dữ liệu:** `Enum OrderStatus`
* **Mô tả:** Đại diện phiên checkout gộp nhiều Shop của người mua.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `PendingPayment` | Chờ thanh toán tiền trước thời hạn `PaymentDeadlineAt` |
| `1` | `PaymentProcessing` | Đang xử lý giao dịch qua cổng thanh toán/ví |
| `2` | `Paid` | Đã thanh toán thành công toàn bộ đơn hàng |
| `3` | `Cancelled` | Đã hủy thanh toán đơn tổng |
| `4` | `Expired` | Quá thời hạn thanh toán quy định (mặc định 15 phút) |

---

### 2.3 SubOrderStatus – Trạng Thái Đơn Hàng Con & Đấu Giá
* **Bảng CSDL:** `SubOrders.Status`, `AuctionOrders.Status`, `OrderStatusHistories.FromStatus`, `OrderStatusHistories.ToStatus`
* **Kiểu dữ liệu:** `Enum SubOrderStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `PendingPayment` | Chờ thanh toán tiền trước thời hạn |
| `1` | `Paid` | Đã thanh toán tiền, chờ người bán xác nhận đơn |
| `2` | `Confirmed` | Người bán đã chấp nhận đơn hàng (`SellerAccepted`) |
| `3` | `Shipping` | Đã bàn giao hàng và đang vận chuyển (`Shipped`) |
| `4` | `Delivered` | Đã giao hàng thành công đến người mua |
| `5` | `Completed` | Đơn hàng hoàn tất trọn vẹn |
| `6` | `Cancelled` | Đơn hàng đã bị hủy |
| `7` | `Refunded` | Đơn hàng đã được hoàn tiền thành công |

---

### 2.4 PaymentMethod – Phương Thức Thanh Toán
* **Bảng CSDL:** `SubOrders.PaymentMethod`, `AuctionOrders.PaymentMethod`
* **Kiểu dữ liệu:** `Enum PaymentMethod`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Wallet` | Thanh toán qua số dư ví nội bộ Nexus |
| `1` | `VnPay` | Thanh toán trực tiếp qua cổng VNPay |
| `2` | `Cod` | Thanh toán khi nhận hàng (chưa hỗ trợ MVP) |

---

### 2.5 OrderActorRole – Vai Trò Tác Nhân Can Thiệp Đơn Hàng
* **Bảng CSDL:** `OrderStatusHistories.ActorRole`, `OrderCancellations.ActorRole`, `OrderRefunds.ActorRole`
* **Kiểu dữ liệu:** `Enum OrderActorRole`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Buyer` | Người mua hàng |
| `1` | `Seller` | Người bán hàng |
| `2` | `Admin` | Quản trị viên sàn |
| `3` | `SupportStaff` | Nhân viên hỗ trợ / CSKH |
| `4` | `System` | Tiến trình hệ thống tự động (Worker, Timeout) |

---

### 2.6 RefundStatus – Trạng Thái Yêu Cầu Hoàn Tiền
* **Bảng CSDL:** `OrderRefunds.Status`
* **Kiểu dữ liệu:** `Enum RefundStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Requested` | Yêu cầu hoàn tiền đã ghi nhận, chờ xử lý bất đồng bộ |
| `1` | `Completed` | Hoàn tiền thành công về ví/tài khoản thanh toán |
| `2` | `Failed` | Giao dịch hoàn tiền thất bại |

---

### 2.7 RefundType – Hình Thức Hoàn Tiền
* **Bảng CSDL:** `OrderRefunds.RefundType`
* **Kiểu dữ liệu:** `Enum RefundType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Full` | Hoàn trả toàn bộ giá trị giao dịch |
| `1` | `Partial` | Hoàn trả một phần giá trị đơn |

---

### 2.8 InvoiceStatus – Trạng Thái Hóa Đơn
* **Bảng CSDL:** `OrderInvoices.Status`
* **Kiểu dữ liệu:** `Enum InvoiceStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Generated` | Hóa đơn điện tử đã khởi tạo thành công |
| `1` | `Failed` | Khởi tạo file hóa đơn thất bại |

---

### 2.9 DiscountScopeType – Phạm Vi Giảm Giá
* **Bảng CSDL:** `DiscountCodes.ScopeType`
* **Kiểu dữ liệu:** `Enum DiscountScopeType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `System` | Mã toàn sàn (Admin tạo, `OwnerSellerId` là NULL) |
| `1` | `Shop` | Mã riêng của gian hàng (Seller tạo, bắt buộc `OwnerSellerId`) |
| `2` | `Product` | Mã giảm riêng theo sản phẩm cụ thể |

---

### 2.10 DiscountType – Hình Thức Giảm Giá
* **Bảng CSDL:** `DiscountCodes.DiscountType`
* **Kiểu dữ liệu:** `Enum DiscountType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Percent` | Giảm theo tỷ lệ phần trăm (giá trị ≤ 100, kèm `MaxDiscountAmount`) |
| `1` | `Fixed` | Giảm số tiền cố định trực tiếp |

---

### 2.11 DiscountStatus – Vòng Đời Mã Giảm Giá
* **Bảng CSDL:** `DiscountCodes.Status`
* **Kiểu dữ liệu:** `Enum DiscountStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Draft` | Bản nháp, đang cấu hình |
| `1` | `Active` | Đang kích hoạt sử dụng |
| `2` | `Inactive` | Đang tạm ngưng áp dụng |
| `3` | `Expired` | Đã hết hạn theo thời gian hoặc lượt dùng |

---

### 2.12 DiscountScopeRefType – Loại Đối Tượng Phạm Vi
* **Bảng CSDL:** `DiscountCodeScopes.ScopeRefType`
* **Kiểu dữ liệu:** `Enum DiscountScopeRefType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Shop` | Áp dụng cho gian hàng người bán |
| `1` | `Product` | Áp dụng cho sản phẩm cụ thể |
| `2` | `Sku` | Áp dụng cho biến thể SKU cụ thể |
| `3` | `Category` | Áp dụng cho toàn bộ danh mục |
| `4` | `All` | Áp dụng cho tất cả (`ScopeRefId` là NULL) |

---

### 2.13 DiscountUsageStatus – Trạng Thái Sử Dụng Mã
* **Bảng CSDL:** `DiscountCodeUsages.Status`
* **Kiểu dữ liệu:** `Enum DiscountUsageStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Reserved` | Đang giữ chỗ trong phiên thanh toán |
| `1` | `Used` | Đã trừ lượt dùng sau khi thanh toán thành công |
| `2` | `Released` | Suất giữ chỗ được hoàn lại do đơn hủy/hết hạn |

---

### 2.14 SettingValueType – Kiểu Dữ Liệu Cấu Hình
* **Bảng CSDL:** `SystemSettings.ValueType`
* **Kiểu dữ liệu:** `Enum SettingValueType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `String` | Kiểu chuỗi ký tự |
| `1` | `Integer` | Kiểu số nguyên |
| `2` | `Decimal` | Kiểu số thập phân |
| `3` | `Boolean` | Kiểu đúng/sai (true/false) |
| `4` | `Json` | Chuỗi định dạng JSON |

---

### 2.15 SettingCategory – Danh Mục Cấu Hình
* **Bảng CSDL:** `SystemSettings.Category`
* **Kiểu dữ liệu:** `Enum SettingCategory`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Reputation` | Cấu hình uy tín người dùng/seller |
| `1` | `Money` | Cấu hình biểu phí, tiền tệ |
| `2` | `Auction` | Cấu hình quy tắc đấu giá |
| `3` | `Timing` | Cấu hình thời hạn timeout, hủy tự động |
| `4` | `System` | Cấu hình hệ thống chung (giới hạn số lượng, retry) |

---

### 2.16 SequenceType – Loại Chuỗi Sinh Mã
* **Bảng CSDL:** `DailyOrderSequences.SeqType`
* **Kiểu dữ liệu:** `Enum SequenceType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `OrderNo` | Chuỗi mã đơn hàng con (`ORD-YYYYMMDD-NNNNNN`) |
| `1` | `AuctionOrderNo` | Chuỗi mã đơn đấu giá (`AOR-YYYYMMDD-NNNNNN`) |
| `2` | `InvoiceNo` | Chuỗi mã hóa đơn (`INV-YYYYMMDD-NNNNNN`) |

---

### 2.17 CancellationReasonCode – Mã Lý Do Hủy Đơn
* **Bảng CSDL:** `OrderCancellations.ReasonCode`
* **Kiểu dữ liệu:** `Enum CancellationReasonCode`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `BuyerChangedMind` | Người mua đổi ý không muốn mua nữa |
| `1` | `OutOfStock` | Người bán hết hàng |
| `2` | `PaymentTimeout` | Quá hạn thanh toán quy định |
| `3` | `SellerRejected` | Người bán từ chối nhận đơn |
| `4` | `Other` | Lý do khác (kèm mô tả trong `ReasonNote`) |

---

### 2.18 AuditAction – Hành Động Kiểm Toán Đơn Hàng & Giỏ Hàng
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `CartCheckout` | Tạo phiên checkout từ giỏ hàng |
| `1` | `OrderCreate` | Khởi tạo đơn hàng mới |
| `2` | `OrderPay` | Ghi nhận thanh toán đơn hàng |
| `3` | `OrderAccept` | Người bán xác nhận đơn |
| `4` | `OrderCancel` | Hủy đơn hàng |
| `5` | `DiscountCreate` | Tạo mới mã giảm giá |
| `6` | `DiscountUpdate` | Cập nhật thông tin mã giảm giá |
| `7` | `InvoiceGenerate` | Xuất hóa đơn điện tử |
