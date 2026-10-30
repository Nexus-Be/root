# 📜 ACTIVE APIS: LOG CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua REST Controller & Gateway cổng `8080` ngày 2026-10-30)  
> **Gateway Controller:** `Nexus.Gateway/Controllers/LogController.cs`  
> **Backend Service:** `Log.Api` (Cổng `8004`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`log_db`), Append-Only Log Store, OpenTelemetry Tracing

---

## 1. TRA CỨU NHẬT KÝ HỆ THỐNG (QUERY LOGS)

- **Endpoint Gateway:** `GET /api/v1/log/logs`
- **Quyền truy cập:** Quản trị viên (`[Authorize(GatewayPolicies.StaffOrAdmin)]`)
- **Forward downstream:** `GET http://log-service:8004/api/v1/log/logs`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |
| `serviceName` | Query | Không | Lọc theo tên dịch vụ sinh log |
| `logLevel` | Query | Không | Lọc theo mức độ log (INFO, WARN, ERROR) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be at least 1 and pageSize between 1 and 100." | Tham số phân trang không hợp lệ |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`LogService.cs`) query phân trang trên bảng `Logs`.
- [x] Thin Controller (`LogController.cs`) ghép cặp 1-to-1, route chính thức duy nhất `/api/v1/log/logs`.
- [x] Gateway routing & Seed fixture (`Seeds/log/logs.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. GHI NHẬN LOG THEO BATCH (BATCH LOG SINK)

- **Endpoint Microservice:** `POST /api/v1/log/batch`
- **Quyền truy cập:** Nội bộ microservices / Gateway
- **Đặc tính:** Append-Only, hỗ trợ ghi nhận hàng loạt log entries cùng lúc.

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`LogService.cs`) chèn batch trực tiếp vào `ILogDbContext`.
- [x] Thin Controller (`LogController.cs`) tiếp nhận payload mảng.
- [x] Trạng thái: `✅ COMPLETED`
