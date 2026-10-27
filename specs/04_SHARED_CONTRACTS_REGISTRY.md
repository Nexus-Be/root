# 04 — ĐĂNG KÝ HỢP ĐỒNG GIAO TIẾP DÙNG CHUNG (SHARED CONTRACTS REGISTRY)

> **Trạng thái triển khai (2026-10-27):** ✅ Đã chuyển dịch toàn diện sang chuẩn hợp đồng **RESTful DTOs (JSON over HTTP)** cho toàn bộ giao tiếp đồng bộ. **BÃI BỎ VÀ LOẠI BỎ HOÀN TOÀN PROTOBUF (`shop.proto`)**. Giao tiếp sự kiện dùng chung tiếp tục sử dụng **RabbitMQ MassTransit Events**. Việc chuyển đổi này giải quyết dứt điểm các lỗi lệch hash, xóa bỏ hoàn toàn rào cản gRPC và cho phép phát triển, kiểm thử độc lập nhanh chóng.
> **Nguồn sự thật:** code Gateway DTOs (`src/Services/ApiGateway/Nexus.Gateway/Dtos/`) và MassTransit Integration Events (`Nexus.Contracts.Events`).
> **Cập nhật lần cuối:** 2026-10-27.

Tài liệu này xác định vị trí nguồn sự thật duy nhất (Single Source of Truth) của các bản hợp đồng dữ liệu REST DTOs và các sự kiện dùng chung (Domain Events) qua RabbitMQ.

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

Quy trình phát triển API mới chuẩn mực không còn phụ thuộc vào `protoc` hay gRPC compilation:

```
[ Developer / AI Agent ]
           │
           ▼ (Bước 1) Khai báo DTOs tại Gateway:
           │         src/Services/ApiGateway/Nexus.Gateway/Dtos/{service}/{feature}Dtos.cs
           │
           ▼ (Bước 2) Tạo Seed JSON tương ứng phục vụ Mock Engine:
           │         src/Services/ApiGateway/Nexus.Gateway/Seeds/{service}/{operation}.json
           │
           ▼ (Bước 3) Viết Gateway Controller Action (Kế thừa GatewayBaseController):
           │         Gọi ForwardAsync / ForwardPagedAsync / ForwardNoContentAsync
           │
           ▼ (Bước 4) Triển khai REST Controller tại Microservice backend:
           │         src/Services/{Service}/{Service}.Api/Controllers/{Feature}Controller.cs
           │
           ▼ (Bước 5) Kiểm thử độc lập:
           │         - Test Mock Mode tại Gateway: pytest / dotnet test / cURL
           │         - Test Real Mode tại Microservice: dotnet test / cURL
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

## 4. DANH MỤC EVENT DÙNG CHUNG QUA RABBITMQ (MASSTRANSIT EVENTS)

> **Trạng thái (2026-10-24):** ❌ **6/8 event trong bảng dưới đây không tồn tại trong code.** Toàn hệ thống chỉ có **1 đường publish còn sống** (`User.Application/Services/Auth/AuthService.cs:147,253` phát `SendOtpEmailIntegrationEvent`); `Wallet` có 4 lời gọi `Publish` (`Wallet.Application/Consumers/StockReservedConsumer.cs:33,50,83,95`) nhưng **nằm trong consumer chưa từng chạy** nên không tính là publisher sống. Có **3 consumer** (Notification nhận OTP, Log nhận `ILogEventOccurred`, Wallet nhận `IStockReservedEvent`). Hai interface event còn lại chỉ được **khai báo**, không ai publish.

| Tên Event | Publisher (khai báo) | Consumers (khai báo) | Trạng thái thực tế (2026-10-24) |
|:---|:---|:---|:---|
| `IOrderSubmittedEvent` | `Commerce` | `Catalog`, `Notification`, `Log` | ❌ Không tồn tại trong code (0 interface, 0 publisher) |
| `IStockReservedEvent` | `Catalog` | `Commerce`, `Wallet`, `Log` | ⚠️ **Chỉ có consumer** `Wallet/.../StockReservedConsumer.cs:13`; **0 publisher** (Catalog chưa có code publish) |
| `IStockReservationFailedEvent` | `Catalog` | `Commerce`, `Notification` | ❌ Không tồn tại |
| `IPaymentCompletedEvent` | `Wallet` | `Commerce`, `Fulfillment`, `Notification` | ⚠️ Interface được khai báo (`Wallet/Wallet.Domain/Events/WalletEvents.cs`), **0 lời gọi publish** |
| `IPaymentFailedEvent` | `Wallet` | `Commerce`, `Catalog` | ⚠️ Khai báo, **0 lời gọi publish** |
| `IShipmentCreatedEvent` | `Fulfillment` | `Commerce`, `Notification`, `Log` | ❌ Không tồn tại |
| `IAuctionEndedEvent` | `Auction` | `Commerce`, `Notification`, `Log` | ❌ Không tồn tại |
| `ILogEventOccurred` | Mọi service | `Log` | ⚠️ Consumer có (`Log.Application/Consumers/GlobalLogConsumer.cs:10`), **0 publisher** trong 9 repo |
| `SendOtpEmailIntegrationEvent` | `User` (`AuthService.cs:147`, `:253`) | `Notification` (`SendOtpEmailConsumer.cs:9`) | ✅ **Hoạt động thật** — 2 bản khai báo giống hệt nhau, cùng namespace `Nexus.Contracts.Events` ⇒ MassTransit MessageUrn khớp |
| `ServiceUnhealthyIntegrationEvent` | `ApiGateway` (`HealthProber/SagaRollbackPublisher.cs:8`) | (không có) | ⚠️ Được khai báo; publisher **không publish gì** (chỉ log, `return Task.CompletedTask`) |

### 4.1 Payload của các event còn tồn tại

```csharp
// User/User.Application/Contracts/SendOtpEmailIntegrationEvent.cs
// Notification/Notification.Application/Contracts/SendOtpEmailIntegrationEvent.cs  (byte-identical)
namespace Nexus.Contracts.Events;
public record SendOtpEmailIntegrationEvent(
    string Email, string FullName, string Otp, int ExpiresInMinutes = 5);

// Wallet/Wallet.Domain/Events/WalletEvents.cs
public interface IStockReservedEvent { Guid OrderId; Guid ReservationId; DateTimeOffset Timestamp; }
public interface IPaymentCompletedEvent { Guid OrderId; Guid TransactionId; decimal Amount; DateTimeOffset Timestamp; }
public interface IPaymentFailedEvent { Guid OrderId; string Reason; DateTimeOffset Timestamp; }

// Log/Log.Domain/Events/LogEvents.cs:3
public interface ILogEventOccurred { /* ServiceName, EventType, ActorUserId, EntityName, EntityId, DetailsJson */ }
```

**Ghi chú thiết kế:** event record khai báo **2 lần ở 2 repo** (`User` và `Notification`) là cách duy nhất hiện tại để giữ tính self-contained của submodule. Đây là điểm cần quyết định: hoặc chấp nhận trùng lặp có kiểm soát (kèm test so khớp schema), hoặc tách `Nexus.Contracts` thành NuGet package dùng chung.
