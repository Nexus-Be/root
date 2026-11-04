# Chuyen De 05: Redis 7 - Ha Tang Cache & Rate Limiting (Shared Redis Architecture)

Chuyen de nay huong dan chi tiet ve kien truc bo nho dem tap trung su dung Redis 7 Alpine tren cong `6379`, quan tri bo nho bang chinh sach LRU, ky luat phan vung khoa (Key Prefix Isolation), va mau thiet ke tu phuc hoi In-Memory Fallback.

---

## 1. Vai Tro Cua Redis 7 Trong He Sinh Thai Nexus

Trong he sinh thai Nexus, Redis 7 duoc su dung nhu mot **Lop luu tru tam thoi toc do cao trong RAM (In-Memory Key-Value Store)** phuc vu hai nhiem vu kien truc song con:

1. **Bo dem Rate Limiting tap trung cho API Gateway:**
   - Khi Gateway scale thanh nhieu container, Redis la noi giu bo dem so luot goi API cua tung dia chi Client IP de thuc hien bop tan suat mot cach cong bang va chinh xac.
2. **Luu tru ma xac thuc OTP va trang thai khoa tam thoi cho UserService:**
   - Ma OTP dang ky va quen mat khau chi co thoi gian song tu 3 den 5 phut.
   - Luu ma OTP tren Redis giup CSDL PostgreSQL khong bi qua tai boi hang trieu thao tac `INSERT` va `DELETE` cac ban ghi tam thoi, dong thoi tan dung co che tu dong xoa theo thoi gian TTL (Time-to-Live).

---

## 2. Quan Tri Bo Nho & Chinh Sach Giai Phong (Memory Management & LRU)

Bo nho RAM tren may chu la tai nguyen huu han va dat do. Neu khong cau hinh gioi han, khi luong truy cap tang dot bien, Redis co the chiem dung het sach RAM cua may va bi he dieu hanh Linux ngat dot ngot boi tien trinh OOM-Killer.

### Cau hinh an toan trong `docker-compose.infra.yml`:

```yaml
redis:
  image: redis:7-alpine
  container_name: nexus-shared-redis
  command: ["redis-server", "--maxmemory", "460mb", "--maxmemory-policy", "allkeys-lru"]
  mem_limit: 500m
  deploy:
    resources:
      limits:
        memory: 500M
```

### Nguyen ly phoi hop 2 tang phong ve:
1. **Tang Container (`mem_limit: 500m`):** Docker dam bao container Redis khong bao gio chiem qua 500MB RAM cua he thong.
2. **Tang Redis Server (`--maxmemory 460mb` & `--maxmemory-policy allkeys-lru`):**
   - Khi dung luong RAM cua Redis cham nguong 460MB, thuat toan **Least Recently Used (LRU)** se duoc kich hoat.
   - Redis se tu dong quet va xoa cac khoa it duoc truy cap nhat de nhuong cho cho cac khoa moi.
   - Nho do, Redis luon giu muc RAM duoi 460MB, khong bao gio cham nguong 500MB cua Docker, ngan ngua tuyet doi nguy co bi container crash.

---

## 3. Ky Luat Phan Vung Khoa (Key Prefix Isolation Governance)

Do tat ca cac dich vu deu su dung chung mot instance Redis tap trung, viec quan tri quy uoc dat ten khoa la bat bien de tranh tinh trang dich vu nay ghi de len khoa cua dich vu khac:

| Dich Vu Su Dung | Tien To Khoa (Key Prefix) | Vi Du Khoa Thuc Te | TTL (Thoi Gian Het Han) |
|:---|:---|:---|:---:|
| **API Gateway** | `nexus:gateway:rate:strict:*` | `nexus:gateway:rate:strict:POST:/api/v1/auth/login:127.0.0.1:2987654` | 60 giay |
| **UserService (OTP)** | `otp:registration:*` | `otp:registration:buyer@nexus.local` | 5 phut |
| **UserService (Password Reset)** | `otp:password_reset:*` | `otp:password_reset:user@nexus.local` | 5 phut |
| **UserService (Cache)** | `user:*` | `user:profile:11111111-1111-1111-1111-111111111111` | 30 phut |

---

## 4. Mau Thiet Ke Tu Phuc Hoi (In-Memory Fallback Design Pattern)

Ca API Gateway va UserService deu trien khai mau thiet ke **In-Memory Fallback** su dung `ConcurrentDictionary` trong C#:

```text
[ Incoming Request ]
        │
        ▼
Kiểm tra kết nối Redis (IsConnected == true)?
        ├── CÓ ──> Thực thi lệnh trên Redis (INCR / SETEX / GET)
        │
        └── KHÔNG (Redis Offline / Mất mạng)
                   │
                   ▼
                   Tự động chuyển hướng sang ConcurrentDictionary trong RAM
                   Ghi log Warning cảnh báo
                   Hệ thống vẫn tiếp tục hoạt động bình thường!
```

### Loi ich kien truc:
- **Tach roi tuyet doi giua phat trien va ha tang:** Lap trinh vien co the bat dau viet code va chay Unit/Integration Test ngay tren may ca nhan ma khong can bat Redis len truoc.
- **Duy tri tinh san sang cao (High Availability):** Khi cum Redis gap su co mang trong 10 giay, he thong van phuc vu nguoi dung ma khong nem ra loi HTTP 500.
