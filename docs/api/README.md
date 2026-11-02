# 🌐 NEXUS E-COMMERCE ECOSYSTEM — FRONTEND API REFERENCE & INTEGRATION MANUAL

> **Dành cho:** Đội ngũ Frontend Developers (Web, Mobile App, Admin Dashboard)  
> **Cổng truy cập duy nhất (Single Gateway Entrypoint):** `http://localhost:8080`  
> **Giao thức:** 100% RESTful HTTP/JSON (Chuẩn RFC 9110)  
> **Interactive Swagger UI:** [http://localhost:8080/swagger](http://localhost:8080/swagger)  
> **Tổng số API đã nghiệm thu (A_Active):** `59 endpoints` (35 User + 24 Catalog)  
> **Trạng thái tài liệu:** ⏳ Quản lý hai trạng thái (`B_none/` đang hoàn thiện vs `A_Active/` đã nghiệm thu).
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
- **`docs/api/B_none/{Service}/{Endpoint}.md`**: API đang trong quá trình phát triển (WIP), mới lên đặc tả từ Excel hoặc chưa được Người dùng (Sếp) kiểm thử thực tế và ký duyệt.
- **`docs/api/A_Active/{Service}/{Endpoint}.md`**: API đã hoàn thiện 100%, vượt qua tất cả unit/integration tests, Gateway route thông suốt và được Người dùng nghiệm thu chính thức.

> ⚠️ **Quy tắc di chuyển:** Tuyệt đối cấm tự ý chuyển file từ `B_none` sang `A_Active` nếu chưa có sự xác nhận rõ ràng của Người dùng (Human Approval).

---

## 3. QUY CHUẨN ĐỊNH DẠNG REQUEST / RESPONSE ENVELOPE

Mọi phản hồi từ Gateway đều được bọc trong một **Vỏ bọc chuẩn hóa (Standard Envelope)**:

### 3.1 Đối tượng đơn lẻ (`ApiResponse<T>`)
```typescript
interface ApiResponse<T> {
  success: boolean;       // Luôn là true nếu HTTP Status 2xx
  statusCode: number;     // Mã HTTP (200, 201...)
  message: string;        // Thông điệp tiếng Anh chuẩn Sentence case
  data: T;                // Dữ liệu nghiệp vụ trả về
  traceId: string;        // Mã trace chuẩn W3C Distributed Tracing
  timestamp: string;      // Thời gian server (ISO 8601 UTC)
}
```

### 3.2 Danh sách có phân trang (`ApiResponse<PagedData<T>>`)
```typescript
interface PagedData<T> {
  items: T[];             // Mảng các bản ghi
  pagination: {
    pageIndex: number;    // Trang hiện tại (bắt đầu từ 1)
    pageSize: number;     // Số phần tử trên 1 trang
    totalCount: number;   // Tổng số bản ghi thỏa mãn điều kiện
    totalPages: number;   // Tổng số trang
    hasPreviousPage: boolean; // Có trang trước không
    hasNextPage: boolean;     // Có trang kế tiếp không
  };
}
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

| Phân Hệ (Service) | Thư Mục Tài Liệu | Số API | Trạng Thái Vòng Đời |
|:---|:---|:---:|:---|
| **User** | [`docs/api/A_Active/User/`](./A_Active/User/) + [`docs/api/B_none/User/`](./B_none/User/) | **72** | 35 API: ✅ `COMPLETED` tại `A_Active/`; 37 API còn lại: ⏳ `IN_PROGRESS` |
| **Catalog** | [`docs/api/A_Active/Catalog/`](./A_Active/Catalog/) + [`docs/api/B_none/Catalog/`](./B_none/Catalog/) | **28** | 24 API: ✅ `COMPLETED` tại `A_Active/`; 4 API review: ⏳ `IN_PROGRESS` tại `B_none/` |
| **Commerce** | [`docs/api/B_none/Commerce/`](./B_none/Commerce/) | **17** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **Auction** | [`docs/api/B_none/Auction/`](./B_none/Auction/) | **21** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **Fulfillment** | [`docs/api/B_none/Fulfillment/`](./B_none/Fulfillment/) | **9** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **Wallet** | [`docs/api/B_none/Wallet/`](./B_none/Wallet/) | **11** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **Notification** | [`docs/api/B_none/Notification/`](./B_none/Notification/) | **11** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **Log** | [`docs/api/B_none/Log/`](./B_none/Log/) | **4** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **CheckHeal** | [`docs/api/B_none/CheckHeal/`](./B_none/CheckHeal/) | **4** | Trạng thái: ⏳ `IN_PROGRESS` (Chờ nghiệm thu) |
| **TỔNG CỘNG** | **9 Phân Hệ Nghiệp Vụ** | **177** | **59 hồ sơ đã nghiệm thu tại `A_Active/`, 118 hồ sơ đang hoàn thiện tại `B_none/`** |

---

### 7.1. Hồ Sơ Đã Nghiệm Thu Tại `A_Active/User/` (35 API Hoàn Tất)

| STT | Endpoint | Tài liệu | Mô tả |
|:---:|:---|:---|:---|
| 01 | `POST /api/v1/auth/register` | [`1_POST_AUTH_REGISTER.md`](./A_Active/User/1_POST_AUTH_REGISTER.md) | Đăng ký tài khoản người dùng |
| 02 | `POST /api/v1/auth/otp/verify` | [`2_POST_AUTH_OTP_VERIFY.md`](./A_Active/User/2_POST_AUTH_OTP_VERIFY.md) | Xác thực OTP đăng ký |
| 03 | `POST /api/v1/auth/otp/resend` | [`3_POST_AUTH_OTP_RESEND.md`](./A_Active/User/3_POST_AUTH_OTP_RESEND.md) | Gửi lại OTP kích hoạt tài khoản |
| 04 | `POST /api/v1/auth/login` | [`4_POST_AUTH_LOGIN.md`](./A_Active/User/4_POST_AUTH_LOGIN.md) | Đăng nhập hệ thống (Email + Password) |
| 05 | `POST /api/v1/auth/refresh` | [`5_POST_AUTH_REFRESH.md`](./A_Active/User/5_POST_AUTH_REFRESH.md) | Làm mới token ngầm (RTR) |
| 06 | `POST /api/v1/auth/password/forgot` | [`6_POST_AUTH_PASSWORD_FORGOT.md`](./A_Active/User/6_POST_AUTH_PASSWORD_FORGOT.md) | Yêu cầu quên mật khẩu & gửi OTP |
| 07 | `PUT /api/v1/auth/password/reset` | [`7_PUT_AUTH_PASSWORD_RESET.md`](./A_Active/User/7_PUT_AUTH_PASSWORD_RESET.md) | Đặt lại mật khẩu bằng mã OTP |
| 08 | `PATCH /api/v1/auth/password` | [`8_PATCH_AUTH_PASSWORD.md`](./A_Active/User/8_PATCH_AUTH_PASSWORD.md) | Đổi mật khẩu cá nhân |
| 09 | `POST /api/v1/auth/logout` | [`9_POST_AUTH_LOGOUT.md`](./A_Active/User/9_POST_AUTH_LOGOUT.md) | Đăng xuất phiên hiện tại |
| 10 | `POST /api/v1/auth/logout-all` | [`10_POST_AUTH_LOGOUT_ALL.md`](./A_Active/User/10_POST_AUTH_LOGOUT_ALL.md) | Đăng xuất toàn bộ phiên thiết bị |
| 11 | `POST /api/v1/users/auth-test` | [`11_POST_USERS_AUTH_TEST.md`](./A_Active/User/11_POST_USERS_AUTH_TEST.md) | Kiểm tra xác thực token |
| 12 | `GET /api/v1/users/{userId}` | [`12_GET_USERS_USERID.md`](./A_Active/User/12_GET_USERS_USERID.md) | Lấy thông tin hồ sơ an toàn của user |
| 13 | `GET /api/v1/me` | [`13_GET_ME.md`](./A_Active/User/13_GET_ME.md) | Lấy thông tin hồ sơ cá nhân |
| 14 | `PATCH /api/v1/me` | [`14_PATCH_ME.md`](./A_Active/User/14_PATCH_ME.md) | Cập nhật thông tin cá nhân |
| 15 | `POST /api/v1/sellers/registration` | [`15_POST_SELLERS_REGISTRATION.md`](./A_Active/User/15_POST_SELLERS_REGISTRATION.md) | Nộp đơn đăng ký Seller onboarding |
| 16 | `POST /api/v1/sellers/otp/verify` | [`16_POST_SELLERS_OTP_VERIFY.md`](./A_Active/User/16_POST_SELLERS_OTP_VERIFY.md) | Xác thực OTP mở shop của Seller |
| 17 | `POST /api/v1/sellers/otp/resend` | [`17_POST_SELLERS_OTP_RESEND.md`](./A_Active/User/17_POST_SELLERS_OTP_RESEND.md) | Gửi lại mã OTP đăng ký mở shop |
| 18 | `GET /api/v1/sellers/status` | [`18_GET_SELLERS_STATUS.md`](./A_Active/User/18_GET_SELLERS_STATUS.md) | Tra cứu trạng thái đơn đăng ký Seller |
| 19 | `GET /api/v1/sellers/profile` | [`19_GET_SELLERS_PROFILE.md`](./A_Active/User/19_GET_SELLERS_PROFILE.md) | Seller xem thông tin shop của mình |
| 20 | `PATCH /api/v1/sellers/profile` | [`20_PATCH_SELLERS_PROFILE.md`](./A_Active/User/20_PATCH_SELLERS_PROFILE.md) | Cập nhật hồ sơ thông tin shop |
| 21 | `GET /api/v1/sellers/{sellerId}` | [`21_GET_SELLERS_ID.md`](./A_Active/User/21_GET_SELLERS_ID.md) | Khách hàng xem thông tin shop người bán |
| 22 | `POST /api/v1/admin/users` | [`22_POST_ADMIN_USERS.md`](./A_Active/User/22_POST_ADMIN_USERS.md) | Admin tạo tài khoản người dùng mới |
| 23 | `GET /api/v1/admin/users` | [`23_GET_ADMIN_USERS.md`](./A_Active/User/23_GET_ADMIN_USERS.md) | Admin xem danh sách người dùng phân trang |
| 24 | `GET /api/v1/admin/users/{userId}` | [`24_GET_ADMIN_USERS_USERID.md`](./A_Active/User/24_GET_ADMIN_USERS_USERID.md) | Admin xem chi tiết hồ sơ & quyền hạn |
| 25 | `PUT /api/v1/admin/users/{userId}/roles` | [`25_PUT_ADMIN_USERS_USERID_ROLES.md`](./A_Active/User/25_PUT_ADMIN_USERS_USERID_ROLES.md) | Admin phân vai trò nội bộ cho user |
| 26 | `PUT /api/v1/admin/users/{userId}` | [`26_PUT_ADMIN_USERS_USERID.md`](./A_Active/User/26_PUT_ADMIN_USERS_USERID.md) | Admin cập nhật thông tin người dùng |
| 27 | `DELETE /api/v1/admin/users/{userId}` | [`27_DELETE_ADMIN_USERS_USERID.md`](./A_Active/User/27_DELETE_ADMIN_USERS_USERID.md) | Admin xóa mềm người dùng khỏi hệ thống |
| 28 | `PATCH /api/v1/admin/users/{userId}/ban` | [`28_PATCH_ADMIN_USERS_USERID_BAN.md`](./A_Active/User/28_PATCH_ADMIN_USERS_USERID_BAN.md) | Admin khóa tài khoản vi phạm |
| 29 | `PATCH /api/v1/admin/users/{userId}/unban` | [`29_PATCH_ADMIN_USERS_USERID_UNBAN.md`](./A_Active/User/29_PATCH_ADMIN_USERS_USERID_UNBAN.md) | Admin mở khóa tài khoản |
| 30 | `GET /api/v1/admin/roles` | [`30_GET_ADMIN_ROLES.md`](./A_Active/User/30_GET_ADMIN_ROLES.md) | Admin xem toàn bộ danh mục vai trò |
| 31 | `GET /api/v1/admin/seller-registrations` | [`31_GET_ADMIN_SELLER_REGISTRATIONS.md`](./A_Active/User/31_GET_ADMIN_SELLER_REGISTRATIONS.md) | Danh sách đơn đăng ký Seller chờ duyệt |
| 32 | `GET /api/v1/admin/seller-registrations/{id}` | [`32_GET_ADMIN_SELLER_REGISTRATIONS_ID.md`](./A_Active/User/32_GET_ADMIN_SELLER_REGISTRATIONS_ID.md) | Chi tiết hồ sơ mở shop & chứng từ |
| 33 | `PUT /api/v1/admin/seller-registrations/{id}/approve` | [`33_PUT_ADMIN_SELLER_REGISTRATIONS_APPROVE.md`](./A_Active/User/33_PUT_ADMIN_SELLER_REGISTRATIONS_APPROVE.md) | Duyệt hồ sơ mở shop của Seller |
| 34 | `PUT /api/v1/admin/seller-registrations/{id}/reject` | [`34_PUT_ADMIN_SELLER_REGISTRATIONS_REJECT.md`](./A_Active/User/34_PUT_ADMIN_SELLER_REGISTRATIONS_REJECT.md) | Từ chối hồ sơ mở shop |
| 35 | `GET /health` | [`35_GET_HEALTH.md`](./A_Active/User/35_GET_HEALTH.md) | Health probe kiểm tra sức khỏe service |

---

### 7.2. Hồ Sơ Đã Nghiệm Thu Tại `A_Active/Catalog/` (24 API Hoàn Tất)

| STT | Endpoint | Tài liệu | Mô tả |
|:---:|:---|:---|:---|
| 01 | `GET /api/v1/categories` | [`01_GET_CATEGORIES.md`](./A_Active/Catalog/01_GET_CATEGORIES.md) | Lấy danh sách danh mục (cây hoặc phẳng) |
| 02 | `GET /api/v1/categories/{id}` | [`02_GET_CATEGORIES_ID.md`](./A_Active/Catalog/02_GET_CATEGORIES_ID.md) | Lấy chi tiết danh mục kèm cây con |
| 03 | `POST /api/v1/categories` | [`03_POST_CATEGORIES.md`](./A_Active/Catalog/03_POST_CATEGORIES.md) | Tạo danh mục mới (Admin/Staff) |
| 04 | `PUT /api/v1/categories/{id}` | [`04_PUT_CATEGORIES_ID.md`](./A_Active/Catalog/04_PUT_CATEGORIES_ID.md) | Cập nhật thông tin danh mục (Admin/Staff) |
| 05 | `DELETE /api/v1/categories/{id}` | [`05_DELETE_CATEGORIES_ID.md`](./A_Active/Catalog/05_DELETE_CATEGORIES_ID.md) | Xóa mềm danh mục (Admin/Staff) |
| 06 | `GET /api/v1/products` | [`06_GET_PRODUCTS.md`](./A_Active/Catalog/06_GET_PRODUCTS.md) | Tìm kiếm & phân trang sản phẩm công khai |
| 07 | `GET /api/v1/products/{id}` | [`07_GET_PRODUCTS_ID.md`](./A_Active/Catalog/07_GET_PRODUCTS_ID.md) | Lấy chi tiết sản phẩm (kèm biến thể, ảnh) |
| 08 | `POST /api/v1/products` | [`08_POST_PRODUCTS.md`](./A_Active/Catalog/08_POST_PRODUCTS.md) | Tạo sản phẩm thông thường mới (Draft) |
| 09 | `POST /api/v1/products/auction` | [`09_POST_PRODUCTS_AUCTION.md`](./A_Active/Catalog/09_POST_PRODUCTS_AUCTION.md) | Tạo sản phẩm đấu giá mới (Draft) |
| 10 | `PUT /api/v1/products/{id}` | [`10_PUT_PRODUCTS_ID.md`](./A_Active/Catalog/10_PUT_PRODUCTS_ID.md) | Cập nhật thông tin chung sản phẩm |
| 11 | `PATCH /api/v1/products/{id}/status` | [`11_PATCH_PRODUCTS_ID_STATUS.md`](./A_Active/Catalog/11_PATCH_PRODUCTS_ID_STATUS.md) | Thay đổi trạng thái sản phẩm |
| 12 | `DELETE /api/v1/products/{id}` | [`12_DELETE_PRODUCTS_ID.md`](./A_Active/Catalog/12_DELETE_PRODUCTS_ID.md) | Xóa mềm sản phẩm và biến thể |
| 13 | `GET /api/v1/products/{id}/images` | [`13_GET_PRODUCTS_ID_IMAGES.md`](./A_Active/Catalog/13_GET_PRODUCTS_ID_IMAGES.md) | Lấy danh sách toàn bộ ảnh sản phẩm |
| 14 | `POST /api/v1/products/{id}/images` | [`14_POST_PRODUCTS_ID_IMAGES.md`](./A_Active/Catalog/14_POST_PRODUCTS_ID_IMAGES.md) | Tải ảnh lên cho sản phẩm (Cloudinary) |
| 15 | `DELETE /api/v1/products/{id}/images/{imageId}` | [`15_DELETE_PRODUCTS_ID_IMAGES_IMAGEID.md`](./A_Active/Catalog/15_DELETE_PRODUCTS_ID_IMAGES_IMAGEID.md) | Xóa ảnh khỏi sản phẩm |
| 16 | `POST /api/v1/products/{id}/variants` | [`16_POST_PRODUCTS_ID_VARIANTS.md`](./A_Active/Catalog/16_POST_PRODUCTS_ID_VARIANTS.md) | Thêm biến thể SKU cho sản phẩm |
| 17 | `PUT /api/v1/products/{id}/default-variant` | [`17_PUT_PRODUCTS_ID_DEFAULT_VARIANT.md`](./A_Active/Catalog/17_PUT_PRODUCTS_ID_DEFAULT_VARIANT.md) | Đặt biến thể mặc định cho sản phẩm |
| 18 | `GET /api/v1/variants/{id}` | [`18_GET_VARIANTS_ID.md`](./A_Active/Catalog/18_GET_VARIANTS_ID.md) | Lấy chi tiết biến thể SKU |
| 19 | `PUT /api/v1/variants/{id}` | [`19_PUT_VARIANTS_ID.md`](./A_Active/Catalog/19_PUT_VARIANTS_ID.md) | Cập nhật thông tin biến thể SKU |
| 20 | `PATCH /api/v1/variants/{id}/status` | [`20_PATCH_VARIANTS_ID_STATUS.md`](./A_Active/Catalog/20_PATCH_VARIANTS_ID_STATUS.md) | Thay đổi trạng thái biến thể SKU |
| 21 | `DELETE /api/v1/variants/{id}` | [`21_DELETE_VARIANTS_ID.md`](./A_Active/Catalog/21_DELETE_VARIANTS_ID.md) | Xóa mềm biến thể SKU |
| 22 | `PATCH /api/v1/images/{id}` | [`22_PATCH_IMAGES_ID.md`](./A_Active/Catalog/22_PATCH_IMAGES_ID.md) | Cập nhật thuộc tính hình ảnh |
| 23 | `DELETE /api/v1/images/{id}` | [`23_DELETE_IMAGES_ID.md`](./A_Active/Catalog/23_DELETE_IMAGES_ID.md) | Xóa hình ảnh theo ID |
| 24 | `GET /api/v1/seller/products` | [`24_GET_SELLER_PRODUCTS.md`](./A_Active/Catalog/24_GET_SELLER_PRODUCTS.md) | Người bán tra cứu sản phẩm của shop |

---

## 8. DANH SÁCH CHI TIẾT TỪNG ENDPOINT THEO DỊCH VỤ

### User Service (72 endpoints: 10 tại `A_Active`, 62 tại `B_none`)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[POST] /api/v1/auth/logout-all`](./A_Active/User/10_POST_AUTH_LOGOUT_ALL.md) | `10` | Đăng xuất khỏi toàn bộ thiết bị khác |
| [`[GET] /api/v1/me/sessions`](./B_none/User/11_GET_ME_SESSIONS.md) | `11` | Xem danh sách thiết bị đang đăng nhập |
| [`[DELETE] /api/v1/me/sessions/{id}`](./B_none/User/12_DELETE_ME_SESSIONS.md) | `12` | Thu hồi / Đăng xuất thiết bị từ xa |
| [`[GET] /api/v1/me`](./B_none/User/13_GET_ME.md) | `13` | Xem danh sách cá nhân của user |
| [`[PATCH] /api/v1/me`](./B_none/User/14_PATCH_ME.md) | `14` | Cập nhật thông tin hồ sơ cá nhân |
| [`[GET] /api/v1/me/avatar`](./B_none/User/15_GET_ME_AVATAR.md) | `15` | Xem ảnh avatar cá nhân |
| [`[POST] /api/v1/me/avatar`](./B_none/User/16_POST_ME_AVATAR.md) | `16` | Tải lên và cập nhật avatar cá nhân |
| [`[GET] /api/v1/me/reputation`](./B_none/User/17_GET_ME_REPUTATION.md) | `17` | Xem uy tín của bản thân |
| [`[GET] /api/v1/me/penalties`](./B_none/User/18_GET_ME_PENALTIES.md) | `18` | xem thông tin phạt của bản thân |
| [`[GET] /api/v1/users/{userId}`](./B_none/User/19_GET_USER.md) | `19` | Xem chi tiết hồ sơ cá nhân của 1 user cụ thể |
| [`[POST] /api/v1/auth/register`](./A_Active/User/1_POST_AUTH_REGISTER.md) | `1` | Người dùng đăng kí tài khoản |
| [`[GET] /api/v1/users/{userId}/avatar`](./B_none/User/20_GET_USER_AVATAR.md) | `20` | Xem ảnh avatar của từng user |
| [`[GET] /api/v1/sellers/{sellerId}`](./B_none/User/21_GET_SELLER.md) | `21` | User lấy thông tin cửa hàng của Seller |
| [`[GET] /api/v1/users/{userId}/reputation`](./B_none/User/22_GET_USER_REPUTATION.md) | `22` | Xem Thẻ Tóm tắt Hồ sơ Uy tín công khai |
| [`[GET] /api/v1/users/{userId}/reputation/history`](./B_none/User/23_GET_USER_REPUTATION_HISTORY.md) | `23` | Xem lịch sử uy tín (tăng or giảm) |
| [`[GET] /api/v1/users/{userId}/reviews`](./B_none/User/24_GET_USER_REVIEWS.md) | `24` | Xem danh sách đánh giá công khai của 1 user/Shop |
| [`[POST] /api/v1/reviews/files/upload`](./B_none/User/25_POST_REVIEW_FILES_UPLOAD.md) | `25` | Upload đánh giá sản phẩm |
| [`[POST] /api/v1/reviews`](./B_none/User/26_POST_REVIEWS.md) | `26` | Đánh giá đối tác 2 chiều (Buyer ↔ Seller) |
| [`[POST] /api/v1/reports/files/upload`](./B_none/User/27_POST_REPORT_FILES_UPLOAD.md) | `27` | Upload bằng chứng tố cáo tài khoản vi phạm (User Violation Evidence) |
| [`[POST] /api/v1/users/reports`](./B_none/User/28_POST_USERS_REPORTS.md) | `28` | Người dùng gửi đơn tố cáo tài khoản vi phạm quy chế |
| [`[GET] /api/v1/me/reports`](./B_none/User/29_GET_ME_REPORTS.md) | `29` | Người dùng xem danh sách các báo cáo do mình đã gửi |
| [`[POST] /api/v1/auth/otp/verify`](./A_Active/User/2_POST_AUTH_OTP_VERIFY.md) | `2` | Xác thực tài khoản người dùng |
| [`[POST] /api/v1/sellers/registration`](./B_none/User/30_POST_SELLER_REGISTRATION.md) | `30` | Seller tạo đơn đăng kí |
| [`[POST] /api/v1/sellers/registration/otp/resend`](./B_none/User/31_POST_SELLER_REGISTRATION_OTP_RESEND.md) | `31` | Gửi lại otp cho tài khoản Seller |
| [`[POST] /api/v1/sellers/registration/documents`](./B_none/User/32_POST_SELLER_REGISTRATION_DOCUMENTS.md) | `32` | Upload tài liệu Seller(CCCD, ....) |
| [`[POST] /api/v1/sellers/otp/verify`](./B_none/User/33_POST_SELLER_OTP_VERIFY.md) | `33` | Xác thực mã otp của Seller |
| [`[GET] /api/v1/sellers/registration`](./B_none/User/34_GET_SELLER_REGISTRATION.md) | `34` | Seller xem đơn (đã được duyệt làm Seller hay chưa) |
| [`[GET] /api/v1/sellers/profile`](./B_none/User/35_GET_SELLER_PROFILE.md) | `35` | Seller tự coi thông tin shop |
| [`[PATCH] /api/v1/sellers/profile`](./B_none/User/36_PATCH_SELLER_PROFILE.md) | `36` | Cập nhật thông tin cá nhân hồ sơ cho Seller |
| [`[GET] /api/v1/admin/seller-registrations/{registrationId}`](./B_none/User/37B_GET_ADMIN_SELLER_REGISTRATIONS.md) | `37B` | Xem chi tiết hồ sơ mở Shop và tài liệu chứng từ định danh |
| [`[GET] /api/v1/admin/seller-registrations`](./B_none/User/37_GET_ADMIN_SELLER_REGISTRATIONS.md) | `37` | Danh sách hồ sơ Seller chờ duyệt |
| [`[PUT] /api/v1/admin/seller-registrations/{registrationId}/approve`](./B_none/User/38_PUT_ADMIN_SELLER_REGISTRATIONS_APPROVE.md) | `38` | Staff duyệt hồ sơ Seller |
| [`[PUT] /api/v1/admin/seller-registrations/{registrationId}/reject`](./B_none/User/39_PUT_ADMIN_SELLER_REGISTRATIONS_REJECT.md) | `39` | Staff từ chối hồ sơ Seller |
| [`[POST] /api/v1/auth/otp/resend`](./A_Active/User/3_POST_AUTH_OTP_RESEND.md) | `3` | Dùng gửi otp cho đăng kí và cả quên mật khẩu |
| [`[GET] /api/v1/admin/reports`](./B_none/User/40_GET_ADMIN_REPORTS.md) | `40` | Admin/Staff xem danh sách các đơn tố cáo tài khoản |
| [`[PUT] /api/v1/admin/reports/{reportId}/dismiss`](./B_none/User/41B_PUT_ADMIN_REPORTS_DISMISS.md) | `41B` | Staff bác bỏ đơn tố cáo sai sự thật / không đủ chứng cứ |
| [`[PUT] /api/v1/admin/reports/{reportId}/resolve`](./B_none/User/41_PUT_ADMIN_REPORTS_RESOLVE.md) | `41` | Staff xử lý chấp thuận tố cáo & áp dụng chế tài kỷ luật |
| [`[PUT] /api/v1/admin/reviews/{id}/hide`](./B_none/User/42_PUT_ADMIN_REVIEWS_HIDE.md) | `42` | Staff/Admin ẩn đánh giá vi phạm tiêu chuẩn |
| [`[GET] /api/v1/admin/users`](./B_none/User/43_GET_ADMIN_USER.md) | `43` | Admin xem danh sách các user |
| [`[POST] /api/v1/admin/users`](./B_none/User/44_POST_ADMIN_USER.md) | `44` | Admin tạo user mới |
| [`[GET] /api/v1/admin/users/{userId}`](./B_none/User/45_GET_ADMIN_USER.md) | `45` | Xem chi tiết hồ sơ cá nhân, phân quyền & uy tín |
| [`[PUT] /api/v1/admin/users/{userId}`](./B_none/User/46_PUT_ADMIN_USER.md) | `46` | Admin cập nhật thông tin của user cụ thể |
| [`[DELETE] /api/v1/admin/users/{userId}`](./B_none/User/47_DELETE_ADMIN_USER.md) | `47` | Xóa MỀM 1 user khỏi hệ thống |
| [`[PATCH] /api/v1/admin/users/{userId}/ban`](./B_none/User/48_PATCH_ADMIN_USER_BAN.md) | `48` | Admin ban 1 user |
| [`[PATCH] /api/v1/admin/users/{userId}/unban`](./B_none/User/49_PATCH_ADMIN_USER_UNBAN.md) | `49` | Admin hủy ban 1 user |
| [`[POST] /api/v1/auth/login`](./A_Active/User/4_POST_AUTH_LOGIN.md) | `4` | Đăng nhập hệ thống (Email + Password) |
| [`[GET] /api/v1/admin/sellers/{sellerId}`](./B_none/User/50_GET_ADMIN_SELLERS.md) | `50` | Admin lấy thông tin cửa hàng của từng Seller |
| [`[PUT] /api/v1/admin/users/{userId}/roles`](./B_none/User/51_PUT_ADMIN_USER_ROLES.md) | `51` | Gán / Thu hồi vai trò nội bộ (Phân quyền SoD) |
| [`[PATCH] /api/v1/admin/users/{userId}/reputation`](./B_none/User/52_PATCH_ADMIN_USER_REPUTATION.md) | `52` | Admin điều chỉnh uy tín của user(thủ công) |
| [`[GET] /api/v1/admin/roles`](./B_none/User/53_GET_ADMIN_ROLES.md) | `53` | Admin xem toàn bộ roles trong hệ thống |
| [`[GET] /api/v1/admin/permissions`](./B_none/User/54_GET_ADMIN_PERMISSIONS.md) | `54` | Xem danh sách các đặc quyền |
| [`[PUT] /api/v1/admin/roles/{roleId}/permissions`](./B_none/User/55_PUT_ADMIN_ROLES_PERMISSIONS.md) | `55` | Cập nhật danh sách đặc quyền (Permissions) cho Vai trò |
| [`[GET] /api/v1/admin/audit-logs`](./B_none/User/56_GET_ADMIN_AUDIT_LOGS.md) | `56` | Tra cứu Nhật ký Kiểm toán hệ thống |
| [`[GET] /api/v1/admin/configs`](./B_none/User/57_GET_ADMIN_CONFIGS.md) | `57` | Xem danh sách tham số cấu hình toàn sàn |
| [`[PUT] /api/v1/admin/configs`](./B_none/User/58_PUT_ADMIN_CONFIGS.md) | `58` | Cập nhật tham số cấu hình toàn sàn |
| [`[POST] /api/v1/auth/refresh`](./A_Active/User/5_POST_AUTH_REFRESH.md) | `5` | Làm mới Token ngầm (Refresh Token Rotation - RTR) |
| [`[POST] /api/v1/auth/password/forgot`](./A_Active/User/6_POST_AUTH_PASSWORD_FORGOT.md) | `6` | Yêu cầu quên mật khẩu & Gửi OTP khôi phục |
| [`[PUT] /api/v1/auth/password/reset`](./A_Active/User/7_PUT_AUTH_PASSWORD_RESET.md) | `7` | Đặt lại mật khẩu mới bằng mã OTP |
| [`[PATCH] /api/v1/auth/password`](./A_Active/User/8_PATCH_AUTH_PASSWORD.md) | `8` | Cập nhật lại mật khẩu(Đổi mật khẩu) |
| [`[POST] /api/v1/auth/logout`](./A_Active/User/9_POST_AUTH_LOGOUT.md) | `9` | Đăng xuất & Thu hồi phiên hiện tại |
| [`[POST] /api/v1/orders/{orderId}/user/{userId}`](./B_none/User/R93_POST_ORDER_USER.md) | `` | Đánh giá người dùng |
| [`[PATCH] /api/v1/orders/{orderId}/user/{userId}`](./B_none/User/R95_PATCH_ORDER_USER.md) | `` | Chỉnh sửa đánh giá người dùng |

