---
name: helpme-yui
description: Kỹ năng điều hướng và trợ giúp trung tâm của Yui Agent Kit (YuiKit). Phân tích bài toán của người dùng, ánh xạ đến đúng tiện ích, kỹ năng, công cụ hoặc playbook phù hợp và cung cấp prompt chạy ngay. Dùng khi gõ /helpme-yui, "helpme yui", "hướng dẫn yuikit".
---

# Hướng Dẫn & Điều Hướng YuiKit (`/helpme-yui`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Giải đáp các thắc mắc về cách sử dụng Yui Agent Kit (`agent-kityui`), chẩn đoán vấn đề kỹ thuật người dùng đang gặp phải, chỉ dẫn chính xác tệp quy chuẩn nguồn và cung cấp sẵn câu lệnh hoặc prompt hoàn chỉnh để người dùng kích hoạt ngay.

---

## Các Nguyên Tắc Bất Biến

1. **Ranh giới tư vấn (Không tự ý thực thi sớm):**  
   Khi được gọi qua `/helpme-yui` hoặc khi người dùng đặt câu hỏi tư vấn (ví dụ: *"làm sao để làm việc X trong YuiKit?"*), Agent **tuyệt đối không** tự ý sửa mã nguồn, không tạo branch git hay khởi chạy các tác vụ nặng. Agent đóng vai trò cố vấn kiến trúc, chỉ cung cấp phương án và prompt chuẩn để người dùng chủ động ra lệnh.
2. **Dẫn link nguồn chính xác:**  
   Mọi lời khuyên đều phải gắn liền với đường dẫn tệp quy chuẩn cụ thể (ví dụ: `core-utilities/workflow/compiled.md#1-feature-playbook` hoặc `skills/your-desire/SKILL.md`).
3. **Bàn giao prompt sẵn sàng thực thi:**  
   Cuối mỗi phần hướng dẫn, Agent luôn cung cấp một khung prompt hoàn chỉnh để người dùng có thể gửi ngay vào chat.

---

## 🧭 5 Tuyến Hướng Dẫn Trọng Tâm

Khi người dùng đặt câu hỏi, Agent phân loại nhu cầu vào 1 trong 5 tuyến sau:

### Tuyến 1: Bắt đầu tác vụ lập trình (Feature, Bug, Refactoring)
- **Điểm vào chính:** `/your-desire` (`skills/your-desire/SKILL.md`)
- **Cơ chế bóc tách 4 tọa độ intake:**
  1. **Scale (Quy mô):** `Small` (1-3 file), `Medium` (lát cắt tính năng/module), `Large` (nhiều giai đoạn/toàn hệ thống).
  2. **Goal (Mục tiêu):** Trạng thái hoàn thành cụ thể, đo lường được.
  3. **Scope (Ranh giới):** Danh sách tệp được phép sửa; cấm sửa ngoài phạm vi.
  4. **Acceptance (Tiêu chuẩn nghiệm thu):** Điều kiện kiểm chứng tất định bằng lệnh chạy thật (Exit Code 0).
- **Bộ ba Playbook kỹ sư (`core-utilities/workflow/compiled.md`):**
  - **Tính năng mới (Feature):** Thiết kế Domain trước ➔ Viết test fail trước (TDD Red) ➔ Lát cắt dọc (Green) ➔ Bằng chứng thực tế (Proof-of-Work).
  - **Sửa lỗi (Bug Fix):** Bằng chứng runtime ➔ Viết bài test tái hiện lỗi trước ➔ Tìm nhị phân nguyên nhân gốc ➔ Sửa phẫu thuật tối thiểu ➔ Chứng minh không hồi quy.
  - **Tái cấu trúc (Refactoring):** Khóa hợp đồng bằng test ➔ Xóa bỏ phần thừa trước (Subtract first) ➔ Các bước nguyên tử ➔ Rà soát lan truyền không vỡ link.
- **Mẫu prompt gửi ngay:**
  ```text
  /your-desire
  Goal: <nêu rõ mục tiêu cần làm hoặc lỗi cần sửa>
  Scale: <Small | Medium | Large>
  Scope: <danh sách tệp hoặc thư mục mục tiêu>
  Acceptance: <lệnh kiểm thử hoặc tiêu chí nghiệm thu Exit Code 0>
  ```

---

### Tuyến 2: Quản lý & Cấu hình Đội Ngũ Subagents
- **Tệp cấu hình toàn cục:** `~/.agent-kityui/teams.json`
- **Giao diện Web Dashboard:** `/setup-team` (`skills/setup-team/SKILL.md`)
  - Chạy máy chủ daemon nền tại `http://localhost:56123`.
  - Quản lý danh sách đội ngũ, phân vai Trưởng nhóm điều phối và tùy biến chỉ dẫn cho từng vai trò.
- **Chuyển đội ngũ nhanh qua CLI:** `/choose-team` (`skills/choose-team/SKILL.md`)
  - Chọn nhanh đội ngũ hoạt động ngay trong chat mà không cần mở trình duyệt.
- **Chế độ vận hành:**
  - `multi_agent`: Trưởng nhóm tự động phân chia công việc cho các subagent chuyên trách (`Builder Coder`, `Bug Hunter`, `Zero-Doubt Auditor`).
  - `single_agent`: Agent chính tự thực hiện toàn bộ quy trình tuần tự, tránh tình trạng lệch phong cách code giữa các subagent.
