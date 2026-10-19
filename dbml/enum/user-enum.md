# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM

---

## 1. UserStatus - Trạng Thái Tài Khoản

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `users.status` | `VARCHAR(30)` / `INT` | Quản lý vòng đời trạng thái tài khoản người dùng trong hệ thống. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `PendingVerification` | Người dùng mới đăng ký, tài khoản đang chờ kích hoạt mã OTP qua email. |
| `1` | `Active` | Đã xác thực OTP thành công, tài khoản đang hoạt động bình thường. |
| `2` | `Banned` | Bị khóa tài khoản do vi phạm (hủy mọi phiên đăng nhập, cấm giao dịch). |
| `3` | `Deleted` | Đã xóa tài khoản (áp dụng cơ chế xóa mềm `is_deleted = true`). |

---

## 2. RoleType - Danh Mục 4 Vai Trò Cốt Lõi Hệ Thống

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `roles.role_code` | `VARCHAR(50)` | Đóng gói vào Claim Roles trong JWT Token để điều hướng giao diện Dashboard. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `1` | `Buyer` | Khách mua hàng & tham gia đặt giá trong các phiên đấu giá. |
| `2` | `Seller` | Người bán hàng, quản lý gian hàng & mở phiên đấu giá sản phẩm. |
| `3` | `SupportStaff` | Nhân viên hỗ trợ (thẩm định hồ sơ mở Shop, xử lý khiếu nại, ẩn đánh giá xấu). |
| `4` | `Admin` | Quản trị viên tối cao (phân quyền nhân sự, cấu hình tham số toàn sàn). |

---

## 3. Gender - Giới Tính Người Dùng

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `users.gender` | `VARCHAR(20)` / `INT` | Lưu trữ giới tính của người dùng. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Unspecified` | Chưa xác định / Không muốn tiết lộ. |
| `1` | `Male` | Nam. |
| `2` | `Female` | Nữ. |
| `3` | `Other` | Khác. |

---

## 4. SellerProfileStatus - Trạng Thái Hồ Sơ Mở Shop

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `seller_profiles.status` | `VARCHAR(30)` | Quản lý tiến trình thẩm định và duyệt hồ sơ đăng ký bán hàng. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Pending` | Buyer vừa nộp hồ sơ gian hàng, đang chờ Support Staff kiểm tra. |
| `1` | `Approved` | Hồ sơ hợp lệ, đã duyệt cấp vai trò Seller và mở quyền tạo kho hàng. |
| `2` | `Rejected` | Bị từ chối (có lý do `rejection_reason` đi kèm để người dùng nộp lại). |

---

## 5. TrustLevel - Cấp Độ Tin Cậy Điểm Uy Tín

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_scores.trust_level` | `VARCHAR(30)` | Rào chắn kỹ thuật tự động kiểm tra điều kiện tham gia đấu giá. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Low` | Điểm $< 40 \rightarrow$ Bị chặn đặt giá (Bid) trong toàn bộ phiên đấu giá. |
| `1` | `Standard` | Điểm từ $40$ đến $49 \rightarrow$ Đủ điều kiện tham gia đấu giá. |
| `2` | `High` | Điểm từ $50$ đến $79 \rightarrow$ Đủ điều kiện mở phiên đấu giá bán hàng. |
| `3` | `Verified` | Điểm $\ge 80 \rightarrow$ Tài khoản uy tín cao, ưu tiên đề xuất sản phẩm. |

---

## 6. ReferenceType - Loại Giao Dịch Tham Chiếu

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_logs.reference_type`, `user_reviews.reference_type` | `VARCHAR(50)` | Xác định nguồn gốc tham chiếu giao dịch hoặc đối tượng liên quan. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `1` | `Order` | Đơn hàng mua sắm thường từ Commerce Service. |
| `2` | `Auction` | Phiên đấu giá từ Auction Service. |
| `3` | `Dispute` | Tranh chấp / Khiếu nại từ hệ thống. |
| `4` | `System` | Can thiệp điều chỉnh từ hệ thống hoặc Admin. |

---

## 7. ReputationChangeReason - Lý Do Biến Động Điểm Uy Tín

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `reputation_logs.reason` | `VARCHAR(255)` | Ghi nhận chi tiết nguyên nhân gây biến động điểm uy tín của tài khoản. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `1` | `OrderCompleted` | Hoàn thành đơn hàng thành công (cộng 1 điểm). |
| `2` | `AuctionPaymentTimeout` | Thắng đấu giá nhưng quá 24h không trả tiền (trừ 10 điểm). |
| `3` | `DisputeCompensation` | Đền bù điểm uy tín sau khi giải quyết tranh chấp. |
| `4` | `ManualAdjustment` | Admin can thiệp cộng/trừ điểm thủ công có giải trình. |
| `5` | `ViolationPenalty` | Phạt trừ điểm do hành vi gian lận hoặc vi phạm quy chế. |

---

## 8. AuditAction - Hành Động Kiểm Toán Quản Trị

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `audit_logs.action` | `VARCHAR(100)` | Ghi vết bất biến (Append-Only) mọi thao tác can thiệp dữ liệu của nhân sự nội bộ. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `1` | `UserUpdate` | Cập nhật thông tin tài khoản người dùng. |
| `2` | `UserBan` | Khóa tài khoản người dùng. |
| `3` | `UserUnban` | Mở khóa tài khoản người dùng. |
| `4` | `SellerApprove` | Phê duyệt hồ sơ mở gian hàng Shop. |
| `5` | `SellerReject` | Từ chối hồ sơ mở gian hàng Shop. |
| `6` | `RoleAssign` | Gán vai trò nhân sự nội bộ (tuân thủ SoD). |
| `7` | `SoftDelete` | Xóa mềm tài khoản người dùng. |
| `8` | `ReputationAdjust` | Can thiệp điều chỉnh điểm uy tín thủ công. |
| `9` | `PasswordReset` | Đặt lại mật khẩu cho người dùng. |
| `10` | `SystemConfigUpdate` | Thay đổi giá trị tham số cấu hình sàn. |

---

## 9. ConfigDataType - Kiểu Dữ Liệu Tham Số Sàn

| Bảng CSDL | Kiểu lưu trữ | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| `system_configs.data_type` | `VARCHAR(30)` | Định nghĩa kiểu dữ liệu của các cấu hình tham số hệ thống. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `1` | `String` | Chuỗi ký tự thông thường. |
| `2` | `Int` | Số nguyên (ví dụ: điểm phạt 10, điểm sàn 40). |
| `3` | `Decimal` | Số thập phân (ví dụ: tỷ lệ phần trăm phí sàn $0.05$). |
| `4` | `Boolean` | Giá trị đúng/sai (`true` / `false`). |
| `5` | `Json` | Chuỗi cấu trúc định dạng JSON. |

---

## 10. OtpType - Mục Đích Mã Xác Thực OTP

| Nơi lưu trữ | Cấu trúc Key (Redis) | Mục đích / Ghi chú |
| :--- | :--- | :--- |
| Bộ nhớ tạm Redis | `otp:{type}:{email}` | Thời hạn tồn tại (TTL): 5 phút. |

**Danh sách giá trị:**

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Registration` | Mã OTP gửi qua email để kích hoạt tài khoản đăng ký mới. |
| `1` | `ForgotPassword` | Mã OTP gửi qua email để xác thực đặt lại mật khẩu quên. |