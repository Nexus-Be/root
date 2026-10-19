# Danh sách Enum / Status – Catalog Service (Project Nexus)

Tài liệu xác định các giá trị enum và trạng thái của Catalog Service, khớp với file `catalog-service.dbml`. Căn cứ: SRS Project Nexus v1.0.

---

## 1. Quy ước chung

| Quy ước | Nội dung |
|---|---|
| Cách viết | `UPPER_SNAKE_CASE`, ví dụ `DRAFT`, `ACTIVE` |
| Cách lưu trong DB | Cột `VARCHAR` + ràng buộc `CHECK (... IN (...))`, không dùng kiểu enum riêng của DBMS, để đổi hệ quản trị hoặc thêm giá trị dễ hơn |
| Giá trị trong API / event | Dùng **đúng chuỗi** này, không đổi tên, không đổi chữ hoa/thường |
| Thêm hoặc đổi giá trị | Là thay đổi hợp đồng API và event, cần review trước khi áp dụng (SRS 4.2) |

> Các service khác nên công bố danh sách enum của mình theo cùng định dạng này, để nhóm thống nhất giá trị trong event và API.

---

## 2. Bảng tổng hợp

| # | Bảng.cột | Giá trị | Mặc định |
|---|---|---|---|
| 1 | `products.status` | `DRAFT`, `ACTIVE`, `INACTIVE` | `DRAFT` |
| 2 | `products.status_reason` | `SELLER_PAUSED`, `DISCONTINUED`, `ADMIN_LOCKED`, `OTHER` | NULL |
| 3 | `products.sale_type` | `REGULAR`, `AUCTION` | `REGULAR` |
| 4 | `product_variants.status` | `ACTIVE`, `INACTIVE` | `ACTIVE` |
| 5 | `product_variants.status_reason` | `OUT_OF_STOCK`, `DISCONTINUED`, `OTHER` | NULL |
| 6 | `product_reviews.status` | `PUBLISHED`, `HIDDEN` | `PUBLISHED` |
| 7 | `product_reviews.is_deleted` | `false`, `true` (cờ boolean, không phải enum) | `false` |
| 8 | `outbox_messages.status` | `PENDING`, `PUBLISHED`, `FAILED` | `PENDING` |
| 9 | `inbox_messages.status` | `RECEIVED`, `PROCESSED`, `FAILED` | `RECEIVED` |
| 10 | `outbox_messages.aggregate_type` | `PRODUCT`, `CATEGORY`, `REVIEW` | (bắt buộc nhập) |

Ngoài ra `categories` không có enum, dùng cờ `is_active` (true/false) và `deleted_at` (xóa mềm).

---

## 3. Chi tiết từng enum

### 3.1 `products.status` – Trạng thái sản phẩm

Căn cứ SRS: 2.6 `PRODUCT_STATUSES = DRAFT, ACTIVE, INACTIVE`; 3.3.1.1 (tạo mới với trạng thái ban đầu); 3.4.1.6 (cart validation kiểm tra sản phẩm còn `ACTIVE`); 2.8 event `ProductStatusChanged`.

| Giá trị | Ý nghĩa | Buyer thấy? | Cho vào giỏ? |
|---|---|---|---|
| `DRAFT` | Bản nháp, seller đang soạn, chưa đăng | Không | Không |
| `ACTIVE` | Đang bán | Có | Có (nếu `sale_type = REGULAR`) |
| `INACTIVE` | Tạm ngưng bán | Không | Không, cart validation báo không hợp lệ |

**Chuyển trạng thái**

