# HƯỚNG DẪN CẤU HÌNH ENV VÀ TRIỂN KHAI CHECKHEAL SERVICE LÊN VPS

> **Tài liệu gốc tại service repo:** [`src/Services/CheckHeal/docs/VPS_ENV_CONFIG_GUIDE.md`](../src/Services/CheckHeal/docs/VPS_ENV_CONFIG_GUIDE.md)
> **Hướng dẫn kỹ thuật lập trình:** [`src/Services/CheckHeal/docs/DEV_GUIDE.md`](../src/Services/CheckHeal/docs/DEV_GUIDE.md)

---

## 📌 Tóm Tắt Nhanh Cho Triển Khai VPS

Dịch vụ `CheckHealService` chạy độc lập tại cổng `8009`, có nhiệm vụ chính:
1. Gửi query nhẹ `SELECT 1;` mỗi 60 giây tới các cơ sở dữ liệu PostgreSQL trên Neon Serverless / Render / Supabase để chống rơi vào trạng thái ngủ đông (Auto-Suspend / Hibernation).
2. Kiểm tra định kỳ HTTP GET `/health` tới 8 Microservices Backend của Nexus.
3. Cung cấp API bật/tắt linh hoạt cho từng Service / DB mà không cần khởi động lại container.

### Biến Môi Trường Tối Thiểu Cần Thiết Trên VPS:
- `ASPNETCORE_ENVIRONMENT=Production`
- `CHECKHEAL_SERVICE_PORT=8009`
- `CHECKHEAL_CRON_INTERVAL=60`
- `CHECKHEAL_DEFAULT_ENABLED=false` (Mặc định tắt, bạn có thể chỉnh tay hoặc bật qua API).
- `CheckHeal__Databases__{service}__ConnectionString`: Chuỗi kết nối PostgreSQL của dịch vụ cần giữ thức.

Xem chi tiết bảng biến môi trường và file mẫu `.env` đầy đủ tại:
👉 **[`src/Services/CheckHeal/docs/VPS_ENV_CONFIG_GUIDE.md`](../src/Services/CheckHeal/docs/VPS_ENV_CONFIG_GUIDE.md)**
