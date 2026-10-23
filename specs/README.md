# NEXUS MICROSERVICES ECOSYSTEM — MASTER SPEC KIT (BỘ ĐẶC TẢ HỆ THỐNG TỔNG)

Tài liệu này là **Bộ Chỉ Dẫn & Đặc Tả Kỹ Thuật Trung Tâm (Master Specification Kit)** cho toàn bộ hệ sinh thái Microservices **Nexus**. Được thiết kế chuẩn hóa để **Lập trình viên trong team** và các **AI Coding Agents (Claude, Cursor, Copilot, DeepSeek Harness, Windsurf...)** khi chuyển đổi phiên làm việc, chuyển máy tính, hoặc tiếp quản mã nguồn đều có thể đọc, nắm bắt tức thì bối cảnh, hiểu đúng bản chất nghiệp vụ, tuân thủ các quy tắc bất di bất dịch và **tuyệt đối không bị ảo giác (zero-hallucination)**.

---

## 1. MỤC LỤC BỘ ĐẶC TẢ HỆ THỐNG TRUNG TÂM (SPECS/)

| File Đặc Tả | Phạm Vi Trách Nhiệm | Nội Dung Chính |
|:---|:---|:---|
| [00_MASTER_SYSTEM_ARCHITECTURE.md](00_MASTER_SYSTEM_ARCHITECTURE.md) | Kiến trúc tổng thể | Sơ đồ C4 Container, DDD Bounded Contexts, mô hình Edge Gateway, nguyên tắc độc lập giữa các service. |
| [01_SERVICE_CATALOG_PORT_MAP.md](01_SERVICE_CATALOG_PORT_MAP.md) | Quy hoạch mạng & hạ tầng | Bảng phân bổ cổng HTTP/gRPC (`8000`-`8008`), cổng Database PostgreSQL (`5433`-`5440`), RabbitMQ, Redis. |
| [02_INTER_SERVICE_COMMUNICATION_MATRIX.md](02_INTER_SERVICE_COMMUNICATION_MATRIX.md) | Giao tiếp liên service | Ma trận gRPC đồng bộ vs RabbitMQ (MassTransit 8.4.1) bất đồng bộ, Điều phối Saga phân tán (Checkout Saga). |
| [03_SECURITY_RBAC_DATA_GOVERNANCE.md](03_SECURITY_RBAC_DATA_GOVERNANCE.md) | Bảo mật & Chuẩn dữ liệu | JWT Bearer Lifecycle, ma trận phân quyền 5 roles, Gateway Mode (`Standard` vs `Bypass`), chuẩn lỗi RFC 9110 / RFC 6585. |
| [04_SHARED_CONTRACTS_REGISTRY.md](04_SHARED_CONTRACTS_REGISTRY.md) | Hợp đồng giao tiếp chung | Single Source of Truth `Contracts/shop.proto`, sự kiện dùng chung (Domain Events), quy trình nâng cấp hợp đồng an toàn. |
| [05_AI_AGENT_ORCHESTRATION_GUIDELINES.md](05_AI_AGENT_ORCHESTRATION_GUIDELINES.md) | Chỉ dẫn cho AI Agents | Quy tắc chống ảo giác (Anti-Hallucination), hướng dẫn giữ context khi chuyển máy/phiên, quy tắc Clean Architecture, No-Repository pattern. |

---

## 2. DANH MỤC SPEC KITS RIÊNG TỪNG SERVICE TRONG `src/Services/`

Mỗi service repository bên trong `src/Services/` là một Git Repository độc lập và sở hữu một **Spec Kit riêng** nằm tại thư mục `specs/` của repo đó:

