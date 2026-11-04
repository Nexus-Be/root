# Chuyen De 04: Grafana - Dashboard Quan Sat Tap Trung (Grafana Observability Architecture)

Chuyen de nay huong dan chi tiet ve kien truc tu dong khoi tao nguon du lieu (Auto-Provisioning Datasources & Dashboards) cua Grafana 10.4.2, va phan tich cau truc dashboard tong quan `nexus_overview.json`.

---

## 1. Vai Tro Cua Grafana Trong He Sinh Thai Nexus

Grafana dong vai tro la **Giao dien quan sat hop nhat (Unified Observability UI)** duy nhat cua he thong tai cong `3000`:
- Ket noi du lieu tu ca **Prometheus** (Metrics) va **Tempo** (Traces).
- Cung cap che do quan sat thoi gian thuc, bieu do Flame Graph phan tich loi, va so do phu thuoc vi dich vu (Node Graph).
- Ho tro che do an danh (`GF_AUTH_ANONYMOUS_ENABLED=true`) giup lap trinh vien mo len la xem duoc ngay tren may dev ma khong can nhap tai khoan mat khau.

---

## 2. Kien Truc Tu Dong Khoi Tao (Zero-Manual Setup via Auto-Provisioning)

Trong cac du an thong thuong, sau khi khoi dong container Grafana, lap trinh vien phai vao Settings, go tay dia chi IP cua Prometheus, go tay dia chi cua Tempo, roi tim file JSON import dashboard thu cong.

He thong Nexus ap dung quy tac **Khong cau hinh thu cong (Zero-Manual Provisioning)** thong qua cac file YAML duoc mount thang vao container:

### 1. File `infra/grafana/datasources.yaml`
Tu dong dang ky 2 nguon du lieu va ket noi chung voi nhau ngay khi container khoi dong:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      httpMethod: POST
      exemplarTraceIdDestinations:
        - name: trace_id
          datasourceUid: tempo
          urlDisplayLabel: 'View in Tempo' # Nút chuyển trực tiếp từ Metric sang Trace

  - name: Tempo
    type: tempo
    url: http://tempo:3200
    jsonData:
      httpMethod: GET
      nodeGraph:
        enabled: true           # Bật tính năng vẽ sơ đồ luồng dịch vụ
      serviceMap:
        datasourceUid: prometheus # Lấy số liệu throughput để hiển thị trên mũi tên liên kết
      spanBar:
        type: 'Tag'
        tag: 'http.status_code'
```

### 2. File `infra/grafana/dashboards.yaml`
Tu dong quet toan bo file JSON trong thu muc `infra/grafana/dashboards/` va hien thi len menu Dashboards ma khong can thao tac Import:

```yaml
apiVersion: 1

providers:
  - name: 'Nexus Dashboards'
    orgId: 1
    folder: 'Nexus Ecosystem'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

---

## 3. Phan Tich Dashboard Tong Quan `nexus_overview.json`

File `infra/grafana/dashboards/nexus_overview.json` duoc dat lam Dashboard mac dinh khi truy cap `http://localhost:3000`:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ NEXUS ECOSYSTEM - OBSERVABILITY OVERVIEW DASHBOARD                     │
├───────────────────┬───────────────────┬────────────────────────────────┤
│ 1. TOTAL RPS      │ 2. ERROR RATE     │ 3. P95 / P99 LATENCY           │
│    (Throughput)   │    (Tỷ lệ lỗi %)  │    (Thời gian phản hồi)        │
├───────────────────┴───────────────────┴────────────────────────────────┤
│ 4. SERVICE DEPENDENCY GRAPH (NodeGraph)                                │
│    [ Gateway ] ──────( 120 req/s )──────> [ User Service ]            │
│         │                                        │                     │
│         └────────( 45 req/s )─────────> [ Catalog Service ]            │
├────────────────────────────────────────────────────────────────────────┤
│ 5. RECENT FAILED TRACES & SPAN PERFORMANCE                             │
│    Bảng danh sách các Trace có HTTP Status = 500 kèm nút "Open Trace"  │
└────────────────────────────────────────────────────────────────────────┘
```

### Cac panel kien truc then chot:
1. **Service Dependency Graph (NodeGraph):**
   Tu dong hien thi cac khoi hinh tron dai dien cho tung microservice. Mui ten noi giua cac khoi the hien huong goi API, do day cua mui ten the hien luu luong request, va mau sac the hien suc khoe (mau xanh la tot, mau do la dang co loi).
2. **Exemplar Traces on Latency Graphs:**
   Moi cot moc thoi gian co request bi cham duoc danh dau kem cham xanh. Lap trinh vien chi can click vao diem do la Grafana tu dong goi Tempo de hien thi toan bo call stack chi tiet.
