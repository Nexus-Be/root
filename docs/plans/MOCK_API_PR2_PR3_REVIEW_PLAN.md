# RÀ SOÁT 2 PR MOCK API (AUCTION / CATALOG) & KẾ HOẠCH XỬ LÝ

> **Trạng thái:** ⚠️ MỘT PHẦN — đây là **báo cáo rà soát + kế hoạch**, chưa sửa code.
> **Nguồn sự thật:** base `6041693` (main/dev/mock trùng nhau) · `refs/pull/2/head = ea51527` (auction) · `refs/pull/3/head = 88555ce` (catalog) · hợp đồng `docs/excel/flow_mock_excel.xlsx` (F2 rows 102–127, F3 rows 130–148).
> **Ngày đo:** 2026-10-25 · **Môi trường:** KHÔNG có `dotnet` SDK trên máy ⇒ chưa build/test được, mọi kết luận dưới đây là kiểm chứng tĩnh (đọc diff + đối chiếu file).

---

## 1. Mục tiêu

1. Đánh giá PR#2 (`feat/auction-mock-api`) và PR#3 (`feat/catalog-mock-api`) — cả hai chỉ tạo mock API tại ApiGateway — theo 3 tiêu chí:
   - (a) có tuân **quy chuẩn mock API của Gateway** không (`MOCK_GUIDE.md` + `specs/02`, `specs/04`),
   - (b) **request/response payload** có đúng hợp đồng không,
   - (c) **URL endpoint** có đúng hợp đồng không.
2. Chia việc thành task nhỏ, có thứ tự và tiêu chí nghiệm thu, để merge được từng PR.

---

## 2. Phạm vi & bối cảnh

| Hạng mục | Giá trị |
|---|---|
| Repo | [src/Services/ApiGateway](../../src/Services/ApiGateway) |
| Base | `6041693` (branch `mock`/`dev`/`main` trùng nhau) |
| PR#1 | `dd060eb` — bản auction sớm, **đã bị PR#2 thay thế**, không cần review riêng |
| PR#2 | `ea51527` — 46 file, +2945/−1388 (code: 1 controller 587 dòng, 1 proto 345 dòng, 1 validation 136 dòng, 1 DTO 36 dòng, 1 test 176 dòng, 16 seed) |
| PR#3 | `88555ce` — 19 file, +747/−27 (code: 1 controller 307 dòng, 1 proto 141 dòng, 1 DTO 35 dòng, 1 test 81 dòng, 8 seed) |
| Hợp đồng | F2 “quản lý sản phẩm” = **26 endpoint** (rows 102–127); F3 “đấu giá” = **19 dòng** (16 REST + 1 gRPC + 2 internal, rows 130–148) |
| Trạng thái service | `auction: Mock` **đã có sẵn từ base**; `catalog: Real→Mock` do PR#3 đổi (đúng quy trình) |

---

## 3. Kết luận tổng hợp (trả lời trực tiếp 3 câu hỏi)

