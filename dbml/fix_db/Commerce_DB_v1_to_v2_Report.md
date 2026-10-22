# Report: Thay đổi DB Commerce v1 → v2

**Đối tượng đọc:** Backend Lead / thành viên codebase cần nắm kiến trúc DB của **Commerce Service**.
**Nguồn:** `DB Commerce (1).sql` (v1) và `DB_Commerce_v2.sql` (v2). Database: PostgreSQL.
**Cấu trúc:** Phần 1 – Mô tả thay đổi. Phần 2 – Code DBML cho dbdiagram.io.

> Ghi chú ngôn ngữ: thuật ngữ tiếng Anh được giữ nguyên và có chú thích (English support) ở cuối report.

---

# PHẦN 1 – MÔ TẢ THAY ĐỔI

## 1. Tóm tắt nhanh (TL;DR)

| Hạng mục | v1 | v2 |
|---|---|---|
| Số bảng | 18 | **19** (thêm `order_refunds`) |
| Foreign key | 14 | **18** (4 FK mới của `order_refunds`) |
| Index tường minh (ngoài PK/UNIQUE cột) | 0 | **44** (nhiều cái là *partial index*) |
| CHECK constraint | 0 | Rất nhiều (status, số tiền, XOR reference, invariant tiền) |
| Seed data | Không | 7 dòng `system_settings` |
| Optimistic lock | `checkout_groups`, `orders`, `auction_orders`, `saga_state` | + `carts`, + `order_refunds` |

**Tư tưởng của v2:** v1 chỉ là "khung bảng" (chỉ có cột, PK, FK). v2 chuyển các quy tắc nghiệp vụ quan trọng **xuống tầng DB** để DB tự bảo vệ dữ liệu (data integrity), đồng thời thêm index đúng theo từng API và từng job nền, và bổ sung bảng refund đã thiếu ở v1.

Ba nhóm thay đổi chính:
1. **[NEW]** Bảng `order_refunds` (hoàn tiền, hỗ trợ hoàn một phần).
2. **[FIX – Integrity]** Thêm CHECK, UNIQUE, cột mới để chặn dữ liệu sai ngay từ DB.
3. **[FIX – Performance]** Thêm index (Postgres **không** tự tạo index cho FK) gắn với API/job cụ thể.

> Giả định của v2: **tạo schema mới, chưa có dữ liệu**. Nếu đã có dữ liệu, xem mục 9 (Migration checklist).

---

## 2. Kiến trúc DB Commerce (để nắm bức tranh chung)

Commerce Service sở hữu 19 bảng, chia thành 6 nhóm:

| Nhóm | Bảng | Vai trò |
|---|---|---|
| **Cart & Checkout** | `carts`, `cart_items`, `checkout_groups` | Giỏ hàng → gom nhiều order thành một lần thanh toán (checkout group) |
| **Order thường** | `orders`, `order_items` | Mỗi seller một `order` trong cùng checkout group; item là snapshot |
| **Order đấu giá** | `auction_orders` | Đơn tạo từ kết quả đấu giá (1 auction = 1 đơn), không đi qua cart |
| **Vòng đời order** | `order_status_history`, `order_cancellations`, `order_refunds` **[NEW]**, `order_invoices` | Lịch sử trạng thái, huỷ, hoàn tiền, hoá đơn. Dùng chung cho cả `orders` và `auction_orders` |
| **Discount** | `discount_codes`, `discount_code_scopes`, `discount_code_usages` | Voucher SYSTEM / SHOP / PRODUCT, phạm vi áp dụng, lượt dùng (reserve → use → release) |
| **Hạ tầng / config** | `system_settings`, `daily_order_sequences`, `saga_state`, `outbox_messages`, `inbox_messages`, `idempotency_keys` | Config, sinh số đơn theo ngày, Saga, Outbox/Inbox pattern, idempotency |

**Nguyên tắc xuyên suốt (không đổi giữa v1 và v2):**
- Microservice: các cột như `buyer_id`, `seller_id`, `product_id`, `sku_id`, `wallet_transaction_id`... là **cross-service reference** (chỉ lưu UUID, **không có FK** sang service khác, được ghi rõ trong `COMMENT`).
- **Snapshot**: `product_name_snapshot`, `unit_price_snapshot`, `shipping_address`... lưu giá trị tại thời điểm tạo để không phụ thuộc thay đổi của Catalog.
- **Optimistic locking** bằng `row_version`.
- **Soft delete** bằng `deleted_at` ở các bảng chính.
- **Money** = `numeric(18,2)`, thời gian = `timestamptz`, PK = `uuid` (`gen_random_uuid()`; cần PostgreSQL 13+ hoặc extension `pgcrypto`).
- FK đều `DEFERRABLE INITIALLY IMMEDIATE`.

Luồng tổng quát: `carts/cart_items` → (checkout) → `checkout_groups` → `orders` (mỗi seller một đơn) → `order_items`. Đơn đấu giá đi riêng qua `auction_orders`. Mọi thay đổi trạng thái ghi vào `order_status_history`; huỷ ghi vào `order_cancellations`; tiền hoàn đi qua `order_refunds` rồi sang Payment Service bằng outbox.

---

## 3. Bảng tổng hợp thay đổi theo từng bảng

Ký hiệu: **[NEW]** bảng/cột mới · **[FIX]** sửa/bổ sung ràng buộc · **[IDX]** thêm index · **[=]** không đổi.

| Bảng | Thay đổi chính ở v2 |
|---|---|
| `carts` | [NEW col] `row_version` · [FIX] CHECK `status`, CHECK `item_count>=0 AND subtotal_amount>=0` · [IDX] unique 1 giỏ ACTIVE/buyer, index job abandon |
| `cart_items` | [FIX] UNIQUE `(cart_id, sku_id)`, CHECK `quantity>0`, CHECK `unit_price_snapshot>=0` · [IDX] `product_id` |
| `checkout_groups` | [NEW col] `payment_attempt_count` · [FIX] CHECK `status` (5 giá trị), CHECK số tiền/lần thử · [IDX] unique 1 checkout đang mở/cart, theo buyer, job expire |
| `orders` | [FIX] CHECK `status` (**thêm `CONFIRMED`**), `payment_method`, số tiền ≥ 0, **invariant tổng tiền** · [IDX] 7 index theo API/job |
| `order_items` | [FIX] CHECK `quantity>0`, các số tiền ≥ 0 · [IDX] `order_id` |
| `auction_orders` | [NEW col] `image_url_snapshot`, `sku_attributes_snapshot` · [FIX] CHECK status (thêm `CONFIRMED`), payment_method, amounts, total · [IDX] 6 index |
| `order_status_history` | [FIX] CHECK XOR `order_id`/`auction_order_id`, CHECK `actor_role` · [IDX] 2 partial index |
| `order_cancellations` | [FIX] CHECK XOR, CHECK `actor_role` · [IDX] unique mỗi đơn huỷ 1 lần · cột `refund_transaction_id` **DEPRECATED** |
| **`order_refunds`** | **[NEW TABLE]** + 4 FK + 6 index + 6 CHECK |
| `order_invoices` | [FIX] CHECK XOR, CHECK `status` · [IDX] unique mỗi đơn 1 hoá đơn |
| `discount_codes` | [FIX] 7 CHECK (scope, owner, type, value, amounts, status, counts, period) · [IDX] unique `lower(code)`, index list voucher |
| `discount_code_scopes` | [FIX] CHECK type, CHECK ALL ⇔ ref NULL · [IDX] unique chống trùng scope, index tra ngược |
| `discount_code_usages` | [FIX] CHECK status, CHECK ref, CHECK amount · [IDX] 3 index |
| `system_settings` | [FIX] CHECK `value_type`, `category` · **[SEED]** 7 setting |
| `daily_order_sequences` | [FIX] CHECK `seq_type`, `last_value>=0` |
| `saga_state` | [FIX] CHECK `saga_type` · [IDX] quét saga treo · bổ sung COMMENT các state |
| `outbox_messages` | [FIX] CHECK `status` · [IDX] pending, cleanup |
| `inbox_messages` | [FIX] CHECK `status` · [IDX] retry |
| `idempotency_keys` | [IDX] `expires_at` cho job dọn |

---

## 4. Chi tiết thay đổi

### 4.1 [NEW] Bảng `order_refunds`

**Vì sao thêm?** v1 chỉ có `order_cancellations.refund_transaction_id` (1 cột), không thể biểu diễn: refund đang xử lý (async), refund thất bại, hoàn một phần, refund "tiền về muộn" của cả checkout group. v2 tách thành bảng riêng; mỗi dòng là **một yêu cầu hoàn tiền gửi sang Payment Service** (bất đồng bộ qua outbox).

**Thiết kế chính:**

