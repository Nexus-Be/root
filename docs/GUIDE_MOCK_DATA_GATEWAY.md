# HƯỚNG DẪN TẠO MOCK API, CHUYỂN ĐỔI RUNTIME, BYPASS AUTH & KIỂM TRA HEALTH CHECK
## (NEXUS GATEWAY MOCK ENGINE, RUNTIME SWITCHING & HEALTH PROBER GUIDE)

> **Mục tiêu**: Cung cấp cẩm nang thực hành toàn diện giúp Developer (Frontend, Backend, QA) nắm vững:
> 1. Kiến trúc tiền xử lý của Gateway và quy trình tạo Mock API chuẩn **DUY NHẤT**: **Khai báo Endpoint trong Controller C# + Tạo dữ liệu Seed Fixture tại thư mục `Seeds/`**.
> 2. Cách chuyển đổi linh hoạt giữa chế độ **`Mock`** và **`Real`**.
> 3. Cách sử dụng tính năng **Bypass Auth Mode** để test không cần JWT token.
> 4. Cách sử dụng và kiểm tra hệ thống **Health Check & Prober Daemon**.

---

## PHẦN 1: KIẾN TRÚC GATEWAY & QUY TRÌNH TẠO MOCK API CHUẨN

---

### 1. Kiến Trúc & Các Bước Tiền Xử Lý Của Gateway (Request Pipeline)

Mọi request khi gửi đến Nexus API Gateway đều được xử lý tuần tự và tự động qua **6 bước trong Middleware Pipeline** (`PipelineExtensions.cs`) trước khi trả về cho client:

```
[ Client Request ]
       │
       ▼
1. Exception Handler & Centralized Logging (Bắt ngoại lệ toàn cục, cấp phát X-Trace-Id)
       │
       ▼
2. URL Rewrite & Route Resolution (/gateway/api/* -> /api/*, ánh xạ tới Controller Action)
       │
       ▼
3. Mode & Auth Resolution (Xác định Service Mode: "Mock"/"Real", AuthMode: "Enforce"/"Bypass")
       │
       ▼
4. Security & Rate Limiting (JWT Bearer Token, [Authorize] RBAC, Redis Rate Limiting)
       │
       ▼
5. Controller Model Binding & Input Validation (Bind DTO, tự động validate dữ liệu đầu vào)
       │
       ▼
6. Gateway Dispatcher Execution (IGatewayDispatcher điều phối: Mock -> Seeds/ | Real -> gRPC)
       │
       ▼
[ Client Response: ApiResponse<T> ]
```

#### Chi tiết 6 bước xử lý:
1. **Global Exception Handling & Diagnostics**:
   - `GatewayExceptionHandler` bắt toàn bộ lỗi, tự động chuyển đổi sang chuẩn **RFC 9110 ProblemDetails** và bọc trong envelope lỗi chuẩn (`ApiErrorResponse`).
   - Cấp phát mã `X-Trace-Id` duy nhất xuyên suốt toàn bộ vòng đời request và đồng bộ sang Grafana Tempo.
2. **URL Rewrite & Route Resolution**:
   - Tự động chuẩn hóa `/gateway/api/v1/...` về `/api/v1/...` để đảm bảo tương thích ngược.
   - Nhận diện Service phụ trách thông qua attribute `[BackendTag("service_name")]` trên Controller và khớp Route với Controller Action.
3. **Gateway Request Resolution & Mode Evaluation**:
   - `GatewayRequestResolution` kiểm tra cấu hình trong `gateway.runtime.json` để xác định trạng thái của Service (`Mock` hay `Real`) và AuthMode (`Enforce` hay `Bypass`).
4. **Security, Authentication, RBAC & Rate Limiting**:
   - Kiểm tra JWT Token (`UseAuthentication`) và phân quyền người dùng (`UseAuthorization`) dựa trên metadata `[Authorize(Roles = "...")]` hoặc `[AllowAnonymous]`.
   - Kiểm tra giới hạn tần suất gọi API qua Redis Distributed Rate Limiting (`[EnableRateLimiting]`).
5. **Model Binding & Input Validation**:
   - ASP.NET Core tự động bind query parameters, route values và request body vào DTO C#.
   - Controller validate logic nghiệp vụ qua các helper (`ValidationHelpers`, `pagination.EnsureValid()`), ném `GatewayInputException` khi dữ liệu không hợp lệ.
