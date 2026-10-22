# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — COMMERCE SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `CartStatus` | `Carts.Status` | `Active (0)` | Trạng thái giỏ hàng của người mua |
| 2 | `OrderStatus` | `Orders.Status` | `PendingPayment (0)` | Trạng thái đơn hàng tổng (Master Order) của người mua |
| 3 | `DiscountScopeType` | `DiscountCodes.ScopeType` | — | Phạm vi áp dụng của mã giảm giá |
| 4 | `DiscountType` | `DiscountCodes.DiscountType` | — | Hình thức giảm giá (phần trăm hoặc số tiền cố định) |
| 5 | `DiscountStatus` | `DiscountCodes.Status` | `Draft (0)` | Vòng đời mã giảm giá *(đã bỏ Disabled/Deleted vì có trường riêng)* |
| 6 | `DiscountScopeRefType` | `DiscountCodeScopes.ScopeRefType` | — | Loại đối tượng liên kết phạm vi giảm giá |
| 7 | `DiscountUsageStatus` | `DiscountCodeUsages.Status` | `Reserved (0)` | Trạng thái giữ chỗ và sử dụng mã giảm giá |
| 8 | `SubOrderStatus` | `SubOrders.Status`, `AuctionOrders.Status`, `OrderStatusHistories.FromStatus`, `OrderStatusHistories.ToStatus` | `PendingPayment (0)` | Vòng đời trạng thái đơn hàng con (SubOrder từng Shop) & đơn đấu giá |
| 9 | `OrderActorRole` | `OrderStatusHistories.ActorRole`, `OrderCancellations.ActorRole` | `System (3)` | Vai trò của tác nhân thực hiện thay đổi/hủy đơn |
| 10 | `InvoiceStatus` | `OrderInvoices.Status` | `Generated (0)` | Trạng thái hóa đơn đơn hàng |
| 11 | `CancellationReasonCode`| `OrderCancellations.ReasonCode` | — | Mã lý do hủy đơn hàng |
| 12 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác thương mại |

---

## 2. Chi Tiết Từng Enum

### 2.1 CartStatus – Trạng Thái Giỏ Hàng
* **Bảng CSDL:** `Carts.Status`
* **Kiểu dữ liệu:** `Enum CartStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Active` | Giỏ hàng đang hoạt động, người mua đang thêm/bớt hàng |
| `1` | `Abandoned` | Giỏ hàng bị bỏ quên (không có tương tác sau một thời gian dài) |
| `2` | `Converted` | Đã chuyển đổi thành công sang bước tạo đơn hàng (Checkout) |

---

### 2.2 OrderStatus – Trạng Thái Đơn Hàng Tổng (Master Order)
* **Bảng CSDL:** `Orders.Status`
* **Kiểu dữ liệu:** `Enum OrderStatus`
* **Mô tả:** Đơn hàng tổng của người mua khi checkout nhiều shop trong 1 lần thanh toán.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `PendingPayment` | Đang chờ người mua thanh toán tiền trước thời hạn `PaymentDeadlineAt` |
| `1` | `Paid` | Đã thanh toán thành công toàn bộ số tiền của các đơn con |
| `2` | `Failed` | Giao dịch thanh toán đơn hàng thất bại |
| `3` | `Expired` | Quá thời hạn thanh toán quy định, tự động hủy giữ chỗ |
| `4` | `Cancelled` | Người mua chủ động hủy đơn hàng tổng |

---

### 2.3 DiscountScopeType – Phạm Vi Giảm Giá
* **Bảng CSDL:** `DiscountCodes.ScopeType`
* **Kiểu dữ liệu:** `Enum DiscountScopeType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Global` | Mã toàn sàn (do Admin tạo, áp dụng cho mọi sản phẩm/shop) |
| `1` | `Shop` | Mã riêng của gian hàng (do Seller tạo) |
| `2` | `Category` | Mã áp dụng riêng cho một danh mục hàng hóa cụ thể |
| `3` | `Product` | Mã áp dụng riêng cho sản phẩm cụ thể |

---

### 2.4 DiscountType – Hình Thức Giảm Giá
* **Bảng CSDL:** `DiscountCodes.DiscountType`
* **Kiểu dữ liệu:** `Enum DiscountType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Percentage` | Giảm theo tỷ lệ phần trăm (kèm `MaxDiscountAmount`) |
| `1` | `FixedAmount` | Giảm số tiền cố định trực tiếp |

---