| Từ → Đến | Ai được đổi | Điều kiện |
|---|---|---|
| `DRAFT` → `ACTIVE` | Seller (sản phẩm của mình), Admin | Có ít nhất 1 variant `ACTIVE`. Hàng `REGULAR` phải có giá > 0 |
| `ACTIVE` → `INACTIVE` | Seller, Admin | **Bắt buộc chọn `status_reason`**. Chưa có quy định khi sản phẩm đang có phiên đấu giá (cần chốt với Auction) |
| `INACTIVE` → `ACTIVE` | Seller, Admin | Như `DRAFT` → `ACTIVE`, và `status_reason` được đặt lại NULL. Nếu lý do là `ADMIN_LOCKED` thì **chỉ Admin** được mở lại |
| `ACTIVE`/`INACTIVE` → `DRAFT` | (chưa chốt) | Đề xuất không cho quay lại bản nháp |

```
 DRAFT ──► ACTIVE ◄──► INACTIVE (kèm status_reason)
```

Mỗi lần đổi phát event `ProductStatusChanged`, **payload nên kèm `statusReason`** để các service khác biết vì sao sản phẩm bị ẩn. Cột `published_at` ghi lần đầu chuyển sang `ACTIVE`.

---

### 3.2 `products.status_reason` – Lý do ngừng bán của sản phẩm

Cột `VARCHAR(30)`, cho phép NULL. Căn cứ: yêu cầu của nhóm (SRS không có). Các giá trị là đề xuất, cần nhóm chốt.

| Giá trị | Ý nghĩa | Ai đặt |
|---|---|---|
| `SELLER_PAUSED` | Seller tạm nghỉ bán | Seller |
| `DISCONTINUED` | Ngừng kinh doanh | Seller |
| `ADMIN_LOCKED` | Admin khóa (vi phạm, bị báo cáo) | Admin |
| `OTHER` | Lý do khác | Seller hoặc Admin |

**Quy tắc:**
1. Có giá trị **khi và chỉ khi** `status = INACTIVE`. Các trạng thái khác thì NULL.
2. `ADMIN_LOCKED`: seller không tự bật lại được, chỉ Admin.
3. Cột chỉ lưu **lý do hiện tại**. Lịch sử các lần đổi dựa vào event `ProductStatusChanged` và Event Log (SRS 3.2.1).

```sql
CHECK (status_reason IS NULL OR
       status_reason IN ('SELLER_PAUSED','DISCONTINUED','ADMIN_LOCKED','OTHER'))
CHECK ((status = 'INACTIVE' AND status_reason IS NOT NULL)
    OR (status <> 'INACTIVE' AND status_reason IS NULL))
```

---

### 3.3 `products.sale_type` – Loại bán *(đề xuất, chờ Auction xác nhận)*

Căn cứ SRS: 2.6 `PRODUCT_AUCTION_ENABLED`; 3.5.1.1 (Auction tạo phiên cho một sản phẩm); 3.4.3.1 (đơn tạo từ checkout hoặc từ kết quả đấu giá).

| Giá trị | Ý nghĩa | Giá variant |
|---|---|---|
| `REGULAR` | Bán thường | Bắt buộc > 0 khi đăng bán (`ACTIVE`) |
| `AUCTION` | Chỉ bán qua đấu giá, không vào giỏ, không bán thường | Có thể để trống (giá khởi điểm và bước giá do Auction giữ) |

Lưu ý: một sản phẩm hoặc `REGULAR` hoặc `AUCTION`. Muốn vừa bán thường vừa đấu giá phải tạo hai sản phẩm riêng, hoặc nhóm chốt thêm giá trị `BOTH`.

---

### 3.4 `product_variants.status` – Trạng thái biến thể (SKU)

Căn cứ SRS: 3.6.1.1 (tồn kho theo SKU); 3.4.1.6 (cart validation).

| Giá trị | Ý nghĩa |
|---|---|
| `ACTIVE` | Biến thể đang bán |
| `INACTIVE` | Tạm ngưng riêng biến thể này, sản phẩm cha vẫn bán các biến thể khác |

Nếu sản phẩm cha là `INACTIVE` hoặc `DRAFT` thì mọi variant đều không bán được, dù variant đó là `ACTIVE`.

---