| Tiêu chí | PR#2 — Auction | PR#3 — Catalog |
|---|---|---|
| (a) Tuân quy chuẩn mock API | 🟡 **Đạt phần lõi** — đúng mô hình “Controller + `Seeds/{service}/{operation}.json`”, đi qua `IGatewayDispatcher` (không tự branch Mock/Real), có `[BackendTag]`, `[EnableRateLimiting]`, `GatewayPolicies.*`, validation helper, 17 test. Vướng: csproj bị sửa dòng 1, `GrpcServices="Both"`, và **kéo theo 23 file `.md` + xóa 4 README** không liên quan. | 🔴 **Không đạt** — đúng mô hình dispatcher, nhưng gộp 3 resource vào 1 controller để lại 2 stub mồ côi (trái `specs/02 §3`), dùng `[Authorize(Roles=…)]` thay `GatewayPolicies.*`, không có validation helper, đổi `global.json` (chính sách SDK toàn repo) không liên quan feature. |
| (b) Request/response payload | 🟢 **Đúng** — 16/16 seed khớp **chính xác** danh sách field của hợp đồng F3 (camelCase, đủ field, không thừa). Khác biệt duy nhất là envelope `ApiResponse` của Gateway (xem D2) — khác biệt **có chủ trương**, áp dụng cho cả 9 service. | 🔴 **Sai** — 9 route có tồn tại nhưng shape sai (xem §5.2): thiếu `Variants[]`/`Specifications` ở POST product, `IsDisabled` ngược nghĩa `IsActive` ở PUT category, `data.data` double-nesting, `id` thay `ProductId/CategoryId`, `status:"Active"` thay `ACTIVE`, response list thiếu 8 field (`SaleType/MinPrice/MaxPrice/PrimaryImageUrl/AvgRating/AuctionStatus/IsOpen/IsSold`), DELETE trả 200+body thay vì 204. |
| (c) URL endpoint | 🟢 **Đúng 16/16** route REST của F3, byte-identical path + method. 3 dòng còn lại (`AUC-20` gRPC, `AUC-34`/`AUC-35` internal) **ngoài phạm vi gateway** — cần ghi nhận thành quyết định, không phải lỗi. | 🔴 **Sai 0/26** — toàn bộ 13 route nằm dưới segment `/api/v1/catalog/*` mà hợp đồng **không có**; 17/26 endpoint của F2 **không tồn tại**; 2 endpoint **bịa ra** (`inventory/{productId}`, `inventory/{productId}/adjust`); 1 endpoint thừa (`products/seller/{sellerId}`); 1 sai method (`PUT` thay `PATCH`). |

**Kết luận:** PR#2 **có thể merge sau khi dọn** (~6 task nhỏ). PR#3 **không thể merge** — cần làm lại phần lớn (`proto` + `DTO` + `route` + `seed`), giữ lại khung dispatcher và ý tưởng `ProductsController`.

---

## 4. PR#2 — Auction: chi tiết

### 4.1 URL — khớp 16/16

| Hợp đồng | Method/Path tại [AuctionController.cs](../../src/Services/ApiGateway/Nexus.Gateway/Controllers/AuctionController.cs) | Auth |
|---|---|---|
| AUC-01 `GET /api/v1/auctions` | `[HttpGet("auctions")]` L55 | anon |
| AUC-02 `GET /api/v1/auctions/{auctionId}` | `[HttpGet("auctions/{auctionId}")]` L82 | anon |
| AUC-03 `GET /api/v1/auctions/{auctionId}/bids` | L109 | anon |
| AUC-07 `POST /api/v1/auctions/{auctionId}/bids` | L151 | `Authenticated` + bắt buộc `Idempotency-Key`/`If-Match` |
| AUC-08 `GET /api/v1/me/bids` | L190 | `Authenticated` |
| AUC-09 `GET /api/v1/auctions/{auctionId}/result` | L223 | `Authenticated` |
| AUC-10 `POST /api/v1/auctions` | L255 | `Seller`, 201 |
| AUC-11 `PUT /api/v1/auctions/{auctionId}` | L298 | `Seller` |
| AUC-12 `POST /api/v1/auctions/{auctionId}/cancel` | L337 | `Seller`, body optional |
| AUC-13 `POST /api/v1/auctions/{auctionId}/recreate` | L376 | `Seller`, 201 |
| AUC-14 `GET /api/v1/seller/auctions` | L417 | `Seller` |
| AUC-18 `GET /api/v1/auctions/{auctionId}/status-history` | L447 | `Staff` |
| AUC-15 `POST /api/v1/admin/auctions/{auctionId}/force-cancel` | L478 | `Admin` |
| AUC-19 `GET /api/v1/admin/auctions/{auctionId}/saga` | L510 | `Staff` |
| AUC-16 `GET /api/v1/admin/auction-configs` | L533 | `Admin` |
| AUC-17 `PUT /api/v1/admin/auction-configs/{key}` | L560 | `Admin` |

### 4.2 Payload — khớp 16/16 seed

