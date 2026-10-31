# Notification Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service thông báo và email, cổng 8007, DB `notification_db` 5439. Có 15 test đang xanh.
Rủi ro lớn nhất là hai endpoint gửi email đang mở công khai, cho phép lạm dụng SMTP.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Notification.sln -c Release` | Pass, 0 warning, 0 error |
| Test | 15 pass, 0 fail |
| Endpoint hiện thực | 10 |
| Tài liệu `B_none` | 11 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 0 |
| `HasIndex` | 3 |
| `EmailController` | Không có `RequireRole`, không có `Authorize`, không có `AllowAnonymous` |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| NO-01 | CRITICAL | `POST /api/v1/notifications/email/otp` và `POST /api/v1/notifications/email/send` không xác thực. Gateway định tuyến `/api/v1/notifications/{**catch-all}` sang service, nên bất kỳ ai cũng gửi email từ hệ thống | `Notification.Api/Controllers/Public/EmailController.cs:11-13`, `Gateway/appsettings.json` |
| NO-02 | HIGH | Không có global query filter, thông báo đã xóa mềm vẫn trả ra danh sách của người dùng | 0 `HasQueryFilter` trong `Notification.Infrastructure` |
| NO-03 | MEDIUM | `EmailController` trả object ẩn danh `{ errorCode, message }` thay vì envelope hoặc `ProblemDetails` chuẩn | `Notification.Api/Controllers/Public/EmailController.cs:36-49`, `:103-121` |
| NO-04 | MEDIUM | `ExpiresInMinutes` do client gửi, mặc định 5. Cần chặn giá trị quá lớn để tránh OTP sống quá lâu | `Notification.Api/Controllers/Public/EmailController.cs:57` |
| NO-05 | LOW | 11 tài liệu `B_none` cho 10 endpoint, chưa đối chiếu 1 1 | `docs/api/B_none/Notification/` |

## 4. Checklist thực thi

### Phase A. Đóng lỗ hổng gửi email

- [ ] A.1 Quyết định hướng bảo vệ: bật lại khóa nội bộ cho 2 route email, hoặc yêu cầu xác thực service.
- [ ] A.2 Cập nhật `ClientContextMiddleware` nếu cần chặn lại path nội bộ, và ghi rõ trong `specs`.
- [ ] A.3 Cập nhật `User.Infrastructure/Services/Notification/EmailNotificationClient.cs` cho khớp route và header mới.
- [ ] A.4 Thêm giới hạn tần suất tại Gateway cho nhóm route email.
- [ ] A.5 Test gọi ẩn danh trả 401 hoặc 403.
- [ ] A.6 Test gửi OTP với email sai định dạng trả `VAL_INVALID_EMAIL`.

### Phase B. Chuẩn hóa phản hồi

- [ ] B.1 Thay object ẩn danh bằng envelope hoặc `ProblemDetails` theo quy ước đã chốt.
- [ ] B.2 Chặn `ExpiresInMinutes` trong khoảng 1 đến 15.
- [ ] B.3 Giữ thông báo lỗi tiếng Anh, câu bắt đầu bằng chữ hoa.

### Phase C. Toàn vẹn dữ liệu

- [ ] C.1 Thêm `HasQueryFilter(x => !x.IsDeleted)` cho entity thông báo.
- [ ] C.2 Thêm index cho `Notification.UserId`, `Notification.IsRead`, `Notification.CreatedAt`.
- [ ] C.3 Kiểm tra mẫu email seed đang ở `vi-VN`, ghi rõ đây là dữ liệu mẫu, không phải thông báo lỗi.
- [ ] C.4 Tạo migration additive và kiểm tra snapshot.

### Phase D. Kiểm thử

- [ ] D.1 Giữ 15 test hiện có xanh.
- [ ] D.2 Test người dùng A không đọc được thông báo của người dùng B.
- [ ] D.3 Test phân trang và lọc thông báo chưa đọc.
- [ ] D.4 Test gửi email khi cấu hình SMTP thiếu trả lỗi rõ ràng `EMAIL_SEND_FAILED`.

### Phase E. Tài liệu

- [ ] E.1 Đối chiếu 11 tài liệu với 10 endpoint, xử lý file dư hoặc thiếu.
- [ ] E.2 Chuyển tài liệu đã xong sang `A_Active`.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Notification
dotnet build Notification.sln -c Release
dotnet test  Notification.sln -c Release
```

## 6. Điều kiện hoàn thành

- Không thể gửi email từ bên ngoài mà không có quyền.
- Phản hồi lỗi cùng một hình dạng trên toàn service.
- Build và test xanh.
