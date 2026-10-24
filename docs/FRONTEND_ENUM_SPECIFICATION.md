# BẢN ĐẶC TẢ DANH MỤC ENTITY & ENUM CHUẨN FORM CHO FRONTEND (FE INTEGRATION SPECIFICATION)

> **Trạng thái triển khai (2026-10-24):** ⚠️ Một phần — 78 Enums khớp code (`public enum` trong `*.Domain`); số Entity thực tế là **86 class** trong `*/Domain/Entities` và **87 bảng** trong `dbml/service/*.dbml` (trước đây ghi “88”). Nhiều entity đang **chưa có writer** (ví dụ Fulfillment ghi 0 bảng, Notification 5/10 entity không được dùng).
> **Nguồn sự thật:** code (`*.Domain/Entities`) + `dbml/service/*.dbml`.
> **Cập nhật lần cuối:** 2026-10-24.

> Tài liệu này được đồng bộ và cập nhật từ [FRONTEND_ENTITY_AND_ENUM_CATALOG.md](./FRONTEND_ENTITY_AND_ENUM_CATALOG.md).
> 
> Bao gồm đầy đủ 2 phần:
> 1. **Phần I: Bản Đặc Tả Danh Mục 78 Enums Chuẩn PascalCase** (Được Gateway chuyển đổi hai chiều tự động cho Frontend).
> 2. **Phần II: Bản Đặc Tả Chi Tiết 86 Entity Class Thuộc 8 Microservices** (87 bảng trong `dbml/service/*.dbml`) (Chi tiết các trường dữ liệu, kiểu JSON, ràng buộc nghiệp vụ).
> 
> Vui lòng tham khảo tài liệu chính: **[FRONTEND_ENTITY_AND_ENUM_CATALOG.md](./FRONTEND_ENTITY_AND_ENUM_CATALOG.md)**.