6. **Gateway Dispatcher Execution (`IGatewayDispatcher`)**:
   - **Khi Service ở chế độ `Mock`**: Tự động tìm và đọc file dữ liệu seed mẫu từ thư mục `Seeds/{service}/{operation}.json`, kiểm tra tính hợp lệ qua Protobuf Parser, và bọc trong `ApiResponse<T>` chuẩn.
   - **Khi Service ở chế độ `Real`**: Kiểm tra trạng thái Circuit Breaker từ Health Prober Daemon; nếu healthy sẽ gọi gRPC client sang Microservice downstream tương ứng và bọc kết quả trả về.

---

### 2. Tại Sao Hệ Thống Thống Nhất Duy Nhất 1 Cách Mock?

Trước đây có tài liệu nhắc đến 2 cách (tạo file declarative `*.mock.json` ở `Mocks/` hoặc viết Controller + `Seeds/`). Tuy nhiên, **thực tế kiến trúc của Gateway chỉ sử dụng và khuyến nghị DUY NHẤT một cách: Viết Controller Action + Tạo file Seed Fixture (`Seeds/`)**.

Lý do bắt buộc phải tạo Controller Endpoint kết hợp Seed Fixture:
1. **Đảm bảo đầy đủ các bước của Gateway**: Nếu chỉ tạo file JSON đứng riêng lẻ mà không có Controller, API sẽ không có DTO binding, không có C# validation, không thể khai báo các Attribute phân quyền (`[Authorize]`) và Rate Limit (`[EnableRateLimiting]`) theo chuẩn của hệ thống.
2. **Chuyển đổi `Mock` $\rightarrow$ `Real` trong 0 giây (Zero-Code Switch)**: Controller chính là cầu nối gRPC client. Khi backend service thật hoàn thành, bạn chỉ cần đổi cấu hình `"Mode": "Real"` trong `gateway.runtime.json`, Controller sẽ tự động gọi gRPC mà **không cần viết lại hay sửa đổi bất kỳ dòng code Gateway nào**. Nếu mock không có Controller, khi chuyển sang `Real` request sẽ bị **404 Not Found**.
3. **Cơ chế tự động ưu tiên của Gateway Middleware**: Trong code `MockEngineMiddleware.cs` (dòng 51):
   ```csharp
   if (effectiveMode == "Real" || context.GetEndpoint()?.Metadata.GetMetadata<ControllerActionDescriptor>() != null)
   {
       await _next(context);
       return;
   }
   ```
   Hễ một route đã được định nghĩa Action trong C# Controller thì Gateway **ngay lập tức bỏ qua** file declarative mock để nhường quyền xử lý cho Controller và đọc dữ liệu từ `Seeds/`.

---

### 3. Quy Trình 3 Bước Tạo Mock API Chuẩn Tại Gateway

Mọi endpoint mới cần mock đều tuân thủ đúng 3 bước sau:

```
[ Bước 1: Viết Action trong Controller ] ──► [ Bước 2: Tạo Seed JSON trong Seeds/ ] ──► [ Bước 3: Đặt Mode: Mock & Test ]
```

#### 👉 Bước 1: Khai báo Action trong Controller tương ứng
Mở Controller tương ứng tại thư mục `src/Services/ApiGateway/Nexus.Gateway/Controllers/` (ví dụ `ProductsController.cs`, `CartController.cs`, `OrdersController.cs`...):

```csharp
[ApiController]
[Route("api/v1/catalog/products")]
[BackendTag("catalog")]
[EnableRateLimiting("api")]
public sealed class ProductsController : ControllerBase
{
    private readonly IGatewayDispatcher _dispatcher;
    private readonly CatalogApi.CatalogApiClient _client;

    public ProductsController(IGatewayDispatcher dispatcher, CatalogApi.CatalogApiClient client)
    {
        _dispatcher = dispatcher;
        _client = client;
    }

    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType(typeof(ApiResponse<PagedData<ProductDto>>), StatusCodes.Status200OK)]
    public Task<IResult> ListProducts([FromQuery] PaginationRequest pagination)
    {
        // 1. Tự động validate phân trang: Page >= 1, PageSize từ 1-100
        pagination.EnsureValid();

        // 2. Dispatcher tự động điều phối:
        //    - Mode = Mock: đọc Seeds/catalog/products.json
        //    - Mode = Real: gọi _client.ListProductsAsync(...)
        return _dispatcher.DispatchPagedAsync(
            HttpContext,
            "catalog",                                                          // Tên service
            "products",                                                         // Tên operation (tương ứng tên file seed)
            pagination.Page,
            pagination.PageSize,
            o => _client.ListProductsAsync(new ListProductsRequest              // gRPC call khi ở Real mode
            {
                Page = pagination.Page,
                PageSize = pagination.PageSize
            }, o),
            ProductPageResponse.Parser                                          // Protobuf Message Parser
        );
    }
}
```