Đã đối chiếu từng seed với cột *Response* của hợp đồng: `auctions.json` (12 field/item ↔ AUC-01), `auction.json` (25 field ↔ AUC-02 khớp tuyệt đối), `auction-bids.json` (`sequenceNo`… ↔ AUC-03), `auction-bid-place.json` (9 field ↔ AUC-07), `me-bids.json` (10 ↔ AUC-08), `auction-result.json` (12 ↔ AUC-09), `auction-create.json` (13 ↔ AUC-10), `auction-update.json` (7 ↔ AUC-11), `auction-cancel.json` (5 ↔ AUC-12), `auction-recreate.json` (10 ↔ AUC-13), `seller-auctions.json` (13, có `createdAt` ↔ AUC-14), `auction-force-cancel.json` (6 ↔ AUC-15), `auction-configs.json` (6 ↔ AUC-16), `auction-config-update.json` (8 ↔ AUC-17), `auction-status-history.json` (6/item ↔ AUC-18), `auction-saga.json` (6 ↔ AUC-19). Tên field trong `auction.proto` là `snake_case`, JSON name là `camelCase`; `JsonParser` chấp nhận cả hai nên seed parse sạch.

### 4.3 Nợ kỹ thuật phải dọn trước khi merge

| Mức | Vấn đề | Vị trí |
|---|---|---|
| P1 | Dòng 1 của csproj bị ghi đè thành `\uFEFF` + 4 dấu cách trước `<Project …>` (XML vẫn parse được nên không làm build fail, nhưng sai chuẩn, phá diff/tooling) | [Nexus.Gateway.csproj](../../src/Services/ApiGateway/Nexus.Gateway/Nexus.Gateway.csproj) dòng 1 |
| P1 | `GrpcServices="Both"` cho `auction.proto` — gateway chỉ là client; indent `<Protobuf>` bằng tab+2 space; thêm `<Folder Include="Dtos\Auction\" />`+`<Folder Include="Seeds\auction\" />` vô nghĩa | cùng file, item group `Protobuf` |
| P1 | **1236 dòng docs bị viết lại** (`ADR.md`, `AGENTS.md`, `CLAUDE.md`, `CONFIG_REFERENCE.md`, `DEV_GUIDE.md`, `MOCK_GUIDE.md`, `PLAN.md`, `README.md`, `SETUP_GUIDE_SERVICES.md`, `dac_ta.md`, `input.md`, `specs/00..05`, `specs/README.md`) và **xóa 4 README** (`Mocks/README.md`, `Seeds/{cart,orders,products}/README.md`) — che khuất thay đổi thật khi review | 23 file |
| P2 | XML doc của controller ghi sai nguồn: “`apicontract_Auction.xlsx`, AUC-01 đến AUC-19” — file không tồn tại, đúng ra là `flow_mock_excel.xlsx` và F3 có thêm AUC-20/34/35 | controller dòng ~16 |
| P2 | Seed dùng tiếng Việt (`productName`, `description`) trong khi `MOCK_GUIDE` yêu cầu dữ liệu seed tiếng Anh | 16 seed |
| P2 | Chỉ có seed happy-path ⇒ mock không mô phỏng được các nhánh lỗi mà hợp đồng liệt kê (404 `AUCTION_NOT_FOUND`, 409 `PRODUCT_ALREADY_IN_AUCTION`, 422 `INVALID_SCHEDULE`…); test cũng chỉ phủ happy path + 400 | `Seeds/auction/`, `AuctionMockTests.cs` |
| P2 | Không có route `AUC-34`/`AUC-35` (`/internal/v1/...`) và `AUC-20` gRPC — **hợp lý** nhưng phải ghi thành quyết định “ngoài phạm vi gateway” ở `specs/02` để lần sau không bị coi là thiếu | `specs/02` |

---

## 5. PR#3 — Catalog: chi tiết

### 5.1 Đối chiếu 26 endpoint của F2

Toàn bộ action nằm dưới `[Route("api/v1/catalog")]` — **hợp đồng không có segment `catalog`** (segment này là di sản của 3 stub có từ base: `ProductsController` `api/v1/catalog/products`, `CategoriesController` `api/v1/catalog/categories`, `InventoryController` `api/v1/catalog/inventory`).

