# Kế hoạch kiểm tra tổng thể toàn hệ thống

## 1. Mục tiêu

Lập một kế hoạch kiểm tra dài hơi cho toàn bộ 10 service trong `src/Services`, ghi lại toàn bộ lỗi phát hiện được ở thời điểm 2026-10-31, và chia nhỏ thành checklist thực thi được cho từng service trong thư mục `test/{Service}/PLAN.md`.

Kế hoạch này không sửa mã nguồn. Mọi hạng mục là việc cần làm ở các phiên sau.

## 2. Phạm vi

Trong phạm vi:

- 10 solution: Auction, Catalog, CheckHeal, Commerce, Fulfillment, Gateway, Log, Notification, User, Wallet.
- 4 tầng Clean Architecture của mỗi service.
- Hợp đồng REST, RBAC, envelope, phân trang, mã lỗi.
- Tầng dữ liệu: enum, index, xóa mềm, precision, migration.
- Kiểm thử tự động và tài liệu API hai trạng thái.

Ngoài phạm vi:

- Hạ tầng thật (Neon, Render, VPS), Prometheus, Grafana, Tempo.
- Frontend.
- Thay đổi `.env` hoặc secret.

## 3. Kết quả nền đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build 10 solution Release | 10/10 pass, 0 warning, 0 error |
| Test 5 project có test | 390/390 pass |
| Endpoint hiện thực | 79 |
| Tài liệu API `B_none` | 156 |
| Tài liệu API `A_Active` | 10 (toàn bộ là auth của User) |
| Service không có test | Auction, Catalog, Commerce, Fulfillment, Log |

Chi tiết và lệnh tái lập ở `EVIDENCE.md`.

## 4. Ma trận phát hiện toàn hệ thống

| ID | Mức | Phát hiện | Bằng chứng |
|:---|:---|:---|:---|
| G-01 | CRITICAL | `POST /api/v1/notifications/email/otp` và `POST /api/v1/notifications/email/send` không có xác thực, đi qua Gateway catch-all nên gọi được từ Internet | `Notification.Api/Controllers/Public/EmailController.cs:11-13`, `Gateway/appsettings.json` route `/api/v1/notifications/{**catch-all}` |
| G-02 | HIGH | `POST /api/v1/inventories/initialize` và `GET /api/v1/inventories/{skuId}` không có xác thực | `Fulfillment.Api/Controllers/Public/InventoriesController.cs:10-37` |
| G-03 | HIGH | `POST /api/v1/logs/batch` không có xác thực, cho phép chèn log tùy ý | `Log.Api/Controllers/Public/LogBatchController.cs:12-30` |
| G-04 | HIGH | Wallet chỉ còn 2 controller trong khi `AGENTS.md` đóng băng yêu cầu 3 controller, và script kiểm tra đã được nới thành 2 | `Wallet.Api/Controllers/Internal/` rỗng, `scripts/verify-wallet-architecture.sh` in `2 controllers` |
| G-05 | HIGH | `Idempotency-Key` có helper ở 8 service nhưng không controller nào sử dụng | `rg "GetIdempotencyKey()"` trong `*Api/Controllers` trả 0 |
| G-06 | HIGH | 5 service không có project test | Không tồn tại `*Tests` cho Auction, Catalog, Commerce, Fulfillment, Log |
| G-07 | HIGH | 5 service không có global query filter cho xóa mềm, bản ghi `IsDeleted = true` vẫn trả ra API | `rg HasQueryFilter` chỉ thấy ở Commerce, User, Wallet |
| G-08 | MEDIUM | `WalletAccount.Status` là `string` với literal `"ACTIVE"` thay vì enum int | `Wallet.Domain/Entities/WalletAccount.cs:13` |
| G-09 | MEDIUM | 156 tài liệu `B_none` nhưng chỉ 10 tài liệu `A_Active`; 9/10 service chưa có API nào được nghiệm thu | `docs/api/B_none`, `docs/api/A_Active` |
| G-10 | MEDIUM | 79 endpoint hiện thực so với 156 tài liệu, khoảng một nửa hợp đồng đã ghi chưa có code | `EVIDENCE.md` mục 3 |
| G-11 | MEDIUM | Index rất mỏng ở Auction (1), Catalog (1), Log (1) trong khi có hàng chục entity | `rg HasIndex --glob '*Configuration.cs'` |
| G-12 | MEDIUM | Envelope không nhất quán: service trả DTO thô, Gateway mới bọc `ApiResponse`; riêng `LogBatchController` trả `202` kèm object ẩn danh | `Log.Api/Controllers/Public/LogBatchController.cs:30` |
| G-13 | LOW | Dead code do tạm khóa Internal API: middleware ở 9 service, filter Swagger ở 8 service, khối comment ở Gateway | `ClientContextMiddleware.cs:88-107`, `SwaggerExtensions.cs:228` |
| G-14 | LOW | Số liệu trong `AGENTS.md` lệch code: CheckHeal 17 so với 23 test, Wallet 3 so với 2 controller | `CheckHeal/AGENTS.md`, `Wallet/AGENTS.md` |
| G-15 | LOW | Route `/api/v1/healthcheck` dùng số ít, lệch quy ước số nhiều | `CheckHeal.Api/Controllers/Public/HealthCheckController.cs:12` |

