# 00 — REPO BASELINE (Phase 0 / T0.1 · T0.4)

> Chụp lúc: 2026-10-24T17:3x +07:00 · Read-only snapshot trước khi audit
> Nguồn: `git -C <repo> rev-parse/status/log` + `node .gitnexus/run.cjs status`

## 1. Trạng thái Git của 10 repo

| Repo | Branch | Commit | Commit time | Dirty | Ghi chú |
|---|---|---|---|---|---|
| **root** (`Nexus-Be`) | `dev` | `eec78ce` | 2026-10-24 15:46 | 9 | 8 submodule pointer `M` + `docs/plans/` untracked (do audit tạo) |
| `ApiGateway` | **`mock`** | `efb840d` | 2026-10-24 15:05 | 0 | ⚠️ **khác branch** với 8 service còn lại (`dev`) |
| `Auction` | `dev` | `37895fa` | 2026-10-24 15:44 | 5 | migration bị xoá (xem §2) |
| `Catalog` | `dev` | `4c74107` | 2026-10-24 15:44 | 5 | idem |
| `Commerce` | `dev` | `44616e1` | 2026-10-24 15:44 | 5 | idem |
| `Fulfillment` | `dev` | `1702ffc` | 2026-10-24 15:44 | 5 | idem |
| `Log` | `dev` | `6dcc1d8` | 2026-10-24 15:44 | 5 | idem |
| `Notification` | `dev` | `4d8e46d` | 2026-10-24 15:44 | 5 | idem |
| `User` | `dev` | `f65d2f1` | 2026-10-24 15:44 | 8 | idem (7 file migration) |
| `Wallet` | `dev` | `4ab32a0` | 2026-10-24 15:44 | 5 | idem |

**Phát hiện B-01 (P1):** ApiGateway nằm trên branch `mock`, 8 service trên `dev` → không có trạng thái “một hệ thống” để tái lập. Cần chốt branch policy (`.gitmodules` không khai báo `branch`).

## 2. Phát hiện B-02 (P0): toàn bộ EF migrations đã bị xoá khỏi working tree

Cả 8 service đều ở trạng thái “tracked nhưng deleted on disk”:

| Repo | Migration bị xoá | File còn trên đĩa |
|---|---|---|
| Auction | `20261024082539_InitialAuctionSchema(.Designer).cs`, `AppDbContextModelSnapshot.cs` | 0 |
| Catalog | `20261024081313_InitialCatalogSchema(.Designer).cs`, `AppDbContextModelSnapshot.cs` | 0 |
| Commerce | `20261024081600_InitialCommerceSchema(.Designer).cs`, `AppDbContextModelSnapshot.cs` | 0 |
| Fulfillment | `20261024081723_InitialFulfillmentSchema(.Designer).cs`, `AppDbContextModelSnapshot.cs` | 0 |
| Log | `20261024080751_InitialLogSchema(.Designer).cs`, `LogDbContextModelSnapshot.cs` | 0 |
| Notification | `20261024080613_InitialNotificationSchema(.Designer).cs`, `AppDbContextModelSnapshot.cs` | 0 |
| User | `20261022193809_InitialUserSchema`, `20261022194152_SeedDefaultRoles`, `20261024075751_AddMassTransitOutboxInboxTables` (+Designer), `AppDbContextModelSnapshot.cs` | 0 |
| Wallet | `20261024081115_InitialWalletSchema(.Designer).cs`, `WalletDbContextModelSnapshot.cs` | 0 |

Kèm theo, mỗi repo có `AppDbContext.cs`/`*DbContext.cs` + `Persistence/Seeds/*SeedData.cs` đang **modified** (chưa commit) → đây là một đợt “reset schema” đang dở.

**Hệ quả vận hành:** mọi `Program.cs` gọi `db.Database.Migrate()` khi khởi động; với 0 migration, DB sẽ **không có bảng** (chỉ tạo DB rỗng) và lỗi bị nuốt bởi `catch { LogWarning("Database migration deferred...") }`. Vì vậy “service chạy được” ≠ “service có dữ liệu”.

## 3. GitNexus index — TRƯỚC và SAU re-index

**Trước (2026-10-23 00:47–00:49):** cả 9 repo stale — ví dụ Catalog index trên `0250799`/branch `main`, code thực tế `4c74107`/branch `dev`.

