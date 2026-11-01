---
name: service-api-doc
description: Pre-code API documentation standard for Nexus backend microservices. Mandates drafting a service-level technical API doc before coding, referencing existing domain entities, enums, DTOs, and error patterns for system-wide consistency. Governs pure DTO contracts, validation attributes, and RFC 9110 error matrices inside each service repository.
---

# Service-Level API Pre-Code Documentation Skill

This skill governs the **mandatory pre-code documentation lifecycle** within each Nexus microservice. Before any C# code is written or modified for a REST endpoint, the developer or AI agent must create a technical API specification inside `src/Services/{Service}/docs/api/`.

---

## 1. The Two-Stream Documentation Architecture

The Nexus ecosystem maintains two distinct, decoupled documentation streams:

| Đặc tính | Stream 1: Service-Level Internal Doc | Stream 2: Root Ecosystem Doc |
| :--- | :--- | :--- |
| **Vị trí lưu trữ** | `src/Services/{Service}/docs/api/` | `docs/api/B_none/` & `docs/api/A_Active/` |
| **Thời điểm lập** | **BẮT BUỘC TRƯỚC KHI VIẾT CODE (Pre-Code)** | **Sau khi hoàn thành toàn bộ tính năng** |
| **Điều kiện kích hoạt** | Mọi API mới hoặc sửa đổi trong Service | **Chỉ làm khi có yêu cầu trực tiếp từ Người dùng** |
| **Góc nhìn (Perspective)** | Kỹ thuật nội bộ Service (Developer / Agent) | Tích hợp toàn hệ thống qua Gateway / Frontend |
| **Định dạng dữ liệu trả về** | **Pure DTO** hoặc `PagedData<T>` (không envelope) | `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>` |
| **Phạm vi tham chiếu** | **100% Inward-Only** (chỉ trỏ trong Service) | Toàn hệ thống (Gateway, Submodules, Frontend) |

> **Quy tắc Bất biến:** Agent làm việc trong Service submodule (`src/Services/{Service}/`) **TUYỆT ĐỐI KHÔNG** tạo, sửa, hoặc trỏ tới file tại `docs/api/` ở Root.

---

## 2. Quy trình 3 Bước Tra cứu Source of Truth Trước Khi Lập Doc

Để đảm bảo tính nhất quán và tái sử dụng tối đa, trước khi điền thông tin vào tài liệu API, AI Agent bắt buộc phải thực hiện 3 bước tra cứu trong mã nguồn nội bộ của Service:

### Bước 1: Tra cứu Thực thể Domain (`{Service}.Domain/Entities/`)
- Đọc các entity liên quan tại `{Service}.Domain/Entities/` và `{Service}.Domain/ValueObjects/`.
- Xác định chính xác kiểu dữ liệu C# (`Guid`, `decimal`, `DateTimeOffset`), tính chất nullable (`?`), và ràng buộc khóa chính/khóa ngoại.
- Đảm bảo các trường DTO phản ánh đúng cấu trúc thực thể mà không để lộ các thuộc tính nội bộ của EF Core (`xmin`, navigation properties).

### Bước 2: Tra cứu Bảng mã Enum (`{Service}.Domain/Enums/`)
- Mở thư mục `{Service}.Domain/Enums/` để tra cứu các enum liên quan.
- Xác định giá trị số nguyên trong PostgreSQL (`0`, `1`, `2`...) và tên chuỗi C# dạng PascalCase (`Active`, `PendingVerification`).
- Điền bảng ánh xạ vào **Mục 4.1 của Service Doc**. Tuyệt đối không tự bịa đặt enum mới nếu đã có enum tương đương.

### Bước 3: Tra cứu Mẫu DTO & Xử lý Lỗi Có Sẵn (`{Service}.Application/`)
- Rà soát các thư mục `Services/{ExistingFeature}/` (hoặc `Features/` trong WalletService) để:
  * Kế thừa cấu trúc đặt tên DTO: `{Action}Request`, `{Action}Response`, `{Item}Dto`.
  * Tái sử dụng chuẩn phân trang: `PageQuery` (tham số `page`, `pageSize`) và `PagedData<T>`.
  * Kế thừa mã lỗi RFC 9110 đã có trong service (`{RESOURCE}_NOT_FOUND`, `VAL_INVALID_INPUT`, `FORBIDDEN`, `UNAUTHORIZED`).

