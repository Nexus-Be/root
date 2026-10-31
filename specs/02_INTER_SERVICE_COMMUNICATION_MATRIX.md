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

### 2.1. Trạng Thái Tạm Khóa Internal API
- Toàn bộ route liên service dùng đường dẫn công khai `/api/v1/{resources}`, không còn tiền tố `/api/v1/internal`.
- Không còn thư mục `Controllers/Internal/`. Bảo mật header `X-Internal-Service-Key` đang tạm khóa, đăng ký middleware và handler đã comment.

| Nguồn Gọi (Caller) | Đích Đến (Callee) | Giao Thức | Tên Phương Thức / Route | Phân Loại | Mục Đích Nghiệp Vụ | Trạng thái triển khai |
|:---|:---|:---:|:---|:---:|:---|:---|
| **Gateway (YARP)** | `UserService` | REST | `/api/v1/auth/*`, `/api/v1/users/*`, `/api/v1/admin/users/*`, `/api/v1/sellers/*`, `/api/v1/me` | Public | Quản lý người dùng, đăng ký, đăng nhập và hồ sơ | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `CatalogService` | REST | `/api/v1/products/*`, `/api/v1/categories/*` | Public | Truy vấn và tạo sản phẩm, danh mục | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `CommerceService` | REST | `/api/v1/carts/*`, `/api/v1/orders/*` | Public | Thao tác giỏ hàng và tra cứu đơn hàng | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `AuctionService` | REST | `/api/v1/auctions/*`, `/api/v1/auctions/{id}/bids` | Public | Tham gia và tra cứu phòng đấu giá, đặt giá | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `FulfillmentService`| REST | `/api/v1/shipments/*`, `/api/v1/warehouses/*` | Public | Tra cước, thông tin kho và vận đơn | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `NotificationService`| REST | `/api/v1/notifications/*` | Public | Quản lý thông báo người dùng, preferences, devices | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `LogService` | REST | `/api/v1/logs/*`, `/api/v1/logs/event-types/*` | Public | Truy vấn nhật ký hệ thống | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `WalletService` | REST | `/api/v1/wallets/*`, `/api/v1/admin/wallets/*` | Public | Tra cứu số dư, nạp, rút và chuyển tiền ví | ✅ Forward qua YARP stream |
| **Gateway (YARP)** | `CheckHealService` | REST | `/api/v1/healthcheck/*`, `/health/*` | Public | Giám sát trạng thái hoạt động và keep-alive hệ sinh thái | ✅ Forward qua YARP stream |
| **UserService** | `NotificationService`| REST | `POST /api/v1/notifications/email/otp` | Public REST | Gửi mã OTP xác thực qua email khi đăng ký / quên mật khẩu | ✅ Triển khai qua `EmailNotificationClient` |
| **CatalogService** | `FulfillmentService`| REST | `POST /api/v1/inventories/initialize` | Public REST | Khởi tạo kho và tồn kho vật lý cho SKU sản phẩm mới tạo | ✅ Triển khai qua `FulfillmentClient` |
| **CommerceService**| `WalletService` | REST | `POST /api/v1/wallets/checkout/direct` | Public REST | Thanh toán trừ tiền trực tiếp từ ví khi xác nhận đơn | ✅ Triển khai qua `WalletClient` |
| **Các Service** | `LogService` | REST | `POST /api/v1/logs/batch` | Public REST | Thu thập và nạp nhật ký kiểm toán tập trung | ✅ Triển khai qua `LogBatchController` |

---

## 3. TRẠNG THÁI TẠM KHÓA BẢO MẬT INTERNAL (TEMPORARY INTERNAL SECURITY DISABLE)

1. **Gateway**:
   - Khối chặn `/api/v1/internal` trong `ClientContextMiddleware` đã bị comment từ 2026-10-31.
   - `SanitizeDocument` không còn xóa path internal khỏi tài liệu OpenAPI.
   - Các route liên service đi qua Gateway như API thường.
2. **Microservice**:
   - `InternalServiceAuthMiddleware` đã comment đăng ký ở toàn bộ service.
   - Không còn yêu cầu header `X-Internal-Service-Key`.
3. **Outbound HttpClient**:
   - `InternalServiceAuthHandler` đã comment khỏi đăng ký DI ở User, Catalog và Commerce.
   - Bật lại mô hình cũ cần phê duyệt rõ ràng và khôi phục đồng bộ middleware, handler, Gateway và tài liệu.

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
