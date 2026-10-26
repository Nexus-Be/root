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

---

## 🔐 Cấu Hình GitHub Secrets & Tokens Cho CI/CD Pipeline

File GitHub Actions CI/CD đã được thiết lập tại `.github/workflows/ci-cd.yml` trong repo `CheckHealService`. Khi bạn push code lên GitHub, pipeline sẽ tự động chạy:
1. **Job 1 (Test)**: Chạy `dotnet test CheckHeal.sln` kiểm thử 100% test cases.
2. **Job 2 (Build & Push)**: Đóng gói Docker image đa kiến trúc (`linux/amd64`, `linux/arm64`) và push lên Docker Hub.
3. **Job 3 (Deploy VPS)**: Kết nối SSH vào VPS để kéo image mới và restart container (chỉ chạy trên nhánh `main` khi đã cấu hình VPS secrets).

### Hướng Dẫn Cài Đặt Secrets Trên GitHub:
Vào GitHub Repository: `https://github.com/Nexus-Be/CheckHealService` -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**:

| Tên Secret | Bắt Buộc | Mô Tả |
|:---|:---:|:---|
| `DOCKERHUB_USERNAME` (hoặc `DOCKER_HUB_USERNAME`) | **Có** | Username tài khoản Docker Hub của bạn (ví dụ: `yuikiri`). |
| `DOCKERHUB_TOKEN` (hoặc `DOCKER_HUB_TOKEN`) | **Có** | Personal Access Token (PAT) sinh từ Docker Hub (tại `hub.docker.com` -> Account Settings -> Personal Access Tokens -> Read & Write). |
| `VPS_HOST` | Tùy chọn | IP Public của VPS (ví dụ: `103.xxx.xxx.xxx`). |
| `VPS_USERNAME` | Tùy chọn | User SSH trên VPS (ví dụ: `root` hoặc `ubuntu`). |
| `VPS_PASSWORD` | Tùy chọn | **Mật khẩu SSH của VPS** (hỗ trợ triển khai nhanh qua User & Password). |
| `VPS_SSH_KEY` | Tùy chọn | (Tùy chọn thay thế nếu dùng SSH Key) Khóa Private Key SSH (`~/.ssh/id_rsa`). |
| `VPS_PORT` | Tùy chọn | Cổng SSH của VPS (mặc định: `22`). |
| `VPS_WORK_DIR` | Tùy chọn | Đường dẫn thư mục chứa code trên VPS (mặc định: `~/Nexus-Be`). |
| `RENDER_DEPLOY_HOOK_URL` | Tùy chọn | Webhook URL tự động kích hoạt deploy trên Render (nếu có dùng Render Web Service). |

> *Lưu ý:*
> - CI/CD hỗ trợ đăng nhập VPS bằng **Mật khẩu (`VPS_PASSWORD`)** hoặc **Khóa SSH (`VPS_SSH_KEY`)**. Bạn chỉ cần điền 1 trong 2 cách!
> - Nếu chưa cấu hình các biến `VPS_*`, pipeline vẫn chạy kiểm thử và push Docker Hub bình thường, bước Deploy VPS sẽ tự động được bỏ qua an toàn.

---

## 🔐 3. Bảo Mật Xác Thực API (API Key Authentication)

CheckHealService và ApiGateway sử dụng cơ chế xác thực **API Key** qua Header `X-Api-Key`:
- **Khóa bảo mật**: `j-E<34$h_R}K2[Q1&Yo:SbM6({I?6M88[23!nQ3bJinj@P5:u8?JRw3RKnMRm93E0Q*H1D=)]S#,=ZcEa+KmKC`
- **Tên biến môi trường (Docker / VPS)**: `CHECKHEAL_API_KEY`
- Khi gọi từ Swagger UI: Nhấn nút **Authorize** màu xanh lá ở góc phải, điền mã key và nhấn **Authorize**.
- Khi gọi qua curl / REST Client:
  ```bash
  curl -X GET "http://localhost:8009/api/v1/healthcheck/status" \
    -H "X-Api-Key: j-E<34$h_R}K2[Q1&Yo:SbM6({I?6M88[23!nQ3bJinj@P5:u8?JRw3RKnMRm93E0Q*H1D=)]S#,=ZcEa+KmKC"
  ```
- ApiGateway tự động gắn Header `X-Api-Key` khi chuyển tiếp gọi sang CheckHealService. Mọi yêu cầu gọi vào ApiGateway trên các endpoint prober/healthcheck cũng bắt buộc phải truyền mã bảo mật này.


