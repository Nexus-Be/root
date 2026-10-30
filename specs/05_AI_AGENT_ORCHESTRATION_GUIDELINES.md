# 05 — CHỈ DẪN VẬN HÀNH DÀNH CHO AI CODING AGENTS (AI AGENT ORCHESTRATION GUIDELINES)

> **Trạng thái triển khai (2026-10-27):** ⚠️ Tài liệu này là **bản sao thứ ba** của cùng một bộ luật (đã có `AGENTS.md` và `CLAUDE.md` ở root, md5 giống hệt nhau). Nội dung 6 nguyên tắc dưới đây **trùng khớp** `AGENTS.md` — khi có sai lệch, **`AGENTS.md` là canonical**, tài liệu này giữ vai trò **ma trận đọc file** (Mục 3).
> **Nguồn sự thật:** `AGENTS.md` (luật) + code (hiện trạng `PLAN-20261027-1400-GLOBAL-RESTFUL-PIVOT-AND-GATEWAY-DECOUPLING.md`).
> **Cập nhật lần cuối:** 2026-10-27 — Chuyển dịch toàn diện sang 100% RESTful HTTP/JSON, loại bỏ hoàn toàn gRPC.

Tài liệu này là **Bộ Quy Chuẩn Tối Thượng (Supreme Guidelines)** dành cho các AI Coding Agents (Claude, Cursor, Copilot, DeepSeek Harness, Windsurf, Aider...) và lập trình viên khi hoạt động trong toàn bộ hệ sinh thái Microservices **Nexus**. Bộ quy chuẩn này được thiết kế để giải quyết triệt để vấn đề **mất ngữ cảnh (context loss) khi chuyển phiên/chuyển máy** và **loại bỏ hoàn toàn ảo giác (zero hallucination)**.

> **Đọc kèm:** `docs/plans/SCORECARD.md` (điểm 8 tiêu chí theo từng repo) và `docs/plans/audit/*_AUDIT.md` (bằng chứng chi tiết). Mục 3 dưới đây liệt kê **file phải đọc**, không phải danh sách tính năng đã có.

---

## 🛑 1. NGUYÊN TẮC BẮT BUỘC: LẬP KẾ HOẠCH TRƯỚC KHI HÀNH ĐỘNG (PLAN-FIRST RULE)

Mọi AI Agent khi tiếp nhận một yêu cầu (task) kỹ thuật **BẮT BUỘC PHẢI LẬP KẾ HOẠCH (PLAN)** chi tiết và trình bày rõ ràng trước khi thực hiện bất kỳ thao tác chỉnh sửa mã nguồn, refactor, thêm/xóa file, migration database hoặc thay đổi cấu hình nào.

### Cấu trúc một Kế Hoạch Chuẩn (Standard Agent Plan):
1. **Mục tiêu (Objective)**: Tóm tắt ngắn gọn và chính xác mục tiêu cần đạt được.
2. **Context & Tài liệu cần đọc (Context Gathering)**: Liệt kê các file specs/code cần đọc trước khi làm theo đúng ma trận đọc file tại Mục 3.
3. **Phân tích rủi ro & Phạm vi ảnh hưởng (Impact Analysis)**:
   - Sử dụng công cụ Code Intelligence (GitNexus `impact`) để đánh giá phạm vi ảnh hưởng (Blast Radius).
   - Báo cáo rõ mức độ rủi ro (Low / Medium / High / Critical) và các process/symbol liên quan.
4. **Danh sách các bước thực hiện (Step-by-Step Implementation Checklist)**:
   - Từng bước thực hiện cụ thể, rõ ràng, có thứ tự logic.
5. **Kế hoạch kiểm chứng (Verification Plan)**:
   - Các lệnh biên dịch (`dotnet build`) và bài kiểm thử (`dotnet test`) sẽ chạy để chứng minh tính đúng đắn trước khi bàn giao.

---

## 🧭 2. NGUYÊN TẮC ĐỊNH HƯỚNG TÀI NGUYÊN MỘT CHIỀU (UNIDIRECTIONAL SCOPING: INWARD-ONLY)

Hệ sinh thái Nexus được tổ chức theo mô hình **Multi-Repository với Git Submodules**. Do đó, mọi liên kết và tham chiếu tài liệu phải tuân thủ nghiêm ngặt **Quy tắc Một Chiều (Inward-Only Rule)**:

```
[ Root Repository: Nexus-Be ]
       │
       ▼ (ĐƯỢC PHÉP trỏ vào trong)
┌─────────────────────────────────────────────────────────────┐
│ Submodules: ApiGateway, User, Catalog, Commerce, Log...     │
│ (TUYỆT ĐỐI CHỈ TRỎ NỘI BỘ, KHÔNG ĐƯỢC PHÉP TRỎ NGƯỢC RA)     │
└─────────────────────────────────────────────────────────────┘
```

1. **Các file ở Root (`Nexus-Be/`)**:
   - **ĐƯỢC PHÉP trỏ vào trong** các thư mục con và các service repository (ví dụ: `specs/` ở root có thể trỏ tới `src/Services/ApiGateway/specs/README.md`).
2. **Các file bên trong từng Service Repository (`src/Services/{Service}/`)**:
   - **TUYỆT ĐỐI KHÔNG ĐƯỢC trỏ ngược ra ngoài Root** (`../../../docs/...`, `../../specs/...`).
   - **TUYỆT ĐỐI KHÔNG ĐƯỢC trỏ sang các Sibling Service khác** (`../../Catalog/...`, `../../ApiGateway/ADR.md`).
   - Mỗi Service là một Git Repository độc lập (`git@github.com:Nexus-Be/{Service}Service.git`), có thể được clone và phát triển riêng biệt ở bất kỳ môi trường nào. Tài liệu bên trong service **chỉ được trỏ tới các tài nguyên nội bộ của chính service đó** để đảm bảo tính tự cung tự cấp (Self-contained).

---

## 📚 3. MA TRẬN DANH MỤC FILE BẮT BUỘC PHẢI ĐỌC THEO TỪNG REPOSITORY

Khi bắt đầu làm việc trên bất kỳ repository nào, AI Agent **BẮT BUỘC PHẢI ĐỌC** các file tương ứng theo thứ tự ưu tiên dưới đây trước khi đưa ra phân tích hoặc viết mã:

### 3.0. Khi làm việc tại Root Repository (`Nexus-Be/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Bộ quy tắc làm việc tối thượng, quy chuẩn lỗi, quy tắc GitNexus. |
| 2 | `specs/00_MASTER_SYSTEM_ARCHITECTURE.md` | Bounded Contexts, kiến trúc C4, các quy tắc phân tách service. |
| 3 | `specs/01_SERVICE_CATALOG_PORT_MAP.md` | Bảng phân bổ cổng mạng HTTP REST (Gateway `8080`, Backend `8001`-`8008`) và DB (`5433`-`5440`). |
| 4 | `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md` | Ma trận RESTful đồng bộ 100%, bãi bỏ RabbitMQ MassTransit Saga. |
| 5 | `specs/03_SECURITY_RBAC_DATA_GOVERNANCE.md` | Cơ chế xác thực JWT Bearer, phân quyền 6 roles, chuẩn lỗi RFC 9110. |
| 6 | `specs/04_SHARED_CONTRACTS_REGISTRY.md` | Quy chuẩn REST DTOs và các Domain Events dùng chung. |
| 7 | `specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md` | Tài liệu quy chuẩn vận hành agent hiện tại. |

---

### 3.1. Khi làm việc tại `ApiGateway` (`src/Services/ApiGateway/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Rào chắn agent riêng của Gateway và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Bounded Context của Gateway: Pure Reverse proxy, port `8080`, 0 DB. |
| 3 | `specs/01_ARCHITECTURAL_BLUEPRINT.md` | Kiến trúc 3 khối, ForwardAsync Downstream Dispatching, Rate Limiting. |
| 4 | `specs/02_GATEWAY_CONTROLLERS_ROUTING.md` | Danh mục Controllers, quy tắc viết Action siêu mỏng gọi ForwardAsync. |
| 5 | `specs/03_GATEWAY_STATE_SECURITY.md` | Xác thực JWT và phân quyền RBAC tại Edge. |
| 6 | `DEV_GUIDE.md` | Hướng dẫn phát triển Controller Action và cấu hình routing downstream. |
| 7 | `Nexus.Gateway/Dtos/` | Nguồn sự thật hợp đồng C# DTOs cho các backend microservices. |
| 8 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Checklist nghiệm thu: `dotnet test ApiGateway.sln -c Release`. |

