# Wallet Service. Kế hoạch kiểm tra

## 1. Tóm tắt

Service ví, cổng 8008, DB `wallet_db` 5440. Là service duy nhất dùng MediatR CQRS và đang được đóng băng kiến trúc.
Có 10 endpoint, 11 handler, 61 test xanh. Hai vấn đề chính là tài liệu kiến trúc lệch code và thiếu bảo vệ idempotency.

## 2. Bằng chứng đã xác minh

| Hạng mục | Kết quả |
|:---|:---|
| Build `Wallet.sln -c Release` | Pass, 0 warning, 0 error |
| Test | 61 pass, 0 fail |
| Endpoint hiện thực | 10 |
| Handler CQRS | 11 |
| Controller | 2 (`WalletsController`, `AdminWalletsController`) |
| `Controllers/Internal/` | Tồn tại nhưng rỗng |
| Script kiểm tra kiến trúc | In `OK: Wallet CQRS architecture is intact (11 handlers, 2 controllers, MediatR wired).` |
| Tài liệu `B_none` | 11 |
| Tài liệu `A_Active` | 0 |
| `HasQueryFilter` | 7 |
| `HasIndex` | 7 |
| `Idempotency-Key` | Có helper, không controller nào dùng |

## 3. Phát hiện

| ID | Mức | Mô tả | Bằng chứng |
|:---|:---|:---|:---|
| WA-01 | HIGH | `AGENTS.md` của service và root `AGENTS.md` yêu cầu đúng 3 controller gồm `Internal/InternalWalletsController`, nhưng code chỉ còn 2. Script kiểm tra đã được nới để chấp nhận 2 controller, nên không còn phát hiện được lệch này | `Wallet.Api/Controllers/Internal/` rỗng, `scripts/verify-wallet-architecture.sh` |
| WA-02 | HIGH | Không endpoint ghi tiền nào đọc `Idempotency-Key`. Retry mạng có thể trừ tiền hai lần ở `checkout/direct`, `topups`, `transfers`, `withdrawals` | Helper `GetIdempotencyKey` có ở `Wallet.Api/Extensions/HttpContextExtensions.cs:124`, không được gọi |
| WA-03 | MEDIUM | `WalletAccount.Status` là `string` với literal `"ACTIVE"`, lưu DB dạng varchar(30), trái quy định enum phải là int | `Wallet.Domain/Entities/WalletAccount.cs:13`, `WalletAccountConfiguration.cs:14` |
| WA-04 | MEDIUM | Guard kiến trúc bị nới để khớp code thay vì ép code khớp hợp đồng. Lần sau có thể mất tiếp một controller mà không ai biết | `scripts/verify-wallet-architecture.sh` |
| WA-05 | LOW | Thư mục rỗng `Wallet.Api/Controllers/Internal/` còn sót lại | `Wallet.Api/Controllers/Internal/` |

## 4. Checklist thực thi

### Phase A. Chốt sự thật kiến trúc

- [ ] A.1 Quyết định: khôi phục `InternalWalletsController` hay chính thức đổi hợp đồng thành 2 controller. Ghi ADR.
- [ ] A.2 Nếu chọn 2 controller, cập nhật đồng thời `Wallet/AGENTS.md`, root `AGENTS.md`, `.agents/AGENTS.md`, `.cursor/rules/`.
- [ ] A.3 Nếu chọn khôi phục, tạo lại controller và chuyển route `checkout/direct` về đó.
- [ ] A.4 Sửa script kiểm tra để đối chiếu số controller trong code với số ghi trong `AGENTS.md`, không chỉ đếm cứng.
- [ ] A.5 Xóa thư mục rỗng nếu không dùng.

### Phase B. Idempotency

- [ ] B.1 Thêm bảng lưu khóa idempotency gồm khóa, userId, endpoint, mã kết quả, thời điểm.
- [ ] B.2 Đọc header `Idempotency-Key` ở `checkout/direct`, `topups/vnpay`, `transfers`, `withdrawals`.
- [ ] B.3 Với khóa trùng, trả lại kết quả cũ thay vì xử lý lần hai.
- [ ] B.4 Với khóa trùng nhưng payload khác, trả `409 Conflict` với mã lỗi rõ ràng.
- [ ] B.5 Thêm index unique cho cột khóa.
- [ ] B.6 Test gọi hai lần cùng khóa chỉ sinh một giao dịch.

### Phase C. Enum hóa trạng thái ví

- [ ] C.1 Tạo `WalletStatus` enum kế thừa int, ví dụ `Active = 1`, `Locked = 2`, `Closed = 3`.
- [ ] C.2 Đổi `WalletAccount.Status` sang enum.
- [ ] C.3 Tạo migration additive, có bước chuyển dữ liệu từ chuỗi sang số cho dữ liệu cũ.
- [ ] C.4 Xác nhận API trả `"Active"` dạng PascalCase, không trả số.
- [ ] C.5 Test converter cho giá trị hợp lệ và không hợp lệ.

### Phase D. Kiểm thử

- [ ] D.1 Giữ 61 test hiện có xanh.
- [ ] D.2 Test số dư không thể âm ở mọi đường trừ tiền.
- [ ] D.3 Test chuyển tiền cho chính mình trả lỗi nghiệp vụ.
- [ ] D.4 Test rút tiền vượt số dư khả dụng trả `INSUFFICIENT_BALANCE`.
- [ ] D.5 Test admin duyệt và từ chối yêu cầu rút tiền có ghi audit log.

### Phase E. Tài liệu

- [ ] E.1 Chuyển 11 tài liệu `B_none` sang `A_Active` sau khi test xanh.
- [ ] E.2 Cập nhật tài liệu route `checkout/direct` theo vị trí controller cuối cùng.

## 5. Lệnh kiểm chứng

```bash
cd src/Services/Wallet
./scripts/verify-wallet-architecture.sh
dotnet build Wallet.sln -c Release
dotnet test  Wallet.sln -c Release
```

## 6. Điều kiện hoàn thành

- Script kiểm tra kiến trúc phát hiện được lệch giữa tài liệu và code.
- Mọi đường trừ tiền có bảo vệ idempotency.
- Trạng thái ví là enum int trong DB, PascalCase ở API.
- Build, test và script đều xanh.
