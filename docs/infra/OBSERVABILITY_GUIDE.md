# HƯỚNG DẪN GIÁM SÁT PHÂN TÁN (DISTRIBUTED TRACING): GRAFANA & TEMPO
## (OPENTELEMETRY TRACING, WATERFALL VISUALIZATION & DEBUGGING GUIDE)

> **Mục tiêu tài liệu**: Hướng dẫn cách thức vận hành của hệ thống giám sát phân tán (Observability) trong Nexus Microservices, cách lấy mã `X-Trace-Id` từ phản hồi của Gateway và sử dụng giao diện Grafana Tempo để xem biểu đồ dòng chảy (Waterfall Diagram), phát hiện điểm nghẽn hiệu năng (bottlenecks) và gỡ lỗi xuyên suốt từ Gateway qua Microservices, CSDL và RabbitMQ.

---

## 1. BẢN CHẤT KIẾN TRÚC DISTRIBUTED TRACING TRONG NEXUS

Trong một hệ thống phân tán gồm 9 services, khi người dùng gặp lỗi hoặc một request bị chậm 3 giây, câu hỏi lớn nhất là: **"Thời gian bị nghẽn ở đâu? Tại Gateway, tại UserService, do câu lệnh SQL chậm, hay do RabbitMQ bị trễ?"**

Nexus giải quyết bài toán này bằng chuẩn **W3C Distributed Tracing & OpenTelemetry**:

```
[ Client Request ]
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ 1. API GATEWAY                                         │
│    Sinh ra mã Trace: X-Trace-Id: 4bf92f3577b34da6a3... │
│    Gắn traceparent vào gRPC Metadata                   │
└──────┬─────────────────────────────────────────────────┘
       │ (HTTP/2 gRPC)
       ▼
┌────────────────────────────────────────────────────────┐
│ 2. USER SERVICE                                        │
│    Tiếp nhận TraceId, tạo Span con (Child Span)        │
│    - Thực thi SQL: SELECT * FROM "Users" (12ms)        │
│    - Bắn Event lên RabbitMQ kèm Trace Context (3ms)    │
└──────┬─────────────────────────────────────────────────┘
       │ (AMQP Message Header)
       ▼
┌────────────────────────────────────────────────────────┐
│ 3. NOTIFICATION SERVICE (WORKER)                       │
│    Nhận tin nhắn từ RabbitMQ, tiếp tục TraceId gốc     │
│    - Gửi HTML Email qua Gmail SMTP (450ms)             │
└────────────────────────────────────────────────────────┘
```
Toàn bộ các Span (đoạn ghi dấu thời gian) của tất cả các service được gửi tự động qua giao thức OTLP gRPC (`port 4317`) về kho lưu trữ tập trung **Grafana Tempo**.

---

## 2. THÔNG SỐ CỔNG MẠNG & THÔNG TIN KẾT NỐI

| Thành Phần | Cổng Mạng (Port) | Địa Chỉ Truy Cập / Ghi Nhận | Ghi Chú |
| :--- | :---: | :--- | :--- |
| **Grafana Dashboard** | **3000** | `http://localhost:3000` | Giao diện trực quan hóa traces |
| **Tempo OTLP gRPC** | **4317** | `http://localhost:4317` (hoặc `http://tempo:4317`) | Các service .NET đẩy trace về cổng này |
| **Tempo OTLP HTTP** | **4318** | `http://localhost:4318` | Nhận trace qua HTTP JSON |
| **Tempo Internal API**| **3200** | `http://localhost:3200` | Grafana kết nối vào Tempo qua cổng này |

### Cấu hình sẵn sàng (Zero-Config):
- Container **Grafana** (`nexus-shared-grafana`) đã được cấu hình sẵn chế độ **Anonymous Admin** (không yêu cầu đăng nhập mật khẩu).
- Datasource **Tempo** đã được nạp tự động qua file `infra/grafana/datasources.yaml`. Bạn chỉ cần mở trình duyệt lên là dùng được ngay!

---

## 3. QUY TRÌNH 3 BƯỚC TRA CỨU TRACE TRÊN GRAFANA

### Bước 1: Lấy mã `TraceId` từ Request
Bất kỳ khi nào bạn gọi một API qua Gateway (bằng Swagger, Postman hay Frontend Web):
1. **Cách A (Xem qua Response Header):**  
   Mở phần Response Headers, copy giá trị của header: **`X-Trace-Id`**.
2. **Cách B (Xem qua Response Body):**  
   Mọi phản hồi JSON chuẩn (cả thành công hay báo lỗi ProblemDetails) đều chứa trường `traceId`:
   ```json
   {
     "success": true,
     "statusCode": 200,
     "data": { ... },
     "traceId": "0HNPH0O1RS5U4",
     "timestamp": "2026-10-24T12:00:00Z"
   }
   ```

