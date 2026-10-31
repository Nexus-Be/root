# 06 — Fulfillment Service Reference

Tài liệu này đặc tả cấu trúc thư mục, kiến trúc 4 tầng và chức năng nghiệp vụ của dịch vụ quản lý kho bãi vật lý, tồn kho và vận đơn giao vận.

---

## 1. Thông Tin Dịch Vụ (Service Metadata)

- **Tên dịch vụ:** Nexus Fulfillment & Logistics Service (`Fulfillment`)
- **Vị trí thư mục:** `src/Services/Fulfillment/`
- **Solution:** `Fulfillment.sln`
- **Cổng lắng nghe HTTP REST:** `8006`
- **Cơ sở dữ liệu PostgreSQL:** Cổng `5438` (Container), Database: `fulfillment_db`
- **Giao tiếp liên dịch vụ nội bộ (Inbound):** Tiếp nhận yêu cầu khởi tạo tồn kho SKU từ `CatalogService` qua endpoint `POST /api/v1/internal/inventories/initialize` bảo vệ bằng `X-Internal-Service-Key`
- **Chuẩn hóa phản hồi lỗi:** Đã bổ sung đầy đủ mã lỗi `WAREHOUSE_NOT_FOUND` và `SHIPMENT_NOT_FOUND`

---

## 2. Bản Đồ Cấu Trúc Thư Mục Thực Tế (Folder Tree)

