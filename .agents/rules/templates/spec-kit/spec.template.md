# Đặc Tả Tính Năng: [Tên Tính Năng]
> **Vị trí lưu trữ quy chuẩn:** `specs/[tên-tính-năng]/spec.md`

---

## 1. Bối Cảnh & Mục Tiêu (Context & Goals)
- **Bối cảnh:** [Tại sao cần tính năng này?]
- **Mục tiêu cốt lõi:** [Người dùng làm được gì sau khi hoàn thành?]

---

## 2. Ranh Giới Bất Biến (Non-Goals)
- 🔴 [Nêu rõ những gì phiên bản này KHÔNG giải quyết để chặn AI sinh mã thừa]
- 🔴 [Không tích hợp các module ngoài phạm vi]

---

## 3. Các Tác Nhân (Actors & Roles)
- **Actor 1:** [Quyền hạn và vai trò]
- **Actor 2:** [Quyền hạn và vai trò]

---

## 4. Kịch Bản Kiểm Thử Hành Vi (User Scenarios)

### Kịch bản 1: [Tên kịch bản thành công]
- **Given:** [Điều kiện tiên quyết ban đầu]
- **When:** [Người dùng thực hiện hành động gì]
- **Then:** [Hệ thống phản hồi gì, dữ liệu gì thay đổi]

### Kịch bản 2: [Tên kịch bản lỗi / từ chối]
- **Given:** [Điều kiện khi thiếu quyền hoặc dữ liệu sai]
- **When:** [Người dùng cố tình thực hiện hành động]
- **Then:** [Hệ thống trả về mã lỗi cụ thể, không làm hỏng dữ liệu]

---

## 5. Danh Mục Mã Lỗi & HTTP Status
| Mã lỗi | HTTP Status | Thông điệp trả về |
| :--- | :--- | :--- |
| `ERR_UNAUTHORIZED` | 401 | Yêu cầu đăng nhập |
| `ERR_FORBIDDEN` | 403 | Thiếu quyền thực thi |
| `ERR_NOT_FOUND` | 404 | Tài nguyên không tồn tại |
