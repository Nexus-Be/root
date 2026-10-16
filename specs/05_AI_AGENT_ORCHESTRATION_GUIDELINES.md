# 05 — CHỈ DẪN VẬN HÀNH DÀNH CHO AI CODING AGENTS (AI AGENT ORCHESTRATION GUIDELINES)

Tài liệu này là **Quy Chuẩn Tối Thượng (Supreme Guidelines)** dành cho các AI Coding Agents (Claude, Cursor, Copilot, DeepSeek Harness, Windsurf, Aider...) khi hoạt động trong hệ sinh thái Nexus. Bộ chỉ dẫn này được xây dựng để giải quyết triệt để vấn đề **mất ngữ cảnh (context loss) khi chuyển máy / chuyển phiên** và **loại bỏ hoàn toàn ảo giác (zero hallucination)**.

---

## 1. NGUYÊN TẮC CHỐNG ẢO GIÁC (ANTI-HALLUCINATION GUARDRAILS)

Các AI Agent khi tham gia dự án **BẮT BUỘC TUÂN THỦ 7 ĐIỀU CẤM KỴ SAU ĐÂY**:

1. **CẤM DÙNG REPOSITORY PATTERN BỌC NGOÀI EF CORE**:
   - Kiến trúc của Nexus đã chốt dứt khoát tại [ADR.md](../src/Services/ApiGateway/ADR.md): **Sử dụng trực tiếp `DbContext` và `DbSet` trong Application Layer**.
   - Tuyệt đối **KHÔNG tự ý tạo thêm** các interface `IRepository<T>`, `GenericRepository`, `IUnitOfWork`. EF Core bản thân nó đã là một Unit of Work & Repository hoàn hảo.

2. **CẤM TỰ Ý ĐỔI PORT HOẶC CẤU HÌNH MẠNG**:
   - Dải port `8000` (Gateway) và `8001` - `8008` (Services) là bất biến. Không được tự ý đổi port trong `launchSettings.json` hay `appsettings.json`.

3. **CẤM ĐƯA DATABASE IN-MEMORY HAY STATEFUL BUSINESS LOGIC VÀO GATEWAY**:
   - ApiGateway là một Edge Reverse Proxy thuần túy.
   - Khi chạy chế độ Mock, Gateway chỉ đọc Seed JSON fixture trong `Seeds/{service}/{entity}.json` và kiểm tra cú pháp qua Protobuf Parser, tuyệt đối không tạo in-memory collection hay giả lập logic database stateful.

4. **CẤM THAY ĐỔI PROTOBUF TAG NUMBERS TRONG `shop.proto`**:
   - `Contracts/shop.proto` tại ApiGateway là nguồn sự thật duy nhất. Không đổi tag number của các trường có sẵn để tránh vỡ tương thích nhị phân.

5. **CẤM SỬ DỤNG TRỰC TIẾP DB CỦA SERVICE KHÁC**:
   - Database-Per-Service: Mỗi service chỉ đọc/ghi đúng database của mình. Mọi trao đổi dữ liệu bắt buộc qua gRPC hoặc RabbitMQ Event.

6. **CẤM COMMIT CÁC THƯ MỤC RÁC HOẶC TẠM THỜI**:
   - Tuyệt đối không commit `bin/`, `obj/`, `.idea/`, `.vs/`, `.vscode/`, `.env` vào Git repository.

7. **CẤM VI PHẠM LUỒNG PHỤ THUỘC CLEAN ARCHITECTURE**:
   - `Domain` độc lập 100% (không phụ thuộc bất kỳ project nào).
   - `Application` chỉ phụ thuộc `Domain`.
   - `Infrastructure` và `Api` phụ thuộc `Application` và `Domain`.
   - `Domain` và `Application` tuyệt đối **KHÔNG ĐƯỢC phụ thuộc ngược** vào `Infrastructure` hay `Api`.

---

## 2. QUY TRÌNH TIẾP QUẢN BỐI CẢNH KHI CHUYỂN PHIÊN / CHUYỂN MÁY (CONTEXT PRESERVATION)

Khi bắt đầu một phiên làm việc mới trên một repo bất kỳ:

```
[ Bắt đầu phiên làm việc mới ]
               │
               ▼ (Bước 1) Đọc file specs/00_AGENT_MISSION_GUARDRAILS.md của repo hiện tại
               │         ➔ Nắm vững mục tiêu, ranh giới domain, port, database của repo.
               │
               ▼ (Bước 2) Đọc file specs/01_CLEAN_ARCHITECTURE_LAYERS.md (hoặc ARCHITECTURAL_BLUEPRINT)
               │         ➔ Hiểu rõ vị trí các class, luồng dependency, cách tổ chức code.
               │
               ▼ (Bước 3) Đọc file specs/02_API_GRPC_CONTRACTS.md (hoặc GATEWAY_CONTROLLERS_ROUTING)
               │         ➔ Biết chính xác các RPC methods hoặc REST routes thuộc phạm vi phụ trách.
               │
               ▼ (Bước 4) Đọc file specs/05_DEV_VERIFICATION_CHECKLIST.md
               │         ➔ Lấy danh sách lệnh build và test để sẵn sàng nghiệm thu.
               │
               ▼ (Bước 5) Bắt tay vào thực hiện nhiệm vụ được giao!
```

---

## 3. CHECKLIST KIỂM CHỨNG TRƯỚC KHI BÀN GIAO (PRE-COMMIT SANITY CHECKLIST)

Trước khi thông báo hoàn thành nhiệm vụ với người dùng:

- [ ] **Lệnh biên dịch thành công 100% không cảnh báo nghiêm trọng**:
  ```bash
  dotnet build <SolutionName>.sln -c Release
  ```
- [ ] **Toàn bộ bài test tự động vượt qua 100%**:
  ```bash
  dotnet test <SolutionName>.sln -c Release
  ```
- [ ] **Kiểm tra trạng thái Git (Git Status Clean)**:
  - Không có file rác (`bin/`, `obj/`, `.idea/`) lọt vào staging.
  - Các file sửa đổi đúng phạm vi yêu cầu của task.
- [ ] **Đồng bộ hóa tài liệu**: Cập nhật lại các file `specs/` nếu có thay đổi về route, event, hoặc database schema.