### Catalog Service (28 endpoints: 24 tại `A_Active`, 4 tại `B_none`)

#### Nhóm Đã Nghiệm Thu (`A_Active/Catalog/`)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[GET] /api/v1/categories`](./A_Active/Catalog/01_GET_CATEGORIES.md) | `CAT-14` | Lấy danh sách danh mục (cây phân cấp hoặc phẳng) |
| [`[GET] /api/v1/categories/{id}`](./A_Active/Catalog/02_GET_CATEGORIES_ID.md) | `CAT-18` | Lấy chi tiết danh mục kèm cây con trực thuộc |
| [`[POST] /api/v1/categories`](./A_Active/Catalog/03_POST_CATEGORIES.md) | `CAT-15` | Tạo danh mục mới (Admin/Staff) |
| [`[PUT] /api/v1/categories/{id}`](./A_Active/Catalog/04_PUT_CATEGORIES_ID.md) | `CAT-16` | Cập nhật thông tin danh mục (Admin/Staff) |
| [`[DELETE] /api/v1/categories/{id}`](./A_Active/Catalog/05_DELETE_CATEGORIES_ID.md) | `CAT-17` | Xóa mềm danh mục (Admin/Staff) |
| [`[GET] /api/v1/products`](./A_Active/Catalog/06_GET_PRODUCTS.md) | `CAT-05 / CAT-20` | Tìm kiếm & lọc sản phẩm công khai phân trang |
| [`[GET] /api/v1/products/{id}`](./A_Active/Catalog/07_GET_PRODUCTS_ID.md) | `CAT-06` | Xem chi tiết sản phẩm đầy đủ (kèm biến thể, ảnh, rating) |
| [`[POST] /api/v1/products`](./A_Active/Catalog/08_POST_PRODUCTS.md) | `CAT-01` | Tạo sản phẩm thông thường mới (Draft) |
| [`[POST] /api/v1/products/auction`](./A_Active/Catalog/09_POST_PRODUCTS_AUCTION.md) | `CAT-43` | Tạo sản phẩm đấu giá mới (Draft) |
| [`[PUT] /api/v1/products/{id}`](./A_Active/Catalog/10_PUT_PRODUCTS_ID.md) | `CAT-02` | Cập nhật thông tin chung sản phẩm |
| [`[PATCH] /api/v1/products/{id}/status`](./A_Active/Catalog/11_PATCH_PRODUCTS_ID_STATUS.md) | `CAT-03` | Thay đổi trạng thái sản phẩm (Draft, Active, Inactive) |
| [`[DELETE] /api/v1/products/{id}`](./A_Active/Catalog/12_DELETE_PRODUCTS_ID.md) | `CAT-04` | Xóa mềm sản phẩm và toàn bộ biến thể |
| [`[GET] /api/v1/products/{id}/images`](./A_Active/Catalog/13_GET_PRODUCTS_ID_IMAGES.md) | `CAT-40` | Lấy danh sách hình ảnh của sản phẩm |
| [`[POST] /api/v1/products/{id}/images`](./A_Active/Catalog/14_POST_PRODUCTS_ID_IMAGES.md) | `CAT-12` | Tải lên hình ảnh cho sản phẩm (Cloudinary) |
| [`[DELETE] /api/v1/products/{id}/images/{imageId}`](./A_Active/Catalog/15_DELETE_PRODUCTS_ID_IMAGES_IMAGEID.md) | `CAT-13` | Xóa ảnh khỏi sản phẩm |
| [`[POST] /api/v1/products/{id}/variants`](./A_Active/Catalog/16_POST_PRODUCTS_ID_VARIANTS.md) | `CAT-07` | Thêm biến thể SKU mới cho sản phẩm (tối đa 10) |
| [`[PUT] /api/v1/products/{id}/default-variant`](./A_Active/Catalog/17_PUT_PRODUCTS_ID_DEFAULT_VARIANT.md) | `CAT-10` | Đặt biến thể mặc định cho sản phẩm |
| [`[GET] /api/v1/variants/{id}`](./A_Active/Catalog/18_GET_VARIANTS_ID.md) | `CAT-42` | Lấy thông tin chi tiết một biến thể SKU |
| [`[PUT] /api/v1/variants/{id}`](./A_Active/Catalog/19_PUT_VARIANTS_ID.md) | `CAT-08` | Cập nhật thông tin biến thể SKU |
| [`[PATCH] /api/v1/variants/{id}/status`](./A_Active/Catalog/20_PATCH_VARIANTS_ID_STATUS.md) | `CAT-09` | Thay đổi trạng thái biến thể SKU (Active/Inactive) |
| [`[DELETE] /api/v1/variants/{id}`](./A_Active/Catalog/21_DELETE_VARIANTS_ID.md) | `CAT-11` | Xóa mềm biến thể SKU |
| [`[PATCH] /api/v1/images/{id}`](./A_Active/Catalog/22_PATCH_IMAGES_ID.md) | `CAT-14` | Cập nhật thuộc tính hình ảnh (thứ tự, altText, cờ active) |
| [`[DELETE] /api/v1/images/{id}`](./A_Active/Catalog/23_DELETE_IMAGES_ID.md) | `CAT-13` | Xóa hình ảnh sản phẩm theo ID |
| [`[GET] /api/v1/seller/products`](./A_Active/Catalog/24_GET_SELLER_PRODUCTS.md) | `CAT-44` | Người bán tra cứu danh sách sản phẩm của shop |

