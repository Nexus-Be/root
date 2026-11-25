---
name: your-desire
description: Kỹ năng Master khởi động ý định của người dùng với 4 tọa độ (Quy mô, Mục tiêu, Phạm vi, Nghiệm thu), tự động thế vai linh hoạt và chốt chặn Proof-of-Work.
---

# Khởi Động Ý Định Cùng Subagent Team (`/your-desire`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> **Sổ Bộ Đăng Ký:** [`../../VI_FILES.md`](../../VI_FILES.md)

Cổng tiếp nhận ý định tác nghiệp chính thức để khởi động và điều phối nhiệm vụ thông qua Đội ngũ Subagent đang hoạt động. Kỹ năng này thu thập 4 tọa độ chuẩn (Quy mô, Mục tiêu, Phạm vi, Tiêu chí nghiệm thu), mở bản kế hoạch phân tầng, ủy quyền cho các subagent chuyên trách (hoặc tự động thế vai nếu thiếu) và áp đặt cổng kiểm định bằng chứng thực thi (Proof-of-Work) trước khi đóng việc.

---

## Các Ranh Giới Bất Biến Bắt Buộc

1. **Cổng Kiểm Định Proof-of-Work:** Tuyệt đối không tích `[x]` dựa trên lời nói suông hoặc giả định "code biên dịch được". Bắt buộc phải có output log terminal kiểm thử thật pass.
2. **Giao Thức Bắt Tay Đa Agent (Multi-Agent Checklist Handshake):** Các subagent chỉ báo cáo kết quả và con trỏ tệp; duy nhất Nhạc trưởng (Lead Orchestrator) mới có quyền tích `[x]` vào checklist kế hoạch.
3. **Cơ Chế Tự Thế Vai Linh Hoạt (Graceful Self-Execution Fallback):** Nếu Active Team thiếu bất kỳ vị trí nào (như Coder hoặc Auditor), Chat Agent trong khung chat sẽ tự động đảm nhiệm vai trò đó và đánh dấu nhãn `[Self-Executed: <Vai-Trò>]`.
4. **Chống Lệch Phong Cách Mã Nguồn (Execution Mode):** Khi team được bật cờ `single_agent`, Chat Agent tự mình thực thi tuần tự từ đầu đến cuối, không gọi subagent để bảo đảm 100% mã nguồn đồng nhất phong cách.
5. **Đóng Chủ Đề Zero-Doubt:** Trước khi nghiệm thu, bắt buộc phải giải quyết sạch mọi thắc mắc dở dang trong `.agents/notes/`.

---

## Quy Trình Điều Phối Của Lead Orchestrator

### Bước 1: Tiếp Nhận 4 Tọa Độ (Intake Framing)
Làm rõ hoặc xác nhận 4 tọa độ từ người dùng:
1. **Quy mô (Scale):**
   - `Nhỏ`: 1-3 tệp, sửa lỗi cô lập, điều chỉnh cục bộ.
   - `Vừa`: Xây dựng một tính năng, tái cấu trúc component, viết test tích hợp.
   - `Lớn`: Kiến trúc xuyên suốt, di chuyển dữ liệu lớn, triển khai đa phase.
2. **Mục tiêu (Goal):** Giá trị cốt lõi cần đạt được hoặc lỗi cần loại bỏ.
3. **Phạm vi (Scope):** Danh sách tệp được phép chạm, các ranh giới cấm đụng tới.
4. **Nghiệm thu (Acceptance Criteria):** Lệnh kiểm thử hoặc điều kiện thực nghiệm bắt buộc pass.

### Bước 2: Kiểm Tra Active Team & Chế Độ Vận Hành
Đọc cấu hình đội ngũ đang hoạt động qua đường dẫn toàn cục:
```bash
python3 ~/.agent-kityui/tools/team_manager.py active
```
Kiểm tra cờ `execution_mode` (`multi_agent` vs `single_agent`), vị trí Nhạc trưởng và danh sách các subagent thành viên.

### Bước 3: Khởi Tạo Lộ Trình Kế Hoạch
Tạo tệp kế hoạch chuẩn `.agents/plans/YYYY-MM-DD_HHmm-plan-<tên-chủ-đề>.md` gồm:
- Tiêu đề, Mốc thời gian, Mục tiêu, 4 Tọa độ.
- Kiến trúc & Mô hình dữ liệu: Định nghĩa kiểu dữ liệu, interface và máy trạng thái trước.
- Các Lát Cắt Dọc: Phân chia các giai đoạn độc lập kèm lệnh kiểm thử riêng biệt.

### Bước 4: Vòng Lặp Điều Phối & Thực Thi
Tùy theo `execution_mode`:
- **Chế độ Single Agent (`single_agent`):**
  Chat Agent tự thực thi tuần tự: Viết test lỗi trước $\rightarrow$ Viết code lát cắt $\rightarrow$ Kiểm thử pass $\rightarrow$ Lát cắt kế.
- **Chế độ Multi-Agent (`multi_agent`):**
  Orchestrator phân công cho các subagent qua `Task`:
  - **Ghép Prompt Tự Động:** `base_description` + `extra_description` + mission brief.
  - **Builder Coder:** Viết mã lát cắt dọc theo TDD (hoặc Chat Agent tự làm nếu thiếu).
  - **Zero-Doubt Auditor:** Kiểm thử phản biện đối nghịch và bắt lỗi biên (hoặc Chat Agent tự làm nếu thiếu).

### Bước 5: Thẩm Định Nghiệm Thu & Đóng Zero-Doubt
1. Orchestrator tự tay chạy lại lệnh kiểm thử độc lập để kiểm chứng kết quả.
2. Tích `[x]` vào các hạng mục đã vượt qua kiểm thử.
3. Rà soát `.agents/notes/`, bảo đảm 0 thắc mắc dở dang.
4. Báo cáo kết quả hoàn tất kèm bằng chứng thực nghiệm rõ ràng cho người dùng.
