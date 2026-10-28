<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **root** (6723 symbols, 9712 relationships, 184 execution flows). Index stale? Run `node .gitnexus/run.cjs analyze --index-only`.

- **MUST run impact before editing:** `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`. Report callers, processes, risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing:** `detect_changes({scope: "all"})` or `node .gitnexus/run.cjs detect-changes --scope all --repo .`. Compare: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn on HIGH/CRITICAL `risk` pre-edit;** never waive with `riskSharedAxes`.
- **MUST treat `risk: UNKNOWN` as unresolved, not low.** Confirm with text search before modifying/deleting.
- **MUST use `query` for concepts/flows, `context` for symbols, or `impact` for blast radius.**
- **NEVER** edit before impact analysis · **NEVER** rename with find-and-replace · **NEVER** commit before detect_changes.
- Resources: `gitnexus://repo/root/context` · `clusters` · `processes` · `process/{name}`. CLI skills in `.claude/skills/gitnexus-*/SKILL.md`.
<!-- gitnexus:end -->

---

# QUY CHUẨN VẬN HÀNH DÀNH CHO TẤT CẢ CÁC AI CODING AGENTS

## 🛑 NGUYÊN TẮC 1: BẮT BUỘC LẬP KẾ HOẠCH TRƯỚC KHI HÀNH ĐỘNG (PLAN-FIRST RULE)
Mọi AI Agent khi nhận nhiệm vụ kỹ thuật **BẮT BUỘC PHẢI LẬP VÀ TRÌNH BÀY PLAN** trước khi thực hiện bất kỳ hành động sửa đổi mã nguồn, thêm/xóa file, refactor, tạo migration hay thay đổi cấu hình.
1. **Mục tiêu (Objective)**: Tóm tắt chính xác điều cần làm.
2. **Context & Files cần đọc**: Liệt kê các file theo ma trận đọc file tại Nguyên tắc 3.
3. **Phân tích rủi ro & Phạm vi ảnh hưởng (Impact Analysis)**: Dùng GitNexus `impact`, cảnh báo rõ HIGH/CRITICAL.
4. **Checklist các bước thực hiện (Step-by-Step Implementation)**: Từng bước logic, chi tiết.
5. **Kế hoạch kiểm chứng (Verification)**: Lệnh `dotnet build` và `dotnet test` tương ứng.

## 🧭 NGUYÊN TẮC 2: QUY TẮC ĐỊNH HƯỚNG TÀI NGUYÊN MỘT CHIỀU (INWARD-ONLY SCOPING)
1. **File ở Root (`Nexus-Be/`)**: ĐƯỢC PHÉP trỏ vào trong các thư mục con và service repo (`src/Services/...`).
2. **File bên trong từng Service Repo / Submodule (`src/Services/{Service}/`)**:
   - TUYỆT ĐỐI CHỈ ĐƯỢC trỏ tới tài nguyên nội bộ của chính repo đó.
   - TUYỆT ĐỐI KHÔNG trỏ ngược ra ngoài Root (`../../../docs/...`, `../../specs/...`) hoặc sang Sibling Service (`../../Catalog/...`). Mỗi service phải 100% Self-contained.

## 📚 NGUYÊN TẮC 3: DANH MỤC FILE BẮT BUỘC PHẢI ĐỌC
Khi bắt đầu phiên làm việc tại bất kỳ repository nào, AI Agent **BẮT BUỘC PHẢI ĐỌC** theo danh mục chi tiết tại `docs/agents/reading-matrix.md`.
- **Root**: `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`, `specs/01` qua `05`, `AGENTS.md`.
- **ApiGateway**: `specs/00_AGENT_MISSION_GUARDRAILS.md` qua `05`, `MOCK_GUIDE.md`, `DEV_GUIDE.md`, `Nexus.Gateway/Dtos/`.
- **Microservices Backend**: `specs/00_AGENT_MISSION_GUARDRAILS.md` qua `05_DEV_VERIFICATION_CHECKLIST.md` của service đó.

