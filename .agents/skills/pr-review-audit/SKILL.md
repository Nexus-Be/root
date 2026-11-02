---
name: pr-review-audit
description: Audit and review Pull Requests across Nexus microservices. Validates API documentation, thin controllers, and business logic against canonical standards. Generates persistent 3-file audit reports in .agents/review/{PR_SLUG}/ with human-only logic sign-off checklists, enforcing format-only fixes upon user approval.
---

# Pull Request Review and Audit Skill (`pr-review-audit`)

This skill governs the standardized quality audit and review process for Pull Requests across the Nexus ecosystem. It ensures that every code change merged via PR strictly adheres to architectural conventions, boundary standards, and documentation invariants.

---

## 1. Rào Chắn Kích Hoạt & Ràng Buộc Bất Biến (Invariant Guardrails)

### 1.1 Rào Chắn Chỉ Dùng Khi Review Pull Request (PR-Only Trigger Guard)
* **QUY TẮC BẮT BUỘC:** Kỹ năng này **CHỈ ĐƯỢC PHÉP CHẠY** khi người dùng (Sếp) yêu cầu rõ ràng về việc review Pull Request (ví dụ: *"review pull request này"*, *"review PR #105"*, *"chạy pr-review-audit"*).
* **TUYỆT ĐỐI CẤM** tự ý kích hoạt kỹ năng này trong các tác vụ thông thường (code tính năng mới, refactor nội bộ, fix bug trực tiếp, nghiên cứu tài liệu).

### 1.2 Rào Chắn Kiểm Tra Nhánh Git (Checkout Preflight Verification)
Trước khi thực hiện bất kỳ thao tác phân tích hay quét diff nào, Agent **BẮT BUỘC PHẢI KIỂM TRA** trạng thái checkout của git worktree:
1. Chạy lệnh kiểm tra nhánh hiện tại: `git rev-parse --abbrev-ref HEAD` hoặc `git status`.
2. **Điều kiện Dừng (Hard Stop):**
   * Nếu nhánh hiện tại đang là `dev`, `main` (hoặc nhánh cơ sở) mà chưa chứa các commit của PR: **DỪNG LẠI NGAY LẬP TỨC**.
   * Yêu cầu người dùng checkout sang nhánh của Pull Request cần review trước khi tiếp tục:
     > *"Bạn hiện đang ở nhánh `dev`. Vui lòng checkout sang nhánh của Pull Request (ví dụ: `git checkout feature/PR-105-add-stock`) trước khi thực hiện review."*
3. Chỉ khi nhánh hiện tại đúng là nhánh của PR thì mới bắt đầu Pha 1.

### 1.3 Quy Tắc Ký Duyệt Nghiệp Vụ Của Con Người (Human-Only Logic Sign-off)
* **Agent tuyệt đối KHÔNG ĐƯỢC TỰ Ý ĐÁNH DẤU `[x]`** vào các checklist kiểm tra về logic, usecase và tính đúng đắn của nghiệp vụ.
* Toàn bộ checklist trong báo cáo `03_LOGIC_BUSINESS_AUDIT.md` và phần nghiệm thu logic phải được giữ nguyên trạng thái chưa tích (`[ ]`) để **CON NGƯỜI (Reviewer / Sếp)** trực tiếp kiểm tra và đánh dấu xác nhận.
* Agent chỉ được phép đánh dấu `[x]` vào các mục format/conventions sau khi đã hoàn thành sửa chữa ở Pha 2.

### 1.4 Rào Chắn Tuyệt Đối Không Sửa Logic (Strict Format-Only Fix Guardrail)
* Nếu phát hiện lỗi logic nghiệp vụ, sai sót usecase, hoặc thiếu sót luồng dữ liệu: Agent **CHỈ ĐƯỢC GHI CHÚ (NOTE)** chi tiết vị trí `file:line`, nguyên nhân và khuyến nghị vào báo cáo để tác giả PR tự sửa.
* Agent **TUYỆT ĐỐI KHÔNG TỰ SỬA LOGIC** hoặc cấu trúc nghiệp vụ của code.