## 5. Thứ tự thực thi

Thứ tự dưới đây có phụ thuộc thật, không phải thứ tự hình thức.

### Phase 0. Chốt baseline

- [ ] 0.1 Chạy lại `dotnet build` 10 solution, lưu log vào `test/.logs/`.
- [ ] 0.2 Chạy lại `dotnet test` 5 project, lưu log.
- [ ] 0.3 Ghi lại số endpoint và số tài liệu để so sánh sau khi sửa.
- [ ] 0.4 Chụp `git status` để biết working tree trước khi bắt đầu.

Điều kiện ra: baseline trùng với `EVIDENCE.md`. Nếu lệch, cập nhật `EVIDENCE.md` trước.

### Phase 1. Đóng lỗ hổng bảo mật đang mở

- [ ] 1.1 Chốt lại quyết định về Internal API: giữ tạm khóa hay mở lại có xác thực. Ghi quyết định vào `docs/adr/`.
- [ ] 1.2 Notification: chặn `email/otp` và `email/send` theo một trong hai hướng (xác thực nội bộ, hoặc chỉ cho phép qua route không public).
- [ ] 1.3 Fulfillment: chặn `inventories/initialize`, giới hạn `inventories/{skuId}` theo quyền seller sở hữu.
- [ ] 1.4 Log: chặn `logs/batch`.
- [ ] 1.5 Rà lại 10 controller không có attribute xác thực, phân loại public có chủ đích và public do thiếu sót.
- [ ] 1.6 Viết test hồi quy cho từng route vừa chặn, khẳng định trả 401 hoặc 403.

Điều kiện ra: không còn route ghi dữ liệu nào gọi được mà không xác thực, trừ danh sách public đã được ghi trong ADR.

### Phase 2. Đưa kiến trúc và hợp đồng về đúng

- [ ] 2.1 Quyết định dứt điểm Wallet dùng 2 hay 3 controller, cập nhật đồng thời code, `Wallet/AGENTS.md`, root `AGENTS.md`, và script kiểm tra.
- [ ] 2.2 Triển khai `Idempotency-Key` cho các thao tác ghi tiền và ghi kho.
- [ ] 2.3 Chốt quy ước envelope: service trả `ApiResponse<T>` hay Gateway bọc, ghi vào `specs/04_SHARED_CONTRACTS_REGISTRY.md`.
- [ ] 2.4 Sửa `LogBatchController` cho khớp envelope đã chốt.

Điều kiện ra: root `AGENTS.md`, `AGENTS.md` của service, script kiểm tra và code nói cùng một sự thật.

### Phase 3. Toàn vẹn dữ liệu

