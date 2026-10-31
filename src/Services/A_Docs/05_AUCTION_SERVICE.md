# 05 — Auction Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ đấu giá trực tuyến và đặt giá.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Auction Service (`Auction`)
- **Vị trí thư mục:** `src/Services/Auction/`
- **Solution:** `Auction.sln`
- **Cổng lắng nghe HTTP REST:** `8005`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5437` (Container), Database: `auction_db`
- **Quy chuẩn phân trang:** Phân trang tại cơ sở dữ liệu và trả về cấu trúc chuẩn `PagedData<AuctionDto>`
- **Bảo vệ danh tính đặt giá:** Bắt buộc trích xuất `BidderId` từ `HttpContext.GetUserId()`

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Auction/
├── Auction.Domain/                    # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── Auction.cs                 # Phiên đấu giá (Sản phẩm, Seller, Giá khởi điểm, Bước giá)
│   │   ├── AuctionConfig.cs           # Cấu hình bước giá tối thiểu, tỷ lệ đặt cọc, thời gian gia hạn
│   │   ├── AuctionState.cs            # Trạng thái hiện tại (Giá cao nhất, Người đang dẫn đầu)
│   │   ├── AuctionStatusHistory.cs    # Lịch sử chuyển dịch trạng thái phiên
│   │   ├── AuctionExtension.cs        # Ghi nhận các lần tự động gia hạn khi có bid phút chót
│   │   ├── AuctionResult.cs           # Kết quả chốt phiên (Người thắng cuộc, Giá chốt cuối cùng)
│   │   ├── AuctionSettlement.cs       # Quyết toán thanh toán và hoàn trả tiền cọc cho người thua
│   │   ├── Bid.cs                     # Lượt đặt giá của người tham gia
│   │   ├── BidHistory.cs              # Lịch sử toàn bộ các lượt bid trong phiên
│   │   ├── BidInvalidation.cs         # Ghi nhận lượt bid bị hủy (Ví không đủ tiền, gian lận)
│   │   ├── ProductOpenAuction.cs      # Khóa phiên đấu giá duy nhất đang mở cho một sản phẩm
│   │   ├── IdempotencyKey.cs          # Khóa chống đặt giá trùng lặp
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 4 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── AuctionStatus.cs           # Scheduled, Running, Ended, Completed, Cancelled
│   │   ├── BidInvalidationReason.cs   # InsufficientFunds, BelowMinimumStep, OutOfTime
│   │   ├── IdempotencyScope.cs        # BidPlacement, AuctionSettlement
│   │   └── AuditAction.cs             # Insert, Update, Delete
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Auction.Application/               # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/
│   │   ├── Extensions/EnumExtensions.cs   # Parse Enum an toàn
│   │   └── Models/PagedData.cs            # Cấu trúc phong bì phân trang chuẩn PagedData<T>
│   ├── Interfaces/
│   │   └── IAuctionDbContext.cs       # Hợp đồng truy cập CSDL auction_db
│   ├── Services/
│   │   ├── Auction/                   # Tính năng Quản Lý Phiên Đấu Giá
│   │   │   ├── IAuctionService.cs, AuctionService.cs, AuctionRequests.cs, AuctionResponses.cs, AuctionDtos.cs
│   │   └── Bid/                       # Tính năng Đặt Giá Và Tra Cứu Lịch Sử Bid
│   │       ├── IBidService.cs, BidService.cs, BidRequests.cs, BidResponses.cs, BidDtos.cs
│   └── DependencyInjection.cs         # Đăng ký AuctionService và BidService vào DI
│
├── Auction.Infrastructure/            # 3. TẦNG HẠ TẦNG (Persistence & Configurations)
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Triển khai EF Core DbContext
│   │   ├── Configurations/            # 11 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054757_InitialCreate)
│   │   └── Seeds/AuctionSeedData.cs   # Dữ liệu hạt giống cho các phiên đấu giá mẫu
│   └── DependencyInjection.cs         # Đăng ký AppDbContext
│
└── Auction.Api/                       # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   ├── AuctionsController.cs  # /api/v1/auctions (danh sách phiên active PagedData, chi tiết)
    │   │   └── BidsController.cs      # /api/v1/auctions/{auctionId:guid}/bids (lịch sử đặt giá)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Chưa đăng ký: Internal API tạm khóa
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Quy chuẩn 100% Số Nhiều:** Tuyệt đối dùng `/api/v1/auctions`, `/api/v1/bids`. Cấm dùng route số ít dạng `/auction`.
2. **Không Repository Pattern:** Inject trực tiếp `IAuctionDbContext` vào `AuctionService` và `BidService`.
3. **Phân trang tại Database:** `AuctionService.ListActiveAuctionsAsync` đếm tổng số bản ghi bằng `await _dbContext.Auctions.CountAsync()` và trả về `PagedData<AuctionDto>`.
4. **Bảo vệ danh tính đặt giá (Bidder Identity):** Mọi thao tác đặt giá bắt buộc trích xuất `BidderId` từ `HttpContext.GetUserId()`. Tuyệt đối cấm đặt giá thay người khác hoặc nhận `bidderId` từ body.
5. **Bãi bỏ RabbitMQ:** Toàn bộ thao tác kiểm tra trạng thái phiên và chốt phiên chuyển đổi sang cơ chế kiểm tra đồng bộ và scheduler.
