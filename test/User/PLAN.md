# User Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service định danh và hồ sơ, cổng 8001, DB `usermanagement_db` 5433. Đây là service trưởng thành nhất: 26 endpoint, 233 test xanh, 10 tài liệu đã nghiệm thu.
Rủi ro còn lại nằm ở cấu hình xóa cascade và khối lượng tài liệu chưa nghiệm thu.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `User.sln -c Release` | Pass, 0 warning, 0 error |
| Test | 233 pass, 0 fail |
| Endpoint hiện thực | 26 |
| Tài liệu `B_none` | 62 |
| Tài liệu `A_Active` | 10 (toàn bộ là auth) |
| `HasQueryFilter` | 11 |
| `HasIndex` | 7 |
| `DeleteBehavior.Cascade` trong cấu hình viết tay | 5 |
| BCrypt cho mật khẩu | Có, xác nhận qua test |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| US-01 | MEDIUM | 52 tài liệu `B_none` mô tả endpoint có thể đã chạy được nhưng chưa được nghiệm thu, chưa chuyển `A_Active` | `docs/api/B_none/User/` 62 file so với `docs/api/A_Active/User/` 10 file |
| US-02 | MEDIUM | 5 quan hệ dùng `DeleteBehavior.Cascade` trong cấu hình viết tay, có nguy cơ xóa lan sang dữ liệu kiểm toán | `RefreshTokenConfiguration.cs`, `ReputationLogConfiguration.cs`, `SellerProfileConfiguration.cs`, `UserConfiguration.cs`, `UserPenaltyConfiguration.cs` |
| US-03 | LOW | `DELETE /api/v1/admin/users/{userId}` yêu cầu body chứa lý do xóa. Nhiều client và proxy bỏ body của DELETE | `User.Api/Controllers/Public/AdminUsersController.cs:126-136` |
| US-04 | LOW | Tên quyền seed đang là tiếng Việt, ví dụ `"Xem Danh Sách & Hồ Sơ Người Dùng"`, dễ lệch khi frontend ánh xạ theo mã | `User.Infrastructure/Persistence/Seeds/UserSeedData.cs:300-335` |
| US-05 | LOW | `GET /api/v1/users/{id}` không có `AllowAnonymous` tường minh, đang công khai nhờ không có policy toàn cục. Nếu sau này thêm policy mặc định, hợp đồng đổi mà không ai biết | `User.Api/Controllers/Public/UsersController.cs:22-31` |

## 4. Checklist thực thi

### Phase A. Xóa cascade

- [ ] A.1 Với `RefreshTokenConfiguration`, giữ `Cascade` và ghi lý do, vì token phải chết cùng user.
- [ ] A.2 Với `UserPenaltyConfiguration` và `ReputationLogConfiguration`, đổi sang `Restrict` hoặc `SetNull` để bảo toàn dấu vết kiểm toán.
- [ ] A.3 Với `SellerProfileConfiguration`, đổi sang `Restrict`.
- [ ] A.4 Tạo migration additive và kiểm tra snapshot.
- [ ] A.5 Test xóa user không xóa mất bản ghi kiểm toán.

### Phase B. Hợp đồng công khai

- [ ] B.1 Thêm `[AllowAnonymous]` cho `GET /api/v1/users/{id}` để hợp đồng hiện rõ trong code và Swagger.
- [ ] B.2 Rà DTO hồ sơ công khai, bảo đảm không trả email, số điện thoại, địa chỉ.
- [ ] B.3 Test khẳng định hồ sơ công khai không chứa trường nhạy cảm.
- [ ] B.4 Cân nhắc đổi `DELETE` sang `DELETE` không body, lý do chuyển thành query hoặc header riêng, cập nhật tài liệu và test.

### Phase C. Nghiệm thu tài liệu

- [ ] C.1 Lập bảng 62 tài liệu `B_none` với cột `endpoint tồn tại`, `test xanh`, `trạng thái`.
- [ ] C.2 Chuyển từng tài liệu đã đủ điều kiện sang `A_Active`.
- [ ] C.3 Đánh dấu `NOT_IMPLEMENTED` cho tài liệu chưa có code.
- [ ] C.4 Đồng bộ `docs/FRONTEND_API_ENDPOINT_MAPPING.md`.

### Phase D. Chất lượng dữ liệu seed

- [ ] D.1 Chuyển `PermissionName` sang tiếng Anh, giữ `PermissionCode` ổn định để không phá phân quyền.
- [ ] D.2 Nếu frontend đang hiển thị tiếng Việt, giữ bản dịch ở lớp giao diện thay vì DB.
- [ ] D.3 Chạy lại toàn bộ 233 test sau khi đổi seed.

### Phase E. Kiểm thử bổ sung

- [ ] E.1 Test đăng nhập sai mật khẩu trả `INVALID_CREDENTIALS`.
- [ ] E.2 Test OTP hết hạn trả `OTP_EXPIRED`.
- [ ] E.3 Test người dùng thường không gọi được `/api/v1/admin/users`.
- [ ] E.4 Test khóa tài khoản có ghi audit log.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/User
dotnet build User.sln -c Release
dotnet test  User.sln -c Release
```

## 6. Điều kiện hoàn thành

- Không còn cascade ngoài chủ đích.
- Hợp đồng hồ sơ công khai hiện rõ trong code.
- Mỗi tài liệu có trạng thái cuối cùng.
- 233 test hiện có vẫn xanh, cộng test mới.
