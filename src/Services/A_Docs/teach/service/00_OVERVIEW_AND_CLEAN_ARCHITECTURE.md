# Chuyen De 00: Kien Truc Clean Architecture & Feature Co-location

Chuyen de nay giai thich toan dien ve quy chuan to chuc ma nguon 4 tang Clean Architecture va mo hinh Feature Co-location duoc ap dung dong nhat tren toan bo he sinh thai microservices Nexus.

---

## 1. Mo Hinh Clean Architecture 4 Tang Chuan Hoa

Moi vi dich vu backend trong Nexus (`User`, `Catalog`, `Commerce`, `Auction`, `Fulfillment`, `Notification`, `Log`, `CheckHeal`) duoc dong goi trong dung 4 project tuong ung voi 4 tang phan tach ro rang ve mat trach nhiem:

```text
User.sln
├── User.Domain/           # 1. Tang Mien Nghiep Vu (Pure Domain)
├── User.Application/      # 2. Tang Ca Su Dung (Application Use Cases)
├── User.Infrastructure/   # 3. Tang Ha Tang (Persistence, Redis, Clients)
├── User.Api/              # 4. Tang Ranh Gioi HTTP (Controllers, Middlewares, DI Root)
└── User.Tests/            # 5. Tang Kiem Thu Tu Dong (Unit & Integration Tests)
```

### So do huong phu thuoc (Dependency Inversion Rule)

```text
[ User.Api ]              [ User.Infrastructure ]
      │                               │
      │ Phụ thuộc vào                 │ Triển khai Interfaces của
      ▼                               ▼
     ┌─────────────────────────────────┐
     │        User.Application         │
     └────────────────┬────────────────┘
                      │ Phụ thuộc vào
                      ▼
     ┌─────────────────────────────────┐
     │           User.Domain           │  <-- 0 Thư viện ngoài (Pure C#)
     └─────────────────────────────────┘
```

---

## 2. Chi Tiet Trach Nhiem Va Rang Buoc Tung Tang

### 2.1. Tang Domain (`User.Domain`)
- **Vai tro:** Chiet xuat cac khai niem nghiep vu cot loi, thuc the CSDL (Entities), kieu liet ke (Enums), va ngoai le nghiep vu (Exceptions).
- **Rang buoc bat bien (Zero-Dependency Invariant):**
  Tang Domain tuyet doi **khong phu thuoc vao bat ky thu vien ngoai nao** (Khong EF Core, khong MediatR, khong ASP.NET Core). File `User.Domain.csproj` chi chua khai bao .NET SDK thuan tuy:

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>net8.0</TargetFramework>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
    </PropertyGroup>
