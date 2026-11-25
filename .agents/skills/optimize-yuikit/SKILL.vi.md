---
name: optimize-yuikit
description: Quy trình tối ưu hóa và cập nhật tiện ích, kỹ năng, công cụ hoặc quy tắc YuiKit. Hỗ trợ tùy biến cục bộ (Local) không sinh record và cập nhật toàn cục (Global) qua sổ cái records và biên dịch tự động.
---

# Tối Ưu Hóa YuiKit (`/optimize-yuikit`)
> **Tệp Gốc Tiếng Anh:** [`SKILL.md`](SKILL.md)  
> *(Tệp đối chiếu tiếng Việt dùng cho bạn đọc duyệt)*

Hướng dẫn người dùng tùy biến, tối ưu hóa hoặc cập nhật bất kỳ tài sản nào trong Yui's Agent Kit (Công cụ, Kỹ năng, Tiện ích, hoặc Quy tắc) theo hai phạm vi rõ ràng: **Cục bộ (Local - chỉ repo hiện tại)** và **Toàn cục (Global - cập nhật trực tiếp vào Plugin)**.

---

## Kiến Trúc Thành Phần & Sự Khác Biệt Cấu Trúc

Trước khi tiến hành tối ưu hóa, Agent bắt buộc phải nhận diện đặc thù cấu trúc của từng loại tài sản:

| Loại Tài Sản | Cấu Trúc Thành Phần Tiêu Chuẩn | Quy Tắc Xử Lý Riêng |
| :--- | :--- | :--- |
| **Tiện ích cốt lõi (`core-utilities/`)** | `default.md`, `template.md`, `compiled.md`, `records/` (tạo theo nhu cầu) | Đầy đủ thành phần component, định hướng bởi `template.md`. |
| **Quy chuẩn lập trình (`core-utilities/rule/`)** | `default.md`, `template.md`, `compiled.md`, `records/` (tạo theo nhu cầu) | Đang trong giai đoạn thử nghiệm ý tưởng. |
| **Công cụ tự động (`tools/`)** | Các script thực thi (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`) | Đòn bẩy tự động hóa. |
| **Kỹ năng hệ thống (`skills/`)** | **DUY NHẤT `SKILL.md`** (+ companion `SKILL.vi.md` nếu có) | **KHÔNG CÓ `template.md`, KHÔNG CÓ `records/`, KHÔNG CÓ `default.md`, KHÔNG CÓ `compiled.md`**. Chỉ là tệp định nghĩa kỹ năng độc lập. |

---

## Các Bước Thực Hiện Của Agent

### Bước 1: Xác Định Loại Tài Sản & Mục Tiêu Cần Tối Ưu
Lắng nghe hoặc hỏi người dùng muốn tối ưu hóa thành phần nào:
1. **Tool (Công cụ):** Các script tự động (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`).
2. **Skill (Kỹ năng):** Định nghĩa kỹ năng Agent (`setup-yuikit`, `writing-yuiskill`, `freeze-conversation`, `yui-router`, hoặc skill riêng của dự án).
3. **Core Utility (Tiện ích):** Các phân hệ môi trường (`note`, `decision`, `doc`, `plan`, `context`, `conversation`).
4. **Rule (Quy chuẩn):** Tiêu chuẩn kỹ thuật lập trình (`rule`).

---

### Bước 2: Xác Định Phạm Vi Cập Nhật (Local vs Global)

Người dùng có thể chỉ định rõ bản cập nhật áp dụng cho **Cục bộ (Local - chỉ riêng repo hiện tại)** hay **Toàn cục (Global - cập nhật vào bộ plugin gốc)**:

