# AUDIT — Luật vận hành (`AGENTS.md` / `CLAUDE.md` / `specs/05`)

**Câu hỏi:** “các luật đã đúng chưa?” — luật có đúng **nội dung**, có **khả thi**, và **có được tuân thủ** không.

## 0. Kết luận

Luật được viết **tốt hơn mặt bằng chung**: 6 nguyên tắc rõ ràng, có ma trận file bắt buộc đọc, có DoD đo được. Không có luật nào mâu thuẫn nhau về nội dung.

Nhưng có **3 lỗ hổng hệ thống**:

1. **Luật nằm ở 3 bản** (`AGENTS.md` ≡ `CLAUDE.md` — cùng md5 `88e18fb2088044c9b880f5c2a348c271` — và `specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md` chép lại 6 mục) → sửa 1 bản là lệch 2 bản còn lại.
2. **Không có cơ chế cưỡng chế**: 0/6 nguyên tắc được kiểm tự động trong CI (CI còn không chạy — `OP-04`). Mọi luật hiện là “lời khuyên”.
3. **3 luật đang bị chính code vi phạm** (port bất biến, hợp đồng protobuf duy nhất, thông báo lỗi tiếng Anh) → luật tồn tại nhưng sự thật không tuân.

## 1. Bảng đánh giá 6 nguyên tắc

| # | Nguyên tắc | Nội dung đúng? | Khả thi? | Được tuân thủ? | Bằng chứng |
|---|---|---|---|---|---|
| 1 | **Plan-first** (bắt buộc lập plan trước khi sửa) | ✅ | ⚠️ | ⚠️ | Không có template plan, không có thư mục plan chuẩn trước hôm nay; không có bước CI kiểm tra; **mục GitNexus “MUST run impact”** dựa vào index — mà index đã stale (Catalog index commit `0250799`/branch `main` khi code là `4c74107`/`dev`) → chạy impact trên đồ thị cũ cho cảm giác an toàn giả |
| 2 | **Inward-only** (repo con không trỏ ra ngoài) | ✅ | ✅ | ✅ | Gate `doclink`: **0** outward link trong 9 repo; 0 link chéo sibling |
| 3 | **Ma trận file bắt buộc đọc** | ✅ | ❌ | ⚠️ | 6 file `specs/` có đủ 8/8 repo ✅; nhưng ma trận yêu cầu đọc `<S>.Api/Contracts/shop.proto` — **5/8 service không có file này** (Catalog, Commerce, Auction, Fulfillment, Notification) → bước 3 của quy trình không thực hiện được |
| 4 | **Zero-hallucination** (4 rào chắn) | ✅ | ⚠️ | ❌ | (a) Không Repository pattern ✅ **0 hit**; (b) DB-per-service ✅ 0 connection string chéo; (c) **port bất biến `8000–8008`** ❌ 6/8 `launchSettings.json` dùng port khác (5230/5272/5105/5228/5280/5096); (d) **“hợp đồng protobuf duy nhất”** ❌ 4 bản/3 hash, và bản được chỉ định làm nguồn lại thiếu 8/9 service |
| 5 | **Thông báo lỗi** (English + sentence case + SCREAMING_SNAKE code) | ✅ | ✅ | ❌ | **19 P0 lỗi tiếng Việt** trong ngữ cảnh lỗi (Wallet 13, Gateway 3, Log 3 — chi tiết `gates/errmsg.json`); 3 P1 sai kiểu chữ; mã lỗi thì **đúng** chuẩn (`VAL_INVALID_INPUT`, `AUTH_UNAUTHORIZED`, `RATE_LIMIT_EXCEEDED`, `DOWNSTREAM_UNHEALTHY`…) |
| 6 | **Definition of Done** (plan + inward + build + test + git sạch) | ✅ | ⚠️ | ⚠️ | build **9/9 EXIT 0** ✅; test chỉ 3/9 repo có project (và 3/3 pass) → DoD **không thể đạt** ở 6 repo; git **9/9 dirty** (migration regenerated, `AGENTS.md`/`CLAUDE.md` do tool sinh) |

## 2. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| RL-01 | **P0** | Luật tồn tại 3 bản, không có nguồn duy nhất | `md5sum AGENTS.md CLAUDE.md` = `88e18fb2…`; `specs/05` cùng 6 mục | `CLAUDE.md` = 1 dòng `@AGENTS.md`; `specs/05` chỉ giữ phần giải thích/ ví dụ, trỏ về `AGENTS.md` |
| RL-02 | **P0** | Không luật nào được CI cưỡng chế | CI 9 repo không có bước lint/format/test | Đưa `.tools/audit/audit.py` (9 gate) vào CI: fail nếu có P0 |
| RL-03 | **P0** | Luật “port bất biến” bị vi phạm ở 6 service | `C*_AUDIT.md`, `WA-01` | Sửa `launchSettings.json` (việc của Phase backlog P1) + gate `port` chặn hồi quy |
| RL-04 | **P0** | Luật “hợp đồng protobuf duy nhất” bị vi phạm + luật chỉ sai nguồn | `CT-01` | Sửa `specs/04` + `AGENTS.md` §4.4 trước khi ai đó code theo |
| RL-05 | **P1** | Luật “MUST run impact analysis” không kèm bước **re-index** → chạy trên đồ thị cũ | index stale trước Phase 0 | Thêm “nếu `git rev-parse HEAD` ≠ `meta.json.lastCommit` thì chạy `analyze` trước” |
| RL-06 | **P1** | Luật “thông báo lỗi tiếng Anh” bị vi phạm 19 chỗ | `gates/errmsg.json` | Sửa theo `T1.5`; thêm gate `errmsg` vào CI |
| RL-07 | **P2** | DoD yêu cầu `dotnet test` nhưng 6 repo không có test project → không thể “đạt DoD” | `gates/test.json` | Ghi rõ DoD áp dụng **sau khi** có test project; hoặc hạ DoD cho service chưa có test (kèm ngày) |
| RL-08 | **P2** | `AGENTS.md` không có mục “cấm commit migration regenerated / cấm commit bí mật” | `appsettings.json:26` JWT key; migration `??` | Thêm 2 điều khoản + pre-commit hook |

## 3. Đề xuất sửa luật (nội dung, không chỉ hình thức)

1. **§4.4** đổi từ “Mọi service phải tuân thủ hợp đồng Protobuf gốc trong `Contracts/shop.proto`” → “Mọi service dùng proto sinh từ **`contracts/proto/shop.proto` ở root**; cấm sửa bản copy; CI kiểm hash”.
2. **§1** thêm bước 0: “Xác nhận index GitNexus khớp `HEAD` trước khi dùng `impact`”.
3. **§6 DoD** thêm: “Không commit `*.Designer.cs` mới sinh nếu chưa review schema”; “Không commit secret — dùng `appsettings.example.json`”.
4. **§5** thêm ví dụ sai cụ thể đã gặp: `"Email đã tồn tại"`, `"{field} phải là UUID"`.
5. Thêm **§7 Gate tự động**: bảng gate ↔ lệnh ↔ ngưỡng (chính là `.tools/audit/README.md`).