> 💡 **Với API trả về một đối tượng đơn (Single Object) hoặc POST/PUT**:
> ```csharp
> [HttpPost]
> [Authorize("seller")]
> [ProducesResponseType(typeof(ApiResponse<ProductDto>), StatusCodes.Status201Created)]
> public Task<IResult> CreateProduct([FromBody] CreateProductRequestDto body)
> {
>     ValidationHelpers.EnsureRequired(body.Name, "Name");
> 
>     return _dispatcher.DispatchAsync(
>         HttpContext,
>         "catalog",
>         "product-create",
>         o => _client.CreateProductAsync(new CreateProductRequest { Name = body.Name }, o),
>         ProductResponse.Parser,
>         successMessage: "Product created successfully.",
>         successStatusCode: StatusCodes.Status201Created
>     );
> }
> ```

---

#### 👉 Bước 2: Tạo file JSON dữ liệu mẫu trong `Seeds/`
Tạo file dữ liệu mẫu theo đúng quy tắc đường dẫn:
```
src/Services/ApiGateway/Nexus.Gateway/Seeds/{tên_service}/{tên_operation}.json
```
*(Hoặc `src/Services/ApiGateway/Nexus.Gateway/Seeds/{tên_operation}/{tên_operation}.json`)*

*Ví dụ:* Với `service: "catalog"`, `operation: "products"`, tạo file `src/Services/ApiGateway/Nexus.Gateway/Seeds/catalog/products.json`:

```json
{
  "items": [
    {
      "id": "22222222-2222-2222-2222-000000000001",
      "name": "Bàn phím cơ không dây Nexus Pro",
      "price": 1250000,
      "status": "Active"
    },
    {
      "id": "22222222-2222-2222-2222-000000000002",
      "name": "Chuột Gaming Silent Nexus X",
      "price": 650000,
      "status": "Active"
    }
  ],
  "total": 2
}
```

---

#### 👉 Bước 3: Đảm bảo Service đặt `Mode: "Mock"` và Test trên Swagger
1. Kiểm tra cấu hình trong `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`:
   ```json
   "catalog": {
     "Mode": "Mock",
     "Address": "http://localhost:8002",
     "TimeoutSeconds": 5
   }
   ```
2. Mở trình duyệt truy cập: `http://localhost:8080/swagger`.
3. Tìm đến endpoint vừa khai báo trong Controller $\rightarrow$ bấm **Try it out** $\rightarrow$ **Execute**.
4. Gateway sẽ trả về response bọc trong vỏ bọc chuẩn `ApiResponse<T>`:
   ```json
   {
     "success": true,
     "statusCode": 200,
     "message": "Products retrieved successfully.",
     "data": {
       "items": [
         {
           "id": "22222222-2222-2222-2222-000000000001",
           "name": "Bàn phím cơ không dây Nexus Pro",
           "price": 1250000,
           "status": "Active"
         }
       ],
       "pagination": {
         "pageIndex": 1,
         "pageSize": 20,
         "totalCount": 2,
         "totalPages": 1,
         "hasPreviousPage": false,
         "hasNextPage": false
       }
     },
     "traceId": "0HNPGT7G285Q2",
     "timestamp": "2026-10-24T14:30:00Z"
   }
   ```

---

### 4. Quy Chuẩn Response & Xử Lý Lỗi Hệ Thống

Toàn bộ API qua Gateway bắt buộc phải tuân theo chuẩn định dạng response đồng nhất:

#### Phản hồi thành công (`ApiResponse<T>`):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Sentence case success message in 100% English.",
  "data": { ... },
  "traceId": "0HNPGT7G285Q2",
  "timestamp": "2026-10-24T14:30:00Z"
}
```

#### Phản hồi thất bại / Lỗi (`ApiErrorResponse` theo RFC 9110 ProblemDetails):
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Username, valid email, and password with at least 8 characters are required.",
  "errors": {
    "Email": ["Email address is invalid."]
  },
  "traceId": "0HNPGT7G285Q2",
  "timestamp": "2026-10-24T14:30:00Z"
}
```

