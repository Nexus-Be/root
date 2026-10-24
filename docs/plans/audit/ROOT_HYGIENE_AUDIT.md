# AUDIT — Vệ sinh repo & tái lập (branch, dirty, file lạc, submodule)

**Câu hỏi:** có thể `git clone` rồi dựng lại **đúng** hệ thống đang chạy không?

## 0. Kết luận

**Chưa.** Máy hiện tại chạy được nhưng **git không mô tả được** trạng thái đó:

- 8 service làm trên `dev`, Gateway làm trên `mock`; `.gitmodules` không ghi `branch` → `git submodule update` sẽ lấy **default branch** (không phải `dev`/`mock`), tức là **không tái lập được** hệ thống.
- 9/9 repo **dirty**. Trong đó 18 file `M` là do GitNexus tự sinh (`AGENTS.md`, `CLAUDE.md` ở mỗi repo), còn lại là **migration regenerated chưa commit** ở 8 repo — nghĩa là schema DB đúng hiện tại chỉ tồn tại trên đĩa, không tồn tại trong git.
- Repo `ApiGateway` **không ở cấu trúc chuẩn**: 6 file doc lạc + `global.json` + 2 script `run-dev` nằm ở root repo, trong khi 8 service khác không có.

## 1. Branch & submodule

| Repo | Branch | Commit | Ghi chú |
|---|---|---|---|
| (root) | `dev` | `eec78ce` | |
| ApiGateway | **`mock`** | `efb840d` | lệch nhánh so với 8 repo còn lại |
| Auction | `dev` | `37895fa` | |
| Catalog | `dev` | `4c74107` | |
| Commerce | `dev` | `44616e1` | |
| Fulfillment | `dev` | `1702ffc` | |
| Log | `dev` | `6dcc1d8` | |
| Notification | `dev` | `4d8e46d` | |
| User | `dev` | `f65d2f1` | |
| Wallet | `dev` | `4ab32a0` | |

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| HY-01 | **P1** | `.gitmodules` không có `branch` → không tái lập được | 9 mục, không mục nào có `branch =` | Thêm `branch = dev` (và `mock` cho Gateway) **sau khi** thống nhất nhánh |
| HY-02 | **P0** | Migration regenerated **chưa commit** ở 8 repo → clone mới sẽ không tạo được schema | mỗi repo: file cũ `D`, snapshot `M`, file mới `??` | Commit theo quy trình review schema; hoặc revert và tạo migration mới có lịch sử |
| HY-03 | **P1** | `AGENTS.md`/`CLAUDE.md` bị tool sửa (symbol count) ở 9 repo → nhiễu dirty | `M AGENTS.md`, `M CLAUDE.md` cả 9 repo | Tách block GitNexus ra file riêng (`.gitnexus/AGENTS.block.md`) hoặc chấp nhận và commit 1 lần |

## 2. Trạng thái dirty

| Repo | Số file dirty | Nội dung |
|---|---|---|
| ApiGateway | 2 | `AGENTS.md`, `CLAUDE.md` (tool sinh) |
| Auction / Catalog / Commerce / Fulfillment / Log / Notification / Wallet | 9 mỗi repo | 2 tool + 3 `D` (migration cũ) + 1 snapshot `M` + 2 `??` (migration mới) + 1–2 seed/DbContext `M` |
| User | 12 | như trên + 3 migration cũ (6 file `D`) |

## 3. File lạc & cấu trúc không đồng nhất

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| HY-04 | **P1** | `ApiGateway` có 6 doc lạc ở root repo (`ADR.md`, `PLAN.md`, `dac_ta.md`, `input.md`, `CONFIG_REFERENCE.md`, `SETUP_GUIDE_SERVICES.md`) — 8 repo khác không có | `ls src/Services/ApiGateway` | Chuyển vào `specs/` hoặc `docs/`, xoá `input.md`/`dac_ta.md` (bản nháp) |
| HY-05 | **P2** | `run-dev.sh`, `run-dev.ps1`, `global.json` chỉ có ở ApiGateway | như trên | Script dev nên ở **root** (dùng chung), `global.json` nên ở root |
| HY-06 | **P1** | Mỗi repo có `docker-compose.yml` riêng **+** root có compose → 10 định nghĩa compose, 8 DB bị khai 3 lần (repo, root `docker-compose.yml`, root `docker-compose.infra.yml`) | `ls src/Services/*/docker-compose.yml` | Repo chỉ giữ compose **dev tối thiểu** (1 DB của mình); toàn hệ do root quản |
| HY-07 | **P2** | `.claude/skills/gitnexus/` copy 9 bản (mỗi repo 1 bộ 6 skill) | `find src/Services/*/.claude` | Giữ 1 bản ở root, repo con trỏ (hoặc dùng symlink) |
| HY-08 | **P2** | `nuget.config` chỉ có ở User + Notification | `ls src/Services/*/nuget.config` | Thống nhất: có ở tất cả hoặc không repo nào |
| HY-09 | **P2** | `.gitignore` giống nhau nhưng `bin/`/`obj/` **không** bị track (tốt) — 0 file artifact trong git | `git ls-files \| grep -E '/(bin\|obj)/'` = 0 | Giữ nguyên ✅ |

## 4. Thứ tự dọn (đề xuất)

1. **Commit hoặc revert migration** (HY-02) — đây là P0 vì ảnh hưởng khả năng chạy.
2. **Chốt nhánh** (`dev` cho tất cả, hoặc `dev` + `mock`) → ghi vào `.gitmodules` (HY-01) + sửa trigger CI (`OP-04`).
3. Dọn file lạc Gateway (HY-04) + gom compose về root (HY-06).
4. Tách block GitNexus khỏi `AGENTS.md` (HY-03) để dirty không còn do tool.
