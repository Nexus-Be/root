# Kiến Trúc Health Check, Prober Daemon & Chiến Lược Quản Lý Log Tập Trung
## (Nexus Health Prober & Centralized Logging Architecture Guide)

Tài liệu này là **Quy chuẩn kiến trúc chính thức** quy định cách thức hoạt động của hệ thống giám sát sức khỏe (Health Prober Daemon), cơ chế tự phục hồi (Self-Healing via Docker), xử lý sự cố (Circuit Breaker & Saga Rollback), và **chiến lược phân tầng lưu trữ log** (hiện tại và tương lai khi tích hợp `LogService`).

Mọi lập trình viên và **AI Code Agent** khi làm việc trên hệ thống Nexus Microservices cần đọc kỹ tài liệu này trước khi chỉnh sửa mã nguồn liên quan đến Health Check hoặc Logging.

---

## 1. Cơ Chế Thăm Dò Sức Khỏe (Health Prober Daemon)

### 1.1. Bản Chất Kiến Trúc
* Việc kiểm tra sức khỏe của các microservice **không** do service tự gọi chính nó, mà được thực hiện bởi một **Tác nhân bên ngoài (Prober Daemon)** chạy nền bên trong API Gateway.
* Mỗi microservice trong 8 services (`users`, `catalog`, `commerce`, `log`, `auction`, `fulfillment`, `notification`, `wallet`) có một Prober Daemon độc lập.
* **Mặc định khi Gateway khởi động:** Toàn bộ các Prober Daemon ở trạng thái **TẮT (`Disabled`)**. Chúng chỉ bắt đầu chạy khi được kích hoạt thông qua Gateway Control API hoặc cấu hình hệ thống.

### 1.2. Bốn Tham Số Điều Khiển Chuẩn (Configuration Standard)
Các tham số có thể cấu hình thông qua `appsettings.json` hoặc Biến môi trường (`Gateway__HealthProber__...`):

| Tham Số | Giá Trị Chuẩn | Ý Nghĩa Kỹ Thuật |
| :--- | :---: | :--- |
| **Interval** | **60s** (1 phút) | Chu kỳ định kỳ mỗi lần Prober Daemon gửi request probe tới service. |
| **Timeout** | **30s** | Thời gian tối đa chờ phản hồi. Nếu quá 30s không nhận được HTTP 200, coi như lần probe đó thất bại. |
| **Retries / FailureThreshold** | **5 lần** | Ngưỡng cho phép thất bại liên tiếp trước khi chuyển trạng thái sang `Unhealthy`. |
| **StartPeriod** | **60s** (1 phút) | Thời gian ân hạn khi container mới bật. Trong 60s này, nếu probe lỗi sẽ không tính vào số lần Retries. |

---

## 2. State Machine Của Health Check

Vòng đời trạng thái của một Service được quản lý theo State Machine sau:

```
    [ DISABLED ] ──(Gọi API kích hoạt)──► [ STARTING (StartPeriod 60s) ]
                                                    │
                 ┌──────────────────────────────────┴──────────────────┐
                 │ Nhận HTTP 200 OK                                    │ Hết 60s vẫn lỗi
                 ▼                                                     ▼
           [ HEALTHY ] ◄─────────────(Nhận 200 OK)───────────── [ DEGRADED (1-4 lỗi) ]
                 │                                                     │
                 │ Probe Timeout / 5xx                                 │ Lỗi tiếp chạm 5/5
                 └────────────► [ DEGRADED (1/5) ]                    ▼
                                                                [ UNHEALTHY ]
                                                                      │
                              ┌───────────────────────────────────────┴───────────────────────┐
                              │ 1. Circuit Breaker Fast-Fail: Chặn toàn bộ request tới service │
                              │ 2. Kích hoạt Saga Rollback: Bắn Event lên RabbitMQ            │
                              │ 3. Docker Auto-Recovery: Xóa & Recreate Container             │
                              │ 4. Ghi log sự cố vào File theo cơ chế giới hạn dòng          │
                              └───────────────────────────────────────┬───────────────────────┘
                                                                      ▼
                                                           [ RECOVERING (Recreated) ]
                                                                      │
                                                                      ▼
                                                           [ STARTING (Grace Period 60s) ]
```

---

## 3. Chiến Lược Quản Lý & Lưu Vết Log (Logging Strategy)

### 3.1. Các Lần Check Bình Thường (Healthy Định Kỳ)
* **Quy tắc:** **KHÔNG GHI FILE LOG.**
* **Giải pháp:**
  - Lưu **In-Memory Ring Buffer** (20-30 mẫu gần nhất) trong RAM của Gateway để phục vụ API truy vấn trạng thái tức thì.
  - Đẩy thông số dạng OpenTelemetry Metrics (`service_health_status = 1`, `probe_latency_ms`) lên Grafana Dashboard.

### 3.2. Khi Xảy Ra Lỗi Retry (Degraded 1/5 - 4/5) Và Chạm Ngưỡng Unhealthy (5/5)
* **Giai đoạn hiện tại (Local Incident File Logging):**
  - Gateway tạo một thư mục riêng biệt chuyên quản lý log sức khỏe: `logs/health/`.
  - Toàn bộ các sự cố (Timeout, Connection Refused, 5xx, State Transition sang Unhealthy) được ghi vào file log dạng:
    `logs/health/incident-YYYYMMDD-0001.log`.
  - **Cơ chế giới hạn số dòng (Line-Count Limit Rollover):**
    - Cấu hình qua `MaxLinesPerLogFile` (mặc định: **1000 dòng**).
    - Khi tệp log hiện tại đạt đủ 1000 dòng, hệ thống tự động đóng file và tạo file mới (`incident-YYYYMMDD-0002.log`).
  - *Lưu ý về các Microservices khác:* Hiện tại các backend microservices chỉ lưu `AuditLog` cho các hành động nghiệp vụ quan trọng (như giao dịch ví, thanh toán đơn hàng, thay đổi quyền hạn).