### 1.5 Báo Cáo Lưu Trữ Vĩnh Viễn & Không Commit Lên Git
* Thư mục báo cáo review tại `.agents/review/` là hồ sơ kiểm định chất lượng, **TUYỆT ĐỐI KHÔNG ĐƯỢC XÓA** sau khi hoàn thành sửa format.
* Toàn bộ thư mục `.agents/review/` được đưa vào `.gitignore` ở Root và ở từng submodule service để lưu trữ hoàn toàn ở local, không bị commit hay đẩy lên remote repository.

### 1.6 Quy Tắc Định Vị Thư Mục Báo Cáo Theo Service (Service-Scoped Review Directory Invariant)
* **NGUYÊN TẮC BẮT BIẾN:** Khi review Pull Request của bất kỳ microservice nào (`src/Services/{Service}/`), thư mục báo cáo `.agents/review/` **BẮT BUỘC PHẢI ĐƯỢC TẠO NỘI BỘ BÊN TRONG CHÍNH SERVICE ĐÓ** tại đường dẫn:
  `src/Services/{Service}/.agents/review/{PR_CODE}-{GIT_AUTHOR}-{COMMIT_SUMMARY_SLUG}/`
* **TUYỆT ĐỐI CẤM** tạo thư mục review tại Root repository (`Nexus-Be/.agents/review/`) khi đối tượng review là một service submodule. Báo cáo kiểm định của service nào phải luôn nằm trọn vẹn bên trong submodule của chính service đó, bảo đảm 100% tính tự cung tự cấp (Self-contained) và nguyên tắc Inward-Only.
* *Chỉ khi Pull Request là thay đổi hạ tầng dùng chung toàn cục hoặc tài liệu cấp Root (`Nexus-Be`)* thì thư mục review mới được đặt tại Root `.agents/review/`.

### 1.7 Quy Chuẩn Thông Điệp Commit & Tiêu Đề PR (Zero Emoji / Icon Rule - Rule 18)
* **CẤM TUYỆT ĐỐI EMOJI / ICON:** Tiêu đề PR và toàn bộ commit messages tuyệt đối không chứa emoji hoặc icon (`✨`, `🐛`, `🔧`, `♻️`, `🧪`, `📝`, `⚡`, `👷`, `💄`, `🔒`, `🚧`...).
* **Chuẩn 100% Conventional Commits thuần túy:** Bắt buộc định dạng `<type>(<scope>): <subject>` hoặc `<type>: <subject>` bằng tiếng Anh chuẩn, thể mệnh lệnh, chữ thường, không chấm câu cuối dòng.
* Kiểm tra git log của PR (`git log $(git merge-base HEAD origin/dev)..HEAD --oneline`) để bảo đảm mọi commit trong PR đều tuân thủ.

---

## 2. Cấu Trúc Thư Mục & 3 File Báo Cáo

Báo cáo review được tạo ngay trong thư mục `.agents/review/` của chính service đang được review:
```text
src/Services/{Service}/.agents/review/{PR_CODE}-{GIT_AUTHOR}-{COMMIT_SUMMARY_SLUG}/
├── 01_API_DOCS_AUDIT.md        <-- Phần 1: Kiểm tra tài liệu API nội bộ
├── 02_CONTROLLER_AUDIT.md      <-- Phần 2: Kiểm tra chuẩn Thin Controller
└── 03_LOGIC_BUSINESS_AUDIT.md  <-- Phần 3: Kiểm tra Logic, Usecase & Validation
```

