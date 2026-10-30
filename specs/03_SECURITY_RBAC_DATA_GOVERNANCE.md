# 03 — BẢO MẬT, PHÂN QUYỀN RBAC & QUY CHUẨN DỮ LIỆU (SECURITY & DATA GOVERNANCE)

> **Trạng thái triển khai (2026-10-30):** ✅ Chuẩn hóa bảo mật toàn diện — `UserService` chịu trách nhiệm duy nhất phát hành Token JWT (`AuthService.cs` và `JwtTokenGenerator.cs`), `ApiGateway` đóng vai trò Edge Reverse Proxy xác thực JWT, phân quyền RBAC, và chuyển tiếp các headers định danh (`x-user-id`, `x-user-roles`, `x-user-email`, `x-trace-id`) sang các microservices downstream.
> **Nguồn sự thật:** code (`User.Infrastructure/Services/Security/JwtTokenGenerator.cs`, `User.Api/Controllers/AuthController.cs`, `Nexus.Gateway/Security/SecurityConfiguration.cs`).
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này xác định ma trận phân quyền, vòng đời token JWT, cơ chế Edge Proxy và quy chuẩn định dạng phản hồi chuẩn quốc tế.

---

## 1. MA TRẬN PHÂN QUYỀN VAI TRÒ (RBAC MATRIX)

Hệ thống Nexus phân cấp **6 mức** vai trò (Roles) có tính kế thừa quyền hạn:

| Vai Trò (spec) | Cấp Độ | Tên thực tế trong code | Quyền Hạn Nghiệp Vụ | Trạng thái |
|:---|:---:|:---|:---|:---|
| **anonymous** | 0 | (không có role) | Người dùng vãng lai chưa đăng nhập. | ✅ Có (không cần token) |
| **buyer** | 1 | `Buyer` (seed/code) / `buyer` | Khách hàng đã đăng ký và xác thực tài khoản. | ✅ Đã hỗ trợ qua JWT Claims |
| **seller** | 2 | `Seller` (seed/code) / `seller` | Người bán hàng đã được duyệt tài khoản. | ✅ Đã hỗ trợ qua JWT Claims |
| **staff** | 3 | `Support Staff` (seed) / `staff` | Nhân viên vận hành sàn hỗ trợ xử lý sự cố. | ✅ Đã hỗ trợ qua JWT Claims |
| **admin** | 4 | `Administrator` (seed) / `admin` | Quản trị viên hệ thống toàn sàn. | ✅ Đã hỗ trợ qua JWT Claims |
| **gateway-admin** | 5 | `GatewayAdmin = "gateway-admin"` | Quản trị hạ tầng kỹ thuật Gateway. | ✅ Quản trị hạ tầng qua API Key / Policy |

---

## 2. VÒNG ĐỜI VÀ TIÊU CHUẨN TOKEN JWT

> **Trạng thái (2026-10-30):** ✅ Đã hiện thực cấp phát token tại `UserService` (`JwtTokenGenerator.cs` và `AuthService.cs`), bảo vệ mật khẩu bằng BCrypt có salt, cấp phát Access Token (HMAC-SHA256) và Refresh Token tự động.

- **Thuật toán ký**: HMAC-SHA256 với Secret Key tối thiểu 32 ký tự (cấu hình qua biến môi trường `JWT_SECRET_KEY` hoặc `Jwt:Key`).
- **Claims Bắt Buộc Trong Token**:
  - `sub`: UUID của người dùng (Subject).
  - `role`: Danh sách vai trò (`Buyer`, `Seller`, `Staff`, `Admin`).
  - `permission` / `permissions`: Danh sách mã quyền hạn chi tiết (PBAC - Permissions-Based Access Control) lấy từ các thực thể `RolePermission` và `Permission` của user.
  - `email`: Địa chỉ email của người dùng.
  - `iss`: Issuer (`Nexus.User` hoặc `http://localhost:8001`).
  - `aud`: Audience (`Nexus.Ecosystem` hoặc `shoppingcart-api`).
  - `exp`: Thời gian hết hạn (Epoch seconds).
- **Chuyển tiếp qua REST downstream**: Khi Client gửi `Authorization: Bearer <token>` lên Gateway, Gateway xác thực chữ ký token, trích xuất claims và forward nguyên vẹn các headers định danh sang microservice downstream:
  - `Authorization: Bearer <token>`
  - `x-user-id`: ID người dùng (UUID)
  - `x-user-roles`: Danh sách roles ngăn cách bởi dấu phẩy
  - `x-user-email`: Email người dùng
  - `x-user-permissions`: Danh sách các mã quyền (permissions) ngăn cách bởi dấu phẩy (ví dụ: `PRODUCT_CREATE,PRODUCT_UPDATE`)
  - `x-trace-id` & `traceparent`: Mã vết truy vết phân tán W3C
  - `idempotency-key`: Khóa chống lặp nếu client cung cấp.