| STT | Service Repository | Thư Mục | Spec Kit Riêng | Nhiệm Vụ Chính & Bounded Context | Port HTTP/gRPC |
|:---:|:---|:---|:---:|:---|:---:|
| 0 | **ApiGateway** | `src/Services/ApiGateway/` | [ApiGateway Spec Kit](../src/Services/ApiGateway/specs/README.md) | Edge Reverse Proxy, REST to gRPC, JWT/RBAC, Rate Limit, Mock Engine, Runtime Mode Switch. | `8000` |
| 1 | **UserService** | `src/Services/User/` | [UserService Spec Kit](../src/Services/User/specs/README.md) | Đăng ký, đăng nhập, phát hành JWT, User Profile, phân quyền RBAC, xét duyệt Seller. | `8001` |
| 2 | **CatalogService** | `src/Services/Catalog/` | [CatalogService Spec Kit](../src/Services/Catalog/specs/README.md) | Danh mục (Categories), sản phẩm (Products), quản lý kho ảo của người bán (Seller Inventory). | `8002` |
| 3 | **CommerceService** | `src/Services/Commerce/` | [CommerceService Spec Kit](../src/Services/Commerce/specs/README.md) | Giỏ hàng (Cart), đơn hàng (Orders), Điều phối Checkout Saga State Machine. | `8003` |
| 4 | **LogService** | `src/Services/Log/` | [LogService Spec Kit](../src/Services/Log/specs/README.md) | Quản lý nhật ký hệ thống tập trung (Logs), danh mục sự kiện log (Event Types), nghe RabbitMQ. | `8004` |
| 5 | **AuctionService** | `src/Services/Auction/` | [AuctionService Spec Kit](../src/Services/Auction/specs/README.md) | Phiên đấu giá (Auctions), lượt đặt giá (Bids), quy tắc trả giá và chốt phiên. | `8005` |
| 6 | **FulfillmentService** | `src/Services/Fulfillment/` | [FulfillmentService Spec Kit](../src/Services/Fulfillment/specs/README.md) | Tồn kho kho bãi vật lý, tính cước vận chuyển (Quotes), tra cứu vận đơn (Tracking). | `8006` |
| 7 | **NotificationService** | `src/Services/Notification/` | [NotificationService Spec Kit](../src/Services/Notification/specs/README.md) | Thông báo cá nhân, đánh dấu đã đọc, cài đặt nhận thông báo (Preferences). | `8007` |
| 8 | **WalletService** | `src/Services/Wallet/` | [WalletService Spec Kit](../src/Services/Wallet/specs/README.md) | Ví điện tử riêng biệt, số dư, nạp/rút tiền, chuyển tiền nội bộ, thanh toán đơn hàng. | `8008` |

*(Lưu ý: Thư mục `Project.CleanArchitecture/` ở root là template khung kiến trúc mẫu, không thuộc phạm vi vận hành của các microservices sản phẩm).*

---

## 3. CÁCH SỬ DỤNG CHO AI AGENT & DEVELOPER

1. **Khi AI Agent bắt đầu phiên làm việc trên bất kỳ repo nào**:
   - Đọc trước file `specs/00_AGENT_MISSION_GUARDRAILS.md` của repo đó.
   - Tuân thủ nghiêm ngặt các ranh giới Bounded Context và Anti-Hallucination Rules.
2. **Khi AI Agent cần hiểu cách service giao tiếp với bên ngoài**:
   - Tham khảo `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md` ở root và `02_API_GRPC_CONTRACTS.md` ở service repo.
   - Tuyệt đối không tự ý sửa Protobuf hợp đồng trong service mà không đối chiếu với `Contracts/shop.proto` gốc tại Gateway.
3. **Khi thực hiện code tính năng mới**:
   - Luôn tuân thủ cấu trúc 4 tầng Clean Architecture (`.Api`, `.Application`, `.Domain`, `.Infrastructure`).
   - Sử dụng trực tiếp `DbContext` của EF Core 8 (Tuyệt đối **KHÔNG dùng Repository Pattern bọc ngoài EF Core**).
   - Trước khi hoàn thành, đối chiếu với `05_DEV_VERIFICATION_CHECKLIST.md` để đảm bảo build và test pass 100%.