| # | Hợp đồng F2 | PR#3 | Kết luận |
|---|---|---|---|
| 1 | `GET /api/v1/product/search` | — | ❌ thiếu |
| 2 | `GET /api/v1/product/{productId}` | `GET /api/v1/catalog/products/{id}` L64 | ⚠️ sai prefix + số nhiều + shape |
| 3 | `POST /api/v1/products` | `POST /api/v1/catalog/products` L102 | ⚠️ sai prefix + body thiếu `Variants[]`/`Specifications` |
| 4 | `PATCH /api/v1/product/{productId}` | `PUT /api/v1/catalog/products/{id}` L130 | ⚠️ sai method + prefix |
| 5 | `DELETE /api/v1/product/{productId}` (204) | `DELETE …/products/{id}` L156 (200+body) | ⚠️ sai prefix + status code |
| 6–8 | `POST/GET/DELETE /api/v1/product/{productId}pics` | — | ❌ thiếu 3 |
| 9 | `GET /api/v1/products/{productId}/totalRating` | — | ❌ thiếu |
| 10 | `GET /api/v1/products/{productId}/rating` | — | ❌ thiếu |
| 11 | `PATCH /api/v1/product/{productId}/status` | — | ❌ thiếu |
| 12 | `POST /api/v1/inventory/stock-in` | — | ❌ thiếu |
| 13 | `POST /api/v1/product/{productId}/variants` | — | ❌ thiếu |
| 14–17 | `DELETE/PATCH/GET /api/v1/variant/{variantId}`, `POST …/stock-in` | — | ❌ thiếu 4 |
| 18 | `GET /api/v1/categories` | `GET /api/v1/catalog/categories` L176 | ⚠️ sai prefix |
| 19 | `POST /api/v1/categories` (201 → `{CategoryId, Level}`) | L205 → trả full `CategoryItem` | ⚠️ sai prefix + shape + body thừa `Level` |
| 20 | `PUT /api/v1/categories/{categoryId}` (body `…, ParentId, SortOrder, IsActive`) | L229 (body `…, Level, SortOrder, IsDisabled`) | ⚠️ sai prefix + **`IsDisabled` ngược nghĩa `IsActive`**, thiếu `ParentId` |
| 21 | `DELETE /api/v1/categories` (204, **không path param**) | `DELETE …/categories/{id}` L253 (200+body) | ⚠️ thêm path param + status code |
| 22 | `GET /api/v1/categories/{categoryId}` (→ `{Category, Parent, Children}`) | L189 (→ `{data:{…}}`) | ⚠️ sai prefix + shape |
| 23 | `POST /api/v1/product/auction` (CAT-43) | — | ❌ thiếu |
| 24 | `GET /api/v1/product/aucction/search` | — | ❌ thiếu |
| 25 | `GET /api/v1/product/auctions` | — | ❌ thiếu |
| 26 | `GET /api/v1/product/auction/{auctionId}` | — | ❌ thiếu |

**Tổng:** 0/26 đúng · 9 route lệch · 17 route thiếu · 3 route **không có trong hợp đồng**: `GET products` (list), `GET products/seller/{sellerId}`, `GET inventory/{productId}`, `POST inventory/{productId}/adjust`.

### 5.2 Payload sai cụ thể

