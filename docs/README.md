# TÀI LIỆU KỸ THUẬT HỆ THỐNG NEXUS (NEXUS SYSTEM DOCUMENTATION)

Chào mừng bạn đến với trung tâm tài liệu kỹ thuật của hệ sinh thái **Nexus Microservices Backend (.NET 8)**.

---

## 1. CẤU TRÚC TÀI LIỆU TẠI THƯ MỤC GỐC (ROOT DOCUMENTATION)

Để đảm bảo việc phân tách rõ ràng giữa **Quyết định kiến trúc dài hạn (Architecture Decision Records)**, **Bộ đặc tả kỹ thuật (Technical Specifications)** và **Hướng dẫn vận hành (Operations & Guides)**, tài liệu tại root được tổ chức theo cấu trúc chuẩn:

```
Nexus-Be/
├── docs/                                   # Tài liệu kỹ thuật tổng thể cho đội ngũ phát triển & Stakeholders
│   ├── README.md                           # Trang chủ hướng dẫn tài liệu
│   └── adr/                                # Bộ lưu trữ các Quyết định Kiến trúc (ADR)
│       └── ADR.md                          # 15 Quyết định Kiến trúc Bất biến của toàn hệ thống
│
├── specs/                                  # Bộ Đặc tả Kỹ thuật Trung tâm (Dành cho Developer & AI Coding Agents)
│   ├── README.md                           # Master Spec Kit Index
│   ├── 00_MASTER_SYSTEM_ARCHITECTURE.md    # Sơ đồ C4 Container, Bounded Contexts
│   ├── 01_SERVICE_CATALOG_PORT_MAP.md      # Quy hoạch cổng mạng & Database Ports
│   ├── 02_INTER_SERVICE_COMMUNICATION_MATRIX.md # gRPC vs RabbitMQ MassTransit, Checkout Saga
│   ├── 03_SECURITY_RBAC_DATA_GOVERNANCE.md # JWT Lifecycle, Ma trận RBAC, Gateway State
│   ├── 04_SHARED_CONTRACTS_REGISTRY.md     # shop.proto (Single Source of Truth), Domain Events
│   └── 05_AI_AGENT_ORCHESTRATION_GUIDELINES.md # Quy chuẩn chống ảo giác, Sanity Checklist
│
└── src/Services/
    ├── ApiGateway/                         # API Gateway (Cổng tiếp nhận duy nhất)
    │   ├── DEV_GUIDE.md                    # Hướng dẫn tạo API mới tinh gọn trong 3 bước
    │   ├── CONFIG_REFERENCE.md             # Tra cứu cấu hình runtime
    │   └── ADR.md                          # ADR cục bộ của Gateway
    │
    └── [Service Repositories: User, Catalog, Commerce, Auction, Log, Fulfillment, Notification, Wallet]/
        └── specs/                          # Spec Kit riêng biệt của từng Microservice
```

---

## 2. TRUY CẬP NHANH CÁC TÀI LIỆU TRỌNG TÂM

0. **Hướng Dẫn Bước Kế Tiếp & Checklist Triển Khai Microservices:**  
   👉 Xem chi tiết tại [docs/NEXT_STEPS_AND_CHECKLIST.md](NEXT_STEPS_AND_CHECKLIST.md)  
   *(Kim chỉ nam hành động: Lộ trình 4 giai đoạn, checklist 7 bước code service, quy trình test tích hợp với Gateway)*

1. **Bộ 15 Quyết định Kiến trúc Hệ thống (System ADRs):**  
   👉 Xem chi tiết tại [docs/adr/ADR.md](adr/ADR.md)  
   *(Bao gồm: .NET 8, Clean Architecture, No-Repository, gRPC, RabbitMQ MassTransit, Checkout Saga, Dual-mode Gateway, Zero-validation Controller, Redis Rate Limit...)*

2. **Quy hoạch Cổng mạng & Cơ sở dữ liệu (Ports & DBs):**  
   👉 Xem tại [specs/01_SERVICE_CATALOG_PORT_MAP.md](../specs/01_SERVICE_CATALOG_PORT_MAP.md)

3. **Hướng dẫn cho AI Coding Agents (Anti-Hallucination Guidelines):**  
   👉 Xem tại [specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md](../specs/05_AI_AGENT_ORCHESTRATION_GUIDELINES.md)

4. **Hướng dẫn phát triển Endpoint mới trên Gateway (Dev Guide):**  
   👉 Xem tại [src/Services/ApiGateway/DEV_GUIDE.md](../src/Services/ApiGateway/DEV_GUIDE.md)