```text
src/Services/Fulfillment/
├── Fulfillment.Domain/                # 1. TẦNG MIỀN NGHIỆP VỤ (Pure Domain Layer)
│   ├── Base/
│   │   ├── BaseEntity.cs              # Thực thể cơ sở Id (Guid), CreatedAt, UpdatedAt
│   │   ├── IAuditable.cs              # Theo dõi CreatedBy, UpdatedBy
│   │   └── ISoftDelete.cs             # Xóa mềm IsDeleted, DeletedAt
│   ├── Entities/
│   │   ├── Warehouse.cs               # Kho bãi vật lý (Mã kho, Địa chỉ, Sức chứa)
│   │   ├── Carrier.cs                 # Đơn vị vận chuyển (GiaoHangNhanh, ViettelPost, J&T)
│   │   ├── InventoryItem.cs           # Tồn kho vật lý của SKU trong kho cụ thể
│   │   ├── InventoryLedger.cs         # Sổ cái biến động kho (Nhập, Xuất, Kiểm kê)
│   │   ├── InventoryReservation.cs    # Đặt giữ tồn kho cho đơn hàng đang chờ thanh toán
│   │   ├── InventoryReservationItem.cs# Chi tiết SKU và số lượng đặt giữ
│   │   ├── Shipment.cs                # Vận đơn giao hàng (Mã vận đơn tracking, Trạng thái)
│   │   ├── ShipmentItem.cs            # Mặt hàng kèm theo kiện hàng
│   │   ├── ShipmentEvent.cs           # Lịch sử các mốc sự kiện vận chuyển
│   │   └── AuditLog.cs                # Nhật ký kiểm toán thay đổi dữ liệu
│   ├── Enums/                         # 9 Strongly-typed C# Enums (lưu integer trong DB)
│   │   ├── WarehouseType.cs           # CentralHub, FulfillmentCenter, LocalSorting
│   │   ├── ShipmentStatus.cs          # Created, PickedUp, InTransit, OutForDelivery, Delivered, Returned
│   │   ├── ShipmentEventStatus.cs     # Checkpoint ghi nhận dọc đường
│   │   ├── ShippingServiceType.cs     # Standard, Express, SameDay
│   │   ├── InventoryMovementType.cs   # InboundStock, OutboundShipment, ReturnRestock, Adjustment
│   │   ├── InventoryLedgerReferenceType.cs # PurchaseOrder, CustomerOrder, InventoryAudit
│   │   ├── InventoryReservationStatus.cs  # Reserved, Committed, Released, Expired
│   │   ├── InventoryReservationReferenceType.cs # CheckoutSession, AuctionWin
│   │   └── AuditAction.cs             # Insert, Update, Delete
│   └── Exceptions/
│       └── DomainException.cs         # Ngoại lệ nghiệp vụ miền
│
├── Fulfillment.Application/           # 2. TẦNG CA SỬ DỤNG (Application Layer)
│   ├── Common/Extensions/EnumExtensions.cs # Parse Enum an toàn
│   ├── Interfaces/
│   │   └── IFulfillmentDbContext.cs   # Giao diện DbContext fulfillment_db
│   ├── Services/
│   │   ├── Warehouse/                 # Tính năng Quản Lý Kho Bãi
│   │   │   ├── IWarehouseService.cs, WarehouseService.cs, WarehouseRequests.cs, WarehouseResponses.cs, WarehouseDtos.cs
│   │   ├── Shipment/                  # Tính năng Quản Lý Vận Đơn Giao Hàng
│   │   │   ├── IShipmentService.cs, ShipmentService.cs, ShipmentRequests.cs, ShipmentResponses.cs, ShipmentDtos.cs
│   │   └── Inventory/                 # Tính năng Tồn Kho & Quản Lý SKU
│   │       ├── IInventoryService.cs, InventoryService.cs, InventoryRequests.cs, InventoryResponses.cs
│   └── DependencyInjection.cs         # Đăng ký các dịch vụ tầng Application
│
├── Fulfillment.Infrastructure/        # 3. TẦNG HẠ TẦNG (Persistence & Seed Data)
│   ├── Persistence/
│   │   ├── AppDbContext.cs            # Triển khai EF Core DbContext
│   │   ├── Configurations/            # 8 cấu hình Fluent API EntityTypeConfiguration<T>
│   │   ├── Migrations/                # Migrations EF Core (20261030054853_InitialCreate)
│   │   └── Seeds/FulfillmentSeedData.cs # Dữ liệu kho mẫu và đơn vị vận chuyển
│   └── DependencyInjection.cs         # Đăng ký AppDbContext
│
└── Fulfillment.Api/                   # 4. TẦNG GIAO DIỆN RESTful HTTP API
    ├── Controllers/
    │   ├── Public/                    # Controllers phục vụ người dùng qua Gateway
    │   │   ├── WarehousesController.cs# /api/v1/warehouses (danh sách kho active, chi tiết)
    │   │   └── ShipmentsController.cs # /api/v1/shipments (tra cứu tracking, theo orderId)
    │   └── Internal/                  # Controllers nội bộ liên service
    │       └── InternalInventoriesController.cs # [Route("api/v1/internal/inventories")]
    │                                  # POST /initialize (Khởi tạo tồn kho SKU mới từ Catalog)
    │                                  # GET  /{skuId}    (Tra cứu số dư tồn kho cho Checkout)
    ├── Common/Converters/
    │   └── PascalCaseJsonStringEnumConverter.cs # Tuần tự hóa Enum thành PascalCase
    ├── Extensions/
    │   ├── ServiceDefaultsExtensions.cs # Swagger definitions đầy đủ headers
    │   ├── HttpContextExtensions.cs   # Trích xuất x-user-id và role
    │   └── ObservabilityExtensions.cs # OpenTelemetry tracing
    ├── Middleware/
    │   ├── InternalServiceAuthMiddleware.cs # Bảo vệ /api/v1/internal/* bằng secret key
    │   └── GlobalExceptionHandlerMiddleware.cs # Bắt lỗi trả về ProblemDetails
    └── Program.cs                     # Điểm khởi động ứng dụng .NET 8
```

---

## 3. Các Bất Biến & Quy Chuẩn Nghiệp Vụ Cốt Lõi

1. **Quy chuẩn 100% Số Nhiều:** Tuyệt đối dùng `/api/v1/shipments`, `/api/v1/warehouses`, `/api/v1/inventories`. Cấm dùng route số ít `/shipment` hay `/warehouse`.
2. **Không Repository Pattern:** Inject trực tiếp `IFulfillmentDbContext` vào `WarehouseService`, `ShipmentService`, `InventoryService`.
3. **Phân tách Public API và Internal API:**
   - Tra cứu kho và mã tracking vận đơn là Public API (`Controllers/Public/`).
   - Khởi tạo và điều chỉnh số lượng tồn kho vật lý là Internal API (`Controllers/Internal/InternalInventoriesController.cs`), bảo vệ bắt buộc bằng `InternalServiceAuthMiddleware` và header `X-Internal-Service-Key`.
4. **Bảo vệ quyền sở hữu thông tin vận chuyển:** Tra cứu chi tiết vận đơn theo `orderId` chỉ dành cho người mua sở hữu đơn hàng, người bán gửi hàng hoặc tài khoản `admin`/`staff`.
