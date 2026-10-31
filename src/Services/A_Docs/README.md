# Tổng Quan Cấu Trúc Mã Nguồn Hệ Sinh Thái Microservices Nexus
## (Nexus Microservices Source Code Structure & Architecture Reference)

Tài liệu này cung cấp bản đồ cấu trúc thư mục thực tế, vai trò của từng thành phần và nguyên lý tổ chức mã nguồn của 10 dịch vụ (.NET 8 LTS) trong hệ sinh thái Nexus.

---

## 1. Bảng Tổng Hợp 10 Dịch Vụ Và Phân Bổ Cổng Mạng

| STT | Dịch Vụ | Thư Mục Mã Nguồn | File Tài Liệu Chi Tiết | Cổng HTTP | Cổng DB | Vai Trò Kiến Trúc |
|:---:|:---|:---|:---|:---:|:---:|:---|
| 0 | **Gateway** | `src/Services/Gateway/` | [`00_GATEWAY_SERVICE.md`](00_GATEWAY_SERVICE.md) | `8080` | *None* | Edge Reverse Proxy YARP 2.3.0, Active Anti-Spoofing, JWT Auth, Envelope |
| 1 | **UserService** | `src/Services/User/` | [`01_USER_SERVICE.md`](01_USER_SERVICE.md) | `8001` | `5433` | Định danh, xác thực JWT/OTP, hồ sơ người dùng, quản trị admin, người bán |
| 2 | **CatalogService** | `src/Services/Catalog/` | [`02_CATALOG_SERVICE.md`](02_CATALOG_SERVICE.md) | `8002` | `5434` | Quản lý danh mục hàng hóa, sản phẩm, biến thể và kho ảo sẵn sàng bán |
| 3 | **CommerceService** | `src/Services/Commerce/` | [`03_COMMERCE_SERVICE.md`](03_COMMERCE_SERVICE.md) | `8003` | `5435` | Quản lý giỏ hàng mua sắm, đơn hàng, hóa đơn và checkout đồng bộ |
| 4 | **LogService** | `src/Services/Log/` | [`04_LOG_SERVICE.md`](04_LOG_SERVICE.md) | `8004` | `5436` | Thu thập và truy vấn nhật ký kiểm toán tập trung (Central Audit Logs) |
| 5 | **AuctionService** | `src/Services/Auction/` | [`05_AUCTION_SERVICE.md`](05_AUCTION_SERVICE.md) | `8005` | `5437` | Phiên đấu giá trực tuyến, đặt giá (Bids), gia hạn và chốt phiên |
| 6 | **FulfillmentService** | `src/Services/Fulfillment/` | [`06_FULFILLMENT_SERVICE.md`](06_FULFILLMENT_SERVICE.md) | `8006` | `5438` | Kho bãi vật lý, khởi tạo tồn kho SKU, quản lý vận đơn và cước phí |
| 7 | **NotificationService**| `src/Services/Notification/` | [`07_NOTIFICATION_SERVICE.md`](07_NOTIFICATION_SERVICE.md) | `8007` | `5439` | Thông báo in-app, gửi email OTP/SMTP, đăng ký thiết bị nhận tin |
| 8 | **WalletService** | `src/Services/Wallet/` | [`08_WALLET_SERVICE.md`](08_WALLET_SERVICE.md) | `8008` | `5440` | Quản lý ví điện tử, số dư, nạp tiền VNPay, rút tiền, thanh toán nội bộ |
| 9 | **CheckHealService** | `src/Services/CheckHeal/` | [`09_CHECKHEAL_SERVICE.md`](09_CHECKHEAL_SERVICE.md) | `8009` | *None* | Giám sát trạng thái hoạt động, keep-alive định kỳ chống ngủ đông cơ sở dữ liệu |

---

## 2. Quy Chuẩn Tổ Chức Thư Mục 4 Tầng Clean Architecture Thống Nhất

Chín microservices backend (`User`, `Catalog`, `Commerce`, `Log`, `Auction`, `Fulfillment`, `Notification`, `Wallet`, `CheckHeal`) tuân thủ nghiêm ngặt mô hình 4 tầng Clean Architecture:

