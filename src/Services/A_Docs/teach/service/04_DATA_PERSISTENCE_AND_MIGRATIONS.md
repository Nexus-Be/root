# Chuyen De 04: Luu Tru Du Lieu & Quan Ly Migration (Persistence & Migration Architecture)

Chuyen de nay huong dan toan dien ve kien truc luu tru du lieu su dung Entity Framework Core 8 voi PostgreSQL 16, co che xoa mem tu dong (Soft Delete Query Filters), ky thuat luu Enum dang so nguyen, va quy tac tao du lieu mau khong lam sai lech Snapshot Migration.

---

## 1. Co So Du Lieu Tach Biet (Database-per-Service Isolation)

Trong he thong Nexus, moi microservice so huu doc quyen mot co so du lieu rieng biet:
- **UserService:** `usermanagement_db` (Port container: `5432`, Port host: `5433`).
- **CatalogService:** `category_db` (Port host: `5434`).
- **CommerceService:** `commerce_db` (Port host: `5435`).
- ...

### Rang buoc kien truc bat bien:
1. **Cam truy van cheo (No Cross-Database Queries):** Tuyet doi khong dung `dblink`, Foreign Data Wrapper (FDW) hoac Raw SQL de join sang CSDL cua dich vu khac.
2. **Cam chia se `DbContext`:** Moi service co mot `DbContext` doc lap nam trong tang Infrastructure cua chinh service do.
3. **Tuong tac qua REST:** Khi mot dich vu can du lieu tu dich vu khac, no bat buoc phai goi thong qua HTTP REST Client.

---

## 2. Co Che Xoa Mem Toan Cuc (Global Soft Delete Query Filters)

Trong cac he thong thuc te, du lieu nguoi dung, don hang va thong tin tai khoan khong bao gio duoc phep xoa vat ly khoi o cung (`DELETE FROM ...`) vi can phuc vu doi soat, phap ly va kiem toan.

### Thiet ke Entity
Moi thuc the ke thua `BaseEntity<Guid>`, mac dinh so huu 2 thuoc tinh:
- `IsDeleted`: kieu `bool` (mac dinh `false`).
- `DeletedAt`: kieu `DateTimeOffset?` (thoi diem danh dau xoa).

### Cau hinh Fluent API (`UserConfiguration.cs`)
Tai tang Infrastructure, bo loc toan cuc duoc dang ky tren tung thuc the:

```csharp
// src/Services/User/User.Infrastructure/Persistence/Configurations/UserConfiguration.cs
public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        // Khai báo bộ lọc xóa mềm toàn cục
        builder.HasQueryFilter(x => !x.IsDeleted);

        // ... các cấu hình index và relationship
    }
}
```

### Hieu qua thuc te:
- Khi Service viet truy van LINQ:
  `var users = await _dbContext.Users.ToListAsync();`
  EF Core tu dong chuyen hoa thanh cau lenh SQL:
  `SELECT ... FROM "Users" WHERE "IsDeleted" = FALSE;`
- Lap trinh vien khong can phai nho viet thu cong `.Where(u => !u.IsDeleted)` o moi noi.
- Trong truong hop dac biet can truy van ca ban ghi da xoa (nhu nghiep vu khoi phuc tai khoan cua Admin), lap trinh vien co the chu dong bo qua bo loc bang cach goi `.IgnoreQueryFilters()`.

---

## 3. Luu Tru Enum Dang So Nguyen (Integer Enum Persistence)

He thong Nexus ap dung quy tac bat bien: **100% Enum trong CSDL phai duoc luu duoi dang so nguyen 32-bit (`integer`)**.

### Tai sao CAM dung `HasConversion<string>()`?
- **Lang phi dung luong bo nho:** Mot chuoi `"PendingVerification"` chiem khoang 20 bytes tren moi dong du lieu. Trong khi do, mot so nguyen `int` chi chiem dung 4 bytes.
- **Suy giam toc do Index:** Chi muc B-Tree tren cot so nguyen nhanh hon tu 3 den 5 lan so voi chi muc tren chuoi van ban dai, giup cache bo nho dem cua PostgreSQL hoat dong hieu qua hon rat nhieu.

### Tai sao CAM dung PostgreSQL Custom Enum Types (`CREATE TYPE ... AS ENUM`)?
- PostgreSQL Custom Enum Types khong cho phep chay cac cau lenh cap nhat gia tri (nhu `ALTER TYPE ... ADD VALUE`) ben trong mot Transaction block.
- Dieu nay khien cac Script Migration tu dong cua EF Core bi that bai moi khi he thong bo sung them gia tri Enum moi vao nghiep vu.
- Dung kieu `integer` giup he thong mo rong them gia tri moi (nhu them mot `RoleType` hoac `PenaltyStatus` moi) ma hoan toan khong anh huong den schema CSDL hien co.

