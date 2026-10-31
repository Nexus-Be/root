# Nexus-Be Audit Workspace

Thư mục này chứa kế hoạch kiểm tra (audit plan) cho toàn bộ 10 service trong `src/Services`.
Đây là tài liệu chỉ đọc. Không có mã nguồn nào bị sửa trong quá trình lập kế hoạch.

## Cách dùng

1. Đọc `MASTER_PLAN.md` để nắm thứ tự thực thi và ma trận ưu tiên.
2. Đọc `EVIDENCE.md` để biết bằng chứng gốc (build, test, phép đếm, lệnh đã chạy).
3. Mở `test/{Service}/PLAN.md` để làm theo checklist của từng service.

## Cấu trúc

```text
test/
  README.md            file này
  MASTER_PLAN.md       kế hoạch tổng, thứ tự, phụ thuộc giữa các service
  EVIDENCE.md          bằng chứng build/test/tĩnh kèm lệnh tái lập
  Auction/PLAN.md
  Catalog/PLAN.md
  CheckHeal/PLAN.md
  Commerce/PLAN.md
  Fulfillment/PLAN.md
  Gateway/PLAN.md
  Log/PLAN.md
  Notification/PLAN.md
  User/PLAN.md
  Wallet/PLAN.md
```

## Thang mức độ

| Mức | Ý nghĩa | Thời hạn đề xuất |
|:---|:---|:---|
| CRITICAL | Lỗ hổng bảo mật đang mở ra Internet, hoặc vi phạm bất biến kiến trúc đóng băng | Chặn release, sửa trước mọi việc khác |
| HIGH | Sai logic nghiệp vụ, thiếu test, rò rỉ dữ liệu đã xóa mềm, thiếu endpoint đã cam kết | Trong sprint hiện tại |
| MEDIUM | Lệch chuẩn dữ liệu, lệch envelope, thiếu index, tài liệu chưa nghiệm thu | Trong 2 sprint |
| LOW | Văn bản tài liệu lệch code, dead code, đặt tên route chưa chuẩn | Khi chạm vào file đó |

## Trạng thái bằng chứng

- `dotnet build` 10/10 solution: PASS, 0 warning, 0 error.
- `dotnet test` 5/5 project có test: PASS, 390 test.
- Không có service nào bị sửa code. Chỉ tạo tài liệu trong `test/`.
