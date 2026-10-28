# TÀI LIỆU ĐẶC TẢ FLOW & MOCK API NEXUS (CHUYỂN ĐỔI TỪ EXCEL)

> **Nguồn dữ liệu gốc:** `docs/excel/flow_mock_excel.xlsx`
> **Ngày trích xuất:** 2026-10-28
> **Tổng số mục:** 161 (Gồm 158 HTTP REST APIs, 1 gRPC Internal Endpoint, 2 Hệ thống Background Jobs)

---

## 1. TIÊU CHUẨN PHẢN HỒI TOÀN HỆ THỐNG (RESPONSE STANDARDS)

| STT | Thành phần / Tiêu chuẩn | HTTP Code / Type | Mô tả & Hướng dẫn ánh xạ Gateway |
|:---:|:---|:---|:---|
| 1 | **ApiResponse<T><br>(Single Success Envelope)** | `200 OK / 201 Created` | Áp dụng cho mọi API thành công trả về 1 đối tượng duy nhất hoặc thực hiện thao tác tạo mới/cập nhật. Class C# tương ứng: Nexus.Gateway.Responses.ApiResponse<T>. |
| 2 | **ApiResponse<PagedData<T>><br>(Paged List Success Envelope)** | `200 OK` | Áp dụng cho tất cả 39 endpoints danh sách có phân trang. Gateway tự động map trường "items" và "pagination" từ seed fixture hoặc gRPC Paged Result. Class C#: Nexus.Gateway.Responses.PagedData<T>. |
| 3 | **204 No Content<br>(Empty Response Body)** | `204 No Content` | Áp dụng cho các API xóa thành công (DELETE) hoặc xử lý mà không cần trả về nội dung (ví dụ: đánh dấu thông báo đã đọc, hủy theo dõi). |
| 4 | **ApiErrorResponse<br>(RFC 9110 ProblemDetails)** | `400 / 401 / 403 / 404 / 409 / 500` | Quy chuẩn lỗi toàn hệ thống theo RFC 9110 + AGENTS.md Nguyên tắc 5: 100% tiếng Anh Sentence case (chữ thường, chỉ viết hoa chữ cái đầu câu), errorCode viết hoa SCREAMING_SNAKE_CASE. Class C#: Nexus.Gateway.Responses.ApiErrorResponse. |
| 5 | **Webhook / IPN Callback<br>(External Provider Standard)** | `200 OK` | Áp dụng đặc thù cho các webhook nhận callback từ bên thứ 3 (ví dụ VNPay IPN) tuân theo chuẩn quy định của nhà cung cấp dịch vụ thanh toán. |

### Chuẩn: ApiResponse<T> (`200 OK / 201 Created`)
**Mô tả:** Áp dụng cho mọi API thành công trả về 1 đối tượng duy nhất hoặc thực hiện thao tác tạo mới/cập nhật. Class C# tương ứng: Nexus.Gateway.Responses.ApiResponse<T>.

```json
{
  "success": true,
  "statusCode": 200,
  "message": null,
  "data": {
    // Dữ liệu payload thực tế của nghiệp vụ
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

### Chuẩn: ApiResponse<PagedData<T>> (`200 OK`)
**Mô tả:** Áp dụng cho tất cả 39 endpoints danh sách có phân trang. Gateway tự động map trường "items" và "pagination" từ seed fixture hoặc gRPC Paged Result. Class C#: Nexus.Gateway.Responses.PagedData<T>.

```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      // Danh sách các đối tượng bản ghi (JSON array)
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

### Chuẩn: 204 No Content (`204 No Content`)
**Mô tả:** Áp dụng cho các API xóa thành công (DELETE) hoặc xử lý mà không cần trả về nội dung (ví dụ: đánh dấu thông báo đã đọc, hủy theo dõi).

```json
(Không có body - HTTP 204 Header Only)
```

