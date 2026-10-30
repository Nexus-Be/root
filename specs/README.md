# NEXUS MICROSERVICES ECOSYSTEM — MASTER SPEC KIT (BỘ ĐẶC TẢ HỆ THỐNG TỔNG)

> **Trạng thái triển khai (2026-10-30):** ✅ Chuẩn hóa toàn diện — 100% RESTful HTTP/JSON (CẤM gRPC), bãi bỏ hoàn toàn RabbitMQ, MassTransit, Saga và Outbox/Inbox. Hệ thống cơ sở dữ liệu chuyển sang cơ chế Dual-Mode (Local PostgreSQL ports 5433-5440 và Remote/Neon DB).
> **Nguồn sự thật:** code trong `src/Services/*` và tài liệu kiến trúc tại `specs/`.
> **Cập nhật lần cuối:** 2026-10-30.

Tài liệu này là **Bộ Chỉ Dẫn & Đặc Tả Kỹ Thuật Trung Tâm (Master Specification Kit)** cho toàn bộ hệ sinh thái Microservices **Nexus**. Được thiết kế chuẩn hóa để **Lập trình viên trong team** và các **AI Coding Agents (Claude, Cursor, Copilot, DeepSeek Harness, Windsurf...)** khi chuyển đổi phiên làm việc, chuyển máy tính, hoặc tiếp quản mã nguồn đều có thể đọc, nắm bắt tức thì bối cảnh, hiểu đúng bản chất nghiệp vụ, tuân thủ các quy tắc bất di bất dịch và **tuyệt đối không bị ảo giác (zero-hallucination)**.

---

## 1. MỤC LỤC BỘ ĐẶC TẢ HỆ THỐNG TRUNG TÂM (SPECS/)

| File Đặc Tả | Phạm Vi Trách Nhiệm | Nội Dung Chính |
|:---|:---|:---|
| [00_MASTER_SYSTEM_ARCHITECTURE.md](00_MASTER_SYSTEM_ARCHITECTURE.md) | Kiến trúc tổng thể | Sơ đồ C4 Container, DDD Bounded Contexts, mô hình Edge Gateway, nguyên tắc độc lập giữa các service. |
| [01_UNIFIED_MICROSERVICE_ARCHITECTURE_BLUEPRINT.md](01_UNIFIED_MICROSERVICE_ARCHITECTURE_BLUEPRINT.md) | Bản thiết kế kiến trúc vi dịch vụ | Clean Architecture 4 tầng chuẩn hóa, Feature Co-location (`I{Feature}Service`, `Requests`, `Responses`), Thin Controller 1-1, No-Repository. |
| [01_SERVICE_CATALOG_PORT_MAP.md](01_SERVICE_CATALOG_PORT_MAP.md) | Quy hoạch mạng & hạ tầng | Bảng phân bổ cổng HTTP REST (Gateway `8080`, Services `8001`-`8009`), cổng Database PostgreSQL (`5433`-`5440`), Redis (`6379`), và thông tin bãi bỏ RabbitMQ. |
| [02_INTER_SERVICE_COMMUNICATION_MATRIX.md](02_INTER_SERVICE_COMMUNICATION_MATRIX.md) | Giao tiếp liên service | Ma trận RESTful đồng bộ 100%, bãi bỏ RabbitMQ Message Broker, MassTransit và Checkout Saga. |
| [03_SECURITY_RBAC_DATA_GOVERNANCE.md](03_SECURITY_RBAC_DATA_GOVERNANCE.md) | Bảo mật & Chuẩn dữ liệu | JWT Bearer Lifecycle, chuyển tiếp headers qua HTTP sang downstream, ma trận phân quyền **6 roles**, Gateway Pure Reverse Proxy, chuẩn lỗi RFC 9110 / RFC 6585. |
| [04_SHARED_CONTRACTS_REGISTRY.md](04_SHARED_CONTRACTS_REGISTRY.md) | Hợp đồng giao tiếp chung | Chuẩn hóa RESTful C# DTOs, lịch sử bãi bỏ gRPC Protobuf và RabbitMQ events. |
| [05_AI_AGENT_ORCHESTRATION_GUIDELINES.md](05_AI_AGENT_ORCHESTRATION_GUIDELINES.md) | Chỉ dẫn cho AI Agents | Quy tắc chống ảo giác (Anti-Hallucination), chuẩn hóa RESTful downstream, quy tắc Clean Architecture, No-Repository pattern. |

---

