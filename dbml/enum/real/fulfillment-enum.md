# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — FULFILLMENT SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `WarehouseType` | `Warehouses.Type` | `PlatformWarehouse (1)` | Phân loại mô hình kho bãi lưu trữ hàng hóa |
| 2 | `InventoryReservationStatus` | `InventoryReservations.Status` | `Pending (0)` | Trạng thái giữ chỗ tồn kho (cho đơn hàng/phiên đấu giá) |
| 3 | `InventoryReservationReferenceType` | `InventoryReservations.ReferenceType` | — | Loại giao dịch giữ chỗ tồn kho tham chiếu |
| 4 | `InventoryMovementType` | `InventoryLedgers.MovementType` | — | Loại biến động xuất/nhập/điều chuyển tồn kho (Ledger) |
| 5 | `InventoryLedgerReferenceType` | `InventoryLedgers.ReferenceType` | — | Nguồn tham chiếu phát sinh biến động tồn kho |
| 6 | `ShippingServiceType` | `Shipments.ServiceType` | `Standard (0)` | Gói dịch vụ vận chuyển giao nhận |
| 7 | `ShipmentStatus` | `Shipments.Status` | `ReadyToPick (0)` | Vòng đời kiện hàng từ xuất kho đến tay người mua |
| 8 | `ShipmentEventStatus` | `ShipmentEvents.Status` | — | Mã trạng thái chuẩn hóa của sự kiện hành trình giao hàng |
| 9 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác kho vận |

---

## 2. Chi Tiết Từng Enum

### 2.1 WarehouseType – Loại Kho Hàng
* **Bảng CSDL:** `Warehouses.Type`
* **Kiểu dữ liệu:** `Enum WarehouseType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `SellerWarehouse` | Kho riêng của Người bán (Shop tự quản lý đóng hàng) |
| `1` | `PlatformWarehouse` | Kho trung tâm vận hành tập trung của Sàn |
| `2` | `Consignment` | Kho ký gửi hàng hóa đảm bảo cho các phiên đấu giá đặc biệt |

---

### 2.2 InventoryReservationStatus – Trạng Thái Giữ Chỗ Tồn Kho
* **Bảng CSDL:** `InventoryReservations.Status`
* **Kiểu dữ liệu:** `Enum InventoryReservationStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Đang tạm giữ hàng trong lúc chờ thanh toán hoặc mở phiên đấu giá |
| `1` | `Confirmed` | Đã xác nhận trừ kho chính thức khi đơn hàng đã thanh toán thành công |
| `2` | `Released` | Đã giải phóng số lượng giữ chỗ trả lại kho khả dụng (do hủy đơn/hết hạn) |
| `3` | `Expired` | Giữ chỗ hết hạn do quá thời gian hoàn tất thủ tục |

---

### 2.3 InventoryReservationReferenceType – Loại Tham Chiếu Giữ Chỗ
* **Bảng CSDL:** `InventoryReservations.ReferenceType`
* **Kiểu dữ liệu:** `Enum InventoryReservationReferenceType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Order` | Giữ hàng cho đơn mua sắm thông thường (Commerce Service) |
| `1` | `AuctionCheckout` | Giữ hàng phục vụ phiên đấu giá (Auction Service) |
| `2` | `Manual` | Admin / Quản lý kho khóa giữ hàng thủ công |

---

### 2.4 InventoryMovementType – Loại Biến Động Sổ Kho (Ledger)
* **Bảng CSDL:** `InventoryLedgers.MovementType`
* **Kiểu dữ liệu:** `Enum InventoryMovementType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Inbound` | Nhập hàng mới vào kho |
| `1` | `Outbound` | Xuất kho giao hàng cho đối tác vận chuyển |
| `2` | `Reserve` | Tạm khóa giữ số lượng tồn kho khả dụng |
| `3` | `Release` | Mở khóa trả lại số lượng khả dụng |
| `4` | `Adjustment` | Kiểm kê cân chỉnh số lượng thực tế |
| `5` | `Return` | Nhập lại kho do đơn hàng giao không thành công hoặc khách trả lại |