---

### Bước 2: Mở Giao Diện Explore Trên Grafana
1. Mở trình duyệt truy cập: **`http://localhost:3000/explore`**.
2. Ở góc trên cùng bên trái, đảm bảo ô Datasource đang chọn là **`Tempo`**.

---

### Bước 3: Dán Mã Trace & Xem Biểu Đồ Waterfall
1. Trong giao diện tìm kiếm của Tempo, chọn tab **TraceQL** hoặc nhập trực tiếp mã `traceId` vào ô tìm kiếm.
2. Bấm nút **Run query** (hoặc nhấn phím `Shift + Enter`).
3. Màn hình sẽ hiển thị ngay lập tức biểu đồ dạng thác nước (**Waterfall Trace View**):

```
Span Name                                          Duration     Timeline
─────────────────────────────────────────────────────────────────────────────
▼ GET /api/v1/auth/register (Gateway)               185 ms     ■■■■■■■■■■■■■■
  ▼ UsersApi/Register (gRPC Client Call)            162 ms       ■■■■■■■■■■■■
    ▼ UsersGrpcService.Register (User Backend)      158 ms       ■■■■■■■■■■■
      ▼ Npgsql: SELECT "Users" WHERE "Email" = @p0   14 ms        ■
      ▼ BCrypt.HashPassword                         120 ms        ■■■■■■■■■
      ▼ Npgsql: INSERT INTO "Users"                  18 ms         ■
      ▼ MassTransit: Publish SendOtpEmailIntegration  6 ms          ■
```

---

## 4. KỸ THUẬT PHÂN TÍCH & BẮT BỆNH QUA TRACE (DEBUGGING TIPS)

Khi nhìn vào biểu đồ Waterfall, bạn có thể chẩn đoán ngay lập tức các vấn đề phổ biến:

### 1. Phát hiện Điểm Nghẽn Hiệu Năng (Performance Bottlenecks):
- Thanh nào có chiều dài dài nhất chính là nơi tiêu tốn nhiều thời gian nhất.
- Ví dụ nếu thấy span `BCrypt.HashPassword` mất 120ms $\rightarrow$ Đây là hành vi mã hóa bảo mật bình thường của thuật toán băm mật khẩu.
- Nếu thấy span truy vấn CSDL `Npgsql: SELECT ...` mất tới 800ms $\rightarrow$ CSDL đang bị thiếu Index (chỉ mục) trên cột tìm kiếm!

### 2. Phát Hiện Lỗi Truy Vấn Lặp Lại (N+1 Query Problem):
- Nếu bạn thấy hàng chục thanh span SQL nhỏ (ví dụ 50 câu `SELECT * FROM Categories WHERE Id = ...`) xuất hiện nối tiếp nhau liên tục $\rightarrow$ Code đang bị lỗi N+1 Query do dùng vòng lặp `foreach` để query database thay vì dùng `IN (...)` hoặc `.Include()`.

### 3. Gỡ Lỗi Khi Request Báo Lỗi Đỏ (Spans with Errors):
- Khi một service hoặc một câu truy vấn bị lỗi, thanh Span tương ứng sẽ **chuyển sang màu đỏ**.
- **Cách xem lỗi chi tiết:**
  - Bấm trực tiếp vào thanh màu đỏ đó.
  - Cột bên phải sẽ bung ra toàn bộ thông tin chi tiết:
    - Câu lệnh SQL đầy đủ (`db.statement`).
    - Tên lỗi ngoại lệ (`exception.type`).
    - Chuỗi thông báo lỗi (`exception.message`).
    - Dấu vết dòng code bị crash (`exception.stacktrace`).
  - Bạn không cần phải mò mẫm mở từng file log trên server để tìm nguyên nhân!

---

## 5. CẤU HÌNH OPENTELEMETRY TRONG MÃ NGUỒN MICROSERVICE C#

Tất cả các Microservice trong Nexus đều được trang bị thư viện OpenTelemetry chuẩn:
```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource(serviceName)
        .AddAspNetCoreInstrumentation() // Đo lường request HTTP vào
        .AddGrpcClientInstrumentation() // Đo lường các cuộc gọi gRPC
        .AddNpgsql()                    // Tự động đo lường mọi câu lệnh SQL PostgreSQL
        .AddSource("MassTransit")       // Tự động đo lường việc gửi/nhận message RabbitMQ
        .AddOtlpExporter(o =>
        {
            o.Endpoint = new Uri(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://localhost:4317");
        }));
```
Nhờ cơ chế này, developer không cần phải viết code đo đạc thủ công (manual instrumentation). Toàn bộ luồng dữ liệu đều được thu thập tự động 100%.
