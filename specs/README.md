# NEXUS MICROSERVICES ECOSYSTEM — MASTER SPEC KIT (BỘ ĐẶC TẢ HỆ THỐNG TỔNG)

> **Trạng thái triển khai (2026-10-24):** ⚠️ Một phần — bộ spec này mô tả **kiến trúc mục tiêu**; nhiều mục chưa có trong code (xem bảng trạng thái ở từng file). Điểm audit thực tế: `docs/plans/SCORECARD.md`.
> **Nguồn sự thật:** code trong `src/Services/*` + báo cáo `docs/plans/audit/`.
> **Cập nhật lần cuối:** 2026-10-24.

Tài liệu này là **Bộ Chỉ Dẫn & Đặc Tả Kỹ Thuật Trung Tâm (Master Specification Kit)** cho toàn bộ hệ sinh thái Microservices **Nexus**. Được thiết kế chuẩn hóa để **Lập trình viên trong team** và các **AI Coding Agents (Claude, Cursor, Copilot, DeepSeek Harness, Windsurf...)** khi chuyển đổi phiên làm việc, chuyển máy tính, hoặc tiếp quản mã nguồn đều có thể đọc, nắm bắt tức thì bối cảnh, hiểu đúng bản chất nghiệp vụ, tuân thủ các quy tắc bất di bất dịch và **tuyệt đối không bị ảo giác (zero-hallucination)**.

---

## 1. MỤC LỤC BỘ ĐẶC TẢ HỆ THỐNG TRUNG TÂM (SPECS/)

| File Đặc Tả | Phạm Vi Trách Nhiệm | Nội Dung Chính |
|:---|:---|:---|
| [00_MASTER_SYSTEM_ARCHITECTURE.md](00_MASTER_SYSTEM_ARCHITECTURE.md) | Kiến trúc tổng thể | Sơ đồ C4 Container, DDD Bounded Contexts, mô hình Edge Gateway, nguyên tắc độc lập giữa các service. |
| [01_SERVICE_CATALOG_PORT_MAP.md](01_SERVICE_CATALOG_PORT_MAP.md) | Quy hoạch mạng & hạ tầng | Bảng phân bổ cổng HTTP/gRPC (`8000`-`8008`), cổng Database PostgreSQL (`5433`-`5440`), RabbitMQ, Redis. |
| [02_INTER_SERVICE_COMMUNICATION_MATRIX.md](02_INTER_SERVICE_COMMUNICATION_MATRIX.md) | Giao tiếp liên service | Ma trận gRPC đồng bộ vs RabbitMQ (MassTransit **8.3.0** — không phải 8.4.1) bất đồng bộ, Điều phối Saga phân tán (Checkout Saga — ❌ chưa triển khai). |
| [03_SECURITY_RBAC_DATA_GOVERNANCE.md](03_SECURITY_RBAC_DATA_GOVERNANCE.md) | Bảo mật & Chuẩn dữ liệu | JWT Bearer Lifecycle (❌ chưa có nơi phát token), ma trận phân quyền **6 roles**, Gateway Mode (`Enforce` vs `Bypass` + `Mock/Real` theo từng service), chuẩn lỗi RFC 9110 / RFC 6585. |
| [04_SHARED_CONTRACTS_REGISTRY.md](04_SHARED_CONTRACTS_REGISTRY.md) | Hợp đồng giao tiếp chung | ⚠️ `Contracts/shop.proto` **chưa** là Single Source of Truth (4 bản/3 hash), sự kiện dùng chung (Domain Events), quy trình nâng cấp hợp đồng an toàn. |
| [05_AI_AGENT_ORCHESTRATION_GUIDELINES.md](05_AI_AGENT_ORCHESTRATION_GUIDELINES.md) | Chỉ dẫn cho AI Agents | Quy tắc chống ảo giác (Anti-Hallucination), hướng dẫn giữ context khi chuyển máy/phiên, quy tắc Clean Architecture, No-Repository pattern. |

---

## 2. DANH MỤC SPEC KITS RIÊNG TỪNG SERVICE TRONG `src/Services/`

Mỗi service repository bên trong `src/Services/` là một Git Repository độc lập và sở hữu một **Spec Kit riêng** nằm tại thư mục `specs/` của repo đó:

| STT | Service Repository | Thư Mục | Spec Kit Riêng | Nhiệm Vụ Chính & Bounded Context | Port HTTP/gRPC |
|:---:|:---|:---|:---:|:---|:---:|
| 0 | **ApiGateway** | `src/Services/ApiGateway/` | [ApiGateway Spec Kit](../src/Services/ApiGateway/specs/README.md) | Edge Reverse Proxy, REST to gRPC, JWT/RBAC, Rate Limit, Mock Engine, Runtime Mode Switch — ✅ service hoàn chỉnh nhất (98 test case). | `8000` |
| 1 | **UserService** | `src/Services/User/` | [UserService Spec Kit](../src/Services/User/specs/README.md) | Đăng ký, OTP, User Profile — ⚠️ **không có Login/JWT** (chưa implement), chưa có xét duyệt Seller. | `8001` |
| 2 | **CatalogService** | `src/Services/Catalog/` | [CatalogService Spec Kit](../src/Services/Catalog/specs/README.md) | Danh mục/sản phẩm/kho — ⚠️ hiện chỉ là **REST mock in-memory**, 0/13 rpc gRPC, 0 test. | `8002` |
| 3 | **CommerceService** | `src/Services/Commerce/` | [CommerceService Spec Kit](../src/Services/Commerce/specs/README.md) | Giỏ hàng/đơn hàng — ⚠️ chỉ có 3 query đọc, 0 lệnh ghi, 0 gRPC, Saga ❌ chưa triển khai. | `8003` |
| 4 | **LogService** | `src/Services/Log/` | [LogService Spec Kit](../src/Services/Log/specs/README.md) | Nhật ký tập trung (Logs), Event Types — ✅ gRPC 4/4 + OTel; ⚠️ thiếu endpoint `POST /api/v1/log/batch` nên Gateway không gửi log được. | `8004` |
| 5 | **AuctionService** | `src/Services/Auction/` | [AuctionService Spec Kit](../src/Services/Auction/specs/README.md) | Phiên đấu giá/Bids — ❌ 0 điểm vào ngoài `/health`, service không gọi được. | `8005` |
| 6 | **FulfillmentService** | `src/Services/Fulfillment/` | [FulfillmentService Spec Kit](../src/Services/Fulfillment/specs/README.md) | Tồn kho/vận đơn — ❌ chỉ đọc, 0 lệnh ghi DB, 0 gRPC, 0 test. | `8006` |
| 7 | **NotificationService** | `src/Services/Notification/` | [NotificationService Spec Kit](../src/Services/Notification/specs/README.md) | Thông báo — ⚠️ chỉ có consumer OTP (không ghi DB), 0 gRPC, gửi mail lỗi vẫn báo thành công. | `8007` |
| 8 | **WalletService** | `src/Services/Wallet/` | [WalletService Spec Kit](../src/Services/Wallet/specs/README.md) | Ví điện tử — ✅ gRPC 5/5 + OTel; ⚠️ 24 thông báo lỗi tiếng Việt trong ngữ cảnh lỗi, 0 test, tin header `x-user-id` không kiểm chứng, 6/8 bảng không có đường ghi. | `8008` |

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
