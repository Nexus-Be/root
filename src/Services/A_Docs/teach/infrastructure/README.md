# Giao Trinh Kien Truc Ha Tang Ho Tro & Observability (Shared Infrastructure & Observability Blueprint)

Thu muc nay chua bo tai lieu giang day va tham chieu kien truc chuyen sau ve **Ha Tang Dung Chung (Shared Infrastructure)** va **He Thong Quan Sat Phan Tan (Distributed Observability)** trong he sinh thai microservices Nexus.

Kien truc ha tang duoc thiet ke theo nguyen ly **Single Shared Infrastructure (Ha Tang Tap Trung Duy Nhat)** duoc khai bao doc quyen tai `docker-compose.infra.yml` o thu muc goc, phuc vu dong thoi cho API Gateway va toan bo 9 microservices backend.

---

## 1. Bang Phan Bo Cong Mang Ha Tang Dung Chung (Shared Ports Catalog)

| Thanh Phan | Cong Mang (Host) | Protocol / Muc Dich | Container Name | Thong So Tai Nguyen |
|:---|:---:|:---|:---|:---|
| **Redis 7** | `6379` | TCP / Rate Limiting, OTP, Temporary Cache | `nexus-shared-redis` | RAM Limit: 500MB (`allkeys-lru`) |
| **Tempo (gRPC)** | `4317` | OTLP gRPC / Nhan Trace Spans tu .NET OTel | `nexus-shared-tempo` | v2.4.1, WAL + Compaction 48h |
| **Tempo (HTTP)** | `4318` | OTLP HTTP / Nhan Trace Spans du phong | `nexus-shared-tempo` | v2.4.1 |
| **Tempo (UI/API)** | `3200` | HTTP / Truy van Traces noi bo | `nexus-shared-tempo` | Grafana Tempo Query Engine |
| **Prometheus** | `9090` | HTTP / Time-Series DB, Remote-Write & Exemplars | `nexus-shared-prometheus` | v2.51.0, TSDB 15s scrape |
| **Grafana** | `3000` | HTTP / Dashboard truc quan hoa tong hop | `nexus-shared-grafana` | v10.4.2, Dark Theme, Auto-Provisioning |
| **Local PostgreSQL** | `5433` - `5440` | TCP / Cum 8 CSDL Postgres phuc vu offline dev | `nexus-postgres-*` | v16 Alpine, moi DB 1 container rieng |

---

## 2. Muc Luc Cac Chuyen De Kien Truc Ha Tang

Bo tai lieu duoc chia thanh 7 chuyen de doc lap:

