# DANH MỤC FILE BẮT BUỘC PHẢI ĐỌC TRONG TỪNG REPOSITORY

Khi bắt đầu một phiên làm việc tại bất kỳ repository nào, AI Agent **BẮT BUỘC PHẢI ĐỌC** các file sau theo thứ tự:

### 1. Tại Root Repository (`Nexus-Be/`):
- `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`: Kiến trúc C4 tổng quan, Bounded Contexts.
- `specs/01_UNIFIED_MICROSERVICE_ARCHITECTURE_BLUEPRINT.md`: Kiến trúc Clean Architecture chuẩn hóa, Feature Co-location, 1-to-1 Controller.
- `specs/01_SERVICE_CATALOG_PORT_MAP.md`: Quy hoạch dải port HTTP/REST (Gateway `8080`, Backend `8001`-`8008`) và DB (`5433`-`5440`).
- `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md`: Ma trận RESTful đồng bộ 100%, bãi bỏ Message Broker.
- `specs/03_SECURITY_RBAC_DATA_GOVERNANCE.md`: JWT Bearer, ma trận phân quyền 6 roles, chuẩn RFC 9110.
- `specs/04_SHARED_CONTRACTS_REGISTRY.md`: Nguồn sự thật REST DTOs dùng chung (loại bỏ Protobuf và RabbitMQ).
- `specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md`: Bộ chỉ dẫn toàn diện cho AI Agents.
- `AGENTS.md`: Quy tắc vận hành và quy chuẩn thông báo lỗi.

### 2. Tại `ApiGateway` (`src/Services/ApiGateway/`):
- `specs/00_AGENT_MISSION_GUARDRAILS.md`: Bounded context gateway, port `8080`, 0 DB.
- `specs/01_ARCHITECTURAL_BLUEPRINT.md`: Pipeline Pure Reverse Proxy, Rate Limiting, ForwardAsync.
- `specs/02_GATEWAY_CONTROLLERS_ROUTING.md`: Danh mục Controller, quy tắc viết Action siêu tinh gọn gọi ForwardAsync.
- `specs/03_GATEWAY_STATE_SECURITY.md`: Xác thực JWT và phân quyền RBAC.
- `DEV_GUIDE.md`: Hướng dẫn vận hành Gateway và thêm route downstream mới.
- `Nexus.Gateway/Dtos/`: Hợp đồng C# DTOs cho các backend microservices.
- `specs/05_DEV_VERIFICATION_CHECKLIST.md`: Checklist nghiệm thu Gateway.

### 3. Tại các Microservices Backend (`src/Services/{Service}/`):
Mỗi service (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`) sở hữu một bộ spec kit chuẩn hóa nằm tại `specs/` của service đó:
- `specs/00_AGENT_MISSION_GUARDRAILS.md`: Nhiệm vụ cốt lõi, port REST (`8001`-`8008`), DB port, rào chắn chống ảo giác.
- `specs/01_CLEAN_ARCHITECTURE_LAYERS.md`: Cấu trúc 4 tầng Clean Architecture, No-Repository pattern over EF Core.
- `specs/02_API_REST_CONTRACTS.md`: Hợp đồng RESTful API thuộc phạm vi của service (CẤM gRPC).
- `specs/03_EVENT_MESSAGING.md`: Trạng thái bãi bỏ RabbitMQ / MassTransit, giao tiếp REST đồng bộ.
- `specs/04_DATA_PERSISTENCE.md`: Schema bảng dữ liệu PostgreSQL và cấu hình EF Core (sạch 100% không bảng Outbox).
- `specs/05_DEV_VERIFICATION_CHECKLIST.md`: Lệnh build & test kiểm chứng service.
