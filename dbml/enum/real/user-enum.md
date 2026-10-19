# 📑 HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — USER SERVICE

---

## 📌 PHẦN 1: BẢNG TỔNG HỢP NHANH TOÀN BỘ 11 ENUM HỆ THỐNG

| STT | Tên Enum | Cột CSDL / Nơi lưu | Tóm Tắt Giá Trị (0-based) | Mục Đích Sử Dụng |
| :-: | :--- | :--- | :--- | :--- |
| **1** | `UserStatus` | `users.status` | `PendingVerification (0)`, `Active (1)`, `Banned (2)`, `Deleted (3)` | Vòng đời trạng thái tài khoản |
| **2** | `RoleType` | `roles.role_code` | `Buyer (0)`, `Seller (1)`, `SupportStaff (2)`, `Admin (3)` | 4 vai trò cốt lõi phân quyền toàn sàn |
| **3** | `Gender` | `users.gender` | `Unspecified (0)`, `Male (1)`, `Female (2)`, `Other (3)` | Giới tính người dùng |
| **4** | `SellerProfileStatus` | `seller_profiles.status` | `Pending (0)`, `Approved (1)`, `Rejected (2)` | Tiến trình thẩm định hồ sơ mở Shop |
| **5** | `TrustLevel` | `reputation_scores.trust_level` | `Untrusted (0)`, `Probation (1)`, `Standard (2)`, `Good (3)`, `Excellent (4)` | 5 cấp độ tin cậy rào chắn đấu giá (SRS v1.0) |
| **6** | `ReferenceType` | `reputation_logs.reference_type` | `Order (0)`, `Auction (1)`, `Dispute (2)`, `System (3)` | Nguồn gốc giao dịch tham chiếu |
| **7** | `ReputationChangeReason` | `reputation_logs.reason` | `PositiveReview (0)`, `NegativeReview (1)`, `OrderCompleted (2)`, `AuctionPaymentTimeout (3)`, `DisputeCompensation (4)`, `ManualAdjustment (5)`, `ViolationPenalty (6)` | Lý do cộng / trừ điểm uy tín |
| **8** | `AuditAction` | `audit_logs.action` | `UserUpdate (0)`, `UserBan (1)`, `UserUnban (2)`, `SellerApprove (3)`, `SellerReject (4)`, `RoleAssign (5)`, `SoftDelete (6)`, `ReputationAdjust (7)`, `PasswordReset (8)`, `SystemConfigUpdate (9)` | Lịch sử kiểm toán quản trị Admin |
| **9** | `ConfigDataType` | `system_configs.data_type` | `String (0)`, `Int (1)`, `Decimal (2)`, `Boolean (3)`, `Json (4)` | Kiểu dữ liệu cấu hình tham số sàn |
| **10** | `OtpType` | Redis (`otp:{type}:{email}`) | `Registration (0)`, `ForgotPassword (1)` | Loại mã xác thực OTP gửi qua email |
| **11** | `ReviewerRole` | `user_reviews.reviewer_role` | `Buyer (0)`, `Seller (1)` | Vai trò đối tác gửi đánh giá 2 chiều |

---

## 📋 PHẦN 2: CHI TIẾT TỪNG ENUM

### 1. UserStatus - Trạng Thái Tài Khoản

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `users.status` | `VARCHAR(30) / INT` | Quản lý vòng đời trạng thái tài khoản người dùng trong hệ thống. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`PendingVerification`** | Người dùng mới đăng ký, tài khoản đang chờ kích hoạt mã OTP qua email. |
| **1** | **`Active`** | Đã xác thực OTP thành công, tài khoản đang hoạt động bình thường. |
| **2** | **`Banned`** | Bị khóa tài khoản do vi phạm (hủy mọi phiên đăng nhập, cấm giao dịch). |
| **3** | **`Deleted`** | Đã xóa tài khoản (áp dụng cơ chế xóa mềm `is_deleted = true`). |

---