---

### 3.2. Khi làm việc tại `UserService` (`src/Services/User/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Quản lý định danh, JWT, Port `8001`, DB `5433` (`usermanagement_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | 4 tầng Clean Architecture, No-Repository pattern over EF Core. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: Register, Login, VerifyOtp, Profile... |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; gọi REST gửi OTP sang Notification Service. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Users`, `Roles`, `Permissions`, `SellerRegistrations`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.3. Khi làm việc tại `CatalogService` (`src/Services/Catalog/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Danh mục, sản phẩm, kho ảo, Port `8002`, DB `5434` (`category_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, DbContext trực tiếp trong Application. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: Categories, Products, Seller Inventory. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; giao tiếp trực tiếp qua REST. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Categories`, `Products`, `Inventories`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.4. Khi làm việc tại `CommerceService` (`src/Services/Commerce/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Giỏ hàng, đơn hàng, Port `8003`, DB `5435` (`commerce_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Cấu trúc Clean Architecture, xử lý checkout trực tiếp. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: Carts, Orders, Checkout. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ/Saga; giao tiếp trực tiếp qua REST. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Carts`, `CartItems`, `Orders`, `SubOrders`, `SubOrderItems`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.5. Khi làm việc tại `LogService` (`src/Services/Log/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Append-only logs, Port `8004`, DB `5436` (`log_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, xử lý ghi log hiệu năng cao. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: Ghi log, truy vấn nhật ký, quản trị Event Types. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; nhận log qua REST batch `POST /api/v1/log/batch`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Logs`, `LogEventTypes` (chỉ INSERT/SELECT, cấm UPDATE/DELETE). |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.6. Khi làm việc tại `AuctionService` (`src/Services/Auction/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Đấu giá, bước giá, chốt phiên, Port `8005`, DB `5437` (`auction_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, đồng quy cao trong đặt giá (bidding concurrency). |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: CreateAuction, PlaceBid, CloseAuction. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; trao đổi trực tiếp qua REST. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Auctions`, `Bids`, `AuctionStates`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.7. Khi làm việc tại `FulfillmentService` (`src/Services/Fulfillment/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Kho vật lý, vận đơn, cước phí ship, Port `8006`, DB `5438` (`fulfillment_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, mô hình quản lý kho bãi vật lý. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: CalculateShipping, CreateShipment, Track. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; trao đổi trực tiếp qua REST. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Warehouses`, `Shipments`, `InventoryItems`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.8. Khi làm việc tại `NotificationService` (`src/Services/Notification/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Thông báo in-app, email SMTP/OTP, Port `8007`, DB `5439` (`notification_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, mẫu gửi thông báo đa kênh. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: `NotificationsController`, `EmailController`. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; nhận yêu cầu gửi email qua REST `POST /api/v1/notifications/email`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Notifications`, `NotificationPreferences`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test: `dotnet test Notification.sln -c Release`. |

---