### 3.5 `product_variants.status_reason` – Lý do ngừng bán của biến thể

Cột `VARCHAR(30)`, cho phép NULL. Căn cứ: yêu cầu của nhóm (SRS không có).

| Giá trị | Ý nghĩa | Ai đặt |
|---|---|---|
| `OUT_OF_STOCK` | Hết hàng | Seller |
| `DISCONTINUED` | Ngừng kinh doanh biến thể này | Seller |
| `OTHER` | Lý do khác | Seller hoặc Admin |

**Quy tắc:**
1. Có giá trị **khi và chỉ khi** `status = INACTIVE` của variant.
2. `OUT_OF_STOCK` do **seller tự chọn**. Catalog không biết tồn kho (thuộc Fulfillment, SRS 3.6.1.1). Thông thường hết hàng không cần đổi `status`, vì Fulfillment đã có `available_qty = 0` nên giao diện tự hiện "Hết hàng". Nếu muốn Fulfillment tự ẩn variant khi hết hàng thì cần thêm event và quy tắc riêng, SRS chưa có.

```sql
CHECK (status_reason IS NULL OR
       status_reason IN ('OUT_OF_STOCK','DISCONTINUED','OTHER'))
CHECK ((status = 'INACTIVE' AND status_reason IS NOT NULL)
    OR (status <> 'INACTIVE' AND status_reason IS NULL))
```

---

### 3.6 `product_reviews.status` và `product_reviews.is_deleted` – Trạng thái đánh giá

Căn cứ SRS: 1.2 (đánh giá sản phẩm thuộc phạm vi); 3.1.2.1 (mỗi giao dịch tối đa một đánh giá); 3.1.2.7 (đánh giá liên quan tranh chấp có thể bị điều chỉnh); 3.1.2.8 (ghi nhận để audit).
**Lưu ý:** SRS chưa giao đánh giá *sản phẩm* cho service nào, cần BA xác nhận.

Hai cột độc lập, do hai bên khác nhau điều khiển:

| Cột | Giá trị | Ai đổi | Ý nghĩa |
|---|---|---|---|
| `status` | `PUBLISHED` | Mặc định | Đang hiển thị |
| `status` | `HIDDEN` | Admin / Support | Bị ẩn do kiểm duyệt |
| `is_deleted` | `false` | Mặc định | Chưa xóa |
| `is_deleted` | `true` | Buyer là chủ đánh giá | Buyer tự xóa (xóa mềm). Đã `true` thì không đặt lại `false` |

**Review được hiển thị và tính vào điểm khi cả hai điều kiện cùng đúng:**

```
status = 'PUBLISHED'  AND  is_deleted = false
```

| `status` | `is_deleted` | Hiển thị | Tính vào `star_sum`, `review_count` |
|---|---|---|---|
| `PUBLISHED` | false | Có | Có |
| `HIDDEN` | false | Không | Không |
| `PUBLISHED` | true | Không | Không |
| `HIDDEN` | true | Không | Không |

**Cập nhật `product_rating_stats` khi trạng thái thay đổi** (chỉ cộng/trừ khi "có được tính" đổi từ đúng sang sai hoặc ngược lại):

| Thao tác | Điều kiện | `product_rating_stats` |
|---|---|---|
| Buyer gửi review mới | | `star_sum += rating`, `review_count += 1` |
| Buyer xóa | đang `PUBLISHED`, chưa xóa | `star_sum -= rating`, `review_count -= 1` |
| Buyer xóa | đang `HIDDEN` (đã trừ trước đó) | không đổi |
| Admin ẩn | chưa xóa | `star_sum -= rating`, `review_count -= 1` |
| Admin ẩn | đã xóa | không đổi |
| Admin bỏ ẩn | chưa xóa | cộng lại như review mới |
| Admin bỏ ẩn | đã xóa | không đổi, review vẫn không hiển thị |
| Buyer sửa số sao | đang được tính | `star_sum += (sao mới - sao cũ)` |