> ⚠️ **Lưu ý quy tắc thông báo lỗi (Error Rules)**:
> - **Ngôn ngữ**: 100% tiếng Anh (`English only`).
> - **Quy cách**: Viết hoa duy nhất chữ cái đầu câu (`Sentence case`), ví dụ: `"Email address is required."`.
> - **Mã lỗi**: Viết hoa phân cách gạch dưới (`SCREAMING_SNAKE_CASE`), ví dụ: `VAL_INVALID_INPUT`, `USER_NOT_FOUND`, `AUTH_UNAUTHORIZED`.

---

## PHẦN 2: HƯỚNG DẪN SỬ DỤNG TÍNH NĂNG CHUYỂN ĐỔI MOCK $\leftrightarrow$ REAL

Gateway hỗ trợ 3 cơ chế chuyển đổi chế độ runtime:

### Cách 1: Đổi qua file cấu hình `gateway.runtime.json` (Áp dụng toàn sàn)
Mở file `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`:
```json
"Services": {
  "catalog": {
    "Mode": "Real",          // Đổi "Mock" thành "Real" khi Backend thật đã sẵn sàng
    "Address": "http://localhost:8002",
    "TimeoutSeconds": 5
  }
}
```
*Đặc tính:* Hỗ trợ **Hot-Reload trong 0ms**, lưu file là ăn ngay, không cần tắt/bật lại Gateway.

### Cách 2: Đổi qua Control-Plane API (Dành cho Quản trị viên & Automation Script)
Gateway cung cấp sẵn bộ API quản trị (yêu cầu quyền Admin):
* **Xem trạng thái hiện tại của cả 8 services:**
  ```http
  GET /api/v1/gateway/modes
  ```
* **Cập nhật chế độ cho 1 service cụ thể:**
  ```http
  PUT /api/v1/gateway/modes/catalog
  Content-Type: application/json

  {
    "mode": "Real"
  }
  ```
* **Cập nhật hàng loạt (Bulk Update):**
  ```http
  PUT /api/v1/gateway/modes
  Content-Type: application/json

  {
    "authMode": "Enforce",
    "services": {
      "catalog": "Real",
      "users": "Real",
      "commerce": "Mock"
    }
  }
  ```

### Cách 3: Ghi đè theo từng Request qua HTTP Header (Khuyên dùng khi Test)
Khi service đang ở chế độ `Mock`, nhưng bạn muốn test thử 1 request gọi sang Backend thật:
* Đính kèm Header trong cURL / Postman:
  ```http
  X-Service-Mode-catalog: Real
  ```
Gateway sẽ ưu tiên Header của request cao nhất, giúp bạn test song song mà không ảnh hưởng người khác.

---

## PHẦN 3: HƯỚNG DẪN TÍNH NĂNG BYPASS AUTH MODE

### 1. Ý nghĩa & Vấn đề giải quyết:
Khi phát triển giao diện Frontend, nhiều trang màn hình yêu cầu phải có Token đăng nhập (ví dụ: Xem thông tin cá nhân `policy: "authenticated"`, hoặc Đăng sản phẩm `policy: "seller"`). Nếu Backend `UserService` chưa chạy thật hoặc dev không muốn tốn thời gian gọi API login để lấy token:
$\rightarrow$ **Bypass Auth Mode** cho phép bạn gọi các API này hoàn toàn ẩn danh mà **không bị chặn mã lỗi 401 Unauthorized hay 403 Forbidden**!

### 2. Cách kích hoạt:
Mở file `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`, sửa:
```json
{
  "Gateway": {
    "AuthMode": "Bypass"
  }
}
```

### 3. Cơ chế hoạt động ngầm (`MockSecurityAdapterMiddleware`):
Khi ở chế độ `Bypass`:
- Nếu client không gửi Token, Gateway tự động gán một ClaimsPrincipal danh tính mẫu:
  - `User ID`: `11111111-1111-1111-1111-000000000004`
  - `Roles`: `buyer`, `seller`, `staff`, `admin`