| Vấn đề | Chi tiết |
|---|---|
| Double nesting | `ProductResponse{ ProductItem data = 1; }` + `CategoryResponse{ CategoryItem data = 1; }` ⇒ envelope thành `{success, data:{data:{…}}}`. Không endpoint nào khác của gateway có shape này. |
| Thiếu field bắt buộc ở request | CAT-01 yêu cầu `Variants[]` (bắt buộc ≥1, đúng 1 default) và `Specifications`; DTO `CreateProductDto` chỉ có `SellerId, CategoryId, Name, Description, Brand, Price, Currency`. |
| Seller từ body | `CreateProductDto.SellerId` lấy từ body ⇒ **spoofable**; phải lấy từ claim `sub` như `me/bids` của PR#2. |
| Ngược nghĩa cờ | `UpdateCategoryDto.IsDisabled` vs hợp đồng `IsActive`; seed `categories.json`/`category.json` cũng dùng `is_disabled`. Client gửi `isActive:true` sẽ **không bind** ⇒ luôn hiểu là “đang bật”. |
| Tên field | `ProductItem.id` / `CategoryItem.id` vs hợp đồng `ProductId` / `CategoryId`; `InventoryResponse.product_id` vs `SkuId`. |
| Thiếu 8 field ở list | `products.json` item chỉ có `id, seller_id, category_id, name, description, brand, price, currency, status` — hợp đồng `product/search` cần thêm `SaleType, MinPrice, MaxPrice, PrimaryImageUrl, AvgRating, AuctionStatus, IsOpen, IsSold`. |
| Status vocabulary | Seed `"Active"` vs hợp đồng `DRAFT\|ACTIVE\|INACTIVE`. |
| DELETE | Hợp đồng `204 No Content`; PR trả 200 + body `{success,id}`. |
| Precision | `decimal Price` → `(double)` khi build proto (mất chính xác VND); base đã có `Common/MoneyPrecision.cs`. |
| Seed lỗi copy-paste | `Seeds/catalog/category-delete.json` trả `id: "2222…0001"` — **id của product**, không phải category. |
| Seed trùng | `Seeds/products/products.json` trùng nguyên văn `Seeds/catalog/products.json`; `MockDataMapper.ResolveSeedFilePath` ưu tiên `Seeds/{service}/…` nên file kia là rác. |
| Seed dùng chung | `inventory.json` dùng cho cả GET và `adjust` ⇒ `adjust` không bao giờ phản ánh `quantityChange`. |
| Ngôn ngữ | Toàn bộ seed tiếng Việt, `MOCK_GUIDE` yêu cầu tiếng Anh. |

### 5.3 Vi phạm convention

1. **Gộp 3 resource vào `ProductsController`** trong khi `specs/02 §3` quy định mỗi controller một resource; `CategoriesController` và `InventoryController` vẫn còn nhưng **0 action** (mồ côi, route chết).
2. `[Authorize(Roles = "seller,admin")]` / `"admin,staff"` / `"admin"` thay cho `GatewayPolicies.Seller/Staff/Admin`. Khác biệt thực chất: policy có `RequireClaim("sub")`, `Roles` **không** ⇒ token thiếu `sub` vẫn qua.
3. Không có helper validation (`CatalogValidation`) ⇒ mã lỗi ngầm định, không map được `PRODUCT_NOT_FOUND`, `CATEGORY_NAME_DUPLICATED`, `CATEGORY_CYCLE`… như hợp đồng.
4. `global.json` đổi `rollForward: latestMinor → latestMajor` (và mất newline cuối), csproj thêm `<RollForward>LatestMajor</RollForward>` cho cả **test project** — thay đổi chính sách SDK toàn repo, không liên quan feature mock.
5. `Seeds/README.md` (đã có từ base) không được cập nhật cho catalog.

---

## 6. Quyết định phải chốt trước khi sửa (blocking)

