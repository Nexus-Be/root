# 📐 HƯỚNG DẪN CẬP NHẬT ERD VÀ QUAN HỆ BẢNG CSDL (USER SERVICE)
> **Dành cho:** Vẽ / Chỉnh sửa thủ công trên **Draw.io**, **dbdiagram.io** hoặc tài liệu thiết kế.  
> **Cập nhật:** 22/10/2026 — Chuẩn hóa 13 bảng CSDL `user_db`.

---

## 📌 PHẦN 1. HAI BẢNG MỚI THÊM (NÂNG TỔNG SỐ LÊN 13 BẢNG)

### 1. Bảng `user_reports` (Tố cáo người dùng vi phạm)
* **Ý nghĩa:** Tiếp nhận khiếu nại, tố cáo giữa Người mua (Buyer) và Người bán (Seller) khi có hành vi lừa đảo, chửi bới, bán hàng giả, gian lận đấu giá.
* **Cấu trúc cột:**
  | Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Ý Nghĩa / Ghi Chú |
  | :--- | :--- | :--- | :--- |
  | `id` | `UUID` | **PK** | Khóa chính |
  | `reporter_id` | `UUID` | **FK** ➔ `users.id` | Người gửi đơn tố cáo |
  | `reported_user_id` | `UUID` | **FK** ➔ `users.id` | Kẻ bị tố cáo vi phạm |
  | `violation_type` | `VARCHAR(50)` | NOT NULL | Loại vi phạm (`FRAUD`, `HARASSMENT`, `COUNTERFEIT`, `SPAM`...) |
  | `description` | `TEXT` | NOT NULL | Nội dung chi tiết tố cáo |
  | **`evidence_urls`** | `TEXT[]` | NULL | **Mảng link ảnh/video bằng chứng vi phạm** (upload S3/Cloud) |
  | `status` | `VARCHAR(30)` | NOT NULL | `PENDING`, `UNDER_REVIEW`, `RESOLVED`, `REJECTED` |
  | `resolved_by` | `UUID` | **FK** ➔ `users.id` | Nhân viên Support/Admin duyệt đơn |
  | `resolution_note` | `TEXT` | NULL | Kết luận và hướng giải quyết của Admin |
  | `created_at` | `TIMESTAMP` | NOT NULL | Thời điểm gửi tố cáo |
  | `updated_at` | `TIMESTAMP` | NOT NULL | Thời điểm xử lý xong |
* **Dây nối trên Draw.io:**
  * `users (1)` ────< `user_reports (N)` (qua `reporter_id` ➔ `users.id`)
  * `users (1)` ────< `user_reports (N)` (qua `reported_user_id` ➔ `users.id`)
  * `users (1)` ────< `user_reports (N)` (qua `resolved_by` ➔ `users.id`)

---

### 2. Bảng `user_penalties` (Biên bản án phạt & trừ điểm)
* **Ý nghĩa:** Quản lý lịch sử phạt vi phạm quy chế sàn (bùng kèo đấu giá sau 24h, hủy đơn không lý do) để tự động trừ điểm uy tín và áp dụng chế tài.
* **Cấu trúc cột:**
  | Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Ý Nghĩa / Ghi Chú |
  | :--- | :--- | :--- | :--- |
  | `id` | `UUID` | **PK** | Khóa chính |
  | `user_id` | `UUID` | **FK** ➔ `users.id` | Tài khoản nhận án phạt |
  | `violation_type` | `VARCHAR(50)` | NOT NULL | Hành vi vi phạm (`PAYMENT_TIMEOUT`, `AUCTION_NON_PAYMENT`...) |
  | `reason` | `VARCHAR(500)` | NOT NULL | Lý do xử phạt |
  | `penalty_applied` | `VARCHAR(100)` | NOT NULL | Chế tài (`WARNING`, `DEDUCT_POINTS`, `SUSPEND_BIDDING_3D`, `BAN_ACCOUNT`) |
  | `points_deducted` | `INT` | DEFAULT 0 | Số điểm uy tín bị trừ (ví dụ: -10 điểm) |
  | `status` | `VARCHAR(30)` | DEFAULT 'ACTIVE' | `ACTIVE` (đang hiệu lực), `EXPIRED` (hết hạn), `REVOKED` (hủy bỏ) |
  | `issued_at` | `TIMESTAMP` | NOT NULL | Ngày ban hành án phạt |
  | `expires_at` | `TIMESTAMP` | NULL | Ngày hết hạn phạt (nếu là cấm có thời hạn) |
  | `created_by` | `UUID` | **FK** ➔ `users.id` | Admin/Support ban hành (NULL nếu do cron job tự phạt) |
  | `updated_at` | `TIMESTAMP` | NOT NULL | Ngày cập nhật |
