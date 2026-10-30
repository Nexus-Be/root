# 04 — ĐĂNG KÝ HỢP ĐỒNG GIAO TIẾP DÙNG CHUNG (SHARED CONTRACTS REGISTRY)

> **Trạng thái triển khai (2026-10-30):** ✅ Đã chuyển dịch toàn diện sang chuẩn hợp đồng **RESTful DTOs (JSON over HTTP)** cho toàn bộ giao tiếp. **BÃI BỎ VÀ LOẠI BỎ HOÀN TOÀN PROTOBUF (`shop.proto`) VÀ RABBITMQ / MASSTRANSIT EVENTS**. Toàn bộ giao tiếp giữa các service chuyển sang gọi trực tiếp RESTful API.
> **Nguồn sự thật:** code Gateway DTOs (`src/Services/ApiGateway/Nexus.Gateway/Dtos/`) và REST Controllers tại các microservices.
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này xác định vị trí nguồn sự thật duy nhất (Single Source of Truth) của các bản hợp đồng dữ liệu REST DTOs cho toàn hệ thống.

---

## 1. HỢP ĐỒNG GIAO TIẾP ĐỒNG BỘ — RESTFUL DTOs (DUY NHẤT)

Kể từ bản kiến trúc tháng 10/2026, Nexus chuẩn hóa giao tiếp đồng bộ giữa ApiGateway và 8 Microservices hoàn toàn bằng **RESTful API (JSON over HTTP)**:
1. **Vị trí Hợp đồng DTO**:
   - Phía Gateway: `src/Services/ApiGateway/Nexus.Gateway/Dtos/{Service}/`
   - Phía Microservice: `src/Services/{Service}/{Service}.Application/DTOs/` hoặc `Api/Controllers/`
2. **Quy chuẩn Casing & Đóng Gói**:
   - HTTP JSON Request/Response: `camelCase`.
   - C# DTO Properties: `PascalCase`.
   - Enum Serialization: `PascalCaseJsonStringEnumConverter` hoặc `JsonStringEnumConverter`.
   - Mọi kết quả đơn lẻ bọc trong `ApiResponse<T>`.
   - Mọi kết quả phân trang bọc trong `ApiResponse<PagedData<T>>`.
   - Mọi kết quả rỗng (204) bọc trong `ApiResponse<object>`.
   - Mọi lỗi nghiệp vụ và lỗi hệ thống bọc trong `ApiErrorResponse` (RFC 9110).

---

## 2. QUY TRÌNH THÊM MỚI HOẶC NÂNG CẤP API ĐỒNG BỘ (RESTFUL WORKFLOW)

Quy trình phát triển API mới chuẩn mực không còn phụ thuộc vào `protoc` hay gRPC compilation, loại bỏ mock engine để chạy trực tiếp:

```
[ Developer / AI Agent ]
           │
           ▼ (Bước 1) Khai báo DTOs tại Gateway và Backend Microservice:
           │         Gateway: src/Services/ApiGateway/Nexus.Gateway/Dtos/{service}/{feature}Dtos.cs
           │         Backend: src/Services/{Service}/{Service}.Application/Services/{Feature}/{Feature}Requests.cs & Responses.cs
           │
           ▼ (Bước 2) Triển khai Feature Service tại Microservice backend:
           │         src/Services/{Service}/{Service}.Application/Services/{Feature}/I{Feature}Service.cs & {Feature}Service.cs
           │
           ▼ (Bước 3) Triển khai REST Controller tại Microservice backend:
           │         src/Services/{Service}/{Service}.Api/Controllers/{Feature}Controller.cs
           │
           ▼ (Bước 4) Viết Gateway Controller Action (Kế thừa GatewayBaseController):
           │         src/Services/ApiGateway/Nexus.Gateway/Controllers/{Feature}Controller.cs
           │         Ủy quyền downstream qua ForwardAsync / ForwardPagedAsync / ForwardNoContentAsync
           │
           ▼ (Bước 5) Kiểm thử đầu cuối:
           │         - Kiểm thử unit & integration test: dotnet test <Solution>.sln -c Release
           │         - Kiểm thử gọi API qua Gateway cURL / Swagger: http://localhost:8080/api/v1/...
```

### Nguyên Tắc An Toàn Tương Thích Ngược (Backward Compatibility):
- **Tính cộng gộp (Additive Changes)**: Luôn cho phép thêm trường mới (nullable hoặc có giá trị mặc định).
- **Không đổi kiểu hoặc xóa trường đang sử dụng**: Nếu cần deprecate, đánh dấu `[Obsolete]` trên DTO.
- **Header Định Danh (Identity Propagation)**: Toàn bộ thông tin định danh và ngữ cảnh truy vết được tự động chuyển tiếp qua HTTP Request Headers:
  - `Authorization: Bearer <JWT>`
  - `x-user-id`: ID người dùng
  - `x-user-roles`: Danh sách quyền (ngăn cách bởi dấu phẩy)
  - `x-user-email`: Email người dùng
  - `x-trace-id` & `traceparent`: Mã truy vết phân tán W3C

---

## 3. LỊCH SỬ PROTOBUF VÀ LÝ DO BÃI BỎ (DEPRECATION LOG)

> **Thông báo bãi bỏ:** Toàn bộ các file `shop.proto` và hạ tầng gRPC đã chính thức bị **loại bỏ (deprecated & removed)** khỏi Gateway và các microservices vì các lý do sau:
> 1. 5/9 services trong hệ sinh thái chưa từng hỗ trợ gRPC server, gây thiếu hụt điểm vào đồng bộ.
> 2. Xảy ra hiện tượng lệch hash nghiêm trọng (3 hash khác nhau trên 4 file `shop.proto`), gây khó khăn khi đồng bộ.
> 3. Khó khăn cho Frontend và QA khi debug bằng cURL/Postman.
> 4. Chuẩn RESTful HTTP/JSON tương thích hoàn hảo với Kestrel HTTP/1.1 & HTTP/2 pooling trong .NET 8, đem lại hiệu năng vượt trội và dễ dàng scale.

---

## 4. LỊCH SỬ BÃI BỎ EVENT BROKER VÀ MASSTRANSIT (DEPRECATION LOG)

> **Thông báo bãi bỏ (2026-10-30):** Toàn bộ các Consumer, Event Contracts, MassTransit packages và cấu hình RabbitMQ Message Broker đã chính thức bị **gỡ bỏ hoàn toàn (decommissioned & removed)** khỏi 8 Microservices và API Gateway.
> - User Service gửi OTP email chuyển sang gọi trực tiếp HTTP REST API của Notification Service (`POST /api/v1/notifications/email`) qua `IEmailNotificationClient`.
> - Giao tiếp giữa các service chuyển sang mô hình RESTful API đồng bộ với cơ chế timeout, retry, và circuit breaker.
> - Xóa bỏ toàn bộ các bảng `InboxState`, `OutboxMessage`, `OutboxState` khỏi cơ sở dữ liệu.


