# 📑 HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — USER SERVICE (16 ENUMS)

---

## 📌 PHẦN 1: BẢNG TỔNG HỢP NHANH TOÀN BỘ 16 ENUM HỆ THỐNG

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
| **12** | `ReportViolationType` | `user_reports.violation_type` | `Fraud (0)`, `Harassment (1)`, `Counterfeit (2)`, `Spam (3)`, `Other (4)` | Phân loại hành vi vi phạm khi người dùng bị tố cáo |
| **13** | `ReportStatus` | `user_reports.status` | `Pending (0)`, `UnderReview (1)`, `Resolved (2)`, `Rejected (3)` | Tiến trình xử lý hồ sơ tố cáo vi phạm |
| **14** | `PenaltyViolationType`| `user_penalties.violation_type` | `PaymentTimeout (0)`, `AuctionNonPayment (1)`, `CancellationWithoutReason (2)`, `Fraud (3)`, `Other (4)` | Hành vi vi phạm dẫn đến án phạt |
| **15** | `PenaltyType` | `user_penalties.penalty_applied` | `Warning (0)`, `DeductPoints (1)`, `SuspendBidding3Days (2)`, `BanAccount (3)`, `Other (4)` | Hình thức chế tài / xử phạt áp dụng |
| **16** | `PenaltyStatus` | `user_penalties.status` | `Active (0)`, `Expired (1)`, `Revoked (2)` | Trạng thái hiệu lực của án phạt |

---

## 📋 PHẦN 2: CHI TIẾT TỪNG ENUM

### 1. UserStatus - Trạng Thái Tài Khoản
* **Bảng CSDL:** `users.status`
* **Kiểu dữ liệu:** `Enum UserStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`PendingVerification`** | Người dùng mới đăng ký, tài khoản đang chờ kích hoạt mã OTP qua email. |
| **1** | **`Active`** | Đã xác thực OTP thành công, tài khoản đang hoạt động bình thường. |
| **2** | **`Banned`** | Bị khóa tài khoản do vi phạm (hủy mọi phiên đăng nhập, cấm giao dịch). |
| **3** | **`Deleted`** | Đã xóa tài khoản (áp dụng cơ chế xóa mềm `is_deleted = true`). |

---

### 2. RoleType - Danh Mục 4 Vai Trò Cốt Lõi Hệ Thống
* **Bảng CSDL:** `roles.role_code`
* **Kiểu dữ liệu:** `Enum RoleType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Buyer`** | Khách mua hàng & tham gia đặt giá trong các phiên đấu giá. |
| **1** | **`Seller`** | Người bán hàng, quản lý gian hàng & mở phiên đấu giá sản phẩm. |
| **2** | **`SupportStaff`** | Nhân viên hỗ trợ (thẩm định hồ sơ mở Shop, xử lý khiếu nại/tố cáo). |
| **3** | **`Admin`** | Quản trị viên tối cao (phân quyền nhân sự, cấu hình tham số toàn sàn). |

---

### 3. Gender - Giới Tính Người Dùng
* **Bảng CSDL:** `users.gender`
* **Kiểu dữ liệu:** `Enum Gender`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Unspecified`** | Chưa xác định / Không muốn tiết lộ. |
| **1** | **`Male`** | Nam. |
| **2** | **`Female`** | Nữ. |
| **3** | **`Other`** | Khác. |

---

### 4. SellerProfileStatus - Trạng Thái Hồ Sơ Mở Shop
* **Bảng CSDL:** `seller_profiles.status`
* **Kiểu dữ liệu:** `Enum SellerProfileStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Pending`** | Buyer vừa nộp hồ sơ gian hàng, đang chờ Support Staff kiểm tra. |
| **1** | **`Approved`** | Hồ sơ hợp lệ, đã duyệt cấp vai trò Seller và mở quyền tạo kho hàng. |
| **2** | **`Rejected`** | Bị từ chối (có lý do `rejection_reason` đi kèm để người dùng nộp lại). |

---

### 5. TrustLevel - Cấp Độ Tin Cậy Điểm Uy Tín
* **Bảng CSDL:** `reputation_scores.trust_level`
* **Kiểu dữ liệu:** `Enum TrustLevel`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Untrusted`** | **0 – 39 điểm:** Mất tín nhiệm $\to$ **Bị khóa toàn bộ đấu giá** (cấm đặt giá lẫn mở bán), chặn hình thức COD. |
| **1** | **`Probation`** | **40 – 49 điểm:** Cảnh báo $\to$ Đủ điều kiện Đặt giá ($\ge 40$), nhưng **Bị cấm Mở bán đấu giá** (yêu cầu $\ge 50$). |
| **2** | **`Standard`** | **50 – 69 điểm:** Tiêu chuẩn $\to$ Mức khởi tạo mặc định khi tạo tài khoản (`INITIAL_REPUTATION_SCORE = 50`), đủ quyền cơ bản tham gia và mở bán đấu giá. |
| **3** | **`Good`** | **70 – 89 điểm:** Tốt $\to$ Hoạt động tích cực, mở tối đa 5 phiên đấu giá đồng thời. |
| **4** | **`Excellent`** | **90 – 100 điểm:** Xuất sắc $\to$ Đối tác Vàng, có huy hiệu tín nhiệm, ưu tiên đề xuất sản phẩm lên top tìm kiếm. |

---

### 6. ReferenceType - Loại Giao Dịch Tham Chiếu
* **Bảng CSDL:** `reputation_logs.reference_type`, `user_reviews.reference_type`
* **Kiểu dữ liệu:** `Enum ReferenceType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Order`** | Đơn hàng mua sắm thường từ Commerce Service. |
| **1** | **`Auction`** | Phiên đấu giá từ Auction Service. |
| **2** | **`Dispute`** | Tranh chấp / Khiếu nại từ hệ thống. |
| **3** | **`System`** | Can thiệp điều chỉnh từ hệ thống hoặc Admin. |

---

### 7. ReputationChangeReason - Lý Do Biến Động Điểm Uy Tín
* **Bảng CSDL:** `reputation_logs.reason`
* **Kiểu dữ liệu:** `Enum ReputationChangeReason`

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
* **Bảng CSDL:** `audit_logs.action`
* **Kiểu dữ liệu:** `Enum AuditAction`

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
* **Bảng CSDL:** `system_configs.data_type`
* **Kiểu dữ liệu:** `Enum ConfigDataType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`String`** | Chuỗi ký tự thông thường. |
| **1** | **`Int`** | Số nguyên (ví dụ: điểm phạt `10`, điểm sàn `40`). |
| **2** | **`Decimal`** | Số thập phân (ví dụ: tỷ lệ phần trăm phí sàn `0.05`). |
| **3** | **`Boolean`** | Giá trị đúng/sai (`true` / `false`). |
| **4** | **`Json`** | Chuỗi cấu trúc định dạng JSON. |