---

## 3. Quy chuẩn Cấu trúc File Tài liệu Service

Tài liệu API nội bộ phải được lưu theo quy tắc:
* **Đường dẫn:** `src/Services/{Service}/docs/api/{Feature}/{HTTP_METHOD}_{ENDPOINT_SLUG}.md`
  *(Ví dụ: `docs/api/Users/POST_USERS_REGISTER.md`, `docs/api/Wallets/POST_WALLETS_WITHDRAWALS.md`)*
* **Template mẫu:** Lấy từ `docs/api/SERVICE_API_DOC_TEMPLATE.md` nội bộ của service.
* **Gồm 5 phần bắt buộc:**
  1. **Routing & RBAC:** Method, plural route, controller, interface/handler.
  2. **Input & Validation Schema:** Route/Query params, Request record DTO kèm DataAnnotations.
  3. **Response Contract (Pure DTO):** C# Record DTO và JSON output thuần (không bọc `ApiResponse<T>`).
  4. **RFC 9110 Error Matrix:** Bảng mã lỗi `SCREAMING_SNAKE_CASE`, message English sentence-case, trigger conditions, và bảng Enum.
  5. **Pre-Code Plan & Checklist:** Kế hoạch thực thi 6 bước nghiệp vụ và checklist kiểm chứng.

---

## 4. Các Rào Chắn Bất Biến (Non-Negotiables)

1. **Pure DTO tại Microservice:** Microservice backend tuyệt đối không bọc kết quả qua `ApiResponse<T>`. Controller trả về trực tiếp `Ok(response)`, `StatusCode(201, response)` hoặc `NoContent()`.
2. **100% Plural Route Convention:** Endpoint tài nguyên bắt buộc là danh từ số nhiều viết thường (`/api/v1/users`, `/api/v1/products`, `/api/v1/orders`). Ngoại lệ duy nhất: `/api/v1/me` và `/api/v1/auth`.
3. **Chuẩn Thông báo Lỗi:** 100% tiếng Anh, Sentence case cho `message` (chỉ viết hoa chữ đầu câu), SCREAMING_SNAKE_CASE cho `errorCode`. Tuyệt đối cấm tiền tố `ERR_`.
4. **Phân trang tại Database:** Mọi danh sách phân trang phải nhận `page`, `pageSize` và trả về cấu trúc `PagedData<T>`. Phân trang tính toán 100% tại DB (`Skip`/`Take` và `CountAsync`), cấm Gateway cắt trang.
5. **Ngoại lệ WalletService (Đóng băng):** WalletService là service duy nhất sử dụng classic CQRS với MediatR. Tài liệu API của Wallet ghi nhận Command/Query + Handler tương ứng tại `Wallet.Application/Features/`, controller inject `ISender`. Cấm tạo `I{Feature}Service` facade.

---

## 5. Quy trình Vận hành Chi tiết (Step-by-Step Workflow)

Khi nhận yêu cầu thêm hoặc sửa một REST API:
1. **Khởi tạo Doc trước khi code:** Sao chép `SERVICE_API_DOC_TEMPLATE.md` vào `docs/api/{Feature}/{HTTP_METHOD}_{ENDPOINT_SLUG}.md`.
2. **Điền thông tin và tham chiếu:** Thực hiện 3 bước tra cứu Source of Truth, điền đầy đủ 5 mục của template.
3. **Lập Plan chi tiết:** Hoàn thiện mục 5.1 (Pre-Code Plan) mô tả rõ luồng xử lý từ Controller -> Service -> DB.
4. **Viết Code:** Tiến hành code C# theo đúng hợp đồng DTO và Error Matrix đã định nghĩa trong doc.
5. **Kiểm thử & Nghiệm thu nội bộ:** Chạy `dotnet test` vượt qua 100%. Tích các mục trong checklist 5.2 và chuyển trạng thái doc thành `✅ VERIFIED`.