### 2.1 Quy Ước Đặt Tên Thư Mục
`{PR_CODE}-{GIT_AUTHOR}-{COMMIT_SUMMARY_SLUG}`
* **PR_CODE:** Trích xuất từ tên branch (ví dụ: `feature/PR-105-add-stock` -> `PR-105`), commit message, hoặc tham số người dùng cung cấp. Nếu không có số PR thì đặt `PR-LOCAL-{YYYYMMDD}`.
* **GIT_AUTHOR:** Trích xuất từ `git log -1 --pretty=format:'%an'`, chuyển thành chữ thường, không dấu, nối bằng dấu gạch ngang (ví dụ: `yuikiri`).
* **COMMIT_SUMMARY_SLUG:** 3 đến 5 từ khóa ngắn gọn từ thông điệp commit mới nhất (ví dụ: `add-product-variant-stock`).
* *Ví dụ đầy đủ:* `.agents/review/PR-105-yuikiri-add-product-variant-stock/`

---

## 3. Nội Dung Chi Tiết 3 File Báo Cáo

### File 1: `01_API_DOCS_AUDIT.md` (Kiểm Tra Tài Liệu API)
Tập trung đối soát tính chuẩn hóa và ăn khớp giữa tài liệu API nội bộ (`docs/api/`) với code C#:
```markdown
# AUDIT BÁO CÁO PHẦN 1: TÀI LIỆU API (API DOCS)

- **PR:** {PR_CODE} - {GIT_AUTHOR}
- **Ngày audit:** YYYY-MM-DD
- **Phạm vi kiểm tra:** Danh sách các endpoint/file tài liệu API bị thay đổi trong PR

---

## Chi tiết từng API

### API 1: [{HTTP_METHOD}] {ROUTE_PATH}
- **File tài liệu:** `docs/api/{Feature}/{METHOD}_{ENDPOINT}.md`
- **File C# đối soát:** `Controllers/{Feature}Controller.cs` & `Services/{Feature}/`

#### Checklist Đánh Giá:
- [ ] File tài liệu tồn tại đúng thư mục và đặt tên chuẩn `{METHOD}_{ENDPOINT_SLUG}.md`.
- [ ] Tuân thủ đầy đủ 5 phần của `SERVICE_API_DOC_TEMPLATE.md`.
- [ ] Mục 1 (Code Trace): Khớp chính xác tên Controller, Action, Service Interface, và Entity table.
- [ ] Mục 2 (Input & Validation): Khớp chính xác tên trường, kiểu C#, nullability, và DataAnnotations (`[Required]`, `[StringLength]`, `[Range]`).
- [ ] Mục 3 (Response Contract): Khớp chính xác C# Response Record DTO và JSON mẫu dạng Pure DTO (không bọc `ApiResponse<T>`).
- [ ] Mục 4 (Enum Mapping): Khớp chính xác giá trị số nguyên DB (0, 1, 2) và chuỗi PascalCase API với `{Service}.Domain/Enums/`.
- [ ] Mục 5 (Error Matrix): Khớp các mã lỗi `SCREAMING_SNAKE_CASE`, message English sentence-case với các exception được ném trong C#.

#### Ghi chú & Đánh giá:
- Trạng thái: [PASS] / [WARN - FORMAT] / [FAIL - LOGIC NOTE]
- Chi tiết vi phạm (nếu có): Cụ thể dòng và nội dung lệch pha giữa doc và code C#.
```

---

