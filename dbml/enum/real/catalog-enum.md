# HỆ THỐNG DANH MỤC TRẠNG THÁI & ENUM — CATALOG SERVICE

---

## 1. Bảng Tổng Hợp Enum

| STT | Tên Enum | Bảng & Cột CSDL | Mặc định | Mô tả nghiệp vụ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `ProductStatus` | `Products.Status` | `Draft (0)` | Vòng đời hiển thị và kinh doanh của sản phẩm |
| 2 | `SaleType` | `Products.SaleType` | `Regular (0)` | Hình thức bán sản phẩm (bán lẻ thường hoặc qua đấu giá) |
| 3 | `VariantStatus` | `ProductVariants.Status` | `Active (0)` | Trạng thái kinh doanh độc lập của biến thể (SKU) |
| 4 | `ProductInactiveReason` | `Products.StatusReason` | — | Lý do sản phẩm cha tạm ngừng kinh doanh |
| 5 | `VariantInactiveReason` | `ProductVariants.StatusReason` | — | Lý do biến thể (SKU) tạm ngừng kinh doanh |
| 6 | `ReviewStatus` | `ProductReviews.Status` | `Published (0)` | Trạng thái hiển thị và kiểm duyệt đánh giá |
| 7 | `AuditAction` | `AuditLogs.Action` | — | Hành động kiểm toán thao tác dữ liệu Catalog |

---

## 2. Chi Tiết Từng Enum

### 2.1 ProductStatus – Trạng Thái Sản Phẩm
* **Bảng CSDL:** `Products.Status`
* **Kiểu dữ liệu:** `Enum ProductStatus`
* **Ghi chú:** Đã phân định rõ: việc xóa sản phẩm được quản lý bằng cơ chế xóa mềm qua cờ `IsDeleted` và `DeletedAt`.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Draft` | Bản nháp, người bán đang soạn thảo, chưa xuất bản trên sàn |
| `1` | `Active` | Đang mở bán công khai, hiển thị trong tìm kiếm và cho phép mua |
| `2` | `Inactive` | Tạm ngừng bán (bắt buộc kèm theo lý do `StatusReason`) |

---

### 2.2 SaleType – Hình Thức Bán Hàng
* **Bảng CSDL:** `Products.SaleType`
* **Kiểu dữ liệu:** `Enum SaleType`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Regular` | Bán lẻ thông thường (có thể thêm vào giỏ hàng và mua trực tiếp) |
| `1` | `Auction` | Chỉ bán thông qua sàn đấu giá, không cho phép đặt giỏ hàng trực tiếp |

---

### 2.3 VariantStatus – Trạng Thái Biến Thể SKU
* **Bảng CSDL:** `ProductVariants.Status`
* **Kiểu dữ liệu:** `Enum VariantStatus`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Active` | Biến thể đang được mở bán |
| `1` | `Inactive` | Tạm ngưng bán riêng biến thể này (bắt buộc kèm theo `StatusReason`) |

---

### 2.4 ProductInactiveReason – Lý Do Sản Phẩm Tạm Ngừng Bán
* **Bảng CSDL:** `Products.StatusReason`
* **Kiểu dữ liệu:** `Enum ProductInactiveReason`
* **Quy tắc:** Bắt buộc nhập khi `Products.Status = Inactive`, để `NULL` ở các trạng thái khác.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `SellerPaused` | Người bán chủ động tạm nghỉ kinh doanh mặt hàng |
| `1` | `Discontinued` | Nhà cung cấp / Người bán ngừng kinh doanh vĩnh viễn |
| `2` | `AdminLocked` | Quản trị viên khóa do vi phạm chính sách hoặc bị khiếu nại (chỉ Admin mới được mở lại) |
| `3` | `Other` | Lý do khác |

---

### 2.5 VariantInactiveReason – Lý Do Biến Thể Tạm Ngừng Bán
* **Bảng CSDL:** `ProductVariants.StatusReason`
* **Kiểu dữ liệu:** `Enum VariantInactiveReason`
* **Quy tắc:** Bắt buộc nhập khi `ProductVariants.Status = Inactive`, để `NULL` ở các trạng thái khác.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `OutOfStock` | Tạm hết hàng (người bán chủ động chọn) |
| `1` | `Discontinued` | Ngừng kinh doanh mẫu biến thể cụ thể này |
| `2` | `Other` | Lý do khác |

---

### 2.6 ReviewStatus – Trạng Thái Đánh Giá Sản Phẩm
* **Bảng CSDL:** `ProductReviews.Status`
* **Kiểu dữ liệu:** `Enum ReviewStatus`
* **Ghi chú:** Việc xóa đánh giá bởi người dùng được lưu vết độc lập bằng cờ `IsDeleted`. Đánh giá chỉ được hiển thị và tính điểm khi `Status = Published` và `IsDeleted = false`.

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `Published` | Đang hiển thị công khai và được tính vào tổng điểm sao trung bình |
| `1` | `Hidden` | Bị ẩn bởi Quản trị viên / Nhân viên hỗ trợ do vi phạm tiêu chuẩn cộng đồng |

---

### 2.7 AuditAction – Hành Động Kiểm Toán Catalog
* **Bảng CSDL:** `AuditLogs.Action`
* **Kiểu dữ liệu:** `Enum AuditAction`

| Mã | Giá trị Enum | Mô tả chi tiết |
| :---: | :--- | :--- |
| `0` | `ProductCreate` | Tạo mới sản phẩm |
| `1` | `ProductUpdate` | Cập nhật thông tin sản phẩm |
| `2` | `ProductDelete` | Xóa sản phẩm |
| `3` | `CategoryCreate` | Tạo mới danh mục |
| `4` | `CategoryUpdate` | Cập nhật danh mục |
| `5` | `CategoryDelete` | Xóa danh mục |
| `6` | `ReviewModerate` | Kiểm duyệt / Ẩn hiện đánh giá sản phẩm |
