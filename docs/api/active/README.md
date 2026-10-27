# 🟢 DANH MỤC API ĐÃ NỐI & CHẠY THỰC TẾ QUA API GATEWAY (REAL MODE)

> **Trạng thái tài liệu:** ✅ CÓ (Đã kiểm chứng thực tế qua cURL và Docker containers ngày 2026-10-28)  
> **Nguồn sự thật:** Kết quả thực thi trực tiếp trên API Gateway (`http://localhost:8080`) kết nối với các microservices backend qua RESTful HTTP/JSON và RabbitMQ.  
> **Cổng API Gateway duy nhất:** `http://localhost:8080`

---

## 1. TỔNG QUAN KIẾN TRÚC KẾT NỐI (SYSTEM ARCHITECTURE)

Hệ thống Nexus vận hành với **API Gateway duy nhất tại cổng 8080**. Khi client gửi request kèm header `X-Gateway-Mode: Real`, Gateway sẽ thực hiện forward trực tiếp xuống các microservices backend tương ứng:

```
[ Frontend / Client ]
         │ (HTTP/REST JSON - Cổng 8080)
         ▼
 ┌───────────────┐
 │  ApiGateway   │ (Port 8080 - JWT Auth & Identity Propagation)
 └───────┬───────┘
         │
         ├──▶ [ User Service ] : 8001 (/api/v1/auth/*, /api/v1/me) ──▶ PostgreSQL (Neon) & Redis (OTP) & RabbitMQ
         ├──▶ [ Wallet Service ] : 8008 (/api/v1/wallets/me)
         └──▶ [ Notification Service ] : 8007 (RabbitMQ Event Consumer)
```

---

## 2. BẢNG TRẠNG THÁI CÁC CONTROLLER & API ĐÃ HOẠT ĐỘNG (ACTIVE CONTROLLERS)

| STT | Gateway Controller | Backend Service | Cổng Backend | Số API Đã Chạy Thật | Tài Liệu Chi Tiết |
|:---:|:---|:---|:---:|:---:|:---|
| 1 | `AuthController` | `User.Api` | `8001` | 4 endpoints | [`AUTH_CONTROLLER.md`](./AUTH_CONTROLLER.md) |
| 2 | `UsersController` | `User.Api` | `8001` | 1 endpoint | [`USERS_CONTROLLER.md`](./USERS_CONTROLLER.md) |
| 3 | `WalletController` | `Wallet.Api` | `8008` | 1 endpoint | [`WALLET_CONTROLLER.md`](./WALLET_CONTROLLER.md) |

---

## 3. CƠ CHẾ BẢO MẬT & TRUYỀN DANH TÍNH (IDENTITY PROPAGATION)

1. **Khách hàng gọi Gateway (`:8080`)**:
   - Truyền JWT Token trong header: `Authorization: Bearer <accessToken>`.
   - Bật chế độ gọi backend thật: `X-Gateway-Mode: Real`.
2. **API Gateway xử lý**:
   - Xác thực chữ ký JWT bằng Symmetric Key (`Jwt:Key`).
   - Kiểm tra hạn dùng (`exp`), `issuer`, và `audience`.
   - Trích xuất claim `sub` $\rightarrow$ gán vào header `x-user-id`.
   - Trích xuất claim `role` $\rightarrow$ gán vào header `x-user-roles`.
   - Trích xuất claim `email` $\rightarrow$ gán vào header `x-user-email`.
   - Tự động sinh hoặc chuyển tiếp `x-trace-id` để phục vụ phân tích log/trace trên Tempo & Grafana.
3. **Backend Service tiếp nhận**:
   - Chỉ cần đọc header `x-user-id` trực tiếp từ request, không cần tốn chi phí giải mã lại JWT, bảo đảm hiệu năng cao và tuân thủ Zero-Trust nội bộ.

---

## 4. CHI TIẾT TỪNG CONTROLLER
- 🔐 [Tài liệu AuthController](./AUTH_CONTROLLER.md)
- 👤 [Tài liệu UsersController](./USERS_CONTROLLER.md)
- 💳 [Tài liệu WalletController](./WALLET_CONTROLLER.md)