---

### 2.5 InventoryLedgerReferenceType – Nguồn Tham Chiếu Biến Động Kho
* **Bảng CSDL:** `InventoryLedgers.ReferenceType`
* **Kiểu dữ liệu:** `Enum InventoryLedgerReferenceType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Order` | Phát sinh từ đơn hàng thương mại |
| `1` | `Reservation` | Phát sinh từ lệnh giữ chỗ kho |
| `2` | `Audit` | Phát sinh từ đợt kiểm kê kho định kỳ |
| `3` | `StockIn` | Phát sinh từ phiếu nhập kho của người bán |

---

### 2.6 ShippingServiceType – Gói Cước Vận Chuyển
* **Bảng CSDL:** `Shipments.ServiceType`
* **Kiểu dữ liệu:** `Enum ShippingServiceType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Standard` | Giao hàng tiêu chuẩn (2-4 ngày) |
| `1` | `Express` | Giao hàng hỏa tốc (24-48 giờ) |
| `2` | `SameDay` | Giao hàng ngay trong ngày nội thành |

---

### 2.7 ShipmentStatus – Trạng Thái Kiện Hàng Vận Chuyển
* **Bảng CSDL:** `Shipments.Status`
* **Kiểu dữ liệu:** `Enum ShipmentStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `ReadyToPick` | Đơn hàng sẵn sàng chờ nhân viên/seller lấy hàng đóng gói |
| `1` | `Picking` | Đang trong quá trình nhặt hàng trong kho |
| `2` | `Packed` | Đã đóng gói xong, dán mã vận đơn, chờ bàn giao |
| `3` | `HandedOver` | Đã bàn giao cho đơn vị vận chuyển (GHN, ViettelPost...) |
| `4` | `InTransit` | Đang trên đường luân chuyển liên tỉnh/vùng |
| `5` | `Delivered` | Đã giao thành công đến tay người nhận |
| `6` | `DeliveryFailed` | Giao hàng thất bại (khách không nghe máy, sai địa chỉ) |
| `7` | `Returned` | Chuyển hoàn về lại kho gửi |
| `8` | `Cancelled` | Kiện hàng bị hủy trước khi bàn giao |

---

### 2.8 ShipmentEventStatus – Mã Sự Kiện Hành Trình
* **Bảng CSDL:** `ShipmentEvents.Status`
* **Kiểu dữ liệu:** `Enum ShipmentEventStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Created` | Tạo mã kiện hàng trên hệ thống hãng vận chuyển |
| `1` | `PickedUp` | Shipper đã lấy hàng thành công |
| `2` | `InTransit` | Kiện hàng đến kho phân loại trung chuyển |
| `3` | `OutForDelivery` | Shipper đang đi giao cho người nhận |
| `4` | `Delivered` | Giao hàng thành công có chữ ký |
| `5` | `DeliveryFailed` | Thử giao không thành công |
| `6` | `Returned` | Kiện hàng hoàn về kho xuất phát |

---

### 2.9 AuditAction – Hành Động Kiểm Toán Kho Vận
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `WarehouseCreate` | Khởi tạo thông tin kho hàng |
| `1` | `WarehouseUpdate` | Cập nhật địa chỉ / thông tin kho |
| `2` | `InventoryAdjust` | Điều chỉnh số lượng tồn kho |
| `3` | `StockIn` | Tạo phiếu nhập kho |
| `4` | `ReservationCreate` | Giữ chỗ tồn kho |
| `5` | `ReservationConfirm`| Xác nhận trừ kho |
| `6` | `ReservationRelease`| Giải phóng số lượng giữ chỗ |
| `7` | `ShipmentCreate` | Khởi tạo đơn vận chuyển |
| `8` | `ShipmentDispatch` | Bàn giao hàng cho bên vận chuyển |
| `9` | `ShipmentDeliver` | Xác nhận giao hàng hoàn tất |
