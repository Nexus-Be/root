<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **root** (6723 symbols, 9712 relationships, 184 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact before editing.** Use `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`; report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "main"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "main" --repo .`.
- MUST warn on HIGH/CRITICAL `risk` pre-edit; never use `riskSharedAxes` to waive a HIGH/CRITICAL `risk` warning. Compare File/symbol: MCP File omits axes; Graph-RAG expands File.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- **MUST use `query({search_query: "concept"})` for concepts/flows, `context({name: "symbolName"})` for a named symbol, or `impact` for blast radius, on read-only callers, dependencies, imports, or execution flow.** Graph first; text search only for empty/`UNKNOWN`/literals.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/root/context` | Codebase overview, check index freshness |
| `gitnexus://repo/root/clusters` | All functional areas |
| `gitnexus://repo/root/processes` | All execution flows |
| `gitnexus://repo/root/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

---

# QUY CHUẨN VẬN HÀNH DÀNH CHO TẤT CẢ CÁC AI CODING AGENTS

---

## 🛑 NGUYÊN TẮC 1: BẮT BUỘC LẬP KẾ HOẠCH TRƯỚC KHI HÀNH ĐỘNG (PLAN-FIRST RULE)

Mọi AI Agent khi nhận nhiệm vụ kỹ thuật **BẮT BUỘC PHẢI LẬP VÀ TRÌNH BÀY PLAN** trước khi thực hiện bất kỳ hành động sửa đổi mã nguồn, thêm/xóa file, refactor, tạo migration hay thay đổi cấu hình nào.

Một Plan chuẩn bắt buộc phải có:
1. **Mục tiêu (Objective)**: Tóm tắt chính xác điều cần làm.
2. **Context & Files cần đọc**: Liệt kê các file theo đúng ma trận đọc file tại Nguyên tắc 3.
3. **Phân tích rủi ro & Phạm vi ảnh hưởng (Impact Analysis)**:
   - Dùng GitNexus `impact` đánh giá blast radius các symbol bị ảnh hưởng.
   - Cảnh báo rõ nếu mức độ rủi ro là HIGH hoặc CRITICAL.
4. **Checklist các bước thực hiện (Step-by-Step Implementation)**: Từng bước logic, chi tiết.
5. **Kế hoạch kiểm chứng (Verification)**: Lệnh `dotnet build` và `dotnet test` tương ứng.

---

## 🧭 NGUYÊN TẮC 2: QUY TẮC ĐỊNH HƯỚNG TÀI NGUYÊN MỘT CHIỀU (INWARD-ONLY SCOPING)

Hệ thống Nexus được tổ chức dưới dạng **Multi-Repository với Git Submodules**:
1. **File ở Root (`Nexus-Be/`)**: **ĐƯỢC PHÉP trỏ vào trong** các thư mục con và các service repository (`src/Services/...`).
2. **File bên trong từng Service Repo / Submodule (`src/Services/{Service}/`)**:
   - **TUYỆT ĐỐI CHỈ ĐƯỢC trỏ tới các tài nguyên nội bộ của chính repo đó**.
   - **TUYỆT ĐỐI KHÔNG ĐƯỢC trỏ ngược ra ngoài Root** (`../../../docs/...`, `../../specs/...`).
   - **TUYỆT ĐỐI KHÔNG ĐƯỢC trỏ sang các Sibling Service khác** (`../../Catalog/...`, `../../ApiGateway/ADR.md`).
   - Mỗi service là một Git repository độc lập, phải đảm bảo tính tự cung tự cấp (100% Self-contained).

---

## 📚 NGUYÊN TẮC 3: DANH MỤC FILE BẮT BUỘC PHẢI ĐỌC TRONG TỪNG REPOSITORY

Khi bắt đầu một phiên làm việc tại bất kỳ repository nào, AI Agent **BẮT BUỘC PHẢI ĐỌC** các file sau theo thứ tự:

### 1. Tại Root Repository (`Nexus-Be/`):
- `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`: Kiến trúc C4 tổng quan, Bounded Contexts.
- `specs/01_SERVICE_CATALOG_PORT_MAP.md`: Quy hoạch dải port HTTP/gRPC (`8000`-`8008`) và DB (`5433`-`5440`).
- `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md`: Ma trận gRPC đồng bộ vs RabbitMQ Saga.
- `specs/03_SECURITY_RBAC_DATA_GOVERNANCE.md`: JWT Bearer, ma trận phân quyền 6 roles, chuẩn RFC 9110.
- `specs/04_SHARED_CONTRACTS_REGISTRY.md`: Nguồn sự thật Protobuf và các sự kiện dùng chung.
- `specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md`: Bộ chỉ dẫn toàn diện cho AI Agents.
- `AGENTS.md`: Quy tắc vận hành và quy chuẩn thông báo lỗi.

### 2. Tại `ApiGateway` (`src/Services/ApiGateway/`):
- `specs/00_AGENT_MISSION_GUARDRAILS.md`: Bounded context gateway, port `8000`, 0 DB.
- `specs/01_ARCHITECTURAL_BLUEPRINT.md`: Pipeline 6 bước, Circuit breaker, Health Prober.
- `specs/02_GATEWAY_CONTROLLERS_ROUTING.md`: Danh mục Controller, quy tắc viết Action siêu tinh gọn.
- `specs/03_GATEWAY_STATE_SECURITY.md`: Cấu hình Mock/Real, AuthMode Enforce/Bypass.
- `specs/04_MOCK_ENGINE_SEED_DATA.md`: Cấu trúc dữ liệu Seed Fixture trong `Seeds/`.
- `MOCK_GUIDE.md`: Quy trình tạo Mock API chuẩn duy nhất (Controller Action + Seeds/).
- `DEV_GUIDE.md`: Hướng dẫn thêm API mới vào Gateway.
- `Nexus.Gateway/Contracts/shop.proto`: Hợp đồng Protobuf gRPC gốc.
- `specs/05_DEV_VERIFICATION_CHECKLIST.md`: Checklist nghiệm thu Gateway.

### 3. Tại các Microservices Backend (`src/Services/{Service}/`):
Mỗi service (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`) sở hữu một bộ spec kit chuẩn hóa nằm tại `specs/` của service đó:
- `specs/00_AGENT_MISSION_GUARDRAILS.md`: Nhiệm vụ cốt lõi, port gRPC, DB port, rào chắn chống ảo giác.
- `specs/01_CLEAN_ARCHITECTURE_LAYERS.md`: Cấu trúc 4 tầng Clean Architecture, No-Repository pattern over EF Core.
- `specs/02_API_GRPC_CONTRACTS.md`: Hợp đồng gRPC Server thuộc phạm vi của service.
- `specs/03_EVENT_MESSAGING.md`: Sự kiện RabbitMQ xuất/nhập (Publish / Consume / Saga).
- `specs/04_DATA_PERSISTENCE.md`: Schema bảng dữ liệu PostgreSQL và cấu hình EF Core.
- `specs/05_DEV_VERIFICATION_CHECKLIST.md`: Lệnh build & test kiểm chứng service.

