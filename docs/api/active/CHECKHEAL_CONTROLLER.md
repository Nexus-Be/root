# 🩺 ACTIVE APIS: CHECKHEAL & HEALTH PROBER CONTROLLERS

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua 20 unit/integration tests trên CheckHeal `8009` ngày 2026-10-30)  
> **Gateway Controller:** `Nexus.Gateway/Controllers/HealthProberController.cs`  
> **Backend Service:** `CheckHeal.Api` (Cổng `8009`)  
> **Hạ Tầng Liên Quan:** Database Keep-Alive Worker, Service Probers, In-Memory Health State Manager

---

## 1. TỔNG QUAN SỨC KHỎE HỆ THỐNG (HEALTH DASHBOARD)

- **Endpoint Gateway:** `GET /api/v1/healthcheck/status`
- **Endpoint Microservice:** `GET /api/v1/healthcheck/status`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)

### Response (200 OK)
```json
{
  "totalServices": 8,
  "healthyServices": 8,
  "totalDatabases": 8,
  "healthyDatabases": 8,
  "overallStatus": "Healthy",
  "checkedAt": "2026-10-30T06:00:00Z"
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Manager (`HealthStateManager.cs`) quản lý trạng thái in-memory.
- [x] Background Worker (`KeepAliveCronWorker.cs`) gửi probe định kỳ 60s.
- [x] Unit/Integration tests (20 tests) pass 100%.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. TRẠNG THÁI PROBE TỪNG MICROSERVICE (LIST SERVICES HEALTH)

- **Endpoint Gateway:** `GET /api/v1/healthcheck/services`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)

### Checklist Xác Nhận Hoàn Thành
- [x] Health Prober (`ServiceProber.cs`) gửi HTTP probe tới 8 service ports (`8001`-`8008`).
- [x] Thin Controller (`HealthCheckController.cs`) ghép cặp 1-to-1.
- [x] Trạng thái: `✅ COMPLETED`
