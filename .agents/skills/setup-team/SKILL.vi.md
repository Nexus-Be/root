---
name: setup-team
description: Khởi chạy Web Server cục bộ tại cổng 56123 ở chế độ nền và mở giao diện Web Dashboard quản lý trực quan đội ngũ Subagent.
---

# Thiết Lập Đội Ngũ Subagent Qua Web UI (`/setup-team`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> **Sổ Bộ Đăng Ký:** [`../../VI_FILES.md`](../../VI_FILES.md)

Khởi chạy và kết nối tới giao diện đồ họa Web Dashboard quản lý đội ngũ Subagent tại cổng cục bộ `56123`. Kỹ năng này đảm bảo server chạy ở chế độ daemon nền phi chặn (không gây treo terminal) và cung cấp giao diện trực quan để người dùng cấu hình team, bật tắt chế độ Multi-Agent vs Single Agent, phân quyền Nhạc trưởng (Lead Orchestrator), thêm chỉ dẫn cho vai trò và chọn Active Team.

---

## Các Ranh Giới Bất Biến Bắt Buộc

1. **Khởi Chạy Nền Phi Chặn (Chống Treo Terminal):** Web server bắt buộc phải được kiểm tra qua cờ `--check` và khởi động qua `--daemon`. Tuyệt đối cấm Agent chạy lệnh foreground gây timeout 30 giây của IDE.
2. **Nguyên Tắc Tái Sử Dụng Server (Không Chạy Trùng Lặp):** Nếu server đã đang chạy trên cổng 56123, Agent **tuyệt đối không chạy thêm, không spawn tiến trình mới**. Chỉ hiển thị thông báo và trả link để người dùng mở trực tiếp.
3. **Cố Định Localhost:** Server chỉ bind vào `127.0.0.1:56123`, ngăn chặn hoàn toàn truy cập từ mạng LAN văn phòng.
4. **Duy Nhất 1 Active Team Toàn Cục:** Mọi thay đổi trên Web UI được lưu nguyên tử về `~/.agent-kityui/teams.json` và áp dụng cho toàn bộ không gian làm việc.

---

## Quy Trình Thực Thi Của Agent

### Bước 1: Kiểm Tra Trạng Thái Server
Chạy lệnh kiểm tra tính lũy đẳng qua đường dẫn toàn cục:
```bash
python3 ~/.agent-kityui/tools/team-server.py --check
```
- Nếu trả về mã 0 (server đã đang chạy): **Không chạy thêm**, chuyển ngay sang Bước 3.
- Nếu trả về mã khác 0 (server chưa chạy): Chuyển sang Bước 2.

### Bước 2: Khởi Động Daemon Chạy Nền
Kích hoạt tiến trình nền:
```bash
python3 ~/.agent-kityui/tools/team-server.py --daemon
```
Lệnh tự tách tiến trình, đóng các luồng I/O và trả về quyền điều khiển ngay sau < 500ms mà không làm gián đoạn phiên chat.

### Bước 3: Cung Cấp Liên Kết Truy Cập & Hướng Dẫn
In ra đường dẫn Markdown nổi bật cho người dùng:
👉 **[Mở Web Dashboard Quản Lý Subagent Team (http://localhost:56123)](http://localhost:56123)**

Tóm tắt các tính năng chính trên Web Dashboard:
- **⚙️ Nút Gạt Multi-Agent vs Single Agent:** Bật/tắt linh hoạt giữa ủy thác cho các Subagent hoặc để duy nhất Main Agent tự làm để giữ đồng nhất phong cách code.
- **⚡ Nút 1-Click "Auto-fill Core Roster":** Tự động điền 3 vị trí worker cốt lõi (`Builder Coder`, `Bug Hunter`, `Zero-Doubt Auditor`) với `model: inherit`. Lead Orchestrator mặc định là Chat Agent.
- **👑 Tùy Chọn Chỉ Định Orchestrator Riêng:** Có thể tự thêm vai trò `Lead Orchestrator` vào team nếu muốn gán một model tư duy riêng biệt khác với model khung chat.
- **🛡️ Tách Bạch Mô Tả Chuẩn & Bổ Sung:** Khóa cứng `base_description` để giữ nguyên chuẩn mực TDD; cho phép thêm chỉ dẫn dự án trong ô `extra_description`.
- **⭐ Nút Đặt Active Team:** 1 click để kích hoạt team dùng chung cho mọi workflow.
- **💾 Lưu Thay Đổi:** Ghi file nguyên tử (Atomic Write) bảo đảm an toàn dữ liệu.
