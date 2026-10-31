# CheckHeal Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service giám sát sức khỏe và giữ ấm hệ thống, cổng 8009, không có DB. Có 11 endpoint và 23 test xanh.
Vấn đề chính là mô hình bảo vệ bằng một khóa API dùng chung và thiếu dấu vết kiểm toán khi bật tắt giám sát.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `CheckHeal.sln -c Release` | Pass, 0 warning, 0 error |
| Test | 23 pass, 0 fail (tài liệu ghi 17) |
| Endpoint hiện thực | 11 |
| Tài liệu `B_none` | 4 |
| Tài liệu `A_Active` | 0 |
| Bảo vệ | `ApiKeyAuthMiddleware`, bỏ qua cho `/`, `/swagger`, `/health`, `/health/live`, `/health/ready` |
| DB cục bộ | Không có, đúng thiết kế |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| CH-01 | MEDIUM | Một khóa API tĩnh dùng chung cho mọi người vận hành. Không biết ai đã tắt giám sát, không có audit log vì không có DB | `CheckHeal.Api/Middleware/ApiKeyAuthMiddleware.cs:38-62` |
| CH-02 | MEDIUM | Endpoint bật tắt target có thể làm tắt keep-alive của một service trong thời gian dài mà không có cảnh báo | `CheckHeal.Api/Controllers/Public/HealthCheckController.cs` |
| CH-03 | MEDIUM | Route `/api/v1/healthcheck` dùng số ít, lệch quy ước số nhiều cho bộ sưu tập | `CheckHeal.Api/Controllers/Public/HealthCheckController.cs:12` |
| CH-04 | LOW | `AGENTS.md` ghi 17 test, thực tế 23 | `CheckHeal/AGENTS.md` mục 0 |
| CH-05 | LOW | 4 tài liệu `B_none` nhưng 11 endpoint, thiếu tài liệu cho phần lớn endpoint điều khiển | `docs/api/B_none/CheckHeal/` |

## 4. Checklist thực thi

### Phase A. Dấu vết kiểm toán

- [ ] A.1 Ghi log có cấu trúc cho mọi lần bật tắt target, gồm IP, thời điểm, target, trạng thái cũ và mới.
- [ ] A.2 Giữ log này ở nơi đọc lại được, ví dụ đẩy sang LogService qua REST.
- [ ] A.3 Thêm endpoint đọc lịch sử thay đổi cấu hình.
- [ ] A.4 Test khẳng định mỗi lần toggle sinh một bản ghi.

### Phase B. Bảo vệ nâng cao

- [ ] B.1 Ghi rõ quy trình luân chuyển khóa API trong `specs`.
- [ ] B.2 Cho phép cấu hình nhiều khóa để xoay vòng mà không gián đoạn.
- [ ] B.3 Thêm giới hạn tần suất cho endpoint toggle để tránh lạm dụng.
- [ ] B.4 Test khóa cũ vẫn dùng được trong thời gian chuyển tiếp.

### Phase C. Hợp đồng route

- [ ] C.1 Quyết định giữ `/api/v1/healthcheck` hay đổi sang `/api/v1/healthchecks`.
- [ ] C.2 Nếu đổi, cập nhật `Gateway/appsettings.json` route `/api/v1/healthcheck/{**catch-all}` và tài liệu.
- [ ] C.3 Thêm route mới vào `docs/FRONTEND_API_ENDPOINT_MAPPING.md`.

### Phase D. Kiểm thử và tài liệu

- [ ] D.1 Giữ 23 test xanh.
- [ ] D.2 Bổ sung test cho endpoint dashboard và on-demand check.
- [ ] D.3 Viết tài liệu cho 11 endpoint, chuyển sang `A_Active` khi xong.
- [ ] D.4 Sửa số test trong `AGENTS.md` cho khớp thực tế.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/CheckHeal
dotnet build CheckHeal.sln -c Release
dotnet test  CheckHeal.sln -c Release
```

## 6. Điều kiện hoàn thành

- Mọi thao tác bật tắt đều truy vết được.
- Route thống nhất quy ước.
- Tài liệu phủ đủ endpoint.
- Build và test xanh.