---

## 4. Hướng Dẫn Dành Cho AI Code Agent & Developer: Gom Log Tập Trung Về `LogService` (Future Roadmap)

> **Trạng thái triển khai (2026-10-24): ❌ Đứt gãy — Gateway đã code phía gửi, LogService chưa có phía nhận.** `ApiGateway/Nexus.Gateway/Logging/GatewayBatchLogSink.cs:50-55` POST `{RemoteEndpoint}/api/v1/internal/logs/batch` (mặc định `http://localhost:8004`), nhưng `Log.Api/Program.cs` **chỉ có** `MapGet("/health")` (dòng 66) và `MapGet("/")` (dòng 67) ⇒ mọi batch log nhận **404**, và lỗi bị nuốt bởi `catch { }` rỗng tại `GatewayBatchLogSink.cs:57-60`. Hiện **không có log tập trung nào được ghi** qua đường này; nguồn log thật duy nhất là Serilog của Gateway (stdout + file roll).
> **Nguồn sự thật:** `GatewayBatchLogSink.cs` (phía gửi) + `Log.Api/Program.cs` (phía nhận).

> ⚠️ **LƯU Ý QUAN TRỌNG KHI TRIỂN KHAI `LogService` (PORT 8004, `log_db`):**
> 
> Khi dự án bắt đầu xây dựng tầng gom log tập trung về `LogService`:
> 1. **Nguyên Tắc Batching (Gom Cụm $\ge$ 1000 Dòng):**
>    - Tuyệt đối **không** gửi từng dòng log đơn lẻ qua HTTP hay RabbitMQ tới LogService (sẽ gây cạn kiệt connection pool và nghẽn mạng).
>    - Toàn bộ log phải được gom vào bộ đệm (Buffer). Chỉ khi nào bộ đệm tích lũy **đủ 1000 dòng log** (hoặc sau một khoảng thời gian FlushTimeout định kỳ, ví dụ 30 giây nếu chưa đủ 1000 dòng) thì mới thực hiện gửi một gói Bulk Payload sang LogService.
> 2. **Kênh Truyền Tải Được Khuyến Nghị:**
>    - *Ưu tiên 1 (Asynchronous Event Bus):* Publish event `LogBatchCreatedIntegrationEvent` qua RabbitMQ tới queue `log-service.batch-ingestion`. Cách này đảm bảo Gateway không bị ảnh hưởng nếu LogService bận hoặc khởi động lại.
>    - *Ưu tiên 2 (HTTP REST Bulk API):* Gửi POST payload dạng JSON array tới `POST /api/v1/internal/logs/batch` của LogService.

---

## 5. Hành Động Khi Service Rơi Vào Trạng Thái Unhealthy

### 5.1. Fast-Fail Circuit Breaker (Tại Gateway)
Khi một service chuyển sang `Unhealthy` hoặc đang `Recovering`:
- Gateway chặn toàn bộ các cuộc gọi đến service đó ngay tại tầng `GatewayDispatcher`.
- Trả về ngay lập tức mã lỗi **HTTP 503 Service Unavailable** theo chuẩn RFC 9110:
  ```json
  {
    "type": "https://datatracker.ietf.org/doc/html/rfc9110#section-15.6.4",
    "title": "Downstream Service Unavailable",
    "status": 503,
    "errorCode": "DOWNSTREAM_UNHEALTHY",
    "detail": "Service 'catalog' is currently unhealthy and undergoing recovery.",
    "traceId": "0HNPG9VV71OGT"
  }
  ```

### 5.2. Kích Hoạt Saga Rollback (Bù Trừ Sự Cố)
- Gateway publish integration event:
  ```csharp
  public record ServiceUnhealthyIntegrationEvent(string ServiceName, DateTime OccurredAt, string Reason);
  ```
- Các service điều phối quy trình phân tán (ví dụ `CommerceService` phụ trách Checkout Saga) khi bắt được event này sẽ tự động hủy các transaction đang treo (Pending) liên quan tới service bị sập để hoàn tiền và nhả tài nguyên.

### 5.3. Docker Container Auto-Recovery
- Gateway kết nối tới Docker Daemon qua `/var/run/docker.sock`.
- Tự động thực thi:
  1. `StopContainerAsync` (timeout 10s).
  2. `RemoveContainerAsync`.
  3. `CreateContainerAsync` & `StartContainerAsync` (sử dụng lại đúng configuration / network / ports).
- Chuyển trạng thái Prober sang `Recovering` $\rightarrow$ Đợi hết `StartPeriod` (60s) trước khi bắt đầu tính lỗi trở lại.
- **Bảo vệ chống lặp vô hạn (CrashLoopBackOff Protection):** Nếu một container tự động restart quá **3 lần liên tiếp** mà vẫn Unhealthy, Prober sẽ ngừng tự động restart và đánh dấu cảnh báo khẩn cấp `CRITICAL_INTERVENTION_NEEDED` để tránh treo máy chủ.
