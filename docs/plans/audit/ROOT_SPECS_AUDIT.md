# AUDIT — Root `specs/` (6 file hợp đồng hệ thống)

**Phạm vi:** `specs/00_MASTER_SYSTEM_ARCHITECTURE.md`, `01_SERVICE_CATALOG_PORT_MAP.md`, `02_INTER_SERVICE_COMMUNICATION_MATRIX.md`, `03_SECURITY_RBAC_DATA_GOVERNANCE.md`, `04_SHARED_CONTRACTS_REGISTRY.md`, `05_AI_AGENT_ORCHESTRATION_GUIDELINES.md`.
**Câu hỏi:** spec có phải “thành phần sự thật” không, hay là tài liệu ước muốn?

## 0. Kết luận

`specs/01` **là sự thật** (port/DB name khớp 100% với compose + Dockerfile + appsettings). `specs/03` **gần sự thật** (envelope/error code khớp code Gateway). `specs/02` và `specs/04` **KHÔNG phải sự thật** — chúng mô tả hệ thống chưa được xây: 13/13 luồng gRPC trong matrix không tồn tại đầu nhận, 6/8 event không tồn tại trong code.

Nguy hiểm nhất: `specs/04` tuyên bố Gateway proto là **Single Source of Truth**, nhưng **file proto ở Gateway chỉ có 1/9 service** (5 rpc) trong khi bản ở service có 9 service (~60 rpc). Nếu ai làm đúng quy trình ghi trong spec (sửa Gateway → copy sang service) thì sẽ **xoá 55 rpc** khỏi hệ thống.

## 1. Bảng đối chiếu từng file

| File | Kết quả | Bằng chứng |
|---|---|---|
| `00_MASTER_SYSTEM_ARCHITECTURE.md` | ⚠️ Đúng phần C4/bounded context, sai phần “trạng thái” | 8 bounded context ↔ 8 service ✅; nhưng mô tả như hệ đã chạy, thực tế 5/8 service không có bề mặt |
| `01_SERVICE_CATALOG_PORT_MAP.md` | ✅ **Sự thật** | Port `8080` (Gateway) và `8001–8008` (Services), DB `5433–5440`, tên DB `usermanagement_db/category_db/commerce_db/log_db/auction_db/fulfillment_db/notification_db/wallet_db` khớp compose + `.env` + `appsettings` 9/9 |
| `02_INTER_SERVICE_COMMUNICATION_MATRIX.md` | ❌ Không phải sự thật | 13 dòng matrix: **7 dòng gRPC** (Gateway → 7 service) nhưng Gateway chỉ có **1** gRPC client (`users`); **6 dòng RabbitMQ** nhưng chỉ 3 consumer + 2 publisher thật tồn tại |
| `03_SECURITY_RBAC_DATA_GOVERNANCE.md` | ⚠️ Gần đúng | Envelope `ApiResponse<T>`/`ApiErrorResponse` + RFC 9110 khớp `ApiResponseFactory`/`ApiErrorResponse`; **nhưng** RBAC lệch: spec khai “5 cấp độ” nhưng bảng có 6 dòng (`anonymous, buyer, seller, staff, admin, gateway-admin`) còn `UserSeedData` chỉ seed **4** role (`Buyer`, `Seller`, `Support Staff`, `Administrator`) → tên `staff` vs `Support Staff`, và `gateway-admin` không phải role DB; **và** `AuthMode: Enforce` + JWT validation chưa có token nào được phát (User không phát JWT) → toàn bộ nhánh auth của Gateway không thể chạy |
| `04_SHARED_CONTRACTS_REGISTRY.md` | ❌ **Sai hướng sự thật** | Tuyên bố SoT = `ApiGateway/Nexus.Gateway/Contracts/shop.proto`; thực tế file đó **chỉ có `UsersApi` 5 rpc**, thiếu 8 service còn lại; bản đầy đủ nằm rải ở `User/Log/Wallet/*.Api/Contracts/shop.proto` với 3 hash khác nhau |
| `05_AI_AGENT_ORCHESTRATION_GUIDELINES.md` | ⚠️ Trùng lặp | Nội dung 6 nguyên tắc **trùng 100%** với `AGENTS.md` (và `CLAUDE.md`) → 3 bản của cùng một luật, sửa 1 bản là lệch |

## 2. Findings

| ID | Sev | Finding | Bằng chứng | Hướng xử lý |
|---|---|---|---|---|
| SP-01 | **P0** | `specs/04` chỉ sai nguồn sự thật proto, dẫn tới quy trình sẽ phá contract | Gateway proto 5 rpc (chỉ `UsersApi`) vs service proto 9 service/~60 rpc | Đổi SoT về `specs/proto/` ở root (hoặc 1 submodule `Nexus.Contracts`), generate/copy bằng script, **cấm sửa tay 4 bản** |
| SP-02 | **P0** | `specs/02` là ma trận của hệ thống tương lai, không phải hệ thống hiện tại | Matrix khai 7 cặp gRPC; `GrpcClientsExtension.cs:12` chỉ 1 cặp thật | Đánh dấu rõ “Mục tiêu” vs “Hiện trạng”, hoặc tách 2 file: `02A_AS_IS` / `02B_TO_BE` |
| SP-03 | **P1** | Matrix khai rpc không tồn tại: `CatalogService.AdjustInventory` (thuộc Fulfillment), `UserService.CreateUser` (không có trong Gateway proto) | `specs/02:27`, `specs/02:21`; grep Gateway proto = 0 | Sửa theo quyết định “kho thuộc Fulfillment” + chốt rpc user |
| SP-04 | **P1** | `specs/03` mô tả 2 trạng thái Gateway (Enforce/Bypass) là “đang chạy”, nhưng không có JWT phát ra → Enforce chặn mọi request | `appsettings.json` `AuthMode: "Enforce"`; `grep System.IdentityModel.Tokens.Jwt` trong User = 0 | Hoặc implement phát JWT ở User, hoặc để `Bypass` trong dev và ghi rõ trong spec |
| SP-05 | **P1** | 3 bản luật (`AGENTS.md` = `CLAUDE.md` = `specs/05`) | `md5sum` root: `88e18fb2088044c9b880f5c2a348c271` cho cả 2 file; `specs/05` cùng 6 mục | `CLAUDE.md` → symlink hoặc 1 dòng `@AGENTS.md`; `specs/05` giữ làm bản giải thích chi tiết |
| SP-06 | **P2** | `specs/00` không có bảng “trạng thái triển khai” nên người đọc không biết phần nào có thật | — | Thêm cột `Status: implemented / spec-only` cho từng bounded context |

## 3. Việc phải làm trước khi coi root specs “xong”

1. `SP-01` — chốt lại nguồn sự thật proto **trước khi** sửa bất kỳ proto nào (nếu không, mọi sửa đổi đều làm drift nặng thêm).
2. `SP-02`/`SP-03` — tách “hiện trạng” và “mục tiêu” trong `specs/02`.
3. `SP-05` — gộp 3 bản luật về 1 nguồn.