| Khía cạnh | Chi tiết |
|---|---|
| Đối tượng được hoàn | **Đúng 1 trong 3**: `order_id` / `auction_order_id` / `checkout_group_id` (CHECK `num_nonnulls(...) = 1`) |
| Ý nghĩa 3 loại | `order_id` = hoàn **một phần** giao dịch của group; `auction_order_id` = đơn đấu giá; `checkout_group_id` = hoàn **toàn bộ** giao dịch của group (tiền về muộn / lệch số tiền ở PAY-01) |
| Trạng thái | `REQUESTED` → `COMPLETED` hoặc `FAILED` |
| Loại hoàn | `refund_type` = `FULL` / `PARTIAL` |
| Liên kết huỷ đơn | `cancellation_id` → `order_cancellations.id`. **NULL** nếu refund thủ công (ORD-13) |
| Giao dịch gốc | `wallet_transaction_id` = giao dịch thanh toán gốc cần hoàn (`originalWalletTransactionId`) |
| Giao dịch hoàn | `refund_transaction_id` điền khi nhận kết quả (ORD-14) |
| Đối soát | `request_event_id` = `outbox_messages.id` của event `OrderRefundRequested`; `failure_code` = mã lỗi khi `RefundFailed` |
| Lock | `row_version` |

**Constraint/Index quan trọng:**
- `ck_order_refunds_done`: nếu `status = COMPLETED` thì **bắt buộc** có `completed_at` và `refund_transaction_id`.
- 3 unique partial index `uq_order_refunds_{order|auction|group}_active`: chỉ cho **1 refund đang hoạt động** (`REQUESTED` hoặc `COMPLETED`) trên mỗi order/auction/group. `FAILED` thì được tạo lại. (Chống refund trùng, ORD-13.)
- `uq_order_refunds_txn`: unique `refund_transaction_id` → xử lý **idempotent** khi nhận kết quả (ORD-14).
- `idx_order_refunds_pending`: Support tìm refund treo (`REQUESTED`) / lỗi (`FAILED`).

> ⚠️ Xem mục 7 về hạn chế của unique index này với "hoàn một phần nhiều lần".

### 4.2 Cart & Checkout

**`carts`**
- Thêm `row_version` (optimistic lock cho CART-02/03).
- CHECK `status IN (ACTIVE, CHECKED_OUT, ABANDONED)`; CHECK số đếm không âm.
- **`uq_carts_active_buyer`**: mỗi buyer tối đa **1 giỏ ACTIVE** (partial unique, bỏ qua giỏ đã soft delete). Code xử lý: insert → bắt `DuplicateKey` → SELECT lại (CART-01/02).
- `idx_carts_abandon`: phục vụ job chuyển giỏ lâu không hoạt động sang ABANDONED (CART-09).
- Comment làm rõ: `item_count` = số **dòng** (không phải tổng quantity); `subtotal_amount` tính theo `unit_price_snapshot`.

**`cart_items`**
- UNIQUE `(cart_id, sku_id)`: một SKU chỉ xuất hiện một dòng trong giỏ → thêm lần nữa thì **cộng dồn quantity** (không tạo dòng mới). Unique này cũng phủ luôn index theo `cart_id`.
- CHECK `quantity > 0`, `unit_price_snapshot >= 0`.
- `idx_cart_items_product`: xoá item khi nhận event `ProductDeleted` (CART-11).

