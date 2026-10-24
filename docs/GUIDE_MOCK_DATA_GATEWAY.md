# HƯỚNG DẪN TẠO MOCK API, CHUYỂN ĐỔI RUNTIME, BYPASS AUTH & KIỂM TRA HEALTH CHECK
## (NEXUS GATEWAY MOCK ENGINE, RUNTIME SWITCHING & HEALTH PROBER GUIDE)

> **Mục tiêu**: Cung cấp cẩm nang thực hành toàn diện giúp Developer (Frontend, Backend, QA) nắm vững:
> 1. Quy trình tạo Mock API mới trong **3 bước** (cả Declarative Mock và Controller Seed).
> 2. Cách chuyển đổi linh hoạt giữa chế độ **`Mock`** và **`Real`**.
> 3. Cách sử dụng tính năng **Bypass Auth Mode** để test không cần JWT token.
> 4. Cách sử dụng và kiểm tra hệ thống **Health Check & Prober Daemon**.

---

## PHẦN 1: TẠO MOCK API MỚI TRONG 3 BƯỚC

Hệ thống hỗ trợ 2 phương pháp Mock tùy theo vai trò và nhu cầu của bạn:

| Phương Pháp | Khi Nào Sử Dụng? | Cần Viết Code C# Không? | Có Hiện Trên Swagger Không? |
| :--- | :--- | :---: | :---: |
| **Cách 1: Declarative Mock (`Mocks/*.mock.json`)**<br>*(Khuyên dùng cho Frontend & QA)* | Khi Backend **chưa viết code C#**, Frontend cần ngay 1 endpoint REST để ghép giao diện. | ❌ **0 dòng code C#** | ✅ **Tự động hiện lên Swagger** |
| **Cách 2: Controller Seed Fixtures (`Seeds/`)**<br>*(Khuyên dùng cho Backend)* | Khi đã viết **Controller Action C#**, cần dữ liệu mẫu chuẩn khi service chạy ở chế độ Mock. | ✅ Có Action C# | ✅ Hiện theo Controller Swagger |

---

### 👉 CÁCH 1: DECLARATIVE MOCK (0 DÒNG C# — ĂN NGAY TRONG 30 GIÂY)

Dành cho trường hợp: Bạn cần tạo một API mới tinh (ví dụ `GET /api/v1/catalog/promotions`) mà không cần đụng vào code C#.

#### Bước 1: Tạo file JSON tại thư mục `Mocks/`
Vào thư mục: `src/Services/ApiGateway/Nexus.Gateway/Mocks/`  
Tạo một file có đuôi bắt buộc là: `*.mock.json` (ví dụ: `promotions.mock.json`).

#### Bước 2: Điền cấu hình theo Template
Gateway tự động bọc dữ liệu của bạn vào vỏ chuẩn `ApiResponse<T>`:

```json
{
  "id": "mock-get-promotions",
  "service": "catalog",
  "method": "GET",
  "path": "/api/v1/catalog/promotions",
  "description": "Lấy danh sách mã khuyến mãi",
  "policy": "public",
  "statusCode": 200,
  "responseType": "paged",
  "message": "Promotions retrieved successfully.",
  "response": {
    "items": [
      {
        "id": "promo-001",
        "title": "Siêu sale công nghệ 50%",
        "discountPercent": 50,
        "maxDiscountAmount": "500000.00"
      }
    ],
    "total": 1
  }
}
```

#### Bước 3: Lưu file & Kiểm tra trên Swagger
1. **Lưu file lại**: Gateway hỗ trợ **Hot-Reload tức thì** (tự động phát hiện file mới thêm mà không cần khởi động lại server).
2. **Mở trình duyệt**: Truy cập `http://localhost:8000/swagger`. Endpoint mock sẽ tự động xuất hiện.
3. Bấm **Try it out** $\rightarrow$ **Execute** $\rightarrow$ Nhận ngay kết quả JSON chuẩn!

---

### 👉 CÁCH 2: CONTROLLER SEED FIXTURES (DÀNH CHO BACKEND C#)

Thư mục `Seeds/` được tổ chức theo **từng nhóm tính năng nghiệp vụ (Feature-based)**:
```
Seeds/
├── auth/         # register.json, login.json, verify-otp.json, resend-otp.json
├── users/        # profile.json (GET /api/v1/users/me)
├── products/     # products.json, product.json (Catalog)
├── cart/         # cart.json (Commerce)
└── orders/       # orders.json, order.json (Commerce)
```