---

## 4. Chi Muc Hieu Nang & Rang Buoc An Toan (Performance Indexes)

File `UserConfiguration.cs` the hien cac thiet ke chi muc tinh te:

### Filtered Unique Index cho cot Nullable
Trong CSDL, cot `Username` la cot tuy chon (co the null neu nguoi dung moi dang ky bang email). Tuy nhien, neu da co username thi bat buoc phai la duy nhat.

```csharp
builder.Property(x => x.Username).HasMaxLength(100);
builder.HasIndex(x => x.Username).IsUnique().HasFilter("\"Username\" IS NOT NULL");
```
- Neu dung unique index thong thuong, mot so he quan tri CSDL co the tu choi khi co 2 ban ghi cung mang gia tri `NULL`.
- Su dung **Filtered Index** (`HasFilter("\"Username\" IS NOT NULL")`) dam bao chi danh chi muc unique cho cac dong thuc su co du lieu, tiet kiem tai nguyen va tranh loi khoa ngoai.

### Ky luat ve DeleteBehavior (Khoa Ngoai)
- **Uu tien `DeleteBehavior.Restrict` hoac `SetNull`:**
  - `BannedBy`, `ResolvedBy`: Khi nguoi quan tri xoa tai khoan, thong tin nguoi ban hanh lenh cam van phai duoc giu lai hoac gan ve null (`SetNull`), tranh viec xoa cascade lam mat sach nguoi dung bi cam.
  - `ReporterId`, `ReportedUserId`: Dùng `Restrict` de ngan chan viec xoa tai khoan lam xoa sach lich su bao cao vi pham.
- **Cam dung `DeleteBehavior.Cascade` bua bai:** Chi ap dung cho cac quan he phu thuoc chat che ve mat vong doi (nhu xoa User se xoa cac RefreshToken va Penalty kem theo cua User do).

---

## 5. Du Lieu Mau Co Dinh (Deterministic Seed Data Invariant)

Trong file `src/Services/User/User.Infrastructure/Persistence/Seeds/UserSeedData.cs`, toan bo du lieu khoi tao he thong (System Roles, Super Admin, System Configurations) deu su dung **GUID co dinh (Deterministic GUIDs)**:

```csharp
public static readonly Guid BuyerRoleId = Guid.Parse("11111111-1111-1111-1111-111111111111");
public static readonly Guid SellerRoleId = Guid.Parse("22222222-2222-2222-2222-222222222222");
public static readonly Guid StaffRoleId = Guid.Parse("33333333-3333-3333-3333-333333333333");
public static readonly Guid AdminRoleId = Guid.Parse("44444444-4444-4444-4444-444444444444");
```

### Ly do kien truc:
- **Cam tuyet doi dung `Guid.NewGuid()` trong `HasData()`:**
  Moi khi go lenh `dotnet ef migrations add`, EF Core se bien dich code va so sanh trang thai Entity hien tai voi `AppDbContextModelSnapshot.cs`.
  Neu dung `Guid.NewGuid()`, moi lan build se sinh ra mot GUID ngau nhien moi. EF Core se tuong rang du lieu seed bi thay doi va lien tuc sinh ra cac file Migration rac (Spurious diff migrations), lam hong toan bo lich su migrate cua team.
- **Hash mat khau seed san:** Toan bo mat khau cua cac tai khoan seed san deu duoc hash truoc bang BCrypt (`$2a$11$...`), khong bao gio de mat khau plain text trong ma nguon.

---

## 6. Tu Dong Ap Dung Migration An Toan (Startup Safe Auto-Migration)

De giam thieu thao tac chay lenh thu cong khi deploy tren moi truong Docker hoac Kubernetes, file `Program.cs` tich hop co che tu dong migrate CSDL khi khoi chay:

```csharp
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        if (db.Database.IsRelational())
        {
            db.Database.Migrate();
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Database migration deferred on startup: {Message}", ex.Message);
    }
}
```

### Diem an toan:
- Kiem tra `db.Database.IsRelational()`: Tranh chay lenh migrate khi dang chay Unit Test su dung `InMemoryDatabase`.
- Boc trong `try-catch`: Neu CSDL PostgreSQL dang khoi dong cham (chua san sang nhan ket noi), ung dung se khong bi crash ngay lap tuc ma ghi log warning, cho phep he thong hoan thanh viec boot hoac thu lai.