**`checkout_groups`**
- Thêm `payment_attempt_count` (giới hạn `PAYMENT_RETRY_LIMIT = 3`, CHK-03).
- CHECK `status IN (PENDING_PAYMENT, PAYMENT_PROCESSING, PAID, CANCELLED, EXPIRED)`.
- **`uq_checkout_groups_open_cart`**: mỗi cart chỉ có **1 checkout đang mở** (`PENDING_PAYMENT` hoặc `PAYMENT_PROCESSING`) → chặn checkout song song (Design Decision #4).
- `idx_checkout_groups_buyer (buyer_id, created_at DESC)`: lịch sử checkout (CHK-04).
- `idx_checkout_groups_expire`: job hết hạn thanh toán (CHK-06).

### 4.3 `orders` và `order_items`

- **Thêm trạng thái `CONFIRMED`** vào status (v1 không có): `PENDING_PAYMENT → PAID → CONFIRMED → SHIPPING → DELIVERED → COMPLETED`, nhánh `CANCELLED` / `REFUNDED`. `CONFIRMED` = seller đã chấp nhận đơn (tương ứng cột `seller_accepted_at`).
- CHECK `payment_method IN (WALLET, VNPAY, COD)` (COD chưa hỗ trợ ở MVP — ghi trong comment).
- CHECK các số tiền ≥ 0 (**riêng `platform_fee_amount` được phép âm** vì = markup − system voucher).
- **Invariant tiền (quan trọng):**

  ```
  total_amount = seller_receive_amount + platform_fee_amount + shipping_fee_amount
  ```
  DB sẽ từ chối bất kỳ đơn nào có tổng tiền không khớp công thức (`ck_orders_amount_invariant`). Service tính tiền sai sẽ lỗi ngay khi insert/update thay vì lệch tiền âm thầm.
- Index theo luồng:

  | Index | Dùng cho |
  |---|---|
  | `idx_orders_checkout_group` | Join orders ↔ checkout group |
  | `idx_orders_buyer_created`, `idx_orders_buyer_status` | ORD-01 buyer xem/lọc đơn |
  | `idx_orders_seller_status_created` (partial `paid_at IS NOT NULL`) | ORD-03 seller **chỉ thấy đơn đã trả tiền** |
  | `idx_orders_seller_respond` (partial `status='PAID'`) | ORD-09 job seller quá hạn phản hồi |
  | `idx_orders_auto_complete` (partial `status='DELIVERED'`) | ORD-08 job tự hoàn tất đơn đã giao |
  | `idx_orders_seller_created` | ORD-11 admin tìm theo seller/ngày |

- `order_items`: CHECK `quantity > 0`, các giá ≥ 0; index `order_id`.

### 4.4 `auction_orders`

- **Thêm 2 cột snapshot:** `image_url_snapshot`, `sku_attributes_snapshot` (cho khớp `order_items`; lấy từ Catalog lúc tạo đơn).
- CHECK status (thêm `CONFIRMED`), `payment_method`.
- CHECK `winning_amount > 0`, `seller_receive_amount >= 0`, `shipping_fee_amount` NULL hoặc ≥ 0.
- **CHECK `ck_auction_orders_total`**: `shipping_fee_amount` và `total_amount` **cùng NULL** (chưa báo giá GHN) hoặc cùng có giá trị và `total = winning_amount + shipping_fee`.
- 6 index tương ứng các API/job của orders, thêm `idx_auction_orders_payment_deadline` (partial `PENDING_PAYMENT`) cho job quá hạn thanh toán (đơn đấu giá có hạn `settled_at + 24h`, khác checkout 15 phút).

### 4.5 Bảng dùng chung `order_*` (history, cancellations, invoices)

Cả 3 bảng đều tham chiếu **hoặc** `orders` **hoặc** `auction_orders` (polymorphic bằng 2 cột FK nullable).

- v1: không có gì ngăn cả hai cùng NULL hoặc cùng có giá trị.
- v2: `CHECK (num_nonnulls(order_id, auction_order_id) = 1)` → **XOR**.
- `order_status_history`: CHECK `actor_role IN (BUYER, SELLER, ADMIN, SUPPORT_STAFF, SYSTEM)`; 2 partial index `(order_id, created_at)` và `(auction_order_id, created_at)` phục vụ `statusHistory` của ORD-02.
- `order_cancellations`: CHECK `actor_role`; unique partial theo `order_id` / `auction_order_id` → **mỗi đơn chỉ huỷ 1 lần**. Cột `refund_transaction_id` giữ lại nhưng đánh dấu **DEPRECATED**, dùng `order_refunds.refund_transaction_id`.
- `order_invoices`: CHECK `status IN (GENERATED, FAILED)`; unique partial → **mỗi đơn một hoá đơn**.

### 4.6 Discount (3 bảng)

**`discount_codes`**
- `uq_discount_codes_code` = unique trên `lower(code)` (không phân biệt hoa thường), chỉ trong code chưa xoá. *(v1 có comment "Unique partial index" nhưng thực tế **chưa tạo index** — v2 sửa lỗi này.)*
- Các CHECK:
  - `scope_type IN (SYSTEM, SHOP, PRODUCT)`
  - `ck_discount_codes_owner`: `(scope_type = 'SYSTEM') = (owner_seller_id IS NULL)` → SYSTEM thì không có owner; SHOP/PRODUCT **bắt buộc** có owner seller.
  - `discount_type IN (PERCENT, FIXED)`; `discount_value > 0`, và nếu PERCENT thì ≤ 100.
  - `max_discount_amount` NULL hoặc > 0; `min_order_amount >= 0`.
  - `status IN (DRAFT, ACTIVE, INACTIVE, EXPIRED)`.
  - `used_count >= 0`, `reserved_count >= 0`, và `used_count + reserved_count <= max_uses_total` (nếu có) → **không thể vượt tổng lượt dùng** kể cả khi race condition.
  - `ends_at > starts_at`.
- `idx_discount_codes_available`: DSC-01 liệt kê voucher đang ACTIVE + hiển thị.

**`discount_code_scopes`**
- CHECK `scope_ref_type IN (SHOP, PRODUCT, SKU, CATEGORY, ALL)`.
- CHECK `(scope_ref_type = 'ALL') = (scope_ref_id IS NULL)` → ALL thì không có ref, loại khác bắt buộc có ref.
- Unique `(discount_code_id, scope_ref_type, COALESCE(scope_ref_id, zero-uuid))` → chống trùng scope (dùng `COALESCE` vì NULL không bằng NULL trong unique).
- `idx_discount_code_scopes_ref`: tra ngược "voucher nào áp dụng cho product/shop này".

**`discount_code_usages`**
- CHECK `status IN (RESERVED, USED, RELEASED)`; `discount_amount >= 0`.
- CHECK `order_id IS NOT NULL OR checkout_group_id IS NOT NULL` (lúc reserve có thể mới chỉ có checkout group).
- Index `(discount_code_id, user_id, status)` cho DSC-03 (đếm lượt dùng theo user); 2 partial index theo `order_id`, `checkout_group_id`.

### 4.7 Hạ tầng (config, sequence, saga, outbox/inbox, idempotency)

| Bảng | Thay đổi |
|---|---|
| `system_settings` | CHECK `value_type`, `category`; **seed 7 setting** (mục 6) |
| `daily_order_sequences` | CHECK `seq_type IN (ORDER_NO, AUCTION_ORDER_NO, INVOICE_NO)`, `last_value >= 0` |
| `saga_state` | CHECK `saga_type IN (CheckoutSaga, OrderCancellationSaga)`; COMMENT liệt kê state: *CheckoutSaga:* `INVENTORY_RESERVING, AWAITING_PAYMENT, PAYMENT_PENDING, COMPLETED, COMPENSATED`; *OrderCancellationSaga:* `CANCELLING, REFUND_PENDING, COMPLETED, FAILED`. Terminal: `COMPLETED, COMPENSATED, FAILED`. Index `idx_saga_state_stuck` quét saga treo (ORD-21) |
| `outbox_messages` | CHECK `status IN (PENDING, PUBLISHED, FAILED, DEAD)`; `idx_outbox_pending` (publisher ORD-20), `idx_outbox_cleanup` (dọn message đã publish) |
| `inbox_messages` | CHECK `status IN (RECEIVED, PROCESSED, FAILED, SKIPPED)`; `idx_inbox_retry` |
| `idempotency_keys` | `idx_idempotency_expires` cho job dọn key hết hạn (ORD-19) |

---

## 5. Các quy tắc nghiệp vụ được DB enforce (invariants)

Đây là danh sách để BE lead biết "DB sẽ từ chối gì", tránh bất ngờ khi code:

| # | Quy tắc | Cơ chế |
|---|---|---|
| 1 | Mỗi buyer tối đa 1 cart ACTIVE | Unique partial `uq_carts_active_buyer` |
| 2 | Một SKU một dòng trong cart | Unique `(cart_id, sku_id)` |
| 3 | Mỗi cart chỉ 1 checkout đang mở | Unique partial `uq_checkout_groups_open_cart` |
| 4 | `orders.total = seller_receive + platform_fee + shipping_fee` | CHECK `ck_orders_amount_invariant` |
| 5 | Auction: shipping_fee và total cùng NULL hoặc `total = winning + shipping` | CHECK `ck_auction_orders_total` |
| 6 | Mỗi record lịch sử/huỷ/refund/hoá đơn gắn đúng 1 loại đơn | CHECK `num_nonnulls(...) = 1` |
| 7 | Mỗi đơn huỷ tối đa 1 lần, có tối đa 1 hoá đơn | Unique partial |
| 8 | Mỗi đơn/group chỉ 1 refund REQUESTED/COMPLETED | Unique partial `uq_order_refunds_*_active` |
| 9 | Refund COMPLETED phải có `completed_at` + `refund_transaction_id` | CHECK `ck_order_refunds_done` |
| 10 | Mã voucher không trùng (không phân biệt hoa thường) | Unique `lower(code)` |
| 11 | Voucher SYSTEM không có owner; SHOP/PRODUCT phải có | CHECK `ck_discount_codes_owner` |
| 12 | `used + reserved <= max_uses_total` | CHECK `ck_discount_codes_counts` |
| 13 | Trạng thái chỉ nhận giá trị trong danh sách | CHECK `status` ở mọi bảng |

---

## 6. Seed data `system_settings`

Insert idempotent (`ON CONFLICT (setting_key) DO NOTHING`), chạy lại không lỗi.

| Key | Value | Category | Ý nghĩa |
|---|---|---|---|
| `CART_EXPIRATION_DAYS` | 7 | TIMING | Ngày không hoạt động trước khi cart thành ABANDONED (CART-09) |
| `CHECKOUT_TIMEOUT_MINUTES` | 15 | TIMING | Hạn thanh toán sau khi tạo checkout (CHK-02) |
| `SELLER_RESPOND_HOURS` | 24 | TIMING | Hạn seller phản hồi đơn đã thanh toán (ORD-09) |
| `ORDER_AUTO_COMPLETE_DAYS` | 7 | TIMING | Số ngày tự hoàn tất đơn đã giao (ORD-08). **Đề xuất, cần BA chốt** |
| `PAYMENT_RETRY_LIMIT` | 3 | SYSTEM | Số lần thử thanh toán tối đa/checkout group (CHK-03) |
| `MAX_QTY_PER_ITEM` | 99 | SYSTEM | Quantity tối đa mỗi dòng cart (CART-02/03) |
| `MAX_CART_ITEMS` | 50 | SYSTEM | Số dòng tối đa trong cart (CART-02) |

**Chưa seed** (chờ BA chốt tỷ lệ): `PLATFORM_MARKUP_PERCENT`, `AUCTION_PLATFORM_FEE_PERCENT`.

---

## 7. Phân tích quyết định thiết kế (ưu / nhược) và điểm cần lưu ý

### 7.1 Polymorphic reference: 2 cột FK nullable + CHECK XOR (đang dùng)

Cách này dùng cho `order_status_history`, `order_cancellations`, `order_invoices`, `order_refunds`.

| | Ưu điểm | Nhược điểm |
|---|---|---|
| **A. 2 cột FK nullable + CHECK XOR (v2)** | Có FK thật, toàn vẹn dữ liệu; một bảng dùng chung nên query/report đơn giản | Mỗi bảng cần 2 unique partial index; thêm loại đơn mới phải thêm cột |
| B. Một cột `order_id` không FK + `order_type` | Gọn, dễ mở rộng | Mất FK, rủi ro dữ liệu mồ côi |
| C. Gộp `orders` và `auction_orders` thành một bảng | Bỏ polymorphic hoàn toàn | Refactor lớn; hai loại đơn có cột/luồng khác nhau (auction không có items, total NULL đến khi báo giá) |

→ v2 chọn **A**: hợp lý với quy mô MVP; đổi lại code phải luôn set đúng 1 trong 2 cột.

### 7.2 CHECK constraint ở DB vs chỉ validate trong code

| | Ưu điểm | Nhược điểm |
|---|---|---|
| **CHECK trong DB (v2)** | Bảo vệ cả khi có bug, script, hoặc service khác ghi vào DB; tránh lệch tiền | Đổi danh sách status phải migration; lỗi DB cần map sang lỗi nghiệp vụ trong code |
| Chỉ validate trong code (v1) | Linh hoạt, dễ đổi | Không có "lưới an toàn"; dữ liệu sai lọt vào rất khó phát hiện |

Gợi ý: nếu status là Java `enum` / C# `enum`, giữ danh sách status ở **một nơi** và đồng bộ với CHECK.

### 7.3 Status dạng `text` + CHECK vs PostgreSQL `ENUM`

| | `text` + CHECK (v2) | `ENUM` type |
|---|---|---|
| Thêm giá trị mới | Sửa CHECK (drop/add constraint) | `ALTER TYPE ... ADD VALUE` (không rollback được trong transaction ở một số phiên bản) |
| Tương thích ORM (Spring Data JPA/EF Core) | Đơn giản, map thẳng string | Cần cấu hình riêng |
→ `text` + CHECK dễ vận hành hơn.

### 7.4 ⚠️ Điểm cần lưu ý / câu hỏi mở cho Lead

1. **"Hoàn một phần" vs unique index refund.** Comment nói hỗ trợ partial refund, nhưng `uq_order_refunds_order_active` chỉ cho **1 refund REQUESTED/COMPLETED trên mỗi `order_id`**. Nghĩa là: một order chỉ hoàn một phần **một lần** (ví dụ hoàn nhiều đợt cho cùng order sẽ bị chặn). Phần "partial" hiện được hiểu là *"hoàn 1 order trong group"*, không phải *"hoàn nhiều đợt từng phần của 1 order"*. Nếu nghiệp vụ cần nhiều đợt, phải đổi unique key (ví dụ thêm `request_event_id` hoặc bỏ unique rồi kiểm tra tổng `amount ≤ total_amount` bằng code/trigger). Cần xác nhận với BA.
2. **Double refund giữa các cấp.** Refund theo `checkout_group_id` và refund theo `order_id` là hai unique index độc lập; DB **không** ngăn việc vừa refund cả group vừa refund từng order. Service phải kiểm tra.
3. **Không có kiểm tra tổng refund ≤ số tiền đã trả.** `amount > 0` nhưng không so với `orders.total_amount` — cần validate trong code.
4. **Chuyển trạng thái (state machine) không được DB enforce.** CHECK chỉ giới hạn tập giá trị, không giới hạn thứ tự (ví dụ `PENDING_PAYMENT → COMPLETED` vẫn hợp lệ với DB). Cần state machine ở tầng service, kết hợp `row_version`.
5. **Auction không có invariant như `orders`.** `auction_orders` chỉ check `total = winning + shipping`; quan hệ `seller_receive + platform_fee = winning_amount` **chưa được enforce**. Có thể cân nhắc thêm CHECK tương tự nếu BA chốt công thức.
6. **`ck_order_refunds_done` chỉ bắt `COMPLETED`.** `FAILED` chưa bắt buộc có `failed_at`/`failure_code`.
7. **Cột trùng ý nghĩa:** `order_cancellations.refund_transaction_id` còn tồn tại nhưng DEPRECATED. Code mới **chỉ dùng** `order_refunds`; có kế hoạch xoá cột ở version sau.
8. **`updated_at` trên bảng append-only** (`order_status_history`): không gây lỗi nhưng thừa. Nếu muốn gọn có thể bỏ ở v3.
9. **Trigger `updated_at`**: schema chỉ có `DEFAULT now()`, nên `updated_at` cần được cập nhật bởi ORM/code (hoặc thêm trigger). Hiện chưa có trigger nào.
10. **`ORDER_AUTO_COMPLETE_DAYS = 7`** là giá trị đề xuất, chưa được BA xác nhận; hai tỷ lệ phí nền tảng chưa có.

---

## 8. Bản đồ Index → API / Job

| Mã | Mô tả | Index liên quan |
|---|---|---|
| CART-01/02 | Lấy/tạo giỏ | `uq_carts_active_buyer` |
| CART-09 | Job hết hạn giỏ | `idx_carts_abandon` |
| CART-11 | Xoá item khi `ProductDeleted` | `idx_cart_items_product` |
| CHK-04 | Lịch sử checkout | `idx_checkout_groups_buyer` |
| CHK-06 | Job hết hạn thanh toán | `idx_checkout_groups_expire` |
| ORD-01 | Buyer xem đơn | `idx_orders_buyer_created`, `idx_orders_buyer_status` (+ auction tương ứng) |
| ORD-02 | Chi tiết + lịch sử | `idx_order_status_history_*` |
| ORD-03 | Seller xem đơn (đã trả tiền) | `idx_orders_seller_status_created` (+ auction) |
| ORD-08 | Job tự hoàn tất | `idx_orders_auto_complete`, `idx_auction_orders_auto_complete` |
| ORD-09 | Job seller quá hạn phản hồi | `idx_orders_seller_respond`, `idx_auction_orders_seller_respond` |
| ORD-11 | Admin tìm kiếm | `idx_orders_seller_created` |
| ORD-13 | Refund thủ công, chặn trùng | `uq_order_refunds_*_active` |
| ORD-14 | Nhận kết quả refund (idempotent) | `uq_order_refunds_txn` |
| ORD-19 | Dọn idempotency key | `idx_idempotency_expires` |
| ORD-20 | Outbox publisher | `idx_outbox_pending`, `idx_outbox_cleanup` |
| ORD-21 | Quét saga treo | `idx_saga_state_stuck` |
| DSC-01 | Liệt kê voucher | `idx_discount_codes_available` |
| DSC-03 | Đếm lượt dùng theo user | `idx_discount_code_usages_user` |
| AO-04 | Đơn đấu giá | các `idx_auction_orders_*` |

---

## 9. Migration checklist (nếu đã có dữ liệu v1)

Tạo mới schema thì bỏ qua mục này. Nếu đã có dữ liệu, kiểm tra **trước khi** thêm constraint, vì `ALTER TABLE ... ADD CONSTRAINT` sẽ fail khi dữ liệu cũ vi phạm:

1. **Cart:** nhiều giỏ ACTIVE/buyer? Trùng `(cart_id, sku_id)`? `quantity <= 0`?
2. **Checkout:** nhiều checkout mở trên cùng cart?
3. **Orders:** đơn có `total_amount ≠ seller_receive + platform_fee + shipping_fee`; status ngoài danh sách; số tiền âm.
4. **Auction orders:** `shipping_fee`/`total` chỉ một trong hai NULL; `total ≠ winning + shipping`.
5. **history / cancellations / invoices:** dòng có cả hai hoặc không có cột order; đơn bị huỷ nhiều lần; đơn có nhiều hoá đơn.
6. **Discount:** code trùng khác hoa thường; SHOP/PRODUCT thiếu owner; `used + reserved > max_uses_total`; scope ALL có ref.
7. Chuyển dữ liệu `order_cancellations.refund_transaction_id` cũ sang `order_refunds` (nếu cần giữ lịch sử).
8. Với bảng lớn: tạo index bằng `CREATE INDEX CONCURRENTLY`, thêm CHECK bằng `NOT VALID` rồi `VALIDATE CONSTRAINT` để tránh khoá bảng lâu.

---

## 10. Glossary (English support)

| Tiếng Anh | Giải thích ngắn |
|---|---|
| **Constraint** | Ràng buộc dữ liệu do DB enforce (PK, FK, UNIQUE, CHECK) |
| **CHECK constraint** | Điều kiện logic mỗi dòng phải thoả |
| **Partial index** | Index chỉ áp dụng cho các dòng thoả điều kiện `WHERE` |
| **Unique partial index** | Unique chỉ trong tập dòng thoả `WHERE` (vd. chỉ cart ACTIVE) |
| **Invariant** | Quy tắc luôn phải đúng (vd. công thức tổng tiền) |
| **Snapshot** | Bản sao dữ liệu tại thời điểm tạo, không đổi theo nguồn gốc |
| **Cross-service reference** | Tham chiếu ID sang service khác, không có FK |
| **Optimistic locking (`row_version`)** | Chống ghi đè đồng thời bằng số phiên bản |
| **Soft delete (`deleted_at`)** | Xoá logic, không xoá vật lý |
| **Saga** | Chuỗi giao dịch phân tán có bước bù trừ (compensation) |
| **Outbox pattern** | Ghi event vào DB cùng transaction, job riêng publish ra message broker |
| **Inbox pattern** | Lưu message đã nhận để xử lý idempotent |
| **Idempotency** | Gọi lặp lại nhiều lần cho cùng kết quả |
| **XOR reference** | Đúng một trong hai cột tham chiếu có giá trị |
| **Compensation** | Hành động hoàn tác một bước saga đã chạy |
| **Reserve → Use → Release** | Vòng đời lượt dùng voucher |

---

## 11. Tổng hợp ENUM trong DB Commerce v2

DB **không dùng PostgreSQL `ENUM` type**. Mọi "enum" là cột `text` + `CHECK (... IN (...))` (xem so sánh ở mục 7.3). Vì vậy danh sách giá trị dưới đây phải được **đồng bộ** với `enum` trong code (Java `enum` / C# `enum`).

### 11.1 Enum dùng chung nhiều bảng

| Enum | Giá trị | Dùng ở (bảng.cột) |
|---|---|---|
| **OrderStatus** | `PENDING_PAYMENT`, `PAID`, `CONFIRMED`, `SHIPPING`, `DELIVERED`, `COMPLETED`, `CANCELLED`, `REFUNDED` | `orders.status`, `auction_orders.status` |
| **PaymentMethod** | `WALLET`, `VNPAY`, `COD` *(COD chưa hỗ trợ ở MVP)* | `orders.payment_method`, `auction_orders.payment_method` |
| **ActorRole** | `BUYER`, `SELLER`, `ADMIN`, `SUPPORT_STAFF`, `SYSTEM` | `order_status_history.actor_role`, `order_cancellations.actor_role`, `order_refunds.actor_role` |

### 11.2 Enum theo từng module

**Cart & Checkout**

| Enum | Giá trị | Cột |
|---|---|---|
| **CartStatus** | `ACTIVE`, `CHECKED_OUT`, `ABANDONED` | `carts.status` |
| **CheckoutGroupStatus** | `PENDING_PAYMENT`, `PAYMENT_PROCESSING`, `PAID`, `CANCELLED`, `EXPIRED` | `checkout_groups.status` |

**Order lifecycle**

| Enum | Giá trị | Cột |
|---|---|---|
| **RefundStatus** | `REQUESTED`, `COMPLETED`, `FAILED` | `order_refunds.status` |
| **RefundType** | `FULL`, `PARTIAL` | `order_refunds.refund_type` |
| **InvoiceStatus** | `GENERATED`, `FAILED` | `order_invoices.status` |

**Discount**

| Enum | Giá trị | Cột |
|---|---|---|
| **DiscountScopeType** | `SYSTEM`, `SHOP`, `PRODUCT` | `discount_codes.scope_type` |
| **DiscountType** | `PERCENT`, `FIXED` | `discount_codes.discount_type` |
| **DiscountStatus** | `DRAFT`, `ACTIVE`, `INACTIVE`, `EXPIRED` | `discount_codes.status` |
| **DiscountScopeRefType** | `SHOP`, `PRODUCT`, `SKU`, `CATEGORY`, `ALL` | `discount_code_scopes.scope_ref_type` |
| **DiscountUsageStatus** | `RESERVED`, `USED`, `RELEASED` | `discount_code_usages.status` |

**Hạ tầng / config**

| Enum | Giá trị | Cột |
|---|---|---|
| **SettingValueType** | `STRING`, `INTEGER`, `DECIMAL`, `BOOLEAN`, `JSON` | `system_settings.value_type` |
| **SettingCategory** | `REPUTATION`, `MONEY`, `AUCTION`, `TIMING`, `SYSTEM` | `system_settings.category` |
| **SequenceType** | `ORDER_NO`, `AUCTION_ORDER_NO`, `INVOICE_NO` | `daily_order_sequences.seq_type` |
| **SagaType** | `CheckoutSaga`, `OrderCancellationSaga` | `saga_state.saga_type` |
| **OutboxStatus** | `PENDING`, `PUBLISHED`, `FAILED`, `DEAD` | `outbox_messages.status` |
| **InboxStatus** | `RECEIVED`, `PROCESSED`, `FAILED`, `SKIPPED` | `inbox_messages.status` |

### 11.3 Giá trị "enum" chỉ có trong COMMENT (DB không có CHECK)

| Cột | Giá trị (theo comment) | Ghi chú |
|---|---|---|
| `saga_state.current_state` | **CheckoutSaga:** `INVENTORY_RESERVING`, `AWAITING_PAYMENT`, `PAYMENT_PENDING`, `COMPLETED`, `COMPENSATED`. **OrderCancellationSaga:** `CANCELLING`, `REFUND_PENDING`, `COMPLETED`, `FAILED` | Terminal state: `COMPLETED`, `COMPENSATED`, `FAILED`. Index `idx_saga_state_stuck` **phụ thuộc** vào 3 giá trị này |
| `order_status_history.from_status` / `to_status` | Cùng tập với **OrderStatus** | **Không có CHECK** ở DB. Nên validate trong code, hoặc cân nhắc thêm CHECK ở v3 |

### 11.4 Cột free-text (chưa có enum ở DB, nhưng nên chuẩn hoá trong code)

| Cột | Ghi chú |
|---|---|
| `order_cancellations.reason_code`, `order_refunds.reason_code` | Mã lý do huỷ/hoàn; chưa chốt danh sách trong DB. Nên có chung một enum trong code (vd. `BUYER_CHANGED_MIND`, `SELLER_TIMEOUT`...) và thống nhất với BA |
| `order_refunds.failure_code` | Mã lỗi do Payment Service trả về |
| `outbox_messages.event_type`, `inbox_messages.event_type`, `aggregate_type` | Tên event/aggregate, nên là hằng số dùng chung trong code |
| `inbox_messages.consumer`, `idempotency_keys.scope` | Tên consumer / phạm vi idempotency |

### 11.5 Luồng trạng thái (state flow) tham khảo

**Order (`orders` / `auction_orders`):**

```
PENDING_PAYMENT ──► PAID ──► CONFIRMED ──► SHIPPING ──► DELIVERED ──► COMPLETED
       │              │          │
       └──► CANCELLED ◄──────────┘            (CANCELLED có thể kèm refund ──► REFUNDED)
```

- `PAID → CONFIRMED`: seller chấp nhận đơn (`seller_accepted_at`), hạn phản hồi `SELLER_RESPOND_HOURS = 24`.
- `DELIVERED → COMPLETED`: tự động sau `ORDER_AUTO_COMPLETE_DAYS` (ORD-08).
- Đây là luồng **gợi ý** suy ra từ các cột thời gian (`paid_at`, `seller_accepted_at`, `shipped_at`, `delivered_at`, `completed_at`, `cancelled_at`). DB **không** enforce thứ tự chuyển (xem mục 7.4, điểm 4); hãy chốt transition hợp lệ với BA.

**Checkout group:** `PENDING_PAYMENT ⇄ PAYMENT_PROCESSING → PAID`; nhánh kết thúc `CANCELLED` hoặc `EXPIRED` (quá `CHECKOUT_TIMEOUT_MINUTES = 15`).

**Refund:** `REQUESTED → COMPLETED` hoặc `REQUESTED → FAILED` (`FAILED` được phép tạo refund mới).

**Discount usage:** `RESERVED → USED` (thanh toán thành công) hoặc `RESERVED → RELEASED` (huỷ/hết hạn).

### 11.6 Gợi ý cách đồng bộ enum giữa code và DB

| Cách | Ưu điểm | Nhược điểm |
|---|---|---|
| **A. Enum trong code + CHECK ở DB (hiện tại)** | Dễ migrate, ORM map thẳng string, DB vẫn chặn giá trị sai | Phải sửa 2 nơi khi thêm giá trị (code + migration CHECK) |
| B. Bảng lookup (`order_statuses`) + FK | Thêm giá trị bằng INSERT, có thể gắn metadata (nhãn, thứ tự) | Thêm bảng và JOIN, nhiều FK hơn |
| C. PostgreSQL `ENUM` type | Gọn, tiết kiệm lưu trữ | Khó đổi/xoá giá trị, cấu hình ORM phức tạp hơn |

→ Giữ **A**. Ví dụ map trong Java (Spring Boot / JPA):

```java
public enum OrderStatus {
    PENDING_PAYMENT, PAID, CONFIRMED, SHIPPING,
    DELIVERED, COMPLETED, CANCELLED, REFUNDED
}

@Enumerated(EnumType.STRING)   // bắt buộc STRING, không dùng ORDINAL
@Column(nullable = false)
private OrderStatus status;
```

Tương đương C# (EF Core): `builder.Property(o => o.Status).HasConversion<string>();`

> *English support:* In this schema an "enum" is a `text` column guarded by a `CHECK ... IN (...)` constraint, not a native PostgreSQL `ENUM`. Always map enums as **strings** in the ORM (`EnumType.STRING` in JPA, `HasConversion<string>()` in EF Core), never as ordinals, so that the code stays aligned with the CHECK constraints.

---

# PHẦN 2 – CODE DBDIAGRAM.IO (DBML)

Cách dùng: vào https://dbdiagram.io → New Diagram → dán toàn bộ code bên dưới.

Lưu ý: DBML **không biểu diễn được** `CHECK` và điều kiện `WHERE` của partial index, nên các ràng buộc này được ghi trong `note` của cột/index. Thứ tự `DESC` của index cũng ghi trong `note`. Đây là diagram v2.

```dbml
Project commerce_v2 {
  database_type: 'PostgreSQL'
  Note: 'Commerce Service DB v2. CHECK constraint va dieu kien WHERE cua partial index duoc ghi trong note.'
}

// =====================================================================
// CART & CHECKOUT
// =====================================================================
Table carts {
  id uuid [pk, default: `gen_random_uuid()`]
  buyer_id uuid [not null, note: 'Cross-service ref: user.users.id']
  status text [not null, default: 'ACTIVE', note: 'CHECK: ACTIVE | CHECKED_OUT | ABANDONED']
  item_count integer [not null, default: 0, note: 'So dong cart_items (khong phai tong quantity). CHECK >= 0']
  subtotal_amount numeric(18,2) [not null, default: 0, note: 'Tam tinh theo unit_price_snapshot. CHECK >= 0']
  last_activity_at timestamptz [not null, default: `now()`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  deleted_at timestamptz
  row_version bigint [not null, default: 0, note: 'Optimistic lock (CART-02/03). NEW in v2']

  indexes {
    buyer_id [unique, name: 'uq_carts_active_buyer', note: 'PARTIAL WHERE status = ACTIVE AND deleted_at IS NULL. Toi da 1 gio ACTIVE moi buyer (CART-01/02)']
    last_activity_at [name: 'idx_carts_abandon', note: 'PARTIAL WHERE status = ACTIVE AND deleted_at IS NULL. Job het han gio (CART-09)']
  }

  Note: 'Gio hang cua buyer'
}

Table cart_items {
  id uuid [pk, default: `gen_random_uuid()`]
  cart_id uuid [not null]
  product_id uuid [not null, note: 'Cross-service ref: catalog.products.id']
  sku_id uuid [not null, note: 'Cross-service ref: catalog.product_variants.id']
  seller_id uuid [not null, note: 'Cross-service ref: user.users.id']
  quantity integer [not null, note: 'CHECK > 0']
  unit_price_snapshot numeric(18,2) [not null, note: 'CHECK >= 0']
  product_name_snapshot text [not null]
  added_at timestamptz [not null, default: `now()`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    (cart_id, sku_id) [unique, name: 'uq_cart_items_cart_sku', note: 'Mot SKU mot dong trong gio']
    product_id [name: 'idx_cart_items_product', note: 'CART-11: xoa item khi ProductDeleted']
  }
}

Table checkout_groups {
  id uuid [pk, default: `gen_random_uuid()`]
  cart_id uuid
  buyer_id uuid [not null, note: 'Cross-service ref: user.users.id']
  status text [not null, default: 'PENDING_PAYMENT', note: 'CHECK: PENDING_PAYMENT | PAYMENT_PROCESSING | PAID | CANCELLED | EXPIRED']
  total_amount numeric(18,2) [not null, note: 'CHECK >= 0']
  wallet_transaction_id uuid [note: 'Cross-service ref: wallet.wallet_transactions.id']
  payment_attempt_count integer [not null, default: 0, note: 'NEW in v2. So lan thu thanh toan, toi da PAYMENT_RETRY_LIMIT = 3. CHECK >= 0']
  payment_deadline_at timestamptz [not null]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  row_version bigint [not null, default: 0]

  indexes {
    cart_id [unique, name: 'uq_checkout_groups_open_cart', note: 'PARTIAL WHERE cart_id IS NOT NULL AND status IN (PENDING_PAYMENT, PAYMENT_PROCESSING). Chan checkout song song tren cung gio']
    (buyer_id, created_at) [name: 'idx_checkout_groups_buyer', note: 'created_at DESC. CHK-04']
    payment_deadline_at [name: 'idx_checkout_groups_expire', note: 'PARTIAL WHERE status = PENDING_PAYMENT. CHK-06 job het han']
  }
}

// =====================================================================
// ORDERS (thuong)
// =====================================================================
Table orders {
  id uuid [pk, default: `gen_random_uuid()`]
  order_no text [unique, not null, note: 'ORD-YYYYMMDD-NNNNNN']
  buyer_id uuid [not null, note: 'Cross-service ref: user.users.id']
  seller_id uuid [not null, note: 'Cross-service ref: user.users.id']
  checkout_group_id uuid [not null]
  status text [not null, default: 'PENDING_PAYMENT', note: 'CHECK: PENDING_PAYMENT | PAID | CONFIRMED | SHIPPING | DELIVERED | COMPLETED | CANCELLED | REFUNDED. CONFIRMED la moi o v2']
  payment_method text [not null, default: 'WALLET', note: 'CHECK: WALLET | VNPAY | COD (COD chua ho tro o MVP)']
  wallet_transaction_id uuid [note: 'Cross-service ref: wallet.wallet_transactions.id']
  shipping_address jsonb [not null, note: 'Snapshot address {receiverName, phone, street...}']
  contact_phone text [not null]
  items_amount numeric(18,2) [not null, default: 0]
  product_discount_amount numeric(18,2) [not null, default: 0]
  shop_discount_amount numeric(18,2) [not null, default: 0]
  platform_markup_amount numeric(18,2) [not null, default: 0, note: 'Platform percentage added after seller discounts']
  system_discount_amount numeric(18,2) [not null, default: 0]
  shipping_fee_amount numeric(18,2) [not null, default: 0]
  total_amount numeric(18,2) [not null, default: 0, note: 'Amount buyer pays. INVARIANT: total = seller_receive + platform_fee + shipping_fee']
  seller_receive_amount numeric(18,2) [not null, default: 0, note: 'Amount seller gets']
  platform_fee_amount numeric(18,2) [not null, default: 0, note: 'Markup minus system voucher; may be negative (khong bi CHECK >= 0)']
  payment_deadline_at timestamptz [not null]
  seller_respond_deadline_at timestamptz [note: 'paid_at + 24h']
  paid_at timestamptz
  seller_accepted_at timestamptz
  shipped_at timestamptz
  delivered_at timestamptz
  completed_at timestamptz
  cancelled_at timestamptz
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  deleted_at timestamptz
  row_version bigint [not null, default: 0]

  indexes {
    checkout_group_id [name: 'idx_orders_checkout_group']
    (buyer_id, created_at) [name: 'idx_orders_buyer_created', note: 'created_at DESC. PARTIAL WHERE deleted_at IS NULL. ORD-01']
    (buyer_id, status) [name: 'idx_orders_buyer_status', note: 'PARTIAL WHERE deleted_at IS NULL']
    (seller_id, status, created_at) [name: 'idx_orders_seller_status_created', note: 'created_at DESC. PARTIAL WHERE paid_at IS NOT NULL AND deleted_at IS NULL. ORD-03 seller chi thay don da tra tien']
    seller_respond_deadline_at [name: 'idx_orders_seller_respond', note: 'PARTIAL WHERE status = PAID. ORD-09']
    delivered_at [name: 'idx_orders_auto_complete', note: 'PARTIAL WHERE status = DELIVERED. ORD-08']
    (seller_id, created_at) [name: 'idx_orders_seller_created', note: 'created_at DESC. PARTIAL WHERE deleted_at IS NULL. ORD-11 admin']
  }
}

Table order_items {
  id uuid [pk, default: `gen_random_uuid()`]
  order_id uuid [not null]
  product_id uuid [not null, note: 'Cross-service ref: catalog.products.id']
  sku_id uuid [not null, note: 'Cross-service ref: catalog.product_variants.id']
  seller_id uuid [not null, note: 'Cross-service ref: user.users.id']
  product_name_snapshot text [not null]
  sku_code_snapshot text
  sku_attributes_snapshot jsonb [not null, default: '{}']
  image_url_snapshot text
  quantity integer [not null, note: 'CHECK > 0']
  unit_price numeric(18,2) [not null, note: 'CHECK >= 0']
  unit_price_after_discount numeric(18,2) [not null, note: 'CHECK >= 0']
  line_total numeric(18,2) [not null, note: 'CHECK >= 0']
  discount_code_id uuid [note: 'Direct product discount code (soft ref, khong co FK)']
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    order_id [name: 'idx_order_items_order']
  }
}

// =====================================================================
// AUCTION ORDERS
// =====================================================================
Table auction_orders {
  id uuid [pk, default: `gen_random_uuid()`]
  order_no text [unique, not null, note: 'AOR-YYYYMMDD-NNNNNN']
  auction_id uuid [unique, not null, note: 'Cross-service ref: auction.auctions.id']
  buyer_id uuid [not null, note: 'Cross-service ref: user.users.id (winner)']
  seller_id uuid [not null, note: 'Cross-service ref: user.users.id']
  winning_bid_id uuid [not null, note: 'Cross-service ref: auction.bids.id']
  product_id uuid [not null, note: 'Cross-service ref: catalog.products.id']
  sku_id uuid [note: 'Cross-service ref: catalog.product_variants.id']
  product_name_snapshot text [not null]
  image_url_snapshot text [note: 'NEW in v2. Snapshot anh san pham luc tao don']
  sku_attributes_snapshot jsonb [not null, default: '{}', note: 'NEW in v2. Snapshot thuoc tinh SKU luc tao don']
  winning_amount numeric(18,2) [not null, note: 'CHECK > 0']
  shipping_address jsonb
  contact_phone text
  shipping_fee_amount numeric(18,2) [note: 'Null until winner enters address and GHN quote. CHECK NULL hoac >= 0']
  total_amount numeric(18,2) [note: 'Null until quote; winning amount + shipping fee. CHECK: cung NULL voi shipping_fee hoac = winning + shipping_fee']
  seller_receive_amount numeric(18,2) [not null, note: 'CHECK >= 0']
  platform_fee_amount numeric(18,2) [not null]
  status text [not null, default: 'PENDING_PAYMENT', note: 'CHECK: PENDING_PAYMENT | PAID | CONFIRMED | SHIPPING | DELIVERED | COMPLETED | CANCELLED | REFUNDED']
  payment_method text [not null, default: 'WALLET', note: 'CHECK: WALLET | VNPAY | COD (COD chua ho tro o MVP)']
  wallet_transaction_id uuid [note: 'Cross-service ref: wallet.wallet_transactions.id']
  payment_deadline_at timestamptz [not null, note: 'settled_at + 24h']
  seller_respond_deadline_at timestamptz
  paid_at timestamptz
  seller_accepted_at timestamptz
  shipped_at timestamptz
  delivered_at timestamptz
  completed_at timestamptz
  cancelled_at timestamptz
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  deleted_at timestamptz
  row_version bigint [not null, default: 0]

  indexes {
    (buyer_id, created_at) [name: 'idx_auction_orders_buyer_created', note: 'created_at DESC. PARTIAL WHERE deleted_at IS NULL']
    (buyer_id, status) [name: 'idx_auction_orders_buyer_status', note: 'PARTIAL WHERE deleted_at IS NULL']
    (seller_id, status, created_at) [name: 'idx_auction_orders_seller_status_created', note: 'created_at DESC. PARTIAL WHERE paid_at IS NOT NULL AND deleted_at IS NULL']
    payment_deadline_at [name: 'idx_auction_orders_payment_deadline', note: 'PARTIAL WHERE status = PENDING_PAYMENT']
    seller_respond_deadline_at [name: 'idx_auction_orders_seller_respond', note: 'PARTIAL WHERE status = PAID']
    delivered_at [name: 'idx_auction_orders_auto_complete', note: 'PARTIAL WHERE status = DELIVERED']
  }
}

// =====================================================================
// ORDER LIFECYCLE (dung chung cho orders va auction_orders)
// Moi bang: CHECK dung 1 trong order_id / auction_order_id
// =====================================================================
Table order_status_history {
  id uuid [pk, default: `gen_random_uuid()`]
  order_id uuid [note: 'XOR voi auction_order_id']
  auction_order_id uuid [note: 'XOR voi order_id']
  from_status text
  to_status text [not null]
  changed_by uuid [note: 'Cross-service ref: user.users.id']
  actor_role text [not null, default: 'SYSTEM', note: 'CHECK: BUYER | SELLER | ADMIN | SUPPORT_STAFF | SYSTEM']
  reason text
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    (order_id, created_at) [name: 'idx_order_status_history_order', note: 'PARTIAL WHERE order_id IS NOT NULL. ORD-02']
    (auction_order_id, created_at) [name: 'idx_order_status_history_auction', note: 'PARTIAL WHERE auction_order_id IS NOT NULL']
  }

  Note: 'CHECK num_nonnulls(order_id, auction_order_id) = 1'
}

Table order_cancellations {
  id uuid [pk, default: `gen_random_uuid()`]
  order_id uuid [note: 'XOR voi auction_order_id']
  auction_order_id uuid [note: 'XOR voi order_id']
  cancelled_by uuid [note: 'Cross-service ref: user.users.id']
  actor_role text [not null, note: 'CHECK: BUYER | SELLER | ADMIN | SUPPORT_STAFF | SYSTEM']
  reason_code text [not null]
  reason_note text
  was_paid boolean [not null, default: false]
  refund_transaction_id uuid [note: 'DEPRECATED: dung order_refunds.refund_transaction_id. Giu lai de tuong thich']
  inventory_released boolean [not null, default: false]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    order_id [unique, name: 'uq_order_cancellations_order', note: 'PARTIAL WHERE order_id IS NOT NULL. Moi don chi huy 1 lan']
    auction_order_id [unique, name: 'uq_order_cancellations_auction', note: 'PARTIAL WHERE auction_order_id IS NOT NULL']
  }

  Note: 'CHECK num_nonnulls(order_id, auction_order_id) = 1'
}

// [NEW in v2]
Table order_refunds {
  id uuid [pk, default: `gen_random_uuid()`]
  order_id uuid [note: 'Refund cho 1 order thuong (hoan mot phan giao dich cua group)']
  auction_order_id uuid [note: 'Refund cho 1 don dau gia']
  checkout_group_id uuid [note: 'Refund toan bo giao dich cua group (tien ve muon / lech so tien o PAY-01)']
  cancellation_id uuid [note: 'Lien ket order_cancellations neu refund phat sinh do huy don; NULL neu refund thu cong (ORD-13)']
  refund_type text [not null, default: 'FULL', note: 'CHECK: FULL | PARTIAL']
  amount numeric(18,2) [not null, note: 'CHECK > 0']
  status text [not null, default: 'REQUESTED', note: 'CHECK: REQUESTED | COMPLETED | FAILED']
  reason_code text [not null]
  reason_note text
  actor_role text [not null, default: 'SYSTEM', note: 'CHECK: BUYER | SELLER | ADMIN | SUPPORT_STAFF | SYSTEM']
  requested_by uuid [note: 'Cross-service ref: user.users.id (NULL neu SYSTEM)']
  wallet_transaction_id uuid [note: 'Cross-service ref: giao dich thanh toan goc can hoan (originalWalletTransactionId)']
  refund_transaction_id uuid [note: 'Cross-service ref: wallet.wallet_transactions.id cua giao dich hoan tien (dien o ORD-14)']
  request_event_id uuid [note: 'outbox_messages.id cua event OrderRefundRequested, de doi soat']
  failure_code text [note: 'Ma loi Payment tra ve khi RefundFailed, Support doi soat thu cong']
  requested_at timestamptz [not null, default: `now()`]
  completed_at timestamptz
  failed_at timestamptz
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  row_version bigint [not null, default: 0]

  indexes {
    order_id [unique, name: 'uq_order_refunds_order_active', note: 'PARTIAL WHERE order_id IS NOT NULL AND status IN (REQUESTED, COMPLETED). ORD-13 chan refund trung; FAILED thi duoc tao lai']
    auction_order_id [unique, name: 'uq_order_refunds_auction_active', note: 'PARTIAL WHERE auction_order_id IS NOT NULL AND status IN (REQUESTED, COMPLETED)']
    checkout_group_id [unique, name: 'uq_order_refunds_group_active', note: 'PARTIAL WHERE checkout_group_id IS NOT NULL AND status IN (REQUESTED, COMPLETED)']
    refund_transaction_id [unique, name: 'uq_order_refunds_txn', note: 'PARTIAL WHERE refund_transaction_id IS NOT NULL. ORD-14 idempotent']
    (status, requested_at) [name: 'idx_order_refunds_pending', note: 'PARTIAL WHERE status IN (REQUESTED, FAILED). Support doi soat refund treo/loi']
    cancellation_id [name: 'idx_order_refunds_cancellation', note: 'PARTIAL WHERE cancellation_id IS NOT NULL']
  }

  Note: '''
    Yeu cau hoan tien gui sang Payment Service (async qua outbox). Ho tro hoan toan phan va mot phan.
    CHECK num_nonnulls(order_id, auction_order_id, checkout_group_id) = 1
    CHECK: status = COMPLETED thi bat buoc co completed_at va refund_transaction_id
  '''
}

Table order_invoices {
  id uuid [pk, default: `gen_random_uuid()`]
  invoice_no text [unique, not null, note: 'INV-YYYYMMDD-NNNNNN']
  order_id uuid [note: 'XOR voi auction_order_id']
  auction_order_id uuid [note: 'XOR voi order_id']
  total_amount numeric(18,2) [not null]
  file_url text
  status text [not null, default: 'GENERATED', note: 'CHECK: GENERATED | FAILED']
  issued_at timestamptz [not null, default: `now()`]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    order_id [unique, name: 'uq_order_invoices_order', note: 'PARTIAL WHERE order_id IS NOT NULL. Moi don mot hoa don']
    auction_order_id [unique, name: 'uq_order_invoices_auction', note: 'PARTIAL WHERE auction_order_id IS NOT NULL']
  }

  Note: 'CHECK num_nonnulls(order_id, auction_order_id) = 1'
}

// =====================================================================
// DISCOUNT
// =====================================================================
Table discount_codes {
  id uuid [pk, default: `gen_random_uuid()`]
  code text [not null, note: 'Unique khong phan biet hoa thuong trong cac code chua xoa (uq_discount_codes_code)']
  name text [not null]
  scope_type text [not null, note: 'CHECK: SYSTEM | SHOP | PRODUCT. SYSTEM <=> owner_seller_id IS NULL']
  owner_seller_id uuid [note: 'Cross-service ref: user.users.id (null if SYSTEM)']
  discount_type text [not null, note: 'CHECK: PERCENT | FIXED']
  discount_value numeric(18,2) [not null, note: 'CHECK > 0, va <= 100 neu PERCENT']
  max_discount_amount numeric(18,2) [note: 'NULL = khong gioi han. CHECK > 0 neu co']
  min_order_amount numeric(18,2) [not null, default: 0, note: 'CHECK >= 0']
  max_uses_total integer [note: 'CHECK used_count + reserved_count <= max_uses_total']
  max_uses_per_user integer [note: 'CHECK > 0 neu co']
  used_count integer [not null, default: 0, note: 'CHECK >= 0']
  reserved_count integer [not null, default: 0, note: 'CHECK >= 0']
  is_visible boolean [not null, default: true, note: 'Hidden codes can still be used']
  status text [not null, default: 'DRAFT', note: 'CHECK: DRAFT | ACTIVE | INACTIVE | EXPIRED']
  starts_at timestamptz
  ends_at timestamptz [note: 'CHECK ends_at > starts_at']
  created_by uuid
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  deleted_at timestamptz

  indexes {
    `lower(code)` [unique, name: 'uq_discount_codes_code', note: 'PARTIAL WHERE deleted_at IS NULL']
    (scope_type, owner_seller_id, ends_at) [name: 'idx_discount_codes_available', note: 'PARTIAL WHERE status = ACTIVE AND is_visible AND deleted_at IS NULL. DSC-01']
  }
}

Table discount_code_scopes {
  id uuid [pk, default: `gen_random_uuid()`]
  discount_code_id uuid [not null]
  scope_ref_type text [not null, note: 'CHECK: SHOP | PRODUCT | SKU | CATEGORY | ALL']
  scope_ref_id uuid [note: 'CHECK: scope_ref_type = ALL <=> scope_ref_id IS NULL']
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    (discount_code_id, scope_ref_type, `coalesce(scope_ref_id, '00000000-0000-0000-0000-000000000000'::uuid)`) [unique, name: 'uq_discount_code_scopes', note: 'Chong trung scope; COALESCE vi NULL khong bang NULL']
    (scope_ref_type, scope_ref_id) [name: 'idx_discount_code_scopes_ref']
  }
}

Table discount_code_usages {
  id uuid [pk, default: `gen_random_uuid()`]
  discount_code_id uuid [not null]
  user_id uuid [not null, note: 'Cross-service ref: user.users.id']
  order_id uuid
  checkout_group_id uuid
  status text [not null, default: 'RESERVED', note: 'CHECK: RESERVED | USED | RELEASED']
  discount_amount numeric(18,2) [not null, default: 0, note: 'CHECK >= 0']
  reserved_at timestamptz [not null, default: `now()`]
  used_at timestamptz
  released_at timestamptz
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    (discount_code_id, user_id, status) [name: 'idx_discount_code_usages_user', note: 'DSC-03: dem luot dung theo user (RESERVED + USED)']
    order_id [name: 'idx_discount_code_usages_order', note: 'PARTIAL WHERE order_id IS NOT NULL']
    checkout_group_id [name: 'idx_discount_code_usages_group', note: 'PARTIAL WHERE checkout_group_id IS NOT NULL']
  }

  Note: 'CHECK order_id IS NOT NULL OR checkout_group_id IS NOT NULL'
}

// =====================================================================
// PLATFORM / INFRASTRUCTURE
// =====================================================================
Table system_settings {
  id uuid [pk, default: `gen_random_uuid()`]
  setting_key text [unique, not null]
  setting_value text [not null]
  value_type text [not null, default: 'STRING', note: 'CHECK: STRING | INTEGER | DECIMAL | BOOLEAN | JSON']
  category text [not null, note: 'CHECK: REPUTATION | MONEY | AUCTION | TIMING | SYSTEM']
  description text
  is_editable boolean [not null, default: true]
  updated_by uuid
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  Note: 'Seed v2: CART_EXPIRATION_DAYS=7, CHECKOUT_TIMEOUT_MINUTES=15, SELLER_RESPOND_HOURS=24, ORDER_AUTO_COMPLETE_DAYS=7 (de xuat), PAYMENT_RETRY_LIMIT=3, MAX_QTY_PER_ITEM=99, MAX_CART_ITEMS=50'
}

Table daily_order_sequences {
  seq_date date [not null]
  seq_type text [not null, note: 'CHECK: ORDER_NO | AUCTION_ORDER_NO | INVOICE_NO']
  last_value bigint [not null, default: 0, note: 'CHECK >= 0']
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]

  indexes {
    (seq_date, seq_type) [pk]
  }
}

Table saga_state {
  correlation_id uuid [pk, note: 'order_id / checkout_group_id']
  current_state text [not null, note: 'CheckoutSaga: INVENTORY_RESERVING | AWAITING_PAYMENT | PAYMENT_PENDING | COMPLETED | COMPENSATED. OrderCancellationSaga: CANCELLING | REFUND_PENDING | COMPLETED | FAILED. Terminal: COMPLETED, COMPENSATED, FAILED']
  saga_type text [not null, note: 'CHECK: CheckoutSaga | OrderCancellationSaga']
  state_data jsonb [not null, default: '{}']
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz [not null, default: `now()`]
  row_version bigint [not null, default: 0]

  indexes {
    updated_at [name: 'idx_saga_state_stuck', note: 'PARTIAL WHERE current_state NOT IN (COMPLETED, COMPENSATED, FAILED). ORD-21 quet saga treo']
  }
}

Table outbox_messages {
  id uuid [pk, default: `gen_random_uuid()`, note: 'event_id']
  aggregate_type text [not null]
  aggregate_id uuid [not null]
  event_type text [not null]
  payload jsonb [not null]
  headers jsonb [not null, default: '{}']
  occurred_at timestamptz [not null]
  created_at timestamptz [not null, default: `now()`]
  published_at timestamptz
  retry_count integer [not null, default: 0]
  last_error text
  status text [not null, default: 'PENDING', note: 'CHECK: PENDING | PUBLISHED | FAILED | DEAD']

  indexes {
    occurred_at [name: 'idx_outbox_pending', note: 'PARTIAL WHERE status = PENDING. ORD-20']
    published_at [name: 'idx_outbox_cleanup', note: 'PARTIAL WHERE status = PUBLISHED']
  }
}

Table inbox_messages {
  message_id uuid [not null]
  consumer text [not null]
  event_type text [not null]
  payload jsonb [not null]
  received_at timestamptz [not null, default: `now()`]
  processed_at timestamptz
  status text [not null, default: 'RECEIVED', note: 'CHECK: RECEIVED | PROCESSED | FAILED | SKIPPED']
  retry_count integer [not null, default: 0]
  last_error text

  indexes {
    (message_id, consumer) [pk]
    received_at [name: 'idx_inbox_retry', note: 'PARTIAL WHERE status IN (RECEIVED, FAILED)']
  }
}

Table idempotency_keys {
  "key" text [not null]
  scope text [not null]
  request_hash text [not null]
  response_status integer
  response_body jsonb
  created_at timestamptz [not null, default: `now()`]
  expires_at timestamptz [not null]

  indexes {
    ("key", scope) [pk]
    expires_at [name: 'idx_idempotency_expires', note: 'ORD-19 job don key het han']
  }
}

// =====================================================================
// RELATIONSHIPS (chi FK noi bo Commerce; cross-service ref khong ve)
// =====================================================================
Ref: cart_items.cart_id > carts.id
Ref: checkout_groups.cart_id > carts.id
Ref: orders.checkout_group_id > checkout_groups.id
Ref: order_items.order_id > orders.id

Ref: order_status_history.order_id > orders.id
Ref: order_status_history.auction_order_id > auction_orders.id

Ref: order_cancellations.order_id > orders.id
Ref: order_cancellations.auction_order_id > auction_orders.id

Ref: order_refunds.order_id > orders.id
Ref: order_refunds.auction_order_id > auction_orders.id
Ref: order_refunds.checkout_group_id > checkout_groups.id
Ref: order_refunds.cancellation_id > order_cancellations.id

Ref: order_invoices.order_id > orders.id
Ref: order_invoices.auction_order_id > auction_orders.id

Ref: discount_code_scopes.discount_code_id > discount_codes.id
Ref: discount_code_usages.discount_code_id > discount_codes.id
Ref: discount_code_usages.order_id > orders.id
Ref: discount_code_usages.checkout_group_id > checkout_groups.id

// =====================================================================
// TABLE GROUPS
// =====================================================================
TableGroup cart_checkout {
  carts
  cart_items
  checkout_groups
}

TableGroup regular_orders {
  orders
  order_items
}

TableGroup auction {
  auction_orders
}

TableGroup order_lifecycle {
  order_status_history
  order_cancellations
  order_refunds
  order_invoices
}

TableGroup discounts {
  discount_codes
  discount_code_scopes
  discount_code_usages
}

TableGroup platform_infra {
  system_settings
  daily_order_sequences
  saga_state
  outbox_messages
  inbox_messages
  idempotency_keys
}
```