```
[ Người dùng yêu cầu tối ưu hóa / update ]
                    │
                    ├── Nếu là SKILL ───────► Luôn là LOCAL cho repo hiện tại (.agents/skills/<name>/SKILL.md)
                    │
                    └── Nếu là Tiện ích / Công cụ / Quy chuẩn
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
            [ Phạm vi LOCAL ]           [ Phạm vi GLOBAL ]
      (Mặc định khi làm trên repo) (Chỉ khi người dùng yêu cầu rõ)
                    │                           │
         - Đọc chỉ dẫn template.md   - Tự động tạo thư mục records/
         - KHÔNG tạo record          - Tạo tệp YYYY-MM-DD-XX-<slug>.md
         - Ghi đè trực tiếp vào repo - Chạy compile-component.py
           đích tại .agents/rules/   - Cập nhật compiled.md vào plugin gốc
```

---

### Bước 3: Luồng Xử Lý Theo Từng Trường Hợp

#### Nhánh A: Tối ưu hóa SKILL (Luôn luôn là Local)
- **Đặc thù của Skill:** Kỹ năng **KHÔNG CÓ** template, không có record, không có compiled.
- **Hành động:** Tạo mới hoặc chỉnh sửa trực tiếp tệp kỹ năng tại `.agents/skills/<tên-skill>/SKILL.md` trong repo hiện tại của người dùng.
- **Tính cô lập:** Thay đổi chỉ áp dụng cho riêng dự án đó. Kho plugin gốc hoàn toàn không bị ảnh hưởng.

#### Nhánh B: Tối ưu hóa Tiện ích / Quy tắc / Công cụ — CỤC BỘ (LOCAL - Mặc định)
Khi người dùng tùy biến cho riêng dự án đang làm việc:
1. **Đọc chỉ dẫn từ Template:** Đọc `template.md` trong `core-utilities/<thành-phần>/` để nắm rõ **Điểm an toàn (Safe Levers)** và **Ràng buộc bất biến (Invariants)** để tư vấn cho người dùng.
2. **Không tạo Record:** **TUYỆT ĐỐI KHÔNG** tạo thư mục `records/` và không tạo file record trong repo này.
3. **Ghi đè trực tiếp tại repo đích:** Soạn thảo bản mới và lưu ghi đè trực tiếp vào tệp tương ứng trong repo hiện tại (ví dụ: `.agents/rules/<thành-phần>-management.md`).
4. **Bảo toàn Plugin gốc:** Kho plugin toàn cục (`agent-kityui`) không lưu vết và không thay đổi bất kỳ tệp nào.

#### Nhánh C: Tối ưu hóa Tiện ích / Quy tắc / Công cụ — TOÀN CỤC (GLOBAL - Cập nhật Plugin)
Chỉ kích hoạt khi người dùng **yêu cầu rõ ràng** là muốn cập nhật toàn cục vào chính bộ plugin `agent-kityui`:
1. **Tự động tạo thư mục `records/` theo nhu cầu (on-demand):**
   ```bash
   mkdir -p core-utilities/<thành-phần>/records
   ```
2. **Soạn thảo tệp bản ghi ghi đè:** Tạo tệp bản ghi tại:
   `core-utilities/<thành-phần>/records/YYYY-MM-DD-XX-<slug>.md`
3. **Kích hoạt đòn bẩy biên dịch:**
   ```bash
   python3 tools/compile-component.py <thành-phần>
   ```
   *(Hoặc qua `python3 ~/.agent-kityui/tools/compile-component.py <thành-phần>` nếu chạy ngoài repo)*
4. **Kiểm tra kết quả biên dịch:** Xác nhận `compiled.md` được cập nhật sạch sẽ, đồng bộ làm chuẩn xuất xưởng mới.

---

### Bước 4: Kiểm Tra Toàn Vẹn & Báo Cáo
1. Kiểm tra cú pháp và tính toàn vẹn liên kết của tệp vừa cập nhật.
2. Nếu có tệp tiếng Việt đối chiếu (`*.vi.md`) đi kèm, cập nhật đồng bộ và đăng ký vào `VI_FILES.md`.
3. Báo cáo rõ ràng đường dẫn tệp đã cập nhật và phạm vi áp dụng (Local hay Global) cho người dùng.
