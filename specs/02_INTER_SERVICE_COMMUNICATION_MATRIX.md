# 02 — MA TRẬN GIAO TIẾP LIÊN DỊCH VỤ (INTER-SERVICE COMMUNICATION MATRIX)

> **Trạng thái triển khai (2026-10-30):** ✅ Đã chuyển dịch toàn diện sang **100% RESTful (JSON over HTTP)** cho toàn bộ giao tiếp từ Gateway $\rightarrow$ Backend Microservices và giữa các Microservices với nhau. **CẤM TUYỆT ĐỐI gRPC**. Bãi bỏ hoàn toàn RabbitMQ, MassTransit, Saga State Machine và Outbox/Inbox tables.
> **Nguồn sự thật:** code 9 repo (`PLAN-20261030-0335-DECOMMISSION-SAGA-RABBITMQ-AND-OUTBOX-INBOX.md`).
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này xác định ma trận giao tiếp **100% RESTful HTTP/JSON** giữa API Gateway và 8 microservices, cũng như các tương tác trực tiếp liên microservice.

---

## 1. NGUYÊN TẮC GIAO TIẾP ĐỒNG BỘ 100% RESTFUL HTTP/JSON

| Tiêu Chí | Đặc Tả |
|:---|:---|
| **Mục đích** | Truy vấn dữ liệu (Query), thực hiện lệnh (Command), và trao đổi thông tin liên service. |
| **Giao thức** | HTTP/1.1 hoặc HTTP/2 (Keep-Alive Pooling) trên nền chuẩn JSON (`camelCase`). **CẤM gRPC**. |
| **Bảo mật & Ủy quyền** | JWT Bearer Token tại Gateway, metadata `x-user-id`, `x-user-roles`, `x-user-permissions` chuyển tiếp downstream. |
| **Độ trễ** | Rất thấp (< 5-10ms trong mạng nội bộ Docker/VPS). |
| **Khả năng phục hồi** | Xử lý qua timeout ngắn, circuit breaker tại Gateway, và client retry có backoff. |

---

## 2. MA TRẬN GIAO TIẾP LIÊN SERVICE (COMMUNICATION MATRIX)

| Nguồn Gọi (Caller) | Đích Đến (Callee) | Giao Thức | Tên Phương Thức / Route | Mục Đích Nghiệp Vụ | Trạng thái triển khai |
|:---|:---|:---:|:---|:---|:---|
| **ApiGateway** | `UserService` | REST | `/api/v1/auth/*`, `/api/v1/user/*`, `/api/v1/admin/user/*` | Quản lý người dùng, đăng ký, đăng nhập và hồ sơ | ✅ Gateway hỗ trợ Mock/Real qua `ForwardAsync` |
| **ApiGateway** | `CatalogService` | REST | `/api/v1/products/*`, `/api/v1/categories/*`, `/api/v1/inventory/*` | Truy vấn và cập nhật danh mục, sản phẩm, tồn kho | ✅ Catalog có 13 REST Controllers, Gateway hỗ trợ `ForwardAsync` |
| **ApiGateway** | `CommerceService` | REST | `/api/v1/cart/*`, `/api/v1/orders/*` | Thao tác giỏ hàng và đặt hàng | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `AuctionService` | REST | `/api/v1/auctions/*` | Tham gia và tạo phòng đấu giá | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `FulfillmentService`| REST | `/api/v1/shipments/*` | Tra cước và vận đơn | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `NotificationService`| REST | `/api/v1/notifications/*`, `/api/v1/notifications/email/*` | Quản lý thông báo người dùng, gửi email OTP/alert | ✅ Notification có `NotificationsController` & `EmailController`, Gateway hỗ trợ `ForwardAsync` |
| **ApiGateway** | `LogService` | REST | `/api/v1/logs/*`, `/api/v1/log/batch` | Ghi log, truy vấn nhật ký hệ thống | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **ApiGateway** | `WalletService` | REST | `/api/v1/wallet/*` | Tra cứu số dư, nạp, rút và giao dịch ví | ✅ Gateway chuẩn hóa qua `ForwardAsync` |
| **UserService** | `NotificationService`| REST | `POST /api/v1/notifications/email` | Gửi mã OTP xác thực qua email khi đăng ký / quên mật khẩu | ✅ Triển khai qua `IEmailNotificationClient` |
| **CommerceService**| `WalletService` | REST | `POST /api/v1/wallet/transactions` | Thanh toán đơn hàng trực tiếp qua API ví | 🎯 Thiết kế REST trực tiếp |
| **CommerceService**| `CatalogService` | REST | `POST /api/v1/inventory/reserve` | Khóa tồn kho ảo trực tiếp khi xác nhận đơn hàng | 🎯 Thiết kế REST trực tiếp |

---

## 3. QUY TẮC ĐẢM BẢO TÍNH TOÀN VẸN VÀ CHỐNG TRÙNG LẶP (IDEMPOTENCY)

1. **Idempotent REST APIs**:
   - Các API tạo giao dịch (thanh toán, trừ ví, đặt hàng) chấp nhận header `Idempotency-Key` (UUIDv4) để đảm bảo không bị trừ tiền hoặc tạo đơn 2 lần khi client retry.
2. **Timeouts & Graceful Degradation**:
   - Khi gọi liên service phụ trợ (như gửi email OTP), nếu service đích tạm thời offline, client ghi nhận structured log và trả mã lỗi rõ ràng hoặc tiếp tục với fallback an toàn.
3. **HTTP Status Codes Chuẩn Hóa**:
   - Thành công: `200 OK` (có body `ApiResponse<T>`), `201 Created` (tạo mới tài nguyên), `204 NoContent` (xóa hoặc không cần body).
   - Lỗi Client: `400 BadRequest`, `401 Unauthorized`, `403 Forbidden`, `404 NotFound`, `409 Conflict`.
   - Lỗi Server: `500 InternalServerError`, `502 BadGateway` (khi downstream service không phản hồi).