---

## 3. CƠ CHẾ VẬN HÀNH GATEWAY (EDGE REVERSE PROXY)

Gateway vận hành dưới mô hình **Pure Edge Reverse Proxy**:
1. **Xác thực tập trung (Centralized Authentication)**:
   - Các endpoint yêu cầu phân quyền (`[Authorize]`) bắt buộc phải có JWT Token hợp lệ.
   - Chưa đăng nhập (không token) $\rightarrow$ trả về `401 Unauthorized` bọc trong `ApiErrorResponse`.
   - Token không đủ quyền theo Role $\rightarrow$ trả về `403 Forbidden` bọc trong `ApiErrorResponse`.
2. **Ủy quyền chuyển tiếp (Downstream Forwarding)**:
   - Khi token hợp lệ, Gateway chuyển tiếp trực tiếp request qua `BackendDispatcher` (`HttpClient`) tới đúng cổng của backend microservice tương ứng.

Gateway có **hai trục độc lập**, không phải một biến `GatewayMode`:

| Trục | Giá trị hợp lệ | Ý nghĩa | Nơi cấu hình |
|:---|:---|:---|:---|
| `Gateway.Services.{service}.Mode` | `Mock` \| `Real` | Mỗi service chọn nguồn dữ liệu riêng | `appsettings.json` (8 entry), ghi đè bởi `gateway.runtime.json` + env |
| `Gateway.AuthMode` (hoặc `GatewayMode` cũ) | `Enforce` \| `Bypass` | Có kiểm JWT/RBAC hay cấp danh tính giả lập | `GatewayOptions.cs:38,101,110` |

1. **Trạng Thái Enforce (mặc định, `AuthMode: "Enforce"`)**:
   - Áp dụng kiểm tra JWT và ma trận RBAC nghiêm ngặt.
   - Chưa đăng nhập (không token) → `401 Unauthorized`.
   - Token không đủ quyền → `403 Forbidden`.

2. **Trạng Thái Mock/Bypass (chỉ Development)**:
   - Dành cho Frontend kiểm thử giao diện độc lập với mock data: client gọi mock API không cần token, Gateway cấp danh tính giả lập.
   - **Ngoại lệ an toàn**: `GatewayControlController.cs:17` và `HealthProberController.cs:19` gắn `[DisableMockAuthorizationBypass]` + `[Authorize(GatewayPolicies.GatewayAdmin)]`; attribute được enforce tại `Security/GatewayAuthorization.cs:35-36` và bởi `MockEngineMiddleware.cs:178`. ✅ Có thật, đã kiểm 2/2 controller control-plane.
   - ⚠️ **Rủi ro đang bật**: `ApiGateway/Nexus.Gateway/gateway.runtime.json:44-46` đặt `AllowClientModeOverrideInDevelopment`, `AllowAnonymousMockAuthInDevelopment`, `AllowMockTokenAuth` = `true` **trong file được commit**, và `:52` đặt `users: Mock` trong khi `:59` `catalog: Real`. File này được nạp **sau** `appsettings.json` (`Extensions/ConfigurationExtensions.cs:12-16`) nên nó **thắng**: môi trường thật đang chạy mock + bypass auth. `GatewayOptions.IsValid(isDevelopment)` sẽ **chặn khởi động ở Production** vì lý do này.

---

## 4. QUY CHUẨN ĐỊNH DẠNG PHẢN HỒI (API RESPONSE ENVELOPES)

Mọi phản hồi từ hệ sinh thái Nexus bắt buộc tuân theo định dạng chuẩn đã quy định trong `input.md`.

> **Trạng thái (2026-10-24):** ⚠️ Envelope có implementation thật ở Gateway (`Responses/ApiResponseFactory.cs`) nhưng **Catalog có envelope thứ hai** (`Catalog.Api/Models/ApiResponse.cs:53-63`) và **hai nguồn `traceId`** (`Catalog.Api/Middleware/GlobalExceptionHandlerMiddleware.cs:34` vs `ApiResponseFactory.cs:20`) ⇒ cùng một response có thể mang 2 giá trị trace khác nhau tuỳ đường đi. 8 backend còn lại không có endpoint HTTP (chỉ Gateway và Catalog mock trả envelope).