#### Bước 1: Khai báo Endpoint trong Controller tương ứng
Vào Controller (ví dụ `ProductsController.cs`):
```csharp
[HttpGet("catalog/products")]
[AllowAnonymous]
public Task<IResult> ListProducts()
{
    return _dispatcher.DispatchAsync(
        HttpContext,
        "products",   // Tên thư mục hoặc service trong Seeds/
        "products",   // Tên file JSON trong Seeds/ (không cần đuôi .json)
        o => null!,   // Callback gRPC thật (truyền null khi đang làm mock)
        null!,        // Parser Protobuf (truyền null khi chưa có proto)
        successMessage: "Products retrieved successfully."
    );
}
```

#### Bước 2: Tạo file JSON dữ liệu mẫu trong `Seeds/{feature}/`
Tạo file `Seeds/products/products.json`:
```json
{
  "items": [
    {
      "id": "prod-001",
      "name": "Bàn phím cơ không dây",
      "price": 1250000,
      "status": "Active"
    }
  ],
  "total": 1
}
```

#### Bước 3: Đảm bảo Service đang ở chế độ Mock & Test
Trong `gateway.runtime.json`, đảm bảo `"catalog": { "Mode": "Mock" }`.  
Mở Swagger `http://localhost:8000/swagger` và thực thi API $\rightarrow$ Gateway tự động bọc dữ liệu vào `ApiResponse<T>` chuẩn kèm `traceId` và `timestamp`!

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
* Hoặc ép toàn bộ request dùng Mock:
  ```http
  X-Mock-Mode: true
  ```
Gateway sẽ ưu tiên Header của request cao nhất, giúp bạn test song song mà không ảnh hưởng người khác.

---

## PHẦN 3: HƯỚNG DẪN TÍNH NĂNG BYPASS AUTH MODE

### 1. Ý nghĩa & Vấn đề giải quyết:
Khi phát triển giao diện Frontend, nhiều trang màn hình yêu cầu phải có Token đăng nhập (ví dụ: Xem thông tin cá nhân `policy: "authenticated"`, hoặc Đăng sản phẩm `policy: "seller"`). Nếu Backend `UserService` chưa chạy thật hoặc dev không muốn tốn thời gian gọi API login để lấy token:
$\rightarrow$ **Bypass Auth Mode** cho phép bạn gọi các API này hoàn toàn ẩn danh mà **không bị chặn mã lỗi 401 Unauthorized hay 403 Forbidden**!

### 2. Cách kích hoạt:
Mở file `gateway.runtime.json`, sửa:
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
* **`GET http://localhost:8000/health/live` (Liveness Probe)**:
  - Trả về HTTP 200 OK nếu tiến trình Gateway đang sống. Kubernetes sử dụng endpoint này để biết container có bị treo (deadlock) hay không để restart.
* **`GET http://localhost:8000/health/ready` (Readiness Probe)**:
  - Trả về HTTP 200 OK khi Gateway đã sẵn sàng tiếp nhận lưu lượng (Redis đã kết nối, MockEngine đã tải xong định nghĩa).

---

### 2. Quản Lý Hệ Thống Health Prober Daemons Của 8 Services:
Mỗi backend service có một luồng Prober Daemon chạy ngầm trong Gateway. Mặc định khi khởi động, các daemon ở trạng thái `Disabled` để tiết kiệm tài nguyên.

#### A. Xem trạng thái sức khỏe của toàn bộ 8 services:
```bash
curl -X GET http://localhost:8000/api/v1/gateway/prober/status \
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
curl -X PUT http://localhost:8000/api/v1/gateway/prober/catalog \
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
curl -X POST http://localhost:8000/api/v1/gateway/prober/check/catalog \
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
    "title": "Service Unavailable",
    "status": 503,
    "detail": "Service 'catalog' is currently unhealthy and unavailable.",
    "errorCode": "DOWNSTREAM_UNHEALTHY",
    "traceId": "0HNPH0O1RS5U4"
  }
  ```
- *Lợi ích:* Giúp Gateway không bị treo luồng khi chờ timeout của service chết, bảo vệ toàn bộ hệ thống không bị sập dây chuyền (Cascading Failure).