- Các endpoint có thuộc tính `[Authorize]` sẽ tự động cho phép request đi qua.
- **Lưu ý an ninh**: Tính năng Bypass **chỉ hoạt động ở môi trường Development** (`ASPNETCORE_ENVIRONMENT=Development`). Trên môi trường Production, Gateway luôn bắt buộc chế độ `"Enforce"` nghiêm ngặt. Ngoài ra, các API quản trị Gateway (`/api/v1/gateway/*`) luôn yêu cầu Token Admin thật, không bao giờ bị bypass.

---

## PHẦN 4: HƯỚNG DẪN KIỂM TRA HEALTH CHECK & HEALTH PROBER

Gateway trang bị hệ thống kiểm tra sức khỏe phân tầng:

```
[ K8s / Load Balancer ] ──▶ [ GET /health/live & /health/ready ] (Gateway Health)
                                       │
                                       ▼ (Prober Daemons)
                         ┌─────────────────────────────┐
                         │   Thăm dò 8 Microservices   │
                         │   (Interval 60s, Timeout 30s)
                         └─────────────────────────────┘
```

### 1. Endpoints Kiểm Tra Sức Khỏe Tự Thân Của Gateway:
* **`GET http://localhost:8080/health/live` (Liveness Probe)**:
  - Trả về HTTP 200 OK nếu tiến trình Gateway đang sống. Kubernetes sử dụng endpoint này để biết container có bị treo (deadlock) hay không để restart.
* **`GET http://localhost:8080/health/ready` (Readiness Probe)**:
  - Trả về HTTP 200 OK khi Gateway đã sẵn sàng tiếp nhận lưu lượng (Redis đã kết nối, MockEngine đã tải xong định nghĩa).

---

### 2. Quản Lý Hệ Thống Health Prober Daemons Của 8 Services:
Mỗi backend service có một luồng Prober Daemon chạy ngầm trong Gateway. Mặc định khi khởi động, các daemon ở trạng thái `Disabled` để tiết kiệm tài nguyên.

#### A. Xem trạng thái sức khỏe của toàn bộ 8 services:
```bash
curl -X GET http://localhost:8080/api/v1/gateway/prober/status \
     -H "Authorization: Bearer <token_admin>"
```
Response mẫu:
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "catalog": {
      "daemonStatus": "Enabled",
      "healthState": "Healthy",
      "consecutiveFailures": 0,
      "lastChecked": "2026-10-24T12:00:00Z",
      "address": "http://localhost:8002"
    },
    "users": {
      "daemonStatus": "Disabled",
      "healthState": "Unknown",
      "consecutiveFailures": 0,
      "address": "http://localhost:8001"
    }
  }
}
```

#### B. Bật giám sát sức khỏe cho 1 service:
```bash
curl -X PUT http://localhost:8080/api/v1/gateway/prober/catalog \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <token_admin>" \
     -d '{
       "enabled": true,
       "intervalSeconds": 30,
       "failureThreshold": 3
     }'
```

#### C. Kích hoạt kiểm tra sức khỏe tức thì (Manual Probe):
Khi bạn vừa deploy xong một service và muốn Gateway kiểm tra ngay lập tức mà không cần đợi chu kỳ 60 giây:
```bash
curl -X POST http://localhost:8080/api/v1/gateway/prober/check/catalog \
     -H "Authorization: Bearer <token_admin>"
```

---

### 3. Cơ Chế Circuit Breaker Fast-Fail (503 ProblemDetails):
Khi một service bị chết (ví dụ `catalog` bị sập quá 5 lần probe liên tiếp):
- Prober Daemon chuyển trạng thái của service sang **`Unhealthy`**.
- **Circuit Breaker tự động kích hoạt:** Toàn bộ các request tiếp theo gửi tới `/api/v1/catalog/*` sẽ bị Gateway ngắt mạch ngay lập tức trong **0ms** và trả về mã lỗi **HTTP 503**:
  ```json
  {
    "type": "https://tools.ietf.org/html/rfc9110#section-15.6.4",
    "title": "Downstream Service Unavailable",
    "status": 503,
    "detail": "Service 'catalog' is currently unhealthy or undergoing recovery.",
    "errorCode": "DOWNSTREAM_UNHEALTHY",
    "traceId": "0HNPH0O1RS5U4"
  }
  ```
- *Lợi ích:* Giúp Gateway không bị treo luồng khi chờ timeout của service chết, bảo vệ toàn bộ hệ thống không bị sập dây chuyền (Cascading Failure).
