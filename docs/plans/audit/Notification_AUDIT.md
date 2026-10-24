# AUDIT — Notification (`src/Services/Notification`)

- **Branch:** `dev` · **Commit:** `4d8e46d` · **Dirty:** 5
- **Quy mô:** 53 file `.cs` / 1.324 LOC · Infrastructure 651 · Domain 346 · Api 146 · Application **104** · Tests 77 (2 `[Fact]`)
- **Port:** `8007` ✅ (**service duy nhất ngoài User để đúng port ngay profile mặc định**) · **DB:** `5439` `notification_db` ✅
- **Index:** 76 file / 455 symbol / 581 edge / **4 flow**

## 1. Kết luận nhanh

Notification là **nửa sau của đường ống duy nhất đang thật sự chạy được trong hệ thống**: `User.AuthService` publish `SendOtpEmailIntegrationEvent` (`User.Application/Services/Auth/AuthService.cs:147,253`) → `SendOtpEmailConsumer` (`Notification.Infrastructure/Consumers/SendOtpEmailConsumer.cs:9`) nhận và gửi email qua MailKit. Namespace 2 bên đều `Nexus.Contracts.Events`, record **giống hệt nhau** (Email, FullName, Otp, ExpiresInMinutes=5) → MassTransit `MessageUrn` khớp. Đây là **điểm sáng lớn nhất** của toàn hệ thống về event.

Nhưng phần còn lại chưa có:

- **0/4 rpc** (`GetPreferences, ListNotifications, MarkNotificationRead, UpdatePreferences`) → người dùng không xem được thông báo của mình.
- **Application layer 104 LOC** — gần như trống; gần như toàn bộ code nằm ở Infrastructure (651).
- **2 test** duy nhất (`EmailSenderTests`) cho toàn repo.
- **Không OTel** → không biết email nào gửi fail.

## 2. Ma trận 8 tiêu chí

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| C1 | Dễ dev, mỗi phần 1 việc | ⚠️ | Domain đủ entity (10 bảng), nhưng Application 104 LOC → mọi thứ dồn vào Infrastructure/Consumers/Services |
| C2 | Dễ sửa, ít phụ thuộc | ✅ | Consumer chỉ phụ thuộc `IEmailSenderService` (interface) |
| C3 | File đúng folder | ⚠️ | Event contract đặt `Application/Contracts/` (khác Wallet/Log đặt `Domain/Events/`) |
| C4 | Test/chạy độc lập | ⚠️ | Có 2 test cho email sender; **không** test consumer/queue |
| C5 | Theo dõi request | ❌ | không OTel; consumer dùng `context.MessageId` chứ không có trace id |
| C6 | Doc là sự thật | ⚠️ | `specs/02` 4 rpc / 0 impl; `specs/03` mô tả đúng 1 consumer hiện có |
| C7 | Luật đúng | ⚠️ | `nuget.config` riêng; còn lại OK |
| C8 | Format đồng nhất | ⚠️ | `Application/Contracts` + `Application/Common/Interfaces` (khác 6 repo còn lại) |

## 3. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| NO-01 | **P0** | 0/4 rpc → không có API đọc thông báo | `Notification.Api/Program.cs` chỉ `/health` | Thêm `NotificationGrpcService` với 4 rpc |
| NO-02 | **P1** | Consumer chỉ log “dispatched”, không lưu `NotificationRecord`/`NotificationDelivery` → không audit được email đã gửi | `SendOtpEmailConsumer.cs:31-40` chỉ `_logger` + `_emailSender` | Ghi `NotificationRecord` + `Delivery` status trong consumer |
| NO-03 | **P1** | Không retry/DLQ policy rõ ràng cho email | `Infrastructure/DependencyInjection.cs:33` chỉ `AddConsumer` | Cấu hình `UseMessageRetry` + `UseDelayedRedelivery` |
| NO-04 | **P1** | Không OTel | `Program.cs` | Thêm + tag `message_id` |
| NO-05 | **P2** | `EventLog`, `BrokerHealthCheck` có bảng nhưng không có code ghi (trừ health prober?) | 10 DbSet | Kiểm tra và ghi rõ luồng |
| NO-06 | **P2** | 2 test chỉ phủ `EmailSenderTests` | `Notification.Tests/EmailSenderTests.cs` | Thêm test consumer với `InMemoryTestHarness` của MassTransit |

## 4. Việc phải làm trước khi coi Notification “xong”

1. `NO-02` — nếu không lưu record, “thông báo” không có dữ liệu để trả cho `ListNotifications` (NO-01 phụ thuộc NO-02).
2. `NO-03` + `NO-06` — độ tin cậy và test.
3. `NO-01` — surface.