</Project>
```

- **Thanh phan ben trong:**
  - `Base/BaseEntity.cs`: Lop thuc the co so gom `Id` (kieu `Guid`), thoi gian tao/cap nhat (`CreatedAt`, `UpdatedAt`) va cac truong xoa mem (`IsDeleted`, `DeletedAt`).
  - `Entities/`: Cac class POCO dinh nghia cau truc du lieu nhu `User`, `Role`, `Permission`, `SellerProfile`, `AuditLog`.
  - `Enums/`: Cac Enum dinh nghia trang thai nhu `UserStatus`, `RoleType`, `PenaltyStatus`.
  - `Exceptions/`: `DomainException`, `EntityNotFoundException`, `BusinessRuleValidationException` chua san `StatusCode` va `ErrorCode` (SCREAMING_SNAKE_CASE).

### 2.2. Tang Application (`User.Application`)
- **Vai tro:** Dieu phoi ca su dung (Use Cases), xac thuc du lieu dau vao, dinh nghia cac hop dong truy cap du lieu (`IUserDbContext`) va giao tiep lien dich vu.
- **Phu thuoc:** Chi phu thuoc ve mat project reference vao `User.Domain`.
- **Thiet ke thuc dung ve Package Dependencies (Pragmatic Clean Architecture):**
  Trong Clean Architecture thuan ly thuyet, tang Application thuong khong duoc chua bat ky package ngoai nao. Tuy nhien, he thong Nexus lua chon thiet ke thuc dung:
  - Tham chieu `Microsoft.EntityFrameworkCore 8.0.10`: Cho phep giao dien `IUserDbContext` khai bao truc tiep cac `DbSet<T>`. Nho do, tang Application co the su dung truc tiep LINQ Projections (`.Select()`) va phan trang tai CSDL (`.Skip().Take()`) ma khong can den tang Repository trung gian thua thai.
  - Tham chieu `BCrypt.Net-Next 4.0.3`: Cho phep cac use case xac thuc (`AuthService`) bam va kiem tra mat khau truc tiep ma khong can tao mot interface bao boc rong nhu `IPasswordHasher`.
- **Thanh phan ben trong:**
  - `Interfaces/IUserDbContext.cs`: Khai bao cac `DbSet<T>` va phuong thuc `SaveChangesAsync` ma khong lo chi tiet Npgsql hay PostgreSQL.
  - `Interfaces/`: Cac hop dong Typed HTTP Client (`IEmailNotificationClient`, `IFulfillmentServiceClient`, `IWalletServiceClient`).
  - `Services/{Feature}/`: Cac module tinh nang gom Service, Requests va Responses.
  - `Common/Models/PagedData.cs`: Cau truc dong goi ket qua phan trang chuan.
  - `Common/Extensions/AuditLogExtensions.cs`: Tien ich ghi nhat ky kiem toan tap trung.

### 2.3. Tang Infrastructure (`User.Infrastructure`)
- **Vai tro:** Hien thuc hoa toan bo cac interface duoc dinh nghia tai Application bang cac cong nghe cu the: CSDL PostgreSQL qua EF Core, bo nho dem Redis, tao chuoi JWT, va gui goi tin HTTP REST ra ngoai.
- **Phu thuoc:** Phu thuoc vao `User.Application` va `User.Domain`.
- **Thanh phan ben trong:**
  - `Persistence/AppDbContext.cs`: Ke thua `DbContext`, hien thuc `IUserDbContext`.
  - `Persistence/Configurations/`: Cac file Fluent API mapping quan he khoa ngoai, chi muc va bo loc xoa mem.
  - `Persistence/Seeds/UserSeedData.cs`: Dữ lieu khoi tao he thong voi GUID co dinh.
  - `Services/Redis/RedisOtpService.cs`: Hien thuc luu tru va kiem tra OTP qua Redis.
  - `Services/Jwt/JwtTokenGenerator.cs`: Ký token HMAC-SHA256.
  - `Services/Common/IdentityPropagationHandler.cs`: DelegatingHandler tu dong lan truyen headers danh tinh.

### 2.4. Tang Api (`User.Api`)
- **Vai tro:** Diem vao duy nhat (Presentation Layer) cho cac yeu cau HTTP tu API Gateway hoac client ben ngoai. Chuyen doi request, kiem tra dinh danh tai bien, va tra ve phong bi phan hoi.
- **Phu thuoc:** Phu thuoc vao `User.Application` va `User.Infrastructure`.
- **Rang buoc bat bien:** Tuyet doi khong chua logic nghiep vu hoac truy van CSDL truc tiep tai Controller. Controller chi inject duy nhat Interface cua Feature Service tuong ung.

---

## 3. Mo Hinh Feature Co-Location (Dong Goi Theo Tinh Nang)

Thay vi phan chia thu muc theo kieu truyen thong (Commands, Queries, DTOs, Services nam rieng o cac thu muc xa nhau), Nexus ap dung mo hinh **Feature Co-location**. Toan bo cac thanh phan lien quan den mot tinh nang nghiep vu duoc dat chung tai mot thu muc:

```text
User.Application/Services/{Feature}/
├── I{Feature}Service.cs     # Hop dong giao dien cua ca su dung
├── {Feature}Service.cs      # Trien khai nghiep vu (inject truc tiep IUserDbContext)
├── {Feature}Requests.cs     # Tap hop cac C# Records chua du lieu dau vao kem DataAnnotations
├── {Feature}Responses.cs    # Tap hop cac C# Records chua du lieu dau ra (Pure DTOs)
└── {Feature}Dtos.cs         # Sub-DTOs ho tro noi bo (tuy chon)
```

### Vi du thuc te: Tinh nang Auth (`User.Application/Services/Auth/`)
- `IAuthService.cs`: Dinh nghia cac phuong thuc `RegisterAsync`, `VerifyOtpAsync`, `LoginAsync`, `RefreshTokenAsync`.
- `AuthService.cs`: Xu ly kiem tra email ton tai, hash mat khau qua BCrypt, tao token JWT va ghi audit log.
- `AuthRequests.cs`: Chiet xuat cac record: `RegisterApiRequest`, `VerifyOtpApiRequest`, `LoginApiRequest`.
- `AuthResponses.cs`: Chiet xuat cac record: `LoginApiResponse`, `TokenRefreshApiResponse`.

### Mo Hinh Resource Controller Va Feature Service (Phan Tach Tuyen Duong Chuan REST)
Quy chuan REST API cua Nexus yeu cau toan bo cac bo suu tap tai nguyen phai mang danh tu so nhieu rieng biet (`/api/v1/users`, `/api/v1/sellers`, `/api/v1/admin/roles`, `/api/v1/admin/sellers`...). Do do, tai `User.Api/Controllers/Public/` co **8 Controller mong (Thin Controllers)** duoc chia tach theo tai nguyen URL de giu code gon gang. 

Tuy nhien, ve mat kien truc, **moi Controller chi inject duy nhat 1 Feature Service tuong ung** (khong bao gio inject DbContext hoac chua logic tinh toan):
- `IAuthService` <- `AuthController.cs` (`/api/v1/auth`)
- `IProfileService` <- `MeController.cs` (`/api/v1/me`) va `UsersController.cs` (`/api/v1/users/{userId}`)
- `ISellerService` <- `SellerController.cs` (`/api/v1/sellers`), `AdminSellersController.cs` (`/api/v1/admin/sellers`), `AdminSellerRegistrationsController.cs` (`/api/v1/admin/seller-registrations`)
- `IAdminUserService` <- `AdminUsersController.cs` (`/api/v1/admin/users`), `AdminRolesController.cs` (`/api/v1/admin/roles`)

---

## 4. Ly Do Cam Repository Pattern Boc Ngoai EF Core

Trong nhieu he thong truyen thong, lap trinh vien thuong tao `IRepository<T>`, `GenericRepository<T>`, va `IUnitOfWork`. Trong he sinh thai Nexus, viec nay bi **CAM TUYET DOI** vi cac ly do kien truc sau:

1. **EF Core da la Repository va Unit of Work:**
   - `DbContext` chinh la mot implementation hoan chinh cua **Unit of Work Pattern**.
   - `DbSet<T>` chinh la mot implementation cua **Repository Pattern**.
   - Viec bọc them mot lop `IRepository<T>` ben ngoai `DbSet<T>` chi tao them code thua (abstraction bloat) ma khong dem lai loi ich kien truc nao.

2. **Ngan can truy van toi uu (LINQ Projections):**
   - Khi dung Repository generic (nhu `GetByIdAsync(id)` hoac `GetAll()`), lap trinh vien thuong lay toan bo cac cot cua entity len bo nho.
   - Khi inject truc tiep `IUserDbContext`, Service co the dung `.Select(u => new UserSummaryResponse { ... })` de CSDL PostgreSQL chi tra ve dung cac cot can thiet, giam tai I/O va bang thong mang.

3. **Giai quyet triet de van de phan trang tai Database:**
   - Cac Generic Repository thuong vo tinh khuyen khich viec lay `IEnumerable<T>` ve roi moi cat trang trong RAM.
   - Voi `IUserDbContext`, Service thuc hien truc tiep `.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync()` tren CSDL.

---

## 5. Ly Do Cam MediatR / CQRS (Ngoai Tru WalletService)

Nhieu du an .NET thuong chia nho moi endpoint thanh mot Command, CommandHandler, Query, QueryHandler su dung MediatR. He thong Nexus chi ap dung MediatR tren duy nhat `WalletService` (do dac thu CQRS dong bang lien quan den giao dich tai chinh), con lai 8 microservices deu su dung **Feature Services truc tiep** vi:

1. **Giam thieu phan manh code:** Voi MediatR, mot tinh nang don gian co the bi chia nho thanh 4-5 file nam o cac thu muc xa nhau, gay kho khan cho viec theo doi call stack va bao tri.
2. **Loai bo chi phi xu ly bat dong bo khong can thiet:** Service thuan tuy goi phuong thuc qua Interface ro rang, giup trinh bien dich .NET toi uu hoa inlining, de dang viet Unit Test voi Mock, va giu cho luong code de doc nhat co the.
