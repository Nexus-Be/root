# HƯỚNG DẪN HẠ TẦNG REDIS: RATE LIMITING & LƯU TRỮ OTP
## (REDIS CACHE ARCHITECTURE, CLI INSPECTION & KEY MANAGEMENT GUIDE)

> **Mục tiêu tài liệu**: Hướng dẫn cách thức vận hành của Redis trong hệ sinh thái Nexus Microservices, cấu trúc các khóa dữ liệu (Keys), cách sử dụng `redis-cli` để tra cứu, gỡ lỗi Rate Limit và kiểm tra mã xác thực OTP.

---

## 1. VAI TRÒ CỦA REDIS TRONG HỆ THỐNG NEXUS

Redis (phiên bản `7-alpine`) là cơ sở dữ liệu In-Memory tốc độ cao (độ trễ < 1ms), đóng 2 vai trò kỹ thuật sống còn:

### 1.1. Tầng API Gateway: Distributed Dynamic Rate Limiting (Giới hạn tần suất gọi phân tán)
* Khi Gateway được triển khai mở rộng ngang (Scale-out) thành nhiều Container/Pod chạy song song, bộ đếm in-memory thông thường của một tiến trình không thể kiểm soát được tổng số request của người dùng.
* Redis đóng vai trò là **Bộ đếm tập trung (Shared Distributed Counter)**. Bất kể request của một IP/User rơi vào container Gateway nào, bộ đếm trên Redis đều tích lũy chính xác theo từng cửa sổ thời gian (Fixed-Window Bucket).

### 1.2. Tầng UserService: Lưu Trữ & Quản Lý Vòng Đời Mã OTP
* Mã OTP kích hoạt tài khoản có tính chất tạm thời (hiệu lực 5 phút, lưu trữ tối đa 15 phút).
* Việc lưu OTP vào bảng CSDL PostgreSQL quan hệ sẽ gây phình dữ liệu và tốn I/O đĩa không cần thiết.
* Redis đảm nhiệm lưu trữ OTP với tính năng **tự động hết hạn (TTL - Time To Live)**, hỗ trợ kiểm tra trạng thái (`Active`, `Consumed`, `Expired`) cực nhanh.

---

## 2. THÔNG SỐ KẾT NỐI & KHỞI ĐỘNG

| Thông Số | Giá Trị Mặc Định | Ghi Chú |
| :--- | :--- | :--- |
| **Tên Container Docker** | `nexus-shared-redis` | Ảnh `redis:7-alpine` |
| **Cổng mạng (Host & Container)** | `6379` | `localhost:6379` |
| **Mật khẩu (Password)** | Không mật khẩu (Dev) | Có thể cấu hình `requirepass` trên Prod |
| **Volume lưu trữ dữ liệu** | `redis_data` | Giữ dữ liệu khi restart container |

### Khởi động container Redis:
```bash
# Từ thư mục gốc Nexus-Be:
docker compose -f docker-compose.infra.yml up -d redis
```

---

## 3. CƠ CHẾ FAIL-OPEN & FAIL-CLOSED CỦA REDIS TẠI GATEWAY

Gateway trang bị cơ chế bảo vệ thông minh (`RedisFailOpenInDevelopment` trong `appsettings.json`):
* **Ở Môi Trường Development (`ASPNETCORE_ENVIRONMENT=Development`):**
  - Nếu Redis chưa được bật hoặc bị sập, Gateway ghi log `[WARNING] Redis is unavailable; development rate limiting is failing open.` và **cho phép request đi qua bình thường**. Điều này giúp lập trình viên không bị chặn công việc khi chỉ muốn test code offline.
* **Ở Môi Trường Production:**
  - Nếu Redis mất kết nối, Gateway kích hoạt cơ chế **Fail-Closed**, từ chối request với mã lỗi **HTTP 503 `RATE_LIMIT_SERVICE_UNAVAILABLE`** để bảo vệ hệ thống backend khỏi nguy cơ bị tấn công tràn ngập (DDoS).

---

## 4. CẤU TRÚC KHÓA (KEYS SPECIFICATION) & CÁCH TRA CỨU

### 4.1. Khóa Giới Hạn Tần Suất (Rate Limiting Keys tại Gateway)
Được sinh tự động bởi `RedisRateLimitMiddleware.cs` theo định dạng:

$$\mathbf{\{prefix\}:rate:\{policy\}:\{service\}:\{identity\}:\{timeBucket\}}$$

