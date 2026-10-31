# BẢNG ĐỐI CHIẾU VÀ ĐẶC TẢ API GATEWAY CHO FRONTEND
# (FRONTEND API ENDPOINT MAPPING & INTEGRATION GUIDE)

> **Cổng truy cập duy nhất (Single Gateway Entrypoint):** `http://localhost:8080`  
> **Phiên bản API:** `v1` (`/api/v1/...`)  
> **Giao thức chuẩn:** 100% RESTful HTTP/JSON (RFC 9110)  
> **Interactive Swagger UI:** [http://localhost:8080/swagger](http://localhost:8080/swagger)  
> **Trạng thái chuẩn hóa:** ✅ 100% Số nhiều (Plural Collections): `/users`, `/sellers`, `/products`, `/categories`, `/carts`, `/orders`, `/shipments`, `/wallets`, `/auctions`, `/notifications`, `/logs`. Ngoại lệ đơn lẻ (Singleton): `/me` và `/auth`.

---

## MỤC LỤC

1. [Quy Chuẩn Kiến Trúc & Tích Hợp Frontend](#1-quy-chuẩn-kiến-trúc--tích-hợp-frontend)
2. [Cấu Trúc Phong Bì Dữ Liệu (Response Envelope Standards)](#2-cấu-trúc-phong-bì-dữ-liệu-response-envelope-standards)
3. [Headers Toàn Cục & Cơ Chế Mock Mode](#3-headers-toàn-cục--cơ-chế-mock-mode)
4. [Bảng Mã Lỗi Chuẩn Toàn Hệ Thống (Standard Error Codes)](#4-bảng-mã-lỗi-chuẩn-toàn-hệ-thống-standard-error-codes)
5. [Ma Trận Phân Quyền (RBAC Policies)](#5-ma-trận-phân-quyền-rbac-policies)
6. [Danh Mục Endpoint Chi Tiết Theo Module](#6-danh-mục-endpoint-chi-tiết-theo-module)
   - [6.1 Module Xác Thực (Authentication)](#61-module-xác-thực-authentication)
   - [6.2 Module Người Dùng & Hồ Sơ (User & Profile)](#62-module-người-dùng--hồ-sơ-user--profile)
   - [6.3 Module Quản Trị Người Dùng (Admin Users)](#63-module-quản-trị-người-dùng-admin-users)
   - [6.4 Module Sản Phẩm & Danh Mục (Products & Catalog)](#64-module-sản-phẩm--danh-mục-products--catalog)
   - [6.5 Module Danh Mục Hàng Hoá (Categories)](#65-module-danh-mục-hàng-hoá-categories)
   - [6.6 Module Tồn Kho (Inventory)](#66-module-tồn-kho-inventory)
   - [6.7 Module Giỏ Hàng (Cart)](#67-module-giỏ-hàng-cart)
   - [6.8 Module Đơn Hàng & Thanh Toán (Orders & Checkout)](#68-module-đơn-hàng--thanh-toán-orders--checkout)
   - [6.9 Module Đấu Giá (Auctions)](#69-module-đấu-giá-auctions)
   - [6.10 Module Vận Chuyển & Kho Vận (Fulfillment)](#610-module-vận-chuyển--kho-vận-fulfillment)
   - [6.11 Module Thông Báo (Notifications)](#611-module-thông-báo-notifications)
   - [6.12 Module Ví & Giao Dịch (Wallets & Financial)](#612-module-ví--giao-dịch-wallets--financial)
   - [6.13 Module Điều Khiển Gateway & Giám Sát Sức Khỏe (Gateway Control & Health Prober)](#613-module-điều-khiển-gateway--giám-sát-sức-khỏe-gateway-control--health-prober)

---

## 1. QUY CHUẨN KIẾN TRÚC & TÍCH HỢP FRONTEND

1. **Điểm chạm duy nhất**: Frontend (React, Vue, Next.js, Mobile App) chỉ gửi request đến Gateway tại `http://localhost:8080`. Không gọi trực tiếp vào các cổng microservice nội bộ (`8001`-`8008`).
2. **Quy ước định tuyến (Routing Conventions)**:
   - **Quy chuẩn 100% Số nhiều (100% Plural Collections)**:
     - ✅ Bộ sưu tập tài nguyên: `/api/v1/users`, `/api/v1/users/{userId}`, `/api/v1/admin/users`, `/api/v1/sellers`, `/api/v1/products`, `/api/v1/categories`, `/api/v1/carts`, `/api/v1/orders`, `/api/v1/shipments`, `/api/v1/auctions`, `/api/v1/wallets`, `/api/v1/notifications`, `/api/v1/logs`.
     - ✅ Ngoại lệ đơn lẻ (Singleton): `/api/v1/me` (hồ sơ của chính mình) và `/api/v1/auth` (các hành động xác thực).
3. **Quy tắc đặt tên (Casing Rules)**:
   - JSON Request & Response body: `camelCase` (ví dụ: `userId`, `phoneNumber`, `pageIndex`, `totalCount`).
   - Query string parameters: `camelCase` (ví dụ: `?page=1&pageSize=20&keyword=abc`).
   - Route path parameters: `camelCase` (ví dụ: `{userId}`, `{orderId}`, `{auctionId}`).
   - Status & Enums: Luôn tuần tự hóa thành chuỗi `PascalCase` ở JSON Response (ví dụ: `PendingPayment`, `Active`, `InTransit`), cấm số nguyên thô.

---

## 2. CẤU TRÚC PHONG BÌ DỮ LIỆU (RESPONSE ENVELOPE STANDARDS)

### 2.1 Phản hồi Thành công Có Payload (`ApiResponse<T>`) — HTTP 200 / 201
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User profile retrieved successfully.",
  "data": {
    "id": "11111111-1111-1111-1111-111111111111",
    "email": "buyer01@mcs.local",
    "firstName": "Alex",
    "lastName": "Rivers"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-29T01:00:00Z"
}
```

### 2.2 Phản hồi Danh sách Phân trang (`ApiResponse<PagedData<T>>`) — HTTP 200
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Users retrieved successfully.",
  "data": {
    "items": [
      { "id": "uuid-1", "username": "buyer01", "email": "buyer01@mcs.local" }
    ],
    "pageIndex": 1,
    "pageSize": 20,
    "totalCount": 105,
    "totalPages": 6,
    "hasPreviousPage": false,
    "hasNextPage": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-29T01:00:00Z"
}
```

### 2.3 Phản hồi Xoá / Thành công Không Payload — HTTP 204 NoContent
- **Status Code**: `204 NoContent`
- **Response Body**: Hoàn toàn rỗng (Empty body).

### 2.4 Phản hồi Thất bại Chuẩn RFC 9110 ProblemDetails — HTTP 4xx / 5xx
```json
{
  "type": "https://httpstatuses.io/400",
  "title": "Bad Request",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Email is already registered in the system.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-29T01:00:00Z",
  "errors": {
    "email": ["Email format is invalid."]
  }
}
```

---

## 3. HEADERS TOÀN CỤC & CƠ CHẾ MOCK MODE

| Header | Kiểu / Giá trị | Mô tả & Tình huống sử dụng |
|:---|:---|:---|
| `Authorization` | `Bearer <jwt_token>` | Bắt buộc đối với mọi endpoint yêu cầu đăng nhập. |
| `Content-Type` | `application/json` | Bắt buộc khi gửi JSON body (`POST`, `PUT`, `PATCH`). |
| `Idempotency-Key` | UUID string (v4) | Khuyến nghị cho các giao dịch đặt giá đấu giá (`AUC-07`), nạp/rút tiền, thanh toán. |
| `X-Mock` | `true` hoặc `false` | Ép buộc Gateway trả dữ liệu Mock từ fixture `Seeds/` bất kể backend thật đang chạy hay tắt. Rất hữu ích khi Frontend độc lập làm UI. |
| `X-Service-Modes` | `users=Mock;catalog=Real` | Điều khiển nóng chế độ Mock/Real cho từng service riêng rẽ trên từng request. |
| `X-User-Role` | `Buyer` / `Seller` / `Staff` / `Admin` | Giả lập Role người dùng khi Gateway chạy ở cấu hình Development `AuthMode=Bypass`. |
| `X-Trace-Id` | String | Gateway tự sinh hoặc nhận từ client để truy vết luồng distributed tracing trên Grafana Tempo. |

---

## 4. BẢNG MÃ LỖI CHUẨN TOÀN HỆ THỐNG (STANDARD ERROR CODES)

Tất cả thông báo lỗi (`detail`) 100% bằng tiếng Anh Sentence case. Mã lỗi (`errorCode`) định dạng `SCREAMING_SNAKE_CASE`:

| Mã Lỗi (errorCode) | HTTP Status | Ý Nghĩa / Nguyên Nhân Nghiệp Vụ |
|:---|:---:|:---|
| `VAL_INVALID_INPUT` | 400 | Dữ liệu đầu vào sai định dạng, thiếu trường bắt buộc, vượt độ dài. |
| `VAL_INVALID_EMAIL` | 400 | Định dạng địa chỉ email không hợp lệ. |
| `VAL_INVALID_PASSWORD` | 400 | Mật khẩu không đạt yêu cầu bảo mật (tối thiểu 8 ký tự). |
| `VAL_INVALID_OTP` | 400 | Mã OTP không đúng định dạng (phải là 6 chữ số). |
| `VAL_INVALID_AMOUNT` | 400 | Số tiền giao dịch âm hoặc thấp hơn hạn mức tối thiểu. |
| `UNAUTHORIZED` | 401 | Thiếu JWT Token, Token hết hạn hoặc chữ ký không hợp lệ. |
| `FORBIDDEN` | 403 | Người dùng không đủ quyền hạn (Role) để truy cập tài nguyên. |
| `NOT_FOUND` | 404 | Tài nguyên được yêu cầu không tồn tại trong hệ thống. |
| `USER_NOT_FOUND` | 404 | Không tìm thấy tài khoản người dùng theo định danh. |
| `EMAIL_ALREADY_EXISTS` | 409 | Địa chỉ email đã được đăng ký trên hệ thống. |
| `OTP_EXPIRED` | 400 | Mã OTP đã quá hạn sử dụng (sau 5 phút). |
| `OTP_ALREADY_USED` | 400 | Mã OTP này đã được kích hoạt trước đó. |
| `INSUFFICIENT_BALANCE` | 400 | Số dư khả dụng trong ví không đủ để thanh toán/đặt giá. |
| `AUCTION_ENDED` | 400 | Phiên đấu giá đã kết thúc hoặc đã bị hủy. |
| `BID_TOO_LOW` | 400 | Giá đặt không cao hơn giá hiện tại cộng bước giá tối thiểu. |
| `RATE_LIMIT_EXCEEDED` | 429 | Gửi quá số lượng request cho phép trong khung thời gian. |
| `SERVICE_UNAVAILABLE` | 503 | Backend microservice tạm thời không phản hồi hoặc Circuit Breaker mở. |

---

## 5. MA TRẬN PHÂN QUYỀN (RBAC POLICIES)

- `AllowAnonymous`: Bất kỳ ai cũng gọi được (Đăng ký, Đăng nhập, Xem sản phẩm công khai, Xem đấu giá).
- `Authenticated`: Bất kỳ tài khoản nào có JWT hợp lệ.
- `Customer` (`BuyerOrSeller`): Người mua hoặc người bán có tài khoản kích hoạt.
- `Seller`: Tài khoản đã đăng ký cửa hàng và được duyệt thành công.
- `Staff`: Nhân viên vận hành, hỗ trợ khách hàng, kiểm duyệt báo cáo.
- `Admin`: Quản trị viên hệ thống (quyền quản trị tài khoản, cấu hình hệ thống, phân quyền).
- `StaffOrAdmin`: Cả nhân viên vận hành hoặc quản trị viên.
- `GatewayAdmin`: Tài khoản kỹ trị mạng gateway (dùng cho API Gateway Control & Prober).

---

## 6. DANH MỤC ENDPOINT CHI TIẾT THEO MODULE

### 6.1 Module Xác Thực (Authentication)
*Service backend phụ trách: `users` (Port 8001)*

#### 1. Đăng ký tài khoản mới
- **Endpoint**: `POST /api/v1/auth/register`
- **Quyền**: `AllowAnonymous`
- **Request Body (`RegisterRequestDto`)**:
  ```json
  {
    "username": "johndoe",
    "email": "johndoe@example.com",
    "password": "Password123!",
    "firstName": "John",
    "lastName": "Doe"
  }
  ```
- **Response** (HTTP 201): `ApiResponse<RegisterResponseDto>` (trả về `userId`, `email`, `registeredAt`).
- **Mã lỗi thường gặp**: `EMAIL_ALREADY_EXISTS`, `VAL_INVALID_INPUT`.

#### 2. Xác thực OTP đăng ký
- **Endpoint**: `POST /api/v1/auth/otp/verify`
- **Quyền**: `AllowAnonymous`
- **Request Body (`VerifyOtpRequestDto`)**:
  ```json
  {
    "email": "johndoe@example.com",
    "otp": "123456"
  }
  ```
- **Response** (HTTP 200): `ApiResponse<VerifyOtpResponseDto>` (`isVerified: true`).
- **Mã lỗi thường gặp**: `OTP_INVALID`, `OTP_EXPIRED`, `OTP_ALREADY_USED`, `USER_NOT_FOUND`.

#### 3. Gửi lại mã OTP
- **Endpoint**: `POST /api/v1/auth/otp/resend`
- **Quyền**: `AllowAnonymous`
- **Request Body (`ResendOtpRequestDto`)**:
  ```json
  {
    "email": "johndoe@example.com"
  }
  ```
- **Response** (HTTP 200): `ApiResponse<ResendOtpResponseDto>` (`sent: true`).

#### 4. Đăng nhập hệ thống
- **Endpoint**: `POST /api/v1/auth/login`
- **Quyền**: `AllowAnonymous`
- **Request Body (`LoginRequestDto`)**:
  ```json
  {
    "username": "johndoe",
    "password": "Password123!"
  }
  ```
- **Response** (HTTP 200): `ApiResponse<LoginResponseDto>` (trả về `accessToken`, `refreshToken`, `tokenType: "Bearer"`, `userProfile`).

#### 5. Làm mới Access Token
- **Endpoint**: `POST /api/v1/auth/refresh`
- **Quyền**: `AllowAnonymous`
- **Request Body (`RefreshTokenDto`)**:
  ```json
  {
    "refreshToken": "sample-refresh-token-uuid"
  }
  ```
- **Response** (HTTP 200): `ApiResponse<RefreshTokenResponseDto>`.

#### 6. Quên mật khẩu
- **Endpoint**: `POST /api/v1/auth/password/forgot`
- **Quyền**: `AllowAnonymous`
- **Request Body (`ForgotPasswordDto`)**: `{ "email": "johndoe@example.com" }`
- **Response** (HTTP 200): `ApiResponse<ForgotPasswordResponseDto>`.

#### 7. Đặt lại mật khẩu bằng OTP
- **Endpoint**: `PUT /api/v1/auth/password/reset`
- **Quyền**: `AllowAnonymous`
- **Request Body (`ResetPasswordDto`)**: `{ "email": "johndoe@example.com", "otp": "123456", "newPassword": "NewPassword123!" }`
- **Response** (HTTP 200): `ApiResponse<ResetPasswordResponseDto>`.

#### 8. Đổi mật khẩu tài khoản
- **Endpoint**: `PATCH /api/v1/auth/password`
- **Quyền**: `Authenticated`
- **Request Body (`ChangePasswordDto`)**: `{ "currentPassword": "OldPassword123!", "newPassword": "NewPassword123!" }`
- **Response** (HTTP 200): `ApiResponse<ChangePasswordResponseDto>`.

#### 9. Đăng xuất phiên hiện tại
- **Endpoint**: `POST /api/v1/auth/logout`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<LogoutResponseDto>`.

#### 10. Đăng xuất khỏi toàn bộ thiết bị
- **Endpoint**: `POST /api/v1/auth/logout-all`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<LogoutResponseDto>`.

---

### 6.2 Module Người Dùng & Hồ Sơ (User & Profile)
*Service backend phụ trách: `users` (Port 8001)*

#### 1. Lấy thông tin cá nhân của người dùng hiện tại
- **Endpoint**: `GET /api/v1/me` *(Lưu ý: Không dùng route cũ `users/me`)*
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<UserProfileDto>` (id, email, username, firstName, lastName, phoneNumber, avatarUrl, roles, reputationScore).

#### 2. Cập nhật hồ sơ cá nhân
- **Endpoint**: `PATCH /api/v1/me`
- **Quyền**: `Authenticated`
- **Request Body (`UpdateMyProfileDto`)**: `{ "firstName": "John", "lastName": "Doe", "phoneNumber": "0912345678" }`
- **Response** (HTTP 200): `ApiResponse<MyProfileUpdatedResponseDto>`.

#### 3. Danh sách phiên đăng nhập của tôi
- **Endpoint**: `GET /api/v1/me/sessions`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<SessionListResponseDto>`.

#### 4. Thu hồi 1 phiên đăng nhập
- **Endpoint**: `DELETE /api/v1/me/sessions/{sessionId}`
- **Quyền**: `Authenticated`
- **Response** (HTTP 204): `204 NoContent`.

#### 5. Lấy Avatar cá nhân
- **Endpoint**: `GET /api/v1/me/avatar`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<AvatarResponseDto>`.

#### 6. Tải lên Avatar mới
- **Endpoint**: `POST /api/v1/me/avatar`
- **Quyền**: `Authenticated`
- **Content-Type**: `multipart/form-data`
- **Form Fields**: `file` (Binary image file, max 10MB).
- **Response** (HTTP 200): `ApiResponse<AvatarUploadedResponseDto>`.

#### 7. Điểm uy tín cá nhân
- **Endpoint**: `GET /api/v1/me/reputation`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<MyReputationResponseDto>`.

#### 8. Lịch sử bị phạt / vi phạm
- **Endpoint**: `GET /api/v1/me/penalties?page=1&limit=20`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<PenaltyListResponseDto>`.

#### 9. Xem hồ sơ công khai của một người dùng
- **Endpoint**: `GET /api/v1/users/{userId}`
- **Quyền**: `AllowAnonymous`
- **Response** (HTTP 200): `ApiResponse<PublicUserProfileResponseDto>`.

#### 10. Lấy Avatar công khai của một người dùng
- **Endpoint**: `GET /api/v1/users/{userId}/avatar`
- **Quyền**: `AllowAnonymous`
- **Response** (HTTP 200): `ApiResponse<AvatarResponseDto>`.

#### 11. Xem thông tin cửa hàng người bán
- **Endpoint**: `GET /api/v1/sellers/{sellerId}`
- **Quyền**: `AllowAnonymous`
- **Response** (HTTP 200): `ApiResponse<SellerPublicProfileResponseDto>`.

#### 12. Xem điểm uy tín công khai của người dùng
- **Endpoint**: `GET /api/v1/users/{userId}/reputation`
- **Quyền**: `AllowAnonymous`
- **Response** (HTTP 200): `ApiResponse<UserReputationResponseDto>`.

#### 13. Lịch sử biến động uy tín của người dùng
- **Endpoint**: `GET /api/v1/users/{userId}/reputation/history?page=1&limit=20`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<ReputationHistoryResponseDto>`.

#### 14. Danh sách đánh giá về một người dùng
- **Endpoint**: `GET /api/v1/users/{userId}/reviews?page=1&limit=20&filterRating=0`
- **Quyền**: `AllowAnonymous`
- **Response** (HTTP 200): `ApiResponse<UserReviewListResponseDto>`.

#### 15. Tải tệp bằng chứng đánh giá
- **Endpoint**: `POST /api/v1/reviews/files/upload`
- **Quyền**: `Authenticated` (multipart/form-data, max 20MB)
- **Response** (HTTP 200): `ApiResponse<UploadFilesResponseDto>`.

#### 16. Gửi đánh giá người dùng / giao dịch
- **Endpoint**: `POST /api/v1/reviews`
- **Quyền**: `Authenticated`
- **Request Body (`CreateReviewDto`)**:
  ```json
  {
    "transactionType": "ORDER",
    "transactionId": "order-uuid",
    "targetUserId": "user-uuid",
    "rating": 5,
    "comment": "Fast shipping, great quality."
  }
  ```
- **Response** (HTTP 201): `ApiResponse<ReviewCreatedResponseDto>`.

#### 17. Tải lên tệp chứng cứ tố cáo / khiếu nại
- **Endpoint**: `POST /api/v1/reports/files/upload`
- **Quyền**: `Authenticated` (multipart/form-data, max 20MB)
- **Response** (HTTP 200): `ApiResponse<UploadFilesResponseDto>`.

#### 18. Gửi báo cáo / khiếu nại vi phạm người dùng
- **Endpoint**: `POST /api/v1/users/reports`
- **Quyền**: `Authenticated`
- **Request Body (`CreateUserReportDto`)**:
  ```json
  {
    "reportedUserId": "user-uuid",
    "violationType": "FRAUD",
    "description": "Seller did not send item after payment."
  }
  ```
- **Response** (HTTP 201): `ApiResponse<UserReportCreatedResponseDto>`.

#### 19. Danh sách khiếu nại của tôi
- **Endpoint**: `GET /api/v1/me/reports?page=1&limit=20&status=`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<MyReportListResponseDto>`.

#### 20. Đăng ký mở cửa hàng người bán (Seller Registration)
- **Endpoint**: `POST /api/v1/sellers/registration`
- **Quyền**: `Authenticated`
- **Request Body (`CreateSellerRegistrationDto`)**:
  ```json
  {
    "shopName": "Nexus Shop",
    "businessEmail": "shop@nexus.local",
    "hotline": "0987654321",
    "identityCardNumber": "012345678901"
  }
  ```
- **Response** (HTTP 201): `ApiResponse<SellerRegistrationCreatedResponseDto>`.

#### 21. Gửi lại OTP xác nhận email mở shop
- **Endpoint**: `POST /api/v1/sellers/registration/otp/resend`
- **Quyền**: `Authenticated`
- **Request Body (`ResendSellerRegistrationOtpDto`)**: `{ "registrationId": "reg-uuid", "businessEmail": "shop@nexus.local" }`
- **Response** (HTTP 200): `ApiResponse<SellerRegistrationOtpResendResponseDto>`.

#### 22. Tải lên tài liệu mở shop (CCCD / Giấy phép kinh doanh)
- **Endpoint**: `POST /api/v1/sellers/registration/documents`
- **Quyền**: `Authenticated` (multipart/form-data, max 20MB)
- **Form Fields**: `registrationId`, `files`.
- **Response** (HTTP 200): `ApiResponse<UploadFilesResponseDto>`.

#### 23. Xác nhận OTP đăng ký người bán
- **Endpoint**: `POST /api/v1/sellers/otp/verify`
- **Quyền**: `Authenticated`
- **Request Body (`VerifySellerOtpDto`)**: `{ "registrationId": "reg-uuid", "otpCode": "123456" }`
- **Response** (HTTP 200): `ApiResponse<VerifySellerOtpResponseDto>`.

#### 24. Xem trạng thái hồ sơ đăng ký người bán
- **Endpoint**: `GET /api/v1/sellers/registration`
- **Quyền**: `Authenticated`
- **Response** (HTTP 200): `ApiResponse<SellerRegistrationStatusResponseDto>`.

#### 25. Xem hồ sơ cửa hàng của chính mình
- **Endpoint**: `GET /api/v1/sellers/profile`
- **Quyền**: `Seller`
- **Response** (HTTP 200): `ApiResponse<SellerOwnProfileResponseDto>`.

#### 26. Cập nhật hồ sơ cửa hàng của mình
- **Endpoint**: `PATCH /api/v1/sellers/profile`
- **Quyền**: `Seller`
- **Request Body (`UpdateSellerOwnProfileDto`)**: `{ "shopName": "New Shop Name", "description": "High tech store" }`
- **Response** (HTTP 200): `ApiResponse<SellerOwnProfileUpdatedResponseDto>`.

---

### 6.3 Module Quản Trị Người Dùng (Admin Users)
*Service backend phụ trách: `users` (Port 8001)*  
*Tiêu chuẩn routing: Toàn bộ dùng chuẩn số nhiều `/api/v1/admin/users` và `/api/v1/admin/users/{userId}`.*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Request Params / Body | Phản Hồi | Mô Tả Chức Năng |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/admin/users` | `Staff` | Query: `page=1, pageSize=20, keyword, role, status` | `200 ApiResponse<AdminUserListResponseDto>` | Tra cứu & phân trang danh sách người dùng. |
| `POST /api/v1/admin/users` | `Admin` | Body: `CreateAdminUserDto` (`email, password, firstName, lastName`) | `201 ApiResponse<AdminUserCreatedResponseDto>` | Tạo tài khoản người dùng mới từ trang quản trị. |
| `GET /api/v1/admin/users/{userId}` | `Staff` | Route: `userId` (GUID) | `200 ApiResponse<AdminUserDetailResponseDto>` | Lấy chi tiết thông tin quản trị tài khoản. |
| `PUT /api/v1/admin/users/{userId}` | `Admin` | Route: `userId`, Body: `UpdateAdminUserDto` (`firstName, lastName, reason`) | `200 ApiResponse<AdminUserUpdatedResponseDto>` | Cập nhật thông tin tài khoản người dùng. |
| `DELETE /api/v1/admin/users/{userId}` | `Admin` | Route: `userId`, Body: `DeleteAdminUserDto` (`reason`) | `204 NoContent` | Xóa mềm / vô hiệu hóa tài khoản người dùng. |
| `PATCH /api/v1/admin/users/{userId}/ban` | `StaffOrAdmin` | Route: `userId`, Body: `BanAdminUserDto` (`reason, banDurationDays`) | `200 ApiResponse<AdminUserBanResponseDto>` | Khóa tài khoản người dùng kèm lý do. |
| `PATCH /api/v1/admin/users/{userId}/unban` | `StaffOrAdmin` | Route: `userId`, Body: `UnbanAdminUserDto` (`reason`) | `200 ApiResponse<AdminUserUnbanResponseDto>` | Mở khóa tài khoản người dùng. |
| `PUT /api/v1/admin/users/{userId}/roles` | `Admin` | Route: `userId`, Body: `AssignAdminUserRolesDto` (`roleCodes, reason`) | `200 ApiResponse<AdminUserRolesResponseDto>` | Cập nhật gán vai trò (Roles) cho tài khoản. |
| `PATCH /api/v1/admin/users/{userId}/reputation` | `Admin` | Route: `userId`, Body: `AdjustAdminUserReputationDto` (`delta, reason`) | `200 ApiResponse<AdminUserReputationResponseDto>` | Cộng/trừ điểm uy tín người dùng thủ công. |
| `GET /api/v1/admin/seller-registrations` | `Staff` | Query: `page=1, pageSize=20, status` | `200 ApiResponse<AdminSellerRegistrationListResponseDto>` | Danh sách đơn xin mở shop người bán. |
| `GET /api/v1/admin/seller-registrations/{registrationId}` | `Staff` | Route: `registrationId` | `200 ApiResponse<AdminSellerRegistrationDetailResponseDto>` | Xem hồ sơ chi tiết đơn xin mở shop. |
| `PUT /api/v1/admin/seller-registrations/{registrationId}/approve` | `Staff` | Route: `registrationId`, Body: `ApproveSellerRegistrationDto` | `200 ApiResponse<ApproveSellerRegistrationResponseDto>` | Phê duyệt đơn đăng ký bán hàng. |
| `PUT /api/v1/admin/seller-registrations/{registrationId}/reject` | `Staff` | Route: `registrationId`, Body: `RejectSellerRegistrationDto` (`rejectionReason`) | `200 ApiResponse<RejectSellerRegistrationResponseDto>` | Từ chối đơn đăng ký bán hàng kèm lý do. |
| `GET /api/v1/admin/sellers/{sellerId}` | `Staff` | Route: `sellerId` (GUID) | `200 ApiResponse<AdminSellerDetailResponseDto>` | Xem chi tiết hồ sơ người bán phục vụ quản trị. |
| `GET /api/v1/admin/reports` | `Staff` | Query: `page=1, limit=20, status, violationType` | `200 ApiResponse<AdminReportListResponseDto>` | Danh sách báo cáo vi phạm cần xử lý. |
| `PUT /api/v1/admin/reports/{reportId}/resolve` | `Staff` | Route: `reportId`, Body: `ResolveAdminReportDto` (`action`) | `200 ApiResponse<ResolveAdminReportResponseDto>` | Xử lý hoàn tất khiếu nại báo cáo. |
| `PUT /api/v1/admin/reports/{reportId}/dismiss` | `Staff` | Route: `reportId`, Body: `DismissAdminReportDto` (`reason`) | `200 ApiResponse<DismissAdminReportResponseDto>` | Bác bỏ khiếu nại vi phạm. |
| `PUT /api/v1/admin/reviews/{reviewId}/hide` | `Staff` | Route: `reviewId`, Body: `HideAdminReviewDto` (`reason`) | `200 ApiResponse<HideAdminReviewResponseDto>` | Ẩn đánh giá vi phạm tiêu chuẩn cộng đồng. |
| `GET /api/v1/admin/roles` | `StaffOrAdmin` | Không | `200 ApiResponse<AdminRoleListResponseDto>` | Danh sách toàn bộ các vai trò trong hệ thống. |
| `GET /api/v1/admin/permissions` | `StaffOrAdmin` | Không | `200 ApiResponse<AdminPermissionListResponseDto>` | Danh sách các quyền chi tiết (Permissions). |
| `PUT /api/v1/admin/roles/{roleId}/permissions` | `Admin` | Route: `roleId`, Body: `UpdateAdminRolePermissionsDto` (`permissionIds, description`) | `200 ApiResponse<AdminRolePermissionsUpdatedResponseDto>` | Cập nhật ma trận quyền cho một vai trò. |
| `GET /api/v1/admin/audit-logs` | `StaffOrAdmin` | Query: `page=1, limit=20, actorId, action, fromDate, toDate` | `200 ApiResponse<AdminAuditLogListResponseDto>` | Tra cứu nhật ký kiểm toán hành vi quản trị. |
| `GET /api/v1/admin/configs` | `StaffOrAdmin` | Không | `200 ApiResponse<AdminConfigListResponseDto>` | Danh sách cấu hình hệ thống hiện tại. |
| `PUT /api/v1/admin/configs` | `Admin` | Body: `UpdateAdminConfigDto` (`key, value, reason`) | `200 ApiResponse<AdminConfigUpdatedResponseDto>` | Thay đổi giá trị một khóa cấu hình hệ thống. |

---

### 6.4 Module Sản Phẩm & Danh Mục (Products & Catalog)
*Service backend phụ trách: `catalog` (Port 8002)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số & Request Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/products` | `AllowAnonymous` | Query: `page=1, limit=20, categoryId, minPrice, maxPrice, rating, sort` | `200 ApiResponse<ProductListResponseDto>` | Khách xem danh sách sản phẩm phân trang & bộ lọc. |
| `GET /api/v1/products/search` | `Seller` | Query: `page=1, limit=20, keyword, status` | `200 ApiResponse<ProductSearchResponseDto>` | Người bán tìm kiếm sản phẩm trong kho của mình. |
| `GET /api/v1/products/{productId}` | `AllowAnonymous` | Route: `productId` | `200 ApiResponse<ProductDetailResponseDto>` | Xem chi tiết sản phẩm, thuộc tính và các biến thể. |
| `POST /api/v1/products` | `Seller` | Body: `CreateProductDto` (`name, description, categoryId, basePrice, variants`) | `201 ApiResponse<ProductCreatedResponseDto>` | Người bán đăng bán sản phẩm mới. |
| `PATCH /api/v1/products/{productId}` | `Seller` | Route: `productId`, Body: `UpdateProductDto` | `200 ApiResponse<ProductUpdatedResponseDto>` | Cập nhật thông tin mô tả/giá sản phẩm. |
| `DELETE /api/v1/products/{productId}` | `Seller` | Route: `productId` | `204 NoContent` | Người bán ngừng kinh doanh / xoá sản phẩm. |
| `POST /api/v1/products/{productId}/pics` | `Seller` | Multipart: `files` (ảnh sản phẩm) | `201 ApiResponse<ProductImagesAddedResponseDto>` | Tải thêm hình ảnh cho sản phẩm. |
| `GET /api/v1/products/{productId}/pics` | `AllowAnonymous` | Route: `productId` | `200 ApiResponse<ProductImagesResponseDto>` | Lấy danh sách ảnh của sản phẩm. |
| `DELETE /api/v1/products/{productId}/pics` | `Seller` | Route: `productId`, Body: `DeleteImagesDto` | `204 NoContent` | Xóa ảnh khỏi sản phẩm. |
| `GET /api/v1/products/{productId}/totalRating` | `AllowAnonymous` | Route: `productId` | `200 ApiResponse<ProductTotalRatingResponseDto>` | Thống kê số lượng và điểm trung bình đánh giá. |
| `GET /api/v1/products/{productId}/rating` | `AllowAnonymous` | Route: `productId` | `200 ApiResponse<ProductRatingBreakdownDto>` | Phân bổ đánh giá theo số sao 1-5. |
| `PATCH /api/v1/products/{productId}/status` | `Seller` | Route: `productId`, Body: `{ "status": "ACTIVE" }` | `200 ApiResponse<ProductStatusUpdatedResponseDto>` | Đổi trạng thái hiển thị sản phẩm (Active/Draft). |
| `POST /api/v1/products/{productId}/variants` | `Seller` | Route: `productId`, Body: `CreateVariantDto` | `201 ApiResponse<VariantCreatedResponseDto>` | Thêm biến thể SKU mới cho sản phẩm. |
| `DELETE /api/v1/variants/{variantId}` | `Seller` | Route: `variantId` | `204 NoContent` | Xoá biến thể SKU. |
| `PATCH /api/v1/variants/{variantId}` | `Seller` | Route: `variantId`, Body: `UpdateVariantDto` | `200 ApiResponse<VariantUpdatedResponseDto>` | Cập nhật SKU / giá bán của biến thể. |
| `GET /api/v1/variants/{variantId}` | `Seller` | Route: `variantId` | `200 ApiResponse<VariantDetailResponseDto>` | Xem chi tiết 1 biến thể SKU. |
| `POST /api/v1/products/auction` | `Seller` | Body: `CreateAuctionProductDto` | `201 ApiResponse<AuctionProductCreatedResponseDto>` | Đăng sản phẩm đặc thù phục vụ tạo phiên đấu giá. |
| `GET /api/v1/products/auction/search` | `Seller` | Query: `keyword, page, limit` | `200 ApiResponse<AuctionProductListDto>` | Tìm kiếm sản phẩm đấu giá trong kho. |
| `GET /api/v1/products/auctions` | `Seller` | Query: `page, limit` | `200 ApiResponse<AuctionProductListDto>` | Danh sách sản phẩm đấu giá của người bán. |
| `GET /api/v1/products/auction/{auctionId}` | `Seller` | Route: `auctionId` | `200 ApiResponse<AuctionProductDetailDto>` | Chi tiết sản phẩm gán với phiên đấu giá. |

---

### 6.5 Module Danh Mục Hàng Hoá (Categories)
*Service backend phụ trách: `catalog` (Port 8002)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/categories` | `AllowAnonymous` | Query: `parentId, tree=false, keyword` | `200 ApiResponse<CategoryListResponseDto>` | Lấy cây danh mục hoặc danh sách phẳng. |
| `GET /api/v1/categories/{categoryId}` | `AllowAnonymous` | Route: `categoryId` | `200 ApiResponse<CategoryDetailResponseDto>` | Chi tiết danh mục kèm danh mục cha & con. |
| `POST /api/v1/categories` | `SellerOrStaffOrAdmin` | Body: `CreateCategoryDto` (`name, slug, parentId, iconUrl`) | `201 ApiResponse<CategoryCreatedResponseDto>` | Tạo danh mục mới trong hệ thống. |
| `PUT /api/v1/categories/{categoryId}` | `StaffOrAdmin` | Route: `categoryId`, Body: `UpdateCategoryDto` | `200 ApiResponse<CategoryUpdatedResponseDto>` | Cập nhật thông tin danh mục. |
| `DELETE /api/v1/categories/{categoryId}` | `StaffOrAdmin` | Route: `categoryId` | `204 NoContent` | Xóa mềm danh mục sản phẩm. |

---

### 6.6 Module Tồn Kho (Inventory)
*Service backend phụ trách: `catalog` (Port 8002)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `POST /api/v1/inventory/stock-in` | `Seller` | Body: `StockInDto` (`items: [{ skuId, quantity, unitCost }]`) | `200 ApiResponse<StockInResponseDto>` | Nhập kho theo lô nhiều SKU cùng lúc. |
| `POST /api/v1/variants/{variantId}/stock-in` | `Seller` | Route: `variantId`, Body: `StockInVariantDto` (`quantity`) | `200 ApiResponse<StockInVariantResponseDto>` | Nhập kho bổ sung số lượng cho một biến thể cụ thể. |

---

### 6.7 Module Giỏ Hàng (Cart)
*Service backend phụ trách: `commerce` (Port 8003)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/carts` | `Customer` | Không | `200 ApiResponse<CartResponseDto>` | Lấy toàn bộ sản phẩm trong giỏ hàng của tôi. |
| `POST /api/v1/carts/items` | `Customer` | Body: `AddCartItemRequest` (`productId, skuId, quantity`) | `200 ApiResponse<AddCartItemResponseDto>` | Thêm sản phẩm hoặc biến thể vào giỏ hàng. |
| `PATCH /api/v1/carts/items/{cartItemId}` | `Customer` | Route: `cartItemId`, Body: `UpdateCartItemRequest` (`quantity`) | `200 ApiResponse<UpdateCartItemResponseDto>` | Đổi số lượng của 1 sản phẩm trong giỏ. |
| `DELETE /api/v1/carts/items` | `Customer` | Body: `RemoveCartItemsRequest` (`cartItemIds, all: false`) | `200 ApiResponse<RemoveCartItemsResponseDto>` | Xoá một số sản phẩm đã chọn khỏi giỏ. |
| `DELETE /api/v1/carts/items/all` | `Customer` | Không | `200 ApiResponse<ClearCartResponseDto>` | Dọn dẹp sạch toàn bộ giỏ hàng. |
| `GET /api/v1/carts/items/select` | `Customer` | Query: `cartItemIds=id1,id2` | `200 ApiResponse<List<CartItemValidationDto>>` | Kiểm tra tồn kho & giá các dòng chọn trước checkout. |

---

### 6.8 Module Đơn Hàng & Thanh Toán (Orders & Checkout)
*Service backend phụ trách: `commerce` (Port 8003)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/orders` *(alias `order`)* | `Customer` | Query: `page=1, pageSize=20, status, fromDate, toDate` | `200 ApiResponse<PagedData<OrderListItemDto>>` | Danh sách lịch sử đơn hàng của người mua. |
| `GET /api/v1/orders/buyer/{buyerId}` | `Customer` | Route: `buyerId` (GUID), Query: `page=1, pageSize=20` (1..100) | `200 ApiResponse<PagedData<OrderDto>>` | Đơn hàng của một người mua; máy chủ kiểm tra quyền sở hữu với `x-user-id` và phân trang tại DB. |
| `POST /api/v1/checkouts/quote` | `Customer` | Body: `CheckoutQuoteRequest` (`cartItemIds, shippingAddress, paymentMethod`) | `200 ApiResponse<CheckoutQuoteResponseDto>` | Tính trước phí ship, chiết khấu và tổng tiền đơn. |
| `POST /api/v1/orders` | `Customer` | Body: `CreateOrderRequest` (`quoteId, shippingAddress, contactPhone, paymentMethod`) | `201 ApiResponse<CreateOrderResponseDto>` | Đặt hàng chính thức từ báo giá quote đã tính. |
| `GET /api/v1/orders/{orderId}` | `Customer` | Route: `orderId` | `200 ApiResponse<OrderDetailResponseDto>` | Xem chi tiết 1 đơn hàng và các đơn con của shop. |
| `GET /api/v1/subOrder/{subOrderId}` | `Customer` | Route: `subOrderId` | `200 ApiResponse<SubOrderDetailDto>` | Xem chi tiết đơn hàng con thuộc một shop cụ thể. |
| `POST /api/v1/orders/{orderId}/cancel` | `Customer` | Route: `orderId`, Body: `CancelOrderRequest` (`reasonCode`) | `200 ApiResponse<CancelOrderResponseDto>` | Người mua hủy đơn khi chưa thanh toán / xử lý. |
| `POST /api/v1/orders/{orderId}/accept` | `Seller` | Route: `orderId`, Body: `SubOrderDecisionRequest` (`subOrderId`) | `200` | Người bán xác nhận đồng ý đóng gói giao hàng. |
| `POST /api/v1/orders/{orderId}/reject` | `Seller` | Route: `orderId`, Body: `SubOrderDecisionRequest` (`subOrderId, reasonCode`) | `200` | Người bán từ chối đơn hàng do hết hàng/sự cố. |
| `POST /api/v1/payments/webhook` | `AllowAnonymous` | Body: `PaymentWebhookRequest` | `200` | Webhook nhận tín hiệu thanh toán từ cổng trung gian. |
| `POST /api/v1/orders/{orderId}/products/{productId}/reviews` | `Customer` | Route: `orderId, productId`, Body: `CreateProductReviewRequest` | `201` | Viết đánh giá sản phẩm sau khi đơn hoàn tất. |
| `POST /api/v1/orders/{orderId}/user/{userId}` | `Customer` | Route: `orderId, userId`, Body: `CreateUserFeedbackRequest` | `201` | Đánh giá thái độ người bán / người mua theo đơn. |
| `PATCH /api/v1/orders/{orderId}/products/{productId}/reviews` | `Customer` | Route: `orderId, productId`, Body: `UpdateProductReviewRequest` | `200` | Cập nhật lại đánh giá sản phẩm. |
| `PATCH /api/v1/orders/{orderId}/user/{userId}` | `Customer` | Route: `orderId, userId`, Body: `UpdateUserFeedbackRequest` | `200` | Cập nhật lại phản hồi người dùng. |
| `POST /api/v1/subOrder/{subOrderId}/refund` | `Customer` | Route: `subOrderId`, Body: `RefundSubOrderRequest` (`reason`) | `200` | Yêu cầu hoàn tiền cho một đơn hàng con. |

---

### 6.9 Module Đấu Giá (Auctions)
*Service backend phụ trách: `auction` (Port 8005)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/auctions` | `AllowAnonymous` | Query: `page=1, pageSize=20, status` | `200 ApiResponse<PagedData<AuctionSummaryDto>>` | Danh sách phiên đấu giá đang mở hoặc sắp mở. |
| `GET /api/v1/auctions/{auctionId}` | `AllowAnonymous` | Route: `auctionId` | `200 ApiResponse<AuctionDetailResponseDto>` | Chi tiết phiên đấu giá, giá hiện tại, thời gian còn lại. |
| `GET /api/v1/auctions/{auctionId}/bids` | `AllowAnonymous` | Route: `auctionId`, Query: `page=1, pageSize=20` | `200 ApiResponse<PagedData<BidItemDto>>` | Lịch sử các bước đặt giá trong phiên đấu giá. |
| `POST /api/v1/auctions/{auctionId}/bids` | `Authenticated` | Route: `auctionId`, Header: `Idempotency-Key`, Body: `PlaceBidRequestDto` (`bidAmount`) | `201 ApiResponse<PlaceBidResponseDto>` | Đặt giá mới (tự động khóa ký quỹ trong ví). |
| `GET /api/v1/me/bids` | `Authenticated` | Query: `page=1, pageSize=20, status` | `200 ApiResponse<PagedData<MyBidSummaryDto>>` | Danh sách các phiên đấu giá mà tôi đang tham gia. |
| `GET /api/v1/auctions/{auctionId}/result` | `AllowAnonymous` | Route: `auctionId` | `200 ApiResponse<AuctionResultDto>` | Kết quả chung cuộc phiên đấu giá (người thắng, giá chốt). |
| `POST /api/v1/auctions` | `Seller` | Body: `CreateAuctionRequestDto` (`productId, startPrice, stepPrice, startTime, endTime`) | `201 ApiResponse<CreateAuctionResponseDto>` | Người bán mở phiên đấu giá mới. |
| `PUT /api/v1/auctions/{auctionId}` | `Seller` | Route: `auctionId`, Body: `UpdateAuctionRequestDto` | `200 ApiResponse<UpdateAuctionResponseDto>` | Cập nhật cấu hình phiên khi chưa bắt đầu. |
| `POST /api/v1/auctions/{auctionId}/cancel` | `Seller` | Route: `auctionId`, Body: `CancelAuctionRequestDto` (`reason`) | `200 ApiResponse<CancelAuctionResponseDto>` | Người bán hủy phiên đấu giá trước giờ G. |
| `POST /api/v1/auctions/{auctionId}/recreate` | `Seller` | Route: `auctionId` | `201 ApiResponse<CreateAuctionResponseDto>` | Tạo lại phiên đấu giá mới từ phiên thất bại. |
| `GET /api/v1/sellers/auctions` | `Seller` | Query: `page=1, pageSize=20, status` | `200 ApiResponse<PagedData<AuctionSummaryDto>>` | Danh sách phiên đấu giá do chính shop tạo ra. |
| `GET /api/v1/auctions/{auctionId}/status-history` | `Authenticated` | Route: `auctionId` | `200 ApiResponse<List<AuctionStatusHistoryDto>>` | Lịch sử chuyển trạng thái vòng đời phiên đấu giá. |
| `POST /api/v1/admin/auctions/{auctionId}/force-cancel` | `Admin` | Route: `auctionId`, Body: `AdminForceCancelAuctionDto` (`reason`) | `200` | Quản trị viên cưỡng chế dừng phiên đấu giá vi phạm. |
| `GET /api/v1/admin/auctions/{auctionId}/saga` | `Admin` | Route: `auctionId` | `200 ApiResponse<AuctionSagaStateDto>` | Kiểm tra trạng thái điều phối Saga phân tán. |
| `GET /api/v1/admin/auction-configs` | `Admin` | Không | `200 ApiResponse<AuctionConfigListDto>` | Danh sách cấu hình sàn đấu giá (bước giá, trần giá). |
| `PUT /api/v1/admin/auction-configs/{key}` | `Admin` | Route: `key`, Body: `UpdateAuctionConfigDto` (`value`) | `200 ApiResponse<AuctionConfigItemDto>` | Cập nhật giá trị cấu hình đấu giá. |

---

### 6.10 Module Vận Chuyển & Kho Vận (Fulfillment)
*Service backend phụ trách: `fulfillment` (Port 8006)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/shipments/{shipmentId}` | `Customer` | Route: `shipmentId` | `200 ApiResponse<ShipmentDetailResponseDto>` | Chi tiết vận đơn và lịch sử các mốc lộ trình giao. |
| `GET /api/v1/shipments/order/{orderId}` | `Customer` | Route: `orderId` | `200 ApiResponse<List<ShipmentListItemDto>>` | Danh sách tất cả kiện hàng thuộc về một đơn hàng. |
| `GET /api/v1/sellers/shipments` | `Seller` | Query: `page=1, pageSize=20, status` | `200 ApiResponse<PagedData<SellerShipmentListItemDto>>` | Danh sách vận đơn gửi đi của người bán. |
| `GET /api/v1/sellers/shipments/search` | `Seller` | Query: `page, pageSize, keyword, status, fromDate, toDate` | `200 ApiResponse<PagedData<SellerShipmentListItemDto>>` | Tìm kiếm vận đơn của người bán theo mã/ngày. |
| `GET /api/v1/sellers/shipments/{shipmentId}` | `Seller` | Route: `shipmentId` | `200 ApiResponse<ShipmentDetailResponseDto>` | Người bán xem chi tiết 1 kiện hàng của mình. |
| `PATCH /api/v1/shipments/{shipmentId}/tracking` | `Authenticated` | Route: `shipmentId`, Body: `UpdateShipmentTrackingRequest` (`status, location`) | `200 ApiResponse<ShipmentTrackingUpdatedResponseDto>` | Cập nhật vị trí tracking kiện hàng. |
| `POST /api/v1/shipments/{shipmentId}/complete` | `Customer` | Route: `shipmentId` | `200 ApiResponse<ShipmentCompletedResponseDto>` | Người mua ấn nút "Đã nhận được hàng". |
| `POST /api/v1/shipments/webhook` | `AllowAnonymous` | Body: `ShipmentWebhookRequest` (`trackingNumber, status`) | `200` | Webhook nhận cập nhật từ hãng vận chuyển (GHTK/GHN). |

---

### 6.11 Module Thông Báo (Notifications)
*Service backend phụ trách: `notification` (Port 8007)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/notifications/me` | `Customer` | Query: `page=1, limit=20, isRead` | `200 ApiResponse<PagedData<NotificationItemDto>>` | Danh sách thông báo in-app của người dùng hiện tại. |
| `PATCH /api/v1/notifications/me/read` | `Customer` | Body: `MarkNotificationsReadRequest` (`notificationIds, all: true`) | `200 ApiResponse<MarkReadResponseDto>` | Đánh dấu đã đọc một hoặc toàn bộ thông báo. |
| `POST /api/v1/notifications/devices` | `Customer` | Body: `RegisterDeviceRequest` (`deviceToken, platform`) | `200 ApiResponse<DeviceRegisteredDto>` | Đăng ký thiết bị (FCM Token) nhận Push Notification. |
| `DELETE /api/v1/notifications/devices/{token}` | `Customer` | Route: `token` | `204 NoContent` | Hủy đăng ký một thiết bị khi người dùng đăng xuất. |
| `GET /api/v1/notifications/preferences` | `Customer` | Không | `200 ApiResponse<NotificationPreferencesDto>` | Cài đặt kênh nhận tin (Email, In-App, Push). |
| `PUT /api/v1/notifications/preferences` | `Customer` | Body: `NotificationPreferencesDto` | `200 ApiResponse<NotificationPreferencesDto>` | Cập nhật bật/tắt nhận tin theo từng kênh/chủ đề. |
| `GET /api/v1/admin/notifications/channels/{code}` | `StaffOrAdmin` | Route: `code` | `200` | Quản trị viên xem cấu hình cổng gửi (SendGrid, FCM). |
| `PUT /api/v1/admin/notifications/channels/{code}` | `Admin` | Route: `code`, Body: `UpdateChannelConfigDto` | `200` | Cập nhật cấu hình kênh gửi thông báo. |
| `GET /api/v1/admin/notifications/templates` | `StaffOrAdmin` | Không | `200 ApiResponse<List<TemplateDto>>` | Danh sách các mẫu email/thông báo mẫu. |
| `POST /api/v1/admin/notifications/templates` | `Admin` | Body: `CreateTemplateDto` | `201 ApiResponse<TemplateDto>` | Tạo mẫu thông báo mới trong hệ thống. |
| `GET /api/v1/admin/notifications` | `StaffOrAdmin` | Query: `page=1, limit=20, channel, status` | `200` | Lịch sử nhật ký gửi thông báo toàn hệ thống. |
| `GET /api/v1/admin/event-logs` | `StaffOrAdmin` | Query: `page=1, limit=20, eventType` | `200` | Xem lịch sử tiếp nhận sự kiện RabbitMQ. |
| `GET /api/v1/admin/health/broker` | `StaffOrAdmin` | Không | `200` | Trạng thái kết nối tới Message Broker RabbitMQ. |

---

### 6.12 Module Ví & Giao Dịch (Wallets & Financial)
*Service backend phụ trách: `wallet` (Port 8008)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Tham Số / Body | Phản Hồi | Mô Tả Nghiệp Vụ |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/wallets/me` | `Authenticated` | Không | `200 ApiResponse<WalletResponse>` | Lấy số dư khả dụng (`availableBalance`) và số dư bị giữ (`lockedBalance`). Tự tạo ví 0 đồng nếu chưa có. |
| `POST /api/v1/wallets/topups/vnpay` | `Authenticated` | Body: `TopupVnPayCommand` (`amount` 10.000–100.000.000, `currency`, `paymentMethod`, `bankCode`, `returnUrl`) | `201 ApiResponse<TopupResponse>` | Tạo `WalletTopup` Pending và trả URL thanh toán VNPay. |
| `POST /api/v1/wallets/vnpay/ipn` | `AllowAnonymous` | Query & Body theo chuẩn VNPay | `200 VnPayIpnResponse` (`responseCode`, `message`) | Webhook IPN nhận kết quả giao dịch; `00` là thành công, `97` sai chữ ký. |
| `GET /api/v1/wallets/vnpay/return` | `AllowAnonymous` | Query theo chuẩn VNPay | `200 VnPayReturnResponse` hoặc `400 VAL_INVALID_SIGNATURE` | Browser return callback sau khi thanh toán; kiểm tra chữ ký trước khi trả kết quả. |
| `POST /api/v1/wallets/transfers` | `Authenticated` | Body: `TransferCommand` (`recipientUserId`, `amount` 1.000–100.000.000, `note`) | `200 ApiResponse<TransferResponse>` | Chuyển tiền nội bộ giữa hai ví, ghi 2 bút toán TransferIn/TransferOut. |
| `POST /api/v1/wallets/withdrawals` | `Authenticated` | Body: `RequestWithdrawalCommand` (`amount` 50.000–500.000.000, `bankCode`, `accountNumber`) | `400 BUSINESS_RULE_VIOLATION` (hiện tại) | Endpoint đã khai báo nhưng luồng tạo yêu cầu rút tiền đang bị vô hiệu hóa. |
| `PATCH /api/v1/admin/wallets/withdrawals/{withdrawalId:guid}` | `StaffOrAdmin` | Route: `withdrawalId`, Body: `ProcessWithdrawalCommand` (`action: APPROVE/REJECT`, `adminNote`) | `200 ApiResponse<ProcessWithdrawalResponse>` | Duyệt giải ngân hoặc từ chối rút tiền, ghi audit log. |
| `GET /api/v1/wallets/transactions` | `Authenticated` | Query: `page=1`, `pageSize=10`, `type`, `fromDate`, `toDate` | `200 ApiResponse<WalletTransactionPageResponse>` | Lịch sử biến động số dư, lọc theo `type` (`DEPOSIT`, `WITHDRAWAL`, `PAYMENT`, `REFUND` hoặc tên enum). |
| `POST /api/v1/admin/wallets/{walletId:guid}/adjustments` | `Admin` | Route: `walletId`, Body: `AdjustWalletBalanceCommand` (`amount`, `adjustmentType: Credit/Debit`, `reason`) | `200 ApiResponse<BalanceAdjustmentResponse>` | Admin điều chỉnh số dư thủ công kèm ghi vết audit. |
| `POST /api/v1/internal/wallets/checkout/direct` | `InternalServiceKey` | Header `x-user-id`, Body: `CheckoutDirectCommand` (`orderId`, `amount`, `gateway`, `bankCode`, `returnUrl`) | `200 DirectPaymentResponse` | Thanh toán trực tiếp cho đơn hàng (idempotent theo `orderId`). Chỉ gọi nội bộ, Gateway chặn `/internal`. |

---

### 6.13 Module Điều Khiển Gateway & Giám Sát Sức Khỏe (Gateway Control & Health Prober)
*Chức năng nội bộ Gateway (Port 8080)*

| Phương Thức & Tuyến Đường | Quyền Yêu Cầu | Request Params / Body | Phản Hồi | Mô Tả Chức Năng |
|:---|:---:|:---|:---:|:---|
| `GET /api/v1/gateway/modes` | `GatewayAdmin` | Không | `200 ApiResponse<ServiceModesResponseDto>` | Xem chế độ hoạt động (`Real` / `Mock`) của toàn bộ 8 services. |
| `PUT /api/v1/gateway/modes/{service}` | `GatewayAdmin` | Route: `service`, Body: `{ "mode": "Real" }` | `200` | Đổi nóng chế độ Mock/Real của 1 service cụ thể. |
| `PUT /api/v1/gateway/modes` | `GatewayAdmin` | Body: `BulkServiceModeUpdateRequestDto` | `200` | Đổi hàng loạt chế độ các microservices. |
| `GET /api/v1/mock-engine/definitions` | `GatewayAdmin` | Không | `200` | Xem danh mục các declarative mock route đang kích hoạt. |
| `POST /api/v1/mock-engine/reload` | `GatewayAdmin` | Không | `200` | Nạp lại tức thì các tệp seed fixtures `Seeds/` và mock definitions. |
| `GET /api/v1/gateway/prober/status` | `GatewayAdmin` | Không | `200 ApiResponse<GatewayProberStatusDto>` | Snapshot tổng thể tình trạng kết nối tới 8 backend microservices. |
| `GET /api/v1/gateway/prober/status/{service}` | `GatewayAdmin` | Route: `service` | `200 ApiResponse<ServiceProbeStateDto>` | Xem latency, trạng thái circuit breaker của 1 service. |
| `PUT /api/v1/gateway/prober/{service}` | `GatewayAdmin` | Route: `service`, Body: `ServiceProberToggleDto` (`isEnabled`) | `200` | Bật/tắt daemon kiểm tra sức khỏe nền của 1 service. |
| `PUT /api/v1/gateway/prober/bulk` | `GatewayAdmin` | Body: `BulkProberToggleDto` | `200` | Bật/tắt hàng loạt prober daemons. |
| `POST /api/v1/gateway/prober/{service}/check` | `GatewayAdmin` | Route: `service` | `200 ApiResponse<ProbeExecutionResultDto>` | Kích hoạt probe kiểm tra kết nối ngay tức thì (On-demand check). |
| `GET /api/v1/gateway/prober/databases/status` | `GatewayAdmin` | Không | `200` | Tình trạng kiểm tra sức khỏe của 8 cơ sở dữ liệu PostgreSQL. |
| `POST /api/v1/gateway/prober/databases/{service}/check` | `GatewayAdmin` | Route: `service` | `200` | Thực hiện câu query probe `SELECT 1;` tức thì tới cơ sở dữ liệu. |