## 🔒 NGUYÊN TẮC 4: RÀO CHẮN BẤT BIẾN CHỐNG ẢO GIÁC (ZERO-HALLUCINATION)
1. **CẤM DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**: Dùng trực tiếp `DbContext` và `DbSet<T>` trong Application Layer.
2. **CÔ LẬP TUYỆT ĐỐI DATABASE (DATABASE-PER-SERVICE)**: Không query trực tiếp DB của service khác.
3. **CẤU HÌNH PORT LÀ BẤT BIẾN**: Gateway `8080`, Microservices HTTP/REST `8001`-`8008`, DB `5433`-`5440`.
4. **100% SỬ DỤNG RESTFUL HTTP/JSON — CẤM gRPC CHO GIAO TIẾP ĐỒNG BỘ**:
   - Chuẩn RESTful: `/api/v1/{resource}`, RFC 9110 (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
   - Dữ liệu trả về: `ApiResponse<T>`, `ApiResponse<PagedData<T>>`, hoặc `204 NoContent`.
   - Bất đồng bộ: RabbitMQ qua MassTransit (Event-driven / Outbox Pattern / Saga).
5. **ĐỐI SOÁT TÀI LIỆU EXCEL**: Chỉ tin ý đồ nghiệp vụ (semantic), KHÔNG tin định dạng/casing. Quy chuẩn Role (PascalCase theo `specs/03`), DTO (camelCase), DB (snake_case).
6. **BẢO MẬT & QUẢN LÝ BIẾN MÔI TRƯỜNG (`.env`)**:
   - CẤM tự ý xóa/ghi đè secrets. Khi có chỉ đạo trực tiếp từ người dùng, rà soát `.env.example`, `.env.test`, compose và cung cấp block cấu hình rõ ràng. Tuyệt đối cấm duplicate keys.
7. **HẠ TẦNG PHỤ TRỢ TẬP TRUNG (SINGLE SHARED INFRASTRUCTURE)**:
   - Redis (`6379`), RabbitMQ (`5672`), Tempo, Grafana chỉ khai báo 1 lần tại `src/Infrastructure/` hoặc `docker-compose.infra.yml`. CẤM khai báo riêng lẻ trong submodule. Dùng Key Prefix riêng trên Redis chung (`nexus:gateway:*`, `otp:*`, `user:*`).
8. **FEATURE-DRIVEN CO-LOCATION & 1-TO-1 CONTROLLER PAIRING (CHUẨN HÓA ĐẶC TẢ `specs/01`)**:
   - Tầng Application: Toàn bộ thành phần của một tính năng đặt tại `{Service}.Application/Services/{Feature}/` gồm: `I{Feature}Service.cs`, `{Feature}Service.cs` (inject trực tiếp `I{Service}DbContext`, cấm Repository), `{Feature}Requests.cs`, `{Feature}Responses.cs`, `{Feature}Dtos.cs` (tùy chọn).
   - Tầng Api: Ghép cặp 1-to-1 với một thin controller tại `{Service}.Api/Controllers/{Feature}Controller.cs`, chỉ inject duy nhất `I{Feature}Service`.
9. **CÁCH LY INBOUND CONSUMER THEO SERVICE NGUỒN & DI EXTENSION**:
   - Tầng Application: Consumers nhận sự kiện RabbitMQ bắt buộc đặt tại `{Service}.Application/Consumers/{SourceService}/{EventName}Consumer.cs`.
   - Đóng gói đăng ký MassTransit qua file `{Service}.Application/Consumers/ConsumerExtensions.cs` (extension method `AddApplicationConsumers(this IBusRegistrationConfigurator)`).
   - Tầng Infrastructure: Cấu hình MassTransit chỉ gọi `x.AddApplicationConsumers()` kết hợp với Outbox và RabbitMQ. Cấm đặt Consumer tại tầng Api hoặc rải rác trong Infrastructure.
10. **QUY CHUẨN BẮT BIẾN KHI PHÁT TRIỂN & KHAI BÁO API MỚI (MANDATORY API RULES)**:
   - **Cấm trùng lặp Route alias (No Duplicate Route Aliases)**: Cấm tuyệt đối khai báo nhiều route attributes trùng lặp (ví dụ `[HttpGet("user")]` và `[HttpGet("users")]`) trên cùng một Action. Mỗi action chỉ có 1 route endpoint chính thức duy nhất.
   - **Quy ước Route Số ít cho User/AdminUser (Singular Route Convention)**: Toàn bộ endpoint liên quan đến User và AdminUser phải dùng danh từ số ít (`/api/v1/user`, `/api/v1/user/{userId}`, `/api/v1/admin/user`, `/api/v1/admin/user/{userId}`, `/api/v1/me`). Giữ danh từ số nhiều cho các collection chuẩn của domain khác (`/api/v1/auctions`, `/api/v1/categories`, `/api/v1/wallets`, `/api/v1/notifications`).
   - **Mô hình Thin Controller & Kế thừa đúng chuẩn**:
     - Tại API Gateway: Controller bắt buộc kế thừa `GatewayBaseController`, không chứa business logic, chỉ validate input cơ bản qua `UserValidation` và ủy quyền downstream qua `ForwardAsync` / `ForwardPagedAsync` / `ForwardNoContentAsync`.
     - Tại Microservice: Kế thừa `ControllerBase`, ghép cặp 1-to-1 với feature service tương ứng.
   - **Phong bì dữ liệu chuẩn (Envelope Standard)**: Mọi endpoint trả dữ liệu đều phải bọc qua `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`. Endpoint xóa hoặc không trả dữ liệu body bắt buộc trả HTTP `204 NoContent`. DTOs dùng PascalCase trong C# và camelCase trong JSON serialization.
   - **Chuẩn hóa XML Comment Endpoint**: Chỉ dùng single-line XML `<summary>` ngắn gọn trực tiếp trên từng Action method. Cấm viết class-level remarks, section dividers kẻ ngang hoặc comment dài dòng nhiều dòng.
   - **Bắt buộc Mock Seed Fixture**: Khi thêm endpoint mới vào Gateway, bắt buộc tạo seed fixture tương ứng tại `Seeds/{service}/{name}.json` để đảm bảo Mock mode luôn hoạt động độc lập và pass 100% test `UserSeedConformanceTests`.
   - **Đồng bộ Tài liệu & Specs**: Khi thêm mới hoặc thay đổi bất kỳ route/DTO nào, bắt buộc cập nhật đồng thời file spec tương ứng (`specs/02_GATEWAY_CONTROLLERS_ROUTING.md`) và tài liệu API Frontend (`docs/FRONTEND_API_ENDPOINT_MAPPING.md`).

## 💬 NGUYÊN TẮC 5: QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG
1. **Ngôn ngữ (100% English)**: Toàn bộ thông báo lỗi viết bằng tiếng Anh. Tuyệt đối không dùng tiếng Việt.
2. **Quy cách viết hoa (Sentence case)**: Viết hoa duy nhất chữ cái đầu câu (trừ tên riêng, viết tắt `ID`, `OTP`, `JWT`, `URL`, `Email`...). Ví dụ: `"Email is already registered in the system."`
3. **Mã lỗi (SCREAMING_SNAKE_CASE)**: Viết hoa toàn bộ và nối bằng gạch dưới: `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `USER_NOT_FOUND`.

## 🎯 NGUYÊN TẮC 6: ĐIỀU KIỆN HOÀN THÀNH NHIỆM VỤ (DEFINITION OF DONE)
- [ ] Đã lập Plan chi tiết trước khi thực hiện.
- [ ] Tuân thủ nguyên tắc Inward-Only.
- [ ] `dotnet build <Solution>.sln -c Release` thành công 100% (0 error).
- [ ] `dotnet test <Solution>.sln -c Release` vượt qua 100% kiểm thử.
- [ ] Git sạch, không commit file rác (`bin/`, `obj/`, `.vs/`).

## 🧪 NGUYÊN TẮC 7: HIỆN TRẠNG HỆ THỐNG & ĐIỀU KIỆN BẮT ĐẦU
Chi tiết audit: `docs/agents/system-audit.md`, `docs/plans/SCORECARD.md`, `docs/plans/FIX_BACKLOG.md`.
- Code nghiệp vụ mới CHỈ bắt đầu sau khi hoàn tất Track S trong `docs/plans/SETUP_PHASE_PLAN.md`.
- Mọi tài liệu khi sửa phải có banner trạng thái theo `docs/plans/DOC_UPDATE_PROTOCOL.md`.
- Không coi `/health` là bằng chứng service hoạt động vì không kiểm tra DB.

## 📝 NGUYÊN TẮC 8: QUY CHUẨN ĐÓNG PHIÊN, BÁO CÁO & LƯU TRỮ KẾ HOẠCH
Tuân thủ quy trình đầu/cuối phiên chi tiết tại `docs/agents/session-protocol.md`.
1. **Lưu trữ Kế hoạch**: Ghi tại `.agents/plan/PLAN-YYYYMMDD-HHMM-[TEN_VAN_DE].md` (Mục tiêu, Hướng giải quyết, Checklist).
2. **Báo cáo Nhật ký**: Ghi tại `.agents/history/YYYY-MM-DD_session_summary.md` (Tổng thể, Nghiên cứu, Link Plan, Báo cáo cá nhân, Báo cáo toàn team).

<!-- super-board:begin v3.1.2 (managed; edits inside are overwritten on upgrade) -->
## Super Board

Board: Backlog · Ready · Building · QA · Review · Blocked · Done. Labels route: `qa` skips Building · `bug`, `feature`, none → built first.

| When | Use | NEVER |
|---|---|---|
| Set up / repair the board | `/super-board onboard` | DON'T hand-edit config mid-run |
| Check tickets before a run | `/super-board lint` | NEVER run with AC-less tickets |
| Drain the board | `/super-board run` | NEVER build, test or merge from the orchestrator |
| Board state / halt | `/super-board status` · `/super-board stop` | |
| Build one ticket | `/super-build` | NEVER build outside the card's worktree |
| QA a branch, or a live URL alone | `/super-qa` · `/super-qa <url>` | NEVER mark QA pass without evidence |
| Review a PR, merge | `/super-review` | NEVER `gh pr merge` direct — merge gate only |
| File bugs from Sentry, PostHog, PRs | `/super-collect` | DON'T file without a verifier pass |
| UI polish | `/ui-refine-loop` (human runs it) | board NEVER runs it |
| Diagram / explainer page | `/visual` | |
| Commit, pull, push this branch | `/git-sync` | NEVER force push or rebase shared history |

| Rule | Value |
|---|---|
| Config | `.claude/super-board/configs/<slug>.json` |
| Isolation | 1 card · 1 worktree · 1 branch |
| Merge | auto for normal changes · money, auth, destructive schema (DROP/TRUNCATE/RENAME) → human · PR > 400 changed lines → human |
| Migrations | additive → robot migrates allowed DBs only · live DB ALWAYS → 🙋 needs you |
| Blocked card | block-template comment · last line `blocked-by:` · 🙋 = needs you |
| Secrets | NEVER read `.env`; key names via `.claude/bin/super-board-env-check.sh` |

## Writing (super-board)

| Thing | Format → `.claude/skills/super-board/references/writing-standard.md` |
|---|---|
| Commit, PR title | `<emoji> [type] scope: subject` + short bullets · ✨ feat 🐛 fix 🔧 chore ♻️ refactor 🧪 test 📝 docs |
| PR body | blocks: status · Problem · Solution · AC + proof · history · Before\|After · Risk — `super-board-pr-body.sh` |
| Ticket | Problem · Context · Fix · AC · Risk · Blocked by → `docs/agents/issue-tracker.md` |
| Comment | `[role] [label] status` · Did · ✅ Done · ❌ Not done · Next · ≤ 8 lines |
| PR author notes | file + critical inline review comments: Purpose · What changed · Why it matters → `pr-author-notes.md` |

- NEVER chain steps with arrows. One step per line, lettered under Where.
- NEVER link screenshots. Embed a raw URL pinned to a sha.
- DON'T repeat file lists in status comments. DON'T write "Not verified" or "Next" in a PR body.
<!-- super-board:end -->
