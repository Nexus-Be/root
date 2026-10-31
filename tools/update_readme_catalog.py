#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, glob, re

SERVICES = [
    'User', 'Catalog', 'Commerce', 'Auction', 'Fulfillment',
    'Wallet', 'Notification', 'Log', 'CheckHeal'
]

summary_rows = []
total_files = 0

detailed_sections = []

for svc in SERVICES:
    svc_dir = os.path.join('docs/api/B_none', svc)
    files = sorted(glob.glob(os.path.join(svc_dir, '*.md')))
    count = len(files)
    total_files += count
    
    summary_rows.append(f"| **{svc}** | [`docs/api/B_none/{svc}/`](./B_none/{svc}/) | **{count}** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |")
    
    ep_rows = []
    for f in files:
        fname = os.path.basename(f)
        with open(f, 'r', encoding='utf-8') as fp:
            content = fp.read()
        
        # Extract title line
        first_line = content.split('\n')[0].replace('# ', '').strip()
        ref_m = re.search(r'\*\*Mã tham chiếu Excel:\*\*\s*`?([^`\n]+)`?', content)
        ref_id = ref_m.group(1).strip() if ref_m else '-'
        desc_m = re.search(r'\*\*Mô tả chức năng:\*\*\s*(.+)', content)
        desc = desc_m.group(1).strip() if desc_m else '-'
        
        ep_rows.append(f"| [`{first_line}`](./B_none/{svc}/{fname}) | `{ref_id}` | {desc} |")
    
    ep_table = "\n".join([
        f"### {svc} Service ({count} endpoints)",
        "",
        "| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |",
        "|:---|:---:|:---|"
    ] + ep_rows)
    detailed_sections.append(ep_table)

summary_table = "\n".join([
    "| Phân Hệ (Service) | Thư Mục Tài Liệu (`B_none`) | Số API | Trạng Thái Vòng Đời |",
    "|:---|:---|:---:|:---|"
] + summary_rows + [
    f"| **TỔNG CỘNG** | **9 Phân Hệ Nghiệp Vụ** | **{total_files}** | **100% Đã sinh hồ sơ chuẩn hóa tại `B_none/`** |"
])

