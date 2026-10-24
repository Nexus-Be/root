<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **root** (5272 symbols, 7914 relationships, 161 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/root/context` | Codebase overview, check index freshness |
| `gitnexus://repo/root/clusters` | All functional areas |
| `gitnexus://repo/root/processes` | All execution flows |
| `gitnexus://repo/root/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

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
- `specs/03_SECURITY_RBAC_DATA_GOVERNANCE.md`: JWT Bearer, ma trận phân quyền 5 roles, chuẩn RFC 9110.
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
3. **CẤU HÌNH PORT LÀ BẤT BIẾN**: Dải port HTTP/gRPC `8000`-`8008` và DB `5433`-`5440` là cố định.
4. **HỢP ĐỒNG PROTOBUF DUY NHẤT**: Mọi service phải tuân thủ hợp đồng Protobuf gốc trong `Contracts/shop.proto`.

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