| STT | Chuyen De | File Tai Lieu | Noi Dung Trong Tam |
|:---:|:---|:---|:---|
| 00 | **Tong Quan Ha Tang & Mang Dung Chung** | [`00_OVERVIEW_AND_INFRA_TOPOLOGY.md`](00_OVERVIEW_AND_INFRA_TOPOLOGY.md) | Kien truc Single Shared Infra, mang ngoai `nexus-network`, quan tri tai nguyen RAM/CPU, chien luoc Hybrid Cloud. |
| 01 | **OpenTelemetry & Distributed Tracing** | [`01_OPENTELEMETRY_AND_DISTRIBUTED_TRACING.md`](01_OPENTELEMETRY_AND_DISTRIBUTED_TRACING.md) | Chuan OTLP trong .NET 8, `AddServiceObservability`, W3C `traceparent`, co che loc nhieu `/health` va `/swagger`. |
| 02 | **Grafana Tempo - Distributed Tracing Backend** | [`02_TEMPO_DISTRIBUTED_TRACING_BACKEND.md`](02_TEMPO_DISTRIBUTED_TRACING_BACKEND.md) | Luu tru trace dang block khong can Elasticsearch, `metrics_generator`, tu dong sinh RED metrics sang Prometheus. |
| 03 | **Prometheus - Thu Thap Chi So & Exemplars** | [`03_PROMETHEUS_METRICS_AND_EXEMPLARS.md`](03_PROMETHEUS_METRICS_AND_EXEMPLARS.md) | TSDB luu tru metrics, remote-write receiver, khai niem Exemplar ket noi truc tiep tu bieu do do tre sang TraceId. |
| 04 | **Grafana - Dashboard Quan Sat Tap Trung** | [`04_GRAFANA_UNIFIED_OBSERVABILITY_DASHBOARDS.md`](04_GRAFANA_UNIFIED_OBSERVABILITY_DASHBOARDS.md) | Auto-provisioning datasources & dashboards qua YAML, dashboard `nexus_overview.json`, Service Dependency Graph. |
| 05 | **Redis 7 - Ha Tang Cache & Rate Limiting** | [`05_REDIS_SHARED_INFRASTRUCTURE.md`](05_REDIS_SHARED_INFRASTRUCTURE.md) | Gioi han 500MB voi chinh sach `allkeys-lru`, phan vung Key Prefix an toan, mau thiet ke In-Memory Fallback. |
| 06 | **Cum Co So Du Lieu Cuc Bo & Hybrid Cloud** | [`06_LOCAL_DATABASE_CLUSTER_AND_HYBRID_CLOUD.md`](06_LOCAL_DATABASE_CLUSTER_AND_HYBRID_CLOUD.md) | Cum 8 CSDL Postgres (ports 5433-5440) cho offline mode, kiem tra suc khoe `pg_isready`, doi soat voi Neon Cloud. |

---

## 3. So Do Luong Hoat Dong Cua He Thong Observability

```text
[ .NET Microservices & API Gateway ]
        │
        ├── 1. Sinh Spans qua OpenTelemetry .NET SDK
        │      (Tự động inject W3C traceparent vào outgoing HTTP requests)
        │
        ├── 2. Bắn Spans qua OTLP gRPC tới Tempo (Port 4317)
        │      ▼
        │   [ Grafana Tempo (Port 3200) ]
        │      │ - Lưu trữ trace blocks vào ổ cứng cục bộ (WAL + Compaction)
        │      │ - Metrics Generator tự động phân tích Spans thành RED Metrics (Rate, Error, Duration)
        │      ▼
        │   [ Prometheus (Port 9090) ] (Nhận Remote-Write từ Tempo)
        │      │ - Lưu trữ Time-Series Metrics
        │      │ - Gắn Exemplars (TraceId gắn liền với các điểm spike độ trễ)
        │      ▼
        └── [ Grafana Dashboard (Port 3000) ]
               │ - Đồ thị Metrics tổng quan (Throughput, Error Rate, p95 Latency)
               │ - Sơ đồ phụ thuộc dịch vụ tự động (Service Dependency Graph)
               │ - Click trực tiếp từ điểm lỗi trên biểu đồ để mở ngay Flame Graph trong Tempo
```

---

## 4. Nguyen Tac Bat Bien: Cam Khai Bao Ha Tang Rieng Le Tai Submodules

He thong quy dinh bat bien:
1. **Cam khai bao Redis hoac Tempo rieng le:** Moi submodule microservice (`src/Services/{Service}/`) tuyet doi khong duoc phep tao container Redis hoac Tempo rieng biet ben trong file `docker-compose.yml` cua chinh service do.
2. **Khai bao tap trung:** Toan bo ha tang ho tro chung chi duoc khai bao tai file goc `docker-compose.infra.yml`.
3. **Phat trien doc lap:** Khi lap trinh vien chay service truc tiep tu Visual Studio, Rider hoac `dotnet run`, chi can go mot lenh duy nhat:
   ```bash
   docker compose -f docker-compose.infra.yml up -d
   ```
   Toan bo he sinh thai tro tro (Redis, Tempo, Prometheus, Grafana) se san sang phuc vu toan bo cac dich vu.
