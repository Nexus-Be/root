# Chuyen De 00: Tong Quan Ha Tang & Mang Dung Chung (Infrastructure Topology Architecture)

Chuyen de nay giai thich ve kien truc mang ha tang tap trung trong he sinh thai Nexus, nguyen ly Single Shared Infrastructure, quan tri gioi han tai nguyen phan cung, va chien luoc ket hop Hybrid giua Neon Cloud va Docker cuc bo.

---

## 1. Kien Truc Ha Tang Tap Trung (Single Shared Infrastructure)

Trong kien truc Microservices truyen thong, moi vi dich vu thuong co xu huong tu khai bao container Redis, co so du lieu va he thong giam sat rieng trong file `docker-compose.yml` cua chinh no.

Viec nay gay ra cac van de nghiem trong trong qua trinh phat trien:
1. **Can kiet tai nguyen may dev:** Neu 9 microservices deu khoi chay container Redis rieng, may cua lap trinh vien se ton hang chuc GB RAM chi de duy tri cac tien trinh chay ngam trung lap.
2. **Khong chia se duoc trang thai:** API Gateway khong the kiem tra so luot goi OTP cua User Service neu moi ben su dung mot phan vung Redis tach biet.
3. **Phan manh giam sat:** Tracing va Metrics bi chia nho thanh nhieu he thong rieng le, khong the ket noi duoc toan bo luong di cua request.

### Giai phap cua Nexus:
Toan bo ha tang ho tro duoc gop chung vao mot file duy nhat tai goc du an: [docker-compose.infra.yml](docker-compose.infra.yml). File nay khoi tao 4 thanh phan ho tro chinh:
- `nexus-shared-redis`: Cổng `6379`.
- `nexus-shared-tempo`: Cổng `4317`, `4318`, `3200`.
- `nexus-shared-prometheus`: Cổng `9090`.
- `nexus-shared-grafana`: Cổng `3000`.

---

## 2. Kien Truc Mang Ngoai Dung Chung (`nexus-network`)

De tat ca cac container (khi chay qua Docker) va cac ung dung .NET (khi chay truc tiep tu IDE nhu Visual Studio, Rider hoac VS Code) co the giao tiep lien mach voi nhau, he thong khai bao mang ngoai `nexus-network`:

```yaml
# docker-compose.infra.yml
networks:
  default:
    name: nexus-network
    external: true
```

### Nguyen ly ket noi:
1. Khi container khoi chay, chung gia nhap vao bridge network `nexus-network`, cho phep goi lan nhau thong qua DNS noi bo cua Docker (vi du: `http://prometheus:9090`, `http://tempo:3200`).
2. Dong thoi, file compose public cac port ra may chu (`ports: - "6379:6379"`, `- "4317:4317"`), cho phep ung dung .NET dang chay truc tiep tren may host ket noi vao qua `localhost` mot cach trong suot.

---

## 3. Quan Tri Tai Nguyen Phan Cung (Resource Limits Governance)

Moi container ha tang deu duoc thiet lap han muc tai nguyen co dinh trong `docker-compose.infra.yml` de dam bao khong chiem dung qua nhieu tai nguyen may tinh cua lap trinh vien:

```yaml
redis:
  image: redis:7-alpine
  command: ["redis-server", "--maxmemory", "460mb", "--maxmemory-policy", "allkeys-lru"]
  mem_limit: 500m
  deploy:
    resources:
      limits:
        memory: 500M
```

- **Han muc bo nho (Memory Limit 500MB):** Ngan chan Redis tang truong bo nho khong kiem soat.
- **Chinh sach giai phong (LRU Policy):** Khi bo nho dat 460MB, Redis tu dong huy cac khoa it duoc su dung nhat (`allkeys-lru`), tranh viec Docker daemon ngat container do loi Out-Of-Memory.
- **Compactor 48h trong Tempo:** Tempo chi giu trace blocks trong 48 gio tren o dia cuc bo, tu dong don dep cac file trace cu.

---

## 4. Chien Luoc Ha Tang Hybrid (Cloud Database & Local Observability)

Nexus ap dung chien luoc ha tang lai linh hoat (Hybrid Strategy):

### 1. Co so du lieu PostgreSQL tren Neon Cloud
- Toan bo CSDL quan he cua 8 microservices duoc dat tren **Neon Serverless PostgreSQL**.
- **Loi ich:** Tinh nang Scale-to-Zero tiet kiem chi phi, ho tro Branching CSDL tuc thi cho tung nhanh Git / Pull Request, khong gay nang may cua lap trinh vien.

### 2. Cum CSDL Cuc Bo (Offline Fallback Cluster)
- Trong truong hop lap trinh vien lam viec offline (khong co Internet) hoac can chay test cuc bo hoan toan doc lap, he thong cung cap san file [src/Infrastructure/databases/docker-compose.yml](src/Infrastructure/databases/docker-compose.yml) khoi chay cum 8 container PostgreSQL tren cac cong rieng biet tu `5433` den `5440`.

### 3. Ha tang Telemetry chay cuc bo (Local Observability)
- Thay vi gui toan bo trace va metrics len cac dich vu SaaS dat do (nhu Datadog, New Relic hay Dynatrace), he thong su dung bo ba ma nguon mo **Tempo + Prometheus + Grafana** chay cuc bo bang Docker.
- Toan bo chi phi luu tru trace va do dac thoi gian thuc tren moi truong dev la **0 dong**, dong thoi dam bao du lieu noi bo khong bi day ra ben ngoai trai phep.