---

### 10. OtpType - Mục Đích Mã Xác Thực OTP
* **Nơi lưu trữ:** Bộ nhớ tạm Redis (`otp:{type}:{email}`)

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Registration`** | Mã OTP gửi qua email để kích hoạt tài khoản đăng ký mới. |
| **1** | **`ForgotPassword`** | Mã OTP gửi qua email để xác thực đặt lại mật khẩu quên. |

---

### 11. ReviewerRole - Vai Trò Đối Tác Gửi Đánh Giá
* **Bảng CSDL:** `user_reviews.reviewer_role`
* **Kiểu dữ liệu:** `Enum ReviewerRole`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Buyer`** | Người mua gửi đánh giá nhận xét cho Người bán / Shop sau khi nhận hàng. |
| **1** | **`Seller`** | Người bán gửi đánh giá nhận xét cho Người mua sau khi hoàn tất đơn. |

---

### 12. ReportViolationType - Loại Vi Phạm Tố Cáo
* **Bảng CSDL:** `user_reports.violation_type`
* **Kiểu dữ liệu:** `Enum ReportViolationType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Fraud`** | Hành vi lừa đảo chiếm đoạt tài sản, gian lận thanh toán. |
| **1** | **`Harassment`** | Quấy rối, đe dọa, xúc phạm nhân phẩm đối tác. |
| **2** | **`Counterfeit`** | Bán hàng giả, hàng nhái, vi phạm quyền sở hữu trí tuệ. |
| **3** | **`Spam`** | Spam tin nhắn, đặt đơn ảo, phá hoại phiên đấu giá. |
| **4** | **`Other`** | Hành vi vi phạm quy chế sàn khác (kèm mô tả chi tiết). |

---

### 13. ReportStatus - Trạng Thái Hồ Sơ Tố Cáo
* **Bảng CSDL:** `user_reports.status`
* **Kiểu dữ liệu:** `Enum ReportStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Pending`** | Tiếp nhận đơn tố cáo mới, chờ phân công nhân viên xem xét. |
| **1** | **`UnderReview`** | Nhân viên hỗ trợ đang điều tra, liên hệ các bên và đối soát chứng cứ. |
| **2** | **`Resolved`** | Đã có kết luận giải quyết (có thể kèm án phạt áp dụng cho tài khoản vi phạm). |
| **3** | **`Rejected`** | Từ chối tố cáo do chứng cứ không xác thực hoặc tố cáo sai sự thật. |

---

### 14. PenaltyViolationType - Loại Hành Vi Vi Phạm Dẫn Đến Phạt
* **Bảng CSDL:** `user_penalties.violation_type`
* **Kiểu dữ liệu:** `Enum PenaltyViolationType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`PaymentTimeout`** | Quá hạn thanh toán đơn hàng quy định. |
| **1** | **`AuctionNonPayment`** | Bùng kèo không thanh toán sau 24h thắng phiên đấu giá. |
| **2** | **`CancellationWithoutReason`** | Người bán tự ý hủy đơn hàng đã xác nhận mà không có lý do chính đáng. |
| **3** | **`Fraud`** | Gian lận giá thầu, tạo nick ảo đẩy giá hoặc bán hàng cấm. |
| **4** | **`Other`** | Vi phạm các quy định vận hành khác của sàn. |

---

### 15. PenaltyType - Hình Thức Chế Tài Áp Dụng
* **Bảng CSDL:** `user_penalties.penalty_applied`
* **Kiểu dữ liệu:** `Enum PenaltyType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Warning`** | Gửi thông báo cảnh cáo chính thức đến tài khoản. |
| **1** | **`DeductPoints`** | Trừ điểm uy tín sàn (ghi kèm số điểm trừ vào `points_deducted`). |
| **2** | **`SuspendBidding3Days`** | Tạm đình chỉ quyền tham gia đấu giá trong 3 ngày. |
| **3** | **`BanAccount`** | Khóa tài khoản vĩnh viễn và cấm tham gia sàn. |
| **4** | **`Other`** | Chế tài xử phạt đặc thù khác. |

---

### 16. PenaltyStatus - Trạng Thái Hiệu Lực Án Phạt
* **Bảng CSDL:** `user_penalties.status`
* **Kiểu dữ liệu:** `Enum PenaltyStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :-: | :--- | :--- |
| **0** | **`Active`** | Án phạt đang có hiệu lực thi hành. |
| **1** | **`Expired`** | Án phạt có thời hạn đã hết hiệu lực. |
| **2** | **`Revoked`** | Án phạt đã được Admin hủy bỏ / ân xá sau khi khiếu nại thành công. |