---

## 🔒 NGUYÊN TẮC 4: RÀO CHẮN BẤT BIẾN CHỐNG ẢO GIÁC (ZERO-HALLUCINATION)

1. **CẤM DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**: Sử dụng trực tiếp `DbContext` và `DbSet<T>` trong Application Layer.
2. **CÔ LẬP TUYỆT ĐỐI DATABASE (DATABASE-PER-SERVICE)**: Không query trực tiếp DB của service khác.
3. **CẤU HÌNH PORT LÀ BẤT BIẾN**: Dải port HTTP/REST `8000`-`8008` và DB `5433`-`5440` là cố định.
4. **QUY TẮC BẤT BIẾN: CẤM SỬ DỤNG gRPC CHO GIAO TIẾP ĐỒNG BỘ — 100% SỬ DỤNG RESTFUL HTTP/JSON**:
   - **Tuyệt đối KHÔNG sử dụng gRPC cho các dịch vụ giao tiếp đồng bộ**: Loại bỏ và cấm sử dụng gRPC giữa ApiGateway và các Microservices backend, cũng như giữa các Microservices nội bộ với nhau. Toàn bộ giao tiếp đồng bộ chuyển dịch hoàn toàn sang chuẩn **RESTful HTTP/JSON**.
   - **Chuẩn hóa RESTful API**:
     + Đường dẫn API: `/api/v1/{resource}`.
     + Phương thức HTTP chuẩn RFC 9110 (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
     + Dữ liệu trả về bọc chuẩn `ApiResponse<T>`, `ApiResponse<PagedData<T>>` hoặc `204 NoContent`.
     + Toàn bộ mã lỗi định dạng `SCREAMING_SNAKE_CASE` và câu thông báo tiếng Anh chuẩn Sentence case theo Nguyên tắc 5.
   - **Giao tiếp bất đồng bộ**: Tiếp tục sử dụng RabbitMQ qua MassTransit (Event-driven / Outbox Pattern / Saga).
5. **CẤM TỰ Ý SỬA ĐỔI BIẾN MÔI TRƯỜNG, SECRET VÀ KEY BÍ MẬT (MANDATORY HUMAN-IN-THE-LOOP FOR SECRETS)**:
   - **Tuyệt đối CẤM mọi AI Coding Agent tự ý sửa đổi, thay thế, xóa hoặc ghi đè các biến môi trường (`.env`, `.env.*`), Connection Strings, API Keys, JWT Secrets, chứng chỉ hoặc bất kỳ thông tin bí mật (credentials/secrets) nào trong toàn bộ hệ thống.**
   - **Bắt buộc phải xin ý kiến và nhận được sự đồng ý rõ ràng (explicit approval) từ người dùng trước khi thực hiện bất kỳ thay đổi nào liên quan đến biến môi trường hoặc tài khoản bí mật.**
   - Khi phát hiện cấu hình môi trường, connection string hoặc secret key có vấn đề hoặc cần cập nhật, Agent **CHỈ ĐƯỢC PHÉP báo cáo hiện trạng, đề xuất phương án và chờ người dùng xác nhận**, tuyệt đối không tự ý can thiệp.

---

## 💬 NGUYÊN TẮC 5: QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG (MANDATORY ERROR RULES)

Tất cả các thông báo lỗi (Error Messages, Exceptions, ProblemDetails, Validation Errors, Response Details) trong toàn bộ hệ thống Nexus Microservices và API Gateway **BẮT BUỘC** phải tuân theo 3 nguyên tắc sau:
1. **Ngôn ngữ (100% English)**: Toàn bộ thông báo lỗi phải được viết bằng tiếng Anh. Tuyệt đối không dùng tiếng Việt trong chuỗi thông báo lỗi trả về cho client.
2. **Quy cách viết hoa (Sentence case)**: Viết hoa duy nhất chữ cái đầu câu, các từ tiếp theo viết thường (ngoại trừ tên riêng, từ viết tắt hoặc định danh kỹ thuật như `ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`...).
   - ✅ Đúng: `"Email is already registered in the system."`
   - ✅ Đúng: `"OTP code has expired or does not exist."`
   - ✅ Đúng: `"OTP code is invalid."`
   - ✅ Đúng: `"This OTP code has already been used."`
   - ✅ Đúng: `"Username, valid email, and password with at least 8 characters are required."`
   - ❌ Sai: `"Lỗi mã OTP không hợp lệ"` (Không dùng tiếng Việt)
   - ❌ Sai: `"invalid email address"` (Chữ cái đầu không viết hoa)
   - ❌ Sai: `"INVALID EMAIL ADDRESS"` (Cấm viết hoa toàn bộ)
   - ❌ Sai: `"Invalid Email Address Provided"` (Không dùng Title Case)
3. **Mã lỗi (Error Codes — SCREAMING_SNAKE_CASE)**: Mã lỗi luôn viết hoa toàn bộ và nối bằng dấu gạch dưới:
   - Ví dụ: `EMAIL_ALREADY_EXISTS`, `OTP_EXPIRED`, `OTP_INVALID`, `OTP_ALREADY_USED`, `USER_NOT_FOUND`, `VAL_INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`.

---

## 🎯 NGUYÊN TẮC 6: ĐIỀU KIỆN HOÀN THÀNH NHIỆM VỤ (DEFINITION OF DONE)

Một task của AI Agent chỉ được coi là hoàn tất khi:
- [ ] Đã lập Plan chi tiết trước khi thực hiện.
- [ ] Tuân thủ nguyên tắc một chiều (Inward-Only), không có liên kết trỏ ngược ra ngoài repo.
- [ ] `dotnet build <Solution>.sln -c Release` thành công 100% (0 error).
- [ ] `dotnet test <Solution>.sln -c Release` vượt qua 100% các bài kiểm thử.
- [ ] Trạng thái Git sạch, không commit file rác (`bin/`, `obj/`, `.vs/`, `.idea/`).

---

## 🧪 NGUYÊN TẮC 7: HIỆN TRẠNG HỆ THỐNG (BẮT BUỘC ĐỌC TRƯỚC KHI CODE)

> Số liệu dưới đây được đo bằng `.tools/audit/audit.py` + đọc toàn bộ **511 file `.cs` / 20.612 dòng** của 9 repo (ngày 2026-10-24). Đây là **sự thật đã kiểm chứng**, không phải mô tả kiến trúc.

**Điểm audit: 176 phát hiện — P0 42, P1 23, P2 111.** Chi tiết: `docs/plans/SCORECARD.md`, `docs/plans/FIX_BACKLOG.md`, `docs/plans/audit/*_AUDIT.md`.

1. **Bề mặt dịch vụ**: 5/9 service (Auction, Catalog, Commerce, Fulfillment, Notification) **không có gRPC server** — chỉ `GET /health`. Ngoại lệ duy nhất là **Catalog**: ngoài `/health` còn **13 action REST mock** (`Catalog.Api/Controllers/{Products,Categories,Inventory}Controller.cs`, `Program.cs:69 app.MapControllers()`) — REST chạy được nhưng bind thẳng `MockCatalogStore`, không đi qua Application Layer và **0/13 rpc gRPC**. Chỉ User/Log/Wallet có gRPC server thật.
2. **Hợp đồng**: 4 bản `shop.proto` / 3 hash; Gateway chỉ có 1 client (`users`). Không có nguồn sự thật duy nhất ⇒ **cấm sửa `shop.proto`** khi chưa chốt (xem `specs/04` §1).
3. **Auth**: Gateway validate JWT nhưng **không service nào phát JWT**; `UsersApi/Login` chưa implement; 8 backend không có authentication và tin header `x-user-id`.
4. **Trace/Observability**: `x-trace-id` chỉ được set ở Gateway, **0 backend đọc**; OTel package chỉ có ở Gateway/Log/Wallet (6 service có config nhưng không có package ⇒ config chết).
5. **Event bus**: chỉ **1 đường publish còn sống** (`User` → `SendOtpEmailIntegrationEvent`; 4 lời gọi `Publish` trong `Wallet/.../StockReservedConsumer.cs` nằm trong consumer không bao giờ chạy); 6/8 event trong `specs/04` không tồn tại trong code; Saga chưa triển khai.
6. **Test**: chỉ 3/9 repo có test project (Gateway 98 case, User 9 case, Notification 2 case). `dotnet build` 9/9 pass, nhưng **6/9 repo 0 test**.
7. **Bí mật**: JWT key thật trong `ApiGateway/Nexus.Gateway/appsettings.json:26`; `MatkhaucuaTui123@` trong 6 `Infrastructure/DependencyInjection.cs`, 8 `.env.example`, 8 `README.md`, 8 `docker-compose.yml`.
8. **Hạ tầng local**: image `postgres:16-alpine` trên máy dev bị hỏng (`exec format error`, script entrypoint 0 byte) ⇒ 8 container DB `Restarting (255)`; `/health` vẫn báo Healthy khi DB chết. Xem `docs/plans/SETUP_PHASE_PLAN.md`.

**Quy tắc rút ra:**
- **Code nghiệp vụ mới CHỈ được bắt đầu sau khi hoàn tất Track S** trong `docs/plans/SETUP_PHASE_PLAN.md` (proto SoT, secret, port, CI, image Postgres).
- Mọi tài liệu khi sửa **phải có banner trạng thái** theo `docs/plans/DOC_UPDATE_PROTOCOL.md` (✅ CÓ / ⚠️ MỘT PHẦN / ❌ CHƯA CÓ + nguồn sự thật + ngày).
- Không được coi `/health` là bằng chứng “service hoạt động”: nó không kiểm tra DB.

---

## 📝 NGUYÊN TẮC 8: QUY CHUẨN ĐÓNG PHIÊN, BÁO CÁO & LƯU TRỮ KẾ HOẠCH (.AGENTS/PLAN VÀ .AGENTS/HISTORY)

> **BẮT BUỘC ĐỌC ĐẦU VÀ CUỐI MỖI PHIÊN LÀM VIỆC**: Quy tắc này áp dụng cho toàn bộ AI Coding Agents mỗi khi kết thúc một nhiệm vụ được giao, kết thúc phiên làm việc, hoặc khi có lệnh hoãn/tạm dừng.

### 1. Quy chuẩn Lưu trữ Kế hoạch Chuẩn tại `.agents/plan/`
- **Thời điểm ghi**: Khi một kế hoạch được chốt sau thảo luận dài, hoặc khi hoàn thành một chuỗi công việc được giao (không phải nháp ban đầu của Planner, mà là bản kế hoạch chuẩn cuối cùng làm nguồn sự thật).
- **Mã Plan (ID)**: Bắt buộc chứa mốc thời gian tạo và mục tiêu giải quyết. Định dạng: `PLAN-YYYYMMDD-HHMM-[TEN_VAN_DE].md` (ví dụ: `PLAN-20261026-0200-API-GATEWAY-MOCK.md`).
- **Nội dung bắt buộc trong file Plan**:
  1. **Mã Plan (ID)** & Thời gian khởi tạo/chốt.
  2. **Vấn đề cần giải quyết**: Mô tả vấn đề tổng thể mà người dùng đưa ra.
  3. **Hướng giải quyết**: Kiến trúc và phương án kỹ thuật đã thống nhất.
  4. **Danh mục Task & Checklist**: Chia nhỏ thành các task con rõ ràng, có trạng thái checklist `[x]` (đã xong) và `[ ]` (chưa xong).

### 2. Quy chuẩn Báo cáo Nhật ký tại `.agents/history/`
Mỗi lần kết thúc/hoãn phiên, bắt buộc tạo file nhật ký theo ngày: `.agents/history/YYYY-MM-DD_session_summary.md` gồm 5 phần:
1. **Miêu tả tổng thể công việc**: Tóm tắt phạm vi công việc đã thực hiện trong phiên/prompt.
2. **Phân tích & Nghiên cứu**: Lý do kỹ thuật, nguyên nhân gốc rễ, đối chiếu tài liệu và kiến trúc.
3. **Liên kết Kế hoạch**: Bắt buộc trỏ tới Mã Plan (`PLAN-ID`) tương ứng trong `.agents/plan/` (dù đang làm dở hay đã hoàn thành).
4. **Báo cáo Cá nhân từng Thành viên**:
   - Ghi rõ: `Tên (Role/Chức vụ)`.
   - Các vấn đề đã làm trong ngày/prompt.
   - Vấn đề gặp phải & Cách giải quyết.
   - Các vấn đề chưa làm xong & Việc cần làm tiếp theo.
5. **Báo cáo Tổng thể Toàn Team**:
   - Vấn đề tổng thể sếp giao cho team.
   - Các vấn đề đã xử lý thành công.
   - Các vấn đề gặp phải và cách giải quyết của team.
   - Các phần việc/plan chưa xong, cần hoàn thành trong phiên kế tiếp.

