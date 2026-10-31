# Bằng chứng kiểm tra (thu ngày 2026-10-31)

Mọi số liệu dưới đây lấy từ lần chạy thật trên máy, không phải suy đoán.
Mỗi mục ghi kèm lệnh để tái lập.

## 1. Build

Lệnh:

```bash
for d in Auction Catalog CheckHeal Commerce Fulfillment Gateway Log Notification User Wallet; do
  ( cd src/Services/$d && dotnet build $d.sln -c Release --nologo -v q )
done
```

Kết quả:

| Service | Warning | Error | Exit |
|:---|:---:|:---:|:---:|
| Auction | 0 | 0 | 0 |
| Catalog | 0 | 0 | 0 |
| CheckHeal | 0 | 0 | 0 |
| Commerce | 0 | 0 | 0 |
| Fulfillment | 0 | 0 | 0 |
| Gateway | 0 | 0 | 0 |
| Log | 0 | 0 | 0 |
| Notification | 0 | 0 | 0 |
| User | 0 | 0 | 0 |
| Wallet | 0 | 0 | 0 |

## 2. Test

Lệnh:

```bash
for d in CheckHeal Gateway Notification User Wallet; do
  ( cd src/Services/$d && dotnet test $d.sln -c Release --nologo -v q )
done
```

Kết quả:

| Service | Passed | Failed | Skipped | Ghi chú |
|:---|:---:|:---:|:---:|:---|
| CheckHeal | 23 | 0 | 0 | `AGENTS.md` ghi 17 test, thực tế 23 |
| Gateway | 58 | 0 | 0 | |
| Notification | 15 | 0 | 0 | |
| User | 233 | 0 | 0 | |
| Wallet | 61 | 0 | 0 | |
| Auction | không có project test | | | |
| Catalog | không có project test | | | |
| Commerce | không có project test | | | |
| Fulfillment | không có project test | | | |
| Log | không có project test | | | |

Tổng test đang chạy: 390, tất cả pass.

## 3. Đếm endpoint đã hiện thực

Lệnh:

```bash
grep -rho "\[Http\(Get\|Post\|Put\|Patch\|Delete\)" --include="*.cs" {Service}/{Service}.Api/Controllers | wc -l
```

| Service | Endpoint | Tài liệu `B_none` | Tài liệu `A_Active` |
|:---|:---:|:---:|:---:|
| Auction | 3 | 21 | 0 |
| Catalog | 5 | 17 | 0 |
| CheckHeal | 11 | 4 | 0 |
| Commerce | 3 | 17 | 0 |
| Fulfillment | 6 | 9 | 0 |
| Gateway | 0 (YARP, không controller) | 0 | 0 |
| Log | 5 | 4 | 0 |
| Notification | 10 | 11 | 0 |
| User | 26 | 62 | 10 |
| Wallet | 10 | 11 | 0 |

Tổng: 79 endpoint hiện thực, 156 tài liệu `B_none`, 10 tài liệu `A_Active` (toàn bộ là auth của User).

## 4. Kiểm tra kiến trúc tĩnh

| Phép kiểm | Lệnh | Kết quả |
|:---|:---|:---|
| MediatR chỉ có ở Wallet | `rg -l MediatR --glob '*.csproj' src/Services` | Chỉ `Wallet.Application.csproj`. Đạt |
| Không có Repository/UnitOfWork | `rg "(class\|interface)\s+\w*(Repository\|UnitOfWork)\b" --glob '*.cs'` | 0 kết quả. Đạt |
| Domain không tham chiếu EF/ASP.NET/MediatR | `rg -l "Microsoft.EntityFrameworkCore\|Microsoft.AspNetCore\|MediatR" --glob '*.csproj' src/Services/*/*.Domain` | 0 kết quả. Đạt |
| Application không tham chiếu ASP.NET | `rg -l "Microsoft.AspNetCore" --glob '*.csproj' src/Services/*/*.Application` | 0 kết quả. Đạt |
| Không có route alias trùng trên 1 action | script Python quét attribute block | 0 action có 2 attribute `Http*`. Đạt |
| Không inject DbContext vào controller | `rg "I[A-Za-z]*DbContext" --glob '*.cs' */*.Api/Controllers` | 0 kết quả. Đạt |
| Không có secret hard-code | `rg "Password=\|Host=.*;Username="` | Chỉ chuỗi nội suy từ biến môi trường. Đạt |
| Port đúng quy ước | đọc `launchSettings.json` | 8001 đến 8009 và 8080. Đạt |
| Không khai báo Redis container trong submodule | `rg redis --glob 'docker-compose*.yml'` | Chỉ biến `REDIS_CONNECTION_STRING`. Đạt |
| `verify-wallet-architecture.sh` | chạy script | In `OK: Wallet CQRS architecture is intact (11 handlers, 2 controllers, MediatR wired).` |

## 5. Kiểm tra dữ liệu và bảo mật

| Phép kiểm | Lệnh | Kết quả |
|:---|:---|:---|
| Query filter xóa mềm | `rg HasQueryFilter` theo từng service | Auction 0, Catalog 0, Fulfillment 0, Log 0, Notification 0. Commerce 14, User 11, Wallet 7 |
| Index | `rg HasIndex --glob '*Configuration.cs'` | Auction 1, Catalog 1, Log 1, Notification 3, Fulfillment 4, Commerce 7, User 7, Wallet 7 |
| Xóa cascade trong cấu hình viết tay | `rg DeleteBehavior.Cascade --glob '*Configuration.cs'` | 5 chỗ, toàn bộ ở User |
| `HasConversion<string>` hoặc enum PostgreSQL | `rg "HasConversion<string>\|HasPostgresEnum\|MapEnum"` | 0 kết quả. Đạt |
| Controller không có attribute xác thực | quét `RequireRole`/`Authorize`/`AllowAnonymous` | 10 controller, liệt kê ở từng `PLAN.md` |
| Dùng `Idempotency-Key` | `rg "Idempotency-Key\|GetIdempotencyKey()"` | Có helper ở 8 service Api, không controller nào gọi |
| `Guid.NewGuid()` trong seed | `rg "Guid.NewGuid()"` | 0 kết quả. Đạt |
| `DateTime.Now` thay cho UTC | `rg "DateTime\.Now\b"` | 0 kết quả. Đạt |
| Enum converter PascalCase | `rg PascalCaseJsonStringEnumConverter` | Có ở 9 service Api |

## 6. Cấu hình tạm khóa Internal API

| Hạng mục | Trạng thái |
|:---|:---|
| `app.UseMiddleware<InternalServiceAuthMiddleware>()` | Bị comment ở 9 service, CheckHeal comment tại `Program.cs:109` |
| `InternalServiceAuthHandler` DI | Bị comment ở Catalog, Commerce, User |
| Gateway route cho `/api/v1/internal` | Không có trong `Gateway/appsettings.json` |
| `Controllers/Internal/` | Chỉ còn ở Wallet và rỗng |
| Dead code còn lại | `InternalServiceAuthMiddleware` ở 9 service, `InternalOperationFilter` ở 8 service, khối comment trong `ClientContextMiddleware.cs` và `SwaggerExtensions.cs` |
