# 🟢 DANH MỤC API ĐÃ NỐI & CHẠY THỰC TẾ QUA API GATEWAY (REAL MODE)

> **Trạng thái tài liệu:** ✅ CÓ (Đã kiểm chứng thực tế qua Unit/Integration tests và Docker containers ngày 2026-10-30)  
> **Nguồn sự thật:** Kết quả thực thi trực tiếp trên API Gateway (`http://localhost:8080`) kết nối với các microservices backend qua chuẩn 100% RESTful HTTP/JSON (Bãi bỏ RabbitMQ, MassTransit và gRPC).  
> **Cổng API Gateway duy nhất:** `http://localhost:8080`

---

## 1. TỔNG QUAN KIẾN TRÚC KẾT NỐI (SYSTEM ARCHITECTURE)

Hệ thống Nexus vận hành với **API Gateway duy nhất tại cổng 8080**. Khi client gửi request kèm header `X-Gateway-Mode: Real`, Gateway sẽ thực hiện forward trực tiếp xuống các microservices backend tương ứng:

```
[ Frontend / Client ]
         │ (HTTP/REST JSON - Cổng 8080)
         ▼
 ┌───────────────┐
 │  ApiGateway   │ (Port 8080 - JWT Auth & Identity Propagation & Reverse Proxy)
 └───────┬───────┘
         │ (Forward REST HTTP/JSON)
         ├──▶ [ User Service ]         : 8001 (/api/v1/auth/*, /api/v1/me, /api/v1/user/*, /api/v1/sellers/*)
         ├──▶ [ Catalog Service ]      : 8002 (/api/v1/categories/*, /api/v1/products/*)
         ├──▶ [ Commerce Service ]     : 8003 (/api/v1/carts/*, /api/v1/orders/*)
         ├──▶ [ Log Service ]          : 8004 (/api/v1/log/*)
         ├──▶ [ Auction Service ]      : 8005 (/api/v1/auctions/*)
         ├──▶ [ Fulfillment Service ]  : 8006 (/api/v1/warehouses/*, /api/v1/shipments/*)
         ├──▶ [ Notification Service ] : 8007 (/api/v1/notifications/*)
         ├──▶ [ Wallet Service ]       : 8008 (/api/v1/wallets/*, /api/v1/admin/wallets/*)
         └──▶ [ CheckHeal Service ]    : 8009 (/api/v1/healthcheck/*)
```

---

## 2. BẢNG TRẠNG THÁI CÁC CONTROLLER & API ĐÃ HOẠT ĐỘNG (ACTIVE CONTROLLERS)

| STT | Gateway Controller | Backend Service | Cổng Backend | Trạng Thái Triển Khai | Tài Liệu Chi Tiết |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | `AuthController` | `User.Api` | `8001` | ✅ 10 endpoints | [`AUTH_CONTROLLER.md`](./AUTH_CONTROLLER.md) (Xem chi tiết tại [`auth/`](./auth/)) |
| 2 | `UsersController` | `User.Api` | `8001` | ✅ 3 endpoints | [`USERS_CONTROLLER.md`](./USERS_CONTROLLER.md) |
| 3 | `WalletController` | `Wallet.Api` | `8008` | ✅ 8 endpoints | [`WALLET_CONTROLLER.md`](./WALLET_CONTROLLER.md) |
| 4 | `CategoriesController` / `ProductsController` | `Catalog.Api` | `8002` | ✅ REST Endpoints | [`CATALOG_CONTROLLER.md`](./CATALOG_CONTROLLER.md) |
| 5 | `CartController` / `OrdersController` | `Commerce.Api` | `8003` | ✅ REST Endpoints | [`COMMERCE_CONTROLLER.md`](./COMMERCE_CONTROLLER.md) |
| 6 | `AuctionController` | `Auction.Api` | `8005` | ✅ REST Endpoints | [`AUCTION_CONTROLLER.md`](./AUCTION_CONTROLLER.md) |
| 7 | `FulfillmentController` | `Fulfillment.Api` | `8006` | ✅ REST Endpoints | [`FULFILLMENT_CONTROLLER.md`](./FULFILLMENT_CONTROLLER.md) |
| 8 | `NotificationController` | `Notification.Api` | `8007` | ✅ REST Endpoints | [`NOTIFICATION_CONTROLLER.md`](./NOTIFICATION_CONTROLLER.md) |
| 9 | `LogController` | `Log.Api` | `8004` | ✅ REST Endpoints | [`LOG_CONTROLLER.md`](./LOG_CONTROLLER.md) |
| 10 | `HealthProberController` | `CheckHeal.Api` | `8009` | ✅ REST Endpoints | [`CHECKHEAL_CONTROLLER.md`](./CHECKHEAL_CONTROLLER.md) |

---

## 3. CƠ CHẾ BẢO MẬT & TRUYỀN DANH TÍNH (IDENTITY PROPAGATION)

1. **Khách hàng gọi Gateway (`:8080`)**:
   - Truyền JWT Token trong header: `Authorization: Bearer <accessToken>`.
   - Bật chế độ gọi backend thật: `X-Gateway-Mode: Real`.
2. **API Gateway xử lý**:
   - Thẩm định chữ ký JWT bằng Symmetric Key (`Jwt:Key`).
   - Kiểm tra hạn dùng (`exp`), `issuer`, và `audience`.
   - Trích xuất claim `sub` $\rightarrow$ gán vào header `x-user-id`.
   - Trích xuất claim `role` $\rightarrow$ gán vào header `x-user-roles`.
   - Trích xuất claim `email` $\rightarrow$ gán vào header `x-user-email`.
   - Tự động sinh hoặc chuyển tiếp `x-trace-id` để phục vụ phân tích log/trace trên Tempo & Grafana.
3. **Backend Service tiếp nhận**:
   - Sử dụng header `x-user-id` và `x-user-roles` để thực hiện kiểm tra quyền hạn nội bộ (RBAC).
   - Truy vấn trực tiếp database nội bộ của service (`DbContext`), cấm query chéo database service khác.
