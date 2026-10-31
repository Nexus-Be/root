# 02 — Catalog Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ quản lý danh mục và sản phẩm hàng hóa.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Catalog Service (`Catalog`)
- **Vị trí thư mục:** `src/Services/Catalog/`
- **Solution:** `Catalog.sln`
- **Cổng lắng nghe HTTP REST:** `8002`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5434` (Container), Database: `category_db`
- **Giao tiếp liên dịch vụ:** Typed HTTP Client gọi sang `FulfillmentService` (`POST /api/v1/inventories/initialize`) để khởi tạo tồn kho vật lý cho SKU sản phẩm mới
- **Quy chuẩn phân trang:** Phân trang tại cơ sở dữ liệu và trả về cấu trúc chuẩn `PagedData<ProductDto>`

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Catalog/
├── Catalog.Domain/                    # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── Category.cs                # Danh mục hàng hóa (cấu trúc cây cha-con)
│   │   ├── Product.cs                 # Thông tin sản phẩm gốc của Seller
│   │   ├── ProductVariant.cs          # Biến thể sản phẩm (SKU, giá, mã vạch)
│   │   ├── ProductVariantAttribute.cs # Thuộc tính biến thể (Màu sắc, kích cỡ, dung lượng)
│   │   ├── ProductImage.cs            # Hình ảnh mô tả sản phẩm và biến thể
│   │   ├── ProductRatingStats.cs      # Thống kê đánh giá sao và số lượng nhận xét
│   │   ├── ProductReview.cs           # Đánh giá nhận xét của người mua hàng
│   │   ├── PurchaseRecord.cs          # Bản ghi lịch sử lượt mua
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 7 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── ProductStatus.cs           # Trạng thái sản phẩm (Draft, Active, Inactive)
│   │   ├── VariantStatus.cs           # Trạng thái biến thể (Active, Inactive, Discontinued)
│   │   ├── SaleType.cs                # Hình thức bán lẻ hoặc đấu giá
│   │   ├── ReviewStatus.cs            # Trạng thái duyệt nhận xét
│   │   ├── ProductInactiveReason.cs   # Lý do ngừng kinh doanh sản phẩm
│   │   ├── VariantInactiveReason.cs   # Lý do ngừng kích hoạt biến thể
│   │   └── AuditAction.cs             # Hành động kiểm toán (Insert, Update, Delete)
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Catalog.Application/               # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/
│   │   ├── Extensions/EnumExtensions.cs   # Tiện ích parse Enum an toàn
│   │   └── Models/PagedData.cs            # Cấu trúc phong bì phân trang chuẩn PagedData<T>
│   ├── Interfaces/
│   │   ├── ICatalogDbContext.cs       # Hợp đồng truy cập CSDL catalog_db
│   │   └── IFulfillmentClient.cs         # Hợp đồng gọi sang Fulfillment Service
│   ├── Services/
│   │   ├── Category/                  # Tính năng Danh Mục Hàng Hóa
│   │   │   ├── ICategoryService.cs, CategoryService.cs, CategoryRequests.cs, CategoryResponses.cs, CategoryDtos.cs
│   │   └── Product/                   # Tính năng Quản Lý Sản Phẩm
│   │       ├── IProductService.cs, ProductService.cs, ProductRequests.cs, ProductResponses.cs, ProductDtos.cs
│   └── DependencyInjection.cs         # Đăng ký CategoryService và ProductService
│
├── Catalog.Infrastructure/            # 3. TẦNG HẠ TẦNG (Persistence & Typed HTTP Client)
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Triển khai DbContext, lưu Enum integer
│   │   ├── Configurations/            # 8 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054329_InitialCreate)
│   │   └── Seeds/CatalogSeedData.cs   # Dữ liệu hạt giống cho danh mục và sản phẩm mẫu
│   ├── Services/
│   │   ├── Common/InternalServiceAuthHandler.cs # Chưa đăng ký: Internal API tạm khóa
│   │   └── Fulfillment/FulfillmentClient.cs # Gọi POST /api/v1/inventories/initialize
│   └── DependencyInjection.cs         # Đăng ký DbContext và Typed HttpClient
│
└── Catalog.Api/                       # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   ├── CategoriesController.cs# /api/v1/categories
    │   │   └── ProductsController.cs  # /api/v1/products (trả về PagedData<ProductDto>)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Cấu hình Swagger đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Chưa đăng ký: Internal API tạm khóa
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Quy chuẩn 100% Số Nhiều:** Tuyệt đối dùng `/api/v1/products`, `/api/v1/categories`, `/api/v1/variants`. Cấm dùng route số ít dạng `/product`.
2. **Không Repository Pattern:** Inject trực tiếp `ICatalogDbContext` vào `ProductService` và `CategoryService`.
3. **Phân trang tại Database:** `ProductService.ListAsync` bắt buộc chạy `await _dbContext.Products.CountAsync()` và trả về `PagedData<ProductDto>`.
4. **Bảo vệ danh tính Seller:** Khi tạo sản phẩm mới, `SellerId` phải được trích xuất từ `this.GetUserId()`, không tin tưởng tham số do client gửi lên.
5. **Khởi tạo kho đồng bộ:** Khi sản phẩm được tạo, service tự động gọi `FulfillmentClient` để khởi tạo bản ghi tồn kho vật lý không kèm khóa bảo mật nội bộ.
