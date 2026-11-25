# DOMAIN GLOSSARY: TỪ ĐIỂN THUẬT NGỮ BẤT BIẾN (UBIQUITOUS LANGUAGE)
> **Mục đích:** Khóa cứng toàn bộ định nghĩa từ ngữ nghiệp vụ dùng chung giữa Người Dùng và AI Agent. Mọi mã nguồn (Entities, DTOs, API endpoints, UI labels, Database Columns) bắt buộc phải ánh xạ 100% theo các định danh trong tệp này.
> **Quy tắc:** Khi có từ ngữ mơ hồ hoặc mới xuất hiện, Agent dừng lại làm rõ hai chiều và bổ sung ngay vào bảng dưới đây trước khi code.

- ⏱️ **Thời gian khởi tạo từ điển:** [Ngày, Giờ, Phút (UTC+7)]
- ⏱️ **Thời gian cập nhật gần nhất:** [Ngày, Giờ, Phút (UTC+7)]

---

## 📖 BẢNG ĐỐI CHIẾU THUẬT NGỮ & ĐỊNH NGHĨA HAI CHIỀU

| Thuật Ngữ (Term) | Cách Hiểu Của Người Dùng (User Definition) | Ngữ Cảnh Áp Dụng (Context & Scope) | Ngoại Lệ / Lưu Ý (Edge Cases) |
| :--- | :--- | :--- | :--- |
| **`[Ví dụ: Tenant]`** | Khách hàng doanh nghiệp thuê nền tảng SaaS | Toàn bộ hệ thống, cô lập dữ liệu | Không bao gồm System Root Admin |
| **`[Ví dụ: CustomFields]`** | Trường dữ liệu động mở rộng lưu dạng JSONB | Bảng Nhân sự (Employee) | Đánh chỉ mục GIN, không đổi schema |

---

## 🔒 NGUYÊN TẮC BẤT BIẾN
1. **Không đoán nghĩa:** Nếu từ ngữ chưa có trong bảng này và mang tính mơ hồ, Agent bắt buộc phải hỏi lại.
2. **Nhất quán mã nguồn:** Tên biến trong code, tên trường DB và nhãn giao diện bắt buộc dùng đúng danh từ đã chốt ở cột 1.