readme_template = f"""# 🌐 NEXUS E-COMMERCE ECOSYSTEM — FRONTEND API REFERENCE & INTEGRATION MANUAL

> **Dành cho:** Đội ngũ Frontend Developers (Web, Mobile App, Admin Dashboard)  
> **Cổng truy cập duy nhất (Single Gateway Entrypoint):** `http://localhost:8080`  
> **Giao thức:** 100% RESTful HTTP/JSON (Chuẩn RFC 9110)  
> **Interactive Swagger UI:** [http://localhost:8080/swagger](http://localhost:8080/swagger)  
> **Tổng số API đã chuẩn hóa:** `{total_files} endpoints`  
> **Trạng thái tài liệu:** ⏳ Quản lý hai trạng thái (`B_none/` chưa nghiệm thu vs `A_Active/` đã hoàn tất).
> **Ghi chú về YARP Gateway:** Gateway hoạt động như một Edge Reverse Proxy phi trạng thái (Stateless), bãi bỏ hoàn toàn Mock Mode, chịu trách nhiệm xác thực JWT Bearer, bảo vệ chống giả mạo header và điều phối chuyển tiếp xuống 9 microservices backend. Gateway không sở hữu database hay endpoint nghiệp vụ riêng.

---

## 📑 MỤC LỤC TỔNG QUAN

1. [Kiến Trúc & Quy Tắc Tích Hợp Dành Cho Frontend](#1-kiến-trúc--quy-tắc-tích-hợp-dành-cho-frontend)
2. [Cơ Chế Quản Lý Hồ Sơ Hai Trạng Thái (B_none vs A_Active)](#2-cơ-chế-quản-lý-hồ-sơ-hai-trạng-thái-b_none-vs-a_active)
3. [Quy Chuẩn Định Dạng Request / Response Envelope](#3-quy-chuẩn-định-dạng-request--response-envelope)
4. [Quy Chuẩn Bắt Lỗi & Xử Lý Ngoại Lệ (RFC 9110 Error Matrix)](#4-quy-chuẩn-bắt-lỗi--xử-lý-ngoại-lệ-rfc-9110-error-matrix)
5. [Quy Chuẩn Đặc Tả Enum Cho Frontend (Domain Enums Mapping)](#5-quy-chuẩn-đặc-tả-enum-cho-frontend-domain-enums-mapping)
6. [Hệ Thống Phân Quyền (RBAC Matrix)](#6-hệ-thống-phân-quyền-rbac-matrix)
7. [DANH MỤC 9 PHÂN HỆ API CHI TIẾT (MASTER CATALOG)](#7-danh-mục-9-phân-hệ-api-chi-tiết-master-catalog)
8. [DANH SÁCH CHI TIẾT TỪNG ENDPOINT THEO DỊCH VỤ](#8-danh-sách-chi-tiết-từng-endpoint-theo-dịch-vụ)

---

## 1. KIẾN TRÚC & QUY TẮC TÍCH HỢP DÀNH CHO FRONTEND

Hệ thống Nexus được xây dựng theo kiến trúc **Microservices phân tán** với **YARP API Gateway duy nhất (Port 8080)** làm cầu nối trung gian bảo vệ và điều phối:

```
[ Frontend Client (Web / Mobile App / Admin) ]
                     │  (HTTP/JSON)
                     ▼
       ┌───────────────────────────┐
       │   YARP Gateway (:8080)    │
       │   - Reverse Proxy         │
       │   - JWT Auth & RBAC       │
       │   - Rate Limiting         │
       │   - Zero DB / Stateless   │
       └─────────────┬─────────────┘
                     │ (Forward REST HTTP/JSON)
     ┌───────────────┼───────────────┬───────────────┐
     ▼               ▼               ▼               ▼
[ UserService ] [CatalogService][CommerceService][AuctionService]
  (:8001)         (:8002)         (:8003)         (:8005)
     ▼               ▼               ▼               ▼
[Fulfillment]   [Notification]   [WalletService]  [LogService]
  (:8006)         (:8007)         (:8008)         (:8004)
```

### 3 Nguyên tắc bất biến khi FE tích hợp:
1. **Frontend CHỈ gọi duy nhất vào Gateway Port 8080**: Tuyệt đối không gọi trực tiếp vào các cổng `8001`-`8009` của microservices nội bộ.
2. **100% Giao tiếp qua RESTful HTTP/JSON (100% Plural Domain Collections)**:
   - Sử dụng chuẩn HTTP Methods: `GET` (đọc), `POST` (tạo mới/hành động), `PUT` (thay thế toàn bộ), `PATCH` (cập nhật từng phần), `DELETE` (xóa).
   - Đường dẫn chuẩn hóa: 100% số nhiều (`/api/v1/users`, `/api/v1/products`, `/api/v1/categories`, `/api/v1/carts`, `/api/v1/orders`, `/api/v1/shipments`, `/api/v1/auctions`, `/api/v1/wallets`, `/api/v1/notifications`, `/api/v1/logs`).
   - Ngoại lệ đơn lẻ (Singleton): Duy nhất `/api/v1/me` và `/api/v1/auth`.
3. **Quy tắc đặt tên trường dữ liệu (Casing)**:
   - Request Body & Query Params: `camelCase` (ví dụ: `pageSize`, `productId`, `shippingAddress`).
   - Response Payload: `camelCase` (ví dụ: `accessToken`, `totalCount`, `isDefault`).
   - Enum & Status: Luôn tuần tự hóa thành chuỗi `PascalCase` ở API (ví dụ: `PendingPayment`, `Active`, `InTransit`).

---

## 2. CƠ CHẾ QUẢN LÝ HỒ SƠ HAI TRẠNG THÁI (B_none vs A_Active)

Mọi tài liệu API đều được quản lý nghiêm ngặt theo **Vòng đời 2 trạng thái**:
- **`docs/api/B_none/{{Service}}/{{Endpoint}}.md`**: API đang trong quá trình phát triển (WIP), mới lên đặc tả từ Excel hoặc chưa được Người dùng (Sếp) kiểm thử thực tế và ký duyệt.
- **`docs/api/A_Active/{{Service}}/{{Endpoint}}.md`**: API đã hoàn thiện 100%, vượt qua tất cả unit/integration tests, Gateway route thông suốt và được Người dùng nghiệm thu chính thức.

> ⚠️ **Quy tắc di chuyển:** Tuyệt đối cấm tự ý chuyển file từ `B_none` sang `A_Active` nếu chưa có sự xác nhận rõ ràng của Người dùng (Human Approval).

---

## 3. QUY CHUẨN ĐỊNH DẠNG REQUEST / RESPONSE ENVELOPE

Mọi phản hồi từ Gateway đều được bọc trong một **Vỏ bọc chuẩn hóa (Standard Envelope)**:

### 3.1 Đối tượng đơn lẻ (`ApiResponse<T>`)
```typescript
interface ApiResponse<T> {{
  success: boolean;       // Luôn là true nếu HTTP Status 2xx
  statusCode: number;     // Mã HTTP (200, 201...)
  message: string;        // Thông điệp tiếng Anh chuẩn Sentence case
  data: T;                // Dữ liệu nghiệp vụ trả về
  traceId: string;        // Mã trace chuẩn W3C Distributed Tracing
  timestamp: string;      // Thời gian server (ISO 8601 UTC)
}}
```

### 3.2 Danh sách có phân trang (`ApiResponse<PagedData<T>>`)
```typescript
interface PagedData<T> {{
  items: T[];             // Mảng các bản ghi
  pagination: {{
    pageIndex: number;    // Trang hiện tại (bắt đầu từ 1)
    pageSize: number;     // Số phần tử trên 1 trang
    totalCount: number;   // Tổng số bản ghi thỏa mãn điều kiện
    totalPages: number;   // Tổng số trang
    hasPreviousPage: boolean; // Có trang trước không
    hasNextPage: boolean;     // Có trang kế tiếp không
  }};
}}
```

### 3.3 Thao tác không trả về dữ liệu (`204 NoContent`)
- Các thao tác như `DELETE` hoặc cập nhật không cần payload trả về sẽ trả về mã HTTP `204 NoContent` với Body rỗng.

---

## 4. QUY CHUẨN BẮT LỖI & XỬ LÝ NGOẠI LỆ (RFC 9110 ERROR MATRIX)

Toàn bộ lỗi từ hệ thống Nexus đều tuân thủ chặt chẽ tiêu chuẩn **RFC 9110 ProblemDetails**:
- **errorCode**: `SCREAMING_SNAKE_CASE` (ví dụ: `VAL_INVALID_INPUT`, `USER_NOT_FOUND`, `ORDER_NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`).
- **message**: 100% tiếng Anh Sentence case (ví dụ: `"Order not found with the specified ID."`).

---

## 5. QUY CHUẨN ĐẶC TẢ ENUM CHO FRONTEND (DOMAIN ENUMS MAPPING)

Mọi tài liệu API đều chỉ rõ từng trường enum trong JSON Payload:
1. **Tên trường Payload (JSON Field)**: Tên thuộc tính trong JSON (ví dụ: `status`, `paymentMethod`, `gender`).
2. **Kiểu C# Enum**: Tên kiểu strongly-typed trong backend (ví dụ: `OrderStatus`, `UserStatus`).
3. **Giá trị DB (integer)**: Số nguyên lưu trong PostgreSQL (0, 1, 2...).
4. **Giá trị API (string PascalCase)**: Chuỗi JSON gửi nhận (`"PendingPayment"`, `"Active"`).
5. **Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend**: Ý nghĩa thực tế và màu badge gợi ý (Warning vàng, Success xanh, Danger đỏ, Muted xám).

---

## 6. HỆ THỐNG PHÂN QUYỀN (RBAC MATRIX)

- `AllowAnonymous` / `Guest`: Chưa đăng nhập (Xem sản phẩm, danh mục, đấu giá, đăng ký tài khoản).
- `Buyer`: Người mua hàng (Quản lý giỏ hàng, đặt hàng, nạp tiền ví, đặt giá đấu).
- `Seller`: Người bán hàng (Đăng bán sản phẩm, mở phiên đấu giá, duyệt đơn con, quản lý kho).
- `StaffOrAdmin`: Nhân viên hỗ trợ và quản trị viên (Duyệt hồ sơ Seller, xử lý tố cáo).
- `Admin`: Toàn quyền hệ thống (Phân quyền, cấu hình hệ thống, kiểm toán).

---

## 7. DANH MỤC 9 PHÂN HỆ API CHI TIẾT (MASTER CATALOG)

{summary_table}

---

## 8. DANH SÁCH CHI TIẾT TỪNG ENDPOINT THEO DỊCH VỤ

{chr(10).join(detailed_sections)}

---

## 9. LIÊN HỆ & HỖ TRỢ KỸ THUẬT

- **API Gateway Swagger UI**: [http://localhost:8080/swagger](http://localhost:8080/swagger)
- **Kiểm tra sức khỏe hệ thống (CheckHeal)**: `GET http://localhost:8080/api/v1/healthcheck/status`
- **Mẫu văn bản tài liệu API chuẩn**: Xem tại `docs/api/API_DOC_TEMPLATE.md`
"""

with open('docs/api/README.md', 'w', encoding='utf-8') as f:
    f.write(readme_template)

print(f"Hoàn tất cập nhật docs/api/README.md với {total_files} endpoints!")