#### Nhóm Đang Phát Triển / Chờ Nghiệm Thu (`B_none/Catalog/`)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[GET] /api/v1/products/{productId}/totalRating`](./B_none/Catalog/R111_GET_PRODUCTS_TOTALRATING.md) | `` | Xem tổng quan sao đánh giá trung bình của sản phẩm |
| [`[GET] /api/v1/products/{productId}/rating`](./B_none/Catalog/R112_GET_PRODUCTS_RATING.md) | `` | Danh sách bình luận & đánh giá của người mua |
| [`[POST] /api/v1/orders/{orderId}/products/{productId}/reviews`](./B_none/Catalog/R92_POST_ORDER_PRODUCTS_REVIEWS.md) | `` | Người mua đánh giá sản phẩm sau khi hoàn thành đơn |
| [`[PATCH] /api/v1/orders/{orderId}/products/{productId}/reviews`](./B_none/Catalog/R94_PATCH_ORDER_PRODUCTS_REVIEWS.md) | `` | Chỉnh sửa đánh giá sản phẩm |
### Commerce Service (17 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[POST] /api/v1/wallets/checkout/direct`](./B_none/Commerce/R181_POST_WALLETS_CHECKOUT_DIRECT.md) | `` | Tạo phiên thanh toán trực tiếp qua cổng VNPay cho đơn hàng (bỏ qua số dư ví) |
| [`[POST] /api/v1/carts/items`](./B_none/Commerce/R69_POST_CART_ITEMS.md) | `` | thêm 1 hoặc nhiều sản phẩm vào giỏ hàng |
| [`[GET] /api/v1/carts`](./B_none/Commerce/R70_GET_CART.md) | `` | xem toàn bộ các sản phẩm của giỏ hàng, gửi list cart lên và kho check cái list đó và catalogc |
| [`[PATCH] /api/v1/carts/items/{id}`](./B_none/Commerce/R71_PATCH_CART_ITEMS.md) | `` | đổi số lượng 1 sản phẩm trong giỏ hàng |
| [`[DELETE] /api/v1/carts/items`](./B_none/Commerce/R72_DELETE_CART_ITEMS.md) | `` | xóa 1 hoặc nhiều sản phẩm ra khỏi giỏ |
| [`[DELETE] /api/v1/carts/items/all`](./B_none/Commerce/R73_DELETE_CART_ITEMS_ALL.md) | `` | xóa toàn bộ sản phẩm ra khỏi giỏ |
| [`[GET] /api/v1/carts/items/select`](./B_none/Commerce/R74_GET_CART_ITEMS_SELECT.md) | `` | buyer select ccasc item bên trong cart và trả ra giá tiền |
| [`[POST] /api/v1/checkouts/quote`](./B_none/Commerce/R75_POST_CHECKOUT_QUOTE.md) | `` | buyer nhập địa chi, mã giảm giá và coi trước thông tin sau giảm và thông tin tiền ship tính trước |
| [`[POST] /api/v1/orders`](./B_none/Commerce/R76_POST_ORDERS.md) | `` | tạo order |
| [`[GET] /api/v1/orders/{orderId}`](./B_none/Commerce/R77_GET_ORDER.md) | `` | lấy thôn tin chi tiết của order đó |
| [`[GET] /api/v1/orders`](./B_none/Commerce/R78_GET_ORDER_HO_C_ORDERS.md) | `` | Lấy danh sách lịch sử đơn hàng của người mua (Buyer Orders List) |
| [`[GET] /api/v1/sub-orders/{subOrderId}`](./B_none/Commerce/R79_GET_SUBORDER.md) | `` | coi thong tin chi tiết của 1 sub order |
| [`[POST] /api/v1/orders/{orderId}/cancel`](./B_none/Commerce/R80_POST_ORDERS_CANCEL.md) | `` | cancel cái order đó, chưa chuyển khoản, chưa thanh toán |
| [`[POST] /api/v1/orders/{orderId}/accept`](./B_none/Commerce/R83_POST_ORDERS_ACCEPT.md) | `` | seller chấp nhận cái đơn đó hay ko/ xác nhận |
| [`[POST] /api/v1/orders/{orderId}/reject`](./B_none/Commerce/R84_POST_ORDERS_REJECT.md) | `` | seller chấp nhận cái đơn đó hay ko/ từ chối |
| [`[GET] /api/v1/shipments/order/{orderId}`](./B_none/Commerce/R87_GET_SHIPMENTS_ORDER.md) | `` | coi order đó có mấy shipment |
| [`[POST] /api/v1/sub-orders/{subOrderId}/refund`](./B_none/Commerce/R99_POST_SUBORDER_REFUND.md) | `` | Hoàn tiền sub-order riêng lẻ kèm kiểm tra điều kiện trạng thái |
### Auction Service (21 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[POST] /api/v1/products/auction`](./B_none/Auction/R125_POST_PRODUCT_AUCTION.md) | `` | thêm sản phẩm đấu giá |
| [`[GET] /api/v1/products/auctions`](./B_none/Auction/R127_GET_PRODUCT_AUCTIONS.md) | `` | coi đươc toàn bộ các sản phẩm seller đó đã đấu giá |
| [`[GET] /api/v1/products/auction/{auctionId}`](./B_none/Auction/R128_GET_PRODUCT_AUCTION.md) | `` | coi thông tin chi tiết của sản phẩm đấu giá đó |
| [`[GET] /api/v1/auctions`](./B_none/Auction/R131_GET_AUCTIONS.md) | `` | User xem danh sách các phiên đấu giá |
| [`[GET] /api/v1/auctions/{auctionId}`](./B_none/Auction/R132_GET_AUCTIONS.md) | `` | Xem chi tiết 1 phiên đấu giá |
| [`[POST] /api/v1/auctions`](./B_none/Auction/R133_POST_AUCTIONS.md) | `` | Seller tạo phiên đấu giá, chọn 1 sản phẩm có rồi |
| [`[PUT] /api/v1/auctions/{auctionId}`](./B_none/Auction/R134_PUT_AUCTIONS.md) | `` | Seller chỉnh sửa phiên đấu giá(khi chưa bắt đầu) |
| [`[POST] /api/v1/auctions/{auctionId}/cancel`](./B_none/Auction/R135_POST_AUCTIONS_CANCEL.md) | `` | Seller hủy phiên đấu giá(khi phiên đấu giá chưa bắt đầu) |
| [`[POST] /api/v1/auctions/{auctionId}/recreate`](./B_none/Auction/R136_POST_AUCTIONS_RECREATE.md) | `` | Tạo lại phiên mới cho sản phẩm ở phiên cũ (đã bị đấu giá thất bại) |
| [`[GET] /api/v1/auctions/{auctionId}/status-history`](./B_none/Auction/R137_GET_AUCTIONS_STATUS_HISTORY.md) | `` | Nhật kí đổi trạng thái của từng auction |
| [`[GET] /api/v1/sellers/auctions`](./B_none/Auction/R138_GET_SELLER_AUCTIONS.md) | `` | Seller xem toàn bộ phiên đấu giá của mình |
| [`[POST] /api/v1/admin/auctions/{auctionId}/force-cancel`](./B_none/Auction/R139_POST_ADMIN_AUCTIONS_FORCE_CANCEL.md) | `` | Admin cưỡng chế hủy phiên đấu giá khi có bất thường |
| [`[GET] /api/v1/admin/auctions/{auctionId}/saga`](./B_none/Auction/R140_GET_ADMIN_AUCTIONS_SAGA.md) | `` | Admin theo dõi xem phiên đang ở bước nào của luồng đơn hàng(sau khi chốt người thắng -> commerce) |
| [`[GET] /api/v1/admin/auction-configs`](./B_none/Auction/R141_GET_ADMIN_AUCTION_CONFIGS.md) | `` | Xem các luật đang hiệu lực (tham chiếu tới userSerive để lấy field uy tín seller,buyer, số lần gia hạn,gia hạn bao nhiêu phút,.....) |
| [`[PUT] /api/v1/admin/auction-configs/{key}`](./B_none/Auction/R142_PUT_ADMIN_AUCTION_CONFIGS.md) | `` | Cập nhật cấu hình đấu giá(chỉ ảnh hưởng auction tương lai ) |
| [`[POST] /api/v1/auctions/{auctionId}/bids`](./B_none/Auction/R143_POST_AUCTIONS_BIDS.md) | `` | Buyer đặt giá cho một phiên đấu giá |
| [`[GET] /api/v1/auctions/{auctionId}/bids`](./B_none/Auction/R144_GET_AUCTIONS_BIDS.md) | `` | User xem được lịch sử đặt giá của phiên đang tham gia |
| [`[GET] /api/v1/me/bids`](./B_none/Auction/R145_GET_ME_BIDS.md) | `` | Buyer coi được các phiên đấu giá mà bản thân đã từng tham gia |
| [`[GET] /api/v1/auctions/{auctionId}/result`](./B_none/Auction/R146_GET_AUCTIONS_RESULT.md) | `` | Xem kết quả của phiên đấu giá |
| [`[GET] /internal/v1/auctions/status?productId={productId}`](./B_none/Auction/R148_GET_INTERNAL_V1_AUCTIONS_STATUS_PRODUCTID.md) | `` | Catalog lấy trạng thái phiên đấu giá gần nhất của một sản phẩm, để ẩn sản phẩm khỏi kho ảo khi đã bán xong |
| [`[GET] /internal/v1/auctions/{auctionId}/summary`](./B_none/Auction/R149_GET_INTERNAL_V1_AUCTIONS_SUMMARY.md) | `` | Catalog lấy thông tin chi tiết một phiên: người đang trả giá cao nhất, giá khởi điểm, giá hiện tại, bước giá |
### Fulfillment Service (9 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[POST] /api/v1/inventories/stock-in`](./B_none/Fulfillment/R114_POST_INVENTORY_STOCK_IN.md) | `` | thêm hàng vào kho, 1 list, kèm số lượng thêm, kèm chủng loại muốn thêm |
| [`[POST] /api/v1/variants/{variantId}/stock-in`](./B_none/Fulfillment/R119_POST_VARIANT_STOCK_IN.md) | `` | thêm biến thể của sản phảm vào kho |
| [`[GET] /api/v1/shipments/{shipmentId}`](./B_none/Fulfillment/R86_GET_SHIPMENTS.md) | `` | coi thông tin chi tiết của 1 shipment |
| [`[GET] /api/v1/sellers/shipments`](./B_none/Fulfillment/R88_GET_SELLER_SHIPMENT.md) | `` | lấy danh sách các đơn ship của selller phải giao |
| [`[GET] /api/v1/sellers/shipments/search`](./B_none/Fulfillment/R89_GET_SELLER_SHIPMENT_SEARCH.md) | `` | filter, search shipment của 1 seller, lọc trạng thái |
| [`[GET] /api/v1/sellers/shipments/{shipmentId}`](./B_none/Fulfillment/R90_GET_SELLER_SHIPMENT.md) | `` | coi chi tiết cái shipment của seller đó |
| [`[PATCH] /api/v1/shipments/{shipmentId}/tracking`](./B_none/Fulfillment/R91_PATCH_SHIPMENTS_TRACKING.md) | `` | cập nhập trạng thái cái shipment từ ghn |
| [`[POST] /api/v1/shipments/{shipmentId}/complete`](./B_none/Fulfillment/R97_POST_SHIPMENT_COMPLETE.md) | `` | người dùng ấn nút đã nhận được hàng |
| [`[POST] /api/v1/shipments/webhook`](./B_none/Fulfillment/R98_POST_SHIPMENTS_WEBHOOK.md) | `` | nhận thông tin từ ghn. |
### Wallet Service (11 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[GET] /api/v1/wallets/me`](./B_none/Wallet/R178_GET_WALLETS_ME.md) | `` | Lấy thông tin ví và số dư khả dụng/bị khóa của cá nhân |
| [`[POST] /api/v1/wallets/topups/vnpay`](./B_none/Wallet/R179_POST_WALLETS_TOPUPS_VNPAY.md) | `` | Tạo yêu cầu nạp tiền vào ví qua cổng VNPay và lấy URL thanh toán |
| [`[POST] /api/v1/wallets/vnpay/ipn`](./B_none/Wallet/R180_POST_WALLETS_VNPAY_IPN.md) | `` | Webhook nhận kết quả IPN từ VNPay (Nạp ví hoặc Thanh toán đơn trực tiếp) |
| [`[POST] /api/v1/wallets/withdrawals`](./B_none/Wallet/R182_POST_WALLETS_WITHDRAWALS.md) | `` | Người bán (Seller) tạo yêu cầu rút tiền từ ví về tài khoản ngân hàng |
| [`[PATCH] /api/v1/admin/wallets/withdrawals/{id}`](./B_none/Wallet/R183_PATCH_ADMIN_WALLETS_WITHDRAWALS.md) | `` | Quản trị viên duyệt hoặc từ chối yêu cầu rút tiền của Seller |
| [`[GET] /api/v1/wallets/transactions`](./B_none/Wallet/R184_GET_WALLETS_TRANSACTIONS.md) | `` | Tra cứu lịch sử biến động sổ cái (wallet_transactions) cá nhân |
| [`[POST] /api/v1/admin/wallets/{walletId}/adjustments`](./B_none/Wallet/R185_POST_ADMIN_WALLETS_ADJUSTMENTS.md) | `` | Admin điều chỉnh số dư ví thủ công (Cộng/Trừ tiền kèm kiểm toán) |
| [`[POST] /api/v1/wallets/transfers`](./B_none/Wallet/R186_POST_WALLETS_TRANSFERS.md) | `` | Chuyển tiền nội bộ giữa hai ví, ghi hai bút toán TransferOut/TransferIn |
| [`[GET] /api/v1/wallets/vnpay/return`](./B_none/Wallet/R187_GET_WALLETS_VNPAY_RETURN.md) | `` | Browser return callback từ VNPay sau khi thanh toán |
| [`[POST] /api/v1/wallets/checkout/direct`](./B_none/Wallet/R188_POST_WALLETS_CHECKOUT_DIRECT.md) | `` | Thanh toán trực tiếp cho đơn hàng từ ví (liên service, route công khai, Internal API tạm khóa) |
| [`[POST] /api/v1/payments/webhook`](./B_none/Wallet/R81_POST_PAYMENTS_WEBHOOK.md) | `` | ⚠️ `SUPERSEDED` — endpoint không tồn tại; dùng R180 thay thế |
### Notification Service (11 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[POST] /api/v1/notifications/devices`](./B_none/Notification/R186_POST_NOTIFICATIONS_DEVICES.md) | `` | Đăng ký hoặc làm mới FCM/APNs device token để nhận push notification |
| [`[DELETE] /api/v1/notifications/devices`](./B_none/Notification/R187_DELETE_NOTIFICATIONS_DEVICES.md) | `` | Thu hồi hoặc vô hiệu hóa device token khi logout hoặc tắt quyền push |
| [`[GET] /api/v1/notifications/preferences`](./B_none/Notification/R188_GET_NOTIFICATIONS_PREFERENCES.md) | `` | Lấy danh sách cấu hình bật/tắt nhận thông báo của người dùng |
| [`[PUT] /api/v1/notifications/preferences`](./B_none/Notification/R189_PUT_NOTIFICATIONS_PREFERENCES.md) | `` | Cập nhật tùy chọn bật/tắt nhận thông báo theo loại sự kiện và kênh gửi |
| [`[GET] /api/v1/notifications/me`](./B_none/Notification/R190_GET_NOTIFICATIONS_ME.md) | `` | Lấy danh sách lịch sử thông báo in-app (quả chuông) kèm số lượng chưa đọc |
| [`[PATCH] /api/v1/notifications/me/read`](./B_none/Notification/R191_PATCH_NOTIFICATIONS_ME_READ.md) | `` | Đánh dấu một số hoặc toàn bộ thông báo trong hộp thư là đã đọc |
| [`[GET] /api/v1/admin/notifications/channels/{code}`](./B_none/Notification/R192_GET_ADMIN_NOTIFICATIONS_CHANNELS.md) | `` | Admin xem trạng thái và cấu hình kênh gửi thông báo |
| [`[PUT] /api/v1/admin/notifications/channels/{code}`](./B_none/Notification/R193_PUT_ADMIN_NOTIFICATIONS_CHANNELS.md) | `` | Admin cập nhật cấu hình và bật/tắt kênh gửi thông báo |
| [`[GET] /api/v1/admin/notifications/templates`](./B_none/Notification/R194_GET_ADMIN_NOTIFICATIONS_TEMPLATES.md) | `` | Admin xem danh sách mẫu thông báo (Template Engine) |
| [`[POST] /api/v1/admin/notifications/templates`](./B_none/Notification/R195_POST_ADMIN_NOTIFICATIONS_TEMPLATES.md) | `` | Admin tạo mẫu nội dung thông báo mới |
| [`[GET] /api/v1/admin/notifications`](./B_none/Notification/R196_GET_ADMIN_NOTIFICATIONS.md) | `` | Admin/Staff tra cứu lịch sử gửi thông báo và nhật ký lỗi delivery |
### Log Service (4 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[GET] /api/v1/logs`](./B_none/Log/LOG-01_GET_ROOT.md) | `LOG-01` | Truy vấn danh sách nhật ký hệ thống tập trung (Centralized Logs) có phân trang và bộ lọc linh hoạt. |
| [`[GET] /api/v1/logs/{id}`](./B_none/Log/LOG-02_GET_ID.md) | `LOG-02` | Tra cứu chi tiết một bản ghi nhật ký hệ thống theo mã định danh UUID. |
| [`[GET] /api/v1/logs/event-types`](./B_none/Log/LOG-03_GET_EVENT_TYPES.md) | `LOG-03` | Lấy danh mục các loại sự kiện hệ thống đã đăng ký theo dõi kiểm toán. |
| [`[PUT] /api/v1/logs/event-types/{code}`](./B_none/Log/LOG-04_PUT_EVENT_TYPES_CODE.md) | `LOG-04` | Bật hoặc tắt trạng thái ghi nhật ký cho một loại sự kiện cụ thể. |
### CheckHeal Service (4 endpoints)

