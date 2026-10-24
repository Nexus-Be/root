# TRUNG TÂM TÀI LIỆU KỸ THUẬT HỆ THỐNG NEXUS
## (NEXUS SYSTEM DOCUMENTATION PORTAL)

Chào mừng bạn đến với trung tâm tài liệu kỹ thuật toàn diện của hệ sinh thái **Nexus Microservices Backend (.NET 8 LTS, C# 12)**.

---

## 1. CẨM NANG DÀNH CHO DEVELOPER (DEVELOPER GUIDES)

Tài liệu thực chiến giúp lập trình viên bắt tay vào làm việc ngay:

* **[Cẩm Nang Phát Triển & Kiểm Thử Độc Lập Từng Service (INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md)](INDEPENDENT_SERVICE_DEVELOPMENT_GUIDE.md)**  
  👉 **BẮT BUỘC ĐỌC ĐỐI VỚI DEV:** Hướng dẫn cách một developer chỉ phụ trách 1 service có thể tự code, chạy database riêng và test độc lập với API Gateway mà **KHÔNG CẦN bật toàn bộ 9 services**, tiết kiệm RAM (< 2GB).

* **[Cẩm Nang Kiểm Thử Độc Lập gRPC, Event Bus & Chẩn Đoán Lỗi (ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md)](ISOLATED_TESTING_AND_DEBUGGING_GUIDE.md)**  
  👉 **HƯỚNG DẪN TEST POSTMAN & DEBUG:** Chi tiết cách dùng Postman gRPC Request (Server Reflection) test từng Function, Postman HTTP REST test từng Event Consumer qua RabbitMQ Management API, và quy trình 3 tầng chẩn đoán lỗi chuyên sâu bằng Grafana Tempo & Dead-Letter Queues.

* **[Quy Chuẩn Kiến Trúc Clean Architecture 4 Tầng Cho Microservices (CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)](CLEAN_ARCHITECTURE_SERVICE_GUIDE.md)**  
  👉 Hướng dẫn cấu trúc thư mục 4 tầng (`*.Domain`, `*.Application`, `*.Infrastructure`, `*.Api`): phần nào làm cái nào, Entity viết ở đâu, DbContext cấu hình thế nào, gRPC Server viết ở đâu, và quy tắc thông báo lỗi 100% tiếng Anh.

* **[Hướng Dẫn Tạo Mock API, Chuyển Đổi Runtime, Bypass Auth & Health Check (GUIDE_MOCK_DATA_GATEWAY.md)](GUIDE_MOCK_DATA_GATEWAY.md)**  
  👉 Hướng dẫn quy trình 3 bước tạo Mock API chuẩn duy nhất (Controller Action + Seeds/ Fixture), kiến trúc pipeline 6 bước, cách chuyển `Mock` $\leftrightarrow$ `Real`, bật Bypass Auth để test không cần token, và sử dụng Health Prober.

* **[Đặc Tả Kiến Trúc & Cẩm Nang 15 Thư Mục Của API Gateway (GATEWAY_ARCHITECTURE_AND_FOLDERS.md)](GATEWAY_ARCHITECTURE_AND_FOLDERS.md)**  
  👉 Bức tranh toàn cảnh về Edge API Gateway, giải thích chi tiết chức năng của 15 thư mục mã nguồn và danh mục các tính năng cốt lõi (Fine-grained Rate Limiting, Dual-Runtime, Enum conversion...).

* **[Lộ Trình Các Bước Kế Tiếp & Bộ Checklist Triển Khai Microservices (NEXT_STEPS_AND_CHECKLIST.md)](NEXT_STEPS_AND_CHECKLIST.md)**  
  👉 Kim chỉ nam hành động: Lộ trình 4 giai đoạn phát triển 8 services theo thứ tự phụ thuộc dữ liệu và checklist 7 bước code service chuẩn.

* **[Đặc Tả Danh Mục Entity & Enum Chuẩn Form Cho Frontend (FRONTEND_ENTITY_AND_ENUM_CATALOG.md)](FRONTEND_ENTITY_AND_ENUM_CATALOG.md)**  
  👉 Tra cứu 78 Enums và 88 Entities chuẩn kiểu dữ liệu, nullability và validation cho đội ngũ Frontend.

---

## 2. HƯỚNG DẪN HẠ TẦNG KỸ THUẬT CHUYÊN BIỆT (INFRASTRUCTURE GUIDES)

Bộ tài liệu chuyên sâu về từng thành phần hạ tầng trong thư mục `docs/infra/`:

* **[Hướng Dẫn RabbitMQ & Message Bus MassTransit (infra/RABBITMQ_GUIDE.md)](infra/RABBITMQ_GUIDE.md)**  
  👉 Bản chất Event-Driven, tài khoản kết nối (`guest` / `MatkhaucuaTui123@`), cách sử dụng Web UI (`:15672`), xem hàng đợi, soi nội dung JSON tin nhắn, và xử lý lỗi hàng đợi `_error`.

* **[Hướng Dẫn Redis: Rate Limiting & Lưu Trữ OTP (infra/REDIS_GUIDE.md)](infra/REDIS_GUIDE.md)**  
  👉 Bản chất Distributed Rate Limiter tại Gateway, cấu trúc key Rate Limit bucket, cấu trúc key OTP tại UserService, cẩm nang lệnh `redis-cli`, và mẹo xóa key giải phóng hạn mức.

* **[Hướng Dẫn Giám Sát Phân Tán: Grafana & Tempo Traces (infra/OBSERVABILITY_GUIDE.md)](infra/OBSERVABILITY_GUIDE.md)**  
  👉 Chuẩn W3C OpenTelemetry, cách lấy mã `X-Trace-Id` từ response header dán vào Grafana Explore (`:3000`) để xem biểu đồ Waterfall, phát hiện điểm nghẽn hiệu năng và lỗi SQL N+1.

* **[Hướng Dẫn 8 Cơ Sở Dữ Liệu PostgreSQL & EF Core Migrations (infra/POSTGRES_DATABASES_GUIDE.md)](infra/POSTGRES_DATABASES_GUIDE.md)**  
  👉 Bản đồ 8 cơ sở dữ liệu độc lập (ports `5433` - `5440`), hướng dẫn kết nối qua DBeaver / pgAdmin, quy trình tạo và cập nhật Code-First Database Migrations bằng EF Core 8.

---

## 3. QUYẾT ĐỊNH KIẾN TRÚC & ĐẶC TẢ HỆ THỐNG (SYSTEM ARCHITECTURE & ADRS)

* **[Hệ Thống 15 Quyết Định Kiến Trúc Toàn Hệ Thống (docs/adr/ADR.md)](adr/ADR.md)**  
  👉 Các quyết định kiến trúc bất biến đã được phê duyệt: .NET 8, Clean Architecture, No-Repository, gRPC, RabbitMQ MassTransit, Checkout Saga, Dual-mode Gateway, Zero-validation Controller, Redis Rate Limit...

* **[Kiến Trúc Health Prober & Chiến Lược Quản Lý Log Tập Trung (HEALTH_AND_LOGGING_ARCHITECTURE.md)](HEALTH_AND_LOGGING_ARCHITECTURE.md)**  
  👉 Nguyên lý Prober Daemon, State Machine của Health Check, Circuit Breaker Fast-Fail (503), Docker Self-Healing, và chiến lược gom log tập trung về `LogService`.

* **[Bộ Đặc Tả Kỹ Thuật Trung Tâm (specs/README.md)](../specs/README.md)**  
  👉 Bao gồm sơ đồ C4 Container ([00_MASTER_SYSTEM_ARCHITECTURE.md](../specs/00_MASTER_SYSTEM_ARCHITECTURE.md)), Bảng quy hoạch cổng mạng ([01_SERVICE_CATALOG_PORT_MAP.md](../specs/01_SERVICE_CATALOG_PORT_MAP.md)), và Hướng dẫn cho AI Agents ([05_AI_AGENT_ORCHESTRATION_GUIDELINES.md](../specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md)).
