# 05 — CHỈ DẪN VẬN HÀNH DÀNH CHO AI CODING AGENTS (AI AGENT ORCHESTRATION GUIDELINES)

> **Trạng thái triển khai (2026-10-24):** ⚠️ Tài liệu này là **bản sao thứ ba** của cùng một bộ luật (đã có `AGENTS.md` và `CLAUDE.md` ở root, md5 giống hệt nhau). Nội dung 6 nguyên tắc dưới đây **trùng khớp** `AGENTS.md` — khi có sai lệch, **`AGENTS.md` là canonical**, tài liệu này chỉ giữ vai trò **ma trận đọc file** (Mục 3).
> **Nguồn sự thật:** `AGENTS.md` (luật) + code (hiện trạng).
> **Cập nhật lần cuối:** 2026-10-24.

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
| 3 | `specs/01_SERVICE_CATALOG_PORT_MAP.md` | Bảng phân bổ cổng mạng HTTP/gRPC (`8000`-`8008`) và DB (`5433`-`5440`). |
| 4 | `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md` | Ma trận gRPC đồng bộ vs RabbitMQ MassTransit Saga. |
| 5 | `specs/03_SECURITY_RBAC_DATA_GOVERNANCE.md` | Cơ chế xác thực JWT Bearer, phân quyền 6 roles, chuẩn lỗi RFC 9110. |
| 6 | `specs/04_SHARED_CONTRACTS_REGISTRY.md` | Quy chuẩn Protobuf `shop.proto` và các Domain Events dùng chung. |
| 7 | `specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md` | Tài liệu quy chuẩn vận hành agent hiện tại. |

---

### 3.1. Khi làm việc tại `ApiGateway` (`src/Services/ApiGateway/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Rào chắn agent riêng của Gateway và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Bounded Context của Gateway: Reverse proxy, port `8000`, 0 DB. |
| 3 | `specs/01_ARCHITECTURAL_BLUEPRINT.md` | Pipeline 6 bước, Circuit Breaker, Health Prober, Redis Rate Limiting. |
| 4 | `specs/02_GATEWAY_CONTROLLERS_ROUTING.md` | Danh mục 15 Controllers, quy tắc viết Controller Action siêu mỏng. |
| 5 | `specs/03_GATEWAY_STATE_SECURITY.md` | Phân giải Mode (`Mock` vs `Real`), AuthMode (`Enforce` vs `Bypass`). |
| 6 | `specs/04_MOCK_ENGINE_SEED_DATA.md` | Cấu trúc dữ liệu Seed Fixtures trong `Seeds/`. |
| 7 | `MOCK_GUIDE.md` & `DEV_GUIDE.md` | Hướng dẫn phát triển Controller Action và tạo Seed Fixture chuẩn. |
| 8 | `Nexus.Gateway/Contracts/shop.proto` | Nguồn sự thật duy nhất cho hợp đồng Protobuf v3. |
| 9 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Checklist nghiệm thu: `dotnet test ApiGateway.sln -c Release`. |

---