**Sau Phase 0 (2026-10-24 17:28–17:32):** 9/9 repo `✅ up-to-date`.

| Repo | Branch | Files | Nodes (symbols) | Edges | Processes (flows) | Communities |
|---|---|---:|---:|---:|---:|---:|
| **root** | `dev` | 810 | 5960 | 8926 | 191 | 129 |
| ApiGateway | `mock` | 150 | 1252 | 2601 | 100 | 43 |
| User | `dev` | 92 | 618 | 971 | 16 | 11 |
| Wallet | `dev` | 68 | 474 | 755 | 11 | 12 |
| Commerce | `dev` | 88 | 636 | 799 | 7 | 13 |
| Auction | `dev` | 68 | 445 | 565 | 4 | 11 |
| Catalog | `dev` | 63 | 384 | 490 | 4 | 11 |
| Fulfillment | `dev` | 67 | 404 | 514 | 4 | 12 |
| Notification | `dev` | 76 | 455 | 581 | 4 | 9 |
| Log | `dev` | 62 | 414 | 557 | 2 | 9 |

**Đọc bảng này ra vấn đề:** 8 backend service chỉ có **2–16 flow** trong khi Gateway có **100 flow** → đồng nghĩa “nghiệp vụ thật” gần như nằm hết ở Gateway, backend chỉ là CRUD + vài handler. Đây là hệ quả định lượng của phát hiện “gateway chạy mock”.

> Ghi chú: `analyze` tự regenerate block GitNexus trong `AGENTS.md` + `CLAUDE.md` ở root (5272 → **5960 symbols**). Đây là thay đổi do tool, không phải do audit sửa tay — cần commit riêng khi bạn duyệt.

## 5. Baseline tri thức (T0.4)

- Tổng: **5960 symbol / 8926 quan hệ / 191 execution flow** trong index root.
- Phân bố flow: Gateway 100, User 16, Wallet 11, Commerce 7, Auction/Catalog/Fulfillment/Notification 4, Log 2.
- Chi tiết từng repo nằm trong `docs/plans/audit/{Repo}_AUDIT.md` (Phase 2) và `gates/*.json` (facts).


## 4. Toolchain

| Công cụ | Phiên bản | Ghi chú |
|---|---|---|
| .NET SDK | `8.0.129` | khớp `global.json` (Gateway) |
| Docker | `29.8.1` | dùng được cho compose (chưa verify daemon chạy) |
| GitNexus runner | có ở cả 10 repo (`.gitnexus/run.cjs`) | chạy local, không cần `npx` |

## 6. ĐÍNH CHÍNH sau audit (đọc mục này trước khi tin §1–§2)

1. **B-02 đã thay đổi bản chất.** Không phải “migrations bị xoá rồi bỏ đó”: lúc **17:30–17:31 ngày 24/10** (trong khi audit đang chạy) một tiến trình khác đã **regenerate migration** cho cả 8 repo thành 1 file `Initial*` mới (`Auction 20261024103234`, `Catalog 20261024103127`, `Commerce 20261024103145`, `Fulfillment 20261024103218`, `Log 20261024103313`, `Notification 20261024103253`, `User 20261024103058`, `Wallet 20261024103202`). Trạng thái git bây giờ = file cũ `D` + file mới `??` + snapshot `M`.
   → **Nội dung schema đúng, nhưng chưa commit** ⇒ clone mới vẫn không tạo được DB. Đây là **P0 tái lập** (`FIX-001`, `HY-02`), không phải “migration mất”.
   → Riêng `User`: migration mới gộp đủ `InboxState`/`OutboxMessage` + 6 `InsertData` role, nhưng **mất lịch sử 3 migration cũ** (`20261022193809_InitialUserSchema`, `20261022194152_SeedDefaultRoles`, `20261024075751_AddMassTransitOutboxInboxTables`).
2. **Dirty count thực tế cuối audit:** ApiGateway **2** (`AGENTS.md`, `CLAUDE.md` do `analyze` sinh), 7 service **9**, User **12**. Phần tăng so với §1 là do tool (`AGENTS.md`/`CLAUDE.md`) + migration regenerated — **không** do audit sửa code.
3. **Kết quả gate chính thức (chạy lại toàn bộ):** `docs/plans/audit/gates/SUMMARY.md` — **170 phát hiện: P0 = 42, P1 = 23, P2 = 105**. Exit code 1 (có P0).
