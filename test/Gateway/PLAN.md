# Gateway Service. Kế hoạch kiểm tra

## 1. Tóm tắt

YARP reverse proxy tại cổng 8080, không có DB, không có controller. Có 58 test xanh.
Vấn đề chính là không có tài liệu API nào và tài liệu Swagger gộp vẫn phơi các path nội bộ đã ngừng dùng.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Gateway.sln -c Release` | Pass, 0 warning, 0 error |
| Test | 58 pass, 0 fail |
| Route YARP khai báo | 23 route, không có route `/api/v1/internal` |
| Tài liệu `B_none` | 0 |
| Tài liệu `A_Active` | 0 |
| Chặn header giả mạo | Có, trả 403 `FORBIDDEN_HEADER_SPOOFING` |
| Chặn path internal | Đang comment, test xác nhận path đi qua |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| GW-01 | MEDIUM | Không có tài liệu API cho Gateway, không có mô tả bảng route, RBAC tại biên, mã lỗi biên | `docs/api/B_none/Gateway/` rỗng |
| GW-02 | MEDIUM | Tài liệu Swagger gộp vẫn chứa path `/api/v1/internal/wallets/checkout/direct` và các path nội bộ khác, trong khi không còn route tương ứng. Frontend đọc sẽ hiểu sai hợp đồng | `Gateway.Tests/SwaggerAggregationTests.cs:19`, `:66` |
| GW-03 | LOW | Khối chặn path internal bị comment trong `ClientContextMiddleware`, để lại code chết | `Gateway/Middlewares/Global/ClientContextMiddleware.cs:88-107` |
| GW-04 | LOW | `InternalOperationFilter` cho Swagger vẫn tồn tại sau khi tắt mô hình internal | `Gateway/Extensions/SwaggerExtensions.cs:228` |

## 4. Checklist thực thi

### Phase A. Tài liệu Gateway

- [ ] A.1 Tạo `docs/api/B_none/Gateway/` với một file mô tả toàn bộ bảng route.
- [ ] A.2 Ghi rõ route nào yêu cầu JWT, route nào ẩn danh.
- [ ] A.3 Ghi mã lỗi biên: `FORBIDDEN_HEADER_SPOOFING`, `RATE_LIMIT_EXCEEDED`, `SERVICE_UNAVAILABLE`, `WAITING_RESPONSE`.
- [ ] A.4 Ghi hành vi identity propagation: header nào được tiêm, header nào bị chặn.

### Phase B. Swagger gộp

- [ ] B.1 Bật lại filter loại bỏ path `/api/v1/internal` khỏi tài liệu gộp.
- [ ] B.2 Cập nhật `SwaggerAggregationTests` để khẳng định path nội bộ không còn xuất hiện.
- [ ] B.3 Kiểm tra tài liệu gộp khớp danh sách 23 route thật.

### Phase C. Dọn dead code

- [ ] C.1 Quyết định giữ khối chặn internal để bật lại sau hay xóa hẳn.
- [ ] C.2 Nếu giữ, chuyển thành cấu hình bật tắt thay vì comment.
- [ ] C.3 Xóa `InternalOperationFilter` nếu đã bỏ hẳn mô hình internal.
- [ ] C.4 Ghi quyết định vào ADR.

### Phase D. Kiểm thử

- [ ] D.1 Giữ 58 test xanh.
- [ ] D.2 Bổ sung test khẳng định mọi route trong `appsettings.json` đều có upstream hợp lệ.
- [ ] D.3 Bổ sung test khẳng định không route nào trỏ tới `/internal`.
- [ ] D.4 Test giới hạn tần suất trên nhóm route auth và OTP.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Gateway
dotnet build Gateway.sln -c Release
dotnet test  Gateway.sln -c Release
```

## 6. Điều kiện hoàn thành

- Bảng route có tài liệu và khớp `appsettings.json`.
- Swagger gộp không còn path chết.
- Không còn code chết dạng comment.
- Build và test xanh.