### 2. RoleType - Danh Mục 4 Vai Trò Cốt Lõi Hệ Thống

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `roles.role_code` | `VARCHAR(50)` | Đóng gói vào Claim `Roles` trong JWT Token để điều hướng giao diện Dashboard. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Buyer`** | Khách mua hàng & tham gia đặt giá trong các phiên đấu giá. |
| **1** | **`Seller`** | Người bán hàng, quản lý gian hàng & mở phiên đấu giá sản phẩm. |
| **2** | **`SupportStaff`** | Nhân viên hỗ trợ (thẩm định hồ sơ mở Shop, xử lý khiếu nại, ẩn đánh giá xấu). |
| **3** | **`Admin`** | Quản trị viên tối cao (phân quyền nhân sự, cấu hình tham số toàn sàn). |

---

### 3. Gender - Giới Tính Người Dùng

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `users.gender` | `VARCHAR(20) / INT` | Lưu trữ giới tính của người dùng. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Unspecified`** | Chưa xác định / Không muốn tiết lộ. |
| **1** | **`Male`** | Nam. |
| **2** | **`Female`** | Nữ. |
| **3** | **`Other`** | Khác. |

---

### 4. SellerProfileStatus - Trạng Thái Hồ Sơ Mở Shop

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `seller_profiles.status` | `VARCHAR(30)` | Quản lý tiến trình thẩm định và duyệt hồ sơ đăng ký bán hàng. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Pending`** | Buyer vừa nộp hồ sơ gian hàng, đang chờ Support Staff kiểm tra. |
| **1** | **`Approved`** | Hồ sơ hợp lệ, đã duyệt cấp vai trò Seller và mở quyền tạo kho hàng. |
| **2** | **`Rejected`** | Bị từ chối (có lý do `rejection_reason` đi kèm để người dùng nộp lại). |

---

### 5. TrustLevel - Cấp Độ Tin Cậy Điểm Uy Tín

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_scores.trust_level` | `VARCHAR(30)` | Rào chắn kỹ thuật tự động kiểm tra điều kiện tham gia và mở bán đấu giá theo chuẩn **SRS v1.0**. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Untrusted`** | **0 – 39 điểm:** Mất tín nhiệm $\to$ **Bị khóa toàn bộ đấu giá** (cấm đặt giá lẫn mở bán), chặn hình thức COD. |
| **1** | **`Probation`** | **40 – 49 điểm:** Cảnh báo $\to$ Đủ điều kiện Đặt giá ($\ge 40$), nhưng **Bị cấm Mở bán đấu giá** (yêu cầu $\ge 50$). |
| **2** | **`Standard`** | **50 – 69 điểm:** Tiêu chuẩn $\to$ Mức khởi tạo mặc định khi tạo tài khoản (`INITIAL_REPUTATION_SCORE = 50`), đủ quyền cơ bản tham gia và mở bán đấu giá. |
| **3** | **`Good`** | **70 – 89 điểm:** Tốt $\to$ Hoạt động tích cực, mở tối đa 5 phiên đấu giá đồng thời. |
| **4** | **`Excellent`** | **90 – 100 điểm:** Xuất sắc $\to$ Đối tác Vàng, có huy hiệu tín nhiệm, ưu tiên đề xuất sản phẩm lên top tìm kiếm. |

---

### 6. ReferenceType - Loại Giao Dịch Tham Chiếu

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_logs.reference_type`<br>`user_reviews.reference_type` | `VARCHAR(50)` | Xác định nguồn gốc tham chiếu giao dịch hoặc đối tượng liên quan. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Order`** | Đơn hàng mua sắm thường từ Commerce Service. |
| **1** | **`Auction`** | Phiên đấu giá từ Auction Service. |
| **2** | **`Dispute`** | Tranh chấp / Khiếu nại từ hệ thống. |
| **3** | **`System`** | Can thiệp điều chỉnh từ hệ thống hoặc Admin. |

---

### 7. ReputationChangeReason - Lý Do Biến Động Điểm Uy Tín

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_logs.reason` | `VARCHAR(255)` | Ghi nhận chi tiết nguyên nhân gây biến động điểm uy tín của tài khoản. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`PositiveReview`** | Nhận đánh giá tốt 4 hoặc 5 sao từ đối tác sau đơn hàng (**cộng 1 điểm**). |
| **1** | **`NegativeReview`** | Nhận đánh giá xấu 1 hoặc 2 sao từ đối tác (**trừ 1 hoặc 2 điểm**). |
| **2** | **`OrderCompleted`** | Hoàn thành đơn hàng thành công (**cộng 1 điểm**). |
| **3** | **`AuctionPaymentTimeout`** | Thắng đấu giá nhưng quá 24h không trả tiền (**trừ 10 điểm**). |
| **4** | **`DisputeCompensation`** | Đền bù / Khôi phục điểm uy tín sau khi khiếu nại thành công (**hoàn lại điểm**). |
| **5** | **`ManualAdjustment`** | Admin can thiệp cộng/trừ điểm thủ công có giải trình Audit Log. |
| **6** | **`ViolationPenalty`** | Phạt trừ điểm do hành vi gian lận hoặc vi phạm quy chế sàn. |

