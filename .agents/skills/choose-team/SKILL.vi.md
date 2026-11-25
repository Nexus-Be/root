---
name: choose-team
description: Kỹ năng chọn nhanh đội ngũ Subagent đang hoạt động trên toàn cục qua giao diện dòng lệnh trong chat, không mở trình duyệt web.
---

# Chọn Đội Ngũ Subagent (`/choose-team`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> **Sổ Bộ Đăng Ký:** [`../../VI_FILES.md`](../../VI_FILES.md)

Cung cấp khả năng tra cứu và chuyển đổi nhanh Đội ngũ Subagent (Active Team) trong tệp cấu hình toàn cục `~/.agent-kityui/teams.json` ngay trong khung chat hoặc terminal. Kỹ năng này hoạt động **hoàn toàn trên giao diện dòng lệnh (CLI), tuyệt đối không mở trình duyệt web**. Để xem và chỉnh sửa trên giao diện đồ họa, sử dụng kỹ năng `/setup-team`.

---

## Các Ranh Giới Bất Biến Bắt Buộc

1. **Ranh Giới Toàn Cục (Global Scope Invariant):** Cấu hình đội ngũ Subagent mang tính toàn cục duy nhất. Mọi cuộc trò chuyện và quy trình trong không gian làm việc đều dùng chung 1 Team Active duy nhất (`active_team_id`). Nghiêm cấm phân chia team riêng theo từng tab chat.
2. **Ưu Tiên Dòng Lệnh:** Không tự ý bật server hay daemon mạng; tương tác chuẩn xác qua `tools/team_manager.py`.

---

## Quy Trình Thực Thi Của Agent

### Bước 1: Tra Cứu Danh Sách Đội Ngũ Hiện Có
Chạy lệnh kiểm tra danh sách qua đường dẫn toàn cục:
```bash
python3 ~/.agent-kityui/tools/team_manager.py list
```
Nếu chưa có team nào, thông báo cho người dùng và gợi ý gõ `/setup-team` để tạo team.

### Bước 2: Xử Lý Khi Có Tham Số Trực Tiếp
Nếu người dùng gõ kèm mã/tên team (ví dụ: `/choose-team team-core-dev`):
1. Chuyển đổi team ngay lập tức:
   ```bash
   python3 ~/.agent-kityui/tools/team_manager.py set-active <team-id>
   ```
2. Báo cáo tên team vừa kích hoạt, thành viên và Nhạc trưởng điều phối.

### Bước 3: Lựa Chọn Tương Tác (Khi Không Có Tham Số)
Nếu người dùng chỉ gõ `/choose-team`:
1. Liệt kê danh sách các team hiện có và đánh dấu team đang là `[ACTIVE]`.
2. Sử dụng `AskQuestion` để người dùng chọn nhanh team mong muốn bằng bảng chọn trắc nghiệm.
3. Kích hoạt lệnh đổi team qua `python3 ~/.agent-kityui/tools/team_manager.py set-active <team-id>` và xác nhận.

### Bước 4: Tóm Tắt Đội Ngũ Đang Hoạt Động
In ra bản tóm tắt gồm:
- Tên & ID Team đang hoạt động.
- Chế độ vận hành (`Multi-Agent` hoặc `Single Main Agent`).
- Subagent được chỉ định làm Lead Orchestrator (hoặc thông báo mặc định Chat Agent làm Nhạc trưởng).
- Danh sách các Subagent với vai trò và model tương ứng (mặc định là `inherit`).
