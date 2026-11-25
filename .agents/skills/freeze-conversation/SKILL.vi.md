---
name: freeze-conversation
description: Đóng băng và nén ngữ cảnh cuộc trò chuyện hiện tại thành tệp lưu trữ lâu dài tại .agents/conversations/. Nén các lượt chat cũ, giữ độ chi tiết cao cho các lượt gần nhất, và tạo prompt khởi động cho phiên chat mới.
---

# Kỹ Năng Đóng Băng Cuộc Trò Chuyện (`/freeze-conversation`)
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Quy trình nén, ngoại hóa và đóng băng trạng thái làm việc của phiên chat hiện tại vào một tệp tin lưu trữ lâu dài trong `.agents/conversations/` để phiên chat mới có thể tiếp tục công việc ngay lập tức mà không bị mất trí nhớ hay trôi dạt ngữ cảnh.

---

## Các Bước Thực Hiện Của Agent

### Bước 1: Tổng Hợp Toàn Cảnh Trạng Thái (State of the Union)
Thu thập và cấu trúc đầy đủ 4 chiều thông tin thiết yếu:
1. **Ngữ cảnh toàn diện & Bài toán cốt lõi:** Mục tiêu tối cao, kiến trúc hệ thống và các ranh giới bất biến.
2. **Tiến độ thực thi:**
   - Đã làm được những gì? (Những công việc đã hoàn thành, quyết định đã chốt).
   - Đang làm cái gì? (Những phần việc dở dang, đang chỉnh sửa ngay tại lúc này).
   - Sẽ làm gì tiếp theo? (Nhiệm vụ trước mắt cần bắt tay vào làm).
3. **Sự cố & Cách giải quyết:**
   - Đã gặp những vấn đề, lỗi kỹ thuật hoặc sự hiểu lầm nào?
   - Đã giải quyết như thế nào? Những cái gì đã được giải quyết triệt để?
   - Những điểm nào đang còn rắc rối hoặc thắc mắc dở dang chưa xong?

---

### Bước 2: Áp Dụng Độ Phân Giải Bậc Thang (Tiered Granularity)
- **Các lượt chat cũ ở phía trước:** Nén cô đọng thành các gạch đầu dòng sự thật (facts), ngắn gọn, tiết kiệm token.
- **Các lượt chat gần nhất (3 đến 5 lượt cuối):** BẮT BUỘC giữ độ phân giải cao: ghi lại nguyên văn ý định của người dùng, các yêu cầu tinh tế, các ràng buộc kỹ thuật khắt khe.

---

### Bước 3: Thiết Lập Mạng Lưới Tham Chiếu Tệp Nội Bộ
Liên kết chặt chẽ với các tệp nội bộ của dự án bằng link tương đối:
- Nhật ký: `.agents/notes/YYYY-MM-DD_HHmm-<chủ-đề>.md`
- Quyết định: `.agents/decisions/YYYY-MM-DD_HHmm-<quyết-định>.md`
- Kế hoạch: `.agents/plans/YYYY-MM-DD_HHmm-plan-<kế-hoạch>.md`
- Ngữ cảnh & Thuật ngữ: `.agents/rules/GLOSSARY.md`
- Bảng tổng mục: `docs/DANH_MUC_TRIEN_KHAI.md`
*HẠN CHẾ liên kết trực tiếp số dòng trong mã nguồn để tránh bị trôi liên kết.*

---

### Bước 4: Xuất Tệp Đóng Băng & Tạo Prompt Khởi Động
1. Ghi toàn bộ nội dung nén vào `.agents/conversations/YYYY-MM-DD_HHmm-<tên-cuộc-trò-chuyện>.md`.
2. Tạo đoạn Prompt khởi động độc lập (Zero-Loss Kickoff Prompt) ở cuối tệp và in ra nổi bật trong ô chat để người dùng chỉ việc copy-paste sang cửa sổ chat mới.