### File 2: `02_CONTROLLER_AUDIT.md` (Kiểm Tra Chuẩn Controller)
Tập trung kiểm tra tầng chuyển tiếp HTTP Transport Boundary:
```markdown
# AUDIT BÁO CÁO PHẦN 2: THIN CONTROLLER

- **PR:** {PR_CODE} - {GIT_AUTHOR}
- **Ngày audit:** YYYY-MM-DD
- **Phạm vi kiểm tra:** Toàn bộ Controller bị chỉnh sửa trong PR

---

## Chi tiết từng Controller Action

### Controller: `{Feature}Controller.cs` -> Action: `{ActionName}`
- **Đường dẫn file:** `{Service}.Api/Controllers/Public/{Feature}Controller.cs`
- **Route Endpoint:** `[{HTTP_METHOD}] /api/v1/{plural-collection}/...`

#### Checklist Đánh Giá:
- [ ] Vị trí đặt tại `{Service}.Api/Controllers/Public/` và kế thừa `ControllerBase`.
- [ ] Ghép cặp 1-to-1: Chỉ inject duy nhất `I{Feature}Service` (hoặc `ISender` trong WalletService). Không inject DbContext.
- [ ] Quy chuẩn định danh route: 100% danh từ số nhiều viết thường (`/api/v1/products`, `/api/v1/orders`). Ngoại lệ duy nhất: `/api/v1/me`, `/api/v1/auth`.
- [ ] Cấm trùng lặp Route alias: Mỗi action chỉ khai báo đúng 1 route attribute chính thức.
- [ ] Chuẩn hóa XML comment: Single-line `<summary>` trực tiếp trên action method; không viết banner nhiều dòng.
- [ ] Trả về Pure DTO: Trả về trực tiếp DTO qua `Ok(...)`, `StatusCode(201, ...)`, hoặc `NoContent()`. Tuyệt đối cấm tự bọc `ApiResponse<T>` hay dùng `ResultFilter`.
- [ ] Bảo vệ danh tính & Quyền sở hữu: Đọc `userId` từ `HttpContext.GetUserId()`; tuyệt đối không tin tưởng `userId`/`sellerId`/`buyerId` gửi từ client qua query hay body.
- [ ] Truyền CancellationToken đầy đủ vào mọi lệnh async của Service/Sender.

#### Ghi chú & Đánh giá:
- Trạng thái: [PASS] / [WARN - FORMAT] / [FAIL - LOGIC NOTE]
- Chi tiết vi phạm (nếu có): file:line và giải thích vi phạm.
```

---

### File 3: `03_LOGIC_BUSINESS_AUDIT.md` (Kiểm Tra Logic, Usecase & Nghiệp Vụ)
Tập trung kiểm tra tầng Application, Domain, Validation và tính đúng đắn nghiệp vụ:
```markdown
# AUDIT BÁO CÁO PHẦN 3: LOGIC, USECASE & VALIDATION

- **PR:** {PR_CODE} - {GIT_AUTHOR}
- **Ngày audit:** YYYY-MM-DD
- **Phạm vi kiểm tra:** Toàn bộ Service, Domain Entity, Request/Response DTOs trong PR

---

## Chi tiết từng Use Case / Feature

### Feature: `{FeatureName}` -> Function: `{FunctionName}`
- **Vị trí Service:** `{Service}.Application/Services/{Feature}/{Feature}Service.cs`
- **Vị trí Request/Response:** `{Feature}Requests.cs` / `{Feature}Responses.cs`

#### Checklist Đánh Giá Kỹ Thuật (Agent Khảo Sát - Checkbox do Con người xác nhận):
- [ ] Validation biên: Request record DTO khai báo đầy đủ DataAnnotations; không viết if/else validate thủ công trong Controller.
- [ ] Phân trang hệ thống: Danh sách phân trang nhận `PageQuery`, tính toán 100% tại SQL qua `.Skip(...).Take(...)` và `.CountAsync()`, trả về `PagedData<T>`.
- [ ] Cô lập Database: Inject `I{Service}DbContext` và truy vấn trực tiếp `DbSet<T>`. Cấm dùng Repository Pattern over EF Core.
- [ ] Xóa mềm (Soft Delete): Tôn trọng cờ `IsDeleted` và Global Query Filter.
- [ ] Nhật ký kiểm toán (Audit Log): Thao tác nhạy cảm ghi qua `_dbContext.AddAuditLog(...)`. Không dùng `_logger` thay thế audit log.
- [ ] Độ chính xác tiền tệ: Trường tiền tệ sử dụng `decimal` với cấu hình `HasPrecision(18, 2)`.
- [ ] Bất biến số dư ví (Riêng WalletService): Kiểm tra `Balance >= Amount`, cấm để số dư âm.
- [ ] Bất biến Append-Only (Riêng LogService): Bảng `Logs` chỉ `INSERT`/`SELECT`, cấm sửa hoặc xóa.

#### Ghi Chú Lỗi Logic & Nghiệp Vụ (AI Agent Note Only - Không Tự Sửa):
- [NOTE - LOGIC ISSUE] `{file:line}`: Mô tả chi tiết sai sót logic hoặc vi phạm nghiệp vụ để tác giả PR xem và sửa.

---

## Nghiệm Thu Nghiệp Vụ (Dành Riêng Cho Con Người / Human Sign-off Only)
> **LƯU Ý:** Agent tuyệt đối KHÔNG ĐƯỢC tự ý đánh dấu `[x]` vào các mục dưới đây. Chỉ con người (Reviewer/Sếp) mới có quyền kiểm tra và tích hoàn thành.

- [ ] Logic nghiệp vụ xử lý đúng yêu cầu của Use Case.
- [ ] Không phát sinh lỗi hổng bảo mật hoặc gian lận dữ liệu.
- [ ] Luồng giao dịch đảm bảo tính toàn vẹn (ACID / Transaction).
- [ ] Unit & Integration Tests bao phủ đầy đủ happy path và edge cases.
- [ ] Nghiệm thu chính thức: Pull Request đủ điều kiện merge.
```