### Chuẩn: ApiErrorResponse (`400 / 401 / 403 / 404 / 409 / 500`)
**Mô tả:** Quy chuẩn lỗi toàn hệ thống theo RFC 9110 + AGENTS.md Nguyên tắc 5: 100% tiếng Anh Sentence case (chữ thường, chỉ viết hoa chữ cái đầu câu), errorCode viết hoa SCREAMING_SNAKE_CASE. Class C#: Nexus.Gateway.Responses.ApiErrorResponse.

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "Bad request",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Email is already registered in the system.",
  "errors": {
    "email": ["Email is already registered in the system."]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

### Chuẩn: Webhook / IPN Callback (`200 OK`)
**Mô tả:** Áp dụng đặc thù cho các webhook nhận callback từ bên thứ 3 (ví dụ VNPay IPN) tuân theo chuẩn quy định của nhà cung cấp dịch vụ thanh toán.

```json
{
  "RspCode": "00",
  "Message": "Confirm success."
}
```

---

## 2. BẢNG TỔNG HỢP DANH MỤC API THEO PHÂN HỆ

| ID | Phân hệ | Method | Endpoint | ID Tham Chiếu | Mô tả |
|:---:|:---|:---:|:---|:---:|:---|
| 1 | user | `POST` | `/api/v1/auth/register` | `ADM-23` | Người dùng đăng kí tài khoản |
| 2 | user | `POST` | `/api/v1/auth/otp/verify` | `-` | Xác thực tài khoản người dùng |
| 3 | user | `POST` | `/api/v1/auth/otp/resend` | `-` | Dùng gửi otp cho đăng kí và cả quên mật khẩu |
| 4 | user | `POST` | `/api/v1/auth/login` | `-` | Đăng nhập hệ thống (Email + Password) |
| 5 | user | `POST` | `/api/v1/auth/refresh` | `-` | Làm mới Token ngầm (Refresh Token Rotation - RTR) |
| 6 | user | `POST` | `/api/v1/auth/password/forgot` | `-` | Yêu cầu quên mật khẩu & Gửi OTP khôi phục |
| 7 | user | `PUT` | `/api/v1/auth/password/reset` | `-` | Đặt lại mật khẩu mới bằng mã OTP |
| 8 | user | `PATCH` | `/api/v1/auth/password` | `-` | Cập nhật lại mật khẩu(Đổi mật khẩu) |
| 9 | user | `POST` | `/api/v1/auth/logout` | `-` | Đăng xuất & Thu hồi phiên hiện tại |
| 10 | user | `POST` | `/api/v1/auth/logout-all` | `-` | Đăng xuất khỏi toàn bộ thiết bị khác |
| 11 | user | `GET` | `/api/v1/me/sessions` | `-` | Xem danh sách thiết bị đang đăng nhập |
| 12 | user | `DELETE` | `/api/v1/me/sessions/{id}` | `-` | Thu hồi / Đăng xuất thiết bị từ xa |
| 13 | user | `GET` | `/api/v1/me` | `-` | Xem danh sách cá nhân của user |
| 14 | user | `PATCH` | `/api/v1/me` | `-` | Cập nhật thông tin hồ sơ cá nhân |
| 15 | user | `GET` | `/api/v1/me/avatar` | `-` | Xem ảnh avatar cá nhân |
| 16 | user | `POST` | `/api/v1/me/avatar` | `-` | Tải lên và cập nhật avatar cá nhân |
| 17 | user | `GET` | `/api/v1/me/reputation` | `-` | Xem uy tín của bản thân |
| 18 | user | `GET` | `/api/v1/me/penalties` | `-` | xem thông tin phạt của bản thân |
| 19 | user | `GET` | `/api/v1/user/{userId}` | `-` | Xem chi tiết hồ sơ cá nhân của 1 user cụ thể |
| 20 | user | `GET` | `/api/v1/user/{userId}/avatar` | `-` | Xem ảnh avatar của từng user |
| 21 | user | `GET` | `/api/v1/seller/{sellerId}` | `-` | User lấy thông tin cửa hàng của Seller |
| 22 | user | `GET` | `/api/v1/user/{userId}/reputation` | `-` | Xem Thẻ Tóm tắt Hồ sơ Uy tín công khai |
| 23 | user | `GET` | `/api/v1/user/{userId}/reputation/history` | `-` | Xem lịch sử uy tín (tăng or giảm) |
| 24 | user | `GET` | `/api/v1/user/{userId}/reviews` | `-` | Xem danh sách đánh giá công khai của 1 user/Shop |
| 25 | user | `POST` | `/api/v1/review/files/upload` | `-` | Upload đánh giá sản phẩm |
| 26 | user | `POST` | `/api/v1/reviews` | `-` | Đánh giá đối tác 2 chiều (Buyer ↔ Seller) |
| 27 | user | `POST` | `/api/v1/report/files/upload` | `-` | Upload bằng chứng tố cáo tài khoản vi phạm (User Violation Evidence) |
| 28 | user | `POST` | `/api/v1/users/reports` | `-` | Người dùng gửi đơn tố cáo tài khoản vi phạm quy chế |
| 29 | user | `GET` | `/api/v1/me/reports` | `-` | Người dùng xem danh sách các báo cáo do mình đã gửi |
| 30 | user | `POST` | `/api/v1/seller/registration` | `-` | Seller tạo đơn đăng kí |
| 31 | user | `POST` | `/api/v1/seller/registration/otp/resend` | `-` | Gửi lại otp cho tài khoản Seller |
| 32 | user | `POST` | `/api/v1/seller/registration/documents` | `-` | Upload tài liệu Seller(CCCD, ....) |
| 33 | user | `POST` | `/api/v1/seller/otp/verify` | `-` | Xác thực mã otp của Seller |
| 34 | user | `GET` | `/api/v1/seller/registration` | `-` | Seller xem đơn (đã được duyệt làm Seller hay chưa) |
| 35 | user | `GET` | `/api/v1/seller/profile` | `-` | Seller tự coi thông tin shop |
| 36 | user | `PATCH` | `/api/v1/seller/profile` | `-` | Cập nhật thông tin cá nhân hồ sơ cho Seller |
| 37 | user | `GET` | `/api/v1/admin/seller-registrations` | `-` | Danh sách hồ sơ Seller chờ duyệt |
| 37B | user | `GET` | `/api/v1/admin/seller-registrations/{registrationId}` | `-` | Xem chi tiết hồ sơ mở Shop và tài liệu chứng từ định danh |
| 38 | user | `PUT` | `/api/v1/admin/seller-registrations/{registrationId}/approve` | `-` | Staff duyệt hồ sơ Seller |
| 39 | user | `PUT` | `/api/v1/admin/seller-registrations/{registrationId}/reject` | `-` | Staff từ chối hồ sơ Seller |
| 40 | user | `GET` | `/api/v1/admin/reports` | `-` | Admin/Staff xem danh sách các đơn tố cáo tài khoản |
| 41 | user | `PUT` | `/api/v1/admin/reports/{reportId}/resolve` | `-` | Staff xử lý chấp thuận tố cáo & áp dụng chế tài kỷ luật |
| 41B | user | `PUT` | `/api/v1/admin/reports/{reportId}/dismiss` | `-` | Staff bác bỏ đơn tố cáo sai sự thật / không đủ chứng cứ |
| 42 | user | `PUT` | `/api/v1/admin/reviews/{id}/hide` | `-` | Staff/Admin ẩn đánh giá vi phạm tiêu chuẩn |
| 43 | user | `GET` | `/api/v1/admin/user` | `-` | Admin xem danh sách các user |
| 44 | user | `POST` | `/api/v1/admin/user` | `-` | Admin tạo user mới |
| 45 | user | `GET` | `/api/v1/admin/user/{userId}` | `-` | Xem chi tiết hồ sơ cá nhân, phân quyền & uy tín |
| 46 | user | `PUT` | `/api/v1/admin/user/{userId}` | `-` | Admin cập nhật thông tin của user cụ thể |
| 47 | user | `DELETE` | `/api/v1/admin/user/{userId}` | `-` | Xóa MỀM 1 user khỏi hệ thống |
| 48 | user | `PATCH` | `/api/v1/admin/user/{userId}/ban` | `-` | Admin ban 1 user |
| 49 | user | `PATCH` | `/api/v1/admin/user/{userId}/unban` | `-` | Admin hủy ban 1 user |
| 50 | user | `GET` | `/api/v1/admin/sellers/{sellerId}` | `-` | Admin lấy thông tin cửa hàng của từng Seller |
| 51 | user | `PUT` | `/api/v1/admin/user/{userId}/roles` | `-` | Gán / Thu hồi vai trò nội bộ (Phân quyền SoD) |
| 52 | user | `PATCH` | `/api/v1/admin/user/{userId}/reputation` | `-` | Admin điều chỉnh uy tín của user(thủ công) |
| 53 | user | `GET` | `/api/v1/admin/roles` | `-` | Admin xem toàn bộ roles trong hệ thống |
| 54 | user | `GET` | `/api/v1/admin/permissions` | `-` | Xem danh sách các đặc quyền |
| 55 | user | `PUT` | `/api/v1/admin/roles/{roleId}/permissions` | `-` | Cập nhật danh sách đặc quyền (Permissions) cho Vai trò |
| 56 | user | `GET` | `/api/v1/admin/audit-logs` | `-` | Tra cứu Nhật ký Kiểm toán hệ thống |
| 57 | user | `GET` | `/api/v1/admin/configs` | `-` | Xem danh sách tham số cấu hình toàn sàn |
| 58 | user | `PUT` | `/api/v1/admin/configs` | `-` | Cập nhật tham số cấu hình toàn sàn |
| R66 | F1. mua hàng thường. | `GET` | `/api/v1/products` | `CAT-06` | lấy toàn bộ product |
| R67 | F1. mua hàng thường. | `GET` | `/api/v1/products/search` | `CAT-20 + CAT-21` | filter, search product |
| R68 | F1. mua hàng thường. | `GET` | `/api/v1/product/{productId}` | `CAT-05` | lấy thông tin chi tiết của 1 product |
| R69 | F1. mua hàng thường. | `POST` | `/api/v1/cart/items` | `CART-02` | thêm 1 hoặc nhiều sản phẩm vào giỏ hàng |
| R70 | F1. mua hàng thường. | `GET` | `/api/v1/cart` | `CART-01 (ô ID tham chiếu ghi NULL) + FUL-04 + CAT-39 + CAT-24` | xem toàn bộ các sản phẩm của giỏ hàng, gửi list cart lên và kho check cái list đó và catalogc |
| R71 | F1. mua hàng thường. | `PATCH` | `/api/v1/cart/items/{id}` | `CART-03` | đổi số lượng 1 sản phẩm trong giỏ hàng |
| R72 | F1. mua hàng thường. | `DELETE` | `/api/v1/cart/items` | `CART-04` | xóa 1 hoặc nhiều sản phẩm ra khỏi giỏ |
| R73 | F1. mua hàng thường. | `DELETE` | `/api/v1/cart/items/all` | `CART-05` | xóa toàn bộ sản phẩm ra khỏi giỏ |
| R74 | F1. mua hàng thường. | `GET` | `/api/v1/cart/items/select` | `CART-06` | buyer select ccasc item bên trong cart và trả ra giá tiền |
| R75 | F1. mua hàng thường. | `POST` | `/api/v1/checkout/quote` | `CHK-01 (khung) + FUL-12 + CART-07 + CAT-24` | buyer nhập địa chi, mã giảm giá và coi trước thông tin sau giảm và thông tin tiền ship tính trước |
| R76 | F1. mua hàng thường. | `POST` | `/api/v1/orders` | `ORD-01` | tạo order |
| R77 | F1. mua hàng thường. | `GET` | `/api/v1/order/{orderId}` | `ORD-02` | lấy thôn tin chi tiết của order đó |
| R78 | F1. mua hàng thường. | `GET` | `/api/v1/order` / `/api/v1/orders` | `ORD-07` | Lấy danh sách đơn hàng đã mua của người dùng (có phân trang) |
| R79 | F1. mua hàng thường. | `GET` | `/api/v1/subOrder/{subOrderId}` | `ORD-03` | coi thong tin chi tiết của 1 sub order |
| R80 | F1. mua hàng thường. | `POST` | `/api/v1/orders/{orderId}/cancel` | `ORD-04` | cancel cái order đó, chưa chuyển khoản, chưa thanh toán |
| R81 | F1. mua hàng thường. | `POST` | `/api/v1/payments/webhook` | `PAY-01` | thành công, chuyển |
| R82 | F1. mua hàng thường. | `JOB` | `(Job hệ thống tự động quét)` | `ORD-JOB-01` | quét thời gian cái qr đó hết hạn chưa, đổi trạng thái những cái liên quan |
| R83 | F1. mua hàng thường. | `POST` | `/api/v1/orders/{orderId}/accept` | `ORD-05` | seller chấp nhận cái đơn đó hay ko/ xác nhận |
| R84 | F1. mua hàng thường. | `POST` | `/api/v1/orders/{orderId}/reject` | `ORD-06` | seller chấp nhận cái đơn đó hay ko/ từ chối |
| R85 | F1. mua hàng thường. | `JOB` | `(Job hệ thống tự động quét)` | `ORD-JOB-02` | sau 24 tiếng seller ko xác nhận đơn hàng thì hủy |
| R86 | F1. mua hàng thường. | `GET` | `/api/v1/shipments/{shipmentId}` | `FUL-06` | coi thông tin chi tiết của 1 shipment |
| R87 | F1. mua hàng thường. | `GET` | `/api/v1/shipments/order/{orderId}` | `FUL-07` | coi order đó có mấy shipment |
| R88 | F1. mua hàng thường. | `GET` | `/api/v1/seller/shipment` | `FUL-08` | lấy danh sách các đơn ship của selller phải giao |
| R89 | F1. mua hàng thường. | `GET` | `/api/v1/seller/shipment/search` | `FUL-09` | filter, search shipment của 1 seller, lọc trạng thái |
| R90 | F1. mua hàng thường. | `GET` | `/api/v1/seller/shipment/{shipmentId}` | `FUL-10` | coi chi tiết cái shipment của seller đó |
| R91 | F1. mua hàng thường. | `PATCH` | `/api/v1/shipments/{shipmentId}/tracking` | `FUL-11` | cập nhập trạng thái cái shipment từ ghn |
| R92 | F1. mua hàng thường. | `POST` | `/api/v1/order/{orderId}/products/{productId}/reviews` | `ORD-07` | ddbuyer đánh giá 1 sản phẩm, check sản phẩm đã được mua chưa, đã hoàn thành chưa, có phải người này ko. phải điền order id vào |
| R93 | F1. mua hàng thường. | `POST` | `/api/v1/order/{orderId}/user/{userId}` | `ORD-08` | đánh giá người dùng |
| R94 | F1. mua hàng thường. | `PATCH` | `/api/v1/order/{orderId}/products/{productId}/reviews` | `ORD-07` | chỉnh sửa đánh giá sản phẩm |
| R95 | F1. mua hàng thường. | `PATCH` | `/api/v1/order/{orderId}/user/{userId}` | `ORD-08` | chỉnh sửa đánh giá người dùng |
| R97 | F1. mua hàng thường. | `POST` | `/api/v1/shipment/{shipmentId}/complete` | `FUL-13` | người dùng ấn nút đã nhận được hàng |
| R98 | F1. mua hàng thường. | `POST` | `/api/v1/shipments/webhook` | `FUL-14` | nhận thông tin từ ghn. 
nếu nhận được đơn hàng hoàn thành, thì đổi trạng thái những cái liên quan |
| R99 | F1. mua hàng thường. | `POST` | `/api/v1/subOrder/{subOrderId}/refund` | `ORD-11` | Hoàn tiền sub-order riêng lẻ kèm kiểm tra điều kiện trạng thái |
| R102 | F2. quản lý sản phẩm. | `GET` | `/api/v1/products` | `CAT-06` | xem toàn bộ các sản phẩm của shop mình |
| R103 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/search` | `CAT-06 + CAT-21` | search, filter các sản phẩm của shop mình |
| R104 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/{productId}` | `CAT-05` | coi thông tin detail của 1 sản phẩm |
| R105 | F2. quản lý sản phẩm. | `POST` | `/api/v1/products` | `CAT-01` | tạo sản phẩm mới, kèm biến thể đầu, KÈM DANH MỤC |
| R106 | F2. quản lý sản phẩm. | `PATCH` | `/api/v1/product/{productId}` | `CAT-02` | seller cập nhật thông tin sản phẩm, danh mục |
| R107 | F2. quản lý sản phẩm. | `DELETE` | `/api/v1/product/{productId}` | `CAT-04` | Xóa sản phẩm |
| R108 | F2. quản lý sản phẩm. | `POST` | `/api/v1/product/{productId}pics` | `CAT-12` | thêm list ảnh của sản phẩm |
| R109 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/{productId}pics` | `CAT-40 (mới)` | xem các ảnh của sản phẩm |
| R110 | F2. quản lý sản phẩm. | `DELETE` | `/api/v1/product/{productId}pics` | `CAT-13` | xóa list ảnh sản phẩm |
| R111 | F2. quản lý sản phẩm. | `GET` | `/api/v1/products/{productId}/totalRating` | `CAT-31` | xem số sao của 1 sản phẩm, trung bình |
| R112 | F2. quản lý sản phẩm. | `GET` | `/api/v1/products/{productId}/rating` | `CAT-30 + CAT-31` | tổng số sao, và đánh giá của các người mua trong product |
| R113 | F2. quản lý sản phẩm. | `PATCH` | `/api/v1/product/{productId}/status` | `CAT-03` | Cập nhật trạng thái sản phẩm |
| R114 | F2. quản lý sản phẩm. | `POST` | `/api/v1/inventory/stock-in` | `FUL-02 + CAT-24` | thêm hàng vào kho, 1 list, kèm số lượng thêm, kèm chủng loại muốn thêm |
| R115 | F2. quản lý sản phẩm. | `POST` | `/api/v1/product/{productId}/variants` | `CAT-07` | Thêm biến thể cho sản phẩm |
| R116 | F2. quản lý sản phẩm. | `DELETE` | `/api/v1/variant/{variantId}` | `CAT-11` | xóa 1 biến thể |
| R117 | F2. quản lý sản phẩm. | `PATCH` | `/api/v1/variant/{variantId}` | `CAT-08` | Cập nhật thông tin của sản phẩm biến thể |
| R118 | F2. quản lý sản phẩm. | `GET` | `/api/v1/variant/{variantId}` | `CAT-42 (mới)` | xem thông tin chi tiết của 1 biến thể |
| R119 | F2. quản lý sản phẩm. | `POST` | `/api/v1/variant/{variantId}/stock-in` | `FUL-02 + CAT-23` | thêm biến thể của sản phảm vào kho |
| R120 | F2. quản lý sản phẩm. | `GET` | `/api/v1/categories` | `CAT-19` | Xem danh sách danh mục |
| R121 | F2. quản lý sản phẩm. | `POST` | `/api/v1/categories` | `CAT-15` | Tạo danh mục mới, có thể truyền danh mục cha, nếu ko truyền nó là cha |
| R122 | F2. quản lý sản phẩm. | `PUT` | `/api/v1/categories/{categoryId}` | `CAT-16` | Cập nhật danh mục |
| R123 | F2. quản lý sản phẩm. | `DELETE` | `/api/v1/categories` | `CAT-17` | Xóa mềm danh mục |
| R124 | F2. quản lý sản phẩm. | `GET` | `/api/v1/categories/{categoryId}` | `CAT-18` | xem danh sách các danh mục con và thông tin 1 danh mục cha |
| R125 | F2. quản lý sản phẩm. | `POST` | `/api/v1/product/auction` | `CAT-43 (mới)` | thêm sản phẩm đấu giá |
| R126 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/aucction/search` | `CAT-06 + CAT-21` | coi đươc các sản phẩm seller đó đã đấu giá, filter |
| R127 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/auctions` | `CAT-06` | coi đươc toàn bộ các sản phẩm seller đó đã đấu giá |
| R128 | F2. quản lý sản phẩm. | `GET` | `/api/v1/product/auction/{auctionId}` | `AUC-35 + CAT-05` | coi thông tin chi tiết của sản phẩm đấu giá đó |
| R131 | F3. đấu giá. | `GET` | `/api/v1/auctions` | `AUC-01` | User xem danh sách các phiên đấu giá |
| R132 | F3. đấu giá. | `GET` | `/api/v1/auctions/{auctionId}` | `AUC-02` | Xem chi tiết 1 phiên đấu giá |
| R133 | F3. đấu giá. | `POST` | `/api/v1/auctions` | `AUC-10` | Seller tạo phiên đấu giá, chọn 1 sản phẩm có rồi |
| R134 | F3. đấu giá. | `PUT` | `/api/v1/auctions/{auctionId}` | `AUC-11` | Seller chỉnh sửa phiên đấu giá(khi chưa bắt đầu) |
| R135 | F3. đấu giá. | `POST` | `/api/v1/auctions/{auctionId}/cancel` | `AUC-12` | Seller hủy phiên đấu giá(khi phiên đấu giá chưa bắt đầu) |
| R136 | F3. đấu giá. | `POST` | `/api/v1/auctions/{auctionId}/recreate` | `AUC-13` | Tạo lại phiên mới cho sản phẩm ở phiên cũ (đã bị đấu giá thất bại) |
| R137 | F3. đấu giá. | `GET` | `/api/v1/auctions/{auctionId}/status-history` | `AUC-18` | Nhật kí đổi trạng thái của từng auction |
| R138 | F3. đấu giá. | `GET` | `/api/v1/seller/auctions` | `AUC-14` | Seller xem toàn bộ phiên đấu giá của mình |
| R139 | F3. đấu giá. | `POST` | `/api/v1/admin/auctions/{auctionId}/force-cancel` | `AUC-15` | Admin cưỡng chế hủy phiên đấu giá khi có bất thường |
| R140 | F3. đấu giá. | `GET` | `/api/v1/admin/auctions/{auctionId}/saga` | `AUC-19` | Admin theo dõi xem phiên đang ở bước nào của luồng đơn hàng(sau khi chốt người thắng -> commerce) |
| R141 | F3. đấu giá. | `GET` | `/api/v1/admin/auction-configs` | `AUC-16` | Xem các luật đang hiệu lực (tham chiếu tới userSerive để lấy field uy tín seller,buyer, số lần gia hạn,gia hạn bao nhiêu phút,.....) |
| R142 | F3. đấu giá. | `PUT` | `/api/v1/admin/auction-configs/{key}` | `AUC-17` | Cập nhật cấu hình đấu giá(chỉ ảnh hưởng auction tương lai ) |
| R143 | F3. đấu giá. | `POST` | `/api/v1/auctions/{auctionId}/bids` | `AUC-07` | Buyer đặt giá cho một phiên đấu giá |
| R144 | F3. đấu giá. | `GET` | `/api/v1/auctions/{auctionId}/bids` | `AUC-03` | User xem được lịch sử đặt giá của phiên đang tham gia |
| R145 | F3. đấu giá. | `GET` | `/api/v1/me/bids` | `AUC-08` | Buyer coi được các phiên đấu giá mà bản thân đã từng tham gia |
| R146 | F3. đấu giá. | `GET` | `/api/v1/auctions/{auctionId}/result` | `AUC-09` | Xem kết quả của phiên đấu giá |
| R147 | F3. đấu giá. | `GRPC` | `Auction.CheckPaymentDeadline` | `AUC-20` | Commerce gọi khi người thắng nhập địa chỉ hoặc thanh toán, để kiểm tra còn trong hạn thanh toán không |
| R148 | F3. đấu giá. | `GET` | `/internal/v1/auctions/status?productId={productId}` | `AUC-34` | Catalog lấy trạng thái phiên đấu giá gần nhất của một sản phẩm, để ẩn sản phẩm khỏi kho ảo khi đã bán xong |
| R149 | F3. đấu giá. | `GET` | `/internal/v1/auctions/{auctionId}/summary` | `AUC-35` | Catalog lấy thông tin chi tiết một phiên: người đang trả giá cao nhất, giá khởi điểm, giá hiện tại, bước giá |
| R178 | F5. thanh toán. | `GET` | `/api/v1/wallets/me` | `WAL-02` | Lấy thông tin ví và số dư khả dụng/bị khóa của cá nhân |
| R179 | F5. thanh toán. | `POST` | `/api/v1/wallets/topups/vnpay` | `WAL-03` | Tạo yêu cầu nạp tiền vào ví qua cổng VNPay và lấy URL thanh toán |
| R180 | F5. thanh toán. | `POST` | `/api/v1/wallets/vnpay/ipn` | `WAL-04` | Webhook nhận kết quả IPN từ VNPay (Nạp ví hoặc Thanh toán đơn trực tiếp) |
| R181 | F5. thanh toán. | `POST` | `/api/v1/wallets/checkout/direct` | `WAL-05B` | Tạo phiên thanh toán trực tiếp qua cổng VNPay cho đơn hàng (bỏ qua số dư ví) |
| R182 | F5. thanh toán. | `POST` | `/api/v1/wallets/withdrawals` | `WAL-07` | Người bán (Seller) tạo yêu cầu rút tiền từ ví về tài khoản ngân hàng |
| R183 | F5. thanh toán. | `PATCH` | `/api/v1/admin/wallets/withdrawals/{id}` | `WAL-08` | Quản trị viên duyệt hoặc từ chối yêu cầu rút tiền của Seller |
| R184 | F5. thanh toán. | `GET` | `/api/v1/wallets/transactions` | `WAL-09` | Tra cứu lịch sử biến động sổ cái (wallet_transactions) cá nhân |
| R185 | F5. thanh toán. | `POST` | `/api/v1/admin/wallets/{walletId}/adjustments` | `WAL-10` | Admin điều chỉnh số dư ví thủ công (Cộng/Trừ tiền kèm kiểm toán) |
| R186 | F5. thanh toán. | `POST` | `/api/v1/notifications/devices` | `NOTI-01` | Đăng ký hoặc làm mới FCM/APNs device token để nhận push notification |
| R187 | F5. thanh toán. | `DELETE` | `/api/v1/notifications/devices` | `NOTI-02` | Thu hồi hoặc vô hiệu hóa device token khi logout hoặc tắt quyền push |
| R188 | F5. thanh toán. | `GET` | `/api/v1/notifications/preferences` | `NOTI-03` | Lấy danh sách cấu hình bật/tắt nhận thông báo của người dùng |
| R189 | F5. thanh toán. | `PUT` | `/api/v1/notifications/preferences` | `NOTI-04` | Cập nhật tùy chọn bật/tắt nhận thông báo theo loại sự kiện và kênh gửi |
| R190 | F5. thanh toán. | `GET` | `/api/v1/notifications/me` | `NOTI-05` | Lấy danh sách lịch sử thông báo in-app (quả chuông) kèm số lượng chưa đọc |
| R191 | F5. thanh toán. | `PATCH` | `/api/v1/notifications/me/read` | `NOTI-06` | Đánh dấu một số hoặc toàn bộ thông báo trong hộp thư là đã đọc |
| R192 | F5. thanh toán. | `GET` | `/api/v1/admin/notifications/channels/{code}` | `NOTI-07` | Admin xem trạng thái và cấu hình kênh gửi thông báo |
| R193 | F5. thanh toán. | `PUT` | `/api/v1/admin/notifications/channels/{code}` | `NOTI-07` | Admin cập nhật cấu hình và bật/tắt kênh gửi thông báo |
| R194 | F5. thanh toán. | `GET` | `/api/v1/admin/notifications/templates` | `NOTI-08` | Admin xem danh sách mẫu thông báo (Template Engine) |
| R195 | F5. thanh toán. | `POST` | `/api/v1/admin/notifications/templates` | `NOTI-08` | Admin tạo mẫu nội dung thông báo mới |
| R196 | F5. thanh toán. | `GET` | `/api/v1/admin/notifications` | `NOTI-09` | Admin/Staff tra cứu lịch sử gửi thông báo và nhật ký lỗi delivery |
| R197 | F5. thanh toán. | `GET` | `/api/v1/admin/event-logs` | `NOTI-13` | Admin tra cứu nhật ký sự kiện kỹ thuật message bus (90 ngày) |
| R198 | F5. thanh toán. | `GET` | `/api/v1/admin/event-logs/{id}` | `NOTI-14` | Admin xem chi tiết toàn bộ raw JSON payload của sự kiện kỹ thuật |
| R199 | F5. thanh toán. | `GET` | `/api/v1/admin/health/broker` | `NOTI-16` | Admin theo dõi trạng thái sức khỏe, latency và queue depth RabbitMQ |

---

## 3. CHI TIẾT ĐẶC TẢ TỪNG ENDPOINT

## PHÂN HỆ: USER

### [1] POST /api/v1/auth/register
- **Mô tả:** Người dùng đăng kí tài khoản
- **ID Tham Chiếu:** `ADM-23`

#### Request
```
Body:
{
"email": "string",
"password": "string",
"username": "string (optional, max 100)",
"firstName": "string",
"lastName": "string",
"phoneNumber": "string"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Đăng ký thành công, vui lòng kiểm tra email để lấy mã OTP xác thực",
  "data": {
    "userId": "uuid",
    "email": "string",
    "otpExpiresIn": "int: 300"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_VALIDATION_FAILED: The provided input data is invalid.
409 ERR_EMAIL_ALREADY_EXISTS: Email is already registered in the system.
409 ERR_USERNAME_ALREADY_EXISTS: Username is already taken.
409 ERR_PHONE_ALREADY_EXISTS: Phone number is already registered in the system.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-01
2. WAL-01 (tạo ví 0 đồng)
3. NOTI-10 (Gửi email OTP)

---

### [2] POST /api/v1/auth/otp/verify
- **Mô tả:** Xác thực tài khoản người dùng

#### Request
```
Body:
{
  "email": "user@example.com",
  "otp": "123456"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Kích hoạt tài khoản thành công! Bạn có thể đăng nhập ngay bây giờ",
  "data": {
    "isVerified": "boolean: true",
    "email": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_OTP_INVALID: The OTP code provided is invalid.
400 ERR_OTP_EXPIRED: The OTP code has expired.
404 ERR_USER_NOT_FOUND: Account does not exist.
409 ERR_ACCOUNT_ALREADY_ACTIVE: Account has already been verified and activated.
429 ERR_MAX_OTP_ATTEMPTS: Maximum OTP verification attempts exceeded (max 5 attempts).
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-02
2. NOTI-10 (ghi log kích hoạt)

---

### [3] POST /api/v1/auth/otp/resend
- **Mô tả:** Dùng gửi otp cho đăng kí và cả quên mật khẩu

#### Request
```
Body:
{
"email": "string",
"type": "string: \"REGISTER\" | \"FORGOT_PASSWORD\""
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Mã OTP mới đã được gửi tới email của bạn",
  "data": {
    "email": "string",
    "resendCooldown": "int: 60"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
429 ERR_OTP_COOLDOWN: Please wait at least 60 seconds before requesting another OTP.
429 ERR_MAX_DAILY_OTP: Maximum daily OTP request limit exceeded (max 10 requests).
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-03
2. NOTI-10 (gửi lại OTP)

---

### [4] POST /api/v1/auth/login
- **Mô tả:** Đăng nhập hệ thống (Email + Password)

#### Request
```
Body:
{
"identifier": "string (email hoặc username)",
"password": "string",
"deviceInfo": "string: browser, OS",
"ipAddress": "string"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Đăng nhập thành công",
  "data": {
    "accessToken": "string",
    "refreshToken": "string",
    "tokenType": "Bearer",
    "expiresIn": 3600,
    "user": {
      "id": "uuid",
      "email": "string",
      "username": "string | null",
      "firstName": "string",
      "lastName": "string",
      "roles": "string[]",
      "permissions": "string[]"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_INVALID_CREDENTIALS: Invalid username, email, or password.
403 ERR_ACCOUNT_NOT_VERIFIED: Account has not been verified with OTP.
403 ERR_ACCOUNT_BANNED: Account has been locked or banned by an administrator.
423 ERR_ACCOUNT_LOCKED_TEMPORARY: Account is temporarily locked for 30 minutes due to 5 consecutive failed login attempts.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-04

---

### [5] POST /api/v1/auth/refresh
- **Mô tả:** Làm mới Token ngầm (Refresh Token Rotation - RTR)

#### Request
```
Body:
{
"refreshToken": "string",
"deviceInfo": "string: browser, OS"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Làm mới phiên làm việc thành công",
  "data": {
    "accessToken": "string",
    "refreshToken": "string",
    "expiresIn": 3600
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_INVALID_TOKEN: Token is invalid, expired, or malformed.
401 ERR_TOKEN_REUSED: Token reuse attack detected, session has been revoked.
401 ERR_SESSION_REVOKED: Login session has been revoked.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-05

---

### [6] POST /api/v1/auth/password/forgot
- **Mô tả:** Yêu cầu quên mật khẩu & Gửi OTP khôi phục

#### Request
```
Body:
{
"email": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Nếu email tồn tại, hướng dẫn đặt lại mật khẩu đã được gửi đến bạn",
  "data": {
    "email": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
429 ERR_RATE_LIMIT_EXCEEDED: Rate limit exceeded, please try again later.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-06
2. NOTI-10 (gửi OTP reset)

---

### [7] PUT /api/v1/auth/password/reset
- **Mô tả:** Đặt lại mật khẩu mới bằng mã OTP

#### Request
```
Body:
{
  "email": "user@example.com",
  "otpCode": "123456",
  "newPassword": "NewPassword123@",
  "confirmPassword": "NewPassword123@"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập lại!",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_OTP_INVALID_OR_EXPIRED: The OTP code is invalid or has expired.
400 ERR_PASSWORD_SAME_AS_OLD: New password cannot be the same as your recent password.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-07
2. NOTI-10 (email cảnh báo bảo mật)

---

### [8] PATCH /api/v1/auth/password
- **Mô tả:** Cập nhật lại mật khẩu(Đổi mật khẩu)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"oldPassword": "string",
"newPassword": "string",
"confirmPassword": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đổi mật khẩu thành công. Vui lòng đăng nhập lại trên các thiết bị khác",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_WRONG_OLD_PASSWORD: Current password provided is incorrect.
400 ERR_SAME_PASSWORD: New password cannot be the same as your old password.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-08
2. NOTI-10 (email cảnh báo bảo mật)

---

### [9] POST /api/v1/auth/logout
- **Mô tả:** Đăng xuất & Thu hồi phiên hiện tại

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"refreshToken": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đăng xuất thành công",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
404 ERR_SESSION_NOT_FOUND: The specified session was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUTH-09

---

### [10] POST /api/v1/auth/logout-all
- **Mô tả:** Đăng xuất khỏi toàn bộ thiết bị khác

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã đăng xuất khỏi toàn bộ các thiết bị khác thành công",
  "data": {
    "countRevoked": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-05

---

### [11] GET /api/v1/me/sessions
- **Mô tả:** Xem danh sách thiết bị đang đăng nhập

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách phiên đăng nhập thành công",
  "data": {
    "items": [
      {
        "sessionId": "uuid",
        "deviceInfo": "string",
        "ipAddress": "string",
        "lastActiveAt": "timestamp",
        "isCurrent": "boolean"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-03

---

### [12] DELETE /api/v1/me/sessions/{id}
- **Mô tả:** Thu hồi / Đăng xuất thiết bị từ xa

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
"id": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã thu hồi phiên đăng nhập thành công",
  "data": {
    "revokedSessionId": "uuid"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
403 ERR_FORBIDDEN: You do not have permission to manage another user session.
404 ERR_SESSION_NOT_FOUND: The specified session was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-04

---

### [13] GET /api/v1/me
- **Mô tả:** Xem danh sách cá nhân của user

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy thông tin cá nhân thành công",
  "data": {
    "id": "uuid",
    "email": "string",
    "username": "string | null",
    "firstName": "string",
    "lastName": "string",
    "phoneNumber": "string",
    "avatarUrl": "string",
    "address": "string",
    "reputationScore": "int",
    "trustLevel": "string",
    "roles": "string[]",
    "permissions": "string[]",
    "isSeller": "boolean",
    "createdAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, token is missing or expired.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-01
2. GRPC-05 (GetUserContact - Notification & Fulfillment)

---

### [14] PATCH /api/v1/me
- **Mô tả:** Cập nhật thông tin hồ sơ cá nhân

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "username": "string (optional, max 100)",
  "firstName": "string",
  "lastName": "string",
  "phoneNumber": "string",
  "address": {
    "provinceId": 1,
    "districtId": 1,
    "wardCode": "001",
    "streetAddress": "string"
  }
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật hồ sơ thành công",
  "data": {
    "id": "uuid",
    "username": "string | null",
    "firstName": "string",
    "lastName": "string",
    "phoneNumber": "string",
    "avatarUrl": "string",
    "address": "string",
    "updatedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_VALIDATION_FAILED: The provided input data or address is invalid.
409 ERR_USERNAME_DUPLICATE: Username is already taken by another account.
409 ERR_PHONE_DUPLICATE: Phone number is already registered by another account.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-02

---

### [15] GET /api/v1/me/avatar
- **Mô tả:** Xem ảnh avatar cá nhân

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy avatar thành công",
  "data": {
    "userId": "uuid",
    "avatarUrl": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, token is missing or expired.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-06B

---

### [16] POST /api/v1/me/avatar
- **Mô tả:** Tải lên và cập nhật avatar cá nhân

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"file": "binary (image/jpeg, image/png, image/webp, max 5MB)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật ảnh đại diện thành công",
  "data": {
    "avatarUrl": "string",
    "updatedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_INVALID_FILE_TYPE: Unsupported file format, only JPG, PNG, and WEBP are accepted.
413 ERR_FILE_TOO_LARGE: File size exceeds maximum allowed limit of 5mb.
500 ERR_STORAGE_UPLOAD_FAILED: Internal server error occurred while storing uploaded file.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-06

---

### [17] GET /api/v1/me/reputation
- **Mô tả:** Xem uy tín của bản thân

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy thông tin uy tín cá nhân thành công",
  "data": {
    "userId": "uuid",
    "reputationScore": "int",
    "trustLevel": "string",
    "canBid": "boolean",
    "canSell": "boolean",
    "positiveRatingCount": "int",
    "negativeRatingCount": "int",
    "nextLevelThreshold": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, token is invalid or missing.
404 ERR_USER_NOT_FOUND: User account was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-08
2. ADMIN-12 (lấy cấu hình ngưỡng uy tín)

---

### [18] GET /api/v1/me/penalties
- **Mô tả:** xem thông tin phạt của bản thân

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 20)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy lịch sử vi phạm thành công",
  "data": {
    "items": [
      {
        "id": "uuid",
        "violationType": "string",
        "reason": "string",
        "penaltyApplied": "string",
        "pointsDeducted": "int",
        "status": "string",
        "issuedAt": "timestamp",
        "expiresAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, session is missing or expired.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-09
2. REP-02 (ghi phạt bùng kèo đấu giá)
3. REP-03 (ghi phạt seller hủy đơn)
4. REP-05 (nơi ghi user_penalties)

---

### [19] GET /api/v1/user/{userId}
- **Mô tả:** Xem chi tiết hồ sơ cá nhân của 1 user cụ thể

#### Request
```
Path:
{
"userId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy thông tin hồ sơ công khai thành công",
  "data": {
    "id": "uuid",
    "username": "string | null",
    "firstName": "string",
    "lastName": "string",
    "avatarUrl": "string",
    "reputationScore": "int",
    "trustLevel": "string",
    "badges": "string[]",
    "isSeller": "boolean",
    "joinedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_USER_INACTIVE: Account is not active or has been deleted.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-07

---

### [20] GET /api/v1/user/{userId}/avatar
- **Mô tả:** Xem ảnh avatar của từng user

#### Request
```
Path:
{
"userId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy avatar thành công",
  "data": {
    "userId": "uuid",
    "avatarUrl": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. USER-07B

---

### [21] GET /api/v1/seller/{sellerId}
- **Mô tả:** User lấy thông tin cửa hàng của Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
"sellerId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy thông tin cửa hàng thành công",
  "data": {
    "sellerId": "uuid",
    "shopName": "string",
    "avatarUrl": "string",
    "ratingAvg": "decimal",
    "totalReviews": "int",
    "joinedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
404 ERR_SELLER_NOT_FOUND: Shop does not exist or has been deactivated.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-08
2. CART-01 (hiển thị shop trong giỏ hàng)
3. ORD-01 (thông tin shop khi tạo đơn)
4. ORD-03 (thông tin shop trong chi tiết đơn)
5. ORD-11 (tên shop)

---

### [22] GET /api/v1/user/{userId}/reputation
- **Mô tả:** Xem Thẻ Tóm tắt Hồ sơ Uy tín công khai

#### Request
```
Path:
{
"userId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy tóm tắt uy tín thành công",
  "data": {
    "userId": "uuid",
    "reputationScore": "int",
    "trustLevel": "string",
    "badges": "string[]",
    "canBid": "boolean",
    "canSell": "boolean",
    "totalReviews": "int",
    "positiveRatio": "decimal"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REVIEW-05

---

### [23] GET /api/v1/user/{userId}/reputation/history
- **Mô tả:** Xem lịch sử uy tín (tăng or giảm)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 20)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy lịch sử uy tín thành công",
  "data": {
    "items": [
      {
        "id": "int",
        "changeAmount": "int",
        "scoreAfter": "int",
        "reason": "string",
        "referenceType": "string",
        "createdAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_FORBIDDEN: You do not have permission to view other users reputation history.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REVIEW-03
2. REP-01 (+1 điểm đơn hoàn thành)
3. REP-02 (-10 điểm bùng kèo đấu giá)
4. REP-03 (-5 điểm seller hủy đơn)
5. REP-04 (+/- điểm theo số sao đánh giá)
6. ADMIN-14 (nơi ghi reputation_logs)

---

### [24] GET /api/v1/user/{userId}/reviews
- **Mô tả:** Xem danh sách đánh giá công khai của 1 user/Shop

#### Request
```
Path:
{ "userId": "uuid" }

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 10)",
"filterRating": "int (optional: 1..5)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách đánh giá thành công",
  "data": {
    "items": [
      {
        "id": "uuid",
        "reviewerName": "string",
        "rating": "int",
        "comment": "string",
        "mediaUrls": "string[]",
        "createdAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REVIEW-02

---

### [25] POST /api/v1/review/files/upload
- **Mô tả:** Upload đánh giá sản phẩm

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"files": "binary[] (max 5 files)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Upload ảnh đánh giá thành công",
  "data": {
    "fileUrls": "string[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_FILE_LIMIT_EXCEEDED: Maximum limit of 5 attached images exceeded.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FILE-02
2. REVIEW-01

---

### [26] POST /api/v1/reviews
- **Mô tả:** Đánh giá đối tác 2 chiều (Buyer ↔ Seller)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "transactionType": "ORDER|AUCTION",
  "transactionId": "uuid",
  "targetUserId": "uuid",
  "rating": 5,
  "comment": "Giao hang nhanh, dong goi can than.",
  "mediaUrls": ["https://img.example.com/review1.png"]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Gửi đánh giá thành công! Điểm uy tín của đối tác đã được cập nhật",
  "data": {
    "reviewId": "uuid",
    "newTargetReputationScore": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_TRANSACTION_NOT_COMPLETED: Transaction is not yet completed.
400 ERR_REVIEW_WINDOW_EXPIRED: Review submission period of 7 days has expired.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_NOT_TRANSACTION_PARTY: You are not a participant in this transaction.
409 ERR_REVIEW_ALREADY_EXISTS: A review has already been submitted for this transaction.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REVIEW-01
2. ORD-02 (check đơn tồn tại)
3. AUC-09 (kết quả đấu giá)
4. FILE-02 (upload ảnh đính kèm)
5. REP-04 (cập nhật uy tín theo sao)
6. NOTI-10 (thông báo đối tác nhận đánh giá)
7. ORD-23 (check đơn COMPLETED & hạn 7 ngày)

---

### [27] POST /api/v1/report/files/upload
- **Mô tả:** Upload bằng chứng tố cáo tài khoản vi phạm (User Violation Evidence)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"files": "binary[] (<= 5MB)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Upload bằng chứng tố cáo thành công",
  "data": {
    "fileUrls": "string[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_INVALID_FILE_TYPE: Invalid file format, only images up to 5mb are accepted.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FILE-01
2. REPORT-01

---

### [28] POST /api/v1/users/reports
- **Mô tả:** Người dùng gửi đơn tố cáo tài khoản vi phạm quy chế

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "reportedUserId": "uuid",
  "violationType": "SPAM|FRAUD|INAPPROPRIATE_CONTENT",
  "description": "Nguoi dung co hanh vi gian lan.",
  "evidenceUrls": ["https://img.example.com/evidence1.png"]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Gửi đơn tố cáo thành công. Nhân viên sẽ thụ lý trong 24h",
  "data": {
    "reportId": "uuid",
    "status": "PENDING",
    "submittedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_CANNOT_REPORT_SELF: You cannot submit a report against yourself.
400 ERR_VALIDATION_FAILED: Description content must be at least 10 characters long.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
404 ERR_USER_NOT_FOUND: Reported user does not exist.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REPORT-01
2. FILE-01 (upload bằng chứng vi phạm)

---

### [29] GET /api/v1/me/reports
- **Mô tả:** Người dùng xem danh sách các báo cáo do mình đã gửi

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 20)",
"status": "string (optional: PENDING, RESOLVED, REJECTED)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách tố cáo đã gửi thành công",
  "data": {
    "items": [
      {
        "reportId": "uuid",
        "targetType": "string",
        "targetId": "uuid",
        "reason": "string",
        "evidenceUrls": "string[]",
        "status": "string",
        "adminNote": "string",
        "createdAt": "timestamp",
        "resolvedAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, token is missing or expired.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REPORT-05

---

### [30] POST /api/v1/seller/registration
- **Mô tả:** Seller tạo đơn đăng kí

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "shopName": "string",
  "businessEmail": "string",
  "hotline": "string",
  "warehouseAddress": {
    "provinceId": 1,
    "districtId": 1,
    "wardCode": "001",
    "streetAddress": "string"
  },
  "identityCardNumber": "string"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Hồ sơ mở Shop đã được tiếp nhận và chuyển sang trạng thái chờ duyệt",
  "data": {
    "registrationId": "uuid",
    "status": "PENDING_APPROVAL",
    "submittedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_GHN_WAREHOUSE_INVALID: Ghn warehouse address is invalid.
400 ERR_REPUTATION_TOO_LOW: Reputation score is insufficient to open a shop (minimum 50 required).
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
409 ERR_SHOP_NAME_TAKEN: Shop name already exists.
409 ERR_REQUEST_ALREADY_PENDING: A registration request is already pending review.
409 ERR_ALREADY_SELLER: User is already registered as a seller.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-01
2. NOTI-10 (gửi OTP mở shop)
3. GHN API (kiểm tra bưu cục kho)
4. ADMIN-12 (check ngưỡng uy tín >= 50)

---

### [31] POST /api/v1/seller/registration/otp/resend
- **Mô tả:** Gửi lại otp cho tài khoản Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"registrationId": "uuid",
"businessEmail": "string (optional)"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Mã OTP xác thực mở Shop đã được gửi lại tới email",
  "data": {
    "registrationId": "uuid",
    "cooldown": 60
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
404 ERR_REGISTRATION_NOT_FOUND: Registration request was not found.
429 ERR_OTP_COOLDOWN: Please wait at least 60 seconds before requesting another OTP.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-02
2. NOTI-10 (gửi lại OTP qua email mở shop)

---

### [32] POST /api/v1/seller/registration/documents
- **Mô tả:** Upload tài liệu Seller(CCCD, ....)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"registrationId": "uuid",
"frontCccd": "binary",
"backCccd": "binary",
"businessLicense": "binary (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Tải lên tài liệu định danh thành công",
  "data": {
    "documentUrls": "string[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_INVALID_FILE_TYPE: Invalid document format, only JPG, PNG, and PDF are accepted.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
404 ERR_REGISTRATION_NOT_FOUND: Registration request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-03

---

### [33] POST /api/v1/seller/otp/verify
- **Mô tả:** Xác thực mã otp của Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"registrationId": "uuid",
"otpCode": "string (6 digits)"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Xác thực OTP thành công. Hồ sơ đã chuyển sang chờ Staff duyệt",
  "data": {
    "registrationId": "uuid",
    "status": "PENDING_APPROVAL"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_OTP_INVALID: The OTP code provided is invalid.
400 ERR_OTP_EXPIRED: The OTP code has expired.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
404 ERR_REGISTRATION_NOT_FOUND: Registration request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-04

---

### [34] GET /api/v1/seller/registration
- **Mô tả:** Seller xem đơn (đã được duyệt làm Seller hay chưa)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy trạng thái hồ sơ thành công",
  "data": {
    "registrationId": "uuid",
    "status": "PENDING_APPROVAL | APPROVED | REJECTED",
    "rejectionReason": "string | null",
    "submittedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, token is missing or expired.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-05

---

### [35] GET /api/v1/seller/profile
- **Mô tả:** Seller tự coi thông tin shop

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy thông tin Shop thành công",
  "data": {
    "shopId": "uuid",
    "shopName": "string",
    "hotline": "string",
    "pickupAddress": "string",
    "ghnShopId": "string",
    "ratingAvg": "decimal",
    "totalProducts": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_FORBIDDEN_NOT_SELLER: Account does not have the seller role.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-06

---

### [36] PATCH /api/v1/seller/profile
- **Mô tả:** Cập nhật thông tin cá nhân hồ sơ cho Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "shopName": "string",
  "hotline": "string",
  "pickupAddress": {
    "provinceId": 1,
    "districtId": 1,
    "wardCode": "001",
    "streetAddress": "string"
  },
  "description": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật thông tin Shop thành công",
  "data": {
    "shopId": "uuid",
    "shopName": "string",
    "updatedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_FORBIDDEN: You do not have permission to modify this shop.
409 ERR_SHOP_NAME_TAKEN: Shop name is already taken.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-07
2. FUL-12 (tính lại cước ship GHN khi kho đổi địa chỉ)
3. FUL-13 (đồng bộ địa chỉ kho bưu tá GHN lấy hàng)
4. ORD-01 (đồng bộ tên shop mới vào đơn hàng)
5. CART-01 (đồng bộ tên shop mới vào giỏ hàng)

---

### [37] GET /api/v1/admin/seller-registrations
- **Mô tả:** Danh sách hồ sơ Seller chờ duyệt

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 20)",
"status": "string (default: PENDING_APPROVAL)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách hồ sơ mở Shop thành công",
  "data": {
    "items": [
      {
        "registrationId": "uuid",
        "userId": "uuid",
        "shopName": "string",
        "identityCardNumber": "string",
        "warehouseAddress": "string",
        "reputationScore": "int"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view shop registration list.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-07

---

### [37B] GET /api/v1/admin/seller-registrations/{registrationId}
- **Mô tả:** Xem chi tiết hồ sơ mở Shop và tài liệu chứng từ định danh

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
"registrationId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy chi tiết hồ sơ mở Shop thành công",
  "data": {
    "registrationId": "uuid",
    "userId": "uuid",
    "shopName": "string",
    "hotline": "string",
    "pickupAddress": "string",
    "identityCardNumber": "string",
    "idCardFrontUrl": "string",
    "idCardBackUrl": "string",
    "businessLicenseUrl": "string",
    "reputationScore": "int",
    "status": "string",
    "submittedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view registration requests.
404 ERR_REGISTRATION_NOT_FOUND: Registration request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-07B

---

### [38] PUT /api/v1/admin/seller-registrations/{registrationId}/approve
- **Mô tả:** Staff duyệt hồ sơ Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "registrationId": "uuid" }

Body:
{
"note": "string (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Hồ sơ mở Shop đã được phê duyệt. Người dùng đã trở thành Seller",
  "data": {
    "registrationId": "uuid",
    "userId": "uuid",
    "status": "APPROVED",
    "approvedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_REQUEST_NOT_PENDING: Registration request is not in a pending state.
400 ERR_REPUTATION_TOO_LOW: Applicant reputation score has fallen below the threshold of 50.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to approve shop registrations.
404 ERR_REQUEST_NOT_FOUND: Registration request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-08
2. CAT-01 (mở quyền đăng sản phẩm)
3. CAT-43 (mở quyền tạo sản phẩm)
4. NOTI-10 (gửi email chúc mừng)
5. GHN API (tạo shop GHN)

---

### [39] PUT /api/v1/admin/seller-registrations/{registrationId}/reject
- **Mô tả:** Staff từ chối hồ sơ Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "registrationId": "uuid" }

Body:
{
"rejectionReason": "string (lý do cụ thể)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã từ chối hồ sơ mở Shop",
  "data": {
    "registrationId": "uuid",
    "status": "REJECTED",
    "rejectedAt": "timestamp",
    "rejectionReason": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_REASON_REQUIRED: Rejection reason must be at least 10 characters long.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to reject registration requests.
404 ERR_REQUEST_NOT_FOUND: Registration request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-09
2. NOTI-10 (gửi email thông báo lý do từ chối)

---

### [40] GET /api/v1/admin/reports
- **Mô tả:** Admin/Staff xem danh sách các đơn tố cáo tài khoản

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": 1,
  "limit": 20,
  "status": "PENDING|RESOLVED|DISMISSED",
  "violationType": "SPAM|FRAUD"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách đơn tố cáo thành công",
  "data": {
    "items": [
      {
        "id": "uuid",
        "reporterId": "uuid",
        "reportedUserId": "uuid",
        "violationType": "string",
        "description": "string",
        "evidenceUrls": "string[]",
        "status": "string",
        "createdAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to moderate reports.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REPORT-02

---

### [41] PUT /api/v1/admin/reports/{reportId}/resolve
- **Mô tả:** Staff xử lý chấp thuận tố cáo & áp dụng chế tài kỷ luật

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "reportId": "uuid" }

Body:
{
"action": "string (\"DEDUCT_REPUTATION\" | \"BAN_USER\")",
"pointsDeducted": "int (optional: 1..50)",
"resolutionNote": "string (>= 10 ký tự)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã xử lý tố cáo thành công. Chế tài kỷ luật đã được áp dụng",
  "data": {
    "reportId": "uuid",
    "status": "RESOLVED",
    "resolvedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_ALREADY_RESOLVED: Report has already been resolved or processed.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to process reports.
404 ERR_REPORT_NOT_FOUND: Report was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REPORT-03
2. REP-05 (trừ điểm uy tín nếu chọn DEDUCT_REPUTATION)
3. ADMIN-05 (Nhánh BAN_USER)
4. NOTI-10 (gửi kết quả 2 bên)

---

### [41B] PUT /api/v1/admin/reports/{reportId}/dismiss
- **Mô tả:** Staff bác bỏ đơn tố cáo sai sự thật / không đủ chứng cứ

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "reportId": "uuid" }

Body:
{
"reason": "string (lý do bác bỏ)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã bác bỏ đơn tố cáo",
  "data": {
    "reportId": "uuid",
    "status": "DISMISSED",
    "dismissedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_REASON_REQUIRED: A reason is required to dismiss the report.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to dismiss reports.
404 ERR_REPORT_NOT_FOUND: Report was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REPORT-04
2. NOTI-10 (thông báo bác bỏ đơn tố cáo)

---

### [42] PUT /api/v1/admin/reviews/{id}/hide
- **Mô tả:** Staff/Admin ẩn đánh giá vi phạm tiêu chuẩn

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "id": "uuid" }

Body:
{
"reason": "string (lý do ẩn vi phạm)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã ẩn đánh giá vi phạm thành công",
  "data": {
    "reviewId": "uuid",
    "isHidden": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_REASON_REQUIRED: A reason is required to hide the review.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to moderate reviews.
404 ERR_REVIEW_NOT_FOUND: Review was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. REVIEW-04
2. REP-04 (hoàn điểm)
3. NOTI-10 (thông báo ẩn đánh giá vi phạm)

---

### [43] GET /api/v1/admin/user
- **Mô tả:** Admin xem danh sách các user

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (default: 1)",
"limit": "int (default: 20)",
"keyword": "string (tìm tên, email, sđt)",
"role": "string",
"status": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh sách người dùng thành công",
  "data": {
    "items": [
      {
        "id": "uuid",
        "email": "string",
        "firstName": "string",
        "lastName": "string",
        "phoneNumber": "string",
        "status": "string",
        "reputationScore": "int",
        "roles": "string[]"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view user list.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-01

---

### [44] POST /api/v1/admin/user
- **Mô tả:** Admin tạo user mới

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"email": "string",
"password": "string",
"firstName": "string",
"lastName": "string",
"phoneNumber": "string",
"roleCodes": [
"STAFF"
]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "message": "Tạo tài khoản thành công",
  "data": {
    "userId": "uuid",
    "email": "string",
    "roles": "string[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_INVALID_ROLES: The specified role list is invalid.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to create user accounts.
409 ERR_EMAIL_EXISTS: Email already exists in the system.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-01B
2. WAL-01 (tạo ví tiền 0 đồng)
3. NOTI-10 (gửi email tài khoản & mật khẩu)

---

### [45] GET /api/v1/admin/user/{userId}
- **Mô tả:** Xem chi tiết hồ sơ cá nhân, phân quyền & uy tín

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
"userId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy chi tiết người dùng thành công",
  "data": {
    "id": "uuid",
    "email": "string",
    "firstName": "string",
    "lastName": "string",
    "phoneNumber": "string",
    "status": "string",
    "reputationScore": "int",
    "trustLevel": "string",
    "roles": "string[]",
    "permissions": "string[]",
    "sellerProfile": "object",
    "createdAt": "timestamp",
    "auditHistory": "object[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view user details.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-02

---

### [46] PUT /api/v1/admin/user/{userId}
- **Mô tả:** Admin cập nhật thông tin của user cụ thể

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"firstName": "string",
"lastName": "string",
"phoneNumber": "string",
"status": "string",
"reason": "string (lý do sửa)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật thông tin người dùng thành công",
  "data": {
    "id": "uuid",
    "firstName": "string",
    "lastName": "string",
    "status": "string",
    "updatedBy": "uuid",
    "updatedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_AUDIT_REASON_REQUIRED: Intervention reason must be at least 10 characters long.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to edit user information.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-03

---

### [47] DELETE /api/v1/admin/user/{userId}
- **Mô tả:** Xóa MỀM 1 user khỏi hệ thống

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"reason": "string (lý do xóa)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Tài khoản người dùng đã được xóa mềm thành công",
  "data": {
    "id": "uuid",
    "isDeleted": true,
    "deletedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_CANNOT_DELETE_ADMIN: Cannot delete an administrator account.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to delete user accounts.
404 ERR_USER_NOT_FOUND: User was not found.
409 ERR_ACTIVE_AUCTIONS_EXIST: Account currently has active auctions or pending orders.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-04
2. CART-11 (dọn giỏ hàng)
3. AUC-33 (hủy các phiên đấu giá treo)
4. CAT-42 (ẩn toàn bộ sản phẩm của user)

---

### [48] PATCH /api/v1/admin/user/{userId}/ban
- **Mô tả:** Admin ban 1 user

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"reason": "string (lý do khóa)",
"banDurationDays": "int (0 = vĩnh viễn)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã khóa tài khoản người dùng thành công",
  "data": {
    "id": "uuid",
    "status": "BANNED",
    "bannedUntil": "timestamp",
    "reason": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_CANNOT_BAN_ADMIN: Cannot ban or lock an administrator account.
400 ERR_ALREADY_BANNED: Account is already banned or locked.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to ban users.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-05
2. NOTI-10 (gửi mail báo khóa)
3. AUC-33 (chặn đặt giá & hủy phiên đang mở)
4. CART-11 (dọn giỏ hàng)
5. CAT-42 (ẩn/khóa toàn bộ sản phẩm của user)

---

### [49] PATCH /api/v1/admin/user/{userId}/unban
- **Mô tả:** Admin hủy ban 1 user

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"reason": "string (lý do mở khóa)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Đã mở khóa tài khoản người dùng thành công",
  "data": {
    "id": "uuid",
    "status": "ACTIVE",
    "unbannedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_USER_NOT_BANNED: Account is currently active and not banned.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to unban users.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-06
2. NOTI-10 (thông báo tài khoản hoạt động lại)

---

### [50] GET /api/v1/admin/sellers/{sellerId}
- **Mô tả:** Admin lấy thông tin cửa hàng của từng Seller

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
"sellerId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy chi tiết Shop thành công",
  "data": {
    "sellerId": "uuid",
    "shopName": "string",
    "ownerUserId": "uuid",
    "identityCardNumber": "string",
    "pickupAddress": "string",
    "status": "string",
    "auditHistory": "object[]"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_FORBIDDEN: Administrator privileges are required.
404 ERR_SELLER_NOT_FOUND: Shop information was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. SELLER-09

---

### [51] PUT /api/v1/admin/user/{userId}/roles
- **Mô tả:** Gán / Thu hồi vai trò nội bộ (Phân quyền SoD)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
  "roleCodes": ["Staff"],
  "roleIds": [1],
  "reason": "Promotion to customer support staff."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật vai trò người dùng thành công",
  "data": {
    "userId": "uuid",
    "roles": [
      "STAFF"
    ],
    "updatedBy": "uuid"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_SOD_VIOLATION: Separation of duties (SoD) policy violation detected.
400 ERR_CANNOT_DEMOTE_LAST_ADMIN: Cannot demote the last remaining administrator.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_FORBIDDEN: Only super admin has permission to assign roles.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-10

---

### [52] PATCH /api/v1/admin/user/{userId}/reputation
- **Mô tả:** Admin điều chỉnh uy tín của user(thủ công)

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "userId": "uuid" }

Body:
{
"delta": "int ([-50..+50])",
"reason": "string (>= 10 ký tự)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Điều chỉnh điểm uy tín người dùng thành công",
  "data": {
    "userId": "uuid",
    "previousScore": "int",
    "newScore": "int",
    "delta": "int",
    "trustLevel": "string"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_REASON_REQUIRED: Reputation adjustment reason must be at least 10 characters long.
400 ERR_INVALID_DELTA: Reputation delta must be non-zero and within [-50, +50].
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to adjust reputation scores.
404 ERR_USER_NOT_FOUND: User was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-14
2. NOTI-10 (thông báo biến động uy tín)
3. GRPC-01 (đồng bộ quyền đấu giá sang Auction)
4. GRPC-04 (cập nhật cache quyền BID/SELL)

---

### [53] GET /api/v1/admin/roles
- **Mô tả:** Admin xem toàn bộ roles trong hệ thống

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh mục vai trò thành công",
  "data": {
    "items": [
      {
        "roleId": "int",
        "roleName": "string",
        "description": "string",
        "isSystemRole": "boolean",
        "permissionsCount": "int"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view roles.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-16

---

### [54] GET /api/v1/admin/permissions
- **Mô tả:** Xem danh sách các đặc quyền

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy danh mục đặc quyền thành công",
  "data": {
    "items": [
      {
        "permissionId": "int",
        "permissionCode": "string",
        "module": "string",
        "description": "string"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view permissions.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-16B

---

### [55] PUT /api/v1/admin/roles/{roleId}/permissions
- **Mô tả:** Cập nhật danh sách đặc quyền (Permissions) cho Vai trò

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "roleId": 1 }

Body:
{
  "description": "Customer support and complaint resolution.",
  "permissionIds": [1, 2, 3]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật quyền hạn vai trò thành công",
  "data": {
    "roleId": "int",
    "updatedPermissionsCount": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_CANNOT_EDIT_SYSTEM_ROLE: System-defined roles cannot be edited or modified.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to edit roles.
404 ERR_ROLE_NOT_FOUND: Specified role does not exist.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-18

---

### [56] GET /api/v1/admin/audit-logs
- **Mô tả:** Tra cứu Nhật ký Kiểm toán hệ thống

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": 1,
  "limit": 20,
  "actorId": "uuid",
  "action": "string",
  "fromDate": "2026-10-01T00:00:00Z",
  "toDate": "2026-10-26T00:00:00Z"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "actorId": "uuid",
        "action": "USER_BANNED",
        "targetEntity": "users",
        "oldValues": {},
        "newValues": {},
        "reason": "Policy violation.",
        "ipAddress": "127.0.0.1",
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have permission to view audit logs.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-11

---

### [57] GET /api/v1/admin/configs
- **Mô tả:** Xem danh sách tham số cấu hình toàn sàn

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Lấy cấu hình hệ thống thành công",
  "data": {
    "items": [
      {
        "key": "string",
        "value": "string",
        "description": "string",
        "dataType": "string",
        "updatedAt": "timestamp"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to view system configurations.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-12
2. AUC-16 (đồng bộ cấu hình bước giá & phí sàn sang Auction)

---

### [58] PUT /api/v1/admin/configs
- **Mô tả:** Cập nhật tham số cấu hình toàn sàn

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"key": "string",
"value": "string",
"reason": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Cập nhật cấu hình sàn thành công",
  "data": {
    "key": "string",
    "oldValue": "string",
    "newValue": "string",
    "updatedAt": "timestamp"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ERR_INVALID_CONFIG_VALUE: Configuration parameter value is invalid.
401 ERR_UNAUTHORIZED: Authentication required, user is not logged in.
403 ERR_PERMISSION_DENIED: You do not have permission to edit system configurations.
404 ERR_CONFIG_NOT_FOUND: Configuration key was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ADMIN-13
2. AUC-16 (cập nhật cache cấu hình sàn sang Auction)
3. AUC-17 (áp dụng cấu hình đấu giá mới)

---

## PHÂN HỆ: F1. MUA HÀNG THƯỜNG.

### [Row 66] GET /api/v1/products
- **Mô tả:** lấy toàn bộ product
- **ID Tham Chiếu:** `CAT-06`

#### Request
```
Query:
{
"page": "int",
"pageSize": "int",
"keyword": "string",
"categoryId": "uuid",
"status": "DRAFT|ACTIVE|INACTIVE",
"sellerId": "uuid",
"sortBy": "string",
"sortDir": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "brand": "string",
        "minPrice": "decimal",
        "maxPrice": "decimal",
        "primaryImageUrl": "string",
        "avgRating": "decimal",
        "status": "DRAFT|ACTIVE|INACTIVE"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_PAGE: Page and pageSize must be positive integers.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-06
2. orr

---

### [Row 67] GET /api/v1/products/search
- **Mô tả:** filter, search product
- **ID Tham Chiếu:** `CAT-20 + CAT-21`

#### Request
```
Query:
{
"keyword": "string",
"categoryId": "uuid",
"minPrice": "decimal",
"maxPrice": "decimal",
"page": "int",
"pageSize": "int",
"brand": "string",
"saleType": "REGULAR|AUCTION",
"attributes": "string (AttrName=AttrValue)",
"minRating": "decimal",
"sortBy": "newest|priceAsc|priceDesc|rating"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "minPrice": "decimal",
        "maxPrice": "decimal",
        "primaryImageUrl": "string",
        "avgRating": "decimal"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_FILTER: Search filter parameters are invalid.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-20
2. CAT-21

---

### [Row 68] GET /api/v1/product/{productId}
- **Mô tả:** lấy thông tin chi tiết của 1 product
- **ID Tham Chiếu:** `CAT-05`

#### Request
```
Path:
{"productId": "uuid"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "product": {
      "productId": "uuid",
      "sellerId": "uuid",
      "categoryId": "uuid",
      "name": "string",
      "description": "string",
      "brand": "string",
      "saleType": "REGULAR|AUCTION",
      "status": "DRAFT|ACTIVE|INACTIVE",
      "statusReason": "SELLER_PAUSED|DISCONTINUED|ADMIN_LOCKED|OTHER",
      "specifications": "object",
      "publishedAt": "datetime"
    },
    "category": {
      "categoryId": "uuid",
      "parentId": "uuid",
      "name": "string",
      "description": "string",
      "level": "int",
      "sortOrder": "int",
      "isActive": "boolean"
    },
    "variants": [
      {
        "variantId": "uuid",
        "skuCode": "string",
        "name": "string",
        "price": "decimal",
        "status": "ACTIVE|INACTIVE",
        "attributes": [
          {
            "attrName": "string",
            "attrValue": "string"
          }
        ]
      }
    ],
    "images": [
      {
        "url": "string",
        "altText": "string"
      }
    ],
    "rating": {
      "avgRating": "decimal",
      "reviewCount": "int"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_PRODUCT_ID: Product ID format is invalid.
404 PRODUCT_NOT_FOUND: Product was not found or is inactive.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-05

---

### [Row 69] POST /api/v1/cart/items
- **Mô tả:** thêm 1 hoặc nhiều sản phẩm vào giỏ hàng
- **ID Tham Chiếu:** `CART-02`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{"productId": "uuid", "skuId": "uuid", "quantity": "int"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "cartItemId": "uuid",
    "quantity": "int",
    "unitPriceSnapshot": "decimal",
    "cart": {
      "itemCount": "int",
      "subtotalAmount": "decimal"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_QUANTITY: Quantity must be greater than zero.
400 STOCK_INSUFFICIENT: Requested quantity exceeds available stock.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 PRODUCT_NOT_FOUND: Product or SKU does not exist.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CART-02
2. CAT-23
3. CAT-24

---

### [Row 70] GET /api/v1/cart
- **Mô tả:** xem toàn bộ các sản phẩm của giỏ hàng, gửi list cart lên và kho check cái list đó và catalogc
- **ID Tham Chiếu:** `CART-01 (ô ID tham chiếu ghi NULL) + FUL-04 + CAT-39 + CAT-24`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{"includeInvalid": "boolean"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "cartId": "uuid",
    "status": "Active|Abandoned|Converted",
    "itemCount": "int",
    "subtotalAmount": "decimal",
    "lastActivityAt": "datetime",
    "groups": [
      {
        "sellerId": "uuid",
        "sellerName": "string",
        "items": [
          {
            "cartItemId": "uuid",
            "productId": "uuid",
            "skuId": "uuid",
            "productName": "string",
            "skuAttributes": "object",
            "imageUrl": "string",
            "quantity": "int",
            "unitPriceSnapshot": "decimal",
            "currentUnitPrice": "decimal",
            "lineTotal": "decimal",
            "priceChanged": "boolean",
            "stockAvailable": "int",
            "itemStatus": "OK|OUT_OF_STOCK|INACTIVE|PRICE_CHANGED"
          }
        ]
      }
    ],
    "warnings": [
      "CATALOG_UNAVAILABLE|FULFILLMENT_UNAVAILABLE"
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 CART_NOT_FOUND: User cart was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. NULL
2. FUL-04
3. CAT-39
4. CAT-24

---

### [Row 71] PATCH /api/v1/cart/items/{id}
- **Mô tả:** đổi số lượng 1 sản phẩm trong giỏ hàng
- **ID Tham Chiếu:** `CART-03`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"id": "uuid"}

Body:
{"quantity": "int"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "cartItemId": "uuid",
    "quantity": "int",
    "lineTotal": "decimal",
    "cart": {
      "itemCount": "int",
      "subtotalAmount": "decimal"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_QUANTITY: Quantity must be greater than zero.
400 STOCK_INSUFFICIENT: Requested quantity exceeds available stock.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 CART_ITEM_NOT_FOUND: Cart item does not exist in your cart.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CART-03

---

### [Row 72] DELETE /api/v1/cart/items
- **Mô tả:** xóa 1 hoặc nhiều sản phẩm ra khỏi giỏ
- **ID Tham Chiếu:** `CART-04`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "cart": {
      "itemCount": "int",
      "subtotalAmount": "decimal"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Cart item IDs must be provided.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 CART_ITEM_NOT_FOUND: One or more cart items were not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CART-04

---

### [Row 73] DELETE /api/v1/cart/items/all
- **Mô tả:** xóa toàn bộ sản phẩm ra khỏi giỏ
- **ID Tham Chiếu:** `CART-05`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{"all": "boolean"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "removedCount": "int",
    "cart": {
      "itemCount": "int",
      "subtotalAmount": "decimal"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 CART_NOT_FOUND: User cart was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CART-05

---

### [Row 74] GET /api/v1/cart/items/select
- **Mô tả:** buyer select ccasc item bên trong cart và trả ra giá tiền
- **ID Tham Chiếu:** `CART-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"cartItemIds": ["uuid"]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "cartItemId": "uuid",
        "issues": [
          "PRICE_CHANGED|OUT_OF_STOCK|INACTIVE|SELLER_SUSPENDED|QTY_EXCEEDS_STOCK"
        ],
        "currentUnitPrice": "decimal",
        "availableQty": "int"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Cart item IDs are required.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CART-06
2. CAT-24

---

### [Row 75] POST /api/v1/checkout/quote
- **Mô tả:** buyer nhập địa chi, mã giảm giá và coi trước thông tin sau giảm và thông tin tiền ship tính trước
- **ID Tham Chiếu:** `CHK-01 (khung) + FUL-12 + CART-07 + CAT-24`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"cartItemIds": ["uuid"],
"shippingAddress": {
"receiverName": "string",
"street": "string",
"ward": "string",
"district": "string",
"province": "string",
"ghnDistrictId": "int",
"ghnWardCode": "string"
},
"contactPhone": "string",
"paymentMethod": "WALLET|VNPAY",
"carrierCode": "string",
"vouchers": {
"system": "string",
"shops": [{"sellerId": "uuid", "code": "string"}],
"products": [{"skuId": "uuid", "code": "string"}]
}
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "orders": [
      {
        "sellerId": "uuid",
        "items": "array",
        "itemsAmount": "decimal",
        "productDiscountAmount": "decimal",
        "shopDiscountAmount": "decimal",
        "platformMarkupAmount": "decimal",
        "systemDiscountAmount": "decimal",
        "shippingFeeAmount": "decimal",
        "totalAmount": "decimal",
        "shippingOptions": [
          {
            "fee": "decimal",
            "serviceType": "Standard|Express|SameDay",
            "estimatedDeliveryAt": "datetime"
          }
        ],
        "quoteId": "string"
      }
    ],
    "grandTotal": "decimal",
    "appliedVouchers": "array",
    "invalidVouchers": [
      {
        "code": "string",
        "reason": "string"
      }
    ],
    "walletBalance": "decimal",
    "warnings": [
      "SHIPPING_QUOTE_UNAVAILABLE"
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_ADDRESS: Shipping address is incomplete.
400 CART_EMPTY: No valid items selected for checkout.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 VOUCHER_INVALID: One or more vouchers are invalid or expired.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-12
2. CART-07
3. CAT-24

---

### [Row 76] POST /api/v1/orders
- **Mô tả:** tạo order
- **ID Tham Chiếu:** `ORD-01`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "quoteId": "uuid",
  "paymentMethod": "WALLET|VNPAY|COD",
  "shippingAddress": "123 Le Loi, Ben Nghe, Quan 1, TP.HCM",
  "contactPhone": "0901234567",
  "note": "Giao gio hanh chinh"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "orderId": "uuid",
    "orderNo": "ORD-20261026-0001",
    "totalAmount": 480000,
    "status": "PENDING_PAYMENT",
    "paymentDeadlineAt": "2026-10-26T02:00:00Z",
    "paymentUrl": null,
    "subOrderIds": [
      "uuid"
    ],
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Shipping address and phone number are required.
400 QUOTE_EXPIRED: Checkout quote has expired.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
409 IDEMPOTENCY_CONFLICT: Request with this Idempotency-Key is already processed.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CHK-02
2. ORD-19
3. CART-06
4. CART-07
5. ORD-17
6. ORD-18
7. FUL-06

---

### [Row 77] GET /api/v1/order/{orderId}
- **Mô tả:** lấy thôn tin chi tiết của order đó
- **ID Tham Chiếu:** `ORD-02`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "orderId": "uuid",
    "orderNo": "ORD-20261026-0001",
    "buyerId": "uuid",
    "status": "PENDING_PAYMENT",
    "totalAmount": 480000,
    "paymentMethod": "WALLET",
    "shippingAddress": "123 Le Loi, Ben Nghe, Quan 1, TP.HCM",
    "contactPhone": "0901234567",
    "subOrders": [
      {
        "subOrderId": "uuid",
        "subOrderNo": "SUB-20261026-0001",
        "sellerId": "uuid",
        "shopName": "Shop Cong Nghe",
        "status": "PENDING_PAYMENT",
        "itemsAmount": 500000,
        "shippingFee": 30000,
        "discountAmount": 50000,
        "totalAmount": 480000,
        "items": [
          {
            "orderItemId": "uuid",
            "productId": "uuid",
            "skuId": "uuid",
            "productName": "Chuot gaming khong day",
            "skuCode": "MOUSE-WL-01",
            "imageUrl": "https://img.example.com/mouse.png",
            "quantity": 1,
            "unitPrice": 500000,
            "lineTotal": 500000
          }
        ]
      }
    ],
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You do not have permission to view this order.
404 ORDER_NOT_FOUND: Order does not exist or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-02
2. FUL-18
3. CHK-04

---

### [Row 78] GET /api/v1/order (hoặc /api/v1/orders)
- **Mô tả:** Lấy danh sách lịch sử đơn hàng của người mua (Buyer Orders List)
- **ID Tham Chiếu:** `ORD-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": "int (default: 1)",
  "pageSize": "int (default: 20)",
  "status": "string (optional: PendingPayment | Processing | Shipping | Delivered | Completed | Cancelled)",
  "fromDate": "datetime (optional)",
  "toDate": "datetime (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "orderId": "6a1b2c3d-7777-4e8f-9a0b-1c2d3e4f5a07",
        "orderNo": "ORD-20261026-0001",
        "buyerId": "11111111-1111-1111-1111-000000000004",
        "status": "PendingPayment",
        "totalAmount": 480000,
        "paymentMethod": "Wallet",
        "shippingAddress": "123 Le Loi, Ben Nghe, Quan 1, TP.HCM",
        "contactPhone": "0901234567",
        "createdAt": "2026-10-26T00:00:00Z",
        "subOrders": [
          {
            "subOrderId": "b1c2d3e4-8888-4f9a-8b0c-2d3e4f5a6b08",
            "subOrderNo": "SUB-20261026-0001",
            "sellerId": "5e9d1c2b-7f3a-4d8e-9c1b-2a4f6d8e0b12",
            "shopName": "Shop Cong Nghe",
            "status": "PendingPayment",
            "itemsAmount": 500000,
            "shippingFee": 30000,
            "discountAmount": 50000,
            "totalAmount": 480000,
            "items": [
              {
                "orderItemId": "c2d3e4f5-9999-4a0b-9c1d-3e4f5a6b7c09",
                "productId": "9f8e7d6c-2222-4b3c-8d4e-5f6a7b8c9d02",
                "productName": "Chuot gaming khong day",
                "skuId": "7c6b5a49-3333-4c4d-9e5f-6a7b8c9d0e03",
                "skuCode": "MOUSE-WL-01",
                "quantity": 1,
                "unitPrice": 500000,
                "lineTotal": 500000,
                "imageUrl": "https://img.example.com/mouse.png"
              }
            ]
          }
        ]
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 ERR_UNAUTHORIZED: Authentication token is missing or invalid.
403 ERR_FORBIDDEN: User does not have Customer role permission.
```

---

### [Row 79] GET /api/v1/subOrder/{subOrderId}
- **Mô tả:** coi thong tin chi tiết của 1 sub order
- **ID Tham Chiếu:** `ORD-03`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "subOrderId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "orderItemId": "uuid",
        "productId": "uuid",
        "skuId": "uuid",
        "productName": "Chuot gaming khong day",
        "skuCode": "MOUSE-WL-01",
        "quantity": 1,
        "unitPrice": 500000,
        "lineTotal": 500000
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You do not have permission to view this sub-order.
404 SUB_ORDER_NOT_FOUND: Sub-order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-02

---

### [Row 80] POST /api/v1/orders/{orderId}/cancel
- **Mô tả:** cancel cái order đó, chưa chuyển khoản, chưa thanh toán
- **ID Tham Chiếu:** `ORD-04`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid"
}

Body:
{
  "reasonCode": "BUYER_CHANGED_MIND|FOUND_BETTER_PRICE|OTHER",
  "reasonText": "Bought by mistake."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Order has been successfully cancelled.",
  "data": {
    "orderId": "uuid",
    "status": "CANCELLED",
    "cancelledAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ORDER_CANNOT_BE_CANCELLED: Order cannot be cancelled in its current state.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You do not have permission to cancel this order.
404 ORDER_NOT_FOUND: Order does not exist or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CHK-05
2. FUL-10

---

### [Row 81] POST /api/v1/payments/webhook
- **Mô tả:** thành công, chuyển
- **ID Tham Chiếu:** `PAY-01`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "orderId": "uuid",
  "transactionId": "uuid",
  "amount": 480000,
  "status": "SUCCESS|FAILED",
  "paymentMethod": "VNPAY",
  "paidAt": "2026-10-26T00:00:00Z"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Payment webhook processed successfully.",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_SIGNATURE: Invalid webhook signature.
404 ORDER_NOT_FOUND: Order not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. PAY-01: dedupe inbox (message_id), check referenceId tồn tại, check amount = total_amount; lệch amount hoặc order đã CANCELLED/EXPIRED (thanh toán trễ) thì không PAID, phát OrderRefundRequested (thịnh)
2. FUL-09
3. WAL-04
4. PAY-01: group + orders sang PAID qua ORD-18 (CAS row_version), set paid_at, seller_respond_deadline_at = paid_at + 24h, wallet_transaction_id, ghi order_status_history (thịnh)
5. PAY-01: confirm voucher usage RESERVED sang USED (DSC-04) (thịnh)
6. PAY-01: xoá item đã mua khỏi cart theo sku_id, recalc item_count/subtotal_amount (CART), giỏ hết hàng thì carts.status = CHECKED_OUT (thịnh)
7. PAY-01: saga_state = COMPLETED, ghi outbox OrderPaid + CheckoutCompleted; PaymentFailed/Expired thì group về PENDING_PAYMENT (tối đa 3 lần) (thịnh)

---

### [Row 82] BACKGROUND JOB (Job hệ thống tự động quét)
- **Mô tả:** quét thời gian cái qr đó hết hạn chưa, đổi trạng thái những cái liên quan
- **ID Tham Chiếu:** `ORD-JOB-01`

#### Request
*Không có Request Body / Params.*

#### Response
*204 No Content hoặc không có body.*

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CHK-06: quét group PENDING_PAYMENT có payment_deadline_at < now (mỗi 1 phút),
batch 100, SELECT FOR UPDATE SKIP LOCKED (thịnh)
2. CHK-06: hỏi Payment (theo batch referenceIds) có giao dịch đang xử lý hoặc đã SUCCEEDED không; SUCCEEDED thì chuyển sang xử lý PAY-01, Payment không phản hồi thì bỏ qua vòng này (thịnh)
3. CHK-06: huỷ group + orders (CANCELLED/EXPIRED, reason PAYMENT_TIMEOUT, actor SYSTEM) qua ORD-18, ghi history, saga_state = COMPENSATED (thịnh)
4. CHK-06: release voucher (DSC-04), ghi outbox CheckoutExpired + OrderCancelled (Fulfillment release tồn kho qua event) (thịnh)
5. ORD-22: consumer InventoryReservationExpired làm lưới an toàn, dùng chung hàm compensate với CHK-06 và CHK-05 (thịnh)

---

### [Row 83] POST /api/v1/orders/{orderId}/accept
- **Mô tả:** seller chấp nhận cái đơn đó hay ko/ xác nhận
- **ID Tham Chiếu:** `ORD-05`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid"
}

Body:
{
  "subOrderId": "uuid",
  "note": "Order confirmed, preparing items."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "subOrderId": "uuid",
    "status": "SELLER_ACCEPTED",
    "acceptedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_ORDER_STATUS: Order cannot be accepted in its current status.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only the seller of this sub-order can accept it.
404 SUB_ORDER_NOT_FOUND: Sub-order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-04: check seller_id = sub (không thì 404), status = PAID, now <= seller_respond_deadline_at (thịnh)
2. ORD-18: OrderStateMachine.transition(PAID sang CONFIRMED, actor SELLER) CAS row_version, set seller_accepted_at, ghi order_status_history (thịnh)
3. FUL-13
4. check thật sự những sản phẩm trông order thuộc seller đó(quỳnh)
5. ORD-04: ghi outbox OrderSellerAccepted (Fulfillment tạo shipment khi nhận event) (thịnh)

---

### [Row 84] POST /api/v1/orders/{orderId}/reject
- **Mô tả:** seller chấp nhận cái đơn đó hay ko/ từ chối
- **ID Tham Chiếu:** `ORD-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid"
}

Body:
{
  "subOrderId": "uuid",
  "reasonCode": "OUT_OF_STOCK|CANNOT_FULFILL|OTHER",
  "reasonText": "Items are temporarily out of stock."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "subOrderId": "uuid",
    "status": "REJECTED",
    "rejectedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_ORDER_STATUS: Order cannot be rejected in its current status.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only the seller of this sub-order can reject it.
404 SUB_ORDER_NOT_FOUND: Sub-order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-05: check seller_id = sub, status thuộc PAID hoặc CONFIRMED, reasonCode hợp lệ, reasonNote bắt buộc nếu OTHER (thịnh)
2. ORD-06: OrderCancellationSaga TX-1: ORD-18 CAS sang CANCELLED (actor SELLER), lưu order_cancellations (was_paid = true) + order_refunds (REQUESTED) + history (thịnh)
3. FUL-10
4. hoàn tiền lại ví(trí), tạo transaction luôn
5. seller bị trừ uy tín(vinh) - tự động trừ điểm và tra cứu qua REP-03
6. check thật sự những sản phẩm trông order thuộc seller đó(quỳnh)
7. ORD-05: release voucher (DSC-04), ghi outbox OrderCancelled + OrderRefundRequested (hoàn 100% cho buyer) (thịnh)

---

### [Row 85] BACKGROUND JOB (Job hệ thống tự động quét)
- **Mô tả:** sau 24 tiếng seller ko xác nhận đơn hàng thì hủy
- **ID Tham Chiếu:** `ORD-JOB-02`

#### Request
*Không có Request Body / Params.*

#### Response
*204 No Content hoặc không có body.*

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-09: quét order PAID có seller_respond_deadline_at < now (mỗi 1 phút), batch + SKIP LOCKED, lỗi 1 order không chặn cả batch (thịnh)
2. ORD-06: OrderCancellationSaga cho từng order: ORD-18 CAS sang CANCELLED (reason SELLER_NO_RESPONSE, actor SYSTEM), lưu order_cancellations + order_refunds (REQUESTED) + history (thịnh)
3. FUL-10
4. hoàn tiền lại ví(trí), tạo transaction luôn
5. ORD-09: release voucher (DSC-04), ghi outbox OrderCancelled + OrderRefundRequested (thịnh)

---

### [Row 86] GET /api/v1/shipments/{shipmentId}
- **Mô tả:** coi thông tin chi tiết của 1 shipment
- **ID Tham Chiếu:** `FUL-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "shipmentId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "shipmentId": "uuid",
    "orderId": "uuid",
    "subOrderId": "uuid",
    "carrierName": "GHN",
    "trackingNumber": "GHN1029384756",
    "status": "IN_TRANSIT",
    "shippingFee": 30000,
    "codAmount": 0,
    "receiverName": "Nguyen Van A",
    "receiverPhone": "0901234567",
    "receiverAddress": "123 Le Loi, Ben Nghe, Quan 1, TP.HCM",
    "events": [
      {
        "status": "PICKED_UP",
        "location": "Kho Tan Binh",
        "description": "Shipper picked up parcel from seller.",
        "eventAt": "2026-10-26T08:00:00Z"
      },
      {
        "status": "IN_TRANSIT",
        "location": "Kho HN SOC",
        "description": "Parcel is in transit to distribution hub.",
        "eventAt": "2026-10-26T12:00:00Z"
      }
    ],
    "estimatedDeliveryAt": "2026-10-28T18:00:00Z",
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 SHIPMENT_NOT_FOUND: Shipment not found with the provided identifier.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-19

---

### [Row 87] GET /api/v1/shipments/order/{orderId}
- **Mô tả:** coi order đó có mấy shipment
- **ID Tham Chiếu:** `FUL-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "orderId": "uuid",
    "shipments": [
      {
        "shipmentId": "uuid",
        "subOrderId": "uuid",
        "carrierName": "GHN",
        "trackingNumber": "GHN1029384756",
        "status": "IN_TRANSIT",
        "shippingFee": 30000,
        "estimatedDeliveryAt": "2026-10-28T18:00:00Z"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 ORDER_NOT_FOUND: Order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-02: check order thuộc buyer hoặc seller đang đăng nhập (seller chỉ xem order đã paid_at), không thì 404 ORDER_NOT_FOUND (thịnh)
2. FUL-18
3. ORD-02: Fulfillment lỗi thì degrade trả shipment rỗng, không trả 503 (thịnh)

---

### [Row 88] GET /api/v1/seller/shipment
- **Mô tả:** lấy danh sách các đơn ship của selller phải giao
- **ID Tham Chiếu:** `FUL-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": 1,
  "size": 20,
  "status": "READY_TO_SHIP|IN_TRANSIT|DELIVERED"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "shipmentId": "uuid",
        "subOrderId": "uuid",
        "trackingNumber": "GHN1029384756",
        "carrierName": "GHN",
        "status": "READY_TO_SHIP",
        "shippingFee": 30000,
        "receiverName": "Nguyen Van A",
        "receiverPhone": "0901234567",
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only sellers can access shipment management.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-18

---

### [Row 89] GET /api/v1/seller/shipment/search
- **Mô tả:** filter, search shipment của 1 seller, lọc trạng thái
- **ID Tham Chiếu:** `FUL-09`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "keyword": "GHN1029384756",
  "status": "IN_TRANSIT",
  "fromDate": "2026-10-01",
  "toDate": "2026-10-26",
  "page": 1,
  "size": 20
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "shipmentId": "uuid",
        "trackingNumber": "GHN1029384756",
        "subOrderId": "uuid",
        "carrierName": "GHN",
        "status": "IN_TRANSIT",
        "receiverName": "Nguyen Van A",
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Query parameters are invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only sellers can access shipment management.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-18

---

### [Row 90] GET /api/v1/seller/shipment/{shipmentId}
- **Mô tả:** coi chi tiết cái shipment của seller đó
- **ID Tham Chiếu:** `FUL-10`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "shipmentId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "skuId": "uuid",
        "productName": "Chuot gaming khong day",
        "quantity": 1
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You do not have permission to view this shipment.
404 SHIPMENT_NOT_FOUND: Shipment not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-19, FUL-20

---

### [Row 91] PATCH /api/v1/shipments/{shipmentId}/tracking
- **Mô tả:** cập nhập trạng thái cái shipment từ ghn
- **ID Tham Chiếu:** `FUL-11`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "shipmentId": "uuid"
}

Body:
{
  "status": "IN_TRANSIT|OUT_FOR_DELIVERY|DELIVERED",
  "location": "Buu cuc Quan 1",
  "description": "Shipper is delivering parcel to customer.",
  "timestamp": "2026-10-26T14:00:00Z"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "shipmentId": "uuid",
    "trackingNumber": "GHN1029384756",
    "currentStatus": "OUT_FOR_DELIVERY",
    "updatedAt": "2026-10-26T14:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_SHIPMENT_STATUS: Shipment status transition is not permitted.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 SHIPMENT_NOT_FOUND: Shipment not found with the provided identifier.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-17

---

### [Row 92] POST /api/v1/order/{orderId}/products/{productId}/reviews
- **Mô tả:** ddbuyer đánh giá 1 sản phẩm, check sản phẩm đã được mua chưa, đã hoàn thành chưa, có phải người này ko. phải điền order id vào
- **ID Tham Chiếu:** `ORD-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid",
  "productId": "uuid"
}

Body:
{
  "rating": 5,
  "comment": "San pham rat tot, dong goi ky.",
  "images": ["https://img.example.com/review1.png"]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "reviewId": "uuid",
    "orderId": "uuid",
    "productId": "uuid",
    "rating": 5,
    "comment": "San pham rat tot, dong goi ky.",
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_RATING: Rating must be an integer between 1 and 5.
400 ORDER_NOT_COMPLETED: Reviews can only be submitted for completed orders.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
409 REVIEW_ALREADY_EXISTS: You have already reviewed this product.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-23 (mới): GET /internal/v1/orders/{orderId}/rating-eligibility?userId=&productId= , 
check order tồn tại, buyer_id = userId, status = COMPLETED mới được đánh giá (thịnh)
2. check order đó đã đánh giá chưa (quỳnh)
3. lưu đánh giá cho sản phẩm đó èm userid(quỳnh)
4. ORD-23 (mới): check order_items có chứa productId, nhiều quantity trong 1 order_item vẫn tính 1 lần đánh giá, trả {eligible, buyerId, sellerId, status, containsProduct} (thịnh)

---

### [Row 93] POST /api/v1/order/{orderId}/user/{userId}
- **Mô tả:** đánh giá người dùng
- **ID Tham Chiếu:** `ORD-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid",
  "userId": "uuid"
}

Body:
{
  "rating": 5,
  "feedback": "Shop phan hoi nhanh, giao hang dung hen."
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "feedbackId": "uuid",
    "orderId": "uuid",
    "targetUserId": "uuid",
    "rating": 5,
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_RATING: Rating must be an integer between 1 and 5.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 USER_NOT_FOUND: Target user was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-23 (mới): check order tồn tại, status = COMPLETED, buyer_id = người đang đăng nhập (thịnh)
2. check người đó đã đánh giá cái seller đó chưa, cùng 1 order(vinh) - REVIEW-01
3. lưu đánh giá (vinh) - REVIEW-01
4. ORD-23 (mới): check order.seller_id = {userId} (người bị đánh giá), trả {eligible, buyerId, sellerId, status} (thịnh)

---

### [Row 94] PATCH /api/v1/order/{orderId}/products/{productId}/reviews
- **Mô tả:** chỉnh sửa đánh giá sản phẩm
- **ID Tham Chiếu:** `ORD-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid",
  "productId": "uuid"
}

Body:
{
  "rating": 4,
  "comment": "Cap nhat: San pham dung tot sau 1 tuan.",
  "images": ["https://img.example.com/review2.png"]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "reviewId": "uuid",
    "orderId": "uuid",
    "productId": "uuid",
    "rating": 4,
    "comment": "Cap nhat: San pham dung tot sau 1 tuan.",
    "updatedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_RATING: Rating must be an integer between 1 and 5.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You can only edit your own reviews.
404 REVIEW_NOT_FOUND: Review does not exist.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-23 (mới): GET /internal/v1/orders/{orderId}/rating-eligibility?userId=&productId= ,
check order tồn tại, buyer_id = userId, status = COMPLETED mới được đánh giá (thịnh)
2. check order đó đã đánh giá chưa (quỳnh)
3. lưu đánh giá cho sản phẩm đó èm userid(quỳnh)
4. ORD-23 (mới): check order_items có chứa productId, nhiều quantity trong 1 order_item vẫn tính 1 lần đánh giá, trả {eligible, buyerId, sellerId, status, containsProduct} (thịnh)

---

### [Row 95] PATCH /api/v1/order/{orderId}/user/{userId}
- **Mô tả:** chỉnh sửa đánh giá người dùng
- **ID Tham Chiếu:** `ORD-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "orderId": "uuid",
  "userId": "uuid"
}

Body:
{
  "rating": 4,
  "feedback": "Shop da ho tro doi hang nhanh chong."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "feedbackId": "uuid",
    "orderId": "uuid",
    "targetUserId": "uuid",
    "rating": 4,
    "updatedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_RATING: Rating must be an integer between 1 and 5.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You can only edit your own feedback.
404 FEEDBACK_NOT_FOUND: Feedback does not exist.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-23 (mới): check order tồn tại, status = COMPLETED, buyer_id = người đang đăng nhập (thịnh)
2. check người đó đã đánh giá cái seller đó chưa, cùng 1 order(vinh) - REVIEW-01
3. lưu đánh giá (vinh) - REVIEW-01
4. ORD-23 (mới): check order.seller_id = {userId} (người bị đánh giá), trả {eligible, buyerId, sellerId, status} (thịnh)

---

### [Row 97] POST /api/v1/shipment/{shipmentId}/complete
- **Mô tả:** người dùng ấn nút đã nhận được hàng
- **ID Tham Chiếu:** `FUL-13`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "shipmentId": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "shipmentId": "uuid",
    "status": "COMPLETED",
    "completedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_SHIPMENT_STATUS: Shipment can only be completed when delivered.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 SHIPMENT_NOT_FOUND: Shipment not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-23
2. check với ghn nhanh đã đúng chưa
3. ORD-07: check buyer_id = sub, status = DELIVERED, không thì 409 ORDER_STATE_CONFLICT (thịnh)
4. ORD-18: OrderStateMachine.transition(DELIVERED sang COMPLETED, actor BUYER) CAS row_version, set completed_at, ghi order_status_history (thịnh)
5. ORD-07: ghi outbox OrderCompleted (Payment chuyển tiền seller và sinh hoá đơn chạy bất đồng bộ qua event) (thịnh)

---

### [Row 98] POST /api/v1/shipments/webhook
- **Mô tả:** nhận thông tin từ ghn. 
nếu nhận được đơn hàng hoàn thành, thì đổi trạng thái những cái liên quan
- **ID Tham Chiếu:** `FUL-14`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "trackingNumber": "GHN1029384756",
  "status": "DELIVERED",
  "location": "Quan 1, TP.HCM",
  "note": "Delivered to recipient.",
  "timestamp": "2026-10-26T16:00:00Z"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Webhook event processed.",
  "data": {
    "success": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 CARRIER_WEBHOOK_INVALID_SIGNATURE: Invalid webhook signature from shipping provider.
404 SHIPMENT_NOT_FOUND: Tracking number does not match any existing shipment.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. FUL-17
2. ORD-10: dedupe inbox (message_id), check order tồn tại, bỏ qua event cũ hoặc sai thứ tự (thịnh)
3. ORD-10: PickedUp/InTransit sang SHIPPING (set shipped_at); Delivered sang DELIVERED (nếu đang CONFIRMED thì đi 2 bước CONFIRMED > SHIPPING > DELIVERED, ghi 2 dòng history) qua ORD-18 (thịnh)
4. tăng uy tín nếu đơn hàng xong thì tăng uy tín (vinh) - REP-01
5. ORD-10: Returned sang CANCELLED (reason DELIVERY_RETURNED, actor SYSTEM) + tạo order_refunds; Failed giữ SHIPPING và báo Support (thịnh)
6. ORD-10: ghi outbox OrderShipped / OrderDelivered / OrderCancelled (thịnh)

---

### [Row 99] POST /api/v1/subOrder/{subOrderId}/refund
- **Mô tả:** Hoàn tiền sub-order riêng lẻ kèm kiểm tra điều kiện trạng thái
- **ID Tham Chiếu:** `ORD-11`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "subOrderId": "uuid"
}

Body:
{
  "reason": "DEFECTIVE_PRODUCT|MISSING_ITEMS|OTHER",
  "note": "San pham bi loi nguon, yeu cau hoan tien."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "subOrderId": "uuid",
    "refundAmount": 480000,
    "status": "REFUNDED",
    "refundedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_ORDER_STATUS: Refund can only be requested for eligible sub-orders.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 SUB_ORDER_NOT_FOUND: Sub-order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. ORD-13: check status thuộc DELIVERED / COMPLETED / CANCELLED (đã trả tiền, chưa hoàn), Idempotency-Key (ORD-19), chưa có order_refunds REQUESTED/COMPLETED, amount = total_amount (thịnh)
2. FUL-18
3. FUL-24 FUL-25
4. hoàn tiền vào ví người dùng với số tiền tương ứng với cái suborrder đó, lưu transaction ví( trí)
5. ORD-13: INSERT order_refunds (REQUESTED) + history, ghi outbox OrderRefundRequested, trả 202 (thịnh)
6. ORD-14: consumer RefundCompleted/RefundFailed: dedupe inbox, check amount <= total_amount, cập nhật order_refunds (COMPLETED/FAILED) + refund_transaction_id (thịnh)
7. tạo thông báo cho seller và user là đã hoàn tiền thành công vào ví, và đơn hàng đã được hoàn của seller
8. ORD-14: ORD-18 CAS order sang REFUNDED, ghi history, outbox OrderRefundCompleted; RefundFailed thì báo Support đối soát (thịnh)

---

## PHÂN HỆ: F2. QUẢN LÝ SẢN PHẨM.

### [Row 102] GET /api/v1/products
- **Mô tả:** xem toàn bộ các sản phẩm của shop mình
- **ID Tham Chiếu:** `CAT-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT> (optional)"
}

Query:
{
"page": "int",
"pageSize": "int (tối đa 100)",
"keyword": "string",
"categoryId": "uuid",
"status": "DRAFT|ACTIVE|INACTIVE",
"sellerId": "uuid",
"saleType": "REGULAR|AUCTION",
"sortBy": "newest|priceAsc|priceDesc|rating",
"sortDir": "asc|desc"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "brand": "string",
        "saleType": "REGULAR|AUCTION",
        "minPrice": "decimal | null",
        "maxPrice": "decimal | null",
        "primaryImageUrl": "string | null",
        "avgRating": "decimal | null",
        "status": "DRAFT|ACTIVE|INACTIVE",
        "auctionStatus": "DRAFT|SCHEDULED|RUNNING|ENDED|SETTLED|FAILED|CANCELLED | null",
        "isOpen": "boolean | null",
        "isSold": "boolean | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Page < 1, pageSize outside 1..100, invalid sortBy or sortDir, or invalid UUID format.
401 UNAUTHORIZED: Provided token is invalid or has expired.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-06
2. FUL-04

---

### [Row 103] GET /api/v1/product/search
- **Mô tả:** search, filter các sản phẩm của shop mình
- **ID Tham Chiếu:** `CAT-06 + CAT-21`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"keyword": "string",
"categoryId": "uuid",
"minPrice": "decimal",
"maxPrice": "decimal",
"brand": "string",
"saleType": "REGULAR|AUCTION",
"attributes": "string (AttrName=AttrValue)",
"minRating": "decimal (0..5)",
"status": "DRAFT|ACTIVE|INACTIVE",
"sortBy": "newest|priceAsc|priceDesc|rating",
"page": "int",
"pageSize": "int"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "brand": "string",
        "saleType": "REGULAR|AUCTION",
        "minPrice": "decimal | null",
        "maxPrice": "decimal | null",
        "primaryImageUrl": "string | null",
        "avgRating": "decimal | null",
        "status": "DRAFT|ACTIVE|INACTIVE",
        "auctionStatus": "DRAFT|SCHEDULED|RUNNING|ENDED|SETTLED|FAILED|CANCELLED | null",
        "isOpen": "boolean | null",
        "isSold": "boolean | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Minprice > maxprice, rating outside 0..5, invalid sortBy, invalid attribute format, or invalid pagination.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only sellers or administrators can perform this action.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-06, CAT-21
2. FUL-04

---

### [Row 104] GET /api/v1/product/{productId}
- **Mô tả:** coi thông tin detail của 1 sản phẩm
- **ID Tham Chiếu:** `CAT-05`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT> (optional)"
}

Path:
{"productId": "uuid"}

Query:
{"auctionId": "uuid (tùy chọn, dùng khi xem sản phẩm từ trang phiên đấu giá)"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "product": {
      "productId": "uuid",
      "sellerId": "uuid",
      "categoryId": "uuid",
      "name": "string",
      "description": "string",
      "brand": "string",
      "saleType": "REGULAR|AUCTION",
      "status": "DRAFT|ACTIVE|INACTIVE",
      "statusReason": "SELLER_PAUSED|DISCONTINUED|ADMIN_LOCKED|OTHER | null",
      "specifications": "object",
      "publishedAt": "datetime | null"
    },
    "category": {
      "categoryId": "uuid",
      "parentId": "uuid | null",
      "name": "string",
      "description": "string",
      "level": "int (1..3)",
      "sortOrder": "int",
      "isActive": "boolean"
    },
    "variants": [
      {
        "variantId": "uuid",
        "skuCode": "string",
        "name": "string",
        "price": "decimal | null",
        "status": "ACTIVE|INACTIVE",
        "isDefault": "boolean",
        "attributes": [
          {
            "attrName": "string",
            "attrValue": "string"
          }
        ]
      }
    ],
    "images": [
      {
        "imageId": "uuid",
        "url": "string",
        "altText": "string",
        "isActive": "boolean",
        "sortOrder": "int",
        "variantId": "uuid | null"
      }
    ],
    "rating": {
      "avgRating": "decimal | null",
      "reviewCount": "int"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Productid or auctionid is not a valid UUID format.
404 PRODUCT_NOT_FOUND: Product was not found, has been deleted, or is not accessible.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-05
2. FUL-04

---

### [Row 105] POST /api/v1/products
- **Mô tả:** tạo sản phẩm mới, kèm biến thể đầu, KÈM DANH MỤC
- **ID Tham Chiếu:** `CAT-01`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"categoryId": "uuid",
"name": "string",
"description": "string",
"brand": "string",
"specifications": "object",
"variants": [
{
"skuCode": "string",
"name": "string",
"price": "decimal (> 0)",
"currency": "string (mặc định VND)",
"isActive": "boolean (đúng 1 variant = true, là variant mặc định)",
"attributes": [
{
"attrName": "string",
"attrValue": "string"
}
]
}
]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "productId": "uuid",
    "status": "DRAFT",
    "saleType": "REGULAR",
    "variants": [
      {
        "variantId": "uuid",
        "skuCode": "string"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Name is empty, variants missing, price <= 0, no default variant, or duplicate attribute names.
400 CATEGORY_INVALID: Specified categoryid does not exist, is deactivated, or deleted.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 SELLER_NOT_ALLOWED: Account is not an approved seller.
409 SKU_CODE_DUPLICATED: Skucode already exists on an active variant.
503 USER_SERVICE_UNAVAILABLE: Failed to verify seller account with user service.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-01
2. FUL-01

---

### [Row 106] PATCH /api/v1/product/{productId}
- **Mô tả:** seller cập nhật thông tin sản phẩm, danh mục
- **ID Tham Chiếu:** `CAT-02`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Body:
{
"categoryId": "uuid",
"name": "string",
"description": "string",
"brand": "string",
"specifications": "object"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "productId": "uuid",
    "categoryId": "uuid",
    "name": "string",
    "description": "string",
    "brand": "string",
    "saleType": "REGULAR|AUCTION",
    "status": "DRAFT|ACTIVE|INACTIVE",
    "specifications": "object",
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Empty update payload, name is empty, or invalid productid UUID format.
400 CATEGORY_INVALID: New categoryid does not exist, is deactivated, or deleted.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-2
2. FUL-02

---

### [Row 107] DELETE /api/v1/product/{productId}
- **Mô tả:** Xóa sản phẩm
- **ID Tham Chiếu:** `CAT-04`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}
```

#### Response
```
204 No Content
```

#### Error Responses
```
400 VALIDATION_ERROR: Productid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
409 PRODUCT_HAS_ORDER: Product has variants with associated orders, please deactivate instead.
409 PRODUCT_IN_AUCTION: Product is in an active auction and cannot be modified.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-04

---

### [Row 108] POST /api/v1/product/{productId}pics
- **Mô tả:** thêm list ảnh của sản phẩm
- **ID Tham Chiếu:** `CAT-12`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Body:
{
"files": "binary[] (jpg, png, webp)",
"variantId": "uuid (tùy chọn, không gửi = ảnh chung của sản phẩm)",
"altText": "string",
"isActive": "boolean (true = đặt làm ảnh chính)"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "items": [
      {
        "imageId": "uuid",
        "url": "string",
        "isActive": "boolean",
        "sortOrder": "int"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Files list is empty, variantid does not belong to product, or invalid productid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
409 IMAGE_LIMIT_EXCEEDED: Total images for this product cannot exceed 5.
413 FILE_TOO_LARGE: File size exceeds the maximum allowed limit.
415 UNSUPPORTED_MEDIA_TYPE: Unsupported media type, only JPG, PNG, and WEBP formats are allowed.
503 STORAGE_UNAVAILABLE: Failed to upload file to object storage service.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-12

---

### [Row 109] GET /api/v1/product/{productId}pics
- **Mô tả:** xem các ảnh của sản phẩm
- **ID Tham Chiếu:** `CAT-40 (mới)`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT> (optional)"
}

Path:
{"productId": "uuid"}

Query:
{"variantId": "uuid (tùy chọn, lọc ảnh của một variant)"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "imageId": "uuid",
        "url": "string",
        "altText": "string",
        "isActive": "boolean",
        "sortOrder": "int",
        "variantId": "uuid | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Productid or variantid is not a valid UUID, or variant does not belong to product.
404 PRODUCT_NOT_FOUND: Product was not found, has been deleted, or is not active.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-40

---

### [Row 110] DELETE /api/v1/product/{productId}pics
- **Mô tả:** xóa list ảnh sản phẩm
- **ID Tham Chiếu:** `CAT-13`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Query:
{"ids": "uuid[] (ImageId, cách nhau dấu phẩy)"}
```

#### Response
```
204 No Content
```

#### Error Responses
```
400 VALIDATION_ERROR: Image ID list is empty or contains invalid UUIDs.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 IMAGE_NOT_FOUND: One or more images do not exist, were deleted, or do not belong to this product.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-13

---

### [Row 111] GET /api/v1/products/{productId}/totalRating
- **Mô tả:** xem số sao của 1 sản phẩm, trung bình
- **ID Tham Chiếu:** `CAT-31`

#### Request
```
Path:
{"productId": "uuid"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "productId": "uuid",
    "avgRating": "decimal | null",
    "reviewCount": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Productid is not a valid UUID format.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-31

---

### [Row 112] GET /api/v1/products/{productId}/rating
- **Mô tả:** tổng số sao, và đánh giá của các người mua trong product
- **ID Tham Chiếu:** `CAT-30 + CAT-31`

#### Request
```
Path:
{"productId": "uuid"}

Query:
{
"page": "int",
"pageSize": "int",
"rating": "int (1..5, lọc theo số sao)",
"sortBy": "newest|ratingDesc|ratingAsc (đề xuất)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "reviewId": "uuid",
        "rating": "int (1..5)",
        "comment": "string",
        "createdAt": "datetime",
        "reviewerName": "string | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid pagination, rating outside 1..5, invalid sortBy, or invalid productid format.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-30, CAT-31

---

### [Row 113] PATCH /api/v1/product/{productId}/status
- **Mô tả:** Cập nhật trạng thái sản phẩm
- **ID Tham Chiếu:** `CAT-03`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Body:
{
"status": "DRAFT|ACTIVE|INACTIVE",
"statusReason": "SELLER_PAUSED|DISCONTINUED|ADMIN_LOCKED|OTHER (bắt buộc khi INACTIVE, các trạng thái khác để trống)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "productId": "uuid",
    "status": "DRAFT|ACTIVE|INACTIVE",
    "statusReason": "string | null",
    "publishedAt": "datetime | null"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid status, missing statusreason for inactive, or unexpected statusreason.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the product owner, or product is locked by admin (only admin can unlock).
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
409 PRODUCT_NOT_PUBLISHABLE: Cannot activate product without active variants or valid variant prices.
409 PRODUCT_IN_AUCTION: Cannot hide product while it is in an active auction.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-03

---

### [Row 114] POST /api/v1/inventory/stock-in
- **Mô tả:** thêm hàng vào kho, 1 list, kèm số lượng thêm, kèm chủng loại muốn thêm
- **ID Tham Chiếu:** `FUL-02 + CAT-24`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"items": [
{
"skuId": "uuid",
"quantity": "int (> 0)"
}
]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "skuId": "uuid",
        "addedQuantity": "int",
        "stockQuantity": "int"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Items list is empty, quantity <= 0, exceeds 100 SKUs, or duplicate SKUs.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: One or more SKUs do not belong to the calling seller products.
404 SKU_NOT_FOUND: One or more SKUs do not exist or have been deleted.
503 CATALOG_UNAVAILABLE: Fulfillment service failed to communicate with catalog service.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-24
2. FUL-02

---

### [Row 115] POST /api/v1/product/{productId}/variants
- **Mô tả:** Thêm biến thể cho sản phẩm
- **ID Tham Chiếu:** `CAT-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"productId": "uuid"}

Body:
{
"skuCode": "string",
"name": "string",
"price": "decimal (> 0)",
"currency": "string (mặc định VND)",
"attributes": [
{
"attrName": "string",
"attrValue": "string"
}
]
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "variantId": "uuid",
    "skuCode": "string",
    "status": "ACTIVE|INACTIVE"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Price must be > 0, attribute names mismatch with existing variants, or invalid productid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 PRODUCT_NOT_FOUND: Product was not found or has been deleted.
409 SKU_CODE_DUPLICATED: Skucode already exists on an active variant.
409 AUCTION_PRODUCT_SINGLE_VARIANT: Auction products cannot have additional variants.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-07

---

### [Row 116] DELETE /api/v1/variant/{variantId}
- **Mô tả:** xóa 1 biến thể
- **ID Tham Chiếu:** `CAT-11`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"variantId": "uuid"}
```

#### Response
```
204 No Content
```

#### Error Responses
```
400 VALIDATION_ERROR: Variantid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 VARIANT_NOT_FOUND: Variant was not found or has been deleted.
409 LAST_VARIANT: Cannot delete the last remaining variant of a product.
409 VARIANT_HAS_ORDER: Variant has existing orders, please change status to inactive instead.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-11

---

### [Row 117] PATCH /api/v1/variant/{variantId}
- **Mô tả:** Cập nhật thông tin của sản phẩm biến thể
- **ID Tham Chiếu:** `CAT-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"variantId": "uuid"}

Body:
{
"name": "string",
"price": "decimal (> 0 với REGULAR, để trống với AUCTION)",
"currency": "string",
"attributes": [
{
"attrName": "string",
"attrValue": "string"
}
]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "variantId": "uuid",
    "productId": "uuid",
    "skuCode": "string",
    "name": "string",
    "price": "decimal | null",
    "currency": "string",
    "status": "ACTIVE|INACTIVE",
    "attributes": [
      {
        "attrName": "string",
        "attrValue": "string"
      }
    ],
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Empty update payload, invalid price for saletype, or attribute names mismatch.
400 PRICE_REQUIRED: Active regular product must have a valid price.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 VARIANT_NOT_FOUND: Variant was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-08
2. FUL-02

---

### [Row 118] GET /api/v1/variant/{variantId}
- **Mô tả:** xem thông tin chi tiết của 1 biến thể
- **ID Tham Chiếu:** `CAT-42 (mới)`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"variantId": "uuid"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "variantId": "uuid",
    "productId": "uuid",
    "skuCode": "string",
    "name": "string",
    "price": "decimal | null",
    "currency": "string",
    "status": "ACTIVE|INACTIVE",
    "statusReason": "OUT_OF_STOCK|DISCONTINUED|OTHER | null",
    "isDefault": "boolean",
    "hasOrder": "boolean",
    "attributes": [
      {
        "attrName": "string",
        "attrValue": "string"
      }
    ],
    "images": [
      {
        "imageId": "uuid",
        "url": "string",
        "isActive": "boolean"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Variantid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the owner of this product and not an administrator.
404 VARIANT_NOT_FOUND: Variant was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-42
2. FUL-03

---

### [Row 119] POST /api/v1/variant/{variantId}/stock-in
- **Mô tả:** thêm biến thể của sản phảm vào kho
- **ID Tham Chiếu:** `FUL-02 + CAT-23`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"variantId": "uuid"}

Body:
{"quantity": "int (> 0)"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "skuId": "uuid",
    "addedQuantity": "int",
    "stockQuantity": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Quantity must be greater than zero or invalid variantid format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Variant does not belong to a product owned by the calling seller.
404 VARIANT_NOT_FOUND: Variant was not found or has been deleted.
503 CATALOG_UNAVAILABLE: Fulfillment service failed to communicate with catalog service.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-23
2. FUL-02

---

### [Row 120] GET /api/v1/categories
- **Mô tả:** Xem danh sách danh mục
- **ID Tham Chiếu:** `CAT-19`

#### Request
```
Query:
{
"parentId": "uuid (tùy chọn, lấy danh mục con của một danh mục)",
"tree": "boolean (true = dạng cây, false = danh sách phẳng)",
"keyword": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "categoryId": "uuid",
        "name": "string",
        "level": "int (1..3)",
        "sortOrder": "int",
        "children": "[ ... cùng cấu trúc, chỉ có khi Tree = true ]"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid parentid UUID format or tree parameter must be boolean.
404 PARENT_NOT_FOUND: Parent category was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-19

---

### [Row 121] POST /api/v1/categories
- **Mô tả:** Tạo danh mục mới, có thể truyền danh mục cha, nếu ko truyền nó là cha
- **ID Tham Chiếu:** `CAT-15`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"name": "string",
"description": "string",
"parentId": "uuid (không gửi = danh mục gốc)",
"sortOrder": "int"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "categoryId": "uuid",
    "level": "int (1..3)"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Category name is empty or parentid is not a valid UUID.
400 CATEGORY_LEVEL_EXCEEDED: Category hierarchy level exceeds maximum limit of 3.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only administrators can perform this action.
404 PARENT_NOT_FOUND: Parent category was not found or has been deleted.
409 CATEGORY_NAME_DUPLICATED: Category name already exists under the same parent category.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-15

---

### [Row 122] PUT /api/v1/categories/{categoryId}
- **Mô tả:** Cập nhật danh mục
- **ID Tham Chiếu:** `CAT-16`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"categoryId": "uuid"}

Body:
{
"name": "string",
"description": "string",
"parentId": "uuid",
"sortOrder": "int",
"isActive": "boolean"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "categoryId": "uuid",
    "parentId": "uuid | null",
    "name": "string",
    "description": "string",
    "level": "int (1..3)",
    "sortOrder": "int",
    "isActive": "boolean",
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Empty update payload, category name is empty, or invalid category ID.
400 CATEGORY_LEVEL_EXCEEDED: Subtree depth exceeds maximum allowed level of 3 after move.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only administrators can perform this action.
404 CATEGORY_NOT_FOUND: Category was not found or has been deleted.
404 PARENT_NOT_FOUND: New parent category was not found or has been deleted.
409 CATEGORY_NAME_DUPLICATED: Category name already exists under the same parent category.
409 CATEGORY_CYCLE: Cannot move category into its own descendant hierarchy.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-16

---

### [Row 123] DELETE /api/v1/categories
- **Mô tả:** Xóa mềm danh mục
- **ID Tham Chiếu:** `CAT-17`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"categoryId": "uuid"}
```

#### Response
```
204 No Content
```

#### Error Responses
```
400 VALIDATION_ERROR: Categoryid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only administrators can perform this action.
404 CATEGORY_NOT_FOUND: Category was not found or has been deleted.
409 CATEGORY_HAS_PRODUCTS: Category still contains products.
409 CATEGORY_HAS_CHILDREN: Category still contains sub-categories.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-17

---

### [Row 124] GET /api/v1/categories/{categoryId}
- **Mô tả:** xem danh sách các danh mục con và thông tin 1 danh mục cha
- **ID Tham Chiếu:** `CAT-18`

#### Request
```
Path:
{"categoryId": "uuid"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "category": {
      "categoryId": "uuid",
      "parentId": "uuid | null",
      "name": "string",
      "description": "string",
      "level": "int (1..3)",
      "sortOrder": "int",
      "isActive": "boolean"
    },
    "parent": "{ CategoryId, Name, Level } | null (null nếu là danh mục gốc)",
    "children": [
      {
        "categoryId": "uuid",
        "name": "string",
        "level": "int"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Categoryid is not a valid UUID format.
404 CATEGORY_NOT_FOUND: Category was not found or has been deleted.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-18

---

### [Row 125] POST /api/v1/product/auction
- **Mô tả:** thêm sản phẩm đấu giá
- **ID Tham Chiếu:** `CAT-43 (mới)`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
"categoryId": "uuid",
"name": "string",
"description": "string",
"brand": "string",
"specifications": "object",
"variant": {
"skuCode": "string",
"name": "string",
"attributes": [
{
"attrName": "string",
"attrValue": "string"
}
]
}
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "productId": "uuid",
    "status": "DRAFT",
    "saleType": "AUCTION",
    "variant": {
      "variantId": "uuid",
      "skuCode": "string"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Name is empty, variant definition invalid, or unexpected price field for auction product.
400 CATEGORY_INVALID: Specified categoryid does not exist, is deactivated, or deleted.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 SELLER_NOT_ALLOWED: Account is not an approved seller or has insufficient reputation for auctions.
409 SKU_CODE_DUPLICATED: Skucode already exists on an active variant.
503 USER_SERVICE_UNAVAILABLE: Failed to verify seller account with user service.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-43
2. thêm vào kho sản phẩm đấu giá(minh)

---

### [Row 126] GET /api/v1/product/aucction/search
- **Mô tả:** coi đươc các sản phẩm seller đó đã đấu giá, filter
- **ID Tham Chiếu:** `CAT-06 + CAT-21`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"keyword": "string",
"categoryId": "uuid",
"status": "DRAFT|ACTIVE|INACTIVE",
"brand": "string",
"sortBy": "newest|priceAsc|priceDesc|rating",
"sortDir": "asc|desc",
"page": "int",
"pageSize": "int (tối đa 100)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "brand": "string",
        "saleType": "REGULAR|AUCTION",
        "minPrice": "decimal | null",
        "maxPrice": "decimal | null",
        "primaryImageUrl": "string | null",
        "avgRating": "decimal | null",
        "status": "DRAFT|ACTIVE|INACTIVE",
        "auctionStatus": "DRAFT|SCHEDULED|RUNNING|ENDED|SETTLED|FAILED|CANCELLED | null",
        "isOpen": "boolean | null",
        "isSold": "boolean | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid pagination, sortBy parameter, or invalid categoryid format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only sellers or administrators can perform this action.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-06, CAT-21
2. AUC-34

---

### [Row 127] GET /api/v1/product/auctions
- **Mô tả:** coi đươc toàn bộ các sản phẩm seller đó đã đấu giá
- **ID Tham Chiếu:** `CAT-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"status": "DRAFT|ACTIVE|INACTIVE",
"page": "int",
"pageSize": "int (tối đa 100)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "productId": "uuid",
        "name": "string",
        "brand": "string",
        "saleType": "REGULAR|AUCTION",
        "minPrice": "decimal | null",
        "maxPrice": "decimal | null",
        "primaryImageUrl": "string | null",
        "avgRating": "decimal | null",
        "status": "DRAFT|ACTIVE|INACTIVE",
        "auctionStatus": "DRAFT|SCHEDULED|RUNNING|ENDED|SETTLED|FAILED|CANCELLED | null",
        "isOpen": "boolean | null",
        "isSold": "boolean | null"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Page and pageSize parameters must be positive integers.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only sellers or administrators can perform this action.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-06
2. AUC-34

---

### [Row 128] GET /api/v1/product/auction/{auctionId}
- **Mô tả:** coi thông tin chi tiết của sản phẩm đấu giá đó
- **ID Tham Chiếu:** `AUC-35 + CAT-05`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{"auctionId": "uuid"}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auction": {
      "auctionId": "uuid",
      "status": "DRAFT|SCHEDULED|RUNNING|ENDED|SETTLED|FAILED|CANCELLED",
      "startingPriceAmount": "number",
      "bidStepAmount": "number",
      "currentPriceAmount": "number | null",
      "currentLeadingBidderMasked": "string | null",
      "bidCount": "int",
      "startsAt": "datetime",
      "endsAt": "datetime",
      "extensionCount": "int"
    },
    "product": "(như dòng 111, CAT-05: Product, Category, Variants, Images, Rating)"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the seller of this auction and not an administrator.
404 AUCTION_NOT_FOUND: Auction was not found.
404 PRODUCT_NOT_FOUND: Product associated with this auction no longer exists.
503 AUCTION_SERVICE_UNAVAILABLE: Auction service is currently unavailable.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. CAT-05
2. AUC-35

---

## PHÂN HỆ: F3. ĐẤU GIÁ.

### [Row 131] GET /api/v1/auctions
- **Mô tả:** User xem danh sách các phiên đấu giá
- **ID Tham Chiếu:** `AUC-01`

#### Request
```
Query:
{
"page": "int (optional, default 1)",
"pageSize": "int (optional, default 20, tối đa 100)",
"status": "AuctionStatus (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "auctionId": "UUID",
        "productId": "UUID",
        "skuId": "UUID",
        "sellerId": "UUID",
        "productName": "string",
        "primaryImageUrl": "string | null",
        "status": "AuctionStatus",
        "startPriceAmount": "number",
        "currentPriceAmount": "number | null",
        "bidCount": "int",
        "scheduledStartAt": "datetime",
        "scheduledEndAt": "datetime"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid pagination parameters or status is not a valid auctionstatus enum.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-01
2. Catalog trả ra thông tin tên và ảnh chính của nhiều product cùng lúc(Quỳnh)

---

### [Row 132] GET /api/v1/auctions/{auctionId}
- **Mô tả:** Xem chi tiết 1 phiên đấu giá
- **ID Tham Chiếu:** `AUC-02`

#### Request
```
Path:
{ "auctionId": "UUID" }
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "productId": "UUID",
    "skuId": "UUID",
    "sellerId": "UUID",
    "productName": "string",
    "description": "string | null",
    "images": [
      {
        "url": "string",
        "isPrimary": "boolean"
      }
    ],
    "specifications": "object | null",
    "status": "AuctionStatus",
    "startPriceAmount": "number",
    "bidStepAmount": "number",
    "currentPriceAmount": "number | null",
    "bidCount": "int",
    "leadingBidderDisplayName": "string | null",
    "scheduledStartAt": "datetime",
    "originalEndAt": "datetime",
    "scheduledEndAt": "datetime",
    "startedAt": "datetime | null",
    "endedAt": "datetime | null",
    "extensionCount": "int",
    "maxExtensionCount": "int",
    "antiSnipingExtensionMinutes": "int",
    "minReputationToBid": "int",
    "recreatedFromAuctionId": "UUID | null",
    "createdAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format.
404 AUCTION_NOT_FOUND: Auction was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-02
2. CAT-05

---

### [Row 133] POST /api/v1/auctions
- **Mô tả:** Seller tạo phiên đấu giá, chọn 1 sản phẩm có rồi
- **ID Tham Chiếu:** `AUC-10`

#### Request
```
Body:
{
"productId": "UUID",
"skuId": "UUID",
"startPriceAmount": "number",
"bidStepAmount": "number (optional)",
"scheduledStartAt": "datetime",
"scheduledEndAt": "datetime"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "auctionId": "UUID",
    "productId": "UUID",
    "skuId": "UUID",
    "productName": "string",
    "status": "SCHEDULED",
    "startPriceAmount": "number",
    "bidStepAmount": "number",
    "scheduledStartAt": "datetime",
    "scheduledEndAt": "datetime",
    "minReputationToBid": "int",
    "antiSnipingExtensionMinutes": "int",
    "maxExtensionCount": "int",
    "createdAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Start price < 0, bid step <= 0, start time in past, or end time not after start time.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 SELLER_NOT_ELIGIBLE: Seller is not approved or reputation score is below auction threshold (minimum 50).
409 PRODUCT_ALREADY_IN_AUCTION: Product already has an ongoing or scheduled auction.
409 INVENTORY_UNAVAILABLE: Inventory stock hold failed.
422 PRODUCT_NOT_ELIGIBLE: Product is invalid, inactive, does not belong to seller, or SKU mismatch.
422 INVALID_SCHEDULE: Start time cannot exceed 30 days or duration cannot be under 1 hour.
503 USER_SERVICE_UNAVAILABLE: User service is currently unavailable.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-10
2. User trả ra trạng thái duyệt gian hàng, uy tín của Seller(VINH) - GRPC-04
3. CAT-25

---

### [Row 134] PUT /api/v1/auctions/{auctionId}
- **Mô tả:** Seller chỉnh sửa phiên đấu giá(khi chưa bắt đầu)
- **ID Tham Chiếu:** `AUC-11`

#### Request
```
Path:
{ "auctionId": "UUID" }

Body:
{
"startPriceAmount": "number (optional)",
"bidStepAmount": "number (optional)",
"scheduledStartAt": "datetime (optional)",
"scheduledEndAt": "datetime (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "status": "SCHEDULED",
    "startPriceAmount": "number",
    "bidStepAmount": "number",
    "scheduledStartAt": "datetime",
    "scheduledEndAt": "datetime",
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid auctionid, empty payload, or invalid pricing/scheduling values.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the seller of this auction.
404 AUCTION_NOT_FOUND: Auction was not found.
409 AUCTION_NOT_EDITABLE: Auction has already started and cannot be edited.
422 INVALID_SCHEDULE: Start time cannot exceed 30 days or duration cannot be under 1 hour.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-11

---

### [Row 135] POST /api/v1/auctions/{auctionId}/cancel
- **Mô tả:** Seller hủy phiên đấu giá(khi phiên đấu giá chưa bắt đầu)
- **ID Tham Chiếu:** `AUC-12`

#### Request
```
Path:
{ "auctionId": "UUID" }

Body:
{ "reason": "string (optional)" }
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "auctionId": "UUID",
    "fromStatus": "AuctionStatus",
    "status": "CANCELLED",
    "reason": "string | null",
    "cancelledAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format or cancellation reason is empty.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the seller of this auction.
404 AUCTION_NOT_FOUND: Auction was not found.
409 AUCTION_HAS_BIDS: Auction already has bids, only an administrator can cancel it.
409 CONCURRENT_UPDATE: Auction status was modified concurrently by another operation.
422 INVALID_STATE_TRANSITION: Auction status is invalid for cancellation.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-12

---

### [Row 136] POST /api/v1/auctions/{auctionId}/recreate
- **Mô tả:** Tạo lại phiên mới cho sản phẩm ở phiên cũ (đã bị đấu giá thất bại)
- **ID Tham Chiếu:** `AUC-13`

#### Request
```
Path:
{ "auctionId": "UUID (phiên cũ)" }

Body:
{
"startPriceAmount": "number",
"bidStepAmount": "number (optional; bỏ trống thì dùng bước giá mặc định theo config)",
"scheduledStartAt": "datetime",
"scheduledEndAt": "datetime"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "auctionId": "UUID (phiên mới)",
    "recreatedFromAuctionId": "UUID",
    "productId": "UUID",
    "skuId": "UUID",
    "status": "SCHEDULED",
    "startPriceAmount": "number",
    "bidStepAmount": "number",
    "scheduledStartAt": "datetime",
    "scheduledEndAt": "datetime",
    "createdAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid auctionid, start price < 0, bid step <= 0, start time in past, or invalid schedule.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Previous auction does not belong to the calling seller.
403 SELLER_NOT_ELIGIBLE: Reputation score is below the auction hosting threshold (minimum 50).
404 AUCTION_NOT_FOUND: Previous auction was not found.
409 PRODUCT_ALREADY_IN_AUCTION: Product already has an ongoing or scheduled auction.
409 INVENTORY_UNAVAILABLE: Inventory stock hold failed.
422 INVALID_RECREATE_SOURCE: Previous auction is not in failed status.
422 PRODUCT_NOT_ELIGIBLE: Product is no longer eligible.
422 INVALID_SCHEDULE: Start time cannot exceed 30 days or duration cannot be under 1 hour.
503 USER_SERVICE_UNAVAILABLE: User service is currently unavailable.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. User trả ra trạng thái duyệt gian hàng, uy tín của Seller(VINH) - GRPC-04
2. User trả ra trạng thái duyệt gian hàng, uy tín của Seller(VINH) - USER-08
3. Catalog trả ra product của phiên cũ còn ACTIVE và còn thuộc Seller(QUỲNH) CAT-25

---

### [Row 137] GET /api/v1/auctions/{auctionId}/status-history
- **Mô tả:** Nhật kí đổi trạng thái của từng auction
- **ID Tham Chiếu:** `AUC-18`

#### Request
```
Path:
{ "auctionId": "UUID" }
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "UUID",
        "fromStatus": "AuctionStatus | null",
        "toStatus": "AuctionStatus",
        "reason": "string | null",
        "changedBy": "UUID | null",
        "changedAt": "datetime"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format or invalid pagination parameters.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Administrator or staff privileges are required.
404 AUCTION_NOT_FOUND: Auction was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-18

---

### [Row 138] GET /api/v1/seller/auctions
- **Mô tả:** Seller xem toàn bộ phiên đấu giá của mình
- **ID Tham Chiếu:** `AUC-14`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (optional, default 1)",
"pageSize": "int (optional, default 20, tối đa 100)",
"status": "AuctionStatus (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "auctionId": "UUID",
        "productId": "UUID",
        "skuId": "UUID",
        "productName": "string",
        "primaryImageUrl": "string | null",
        "status": "AuctionStatus",
        "startPriceAmount": "number",
        "currentPriceAmount": "number | null",
        "bidCount": "int",
        "scheduledStartAt": "datetime",
        "scheduledEndAt": "datetime",
        "createdAt": "datetime"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid pagination parameters or status is not a valid auctionstatus enum.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only registered sellers can perform this action.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-14
2. Catalog trả ra tên và ảnh chính của nhiều product cùng lúc(Quỳnh) CAT-41

---

### [Row 139] POST /api/v1/admin/auctions/{auctionId}/force-cancel
- **Mô tả:** Admin cưỡng chế hủy phiên đấu giá khi có bất thường
- **ID Tham Chiếu:** `AUC-15`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "auctionId": "UUID" }

Body:
{ "reason": "string (bắt buộc)" }
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "auctionId": "UUID",
    "fromStatus": "AuctionStatus",
    "status": "CANCELLED",
    "reason": "string",
    "cancelledBy": "UUID",
    "cancelledAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format or cancellation reason is empty.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Administrator privileges required, support staff cannot perform this action.
404 AUCTION_NOT_FOUND: Auction was not found.
409 CONCURRENT_UPDATE: Auction status was modified concurrently by another operation.
422 INVALID_STATE_TRANSITION: Auction status is invalid for cancellation (ended auctions cannot be cancelled).
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-15
2. Notification cho tất cả người đã bid và seller kèm lý do(Duy)

---

### [Row 140] GET /api/v1/admin/auctions/{auctionId}/saga
- **Mô tả:** Admin theo dõi xem phiên đang ở bước nào của luồng đơn hàng(sau khi chốt người thắng -> commerce)
- **ID Tham Chiếu:** `AUC-19`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "auctionId": "UUID" }
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "sagaType": "string",
    "currentState": "string",
    "stateData": "object",
    "createdAt": "datetime",
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Administrator or staff privileges are required.
404 AUCTION_NOT_FOUND: Auction was not found or has no winning saga.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-19

---

### [Row 141] GET /api/v1/admin/auction-configs
- **Mô tả:** Xem các luật đang hiệu lực (tham chiếu tới userSerive để lấy field uy tín seller,buyer, số lần gia hạn,gia hạn bao nhiêu phút,.....)
- **ID Tham Chiếu:** `AUC-16`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "configKey": "string",
        "configValue": "json",
        "description": "string | null",
        "version": "int",
        "updatedBy": "UUID | null",
        "updatedAt": "datetime"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only administrators can perform this action.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-16
2. User trả ra các cấu hình uy tín (ngưỡng tổ chức đấu giá, ngưỡng đặt giá, mức phạt)(VINH) - ADMIN-12

---

### [Row 142] PUT /api/v1/admin/auction-configs/{key}
- **Mô tả:** Cập nhật cấu hình đấu giá(chỉ ảnh hưởng auction tương lai )
- **ID Tham Chiếu:** `AUC-17`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{ "key": "string" }

Body:
{
"configValue": "json",
"description": "string (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "configKey": "string",
    "configValue": "json",
    "description": "string | null",
    "version": "int",
    "isActive": "boolean",
    "updatedBy": "UUID | null",
    "createdAt": "datetime",
    "updatedAt": "datetime"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Configuration value type is invalid or out of allowed bounds for this key.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only administrators can perform this action.
404 NOT_FOUND: Configuration key was not found.
409 CONFLICT: Update conflict, only one active record is permitted per key.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-17

---

### [Row 143] POST /api/v1/auctions/{auctionId}/bids
- **Mô tả:** Buyer đặt giá cho một phiên đấu giá
- **ID Tham Chiếu:** `AUC-07`

#### Request
```
Path:
{ "auctionId": "UUID" }

Body:
{ "amount": "number" }
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "bidId": "UUID",
    "auctionId": "UUID",
    "bidSeq": "int",
    "amount": "number",
    "placedAt": "datetime",
    "currentPriceAmount": "number",
    "bidCount": "int",
    "scheduledEndAt": "datetime",
    "extensionCount": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid auctionid, missing Idempotency-Key or If-Match header, or invalid bid amount.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 BIDDER_NOT_ELIGIBLE: Reputation score is below bidding threshold (minimum 40) or account is locked.
404 AUCTION_NOT_FOUND: Auction was not found.
409 CONCURRENT_UPDATE: Concurrent update detected (rowversion mismatch or earlier bid).
410 AUCTION_ENDED: Auction has ended or scheduled end time has passed.
422 AUCTION_NOT_RUNNING: Auction is not in running status.
422 BID_TOO_LOW: Bid amount is below the minimum required bid increment.
422 IDEMPOTENCY_KEY_REUSED: Idempotency key reused with different request payload.
503 USER_SERVICE_UNAVAILABLE: User service is currently unavailable.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-07
2. User trả ra điểm uy tín, trạng thái account Buyer và ngưỡng đặt giá để check đạt(VINH) - GRPC-01
3. Notification cho người bị vượt giá,seller khi có bid mới(Duy)

---

### [Row 144] GET /api/v1/auctions/{auctionId}/bids
- **Mô tả:** User xem được lịch sử đặt giá của phiên đang tham gia
- **ID Tham Chiếu:** `AUC-03`

#### Request
```
Path:
{ "auctionId": "UUID" }

Query:
{
"page": "int (optional, default 1)",
"pageSize": "int (optional, default 20, tối đa 100)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "bidId": "UUID",
        "sequenceNo": "int",
        "bidderId": "UUID",
        "bidderDisplayName": "string",
        "amount": "number",
        "placedAt": "datetime",
        "isOutbid": "boolean",
        "isWinning": "boolean",
        "isInvalidated": "boolean"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format or invalid pagination parameters.
404 AUCTION_NOT_FOUND: Auction was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-03
2. Trả ra tên của danh sách bider(Vinh) GRPC-02

---

### [Row 145] GET /api/v1/me/bids
- **Mô tả:** Buyer coi được các phiên đấu giá mà bản thân đã từng tham gia
- **ID Tham Chiếu:** `AUC-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
"page": "int (optional, default 1)",
"pageSize": "int (optional, default 20, tối đa 100)",
"status": "AuctionStatus (optional)"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "auctionId": "UUID",
        "productId": "UUID",
        "productName": "string",
        "primaryImageUrl": "string | null",
        "auctionStatus": "AuctionStatus",
        "myHighestBidAmount": "number",
        "currentPriceAmount": "number | null",
        "isLeading": "boolean",
        "endsAt": "datetime",
        "lastBidAt": "datetime"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Invalid pagination parameters or status is not a valid auctionstatus enum.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-08
2. Catalog trả ra tên và ảnh chính của nhiều product cùng lúc(Quỳnh) CAT-41

---

### [Row 146] GET /api/v1/auctions/{auctionId}/result
- **Mô tả:** Xem kết quả của phiên đấu giá
- **ID Tham Chiếu:** `AUC-09`

#### Request
```
Path:
{ "auctionId": "UUID" }
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "status": "AuctionStatus",
    "hasWinner": "boolean",
    "winnerId": "UUID | null",
    "winnerDisplayName": "string | null",
    "sellerId": "UUID",
    "winningBidId": "UUID | null",
    "finalPriceAmount": "number | null",
    "determinedAt": "datetime",
    "orderId": "UUID | null",
    "paymentDeadlineAt": "datetime | null",
    "paidAt": "datetime | null"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: You are not the winner, seller, or administrator of this auction.
404 AUCTION_NOT_FOUND: Auction was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-09

---

### [Row 147] GRPC Auction.CheckPaymentDeadline
- **Mô tả:** Commerce gọi khi người thắng nhập địa chỉ hoặc thanh toán, để kiểm tra còn trong hạn thanh toán không
- **ID Tham Chiếu:** `AUC-20`

#### Request
```
Body:
{
"auctionId": "UUID"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "status": "",
    "paymentDeadlineAt": "datetime | null",
    "isWithinDeadline": "boolean"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-20

---

### [Row 148] GET /internal/v1/auctions/status?productId={productId}
- **Mô tả:** Catalog lấy trạng thái phiên đấu giá gần nhất của một sản phẩm, để ẩn sản phẩm khỏi kho ảo khi đã bán xong
- **ID Tham Chiếu:** `AUC-34`

#### Request
```
Path:
{
  "productId": "uuid"
}

Query:
{ "productId": "UUID" }
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "productId": "UUID",
    "auctionId": "UUID | null",
    "status": "",
    "isOpen": "boolean",
    "isSold": "boolean"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Productid is not a valid UUID format.
403 FORBIDDEN: Only internal catalog service can call this endpoint.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-34

---

### [Row 149] GET /internal/v1/auctions/{auctionId}/summary
- **Mô tả:** Catalog lấy thông tin chi tiết một phiên: người đang trả giá cao nhất, giá khởi điểm, giá hiện tại, bước giá
- **ID Tham Chiếu:** `AUC-35`

#### Request
```
Path:
{
  "auctionId": "uuid"
}

Query:
{
"auctionId": "UUID"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "auctionId": "UUID",
    "productId": "UUID",
    "sellerId": "UUID",
    "status": "AuctionStatus",
    "startingPriceAmount": "number",
    "bidStepAmount": "number",
    "currentPriceAmount": "number | null",
    "currentLeadingBidderId": "UUID | null",
    "currentLeadingBidderMasked": "string | null",
    "bidCount": "int",
    "startsAt": "datetime",
    "endsAt": "datetime",
    "extensionCount": "int"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VALIDATION_ERROR: Auctionid is not a valid UUID format.
403 FORBIDDEN: Only internal catalog service can call this endpoint.
404 AUCTION_NOT_FOUND: Auction was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. AUC-35

---

## PHÂN HỆ: F5. THANH TOÁN.

### [Row 178] GET /api/v1/wallets/me
- **Mô tả:** Lấy thông tin ví và số dư khả dụng/bị khóa của cá nhân
- **ID Tham Chiếu:** `WAL-02`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "walletId": "uuid",
    "userId": "uuid",
    "balance": 1500000.0,
    "lockedBalance": 200000.0,
    "availableBalance": 1300000.0,
    "currency": "VND",
    "status": "ACTIVE",
    "updatedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 WALLET_LOCKED: Wallet account is locked or frozen.
404 WALLET_NOT_FOUND: Wallet was not found for the user.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-02

---

### [Row 179] POST /api/v1/wallets/topups/vnpay
- **Mô tả:** Tạo yêu cầu nạp tiền vào ví qua cổng VNPay và lấy URL thanh toán
- **ID Tham Chiếu:** `WAL-03`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "amount": 500000,
  "bankCode": "NCB",
  "returnUrl": "https://shop.example.com/wallet/callback"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "topupId": "uuid",
    "paymentUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=50000000...",
    "txnRef": "TOPUP-20261026-1234",
    "expiresIn": 900
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_AMOUNT: Deposit amount must be at least 10,000 VND.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 WALLET_LOCKED: Wallet account is locked or frozen.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-03

---

### [Row 180] POST /api/v1/wallets/vnpay/ipn
- **Mô tả:** Webhook nhận kết quả IPN từ VNPay (Nạp ví hoặc Thanh toán đơn trực tiếp)
- **ID Tham Chiếu:** `WAL-04`

#### Request
```
Body:
{
  "vnp_TmnCode": "NEXUS001",
  "vnp_Amount": "50000000",
  "vnp_BankCode": "NCB",
  "vnp_BankTranNo": "VNP14072026",
  "vnp_CardType": "ATM",
  "vnp_OrderInfo": "Topup wallet",
  "vnp_PayDate": "20261026103000",
  "vnp_ResponseCode": "00",
  "vnp_TransactionNo": "14072026",
  "vnp_TransactionStatus": "00",
  "vnp_TxnRef": "TOPUP-20261026-1234",
  "vnp_SecureHash": "abcdef123456..."
}
```

#### Response
```
200 OK:
{
  "RspCode": "00",
  "Message": "Confirm success."
}
```

#### Error Responses
```
200 VNPAY_INVALID_CHECKSUM: Invalid checksum hash.
200 VNPAY_ORDER_NOT_FOUND: Order not found.
200 VNPAY_ORDER_ALREADY_CONFIRMED: Order already confirmed.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-04

---

### [Row 181] POST /api/v1/wallets/checkout/direct
- **Mô tả:** Tạo phiên thanh toán trực tiếp qua cổng VNPay cho đơn hàng (bỏ qua số dư ví)
- **ID Tham Chiếu:** `WAL-05B`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "orderId": "uuid",
  "amount": 480000,
  "gateway": "VNPAY",
  "bankCode": "NCB",
  "returnUrl": "https://shop.example.com/checkout/callback"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "transactionId": "uuid",
    "orderId": "uuid",
    "amount": 480000,
    "paymentUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=48000000...",
    "status": "PENDING",
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_AMOUNT: Payment amount must be greater than zero.
400 ORDER_ALREADY_PAID: Order has already been paid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 ORDER_NOT_FOUND: Order was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-05B

---

### [Row 182] POST /api/v1/wallets/withdrawals
- **Mô tả:** Người bán (Seller) tạo yêu cầu rút tiền từ ví về tài khoản ngân hàng
- **ID Tham Chiếu:** `WAL-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "amount": 200000,
  "bankCode": "MB",
  "accountNumber": "0987654321",
  "accountHolderName": "NGUYEN VAN A"
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "withdrawalId": "uuid",
    "amount": 200000,
    "fee": 0,
    "status": "PENDING",
    "requestedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INSUFFICIENT_BALANCE: Insufficient available balance for withdrawal.
400 MIN_WITHDRAWAL_LIMIT: Minimum withdrawal amount is 50,000 VND.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: Only verified sellers can request withdrawals.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-07

---

### [Row 183] PATCH /api/v1/admin/wallets/withdrawals/{id}
- **Mô tả:** Quản trị viên duyệt hoặc từ chối yêu cầu rút tiền của Seller
- **ID Tham Chiếu:** `WAL-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "id": "uuid"
}

Body:
{
  "action": "APPROVE|REJECT",
  "adminNote": "Approved by finance department."
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "withdrawalId": "uuid",
    "status": "APPROVED",
    "processedAt": "2026-10-26T00:00:00Z",
    "transactionId": "uuid"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 ALREADY_PROCESSED: Withdrawal request has already been processed.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
404 WITHDRAWAL_NOT_FOUND: Withdrawal request was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-08

---

### [Row 184] GET /api/v1/wallets/transactions
- **Mô tả:** Tra cứu lịch sử biến động sổ cái (wallet_transactions) cá nhân
- **ID Tham Chiếu:** `WAL-09`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "page": 1,
  "limit": 20,
  "type": "ALL|DEPOSIT|WITHDRAWAL|PAYMENT|REFUND",
  "fromDate": "2026-10-01",
  "toDate": "2026-10-26"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "type": "PAYMENT",
        "amount": -480000,
        "balanceAfter": 1020000,
        "status": "SUCCESS",
        "note": "Payment for order #SUB-01",
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Page or limit is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-09

---

### [Row 185] POST /api/v1/admin/wallets/{walletId}/adjustments
- **Mô tả:** Admin điều chỉnh số dư ví thủ công (Cộng/Trừ tiền kèm kiểm toán)
- **ID Tham Chiếu:** `WAL-10`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "walletId": "uuid"
}

Body:
{
  "amount": 50000,
  "reason": "Compensation for dispute resolution #SUB-01",
  "adjustmentType": "CREDIT|DEBIT"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "adjustmentId": "uuid",
    "walletId": "uuid",
    "amount": 50000,
    "balanceAfter": 1070000,
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_AMOUNT: Adjustment amount must be greater than zero.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
404 WALLET_NOT_FOUND: Target wallet was not found.
```

#### Workflow / Phối hợp nghiệp vụ liên Service
1. WAL-10

---

### [Row 186] POST /api/v1/notifications/devices
- **Mô tả:** Đăng ký hoặc làm mới FCM/APNs device token để nhận push notification
- **ID Tham Chiếu:** `NOTI-01`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "platform": "WEB|IOS|ANDROID",
  "token": "string"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "deviceId": "uuid",
    "userId": "uuid",
    "platform": "WEB|IOS|ANDROID",
    "isActive": true,
    "lastSeenAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_DEVICE_TOKEN: Platform or token is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

---

### [Row 187] DELETE /api/v1/notifications/devices
- **Mô tả:** Thu hồi hoặc vô hiệu hóa device token khi logout hoặc tắt quyền push
- **ID Tham Chiếu:** `NOTI-02`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "token": "string"
}
```

#### Response
```
204 No Content
```

#### Error Responses
```
400 VAL_INVALID_TOKEN: Token is missing or invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
404 DEVICE_TOKEN_NOT_FOUND: Device token was not found for this user.
```

---

### [Row 188] GET /api/v1/notifications/preferences
- **Mô tả:** Lấy danh sách cấu hình bật/tắt nhận thông báo của người dùng
- **ID Tham Chiếu:** `NOTI-03`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "notificationType": "ORDER_PAID|AUCTION_OUTBID|PROMOTION",
        "channelCode": "EMAIL|PUSH|IN_APP",
        "isEnabled": true,
        "isMandatory": true
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

---

### [Row 189] PUT /api/v1/notifications/preferences
- **Mô tả:** Cập nhật tùy chọn bật/tắt nhận thông báo theo loại sự kiện và kênh gửi
- **ID Tham Chiếu:** `NOTI-04`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "preferences": [
    {
      "notificationType": "ORDER_PAID",
      "channelCode": "EMAIL",
      "isEnabled": true
    }
  ]
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "updatedCount": 1,
    "preferences": [
      {
        "notificationType": "ORDER_PAID",
        "channelCode": "EMAIL",
        "isEnabled": true
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_PREFERENCES: Notification type or channel code is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
422 MANDATORY_NOTIFICATION_CANNOT_DISABLE: Mandatory security or transaction notification cannot be disabled.
```

---

### [Row 190] GET /api/v1/notifications/me
- **Mô tả:** Lấy danh sách lịch sử thông báo in-app (quả chuông) kèm số lượng chưa đọc
- **ID Tham Chiếu:** `NOTI-05`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "isRead": false,
  "notificationType": "ORDER_PAID",
  "pageIndex": 1,
  "pageSize": 20
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "notificationType": "ORDER_PAID",
        "title": "Don hang #SUB-01 da duoc thanh toan",
        "body": "Don hang tri gia 480.000d da duoc thanh toan thanh cong.",
        "payload": {
          "orderId": "uuid",
          "subOrderId": "uuid"
        },
        "isRead": false,
        "readAt": null,
        "createdAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 10,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_PAGE: PageIndex or pageSize is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

---

### [Row 191] PATCH /api/v1/notifications/me/read
- **Mô tả:** Đánh dấu một số hoặc toàn bộ thông báo trong hộp thư là đã đọc
- **ID Tham Chiếu:** `NOTI-06`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "notificationIds": ["uuid"],
  "markAll": false
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "updatedCount": 1,
    "unreadCount": 2
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_INPUT: Notification IDs list is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
```

---

### [Row 192] GET /api/v1/admin/notifications/channels/{code}
- **Mô tả:** Admin xem trạng thái và cấu hình kênh gửi thông báo
- **ID Tham Chiếu:** `NOTI-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "code": "EMAIL|PUSH|IN_APP|SMS"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": "uuid",
    "code": "EMAIL",
    "name": "Email Service",
    "provider": "SMTP",
    "config": {
      "host": "smtp.example.com",
      "port": 587,
      "fromAddress": "noreply@shop.example.com"
    },
    "isEnabled": true,
    "updatedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
404 CHANNEL_NOT_FOUND: Notification channel code was not found.
```

---

### [Row 193] PUT /api/v1/admin/notifications/channels/{code}
- **Mô tả:** Admin cập nhật cấu hình và bật/tắt kênh gửi thông báo
- **ID Tham Chiếu:** `NOTI-07`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "code": "EMAIL|PUSH|IN_APP|SMS"
}

Body:
{
  "name": "Email Service",
  "provider": "SMTP",
  "config": {
    "host": "smtp.example.com",
    "port": 587,
    "fromAddress": "noreply@shop.example.com"
  },
  "isEnabled": true
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": "uuid",
    "code": "EMAIL",
    "name": "Email Service",
    "provider": "SMTP",
    "config": {
      "host": "smtp.example.com",
      "port": 587,
      "fromAddress": "noreply@shop.example.com"
    },
    "isEnabled": true,
    "updatedAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 SECRET_IN_CONFIG_FORBIDDEN: Secrets like passwords or API keys are not allowed in config body.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
404 CHANNEL_NOT_FOUND: Notification channel code was not found.
```

---

### [Row 194] GET /api/v1/admin/notifications/templates
- **Mô tả:** Admin xem danh sách mẫu thông báo (Template Engine)
- **ID Tham Chiếu:** `NOTI-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "channelCode": "EMAIL",
  "notificationType": "ORDER_PAID"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "code": "ORDER_PAID_EMAIL",
        "notificationType": "ORDER_PAID",
        "channelCode": "EMAIL",
        "subjectTemplate": "Don hang {{orderNo}} thanh toan thanh cong",
        "bodyTemplate": "<p>Xin chao {{userName}}, don hang {{orderNo}} da duoc xac nhan.</p>",
        "isMandatory": true,
        "locale": "vi-VN",
        "isActive": true
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
```

---

### [Row 195] POST /api/v1/admin/notifications/templates
- **Mô tả:** Admin tạo mẫu nội dung thông báo mới
- **ID Tham Chiếu:** `NOTI-08`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Body:
{
  "code": "ORDER_PAID_EMAIL",
  "notificationType": "ORDER_PAID",
  "channelCode": "EMAIL",
  "subjectTemplate": "Don hang {{orderNo}} thanh toan thanh cong",
  "bodyTemplate": "<p>Xin chao {{userName}}, don hang {{orderNo}} da duoc xac nhan.</p>",
  "isMandatory": true,
  "locale": "vi-VN",
  "isActive": true
}
```

#### Response
```
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "id": "uuid",
    "code": "ORDER_PAID_EMAIL",
    "notificationType": "ORDER_PAID",
    "channelCode": "EMAIL",
    "isMandatory": true,
    "locale": "vi-VN",
    "isActive": true
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 INVALID_TEMPLATE_SYNTAX: Template syntax is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
409 TEMPLATE_CODE_DUPLICATED: Template code and locale already exist.
```

---

### [Row 196] GET /api/v1/admin/notifications
- **Mô tả:** Admin/Staff tra cứu lịch sử gửi thông báo và nhật ký lỗi delivery
- **ID Tham Chiếu:** `NOTI-09`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "userId": "uuid",
  "notificationType": "ORDER_PAID",
  "status": "COMPLETED|PENDING|FAILED",
  "pageIndex": 1,
  "pageSize": 20
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "notificationId": "uuid",
        "userId": "uuid",
        "notificationType": "ORDER_PAID",
        "status": "COMPLETED",
        "createdAt": "2026-10-26T00:00:00Z",
        "deliveries": [
          {
            "deliveryId": "uuid",
            "channelCode": "EMAIL",
            "destination": "u***@gmail.com",
            "status": "SENT",
            "attemptCount": 1
          }
        ]
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_FILTER: Query filter parameters are invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
```

---

### [Row 197] GET /api/v1/admin/event-logs
- **Mô tả:** Admin tra cứu nhật ký sự kiện kỹ thuật message bus (90 ngày)
- **ID Tham Chiếu:** `NOTI-13`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "sourceService": "Commerce|Auction|User|Wallet",
  "eventType": "OrderPaid",
  "pageIndex": 1,
  "pageSize": 20
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "uuid",
        "eventId": "uuid",
        "eventType": "OrderPaid",
        "sourceService": "Commerce",
        "actorId": "uuid",
        "occurredAt": "2026-10-26T00:00:00Z"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
400 VAL_INVALID_FILTER: Query date range or filter is invalid.
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
```

---

### [Row 198] GET /api/v1/admin/event-logs/{id}
- **Mô tả:** Admin xem chi tiết toàn bộ raw JSON payload của sự kiện kỹ thuật
- **ID Tham Chiếu:** `NOTI-14`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Path:
{
  "id": "uuid"
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "id": "uuid",
    "eventId": "uuid",
    "eventType": "OrderPaid",
    "sourceService": "Commerce",
    "actorId": "uuid",
    "payload": {
      "orderId": "uuid",
      "totalAmount": 480000
    },
    "occurredAt": "2026-10-26T00:00:00Z",
    "createdAt": "2026-10-26T00:00:00Z"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
404 EVENT_LOG_NOT_FOUND: Event log entry was not found.
```

---

### [Row 199] GET /api/v1/admin/health/broker
- **Mô tả:** Admin theo dõi trạng thái sức khỏe, latency và queue depth RabbitMQ
- **ID Tham Chiếu:** `NOTI-16`

#### Request
```
Header:
{
  "Authorization": "Bearer <JWT>"
}

Query:
{
  "limit": 50
}
```

#### Response
```
200 OK:
{
  "success": true,
  "statusCode": 200,
  "data": {
    "currentStatus": "UP",
    "lastCheckedAt": "2026-10-26T00:00:00Z",
    "latestLatencyMs": 5,
    "latestQueueDepth": 0,
    "history": [
      {
        "id": "uuid",
        "brokerName": "rabbitmq",
        "status": "UP",
        "latencyMs": 5,
        "queueDepth": 0,
        "checkedAt": "2026-10-26T00:00:00Z"
      }
    ]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

#### Error Responses
```
401 UNAUTHORIZED: Token is missing, expired, or invalid.
403 FORBIDDEN: User does not have administrative permissions.
```

---
