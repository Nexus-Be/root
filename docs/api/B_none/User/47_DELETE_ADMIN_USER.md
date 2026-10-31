# [DELETE] /api/v1/admin/users/{userId}

> **Phân hệ thụ lý:** `UserService`  
> **Tên tính năng:** `AdminUsers`  
> **Mã tham chiếu Excel:** `47`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Xóa MỀM 1 user khỏi hệ thống
* **HTTP Method:** `DELETE`
* **Đường dẫn chuẩn:** `/api/v1/admin/users/{userId}`
* **Đường dẫn gốc trong Excel:** `/api/v1/admin/user/{userId}` (Chuẩn hóa từ '/api/v1/admin/user/{userId}' sang chuẩn 100% số nhiều '/api/v1/admin/users/{userId}'.)
* **Quyền hạn truy cập (RBAC):** `Admin`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/User/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `admin-users-plural-route`)
* **Controller Action:** `User.Api/Controllers/AdminUsersController.cs` $\rightarrow$ `DeleteUser()`
* **Application Interface:** `User.Application/Services/AdminUsers/IAdminUserService.cs` $\rightarrow$ `DeleteUserAsync()`
* **Service Implementation:** `User.Application/Services/AdminUsers/AdminUserService.cs` $\rightarrow$ `DeleteUserAsync()`
* **Thực thể & Bảng DB:** `User.Domain/Entities/User.cs` $\rightarrow$ Bảng `Users` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `userId` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"reason": "string (lý do xóa)"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Không có Body (`204 NoContent`)
Áp dụng cho thao tác xóa hoặc cập nhật không cần trả payload dữ liệu.
```http
HTTP/1.1 204 No Content
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `409` | `ACTIVE_AUCTIONS_EXIST` | "Account currently has active auctions or pending orders." | Điều kiện nghiệp vụ đặc thù: ACTIVE_AUCTIONS_EXIST. |
| `404` | `USER_NOT_FOUND` | "User was not found." | Điều kiện nghiệp vụ đặc thù: USER_NOT_FOUND. |
| `403` | `PERMISSION_DENIED` | "You do not have permission to delete user accounts." | Điều kiện nghiệp vụ đặc thù: PERMISSION_DENIED. |
| `401` | `UNAUTHORIZED` | "Authentication required, user is not logged in." | Điều kiện nghiệp vụ đặc thù: UNAUTHORIZED. |
| `400` | `CANNOT_DELETE_ADMIN` | "Cannot delete an administrator account." | Điều kiện nghiệp vụ đặc thù: CANNOT_DELETE_ADMIN. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `USER_NOT_FOUND` | "User not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `UserStatus` | `0` | `PendingVerification` | **Chờ xác thực OTP**: Tài khoản mới đăng ký, chưa kích hoạt email/SĐT. Badge vàng (Warning). |
| `status` | `UserStatus` | `1` | `Active` | **Đang hoạt động**: Tài khoản đã kích hoạt, đầy đủ quyền mua/bán theo role. Badge xanh lá (Success). |
| `status` | `UserStatus` | `2` | `Banned` | **Bị cấm / Khóa**: Tài khoản vi phạm quy định, bị Admin khóa. Badge đỏ (Danger). |
| `status` | `UserStatus` | `3` | `Deleted` | **Đã xóa mềm**: Tài khoản đã hủy hoặc xóa khỏi hệ thống. Badge xám (Muted). |
| `gender` | `Gender` | `0` | `Unspecified` | **Chưa xác định / Không tiết lộ**: Người dùng chưa chọn giới tính. |
| `gender` | `Gender` | `1` | `Male` | **Nam**: Giới tính nam. |
| `gender` | `Gender` | `2` | `Female` | **Nữ**: Giới tính nữ. |
| `gender` | `Gender` | `3` | `Other` | **Khác**: Giới tính khác. |
| `role` | `RoleType` | `0` | `Buyer` | **Khách hàng / Người mua**: Mua sắm, tham gia đấu giá, quản lý ví cá nhân. |
| `role` | `RoleType` | `1` | `Seller` | **Chủ cửa hàng / Người bán**: Đăng bán sản phẩm, mở phiên đấu giá, giao hàng. |
| `role` | `RoleType` | `2` | `SupportStaff` | **Nhân viên vận hành**: Hỗ trợ khách hàng, duyệt hồ sơ Seller, xử lý báo cáo. |
| `role` | `RoleType` | `3` | `Admin` | **Quản trị viên**: Quản lý toàn bộ hệ sinh thái, phân quyền, cấu hình hệ thống. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `IAdminUserService.cs` và `AdminUserService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `AdminUsersController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `AdminUsersTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `admin-users-plural-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
