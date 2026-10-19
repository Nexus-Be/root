# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — AUCTION SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `AuctionStatus` | `AuctionStates.Status`, `AuctionStatusHistories.FromStatus`, `AuctionStatusHistories.ToStatus` | `Draft (0)` | Vòng đời trạng thái phiên đấu giá |
| 2 | `SagaState` | `SagaStates.CurrentState` | — | Tiến độ luồng Saga điều phối (Đấu giá -> Đơn hàng -> Thanh toán) |
| 3 | `SagaType` | `SagaStates.SagaType` | `AuctionOrderSaga (0)` | Phân loại quy trình Saga |
| 4 | `IdempotencyScope` | `IdempotencyKeys.Scope` | — | Phạm vi áp dụng của khóa chống trùng lặp |
| 5 | `BidInvalidationReason`| `BidInvalidations.Reason` | — | Lý do hủy tư cách lượt đặt giá |
| 6 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác đấu giá |

---

## 2. Chi Tiết Từng Enum

### 2.1 AuctionStatus – Trạng Thái Phiên Đấu Giá
* **Bảng CSDL:** `AuctionStates.Status`, `AuctionStatusHistories.FromStatus`, `AuctionStatusHistories.ToStatus`
* **Kiểu dữ liệu:** `Enum AuctionStatus`
* **Mô tả:** Kiểm soát toàn bộ vòng đời của phiên đấu giá từ khi tạo bản nháp tới khi thanh toán hoàn tất hoặc thất bại.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Draft` | Mới tạo, đang chờ Fulfillment xác nhận giữ 1 sản phẩm từ kho đấu giá |
| `1` | `Scheduled` | Đã giữ kho thành công, đang đếm ngược chờ đến giờ bắt đầu |
| `2` | `Running` | Phiên đang diễn ra, người dùng có thể tham gia đặt giá (Bid) |
| `3` | `Ended` | Đã hết thời gian đấu giá, khóa sổ phiên và chờ tiến trình tạo đơn / thanh toán |
| `4` | `Settled` | Hoàn tất thành công: người thắng đã trả tiền và người bán đã chấp nhận đơn |
| `5` | `Failed` | Thất bại: lỗi giữ kho, không có ai đặt giá, quá hạn thanh toán hoặc người bán từ chối |
| `6` | `Cancelled` | Quản trị viên hủy phiên (bắt buộc nhập lý do), chỉ được hủy khi phiên chưa `Ended` |

---

### 2.2 SagaState – Tiến Trình Điều Phối Saga S2
* **Bảng CSDL:** `SagaStates.CurrentState`
* **Kiểu dữ liệu:** `Enum SagaState`
* **Mô tả:** Trạng thái máy điều phối Saga S2 (Auction $\rightarrow$ Commerce $\rightarrow$ Wallet/Payment).

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `OrderRequested` | Đã gửi kết quả phiên sang Commerce Service, chờ tạo đơn hàng |
| `1` | `AwaitingPayment` | Đơn hàng đã tạo thành công, chờ người thắng thanh toán trước thời hạn |
| `2` | `AwaitingSeller` | Người mua đã thanh toán, chờ người bán xác nhận chấp nhận đơn hàng |
| `3` | `Completed` | Saga hoàn tất trơn tru, phiên chuyển sang `Settled` |
| `4` | `Failed` | Saga gặp sự cố/quá hạn/bị từ chối, phiên chuyển sang `Failed` |

---

### 2.3 SagaType – Phân Loại Quy Trình Saga
* **Bảng CSDL:** `SagaStates.SagaType`
* **Kiểu dữ liệu:** `Enum SagaType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `AuctionOrderSaga` | Luồng điều phối chuyển kết quả đấu giá thành đơn hàng thương mại (Saga S2) |

---

### 2.4 IdempotencyScope – Phạm Vi Khóa Chống Trùng
* **Bảng CSDL:** `IdempotencyKeys.Scope`
* **Kiểu dữ liệu:** `Enum IdempotencyScope`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Bid` | Thao tác đặt giá từ người tham gia đấu giá |
| `1` | `Settlement` | Thao tác kích hoạt chốt phiên và khởi chạy Saga thanh toán |

---

### 2.5 BidInvalidationReason – Lý Do Hủy Lượt Đặt Giá
* **Bảng CSDL:** `BidInvalidations.Reason`
* **Kiểu dữ liệu:** `Enum BidInvalidationReason`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `BidderBanned` | Người tham gia bị khóa tài khoản vi phạm chính sách trong lúc phiên đang chạy |

---

### 2.6 AuditAction – Hành Động Kiểm Toán Đấu Giá
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `AuctionCreate` | Tạo mới phiên đấu giá |
| `1` | `AuctionUpdate` | Cập nhật thông số phiên đấu giá |
| `2` | `AuctionCancel` | Quản trị viên hủy bỏ phiên |
| `3` | `BidPlace` | Ghi nhận lượt đặt giá |
| `4` | `BidInvalidate` | Vô hiệu hóa lượt đặt giá |
| `5` | `AuctionSettle` | Quyết toán / chốt kết quả phiên đấu giá |
| `6` | `ConfigUpdate` | Cập nhật cấu hình tham số đấu giá |
