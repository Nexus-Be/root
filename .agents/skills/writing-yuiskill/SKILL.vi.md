---
name: writing-yuiskill
description: Tạo và thiết lập kỹ năng nội bộ chuẩn mực cho AI Agent trong dự án hiện tại. Tự động sinh .agents/skills/<tên-kỹ-năng>/SKILL.md với Frontmatter YAML hợp lệ.
---

# Kỹ Năng Tạo Kỹ Năng Mới Cho Dự Án (`/writing-yuiskill`)
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Quy trình chuẩn hóa giúp Lập trình viên hoặc AI Agent nhanh chóng tạo một kỹ năng mới (Agent Skill) bên trong thư mục `.agents/skills/<tên-kỹ-năng>/` của repository đang làm việc.

---

## Các Bước Thực Hiện Của Agent

### Bước 1: Thu Thập Yêu Cầu & Ranh Giới Kỹ Năng
Hỏi người dùng 4 thông tin thiết yếu:
1. **Tên kỹ năng (Skill Name):** Dạng kebab-case viết liền bằng dấu gạch ngang (ví dụ: `audit-db-schema`, `generate-api-client`).
2. **Kịch bản kích hoạt (Trigger):** Khi nào thì người dùng hoặc Agent sẽ gọi kỹ năng này?
3. **Đầu vào & Điều kiện tiên quyết:** Cần đọc những tệp, biến môi trường hay dữ liệu nào trước khi chạy?
4. **Các bước hành động chi tiết:** Quy trình 3 đến 5 bước tuần tự Agent phải tuân thủ.

---

### Bước 2: Tạo Thư Mục & Soạn Thảo `SKILL.md`
Khởi tạo thư mục độc lập tại `.agents/skills/<tên-kỹ-năng>/` với cấu trúc:

```markdown
---
name: <tên-kỹ-năng>
description: <Mô tả ngắn gọn 1-2 câu về mục đích và trường hợp kích hoạt>
---

# <Tên Kỹ Năng> (`/<tên-kỹ-năng>`)

## 1. Tổng Quan & Mục Đích
- [Giải thích ngắn gọn kỹ năng này giải quyết bài toán gì]

## 2. Hướng Dẫn Thực Hiện Từng Bước
1. **Bước 1:** [Kiểm tra điều kiện tiên quyết]
2. **Bước 2:** [Thực thi nhiệm vụ cốt lõi]
3. **Bước 3:** [Nghiệm thu kết quả]

## 3. Tiêu Chí Nghiệm Thu
- [Dấu hiệu chứng minh kỹ năng đã hoàn thành đúng chuẩn]
```

Nếu kỹ năng có script hỗ trợ, tạo thêm thư mục con `.agents/skills/<tên-kỹ-năng>/scripts/` và cấp quyền thực thi (`chmod +x`).

---

### Bước 3: Đăng Ký Vào Danh Mục Của Dự Án
Tự động cập nhật vào `.agents/catalog.json` và bổ sung 1 dòng vào bảng `.agents/CATALOG.md` để kỹ năng mới xuất hiện ngay lập tức trong mục lục tra cứu của dự án.

---

### Bước 4: Kiểm Tra Hoàn Tất
1. Đảm bảo cú pháp Frontmatter YAML không có lỗi.
2. Xác nhận tệp tồn tại trên ổ đĩa.
3. Báo cáo cho người dùng biết kỹ năng đã sẵn sàng để gọi qua lệnh `/<tên-kỹ-năng>`.