- **Tự động thế vai linh hoạt (Dynamic Role Substitution):** Nếu đội ngũ thiếu một vai trò cần thiết, Agent chính tự giác đảm nhiệm vai trò đó và đánh dấu log rõ ràng: `[Self-Executed: <Vai trò>]`.

---

### Tuyến 3: Không Gian Làm Việc, Ghi Chép, Quyết Định & Tài Liệu
- **Bàn làm việc & Lưu trữ thắc mắc tạm thời:** `.agents/notes/YYYY-MM-DD_HHmm-<chủ-đề>.md`  
  *Nguyên tắc:* Mỗi chủ đề duy nhất 1 tệp note. Lưu các nghi vấn chưa giải quyết (Pending Doubts). Không tự ý tạo note cho các câu hỏi ngắn thông thường.
- **Chốt quyết định bất biến:** `.agents/decisions/YYYY-MM-DD_HHmm-<quyết-định>.md`  
  *Nguyên tắc:* Đóng chủ đề Zero-Doubt. Phải giải quyết sạch sẽ 100% thắc mắc trong note mới được lưu quyết định chốt.
- **Kế hoạch & Bàn giao đa Agent:** `.agents/plans/YYYY-MM-DD_HHmm-plan-<kế-hoạch>.md`  
  *Nguyên tắc:* Phân tầng Giai đoạn ➔ Tác vụ ➔ Checklist. Chỉ agent tổng hợp cuối cùng mới được đánh dấu `[x]`.
- **Phân hệ tài liệu hai nhánh (`core-utilities/doc/compiled.md`):**
  - `docs/share/<tên-file>.md`: Dành cho người không có repo. Tự đầy đủ, văn phong bình dị, cấm dùng link mã nguồn nội bộ.
  - `docs/repo/<tên-file>.md`: Dành cho thành viên dự án. Khuyến khích dẫn link trực tiếp tới file và hàm trong codebase.
  - *Chế độ làm sạch (Clean Mode):* Xóa sạch các mốc thời gian nội bộ, dòng suy nghĩ nháp và nhãn audit của AI.
- **Ngữ cảnh nghiệp vụ dự án:** `.agents/contexts/business-context.md` (nạp tự động theo 7 Header SRS).

---

### Tuyến 4: Mở Rộng & Cài Đặt Hệ Thống Harness
- **Cài đặt tiện ích vào repo đích:** `/setup-yuikit` (`skills/setup-yuikit/SKILL.md`)
  - Hỗ trợ các gói cài đặt sẵn: `full` (16 gói), `core` (14 gói), `lean` (9 gói).
  - Tích hợp mỏ neo an toàn vào `AGENTS.md` mà không làm hỏng chỉ dẫn cũ của dự án.
- **Tạo kỹ năng mới cho dự án:** `/writing-yuiskill` (`skills/writing-yuiskill/SKILL.md`)
  - Sinh thư mục `.agents/skills/<tên-skill>/SKILL.md` chuẩn form YAML frontmatter.
- **Tối ưu & Cập nhật tiện ích:** `/optimize-yuikit` (`skills/optimize-yuikit/SKILL.md`)
  - Phân định rõ thay đổi Local (chỉ repo này) và Global (toàn cục qua sổ cái `records/`).
- **Nén & Đóng băng phiên trò chuyện dài:** `/freeze-conversation` (`skills/freeze-conversation/SKILL.md`)
  - Nén ngữ cảnh hội thoại vào `.agents/conversations/` để chuyển giao phiên làm việc không mất dữ liệu.

---

### Tuyến 5: Xử Lý Sự Cố Thường Gặp Của Agent
| Hiện tượng sự cố | Nguyên nhân gốc rễ | Giải pháp chuẩn của YuiKit |
| :--- | :--- | :--- |
| **Agent bị crash hoặc tràn ngữ cảnh** | Đổ toàn bộ log terminal hoặc nội dung file lớn vào chat chính | Dùng con trỏ tệp ngắn gọn (`.agents/notes/`, `.agents/plans/`) và ủy quyền tác vụ nặng cho subagent. |
| **Agent dừng lại đột ngột (`turn_ended`)** | Kết thúc lượt bằng câu hỏi xin phép hoặc chỉ gọi tool rỗng | Ra lệnh hành động trực tiếp; Agent tự chủ thực hiện các bước có thể hoàn tác. |
| **Checklist bị tích `[x]` bừa bãi** | Báo cáo cảm tính khi chưa chạy thử nghiệm thật | Áp dụng chốt chặn Proof-of-Work: bắt buộc có output lệnh test đạt Exit Code 0 mới được hoàn tất. |
| **Mã nguồn bị lệch phong cách giữa các file** | Các subagent hoạt động thiếu quy chuẩn đồng bộ | Chuyển chế độ sang `single_agent` hoặc bổ sung chỉ dẫn bổ sung vào `teams.json`. |

---

## ⚡ Mẫu Phản Hồi Tư Vấn Chuẩn

Khi người dùng gọi `/helpme-yui`, Agent luôn trình bày câu trả lời theo 3 phần mạch lạc:

1. **Chẩn đoán & Phương án phù hợp:** Nêu rõ công cụ, tiện ích hoặc playbook nên dùng và giải thích lý do ngắn gọn.
2. **Tọa độ tài liệu tham chiếu:** Trích dẫn đường dẫn tệp quy chuẩn gốc tương ứng.
3. **Mẫu prompt gửi ngay:** Soạn sẵn khung lệnh để người dùng copy hoặc kích hoạt lập tức.