### 3.2. Khi làm việc tại `UserService` (`src/Services/User/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Quản lý định danh, JWT, Port `8001`, DB `5433` (`usermanagement_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | 4 tầng Clean Architecture, No-Repository pattern over EF Core. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `UsersApi`: Register, Login, VerifyOtp, GetProfile... |
| 5 | `specs/03_EVENT_MESSAGING.md` | Sự kiện RabbitMQ: `UserRegisteredEvent`, `UserVerifiedEvent`... |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Users`, `Roles`, `Permissions`, `SellerRegistrations`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.3. Khi làm việc tại `CatalogService` (`src/Services/Catalog/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Danh mục, sản phẩm, kho ảo, Port `8002`, DB `5434` (`category_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, DbContext trực tiếp trong Application. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `CatalogApi`: Categories, Products, Seller Inventory. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Sự kiện Saga: `StockReservedEvent`, `StockReleasedEvent`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Categories`, `Products`, `Inventories`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.4. Khi làm việc tại `CommerceService` (`src/Services/Commerce/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Giỏ hàng, đơn hàng, Saga Orchestrator, Port `8003`, DB `5435` (`commerce_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Cấu trúc Clean Architecture, MassTransit State Machine. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `CommerceApi`: Carts, Orders, Checkout. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Điều phối Checkout Saga: `OrderCreatedEvent`, `OrderCancelledEvent`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Carts`, `CartItems`, `Orders`, `OrderItems`, `OrderSagaState`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.5. Khi làm việc tại `LogService` (`src/Services/Log/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Append-only logs, Port `8004`, DB `5436` (`log_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, xử lý Batching log hiệu năng cao. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `LogApi`: Ghi log, truy vấn nhật ký, quản trị Event Types. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Lắng nghe toàn bộ integration events từ RabbitMQ để ghi audit trail. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `LogEntries` (chỉ INSERT/SELECT, cấm UPDATE/DELETE). |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.6. Khi làm việc tại `AuctionService` (`src/Services/Auction/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Đấu giá, bước giá, chốt phiên, Port `8005`, DB `5437` (`auction_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, đồng quy cao trong đặt giá (bidding concurrency). |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `AuctionApi`: CreateAuction, PlaceBid, CloseAuction. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Sự kiện: `AuctionCreatedEvent`, `BidPlacedEvent`, `AuctionWonEvent`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Auctions`, `Bids`, `AuctionWinners`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.7. Khi làm việc tại `FulfillmentService` (`src/Services/Fulfillment/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Kho vật lý, vận đơn, cước phí ship, Port `8006`, DB `5438` (`fulfillment_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, mô hình quản lý kho bãi vật lý. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `FulfillmentApi`: CalculateShipping, CreateShipment, Track. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Sự kiện: `ShipmentCreatedEvent`, `PackageDeliveredEvent`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Warehouses`, `Shipments`, `TrackingMilestones`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.8. Khi làm việc tại `NotificationService` (`src/Services/Notification/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Thông báo in-app, email SMTP, Port `8007`, DB `5439` (`notification_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, mẫu gửi thông báo đa kênh. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `NotificationApi`: SendNotification, ListUserNotifications. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Lắng nghe event từ toàn hệ thống để phát sinh thông báo tương ứng. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Notifications`, `NotificationPreferences`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

### 3.9. Khi làm việc tại `WalletService` (`src/Services/Wallet/`):
| Thứ tự | File Cần Đọc | Mục Đích & Ngữ Cảnh Nắm Bắt |
|:---:|:---|:---|
| 1 | `AGENTS.md` | Hướng dẫn GitNexus và quy chuẩn thông báo lỗi. |
| 2 | `specs/00_AGENT_MISSION_GUARDRAILS.md` | Số dư, ví tiền, không số dư âm, Port `8008`, DB `5440` (`wallet_db`). |
| 3 | `specs/01_CLEAN_ARCHITECTURE_LAYERS.md` | Clean Architecture, tính toàn vẹn giao dịch tài chính ACID. |
| 4 | `specs/02_API_GRPC_CONTRACTS.md` | Hợp đồng gRPC `WalletApi`: GetBalance, Deposit, Withdraw, Deduct. |
| 5 | `specs/03_EVENT_MESSAGING.md` | Sự kiện Saga: `PaymentCompletedEvent`, `PaymentFailedEvent`. |
| 6 | `specs/04_DATA_PERSISTENCE.md` | Schema bảng `Wallets`, `Transactions`, `BankAccounts`. |
| 7 | `specs/05_DEV_VERIFICATION_CHECKLIST.md` | Lệnh build & test kiểm chứng service. |

---

## 🔒 4. NGUYÊN TẮC BẤT BIẾN CHỐNG ẢO GIÁC (ZERO-HALLUCINATION RULES)

1. **TUYỆT ĐỐI KHÔNG DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**:
   - Sử dụng trực tiếp `DbContext` và `DbSet<T>` trong tầng Application. Không tự ý sinh ra `IRepository<T>` hay `IUnitOfWork`.
2. **CÔ LẬP TUYỆT ĐỐI DỮ LIỆU (DATABASE-PER-SERVICE)**:
   - Mỗi microservice chỉ truy cập cơ sở dữ liệu riêng của mình. Không query chéo database của service khác.
3. **CẤU HÌNH CỔNG MẠNG VÀ DATABASE LÀ BẤT BIẾN**:
   - Dải port `8000`-`8008` và port database `5433`-`5440` là cố định. Cấm tự ý đổi port trong code hay config.
4. **NGUỒN SỰ THẬT DUY NHẤT CHO PROTOBUF — HIỆN CHƯA TỒN TẠI**:
   - Đặc tả: mọi gRPC client và server phải đồng bộ tuyệt đối với `Contracts/shop.proto`; không tự ý đổi tag numbers hiện có.
   - **Hiện trạng (2026-10-24):** có **4 bản `shop.proto` với 3 nội dung khác nhau** (Gateway 66 dòng chỉ `UsersApi`; User 390 dòng/9 service/63 rpc; Log + Wallet 364 dòng/9 service/61 rpc). Bản được coi là canonical lại **thiếu nhất**. Xem `specs/04_SHARED_CONTRACTS_REGISTRY.md` §1 để biết bảng so sánh và `docs/plans/FIX_BACKLOG.md` mục `FIX-002` cho hướng sửa (proto canonical ở root + script đồng bộ + CI check hash).
   - Cho tới khi có nguồn sự thật: **không sửa `shop.proto` ở bất kỳ repo nào** nếu chưa chốt quyết định này.
5. **CẤM TỰ Ý SỬA ĐỔI BIẾN MÔI TRƯỜNG, SECRET VÀ KEY BÍ MẬT (MANDATORY HUMAN-IN-THE-LOOP FOR SECRETS)**:
   - **Tuyệt đối CẤM mọi AI Coding Agent tự ý sửa đổi, thay thế, xóa hoặc ghi đè các biến môi trường (`.env`, `.env.*`), Connection Strings, API Keys, JWT Secrets, chứng chỉ hoặc bất kỳ thông tin bí mật (credentials/secrets) nào trong toàn bộ hệ thống.**
   - **Bắt buộc phải xin ý kiến và nhận được sự đồng ý rõ ràng (explicit approval) từ người dùng trước khi thực hiện bất kỳ thay đổi nào liên quan đến biến môi trường hoặc tài khoản bí mật.**
   - Khi phát hiện cấu hình môi trường, connection string hoặc secret key có vấn đề hoặc cần cập nhật, Agent **CHỈ ĐƯỢC PHÉP báo cáo hiện trạng, đề xuất phương án và chờ người dùng xác nhận**, tuyệt đối không tự ý can thiệp.

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