```text
{Service}/
├── {Service}.Domain/              # Tầng Miền Nghiệp Vụ (Pure Domain)
│   ├── Base/                      # BaseEntity, IAuditable, ISoftDelete
│   ├── Entities/                  # Thực thể CSDL (POCO thuần túy)
│   ├── Enums/                     # Strongly-typed C# Enums (lưu integer trong DB)
│   └── Exceptions/                # DomainException, BusinessRuleValidationException
│
├── {Service}.Application/         # Tầng Ca Sử Dụng (Application Use Cases)
│   ├── Common/                    # Extensions, DTOs dùng chung, PagedData<T>
│   ├── Interfaces/                # I{Service}DbContext, Typed HTTP Client Interfaces
│   ├── Services/{Feature}/        # Feature Co-location (Bắt buộc)
│   │   ├── I{Feature}Service.cs   # Hợp đồng ca sử dụng
│   │   ├── {Feature}Service.cs    # Triển khai nghiệp vụ (inject trực tiếp DbContext)
│   │   ├── {Feature}Requests.cs   # C# Records đầu vào
│   │   ├── {Feature}Responses.cs  # C# Records đầu ra
│   │   └── {Feature}Dtos.cs       # Sub-DTOs nội bộ (tùy chọn)
│   └── DependencyInjection.cs     # Đăng ký dịch vụ tầng Application vào DI Container
│
├── {Service}.Infrastructure/      # Tầng Hạ Tầng (Persistence & Clients)
│   ├── Persistence/
│   │   ├── AppDbContext.cs        # Triển khai EF Core DbContext
│   │   ├── Configurations/        # Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/            # EF Core Migrations & ModelSnapshot
│   │   └── Seeds/                 # Dữ liệu khởi tạo (Deterministic GUIDs)
│   ├── Services/
│   │   ├── Common/                # InternalServiceAuthHandler (tiêm X-Internal-Service-Key)
│   │   └── {Downstream}/          # Typed HttpClient gọi dịch vụ khác qua REST
│   └── DependencyInjection.cs     # Đăng ký DbContext và HttpClients
│
├── {Service}.Api/                 # Tầng Giao Tiếp HTTP (RESTful API Boundary)
│   ├── Controllers/
│   │   ├── Public/                # Tiếp nhận lưu lượng từ Gateway (/api/v1/{resources})
│   │   └── Internal/              # Giao tiếp liên service (/api/v1/internal/{resources})
│   ├── Common/Converters/         # PascalCaseJsonStringEnumConverter
│   ├── Extensions/                # ServiceDefaults, Observability, HttpContextExtensions
│   ├── Middleware/                # InternalServiceAuthMiddleware, GlobalExceptionMiddleware
│   └── Program.cs                 # Điểm khởi động ứng dụng
│
└── {Service}.Tests/               # Tầng Kiểm Thử Tự Động (xUnit, FluentAssertions)
```

---

## 3. Các Rào Chắn Bất Biến (Architectural Invariants)

Mọi kỹ sư và AI Coding Agent khi làm việc trong các thư mục này bắt buộc tuân thủ 5 nguyên tắc:
1. **Không dùng Repository Pattern bọc ngoài EF Core:** Tầng Application inject trực tiếp `I{Service}DbContext` và truy vấn `DbSet<T>`. Tuyệt đối cấm tạo `IRepository<T>`, `GenericRepository`, hoặc `UnitOfWork`.
2. **Không dùng MediatR / CQRS:** Toàn bộ logic nghiệp vụ đặt tập trung trong Feature Services (`Services/{Feature}/`). Không chia tách thành các file Command/Query/Handler phân tán.
3. **100% Giao tiếp qua RESTful HTTP/JSON:** Cấm hoàn toàn gRPC, Protobuf, RabbitMQ, MassTransit và bảng Outbox/Inbox. Giao tiếp liên dịch vụ chuyển sang gọi đồng bộ bằng Typed HttpClient.
4. **Phân tách Public API và Internal API:**
   - Public API đặt trong `Controllers/Public/` với route số nhiều `/api/v1/{resources}`.
   - Internal API đặt trong `Controllers/Internal/` với route `/api/v1/internal/{resources}`, bảo vệ bằng header `X-Internal-Service-Key`.
5. **Cơ sở dữ liệu độc lập (Database-per-service):** Mỗi dịch vụ sở hữu cơ sở dữ liệu PostgreSQL riêng biệt. Cấm truy vấn chéo giữa các cơ sở dữ liệu.
