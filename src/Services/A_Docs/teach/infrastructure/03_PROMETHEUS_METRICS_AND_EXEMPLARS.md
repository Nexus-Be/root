# Chuyen De 03: Prometheus - Thu Thap Chi So & Exemplars (Prometheus Metrics & Exemplars Architecture)

Chuyen de nay huong dan chi tiet ve kien truc luu tru chi so chuoi thoi gian cua Prometheus 2.51.0, co che tiep nhan du lieu day tu xa (Remote-Write Receiver), va khai niem kien truc Exemplars giup ket noi tuc thi giua bieu do tong quan va vet truy vet chi tiet.

---

## 1. Vai Tro Cua Prometheus Trong Kien Truc Nexus

Prometheus dong vai tro la **Co so du lieu chuoi thoi gian (Time-Series Database - TSDB)** tap trung cua he thong Nexus:
- Thu thap va luu tru cac mau du lieu so (Metrics) theo moc thoi gian (Timestamp).
- Cung cap ngon ngu truy van manh me **PromQL** de tinh toan thong so thong ke nhu throughput trung binh, ty le loi phan tram, va cac phan vi do tre (percentiles: p50, p90, p95, p99).

---

## 2. Phan Tich Cau Hinh `infra/prometheus/prometheus.yml`

File cau hinh cua Prometheus duoc thiet lap don gian nhung day du tinh nang hien dai:

```yaml
# infra/prometheus/prometheus.yml
global:
  scrape_interval: 15s     # Tần suất kéo dữ liệu định kỳ mỗi 15 giây
  evaluation_interval: 15s # Tần suất thẩm định các quy tắc cảnh báo

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'tempo'
    static_configs:
      - targets: ['tempo:3200']
```

### Cac tinh nang dac biet duoc bat trong `docker-compose.infra.yml`:
Trong file `docker-compose.infra.yml`, container Prometheus duoc khoi chay voi hai cờ lenh dac biet:
1. **`--web.enable-remote-write-receiver`:**
   Cho phep Prometheus hoat dong o che do nhan du lieu (Push-based Receiver) thay vi chi di cao du lieu thu dong (Pull/Scrape). Nho co cờ nay, Tempo Metrics Generator co the remote-write cac chi so `span-metrics` va `service-graphs` truc tiep vao Prometheus.
2. **`--enable-feature=exemplar-storage`:**
   Kich hoat bo nho luu tru Exemplars trong TSDB cua Prometheus, cho phep luu tru kem `TraceId` vao ben trong cac mau du lieu Histogram.

---

## 3. Khai Niem Kien Truc Exemplars (Cau Noi Giua Metrics Va Traces)

Trong he thong giam sat truyen thong, hai the gioi **Metrics** va **Traces** thuong bi co lap hoan toan:
- Ban nhin thay bieu do do tre p99 bi vot len 5 giay luc 14:30 (Metrics).
- Nhung ban khong biet phai copy `TraceId` nao trong hang trieu request cua thoi diem do de kiem tra tren Tempo (Traces).

### Exemplar giai quyet triet de van de nay:
**Exemplar la mot tham chieu cu the (TraceId) duoc gan truc tiep vao mot diem do dac so lieu trong he thong chi so.**

```text
[ Prometheus Latency Histogram ]
    Độ trễ
      │
  5s  │                                     *  <-- Điểm spike này có Exemplar!
      │                                            {trace_id="4bf92f3577b34da6a3ce929d0e0e4736"}
  1s  │            *          *          *
      │   *  *  *     *  *  *    *  *  *
  0s  └───────────────────────────────────────── Thoi gian
```

### Trai nghiem van hanh tren Grafana:
1. Khi ban mo bieu do do tre tren Grafana, cac diem co Exemplar se hien thi duoi dang cac cham sang (Dots) nam tren duong do thi.
2. Ban chi can di chuot vao cham sang do, Grafana se hien thi pop-up nho: `trace_id = 4bf92f3577b34da6a3ce929d0e0e4736`.
3. Bam vao nut **"View in Tempo"**, Grafana se lap tuc mo giao dien chia doi man hinh (Split Screen) voi dung Flame Graph cua request bi cham 5 giay do.
4. Ban nhin thay ngay dong code hoac cau truy van CSDL gay ra do tre ma khong can phai phong doan hay tim kiem thu cong.
