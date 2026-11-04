# Giao Trinh Kien Truc Vi Dich Vu Nexus (Nexus Microservices Architecture Blueprint)

Thu muc nay chua bo tai lieu giang day va tham chieu kien truc phan mem danh cho cac vi dich vu (.NET 8 LTS) trong he sinh thai Nexus, su dung **UserService** (`src/Services/User/`) lam nguyen mau chuan (Archetype).

Tat ca cac vi dich vu khac trong Nexus (`Catalog`, `Commerce`, `Auction`, `Fulfillment`, `Notification`, `Log`, `CheckHeal`) deu su dung chung bo khung kien truc, quy tac ranh gioi, ky thuat xu ly va cac thanh phan bo tro nay, chi khac biet o nghiep vu dac thu cua tung mien (Domain).

---

## 1. Muc Luc Cac Chuyen De Kien Truc

Bo tai lieu duoc phan tach thanh 7 chuyen de kien truc doc lap:

| STT | Chuyen De | File Tai Lieu | Noi Dung Trong Tam |
|:---:|:---|:---|:---|
| 00 | **Kien Truc Clean Architecture & Feature Co-location** | [`00_OVERVIEW_AND_CLEAN_ARCHITECTURE.md`](00_OVERVIEW_AND_CLEAN_ARCHITECTURE.md) | 4 tang kien truc, Dependency Inversion, Feature Co-location, ly do cam Repository Pattern va MediatR. |
| 01 | **Bao Mat & Quan Ly Danh Tinh** | [`01_SECURITY_AND_IDENTITY.md`](01_SECURITY_AND_IDENTITY.md) | Zero-Trust Edge Identity, `UserContextMiddleware`, `RequireRoleAttribute`, hash BCrypt va sinh JWT. |
| 02 | **Pipeline & Xu Ly Ngoai Le Tap Trung** | [`02_MIDDLEWARE_AND_PIPELINE.md`](02_MIDDLEWARE_AND_PIPELINE.md) | Thu tu Pipeline ASP.NET Core, `GlobalExceptionHandlerMiddleware` chuan RFC 9110, quy che Internal REST. |
| 03 | **Bo Loc, Validation & Tuan Tu Hoa Enum** | [`03_FILTERS_VALIDATION_AND_CONVERTERS.md`](03_FILTERS_VALIDATION_AND_CONVERTERS.md) | `ApiValidationProblemFactory` chong ro ri loi, `PascalCaseJsonStringEnumConverter`, HttpContext extensions. |
| 04 | **Luu Tru Du Lieu & Quan Ly Migration** | [`04_DATA_PERSISTENCE_AND_MIGRATIONS.md`](04_DATA_PERSISTENCE_AND_MIGRATIONS.md) | EF Core 8 voi PostgreSQL, integer enum, global query filter Soft Delete, Deterministic Seed GUIDs. |
| 05 | **Tich Hop Ngoai & Giao Tiep Lien Dich Vu** | [`05_EXTERNAL_INTEGRATIONS_AND_CLIENTS.md`](05_EXTERNAL_INTEGRATIONS_AND_CLIENTS.md) | Typed REST HttpClients, `IdentityPropagationHandler`, Redis OTP in-memory fallback, normalize connection. |
| 06 | **Tien Ich Cat Ngang & Quan Tri He Thong** | [`06_CROSS_CUTTING_AND_UTILITIES.md`](06_CROSS_CUTTING_AND_UTILITIES.md) | `AuditLogExtensions`, OpenTelemetry distributed tracing xuat Tempo, phan trang chuan `PagedData<T>`. |

---

## 2. So Do Tong Quan Luong Xu Ly He Thong

```text
[ External Client ]
        │
        ▼ (JWT Bearer Token / HTTPS)
[ Edge API Gateway (Port 8080) ]
        │ - Xac thuc chu ky JWT tai bien
        │ - Active Anti-Header-Spoofing
        │ - YARP Reverse Proxy tiem headers: x-user-id, x-user-roles, x-user-email, x-trace-id
        ▼
[ Backend Microservice (UserService - Port 8001) ]
  ├── 1. UserContextMiddleware: Doc headers, tao ClaimsPrincipal tren HttpContext.User
  ├── 2. GlobalExceptionHandlerMiddleware: Bat moi ngoai le, tra ve application/problem+json
  ├── 3. Thin Controllers (Public/):
  │        - RequireRoleAttribute: Kiem tra vai tro nguoi dung
  │        - ApiValidationProblemFactory: Bat loi DataAnnotations an toan
  │        - Goi truc tiep IFeatureService (Zero logic trong Controller)
  ├── 4. Feature Services (Application/):
  │        - Xu ly logic nghiep vu
  │        - Truy van truc tiep IUserDbContext (DbSet<T>, Skip/Take phan trang tai DB)
  │        - AddAuditLog: Ghi nhat ky kiem toan commit cung transaction
  └── 5. External Integrations (Infrastructure/):
           - RedisOtpService: Luu OTP (tu dong fallback in-memory neu Redis offline)
           - Typed REST Clients: Goi downstream kem IdentityPropagationHandler
```

---

## 3. Cach Su Dung Bo Tai Lieu Nay

- Neu muon hieu tong quan kien truc va cach to chuc code: bat dau tu Chuyen de 00.
- Neu muon hieu luong xac thuc va phan quyen tu Gateway vao Service: doc Chuyen de 01 va 02.
- Neu muon tim hieu cach chuan hoa REST API, validate va serialize: doc Chuyen de 03.
- Neu muon nam vung cach lam viec voi CSDL, Entity, EF Core: doc Chuyen de 04.
- Neu muon biet cach viet client goi giua cac service va dung Redis: doc Chuyen de 05.
- Neu muon biet cach ghi audit log, phan trang va tracing: doc Chuyen de 06.