### 2.5 DiscountStatus – Vòng Đời Mã Giảm Giá
* **Bảng CSDL:** `DiscountCodes.Status`
* **Kiểu dữ liệu:** `Enum DiscountStatus`
* **Ghi chú:** Trạng thái tạm ẩn do cờ `IsDisabled` quản lý; xóa mềm do cờ `IsDeleted` quản lý. Enum chỉ tập trung vào tiến độ thời gian hiệu lực.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Draft` | Bản nháp, người bán hoặc admin đang cài đặt |
| `1` | `Active` | Đang kích hoạt và sẵn sàng cho người mua áp dụng |
| `2` | `Expired` | Đã hết hạn sử dụng theo mốc `EndsAt` hoặc hết số lượt dùng |

---

### 2.6 DiscountScopeRefType – Loại Đối Tượng Phạm Vi
* **Bảng CSDL:** `DiscountCodeScopes.ScopeRefType`
* **Kiểu dữ liệu:** `Enum DiscountScopeRefType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Category` | Tham chiếu ID danh mục sản phẩm |
| `1` | `Product` | Tham chiếu ID sản phẩm |
| `2` | `Shop` | Tham chiếu ID người bán (Seller) |

---

### 2.7 DiscountUsageStatus – Trạng Thái Sử Dụng Mã
* **Bảng CSDL:** `DiscountCodeUsages.Status`
* **Kiểu dữ liệu:** `Enum DiscountUsageStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Reserved` | Đang giữ chỗ trong tiến trình thanh toán (đặt cờ giữ suất) |
| `1` | `Used` | Đã sử dụng thành công khi đơn hàng được thanh toán |
| `2` | `Released` | Suất giữ chỗ được giải phóng do đơn thanh toán thất bại hoặc hủy |
| `3` | `Expired` | Giữ chỗ hết hạn do quá thời gian hoàn tất đơn |

---

### 2.8 SubOrderStatus – Trạng Thái Đơn Hàng Con & Đấu Giá
* **Bảng CSDL:** `SubOrders.Status`, `AuctionOrders.Status`, `OrderStatusHistories.FromStatus`, `OrderStatusHistories.ToStatus`
* **Kiểu dữ liệu:** `Enum SubOrderStatus`
* **Mô tả:** Vòng đời đơn hàng chi tiết từng gian hàng (SubOrder) và đơn đấu giá (AuctionOrder).

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `PendingPayment` | Chờ thanh toán tiền trước thời hạn `PaymentDeadlineAt` |
| `1` | `Paid` | Đã thanh toán thành công, chờ người bán phản hồi xác nhận đơn |
| `2` | `SellerAccepted` | Người bán đã chấp nhận đơn hàng và chuẩn bị đóng gói |
| `3` | `Shipped` | Đã bàn giao hàng cho đơn vị vận chuyển, đang giao |
| `4` | `Delivered` | Đã giao hàng thành công đến địa chỉ người mua |
| `5` | `Completed` | Đơn hàng hoàn tất trọn vẹn (hết hạn đổi trả/khiếu nại) |
| `6` | `Cancelled` | Đơn hàng đã bị hủy (kèm theo bản ghi trong `OrderCancellations`) |

---

### 2.9 OrderActorRole – Vai Trò Tác Nhân Can Thiệp Đơn Hàng
* **Bảng CSDL:** `OrderStatusHistories.ActorRole`, `OrderCancellations.ActorRole`
* **Kiểu dữ liệu:** `Enum OrderActorRole`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Buyer` | Người mua hàng |
| `1` | `Seller` | Người bán hàng |
| `2` | `Admin` | Quản trị viên sàn |
| `3` | `System` | Tiến trình ngầm tự động (Timeout, Worker) |

---

### 2.10 InvoiceStatus – Trạng Thái Hóa Đơn Đơn Hàng
* **Bảng CSDL:** `OrderInvoices.Status`
* **Kiểu dữ liệu:** `Enum InvoiceStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Generated` | Hóa đơn điện tử đã được tạo thành công |
| `1` | `Paid` | Hóa đơn đã được thanh toán |
| `2` | `Cancelled` | Hóa đơn bị hủy cùng đơn hàng |
| `3` | `Refunded` | Hóa đơn đã được xử lý hoàn tiền |

---

### 2.11 CancellationReasonCode – Mã Lý Do Hủy Đơn
* **Bảng CSDL:** `OrderCancellations.ReasonCode`
* **Kiểu dữ liệu:** `Enum CancellationReasonCode`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `BuyerChangedMind` | Người mua đổi ý không muốn mua nữa |
| `1` | `OutOfStock` | Người bán hết hàng không thể cung cấp |
| `2` | `PaymentTimeout` | Quá hạn thanh toán theo quy định sàn |
| `3` | `SellerRejected` | Người bán từ chối nhận đơn |
| `4` | `Other` | Lý do khác (kèm ghi chú trong `ReasonNote`) |

---

### 2.12 AuditAction – Hành Động Kiểm Toán Đơn Hàng & Giỏ Hàng
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