| Endpoint & Liên kết file | Ref Excel | Mô tả nghiệp vụ |
|:---|:---:|:---|
| [`[GET] /api/v1/healthcheck/status`](./B_none/CheckHeal/CHK-01_GET_STATUS.md) | `CHK-01` | Báo cáo tổng quan tình trạng sức khỏe toàn bộ hệ thống (8 Microservices & 8 Databases). |
| [`[GET] /api/v1/healthcheck/services`](./B_none/CheckHeal/CHK-02_GET_SERVICES.md) | `CHK-02` | Lấy danh sách chi tiết trạng thái kiểm tra sức khỏe của các Microservices. |
| [`[GET] /api/v1/healthcheck/services/{name}`](./B_none/CheckHeal/CHK-03_GET_SERVICES_NAME.md) | `CHK-03` | Xem chi tiết trạng thái kết nối và độ trễ của một dịch vụ cụ thể. |
| [`[PUT] /api/v1/healthcheck/services/{name}/toggle`](./B_none/CheckHeal/CHK-04_PUT_SERVICES_NAME_TOGGLE.md) | `CHK-04` | Bật hoặc tắt giám sát định kỳ cho một dịch vụ cụ thể. |

---

## 9. LIÊN HỆ & HỖ TRỢ KỸ THUẬT

- **API Gateway Swagger UI**: [http://localhost:8080/swagger](http://localhost:8080/swagger)
- **Kiểm tra sức khỏe hệ thống (CheckHeal)**: `GET http://localhost:8080/api/v1/healthcheck/status`
- **Mẫu văn bản tài liệu API chuẩn**: Xem tại `docs/api/API_DOC_TEMPLATE.md`
