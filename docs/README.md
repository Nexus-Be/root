# TRUNG TÂM TÀI LIỆU KỸ THUẬT HỆ THỐNG NEXUS
## (NEXUS SYSTEM DOCUMENTATION PORTAL)

> **Trạng thái triển khai (2026-10-31):** ✅ Kiến trúc hiện tại là 100% RESTful HTTP/JSON. gRPC, RabbitMQ, MassTransit, Saga và Outbox đã bị gỡ bỏ. Gateway là YARP reverse proxy thuần, không còn Mock Engine hay chế độ chuyển Mock/Real.
> **Nguồn sự thật:** code trong `src/Services/*` và cấu hình trong `docker-compose*.yml`. Tài liệu này chỉ là điểm điều hướng, không thay thế code.
> **Cập nhật lần cuối:** 2026-10-31.

Chào mừng bạn đến với trung tâm tài liệu kỹ thuật của hệ sinh thái **Nexus Microservices Backend (.NET 8 LTS, C# 12)**.

---

## 1. BẮT ĐẦU TỪ ĐÂU

Nếu bạn cần biết service A gọi service B như thế nào, hoặc cần deploy hệ thống lên nhiều máy chủ, đọc tài liệu này trước:

- **[Hướng Dẫn Kết Nối Dịch Vụ Toàn Hệ Thống (SERVICE_CONNECTIVITY_GUIDE.md)](SERVICE_CONNECTIVITY_GUIDE.md)**
  👉 Topology, bảng port, route Gateway, ma trận gọi liên service, biến môi trường, ba cách chạy, deploy nhiều máy chủ, firewall, TLS, timeout và chẩn đoán lỗi.

---

## 2. CẨM NANG PHÁT TRIỂN

- **[Quy Chuẩn Kiến Trúc Clean Architecture 4 Tầng (CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)](CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)**
  👉 Trách nhiệm từng tầng, Feature Co-location, quy tắc phụ thuộc, ngoại lệ Wallet dùng MediatR, quy chuẩn controller.

- **[Đặc Tả Kiến Trúc API Gateway (GATEWAY_ARCHITECTURE_AND_FOLDERS.md)](GATEWAY_ARCHITECTURE_AND_FOLDERS.md)**
  👉 Cấu trúc thư mục Gateway, pipeline middleware, YARP, rate limiting, lan truyền danh tính.

- **[Cẩm Nang Kiểm Thử Độc Lập RESTful API & Chẩn Đoán Lỗi (ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md)](ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md)**
  👉 Gọi trực tiếp Swagger/Postman/cURL tại `8001`-`8009`, đọc trace trên Grafana Tempo.

- **[Đặc Tả Entity & Enum Cho Frontend (FRONTEND_ENTITY_AND_ENUM_CATALOG.md)](FRONTEND_ENTITY_AND_ENUM_CATALOG.md)**
  👉 Danh mục enum PascalCase và entity của 8 service nghiệp vụ.

- **[Bảng Đối Chiếu Route API Cho Frontend (FRONTEND_API_ENDPOINT_MAPPING.md)](FRONTEND_API_ENDPOINT_MAPPING.md)**
  👉 Bảng route Gateway đã kiểm chứng, trỏ tới danh mục API chi tiết.

- **[Danh Mục API Hai Trạng Thái (api/README.md)](api/README.md)**
  👉 163 hồ sơ API trong `api/B_none/` và `api/A_Active/`, kèm envelope, mã lỗi và RBAC.

---

## 3. HẠ TẦNG

- **[Redis: Rate Limiting & OTP (infra/REDIS_GUIDE.md)](infra/REDIS_GUIDE.md)**
- **[Grafana & Tempo: Distributed Tracing (infra/OBSERVABILITY_GUIDE.md)](infra/OBSERVABILITY_GUIDE.md)**
- **[8 Cơ Sở Dữ Liệu PostgreSQL & EF Core Migrations (infra/POSTGRES_DATABASES_GUIDE.md)](infra/POSTGRES_DATABASES_GUIDE.md)**

---

## 4. QUYẾT ĐỊNH KIẾN TRÚC VÀ ĐẶC TẢ

- **[Architecture Decision Records (adr/ADR.md)](adr/ADR.md)**
- **[Bộ Đặc Tả Kỹ Thuật Trung Tâm (../specs/README.md)](../specs/README.md)**
- **[Hướng Dẫn Cho AI Agents (../specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md)](../specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md)**

---

## 5. TÀI LIỆU RIÊNG CỦA TỪNG SERVICE

Mỗi service tự cung cấp README và bộ `specs/` nội bộ. Các tài liệu này tuân thủ nguyên tắc self-contained, không trỏ ra ngoài repo service.

- [UserService](../src/Services/User/README.md)
- [CatalogService](../src/Services/Catalog/README.md)
- [CommerceService](../src/Services/Commerce/README.md)
- [AuctionService](../src/Services/Auction/README.md)
- [FulfillmentService](../src/Services/Fulfillment/README.md)
- [NotificationService](../src/Services/Notification/README.md)
- [LogService](../src/Services/Log/README.md)
- [WalletService](../src/Services/Wallet/README.md)
- [CheckHealService](../src/Services/CheckHeal/README.md)
- [Gateway](../src/Services/Gateway/README.md)

---

## 6. QUY ƯỚC KHI CẬP NHẬT TÀI LIỆU

- Mỗi tài liệu phải có banner trạng thái và ngày cập nhật ở đầu file.
- Không mô tả tính năng không còn trong code. Nếu một kiến trúc đã bị gỡ, xóa tài liệu đó thay vì giữ lại.
- Khi route hoặc DTO thay đổi, cập nhật đồng thời `docs/api/`, `docs/FRONTEND_API_ENDPOINT_MAPPING.md` và `docs/SERVICE_CONNECTIVITY_GUIDE.md`.
- Không đưa API key, mật khẩu hoặc connection string thật vào tài liệu. Dùng placeholder.