---

## 4. Quy Trình Vận Hành 2 Pha Chi Tiết

### Pha 1: Quét Diff & Khởi Tạo Báo Cáo (100% Read-Only)
1. **Xác nhận Intent:** Kiểm tra người dùng có đang yêu cầu review Pull Request hay không.
2. **Kiểm tra Nhánh:** Chạy `git rev-parse --abbrev-ref HEAD`. Nếu chưa ở nhánh PR, dừng lại và hướng dẫn checkout.
3. **Tính toán Diff:** Chạy `git diff $(git merge-base HEAD origin/dev)...HEAD --name-only` để lấy danh sách các file thay đổi.
4. **Phân tích Mã Nguồn:**
   * Đọc và đối soát các file tài liệu API (`docs/api/`).
   * Đọc các Controller thay đổi (`Controllers/Public/`).
   * Đọc các Service, DTO, Entity thay đổi (`Services/`, `Domain/`, `Entities/`).
5. **Tạo Thư Mục Báo Cáo:**
   * Tạo thư mục báo cáo tại `src/Services/{Service}/.agents/review/{PR_SLUG}/` (đối với PR của microservice) hoặc `.agents/review/{PR_SLUG}/` (đối với PR cấp Root).
   * Ghi 3 file: `01_API_DOCS_AUDIT.md`, `02_CONTROLLER_AUDIT.md`, `03_LOGIC_BUSINESS_AUDIT.md` với toàn bộ checklist trống `[ ]`.
6. **Báo Cáo Tóm Tắt:**
   * Hiển thị bảng tóm tắt ngắn gọn các vi phạm (Format Warnings và Logic Notes) cho người dùng.

### Pha 2: Sửa Format Có Kiểm Soát (Khi Người Dùng Phê Duyệt)
1. **Hỏi Người Dùng:** Hỏi người dùng có muốn lập Plan sửa các mục vi phạm format/conventions đã phát hiện không.
2. **Nguyên Tắc Sửa:**
   * **ĐƯỢC PHÉP SỬA:** Lỗi format, convention (thêm XML summary 1 dòng, sửa casing enum/DTO, chuẩn hóa route attribute số nhiều, sắp xếp using).
   * **TUYỆT ĐỐI CẤM SỬA:** Logic nghiệp vụ, luồng xử lý, thuật toán, câu lệnh truy vấn DB, hoặc điều kiện if/else nghiệp vụ. Mọi vấn đề logic giữ nguyên ghi chú `[NOTE - LOGIC ISSUE]` trong `03_LOGIC_BUSINESS_AUDIT.md`.
3. **Cập Nhật Checklist:** Sau khi sửa xong các mục format, cập nhật checklist format tương ứng thành `[x]`.
4. **Bảo Tồn Báo Cáo:** Không xóa thư mục `.agents/review/`.
