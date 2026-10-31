# Log Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service nhật ký tập trung, cổng 8004, DB `log_db` 5436. Có 5 endpoint, trong đó có 1 endpoint nạp log hàng loạt đang mở công khai.
Không có test, không có global query filter, chỉ 1 index.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Log.sln -c Release` | Pass, 0 warning, 0 error |
| Test | Không có project test |
| Endpoint hiện thực | 5 |
| Tài liệu `B_none` | 4 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 0 |
| `HasIndex` | 1 |
| Controller đọc log | `LogController` có `[RequireRole("admin", "staff")]` |
| Controller nạp log | `LogBatchController` không có attribute xác thực |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| LG-01 | HIGH | `POST /api/v1/logs/batch` không xác thực, cho phép bơm log giả vào kho nhật ký dùng để điều tra sự cố | `Log.Api/Controllers/Public/LogBatchController.cs:12-30` |
| LG-02 | HIGH | Không có test cho nghiệp vụ nạp log hàng loạt và truy vấn log | Không tồn tại `Log.Tests` |
| LG-03 | HIGH | Không có global query filter, log đã xóa mềm nếu có vẫn trả ra truy vấn | `Log.Infrastructure/`, 0 `HasQueryFilter` |
| LG-04 | MEDIUM | `LogBatchController` trả `202 Accepted` kèm object ẩn danh `{ success, message }`, lệch envelope của phần còn lại | `Log.Api/Controllers/Public/LogBatchController.cs:30` |
| LG-05 | MEDIUM | Chỉ 1 index cho bảng log, trong khi truy vấn lọc theo thời gian, service, mức log, mã tương quan | `rg HasIndex` trả 1 |
| LG-06 | LOW | Hai controller cùng tiền tố route `api/v1/logs`. Hợp lệ về routing nhưng dễ gây nhầm khi đọc code | `LogController`, `LogBatchController` |

## 4. Checklist thực thi

### Phase A. Đóng endpoint nạp log

- [ ] A.1 Thêm xác thực cho `POST /api/v1/logs/batch` theo quyết định chung ở `MASTER_PLAN.md` Phase 1.
- [ ] A.2 Nếu giữ tạm khóa, thêm giới hạn tần suất tại Gateway cho `/api/v1/logs/batch`.
- [ ] A.3 Validate payload: bắt buộc trường `serviceName`, `logLevel`, `message`, giới hạn kích thước lô.
- [ ] A.4 Test gọi ẩn danh trả 401.

### Phase B. Kiểu dữ liệu đầu vào

- [ ] B.1 Thay `[FromBody] object payload` bằng record có kiểu cụ thể.
- [ ] B.2 Trả `ApiResponse<T>` hoặc `202` không body theo quy ước envelope đã chốt.
- [ ] B.3 Test payload sai kiểu trả `VAL_INVALID_INPUT`.

### Phase C. Toàn vẹn dữ liệu

- [ ] C.1 Thêm `HasQueryFilter(x => !x.IsDeleted)` cho entity có `IsDeleted`.
- [ ] C.2 Thêm index cho `LogEntry.CreatedAt`, `LogEntry.ServiceName`, `LogEntry.LogLevel`, `LogEntry.CorrelationId`.
- [ ] C.3 Giữ nguyên tính chất chỉ ghi thêm: không có endpoint sửa hoặc xóa bản ghi log.
- [ ] C.4 Xác nhận `PUT event-types/{code}` chỉ sửa bảng cấu hình, không sửa bảng log.
- [ ] C.5 Tạo migration additive và kiểm tra snapshot.

### Phase D. Kiểm thử

- [ ] D.1 Tạo `Log.Tests`.
- [ ] D.2 Test nạp lô 100 bản ghi thành công.
- [ ] D.3 Test lọc log theo khoảng thời gian và mức log.
- [ ] D.4 Test phân trang biên.
- [ ] D.5 Test không tồn tại endpoint `PUT` hoặc `DELETE` trên `api/v1/logs/{id}`.

### Phase E. Tài liệu

- [ ] E.1 Bổ sung tài liệu cho `logs/batch` và `logs/event-types`.
- [ ] E.2 Ghi ma trận lỗi mới nếu có.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Log
dotnet build Log.sln -c Release
dotnet test  Log.sln -c Release
```

## 6. Điều kiện hoàn thành

- Không còn đường nạp log ẩn danh.
- Log chỉ được ghi thêm, có test chứng minh.
- Có index cho truy vấn chính.
- Build và test xanh.