---

### 8. AuditAction - Hành Động Kiểm Toán Quản Trị

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `audit_logs.action` | `VARCHAR(100)` | Ghi vết bất biến (Append-Only) mọi thao tác can thiệp dữ liệu của nhân sự nội bộ. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`UserUpdate`** | Cập nhật thông tin tài khoản người dùng. |
| **1** | **`UserBan`** | Khóa tài khoản người dùng vi phạm. |
| **2** | **`UserUnban`** | Mở khóa tài khoản người dùng. |
| **3** | **`SellerApprove`** | Phê duyệt hồ sơ mở gian hàng Shop. |
| **4** | **`SellerReject`** | Từ chối hồ sơ mở gian hàng Shop. |
| **5** | **`RoleAssign`** | Gán vai trò nhân sự nội bộ (tuân thủ nguyên tắc SoD). |
| **6** | **`SoftDelete`** | Xóa mềm tài khoản người dùng. |
| **7** | **`ReputationAdjust`** | Can thiệp điều chỉnh điểm uy tín thủ công. |
| **8** | **`PasswordReset`** | Đặt lại mật khẩu cho người dùng. |
| **9** | **`SystemConfigUpdate`** | Thay đổi giá trị tham số cấu hình sàn. |

---

### 9. ConfigDataType - Kiểu Dữ Liệu Tham Số Sàn

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `system_configs.data_type` | `VARCHAR(30)` | Định nghĩa kiểu dữ liệu của các cấu hình tham số hệ thống. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`String`** | Chuỗi ký tự thông thường. |
| **1** | **`Int`** | Số nguyên (ví dụ: điểm phạt `10`, điểm sàn `40`). |
| **2** | **`Decimal`** | Số thập phân (ví dụ: tỷ lệ phần trăm phí sàn `0.05`). |
| **3** | **`Boolean`** | Giá trị đúng/sai (`true` / `false`). |
| **4** | **`Json`** | Chuỗi cấu trúc định dạng JSON. |

---

### 10. OtpType - Mục Đích Mã Xác Thực OTP

| Nơi lưu trữ | Cấu trúc Key (Redis) | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| Bộ nhớ tạm **Redis** | `otp:{type}:{email}` | Thời hạn tồn tại (TTL): 5 phút. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Registration`** | Mã OTP gửi qua email để kích hoạt tài khoản đăng ký mới. |
| **1** | **`ForgotPassword`** | Mã OTP gửi qua email để xác thực đặt lại mật khẩu quên. |

---

### 11. ReviewerRole - Vai Trò Đối Tác Gửi Đánh Giá

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `user_reviews.reviewer_role` | `VARCHAR(20)` | Xác định người viết đánh giá là Người mua hay Người bán trong giao dịch (Bảng `user_reviews`). |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Buyer`** | Người mua gửi đánh giá nhận xét cho Người bán / Shop sau khi nhận hàng. |
| **1** | **`Seller`** | Người bán gửi đánh giá nhận xét cho Người mua sau khi hoàn tất đơn. |