* **`{prefix}`**: Tiền tố mặc định là `nexus:gateway`.
* **`{policy}`**: Chính sách áp dụng: `auth-strict` (5 lần/phút), `auth-login` (10 lần/phút), `user-frequent` (120 lần/phút), `default` (100 lần/phút).
* **`{service}`**: Service phụ trách endpoint (`users`, `catalog`...).
* **`{identity}`**: User ID (nếu đã đăng nhập qua claim `sub`) hoặc Remote IP Address (nếu gọi ẩn danh).
* **`{timeBucket}`**: Số nguyên đại diện cho cửa sổ thời gian cố định: `now.ToUnixTimeSeconds() / windowSeconds`.

*Ví dụ một key thực tế trong Redis:*
```
nexus:gateway:rate:auth-strict:users:127.0.0.1:29782928
```
*Thuật toán Lua Script nguyên tử:*
Khi request đến, Gateway thực thi đoạn mã Lua script nguyên tử:
```lua
local current = redis.call('INCR', KEYS[1])
if current == 1 then
    redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
return current
```
Đoạn script này đảm bảo việc tăng số lượt và gán thời gian hết hạn (PEXPIRE) diễn ra trong cùng một thao tác duy nhất, không bao giờ bị race-condition.

---

### 4.2. Khóa Lưu Mã Xác Thực OTP (OTP Keys tại UserService)
Được sinh bởi `AuthService.cs` trong `UserService`:

$$\mathbf{user:otp:\{normalized\_email\}}$$

*Ví dụ key thực tế:*
```
user:otp:buyer01@example.com
```
*Dữ liệu JSON lưu bên trong:*
```json
{
  "email": "buyer01@example.com",
  "code": "481920",
  "status": "Active",
  "createdAt": "2026-10-24T12:00:00Z",
  "expiresAt": "2026-10-24T12:05:00Z"
}
```
*Vòng đời TTL:*
- Sau khi được tạo, key có TTL mặc định là **900 giây (15 phút)**.
- Người dùng chỉ được nhập mã trong vòng **300 giây (5 phút đầu)**. Nếu quá 5 phút, `AuthService` chuyển trạng thái sang `Expired`.
- Khi người dùng nhập đúng mã, trạng thái chuyển thành `Consumed` để chống tấn công dùng lại mã (Replay Attack).

---

## 5. CẨM NANG LỆNH `redis-cli` DÀNH CHO DEVELOPER

Để tương tác trực tiếp với Redis trong Docker, mở Terminal và gõ:
```bash
docker exec -it nexus-shared-redis redis-cli
```

### Các lệnh tra cứu thường dùng nhất:

#### 1. Kiểm tra danh sách tất cả các key đang có:
```redis
# Liệt kê tất cả keys:
KEYS *

# Tìm kiếm các key liên quan đến Rate Limit:
KEYS nexus:gateway:rate:*

# Tìm kiếm các key chứa mã OTP:
KEYS user:otp:*
```

#### 2. Xem nội dung và số lần gọi hiện tại của một key:
```redis
# Xem số lần request đã gọi (đối với rate limit):
GET nexus:gateway:rate:auth-strict:users:127.0.0.1:29782928
# Kết quả trả về: "3" (nghĩa là đã gọi 3 lần trong cửa sổ 60s)

# Xem nội dung JSON của mã OTP:
GET user:otp:buyer01@example.com
```

#### 3. Xem thời gian sống còn lại (TTL - Time To Live):
```redis
TTL nexus:gateway:rate:auth-strict:users:127.0.0.1:29782928
# Trả về số giây còn lại trước khi bucket tự động bị xóa (ví dụ: 42)
```

#### 4. Mẹo giải phóng hạn mức khi bạn lỡ tay bị chặn lỗi 429:
Khi bạn đang test tính năng và bị Gateway chặn mã lỗi HTTP 429 (`RATE_LIMIT_EXCEEDED`), thay vì phải ngồi đợi hết 60 giây, bạn có thể xóa ngay key đó để tiếp tục test:
```redis
# Xóa key rate limit của bạn:
DEL nexus:gateway:rate:auth-strict:users:127.0.0.1:29782928

# Hoặc xóa toàn bộ dữ liệu rate limit khi dev:
FLUSHDB
```

#### 5. Xem luồng request vào Redis theo thời gian thực (Real-time Stream):
Lệnh này cực kỳ hữu ích khi bạn muốn thấy ngay lập tức lệnh nào đang được Gateway hay UserService gửi xuống Redis:
```redis
MONITOR
```
*(Bấm `Ctrl + C` để thoát chế độ monitor).*
