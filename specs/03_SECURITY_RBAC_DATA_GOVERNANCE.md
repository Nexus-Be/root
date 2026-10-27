# 03 — BẢO MẬT, PHÂN QUYỀN RBAC & QUY CHUẨN DỮ LIỆU (SECURITY & DATA GOVERNANCE)

> **Trạng thái triển khai (2026-10-24):** ❌ Không đạt — Gateway có xác thực JWT + RBAC thật, nhưng **không có service nào phát hành JWT** (`0` dòng code tạo token trong 9 repo), **tên role không đồng nhất giữa seed và code** (`Support Staff`/`Administrator` trong seed vs `staff`/`admin` trong `KnownRoles`), và policy `gateway-admin` lại yêu cầu role `admin`.
> **Nguồn sự thật:** code (`Security/SecurityConfiguration.cs`, `Security/GatewayAuthorization.cs`, `Common/ValidationHelpers.cs`, `User.Infrastructure/Persistence/Seeds/UserSeedData.cs`).
> **Cập nhật lần cuối:** 2026-10-24.

Tài liệu này xác định ma trận phân quyền, vòng đời token JWT, cơ chế 2 trạng thái Gateway và quy chuẩn định dạng phản hồi chuẩn quốc tế.

---

## 1. MA TRẬN PHÂN QUYỀN VAI TRÒ (RBAC MATRIX)

Hệ thống Nexus phân cấp **6 mức** vai trò (Roles) có tính kế thừa quyền hạn (bảng dưới đây có 6 dòng — câu “5 cấp độ” trước đây là sai):

| Vai Trò (spec) | Cấp Độ | Tên thực tế trong code | Quyền Hạn Nghiệp Vụ | Trạng thái |
|:---|:---:|:---|:---|:---|
| **anonymous** | 0 | (không có role) | Người dùng vãng lai chưa đăng nhập. | ✅ Có (không cần token) |
| **buyer** | 1 | `Buyer` (seed) / `buyer` (`KnownRoles`) | Khách hàng đã đăng nhập. | ⚠️ Seed có, nhưng **không có endpoint nào** dùng role này |
| **seller** | 2 | `Seller` (seed) / `seller` | Người bán đã được duyệt (kế thừa `buyer`). | ⚠️ Seed có, endpoint seller **chưa tồn tại** |
| **staff** | 3 | `Support Staff` (seed) / `staff` | Nhân viên vận hành sàn (kế thừa `buyer`). | ❌ **Lệch tên** giữa seed và `KnownRoles` ⇒ so khớp role sẽ trượt |
| **admin** | 4 | `Administrator` (seed) / `admin` | Quản trị viên hệ thống. | ❌ **Lệch tên**; mọi endpoint `/admin/*` trong `specs/02` **chưa tồn tại** |
| **gateway-admin** | 5 | `GatewayPolicies.GatewayAdmin = "gateway-admin"` | Quản trị hạ tầng Gateway. | ❌ Policy khai báo `RequireRole("admin")` (`SecurityConfiguration.cs:161`) — **không phải** `gateway-admin` |

Bằng chứng:
- Seed: `User/User.Infrastructure/Persistence/Seeds/UserSeedData.cs:25,36,47,58` → `Buyer`, `Seller`, `Support Staff`, `Administrator` (**4 role**, không có `gateway-admin`, không có `anonymous`).
- Code: `ApiGateway/Nexus.Gateway/Common/ValidationHelpers.cs:10` → `KnownRoles = ["buyer", "seller", "staff", "admin"]` (**4 role chữ thường**).
- Policy: `ApiGateway/Nexus.Gateway/Security/GatewayAuthorization.cs:12` khai báo `GatewayAdmin = "gateway-admin"` nhưng `Security/SecurityConfiguration.cs:161` viết `o.AddPolicy(GatewayPolicies.GatewayAdmin, p => p.RequireAuthenticatedUser().RequireRole("admin"))`.

> **Quyết định cần chốt:** đặt tên role theo seed (`Support Staff`) hay theo code (`staff`)? Hiện tại cả hai cùng tồn tại ⇒ token phát bằng tên seed sẽ **không** khớp policy dùng tên code.

---

## 2. VÒNG ĐỜI VÀ TIÊU CHUẨN TOKEN JWT

> **Trạng thái (2026-10-24): ❌ Chưa có nơi phát hành.** `User` có `RefreshToken` entity + cấu hình EF nhưng **0 lời gọi**, `User.Application` **không** phụ thuộc `System.IdentityModel.Tokens.Jwt`; `UsersGrpcService` **không** implement `rpc Login`. Gateway có `Microsoft.AspNetCore.Authentication.JwtBearer 8.0.10` để **validate** một token không ai tạo ra.

- **Thuật toán ký**: HMAC-SHA256 với Secret Key tối thiểu 32 ký tự (hoặc RSA-256).
- **Claims Bắt Buộc Trong Token** (đặc tả — chưa implementation nào tuân thủ):
  - `sub`: UUID của người dùng (Subject).
  - `role`: Danh sách vai trò (`buyer`, `seller`, `staff`, `admin`).
  - `iss`: Issuer (`http://localhost:8001` — UserService). ⚠️ Chưa service nào phát token nên claim này chưa từng xuất hiện.
  - `aud`: Audience (`shoppingcart-api`).
  - `exp`: Thời gian hết hạn (Epoch seconds).
- **Chuyển tiếp qua REST downstream**: Khi Client gửi `Authorization: Bearer <token>` lên Gateway, Gateway forward nguyên vẹn header này cùng `x-trace-id`, `x-user-id`, `x-user-roles`, `x-user-email`, `idempotency-key` vào HTTP Request Headers sang backend microservice. ✅ Đã kiểm chứng: `ApiGateway/Nexus.Gateway/Dispatching/HttpBackendCaller.cs` forward đầy đủ các headers này.

### 2.1 Khoá ký — hiện trạng bảo mật
- Khoá thật đang nằm **plaintext trong file được commit**: `ApiGateway/Nexus.Gateway/appsettings.json:26` và lặp lại ở `appsettings.Development.json:25`. Hai file `*.example.json` chứa placeholder đúng.
- `.env.example` **không có** biến `Jwt__Signature` (trái `CONFIG_REFERENCE.md:162-164`) ⇒ không có đường cấu hình qua biến môi trường được tài liệu hoá.
- Vì khoá đã vào git history, việc xoá khỏi file hiện tại **không đủ** — phải rotate khoá.

### 2.2 Ranh giới tin cậy (trust boundary) — hiện trạng
- `AddAuthentication`/`AddJwtBearer`/`UseAuthentication` **chỉ tồn tại ở Gateway** (`Security/SecurityConfiguration.cs:29-30`, `Extensions/PipelineExtensions.cs:87,90`). **8 backend không có authentication** và **tin tuyệt đối** header nội bộ:
  - `Wallet.Api/Services/WalletGrpcService.cs:28,48,68,96,124` đọc `context.RequestHeaders.Get("x-user-id")`.
  - `User.Api/Services/UsersGrpcService.cs:121` tương tự.
- Hệ quả: nếu backend lộ port (8001–8008) hoặc bị gọi trực tiếp, **mọi kiểm soát quyền bị vô hiệu** — bất kỳ ai cũng có thể tự đặt `x-user-id`. Đây là quyết định kiến trúc cần ghi thành ADR (zero-trust nội bộ vs tin cậy mạng nội bộ).

---

## 3. CƠ CHẾ 2 TRẠNG THÁI GATEWAY (GATEWAY STATE)

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
