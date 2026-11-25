---
name: setup-yuikit
description: Quy trình thiết lập tương tác giúp người dùng chọn sử dụng hoặc tải xuống các tiện ích, kỹ năng, công cụ và phôi mẫu YuiKit vào kho dự án đích.
---

# Thiết Lập YuiKit (`/setup-yuikit`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Cài đặt, liên kết sử dụng hoặc tải xuống các tiện ích môi trường làm việc, kỹ năng, công cụ và phôi mẫu chuẩn hóa từ Yui's Agent Kit vào repository hiện tại (hoặc thư mục chỉ định).

---

## Các Bước Thực Hiện Của Agent

### Bước 1: Xác Định Dự Án Đích & Chế Độ Sử Dụng
1. **Đường dẫn đích:** Mặc định là thư mục gốc của repository đang mở (`.`), hoặc đường dẫn do người dùng chỉ định.
2. **Kiểm tra cấu hình hiện có:** Kiểm tra xem `AGENTS.md` (hoặc `AGENT.md`) đã tồn tại chưa.
3. **Chế độ Sử dụng vs Tải xuống:**
   - **Chế độ Sử dụng (Reference):** Nếu người dùng chỉ muốn tham chiếu tiện ích toàn cục mà không sao chép toàn bộ tệp, cấu hình liên kết điều hướng trực tiếp trong `AGENTS.md`.
   - **Chế độ Tải xuống (Download / Provision - Mặc định):** Sao chép các tệp quy chuẩn sạch (`compiled.md`), phôi mẫu và công cụ trực tiếp vào thư mục `.agents/` của dự án đích.

---

### Bước 2: Hiển Thị Danh Mục Tài Sản Không Gian Làm Việc
Hiển thị checklist tương tác để người dùng chọn những tài sản muốn cài đặt hoặc tham chiếu:

#### A. Các Cấu Hình Đóng Gói Sẵn (Presets)
- **Cấu hình 1: Toàn Bộ Không Gian Làm Việc (Full - 16 gói)**
  - Đầy đủ 8 Tiện ích Môi trường (`note`, `decision`, `doc`, `plan`, `skill`, `context`, `conversation`, `rule`).
  - Toàn bộ Phôi mẫu khởi tạo (`notes`, `decisions`, `plans`, `glossary`, `spec-kit`).
  - Các Kỹ năng thiết yếu (`setup-yuikit`, `optimize-yuikit`, `writing-yuiskill`, `freeze-conversation`, `yui-router`).
  - Các Công cụ tự động hóa (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`).
- **Cấu hình 2: Tiện Ích Môi Trường Cốt Lõi (Core - 14 gói)**
  - Các tiện ích vận hành thiết yếu (bỏ qua quy tắc thử nghiệm).
  - Phôi mẫu tiêu chuẩn và các kỹ năng hệ thống.
- **Cấu hình 3: Tiết Kiệm Token (Lean - 9 gói)**
  - Tối ưu hóa dung lượng token (`note`, `decision`, `plan`, `context`, `conversation`, router, phôi mẫu).

#### B. Tùy Chọn Từng Thành Phần Cụ Thể (Custom Selection)
Người dùng có thể chọn riêng lẻ từng mục theo danh mục:
- **Tiện ích môi trường (`core-utilities/`):** `note/`, `decision/`, `doc/`, `plan/`, `skill/`, `context/`, `conversation/`, `rule/`.
- **Kỹ năng hệ thống (`skills/`):** `setup-yuikit/`, `optimize-yuikit/`, `writing-yuiskill/`, `freeze-conversation/`, `yui-router/`.
- **Công cụ tự động hóa (`tools/`):** `init-repo.sh`, `agent-pack.sh`, `compile-component.py`.
- **Phôi mẫu khởi tạo (`core-utilities/template/`):** Notes, Decisions, Plans, Glossary, Spec-Kit.

---

### Bước 3: Tự Động Khởi Tạo Thư Mục Số Nhiều Trong `.agents/`
Chạy công cụ cài đặt hoặc thực thi trực tiếp:
```bash
bash tools/init-repo.sh /path/to/target --preset full
```
*(Nếu gọi ngoài thư mục plugin, gọi theo đường dẫn cài đặt plugin hoặc `bash ~/.agent-kityui/tools/init-repo.sh`)*

**Cơ chế tự động khởi tạo thư mục đích:**
Script tự động tạo đầy đủ các thư mục số nhiều trong `.agents/` cho repo đích:
1. `.agents/notes/` — Bàn làm việc Agent, nhật ký phiên đơn tệp, thắc mắc dở dang.
2. `.agents/decisions/` — Văn bản quyết định kiến trúc bất biến & Zero-Doubt Closure.
3. `.agents/plans/` — Kế hoạch phân tầng & cổng kiểm tra Multi-Agent Checklist Handshake.
4. `.agents/contexts/` — Ngữ cảnh nghiệp vụ & bộ nạp tự động 7 Header SRS.
5. `.agents/conversations/` — Nơi lưu trữ ngữ cảnh các phiên chat đã đóng băng.
6. `.agents/skills/` — Nơi chứa các kỹ năng nội bộ của riêng dự án.
7. `.agents/rules/` — Nơi chứa các quy chuẩn đang kích hoạt được sao chép sạch sẽ từ YuiKit.
8. `docs/` — Tài liệu cho con người đọc, sơ đồ kiến trúc và kịch bản test tay.

> **Cam kết sạch sẽ của Plugin Repo:**
> Repo plugin (`agent-kityui`) không chứa sẵn các thư mục rỗng `records/`. Mọi thư mục làm việc đều được tạo động và tự động tại repo đích khi setup.

**Sao chép tài sản & Tạo danh mục:**
1. Chỉ sao chép tệp `compiled.md` sạch làm quy chuẩn kích hoạt trong `.agents/rules/`.
2. Sao chép phôi mẫu tương ứng vào các thư mục làm việc.
3. Bảo toàn tuyệt đối các tệp phôi mẫu cũ của người dùng (không bao giờ ghi đè phôi mẫu đã có).
4. Tự động sinh `.agents/catalog.json` và `.agents/CATALOG.md` lập chỉ mục các tiện ích đã cài.

---

### Bước 4: Hợp Nhất An Toàn Vào `AGENTS.md`
- **Nếu `AGENTS.md` chưa tồn tại:** Tạo mới tệp với khối harness YuiKit.
- **Nếu `AGENTS.md` đã có thẻ đánh dấu:** Chỉ cập nhật nội dung nằm giữa `<!-- YUI-AGENT-KIT:START -->` và `<!-- YUI-AGENT-KIT:END -->`.
- **Nếu `AGENTS.md` đã có nội dung nhưng chưa có thẻ:** Nối khối harness vào cuối tệp sau dấu phân cách `---`. Giữ nguyên 100% quy tắc riêng của người dùng.

---

### Bước 5: Kiểm Tra & Báo Cáo Nghiệm Thu
1. Xác nhận có đúng 1 khối đánh dấu trong `AGENTS.md`.
2. Kiểm tra toàn bộ liên kết Markdown trong `.agents/CATALOG.md` đều trỏ tới tệp tồn tại thực tế.
3. Báo cáo bảng tóm tắt súc tích cho người dùng.