## 2. DANH MỤC SPEC KITS RIÊNG TỪNG SERVICE TRONG `src/Services/`

Mỗi service repository bên trong `src/Services/` là một Git Repository độc lập và sở hữu một **Spec Kit riêng** nằm tại thư mục `specs/` của repo đó:

| STT | Service Repository | Thư Mục | Spec Kit Riêng | Nhiệm Vụ Chính & Bounded Context | Cổng REST | Cổng DB |
|:---:|:---|:---|:---:|:---|:---:|:---:|
| 0 | **ApiGateway** | `src/Services/ApiGateway/` | [ApiGateway Spec Kit](../src/Services/ApiGateway/specs/README.md) | Edge Reverse Proxy, REST downstream, JWT/RBAC, Rate Limit. | `8080` | N/A (Redis 6379) |
| 1 | **UserService** | `src/Services/User/` | [UserService Spec Kit](../src/Services/User/specs/README.md) | Đăng ký, OTP, Login/JWT, User Profile, Quản trị người dùng, Seller onboarding. | `8001` | `5433` |
| 2 | **CatalogService** | `src/Services/Catalog/` | [CatalogService Spec Kit](../src/Services/Catalog/specs/README.md) | Quản lý danh mục, sản phẩm, kho ảo sẵn sàng bán. | `8002` | `5434` |
| 3 | **CommerceService** | `src/Services/Commerce/` | [CommerceService Spec Kit](../src/Services/Commerce/specs/README.md) | Quản lý giỏ hàng, đặt hàng, xử lý checkout đồng bộ. | `8003` | `5435` |
| 4 | **LogService** | `src/Services/Log/` | [LogService Spec Kit](../src/Services/Log/specs/README.md) | Nhật ký hệ thống tập trung (Append-only Logs), cấu hình Event Types. | `8004` | `5436` |
| 5 | **AuctionService** | `src/Services/Auction/` | [AuctionService Spec Kit](../src/Services/Auction/specs/README.md) | Phiên đấu giá trực tuyến, đặt giá (Bids), chốt phiên. | `8005` | `5437` |
| 6 | **FulfillmentService** | `src/Services/Fulfillment/` | [FulfillmentService Spec Kit](../src/Services/Fulfillment/specs/README.md) | Kho bãi vật lý, quản lý vận đơn, tính cước vận chuyển. | `8006` | `5438` |
| 7 | **NotificationService** | `src/Services/Notification/` | [NotificationService Spec Kit](../src/Services/Notification/specs/README.md) | Đa kênh thông báo (in-app, email SMTP/OTP). | `8007` | `5439` |
| 8 | **WalletService** | `src/Services/Wallet/` | [WalletService Spec Kit](../src/Services/Wallet/specs/README.md) | Quản lý số dư ví, nạp tiền, rút tiền, chuyển tiền nội bộ. | `8008` | `5440` |
| 9 | **CheckHealService** | `src/Services/CheckHeal/` | [CheckHeal Spec Kit](../src/Services/CheckHeal/specs/README.md) | Giám sát sức khỏe hệ thống, keep-alive chống ngủ đông cho 8 DB và microservices. | `8009` | N/A |

---

## 3. CÁCH SỬ DỤNG CHO AI AGENT & DEVELOPER

1. **Khi AI Agent bắt đầu phiên làm việc trên bất kỳ repo nào**:
   - Đọc trước file `specs/00_AGENT_MISSION_GUARDRAILS.md` của repo đó.
   - Tuân thủ nghiêm ngặt các ranh giới Bounded Context và Anti-Hallucination Rules.
2. **Khi AI Agent cần hiểu cách service giao tiếp với bên ngoài**:
   - Tham khảo `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md` ở root và `specs/02_API_REST_CONTRACTS.md` ở service repo.
   - Giao tiếp đồng bộ 100% qua RESTful HTTP/JSON (CẤM gRPC).
3. **Khi thực hiện code tính năng mới**:
   - Luôn tuân thủ cấu trúc 4 tầng Clean Architecture (`.Api`, `.Application`, `.Domain`, `.Infrastructure`) theo `specs/01_UNIFIED_MICROSERVICE_ARCHITECTURE_BLUEPRINT.md`.
   - Sử dụng trực tiếp `DbContext` của EF Core 8 (Tuyệt đối **KHÔNG dùng Repository Pattern bọc ngoài EF Core**).
   - Trước khi hoàn thành, đối chiếu với `05_DEV_VERIFICATION_CHECKLIST.md` để đảm bảo build và test pass 100%.
