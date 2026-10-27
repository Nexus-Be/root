# HIỆN TRẠNG HỆ THỐNG (BẮT BUỘC ĐỌC TRƯỚC KHI CODE)

> Số liệu đo bằng `.tools/audit/audit.py` + đọc toàn bộ **511 file `.cs` / 20.612 dòng** của 9 repo (2026-10-24). Chi tiết: `docs/plans/SCORECARD.md`, `docs/plans/FIX_BACKLOG.md`, `docs/plans/audit/*_AUDIT.md`.

1. **Bề mặt dịch vụ**: 5/9 service (Auction, Catalog, Commerce, Fulfillment, Notification) không có gRPC server — chỉ `GET /health`. Ngoại lệ Catalog: ngoài `/health` còn 13 action REST mock (`Catalog.Api/Controllers/{Products,Categories,Inventory}Controller.cs`). Chỉ User/Log/Wallet có gRPC server thật.
2. **Hợp đồng**: 4 bản `shop.proto` / 3 hash; Gateway chỉ có 1 client (`users`). Không có nguồn sự thật duy nhất ⇒ cấm sửa `shop.proto` khi chưa chốt.
3. **Auth**: Gateway validate JWT nhưng không service nào phát JWT; `UsersApi/Login` chưa implement; 8 backend không có authentication và tin header `x-user-id`.
4. **Trace/Observability**: `x-trace-id` chỉ được set ở Gateway, 0 backend đọc; OTel package chỉ có ở Gateway/Log/Wallet.
5. **Event bus**: chỉ 1 đường publish còn sống (`User` → `SendOtpEmailIntegrationEvent`); 6/8 event trong `specs/04` không tồn tại trong code; Saga chưa triển khai.
6. **Test**: chỉ 3/9 repo có test project (Gateway 98 case, User 9 case, Notification 2 case). 6/9 repo 0 test.
7. **Bí mật**: JWT key thật trong `ApiGateway/Nexus.Gateway/appsettings.json:26`; credentials mặc định trong Infrastructure config.
8. **Hạ tầng local**: image Postgres dev cần lưu ý; `/health` không kiểm tra DB. Xem `docs/plans/SETUP_PHASE_PLAN.md`.

**Quy tắc:**
- Code nghiệp vụ mới CHỈ được bắt đầu sau khi hoàn tất Track S trong `docs/plans/SETUP_PHASE_PLAN.md`.
- Mọi tài liệu khi sửa phải có banner trạng thái theo `docs/plans/DOC_UPDATE_PROTOCOL.md`.
- Không được coi `/health` là bằng chứng “service hoạt động”.