| # | Câu hỏi | Đề xuất |
|---|---|---|
| D1 | Giữ hay bỏ segment `/catalog`? | **Bỏ** — theo hợp đồng F2 và để đồng nhất với F3 (`/api/v1/auctions`), đổi route 3 stub. |
| D2 | Response envelope: bare object (xlsx) hay `ApiResponse` (gateway)? | **Giữ `ApiResponse`** cho cả 9 service; ghi mapping vào `MOCK_GUIDE §4`: `items`→`data.items`, `page`→`data.pagination.pageIndex`, `pageSize`→`data.pagination.pageSize`, `total`→`data.pagination.totalCount`. |
| D3 | Casing: F2 ghi **PascalCase** (`Items`, `Page`, `Total`), F3 ghi **camelCase** (`items`, `page`, `total`) | **camelCase toàn hệ** (khớp gateway + F3 + `JsonFormatter`), sửa lại cột F2 trong xlsx. |
| D4 | Error body: `{Code, Message, Errors[]}` (xlsx) hay RFC-9110 `errorCode/detail/errors` (gateway) | **RFC-9110** theo `AGENTS.md §5`; giữ `errorCode` SCREAMING_SNAKE không tiền tố `ERR_`. |
| D5 | DELETE trả gì? | **204 No Content** theo hợp đồng (product, pics, category, variant) — bỏ `CatalogDeleteResponse`. |
| D6 | `DELETE /api/v1/categories` không path param nhưng cột Request lại ghi `Path: {categoryId}` | **Chốt `DELETE /api/v1/categories/{categoryId}`** và sửa xlsx (đang tự mâu thuẫn). |
| D7 | `GET /api/v1/product/aucction/search` (typo “aucction”) | **Sửa thành `/api/v1/product/auction/search`**, ghi vào changelog hợp đồng. |

---

## 7. Kế hoạch chia task

### 7.1 Nhánh A — PR#2 Auction (dọn để merge)

| ID | Việc | File | Nghiệm thu |
|---|---|---|---|
| A1 | Sửa csproj: khôi phục `<Project Sdk="Microsoft.NET.Sdk.Web">` ở dòng 1 (bỏ BOM/indent), `GrpcServices="Client"`, bỏ 2 `<Folder Include>` | `Nexus.Gateway.csproj` | `git diff` chỉ còn +1 dòng `<Protobuf Include="Contracts/auction.proto" …/>` |
| A2 | Tách doc churn: revert 23 file `.md` + 4 README về base, mở PR docs riêng | 27 file | PR#2 diff chỉ còn file code/seed/test |
| A3 | Sửa XML doc: nêu đúng `flow_mock_excel.xlsx` (F3), liệt kê 16 route, ghi rõ AUC-20/34/35 ngoài phạm vi gateway | `AuctionController.cs` | Không còn tham chiếu `apicontract_Auction.xlsx` |
| A4 | Chuyển seed sang tiếng Anh (giữ nguyên **tên field** và số lượng field) | `Seeds/auction/*.json` | `git diff` chỉ đổi value, không đổi key |
| A5 | (Tuỳ chọn, khuyến nghị) Thêm seed lỗi + test 404/409/422 | `Seeds/auction/`, `AuctionMockTests.cs` | ≥3 case lỗi xanh |
| A6 | Ghi mapping envelope/pagination + phạm vi AUC-20/34/35 vào `specs/02`,`specs/04` | `specs/*` | Tài liệu khớp code |

**Merge gate:** A1–A3 bắt buộc; A4–A6 nên có. Build + test + smoke 16 route.

### 7.2 Nhánh C — PR#3 Catalog (làm lại)