### 3.9. Khi làm việc tại `WalletService` (`src/Services/Wallet/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Số dư, ví tiền, không số dư âm, Port `8008`, DB `5440` (`wallet_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, tính toàn vẹn giao dịch tài chính ACID. |
| 4 | `specs/02_API_REST_CONTRACTS.md` | Hợp đồng RESTful API: GetBalance, Deposit, Withdraw, Transfer. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Trạng thái bãi bỏ RabbitMQ; thực hiện giao dịch thanh toán trực tiếp qua REST. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Wallets`, `WalletTransactions`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

## 🔒 4. NGUYÊN TẮC BẤT BIẾN CHỐNG ẢO GIÁC (ZERO-HALLUCINATION RULES)

1. **TUYỆT ĐỐI KHÔNG DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**:
   - Sử dụng trực tiếp `DbContext` và `DbSet<T>` trong tầng Application. Không tự ý sinh ra `IRepository<T>` hay `IUnitOfWork`.
2. **CÔ LẬP TUYỆT ĐỐI DỮ LIỆU (DATABASE-PER-SERVICE)**:
   - Mỗi microservice chỉ truy cập cơ sở dữ liệu riêng của mình. Không query chéo database của service khác.
3. **CẤU HÌNH CỔNG MẠNG VÀ DATABASE LÀ BẤT BIẾN**:
   - Gateway port `8080` (tránh xung đột với Portainer 8000), dải port microservices `8001`-`8008` và port database `5433`-`5440` là cố định. Cấm tự ý đổi port trong code hay config.
4. **CHUẨN HÓA GIAO TIẾP ĐỒNG BỘ 100% BẰNG RESTFUL HTTP/JSON (CẤM SỬ DỤNG gRPC)**:
   - Hệ thống chuyển đổi toàn diện giao tiếp đồng bộ giữa ApiGateway và các Backend Microservices sang **RESTful API (JSON over HTTP)** qua `GatewayBaseController.ForwardAsync` và `RestDownstreamDispatcher`.
   - Bãi bỏ và loại bỏ hoàn toàn các tệp Protobuf `shop.proto`. DTOs được quản lý kiểu strongly-typed tại từng service (`Dtos/`).
5. **NGUYÊN TẮC ĐỐI SOÁT TÀI LIỆU EXCEL (CHỈ TIN THÔNG TIN, KHÔNG TIN ĐỊNH DẠNG/CẤU TRÚC)**:
   - **Tuyệt đối KHÔNG tin tưởng định dạng hoặc cấu trúc form trong file Excel**: File Excel có thể chứa lỗi định dạng, casing tùy tiện hoặc không nhất quán do người soạn thảo (ví dụ: trong file viết `snake_case`, hoặc viết tên role dạng chữ thường `buyer` thay vì PascalCase `Buyer`...).
   - **Chỉ tin thông tin và ý đồ nghiệp vụ (Semantic Information)**: Trích xuất ý nghĩa trường dữ liệu, quan hệ logic, các bước trong luồng quy trình và điều kiện nghiệp vụ.
   - **Mọi cấu trúc, casing và giá trị enum/role BẮT BUỘC phải quy chuẩn lại theo Code & System Specs**: Tên role chuẩn PascalCase (`Buyer`, `Seller`, `Staff`, `Admin`, `SuperAdmin`, `Guest`), Casing API JSON `camelCase`, C# Model/DTO `PascalCase`, Database `snake_case`.
6. **NGUYÊN TẮC BẢO MẬT & QUẢN LÝ BIẾN MÔI TRƯỜNG (`.env`, `.env.*`)**:
   - **Bảo vệ Secrets & Rào chắn Sandbox**: AI Coding Agent không được tự ý xóa, làm lộ hoặc ghi đè sai lệch các biến môi trường nhạy cảm (JWT Secrets, DB Connection Strings, API Keys...). Lưu ý: Do cơ chế bảo vệ an toàn của sandbox (`secret.basename.env`), việc đọc/ghi trực tiếp file `.env` thực tế có thể bị hệ thống chặn tự động.
   - **Quyền chỉnh sửa khi có chỉ đạo từ Người dùng (Sếp)**: Khi Người dùng (Sếp) có chỉ đạo trực tiếp (ví dụ: *"chỉnh giúp tôi các file env"*, *"cập nhật cấu hình môi trường"*...), AI Agent **ĐƯỢC PHÉP và BẮT BUỘC PHẢI THỰC HIỆN** rà soát, chuẩn hóa các file mẫu `.env.example`, `.env.test`, cấu hình compose, đồng thời đối soát chi tiết và cung cấp block cấu hình rõ ràng để Người dùng cập nhật vào file `.env` thực tế một cách nhanh chóng, chính xác.
   - **Tuyệt đối cấm duplicate keys**: Không để xảy ra tình trạng khai báo trùng lặp biến trong các file môi trường.
7. **HẠ TẦNG PHỤ TRỢ DÙNG CHUNG TẬP TRUNG (SINGLE SHARED INFRASTRUCTURE)**:
   - **Hạ tầng phụ trợ (Redis In-Memory Store, Tempo Tracing, Grafana Dashboard) chỉ được khai báo duy nhất 1 lần tại cụm hạ tầng chung**: Toàn bộ hạ tầng chung nằm tại `src/Infrastructure/docker-compose.yml`, `docker-compose.infra.yml`, hoặc Phần 1 (Hạ tầng) của `docker-compose.yml` gốc.
   - **Tuyệt đối CẤM các microservices con (`src/Services/*`) khai báo container Redis riêng lẻ trong file docker-compose của service đó**: Từng microservice độc lập (như User, ApiGateway...) chỉ định nghĩa duy nhất 1 container ứng dụng của chính service đó (`nexus-{service}`), kết nối vào hạ tầng dùng chung qua bridge network `nexus-network` (`redis:6379`).
   - **Cơ chế phân tách dữ liệu Redis (Shared Redis Multi-Tenancy)**: Toàn hệ thống dùng chung 1 instance Redis (port `6379`, định mức 500MB). Các service sử dụng chung Redis bắt buộc phải phân tách vùng dữ liệu bằng Key Prefix riêng (ví dụ: API Gateway dùng prefix `nexus:gateway:*` cho rate-limiting; User Service dùng prefix `otp:*` cho mã xác thực OTP và `user:*` cho cache người dùng). Tuyệt đối không dựng thêm instance Redis thứ 2 gây lãng phí tài nguyên và xung đột cổng.
8. **FEATURE-DRIVEN CO-LOCATION & 1-TO-1 CONTROLLER PAIRING (CHUẨN HÓA ĐẶC TẢ `specs/01`)**:
   - **Tầng Application**: Toàn bộ thành phần của một tính năng bắt buộc đặt tại `{Service}.Application/Services/{Feature}/` gồm: `I{Feature}Service.cs`, `{Feature}Service.cs` (inject trực tiếp `I{Service}DbContext`, cấm Repository), `{Feature}Requests.cs`, `{Feature}Responses.cs`, `{Feature}Dtos.cs` (tùy chọn).
   - **Tầng Api**: Ghép cặp 1-to-1 với một thin controller tại `{Service}.Api/Controllers/{Feature}Controller.cs`, chỉ inject duy nhất `I{Feature}Service`.
9. **GIAO TIẾP LIÊN SERVICE 100% QUA REST CLIENT & BÃI BỎ MESSAGE BROKER**:
   - Toàn bộ giao tiếp liên service sử dụng **RESTful Web API** trực tiếp (JSON qua HTTP).
   - Bãi bỏ RabbitMQ Message Broker, MassTransit và Transactional Outbox/Inbox tables.
   - Các tác vụ gọi liên service (như User gửi OTP email sang Notification) được thực hiện qua typed `HttpClient` khai báo interface tại Application và hiện thực tại Infrastructure.
10. **QUY CHUẨN BẮT BIẾN KHI PHÁT TRIỂN & KHAI BÁO API MỚI (MANDATORY API RULES)**:
   - **Cấm trùng lặp Route alias (No Duplicate Route Aliases)**: Cấm tuyệt đối khai báo nhiều route attributes trùng lặp (ví dụ `[HttpGet("user")]` và `[HttpGet("users")]`) trên cùng một Action. Mỗi action chỉ có 1 route endpoint chính thức duy nhất.
   - **Quy ước Route Số ít cho User/AdminUser (Singular Route Convention)**: Toàn bộ endpoint liên quan đến User và AdminUser phải dùng danh từ số ít (`/api/v1/user`, `/api/v1/user/{userId}`, `/api/v1/admin/user`, `/api/v1/admin/user/{userId}`, `/api/v1/me`). Giữ danh từ số nhiều cho các collection chuẩn của domain khác (`/api/v1/auctions`, `/api/v1/categories`, `/api/v1/wallets`, `/api/v1/notifications`).
   - **Mô hình Thin Controller & Kế thừa đúng chuẩn**:
     - Tại API Gateway: Controller bắt buộc kế thừa `GatewayBaseController`, không chứa business logic, chỉ validate input cơ bản qua `UserValidation` và ủy quyền downstream qua `ForwardAsync` / `ForwardPagedAsync` / `ForwardNoContentAsync`.
     - Tại Microservice: Kế thừa `ControllerBase`, ghép cặp 1-to-1 với feature service tương ứng.
   - **Phong bì dữ liệu chuẩn (Envelope Standard)**: Mọi endpoint trả dữ liệu đều phải bọc qua `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`. Endpoint xóa hoặc không trả dữ liệu body bắt buộc trả HTTP `204 NoContent`. DTOs dùng PascalCase trong C# và camelCase trong JSON serialization.
   - **Chuẩn hóa XML Comment Endpoint**: Chỉ dùng single-line XML `<summary>` ngắn gọn trực tiếp trên từng Action method. Cấm viết class-level remarks, section dividers kẻ ngang hoặc comment dài dòng nhiều dòng.
   - **Đồng bộ Tài liệu & Specs**: Khi thêm mới hoặc thay đổi bất kỳ route/DTO nào, bắt buộc cập nhật đồng thời file spec tương ứng (`specs/02_GATEWAY_CONTROLLERS_ROUTING.md`) và tài liệu API Frontend (`docs/FRONTEND_API_ENDPOINT_MAPPING.md`).

---

## 💬 5. QUY CHUẨN THÔNG BÁO LỖI TOÀN HỆ THỐNG (MANDATORY ERROR RULES)

Mọi thông báo lỗi (Error Messages, Exceptions, ProblemDetails, Validation Errors) trong toàn hệ thống bắt buộc phải tuân theo 3 nguyên tắc:
1. **100% tiếng Anh**: Tuyệt đối không dùng tiếng Việt trong chuỗi thông báo lỗi trả về cho client.
2. **Quy cách viết hoa (Sentence case)**: Viết hoa duy nhất chữ cái đầu câu, các từ tiếp theo viết thường (trừ từ viết tắt như `ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`...).
   - ✅ Đúng: `"Email is already registered in the system."`
   - ✅ Đúng: `"Username, valid email, and password with at least 8 characters are required."`
   - ❌ Sai: `"Lỗi mã OTP không hợp lệ"` (Không dùng tiếng Việt)
   - ❌ Sai: `"invalid email address"` (Chữ cái đầu không viết hoa)
   - ❌ Sai: `"INVALID EMAIL ADDRESS"` (Cấm viết hoa toàn bộ)
3. **Mã lỗi (SCREAMING_SNAKE_CASE)**: Viết hoa toàn bộ và nối bằng dấu gạch dưới:
   - Ví dụ: `EMAIL_ALREADY_EXISTS`, `OTP_INVALID`, `USER_NOT_FOUND`, `VAL_INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`.

---

## 🎯 6. ĐIỀU KIỆN HOÀN THÀNH NHIỆM VỤ (DEFINITION OF DONE)

Một nhiệm vụ kỹ thuật của AI Agent chỉ được xem là hoàn thành khi:
- [ ] Lập kế hoạch (Plan) đầy đủ trước khi thực hiện.
- [ ] Tuân thủ quy tắc một chiều (Inward-Only) không tạo link trỏ ngược ra ngoài repo.
- [ ] `dotnet build <Solution>.sln -c Release` thành công 100% không có lỗi.
- [ ] `dotnet test <Solution>.sln -c Release` vượt qua 100% các bài kiểm thử.
- [ ] `git status` sạch, không có file rác (`bin/`, `obj/`, `.vs/`, `.idea/`).

---

## 🏗️ 7. KHUNG KIẾN TRÚC CHUẨN MỰC CHO MICROSERVICE (SERVICE BLUEPRINT & THIN CONTROLLER RULE)

Toàn bộ các Microservice trong hệ thống Nexus (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`, `CheckHeal`) và `ApiGateway` bắt buộc phải tuân thủ cấu trúc phân tầng và quy tắc thiết kế sau:

### 1. Phân Tầng Chuẩn & Quy Tắc Giao Tiếp Đồng Bộ (RESTful)
```
{Service}.sln
├── {Service}.Domain/           # 100% Thuần C# độc lập: Entities, Enums, Domain Exceptions.
├── {Service}.Application/      # Use cases nghiệp vụ:
│   ├── Services/{Feature}/     # Chia thư mục theo từng Feature/Module:
│   │   ├── I{Feature}Service.cs   # Hợp đồng interface
│   │   ├── {Feature}Service.cs    # Triển khai use case logic (inject DbContext)
│   │   ├── {Feature}Requests.cs   # Request DTOs (kèm DataAnnotations validation)
│   │   ├── {Feature}Responses.cs  # Response DTOs
│   │   └── {Feature}Dtos.cs       # Sub-DTOs nội bộ (nếu có)
│   ├── Interfaces/             # Interfaces trừu tượng hóa hạ tầng & REST clients
│   └── DependencyInjection.cs  # Đăng ký IoC cho tầng Application
├── {Service}.Infrastructure/   # Triển khai kỹ thuật:
│   ├── Persistence/            # AppDbContext, EntityTypeConfigurations, Migrations
│   ├── Services/               # Triển khai các dịch vụ hạ tầng & REST clients liên service
│   └── DependencyInjection.cs  # Đăng ký IoC cho tầng Infrastructure (DbContext, Redis, HttpClient)
└── {Service}.Api/              # Cổng giao tiếp Web API (ASP.NET Core Web API):
    ├── Controllers/            # Thin Controllers (Dispatcher 1-to-1 với Feature)
    ├── Middleware/             # GlobalExceptionHandlerMiddleware
    ├── Extensions/             # Swagger, Observability extensions
    └── Program.cs              # Nạp DI từ Application & Infrastructure, map middleware & controllers
```

### 2. Quy Tắc "Thin Controller" (Bắt Buộc)
- **Controller chỉ là bộ điều hướng (Thin Dispatcher)**:
  - Chỉ nhận HTTP Request, đọc headers/claims (ví dụ `x-user-id`).
  - Gọi Service Interface trong tầng Application (`I{Feature}Service`).
  - Nhận Response DTO từ Service và bọc trong `IActionResult` phù hợp (`Ok`, `Created`, `NoContent`, `NotFound`).
- **3 ĐIỀU TUYỆT ĐỐI CẤM TRONG CONTROLLER**:
  1. ❌ **CẤM viết logic nghiệp vụ hay chuyển đổi chuỗi trong Controller Action** (ví dụ: cắt chuỗi `DisplayName`, gán role mặc định, tính toán số liệu...). Mọi logic này bắt buộc phải đưa vào bên trong `Application/{Feature}Service`.
  2. ❌ **CẤM map thực thể Domain sang anonymous object** (`new { id = ..., email = ... }`) trong Controller. Service phải trả về Response DTO rõ ràng, strongly-typed.
  3. ❌ **CẤM định nghĩa class/record DTO bên trong file Controller**. Controller và Application dùng chung Request/Response DTO được định nghĩa trong `Application/Services/{Feature}/`.

### 3. Quy Tắc Giao Tiếp Liên Service Qua Typed REST Client (Bãi bỏ RabbitMQ)
- Bãi bỏ hoàn toàn RabbitMQ, MassTransit, Saga và Outbox/Inbox tables.
- Khi cần gọi sang service khác (ví dụ: User gọi Notification gửi email OTP, Commerce gọi Wallet thanh toán):
  - Định nghĩa Interface tại `{Service}.Application/Interfaces/` (ví dụ `IEmailNotificationClient`).
  - Triển khai `HttpClient` tại `{Service}.Infrastructure/Services/` và đăng ký typed client trong `Infrastructure/DependencyInjection.cs`.
  - Service gọi trực tiếp qua HTTP REST API có timeout, retry và fallback ghi log an toàn.

### 4. Quy Tắc Giảm Ràng Buộc & Quản Lý DI (Decoupled Dependency Injection)
- Mỗi tầng có trách nhiệm tự quản lý và đóng gói các dịch vụ của mình thông qua file `DependencyInjection.cs`:
  - `Application/DependencyInjection.cs`: Đăng ký tất cả Application Services (`AddScoped<I{Feature}Service, {Feature}Service>()`).
  - `Infrastructure/DependencyInjection.cs`: Đăng ký DbContext, Redis, Typed REST Clients, và các Adapter kỹ thuật.
- `Api/Program.cs`: Chỉ gọi `builder.Services.AddApplicationServices()` và `builder.Services.AddInfrastructureServices(builder.Configuration)`. Tuyệt đối không đăng ký lẫn lộn các service của Application hay Infrastructure trực tiếp trong `Program.cs`.

### 5. Quy Tắc Validate Dữ Liệu (Validation Placement)
- **Validate định dạng đầu vào (Input Validation)**: Đặt trực tiếp tại Request DTOs bằng Data Annotations (`[Required]`, `[EmailAddress]`, `[MinLength]`, `[RegularExpression]`...) hoặc Validator classes.
- **Validate nghiệp vụ (Business / Domain Validation)**: Đặt bên trong use case của `Application/{Feature}Service` hoặc trong Domain Entities/Exceptions. Khi vi phạm, ném Exception tương ứng để `GlobalExceptionHandlerMiddleware` bắt và trả về ProblemDetails / ApiResponse chuẩn.
- **Thông báo lỗi validation**: Bắt buộc tuân thủ 100% tiếng Anh, Sentence case, và mã lỗi `SCREAMING_SNAKE_CASE` theo Nguyên tắc 5.