Review không bị xóa thật, nên một lần mua chỉ đánh giá được một lần (`UNIQUE purchase_record_id`), kể cả khi đã xóa.

---

### 3.7 `outbox_messages.status` – Event chờ phát

Căn cứ SRS: 2.8 (danh sách event); 3.2.2.1 (khi message broker lỗi); 5.3 (idempotent).

| Giá trị | Ý nghĩa |
|---|---|
| `PENDING` | Chờ gửi lên message broker |
| `PUBLISHED` | Đã gửi thành công |
| `FAILED` | Gửi thất bại sau khi retry, cần xử lý tay |

```
 PENDING ──► PUBLISHED
    │
    └──► FAILED
```

---

### 3.8 `inbox_messages.status` – Event nhận vào

Căn cứ SRS: 5.3 (xử lý idempotent). Catalog nghe `OrderCreated` và `OrderCompleted` (2.8).

| Giá trị | Ý nghĩa |
|---|---|
| `RECEIVED` | Đã nhận, chưa xử lý |
| `PROCESSED` | Đã xử lý xong |
| `FAILED` | Xử lý lỗi, cần retry hoặc xử lý tay |

---

### 3.9 `outbox_messages.aggregate_type` – Loại đối tượng phát event

| Giá trị | Event liên quan (SRS 2.8) |
|---|---|
| `PRODUCT` | `ProductCreated`, `ProductUpdated`, `ProductDeleted`, `ProductStatusChanged` |
| `CATEGORY` | `CategoryCreated`, `CategoryUpdated`, `CategoryDeleted` |
| `REVIEW` | Chưa có trong SRS 2.8, nếu nhóm đồng ý có thể thêm (ví dụ `ProductReviewed`) |

---

## 4. Event Catalog phát và nhận (để đối chiếu với service khác)

| Hướng | Event | Căn cứ |
|---|---|---|
| Phát | `ProductCreated`, `ProductUpdated`, `ProductDeleted`, `ProductStatusChanged` (kèm `statusReason`) | SRS 2.8 |
| Phát | `CategoryCreated`, `CategoryUpdated`, `CategoryDeleted` | SRS 2.8 |
| Nhận | `OrderCreated` (đặt `product_variants.has_order = true`) | SRS 2.8 |
| Nhận | `OrderCompleted` (tạo `purchase_records` để buyer được đánh giá) | SRS 2.8 |

Nội dung (payload) các event này **chưa được SRS định nghĩa**, cần thống nhất với Commerce, Fulfillment và Auction (SRS 4.2).

---

## 5. Điểm cần chốt tại meeting

| # | Vấn đề | Hỏi ai |
|---|---|---|
| 1 | `sale_type` có đúng hai giá trị `REGULAR` / `AUCTION`? Có cần `BOTH`? | Nhóm Auction |
| 2 | Sản phẩm đang có phiên đấu giá có được đổi `INACTIVE` hoặc xóa không? | Nhóm Auction |
| 3 | Danh sách `status_reason` của sản phẩm và variant (mục 3.2, 3.5) đã đủ chưa? Có cần ô ghi chú tự do cho `OTHER` không? | Cả nhóm |
| 4 | Fulfillment có tự ẩn variant khi hết hàng không, hay chỉ seller tự chọn `OUT_OF_STOCK`? | Nhóm Fulfillment |
| 5 | Đánh giá sản phẩm thuộc service nào? Buyer có được sửa, xóa không? | BA / cả nhóm |
| 6 | Buyer xóa đánh giá xong có được đánh giá lại lần mua đó không? (hiện: không) | BA / cả nhóm |
| 7 | Event `OrderCreated`, `OrderCompleted` mang những trường nào (cần `variant_id`, `quantity`)? | Nhóm Commerce |
| 8 | Quy ước đặt tên và cách lưu enum chung cho các service | Cả nhóm |