### A. Phản Hồi Thành Công Đơn Lẻ (`ApiResponse<T>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User retrieved successfully.",
  "data": {
    "id": "usr_9981",
    "fullName": "Nguyen Van A",
    "email": "vana@example.com",
    "status": "Active"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```

### B. Phản Hồi Thành Công Phân Trang (`ApiResponse<PagedData<T>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      { "id": "101", "name": "Bàn phím cơ", "price": "1250000.00" }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 245,
      "totalPages": 13,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```

### C. Phản Hồi Lỗi Chuẩn IETF RFC 9110 / RFC 6585 (`ApiErrorResponse`)
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Please refer to the errors property for additional details.",
  "errors": {
    "Email": ["The Email field is not a valid e-mail address."]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```
*(Tuyệt đối không trả về status 200 kèm `isError: true` theo kiểu anti-pattern; status code trong envelope phải trùng với mã HTTP Status của response.)*

> ⚠️ **Lỗi `type` đang sai ở middleware backend**: mọi mã 4xx (kể cả 404) dùng `#section-15.5.1` (`Notification.Api/Middleware/GlobalExceptionHandlerMiddleware.cs:79`, `Fulfillment.Api/…:79`, `Commerce.Api/…:79`, `Catalog.Api/…:79`). Đúng chuẩn RFC 9110: 400 → `15.5.1`, 401 → `15.5.3`, 403 → `15.5.4`, 404 → `15.5.5`, 409 → `15.5.10`.

---

## 5. QUY CHUẨN THAY ĐỔI & THAO TÁC CƠ SỞ DỮ LIỆU (DATABASE GOVERNANCE RULES)

Khi thay đổi mã nguồn, tạo mới thực thể, chỉnh sửa bảng hoặc đụng tới cơ sở dữ liệu, mọi AI Coding Agent BẮT BUỘC tuân thủ:

### 5.1. Quy chuẩn Lưu trữ & Ép kiểu Enum (Enum Persistence & Boundary Serialization)
- **Bên trong DB (PostgreSQL)**: 100% Enum phải được lưu dưới dạng số nguyên `integer` (32-bit signed int). TUYỆT ĐỐI CẤM dùng `HasConversion<string>()` hoặc PostgreSQL Custom Enum Types (`CREATE TYPE ... AS ENUM`). Tối ưu dung lượng lưu trữ, tốc độ đánh chỉ mục (B-Tree index) và bảo đảm tương thích migration khi mở rộng giá trị mới.
- **Bên trong Domain & Service Layer**: 100% sử dụng C# Enum strongly-typed (kế thừa ngầm định kiểu `int32`), gán giá trị rõ ràng từ `0`. Tuyệt đối CẤM dùng số nguyên ma thuật (magic numbers) hay chuỗi ký tự thô để so sánh trạng thái thực thể.
- **Đầu ra REST API (Outbound to Client)**: 100% phải được tuần tự hóa thành chuỗi PascalCase (`"Active"`, `"PendingVerification"`). Tuyệt đối không để lộ số nguyên thô ra bên ngoài JSON response.
- **Đầu vào REST API (Inbound from Client)**:
  - Với JSON Body: Bắt buộc qua `PascalCaseJsonStringEnumConverter`, chấp nhận case-insensitive và SCREAMING_SNAKE_CASE (tự động loại bỏ dấu gạch dưới). CẤM nhận số nguyên thô (`allowIntegerValues: false`). Nếu giá trị không hợp lệ, ném ngoại lệ `JsonException` tiếng Anh Sentence case liệt kê toàn bộ giá trị hợp lệ.
  - Với Query Parameters & Route Data: Bắt buộc dùng `EnumExtensions.TryToEnum<TEnum>(out var result)` để parse an toàn hoặc `ToEnum<TEnum>()` (ném `ArgumentException` được middleware chuyển thành HTTP 400 `VAL_INVALID_ARGUMENT`).

### 5.2. Quy trình Quản lý Migration EF Core (EF Core Migration Lifecycle)
- **Plan-First**: Trước khi tạo migration, phải trình bày rõ: danh sách cột thêm/sửa, kiểu dữ liệu, index, và ảnh hưởng tới code hiện tại.
- **Quy ước Đặt tên Migration**: Sử dụng timestamp kết hợp hành động nghiệp vụ rõ ràng (ví dụ: `20261030054250_InitialCreate` hoặc `20261030143000_AddSellerVerificationStatus`).
- **Cấm Migration Phá Hủy (Zero Destructive Migrations)**: Tuyệt đối CẤM tự ý thêm lệnh `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, hoặc `RENAME COLUMN` trên cơ sở dữ liệu nếu chưa có sự phê duyệt rõ ràng từ Người dùng (Sếp). Mọi thay đổi phải đi theo hướng an toàn Additive (thêm cột mới nullable hoặc có default value).
- **Đồng bộ Migration Designer & ModelSnapshot**: Khi tạo hoặc cập nhật migration, bắt buộc kiểm tra `AppDbContextModelSnapshot.cs` và file `*.Designer.cs` khớp 100% với schema entity, không để sót migration rác hay migration dở dang.
- **Tự động áp dụng Migration An toàn (Startup Safe Auto-Migration)**: Service chỉ gọi `db.Database.Migrate()` khi `db.Database.IsRelational()` là `true`, và bắt buộc bọc trong khối `try-catch` với log cảnh báo rõ ràng để tránh crash ứng dụng khi DB chưa sẵn sàng.

### 5.3. Cô lập Cơ sở dữ liệu Tuyệt đối (Database-per-Service Isolation)
- Mỗi microservice sở hữu cơ sở dữ liệu riêng biệt (`usermanagement_db:5433`, `category_db:5434`, `commerce_db:5435`, `log_db:5436`, `auction_db:5437`, `fulfillment_db:5438`, `notification_db:5439`, `wallet_db:5440`).
- Tuyệt đối CẤM truy vấn chéo giữa các database (cấm dùng dblink, foreign data wrapper, hoặc raw SQL join sang DB khác).
- Tuyệt đối CẤM chia sẻ `DbContext` giữa các microservices.

### 5.4. Cấm dùng Repository Pattern bọc ngoài EF Core
- Tầng Application trực tiếp inject `I{Service}DbContext` và truy vấn `DbSet<T>`. Cấm tạo `IRepository<T>`, `GenericRepository`, hoặc `UnitOfWork`.

### 5.5. Quy chuẩn Đặt tên và Cấu hình Thực thể (Entity & Fluent API Configuration)
- **Tên bảng**: PascalCase mặc định theo tên Entity / DbSet (không tự ý viết `builder.ToTable("snake_case")`).
- **Kiểu khóa chính**: Bắt buộc dùng `Guid` cho Primary Key của tất cả các entity nghiệp vụ (kế thừa `BaseEntity<Guid>` hoặc `AuditableEntity<Guid>`).
- **Khóa ngoại & Hành vi Xóa (Foreign Keys & DeleteBehavior)**: Ưu tiên dùng `DeleteBehavior.Restrict` hoặc `DeleteBehavior.SetNull`. CẤM dùng `DeleteBehavior.Cascade` bừa bãi gây lỗi cascade cycle hoặc mất dữ liệu diện rộng ngoài ý muốn.
- **Xóa mềm (Soft Delete)**: Mọi entity nghiệp vụ phải chứa trường `IsDeleted` (boolean) và `DeletedAt` (DateTimeOffset?). Bắt buộc khai báo bộ lọc toàn cục `builder.HasQueryFilter(x => !x.IsDeleted)` trong file `*Configuration.cs`.
- **Chỉ mục Hiệu năng (Performance Indexes)**: Tất cả các trường tìm kiếm thường xuyên (`Email`, `Username`, `PhoneNumber`, `Status`) hoặc khóa ngoại phải có chỉ mục. Các trường unique nullable bắt buộc dùng filtered index (ví dụ: `builder.HasIndex(x => x.Username).IsUnique().HasFilter("\"Username\" IS NOT NULL")`).
- **Độ chính xác tiền tệ (Currency & Decimal Precision)**: Mọi trường số tiền, số dư (như `Wallet.Balance`, `Product.Price`, `Bid.Amount`) phải cấu hình kiểu decimal với độ chính xác rõ ràng `HasPrecision(18, 2)`.

### 5.6. Quy chuẩn Dữ liệu Khởi tạo (Seed Data Standards)
- Toàn bộ dữ liệu seed khai báo qua `HasData()` trong `OnModelCreating` hoặc các class helper tại `Persistence/Seeds/`.
- Khóa chính ID trong Seed Data BẮT BUỘC dùng GUID cố định (Deterministic GUIDs như `Guid.Parse("11111111-1111-1111-1111-111111111111")`). TUYỆT ĐỐI CẤM dùng `Guid.NewGuid()` trong `HasData` vì sẽ làm sai lệch snapshot migration sau mỗi lần build.
- Mọi mật khẩu mẫu cho tài khoản seed bắt buộc phải hash bằng BCrypt có salt trước khi đưa vào cấu hình seed (`$2a$11$...`), không lưu plain text.

### 5.7. Bảo vệ Bí mật và Chuỗi kết nối Database
- Tuyệt đối CẤM commit mật khẩu thật, connection string thực tế vào mã nguồn hay git. Mọi thông tin nhạy cảm phải đọc từ biến môi trường.

