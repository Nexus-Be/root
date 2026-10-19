# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — LOG SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `CentralAuditAction` | `CentralAuditLogs.Action` | — | Phân loại hành động kiểm toán tập trung toàn hệ thống |
| 2 | `AuditSyncStatus` | `AuditSyncBatches.Status` | `Completed (0)` | Trạng thái của các đợt đồng bộ nhật ký từ Worker |
| 3 | `AppEnvironment` | `AppLogFileCatalogs.Environment` | `Production (2)` | Môi trường triển khai phát sinh log ứng dụng |
| 4 | `AlertSeverity` | `SecurityAuditAlerts.Severity` | `High (2)` | Cấp độ nghiêm trọng của cảnh báo an ninh |
| 5 | `SecurityRuleType` | `SecurityAuditAlerts.TriggeredRule` | — | Quy tắc bảo mật kích hoạt cảnh báo bất thường |
| 6 | `AlertStatus` | `SecurityAuditAlerts.Status` | `Open (0)` | Trạng thái xử lý sự cố cảnh báo an ninh |

---

## 2. Chi Tiết Từng Enum

### 2.1 CentralAuditAction – Hành Động Kiểm Toán Toàn Sàn
* **Bảng CSDL:** `CentralAuditLogs.Action`
* **Kiểu dữ liệu:** `Enum CentralAuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Create` | Thêm mới bản ghi dữ liệu |
| `1` | `Update` | Cập nhật thông tin bản ghi |
| `2` | `Delete` | Xóa cứng bản ghi dữ liệu |
| `3` | `Login` | Đăng nhập tài khoản người dùng / nhân sự |
| `4` | `Logout` | Đăng xuất tài khoản |
| `5` | `Approve` | Phê duyệt giao dịch, hồ sơ hoặc đơn hàng |
| `6` | `Reject` | Từ chối giao dịch, hồ sơ hoặc đơn hàng |
| `7` | `SoftDelete` | Xóa mềm bản ghi dữ liệu (`IsDeleted = true`) |
| `8` | `Export` | Xuất file báo cáo dữ liệu nhạy cảm |
| `9` | `Other` | Thao tác đặc thù khác |

---

### 2.2 AuditSyncStatus – Trạng Thái Đồng Bộ Batch
* **Bảng CSDL:** `AuditSyncBatches.Status`
* **Kiểu dữ liệu:** `Enum AuditSyncStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Completed` | Đợt đồng bộ nạp log hoàn tất 100% |
| `1` | `Partial` | Đồng bộ thành công một phần, có bản ghi bị lỗi |
| `2` | `Failed` | Đợt đồng bộ thất bại hoàn toàn |

---

### 2.3 AppEnvironment – Môi Trường Hệ Thống
* **Bảng CSDL:** `AppLogFileCatalogs.Environment`
* **Kiểu dữ liệu:** `Enum AppEnvironment`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Development` | Môi trường phát triển nội bộ của lập trình viên |
| `1` | `Staging` | Môi trường kiểm thử tích hợp (UAT / Staging) |
| `2` | `Production` | Môi trường vận hành thực tế (Live Production) |

---

### 2.4 AlertSeverity – Cấp Độ Nghiêm Trọng Cảnh Báo
* **Bảng CSDL:** `SecurityAuditAlerts.Severity`
* **Kiểu dữ liệu:** `Enum AlertSeverity`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Low` | Cảnh báo mức thấp (hành vi bất thường nhẹ) |
| `1` | `Medium` | Cảnh báo mức trung bình (truy cập bất thường) |
| `2` | `High` | Cảnh báo mức cao (xóa hàng loạt, vi phạm bảo mật) |
| `3` | `Critical` | Cảnh báo tối khẩn cấp (xâm nhập trái phép, can thiệp số dư) |

---

### 2.5 SecurityRuleType – Phân Loại Quy Tắc Cảnh Báo
* **Bảng CSDL:** `SecurityAuditAlerts.TriggeredRule`
* **Kiểu dữ liệu:** `Enum SecurityRuleType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `MassDelete` | Phát hiện xóa số lượng lớn bản ghi dữ liệu |
| `1` | `BalanceTampering` | Phát hiện can thiệp số dư ví trái phép |
| `2` | `PrivilegeEscalation` | Phát hiện hành vi leo thang đặc quyền trái phép |
| `3` | `SuspiciousLogin` | Đăng nhập bất thường từ IP lạ hoặc nhiều thiết bị cùng lúc |
| `4` | `RateLimitExceeded` | Vượt ngưỡng truy vấn cho phép liên tục |

---

### 2.6 AlertStatus – Trạng Thái Xử Lý Cảnh Báo
* **Bảng CSDL:** `SecurityAuditAlerts.Status`
* **Kiểu dữ liệu:** `Enum AlertStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Open` | Cảnh báo mới phát hiện, chưa có người nhận xử lý |
| `1` | `Investigating` | Nhân viên an ninh / Admin đang điều tra sự cố |
| `2` | `Resolved` | Đã xử lý khắc phục xong sự cố bảo mật |
| `3` | `Dismissed` | Đánh dấu cảnh báo giả (False Positive) |
