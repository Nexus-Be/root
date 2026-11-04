# Chuyen De 02: Grafana Tempo - Luu Tru Vet Truy Vet Phan Tan (Tempo Tracing Backend Architecture)

Chuyen de nay huong dan chi tiet ve kien truc luu tru trace cua Grafana Tempo 2.4.1, co che tu dong phan tich spans de sinh ra chi so (Metrics Generator), va quy trinh remote-write sang Prometheus kem Exemplars.

---

## 1. Tai Sao Su Dung Grafana Tempo Thay Vi Elasticsearch / Jaeger?

Trong cac he thong Microservices cu, doi ngu ky thuat thuong phai duy tri mot cum Elasticsearch cong kenh chi de danh chi muc (index) va tim kiem traces.
- **Nhuoc diem cua Elasticsearch:** Chi phi phan cung cuc lon (ton nhieu RAM de giu chi muc chuoi), yeu cau bao tri phuc tap, va de gay treo he thong khi luong span tang vot.

### Uu the vuot troi cua Grafana Tempo:
- **Luu tru Trace dang Block truc tiep tren dia:** Tempo khong can danh chi muc toan bo noi dung van ban cua span. No chi luu cac khoi du lieu nen (trace blocks) vao o cung cuc bo hoac S3 Object Storage.
- **Chi phi cuc thap:** Tieu ton it hon 80% RAM so voi Elasticsearch.
- **Tich hop hoan hao voi he sinh thai Grafana:** Ho tro truc quan hoa Flame Graph, bieu do phu thuoc dich vu (Node Graph), va tim kiem nhanh theo TraceId.

---

## 2. Phan Tich Cau Hinh `infra/tempo/tempo.yaml`

File cau hinh cua Tempo trong du an chua cac tham so kien truc then chot:

```yaml
# infra/tempo/tempo.yaml
stream_over_http_enabled: true
server:
  http_listen_port: 3200

# 1. Distributor: Bộ tiếp nhận dữ liệu OTLP từ các service
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

# 2. Ingester & Compactor: Quản lý ghi đệm và nén file
ingester:
  trace_idle_period: 5s
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 48h # Tự động xóa trace cũ sau 48 giờ để giữ ổ cứng sạch

# 3. Metrics Generator: Động cơ phân tích Spans thành Metrics
metrics_generator:
  registry:
    external_labels:
      source: tempo
      cluster: nexus-cluster
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://prometheus:9090/api/v1/write
        send_exemplars: true # Gắn kèm Exemplar để liên kết Metrics với Traces

overrides:
  defaults:
    metrics_generator:
      processors: [service-graphs, span-metrics]

# 4. Storage Engine
storage:
  trace:
    backend: local
    wal:
      path: /var/tempo/wal
    local:
      path: /var/tempo/traces
```

---

## 3. Co Che Metrics Generator (Tu Dong Sinh Chi So Tu Traces)

Diem dac sac nhat trong kien truc Tempo cua Nexus la tinh nang **`metrics_generator`**.

Thay vi bat tung lap trinh vien phai viet code thu cong de do dem so luot request, thoi gian xu ly va ty le loi trong tung Controller, Tempo tu dong lang nghe toan bo luong Spans chay vao cong 4317 va thuc thi 2 bo vi xu ly (Processors):

### 1. `span-metrics` (RED Metrics Engine)
Bo xu ly nay tu dong chiet xuat mo hinh RED tu cac spans:
- **Rate:** So luong request tren moi giay cua tung route (`traces_spanmetrics_calls_total`).
- **Error:** So luong request bi loi HTTP 4xx, 5xx (`status_code = error`).
- **Duration:** Bieu do phan bo do tre p50, p90, p99 (`traces_spanmetrics_latency_bucket`).

### 2. `service-graphs` (Service Dependency Graph Engine)
Bo xu ly nay phan tich moi quan he cha-con giua cac spans:
- Span A (Gateway) goi sang Span B (UserService): Tempo tu dong tao ra mot canh (edge) noi giua `Nexus.Gateway` va `user-service`.
- Tu do sinh ra cac metric: `traces_service_graph_request_total`, `traces_service_graph_request_failed_total`.
- Nho do, Grafana co the tu dong ve so do kien truc toan he thong dang Node Graph ma khong can bat ky file cau hinh thu cong nao.

---

## 4. Quy Trinh Remote-Write Sang Prometheus Kem Exemplars

Sau khi `metrics_generator` tinh toan xong cac chi so RED va Service Graph trong bo nho dem WAL:
1. Tempo su dung co che **Prometheus Remote-Write** de day cac metric nay sang endpoint `http://prometheus:9090/api/v1/write`.
2. Khi tham so `send_exemplars: true` duoc bat, Tempo dinh kem them `TraceId` vao dung diem mau du lieu (data point) bi dot bien ve do tre.
3. Nho co che nay, nguoi van hanh khi nhin thay mot cot do tre bi vot len tren bieu do cua Prometheus co the bam chuot thang vao cot do de mo ra dung ban ghi Trace tuong ung trong Tempo.