- [ ] 3.1 Bổ sung global query filter cho Auction, Catalog, Fulfillment, Log, Notification.
- [ ] 3.2 Thay `WalletAccount.Status` bằng enum int, kèm migration additive.
- [ ] 3.3 Bổ sung index cho khóa ngoại và trường tìm kiếm ở Auction, Catalog, Log.
- [ ] 3.4 Rà `DeleteBehavior.Cascade` ở User, chuyển sang `Restrict` hoặc `SetNull` nếu không có chủ đích.
- [ ] 3.5 Kiểm tra `ModelSnapshot` khớp schema sau mọi thay đổi.

Điều kiện ra: xóa mềm không rò rỉ, enum lưu int, index phủ khóa ngoại chính, không có cascade ngoài chủ đích.

### Phase 4. Kiểm thử

- [ ] 4.1 Tạo project test cho Auction, Catalog, Commerce, Fulfillment, Log.
- [ ] 4.2 Mỗi service tối thiểu phủ: phân quyền, validation, happy path, lỗi nghiệp vụ chính.
- [ ] 4.3 Bổ sung test hồi quy cho mọi lỗi đã sửa ở Phase 1 đến Phase 3.
- [ ] 4.4 Giữ tổng test chạy dưới 60 giây.

Điều kiện ra: 10/10 solution có test và `dotnet test` xanh toàn bộ.

### Phase 5. Hoàn thiện API và tài liệu

- [ ] 5.1 Đối chiếu 156 tài liệu `B_none` với 79 endpoint, lập danh sách chênh lệch.
- [ ] 5.2 Với mỗi endpoint đã có code và test xanh, chuyển tài liệu sang `A_Active`.
- [ ] 5.3 Với mỗi tài liệu chưa có code, đánh dấu `NOT_IMPLEMENTED` thay vì để trạng thái mơ hồ.
- [ ] 5.4 Bổ sung tài liệu cho Gateway, hiện đang 0 file.

Điều kiện ra: mỗi endpoint có đúng một tài liệu, trạng thái rõ ràng, không có tài liệu treo.

### Phase 6. Dọn dẹp

- [ ] 6.1 Xóa `InternalServiceAuthMiddleware` không dùng hoặc ghi rõ trong ADR là đang chờ bật lại.
- [ ] 6.2 Xóa `InternalOperationFilter` và khối comment ở Gateway nếu quyết định là bỏ hẳn.
- [ ] 6.3 Xóa thư mục rỗng `Wallet.Api/Controllers/Internal/`.
- [ ] 6.4 Đồng bộ số liệu test và số controller trong các `AGENTS.md`.
- [ ] 6.5 Cân nhắc đổi `/api/v1/healthcheck` thành `/api/v1/healthchecks` hoặc `/api/v1/health`.

## 6. Bảng theo dõi tiến độ

| Service | CRITICAL | HIGH | MEDIUM | LOW | File |
|:---|:---:|:---:|:---:|:---:|:---|
| Auction | 0 | 3 | 1 | 0 | `Auction/PLAN.md` |
| Catalog | 0 | 2 | 2 | 0 | `Catalog/PLAN.md` |
| CheckHeal | 0 | 0 | 2 | 3 | `CheckHeal/PLAN.md` |
| Commerce | 0 | 2 | 2 | 1 | `Commerce/PLAN.md` |
| Fulfillment | 0 | 3 | 1 | 0 | `Fulfillment/PLAN.md` |
| Gateway | 0 | 0 | 2 | 2 | `Gateway/PLAN.md` |
| Log | 0 | 3 | 1 | 1 | `Log/PLAN.md` |
| Notification | 1 | 1 | 2 | 0 | `Notification/PLAN.md` |
| User | 0 | 0 | 3 | 2 | `User/PLAN.md` |
| Wallet | 0 | 2 | 2 | 1 | `Wallet/PLAN.md` |

## 7. Quy ước đóng task

Một mục chỉ được đánh dấu xong khi có đủ ba thứ:

1. Thay đổi đã vào code hoặc tài liệu, có đường dẫn cụ thể.
2. Có test hoặc lệnh chứng minh hành vi mới.
3. `dotnet build` và `dotnet test` của service đó xanh.
