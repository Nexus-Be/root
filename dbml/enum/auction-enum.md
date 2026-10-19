# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM (AUCTION SERVICE)

## 1. AuctionStatus – Trạng thái phiên đấu giá

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `DRAFT` | Mới tạo, chờ Fulfillment giữ 1 món từ kho đấu giá |
| `2` | `SCHEDULED` | Đã giữ kho, chờ đến giờ bắt đầu |
| `3` | `RUNNING` | Đang nhận giá |
| `4` | `ENDED` | Đã khóa phiên, chờ xử lý đơn (thanh toán, seller xác nhận) |
| `5` | `SETTLED` | Hoàn tất, người thắng đã thanh toán và seller đã chấp nhận |
| `6` | `FAILED` | Không thành: giữ kho lỗi, không ai bid, quá hạn thanh toán hoặc seller từ chối |
| `7` | `CANCELLED` | Admin hủy phiên (bắt buộc ghi lý do), chỉ hủy được khi chưa ENDED |

---

## 2. SagaState – Tiến độ luồng đấu giá $\rightarrow$ đơn hàng

* **Cột CSDL:** `saga_state.current_state`

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `ORDER_REQUESTED` | Đã gửi kết quả sang Commerce, chờ tạo đơn |
| `2` | `AWAITING_PAYMENT` | Đơn đã tạo, chờ người thắng thanh toán trước hạn |
| `3` | `AWAITING_SELLER` | Đã thanh toán, chờ seller chấp nhận hoặc từ chối đơn |
| `4` | `COMPLETED` | Hoàn tất, phiên chuyển sang `SETTLED` |
| `5` | `FAILED` | Thất bại, phiên chuyển sang `FAILED` |

---

## 3. OutboxStatus

* **Cột CSDL:** `outbox_messages.status`

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `PENDING` | Đã ghi, chờ gửi lên message broker |
| `2` | `PUBLISHED` | Đã gửi thành công |
| `3` | `FAILED` | Gửi lỗi, sẽ thử lại |
| `4` | `DEAD` | Lỗi quá số lần thử, cần xử lý thủ công |

---

## 4. InboxStatus

* **Cột CSDL:** `inbox_messages.status`

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `RECEIVED` | Đã nhận, chưa xử lý |
| `2` | `PROCESSED` | Đã xử lý xong |
| `3` | `FAILED` | Xử lý lỗi, sẽ thử lại |
| `4` | `SKIPPED` | Bỏ qua (event trùng hoặc không liên quan) |

---

## 5. IdempotencyScope – Loại thao tác của mã chống gửi trùng

* **Cột CSDL:** `idempotency_keys.scope`

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `BID` | Thao tác đặt giá |
| `2` | `SETTLEMENT` | Thao tác chốt phiên |

---

## 6. SagaType – Loại saga

* **Cột CSDL:** `saga_state.saga_type`

| Số enum | Giá trị | Ý nghĩa |
| :--- | :--- | :--- |
| `1` | `AuctionOrderSaga` | Luồng đấu giá $\rightarrow$ đơn hàng $\rightarrow$ thanh toán (do Auction điều phối) |