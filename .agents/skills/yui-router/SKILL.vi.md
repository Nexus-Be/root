---
name: yui-router
description: Router điều phối ngữ cảnh thông minh cho Yui Agent Kit. Nhận diện ý định tác vụ và kích hoạt đúng tiện ích môi trường làm việc hoặc kỹ năng tương ứng.
---

# Yui Skill Router (`/yui-router`)
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Router điều phối ngữ cảnh thông minh giúp Agent tự động nhận diện ý định của người dùng và kích hoạt đúng tiện ích môi trường làm việc hoặc kỹ năng tương ứng theo nguyên lý **Progressive Disclosure (Nạp ngữ cảnh bậc thang)**.

---

## 🧭 Ma Trận Điều Phối Ngữ Cảnh

Khi nhận được yêu cầu công việc từ người dùng, Agent đối soát với bảng dưới đây:

| Ý định của Người dùng | Lệnh tương ứng | Tiện ích / Tệp cần nạp | Hành động bắt buộc của Agent |
| :--- | :--- | :--- | :--- |
| **Phân tích yêu cầu, logic nghiệp vụ, SRS** | `/srs` hoặc `/context` | `.agents/contexts/business-context.md` | Bóc tách và nạp dữ liệu vào đúng cấu trúc 7 Header SRS. |
| **Yêu cầu rõ ràng về ghi chép nhật ký, thắc mắc** | `/note` | `.agents/notes/YYYY-MM-DD_HHmm-<chủ-đề>.md` | CHỈ ghi file khi có yêu cầu; KHÔNG tự tiện ghi file khi chat hỏi đáp thông thường. |
| **Chốt quyết định kỹ thuật, đóng đề tài** | `/decision` | `.agents/decisions/YYYY-MM-DD_HHmm-<quyết-định>.md` | Quét sạch thắc mắc trong note (Zero-Doubt Closure), khóa ràng buộc bất biến. |
| **Lập kế hoạch, chia giai đoạn, checklist** | `/plan` | `.agents/plans/YYYY-MM-DD_HHmm-plan-<kế-hoạch>.md` | Phân tầng Giai đoạn ➔ Tasks ➔ Multi-Agent Checklist Handshake. |
| **Soạn tài liệu cho người đọc, test tay** | `/doc` | `docs/share/<slug>.md` hoặc `docs/repo/<slug>.md` | Phân nhánh: Share docs (không link repo) vs Repo docs (có link codebase). Chế độ Clean Delivery. |
| **Tạo kỹ năng nội bộ mới cho dự án** | `/writing-yuiskill` | `.agents/skills/writing-yuiskill/SKILL.md` | Tự động sinh `.agents/skills/<tên>/SKILL.md` chuẩn form YAML frontmatter. |
| **Hướng dẫn toàn diện, cố vấn cách dùng YuiKit** | `/helpme-yui` | `skills/helpme-yui/SKILL.md` | Cố vấn trung tâm: chẩn đoán bài toán, trích dẫn quy chuẩn và bàn giao prompt chạy ngay. |
| **Cài đặt hoặc tham chiếu tiện ích vào repo** | `/setup-yuikit` | `.agents/skills/setup-yuikit/SKILL.md` | Mở checklist chọn tiện ích/công cụ/kỹ năng, hợp nhất an toàn vào `AGENTS.md`. |
| **Tối ưu hóa hoặc cập nhật (Local/Global)** | `/optimize-yuikit` | `.agents/skills/optimize-yuikit/SKILL.md` | Tối ưu công cụ, kỹ năng, tiện ích, quy tắc (ghi đè local không record vs update global có record). |
| **Đóng băng & nén ngữ cảnh phiên chat** | `/freeze-conversation` | `.agents/skills/freeze-conversation/SKILL.md` | Đóng băng ngữ cảnh vào `.agents/conversations/YYYY-MM-DD_HHmm-<slug>.md`. |
| **Làm rõ từ ngữ nghiệp vụ mơ hồ** | `/glossary` | `.agents/rules/GLOSSARY.template.md` | Dừng khẩn cấp, phỏng vấn làm rõ 2 chiều, khóa vào từ điển. |
| **Tiết kiệm token, tránh nghẽn context** | `/token` hoặc `/tier` | `.agents/rules/note-management.md` | Định vị bằng Grep/Offset, tránh đọc trọn file > 300 dòng, ghi chép đơn tệp. |

---

## ⚡ Quy Trình Thực Thi Bậc Thang

1. **Xác nhận 1 câu ngắn gọn:** Thông báo cho người dùng biết tiện ích hoặc quy chuẩn nào đang được kích hoạt.
2. **Nạp duy nhất 1 tệp cần thiết:** Chỉ mở tệp tương ứng với công việc đang làm.
3. **Lưu vết trạng thái (chỉ khi có yêu cầu hoặc cột mốc chốt):**
   - Nhật ký ➔ `.agents/notes/YYYY-MM-DD_HHmm-<chủ-đề>.md` (khi người dùng ra lệnh ghi chép)
   - Quyết định ➔ `.agents/decisions/YYYY-MM-DD_HHmm-<quyết-định>.md`
   - Kế hoạch ➔ `.agents/plans/YYYY-MM-DD_HHmm-plan-<kế-hoạch>.md`
   - Tài liệu ➔ `docs/share/<slug>.md` (người ngoài) hoặc `docs/repo/<slug>.md` (nội bộ)