| ID | Việc | Phụ thuộc | Nghiệm thu |
|---|---|---|---|
| C0 | Chốt D1–D7, ghi vào `specs/04` | — | Có biên bản quyết định trong repo |
| C1 | Đổi route 3 stub về `/api/v1/products`, `/api/v1/categories`, `/api/v1/inventory`; tách action về đúng controller | — | Swagger hiện đúng 3 controller, không route chết |
| C2 | Viết lại `catalog.proto` theo F2: 26 endpoint, field `product_id/category_id/items/page/page_size/total`, **bỏ wrapper `data`**, thêm variants/pics/rating/status/stock-in/auction | C0 | Mỗi dòng F2 ↔ 1 rpc/message |
| C3 | Viết lại DTO request theo CAT-01/02/03/07/15/16/17 (`Variants[]`, `Specifications`, `ParentId`, `IsActive`) | C2 | Model binding đủ field, không có `IsDisabled` |
| C4 | Thêm `Common/CatalogValidation.cs` + mã lỗi (`VAL_INVALID_INPUT`, `PRODUCT_NOT_FOUND`, `CATEGORY_NAME_DUPLICATED`, `CATEGORY_HAS_PRODUCTS`, `SKU_CODE_DUPLICATED`…) | C3 | Mỗi mã lỗi trong F2 có test |
| C5 | `sellerId` lấy từ claim `sub`; `PATCH` thay `PUT`; `204` cho DELETE; `[Authorize(GatewayPolicies.*)]` | C3 | Không còn `Roles=` thô, không còn seller trong body |
| C6 | Bỏ double-nesting (`ProductResponse` trả `ProductItem` trực tiếp) | C2 | Response detail không còn `data.data` |
| C7 | Seed: 26 operation mới, tiếng Anh, sửa `category-delete` id, xóa `Seeds/products/`, tách seed `inventory-adjust` | C2 | Không seed trùng, không id sai |
| C8 | `MoneyPrecision` cho price; status chỉ nhận `DRAFT|ACTIVE|INACTIVE` | C3 | Test giá 12.000.000,50 không lệch |
| C9 | Test: happy + 400/403/404/409 + shape envelope | C5,C6 | ≥20 case xanh |
| C10 | Hoàn nguyên `global.json` + `<RollForward>` (hoặc tách PR riêng) | — | `git diff global.json` rỗng |
| C11 | Cập nhật `specs/02` (bảng controller), `specs/04`, `Seeds/README.md` | C1 | Tài liệu khớp code |

**Merge gate:** C0–C2 trước (chốt hợp đồng), rồi C3–C9; C10–C11 trước khi merge.

---

## 8. Kiểm chứng

```bash
cd src/Services/ApiGateway
dotnet build ApiGateway.sln -c Release      # 0 error
dotnet test  ApiGateway.sln -c Release      # 100% pass
```

Smoke tay (Mock mode) — kỳ vọng **200 + `X-Gateway-Mode: Mock`**:

```bash
G=http://localhost:8000
curl -s -D- "$G/api/v1/auctions?page=1&pageSize=5" | head -20
curl -s -D- "$G/api/v1/auctions/a1000000-0000-0000-0000-000000000001"
curl -s -D- "$G/api/v1/products?page=1&pageSize=5"          # sau C1: KHÔNG còn /catalog
curl -s -D- "$G/api/v1/product/22222222-2222-2222-2222-000000000001"
curl -s -D- -X DELETE "$G/api/v1/product/22222222-2222-2222-2222-000000000001" -o /dev/null -w '%{http_code}\n'  # 204
```

**Giới hạn môi trường:** máy hiện tại **không có `dotnet`** ⇒ bắt buộc chạy trên máy có .NET 8 (hoặc container) trước khi merge; mọi đánh giá trong tài liệu này là tĩnh.

---

## 9. Thứ tự thực hiện

1. **C0** (chốt D1–D7) — vì nó quyết định cả 2 PR.
2. **A1–A3** → merge PR#2 (auction) — giá trị cao, rủi ro thấp.
3. **C1–C2** → chốt `catalog.proto` (blocking mọi việc sau).
4. **C3–C9** → PR#3 mới, review lại theo đúng tài liệu này.
5. **A4–A6, C10–C11** → dọn dẹp, đồng bộ tài liệu.

## 10. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Đổi route bỏ `/catalog` làm vỡ client đang gọi stub cũ | Grep toàn bộ repo + hỏi FE trước; giữ alias tạm 1 sprint nếu cần |
| Sửa `catalog.proto` 26 endpoint là thay đổi lớn, dễ lệch lần nữa | Sinh bảng đối chiếu từ xlsx (26 dòng) và đánh dấu ✓ vào chính tài liệu này khi xong |
| Hai PR cùng sửa `Nexus.Gateway.csproj` và `gateway.runtime.json` ⇒ conflict | Merge PR#2 trước, PR#3 rebase sau |
| `MockDataMapper.MapMockAsync` nuốt lỗi parse (fallback raw JSON) ⇒ seed sai shape **không báo lỗi** | Thêm test khẳng định response khớp `parser.ParseJson` (không chỉ `success=true`) |