* **Dây nối trên Draw.io:**
  * `users (1)` ────< `user_penalties (N)` (qua `user_id` ➔ `users.id`)
  * `users (1)` ────< `user_penalties (N)` (qua `created_by` ➔ `users.id`)

---

## 📌 PHẦN 2. CÁC BẢNG CŨ BỔ SUNG CỘT (AVATAR, LINK URL & CỘT QUAN TRỌNG)

### 3. Bảng `users` (Tài khoản người dùng)
* **Cột thêm mới:**
  * **`avatar_url`** (`VARCHAR(500)`): Link ảnh đại diện cá nhân người dùng.
  * `deleted_at` (`TIMESTAMP`): Thời gian xóa mềm (dùng cùng `is_deleted = true`).
  * `banned_by` (`UUID`, FK ➔ `users.id`): Admin đã bấm khóa nick.
  * `first_name` & `last_name`: Đã tách từ `full_name` cũ.
* **Dây nối tự trỏ:**
  * `users (1)` ────< `users (N)` (qua `banned_by` ➔ `users.id`).

---

### 4. Bảng `seller_profiles` (Hồ sơ gian hàng người bán)
* **Cột thêm mới:**
  * **`avatar_url`** (`VARCHAR(500)`): **Logo / Avatar riêng của Shop** (phân biệt với avatar cá nhân).
  * **`id_card_front_url`** (`VARCHAR(500)`): Link ảnh mặt trước CCCD khi duyệt mở shop.
  * **`id_card_back_url`** (`VARCHAR(500)`): Link ảnh mặt sau CCCD.
  * **`business_license_url`** (`VARCHAR(500)`): Link ảnh Giấy phép kinh doanh (nếu có).
  * `business_email` (`VARCHAR(255)`): Email liên hệ công việc riêng của gian hàng.
  * `reviewed_by` (`UUID`, FK ➔ `users.id`): Nhân viên Support/Admin duyệt hồ sơ mở shop.
  *(Lưu ý: Các cột thẻ ngân hàng đã bỏ và chuyển giao dứt điểm sang `WalletService`)*.
* **Dây nối trên Draw.io:**
  * `users (1)` ──── `seller_profiles (0..1)`: **Quan hệ 1 - 1** (nối `seller_profiles.user_id` ➔ `users.id`).
  * `users (1)` ────< `seller_profiles (N)`: **Quan hệ 1 - N** (qua `reviewed_by` ➔ `users.id`).

---

### 5. Bảng `user_reviews` (Đánh giá giao dịch 2 chiều)
* **Cột thêm mới:**
  * **`media_urls`** (`TEXT[]`): **Mảng link ảnh/video mở hộp sản phẩm** khi người mua/bán đánh giá.
  * `reviewer_role` (`VARCHAR(20)`): Bắt buộc chỉ nhận `'BUYER'` hoặc `'SELLER'` để phân biệt đánh giá 2 chiều.
  * `updated_at` (`TIMESTAMP`): Cho phép cập nhật nhận xét đánh giá.
* **Dây nối trên Draw.io:**
  * `users (1)` ────< `user_reviews (N)` (qua `reviewer_id` ➔ `users.id` - người gửi đánh giá)
  * `users (1)` ────< `user_reviews (N)` (qua `reviewee_id` ➔ `users.id` - người nhận đánh giá)

---

### 6. Các cập nhật nhỏ khác
* **Bảng `roles`**: Thêm cột `is_system_role` (`BOOLEAN DEFAULT false`) để bảo vệ 4 vai trò cốt lõi.
* **Bảng `reputation_logs`**: Thêm cột `created_by` (`UUID`, FK ➔ `users.id`) ghi nhận Admin chỉnh điểm bằng tay.
* **Bảng `refresh_tokens`**: Cột trạng thái đã chuẩn hóa thành `is_revoked` (`BOOLEAN`).

