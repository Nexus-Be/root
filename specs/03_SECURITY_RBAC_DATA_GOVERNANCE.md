# 03 — BẢO MẬT, PHÂN QUYỀN RBAC & QUY CHUẨN DỮ LIỆU (SECURITY & DATA GOVERNANCE)

Tài liệu này xác định ma trận phân quyền, vòng đời token JWT, cơ chế 2 trạng thái Gateway và quy chuẩn định dạng phản hồi chuẩn quốc tế.

---

## 1. MA TRẬN PHÂN QUYỀN VAI TRÒ (RBAC MATRIX)

Hệ thống Nexus phân cấp 5 cấp độ vai trò (Roles) có tính kế thừa quyền hạn:

| Vai Trò | Cấp Độ | Quyền Hạn Nghiệp Vụ | Ví Dụ Endpoints Được Phép |
|:---|:---:|:---|:---|
| **anonymous** | 0 | Người dùng vãng lai chưa đăng nhập. | Đăng ký, đăng nhập, xem danh mục, tìm sản phẩm, xem phòng đấu giá công khai. |
| **buyer** (hoặc `authenticated`) | 1 | Khách hàng đã đăng nhập có tài khoản hợp lệ. | Xem/sửa hồ sơ cá nhân (`/users/me`), giỏ hàng (`/commerce/cart`), đặt đơn hàng, ví tiền, đặt giá đấu giá (`/bids`). |
| **seller** | 2 | Người bán hàng đã được quản trị viên phê duyệt (Kế thừa quyền `buyer`). | Đăng bán sản phẩm, cập nhật giá, điều chỉnh kho ảo (`/seller/inventory`), tạo phiên đấu giá, xem đơn hàng của shop (`/seller/orders`). |
| **staff** | 3 | Nhân viên vận hành sàn (Kế thừa quyền `buyer`). | Xem danh sách người dùng (`/admin/users`), xét duyệt hồ sơ seller (`/admin/sellers/{id}/approve`), xem toàn bộ đơn sàn (`/admin/orders`), xem nhật ký hệ thống (`/log/logs`). |
| **admin** | 4 | Quản trị viên hệ thống (Kế thừa quyền `staff`, `seller`, `buyer`). | Tạo tài khoản admin/staff, gán role người dùng (`/admin/users/{id}/roles`), cấu hình danh mục sản phẩm, bật/tắt sự kiện ghi log. |
| **gateway-admin** | 5 | Quản trị hạ tầng kỹ thuật Gateway (Chặn hoàn toàn bypass). | Xem/đổi trạng thái Mock/Real các service (`/gateway/modes`), bật/tắt mode auth (`/gateway/mode`), nạp lại mock definitions (`/mock-engine/reload`). |

---

## 2. VÒNG ĐỜI VÀ TIÊU CHUẨN TOKEN JWT

- **Thuật toán ký**: HMAC-SHA256 với Secret Key tối thiểu 32 ký tự (hoặc RSA-256).
- **Claims Bắt Buộc Trong Token**:
  - `sub`: UUID của người dùng (Subject).
  - `role`: Danh sách vai trò (`buyer`, `seller`, `staff`, `admin`).
  - `iss`: Issuer (`http://localhost:8001` - UserService).
  - `aud`: Audience (`shoppingcart-api`).
  - `exp`: Thời gian hết hạn (Epoch seconds).
- **Chuyển tiếp qua gRPC**: Khi Client gửi `Authorization: Bearer <token>` lên Gateway, Gateway tự động forward nguyên vẹn header này vào Metadata của gRPC Call sang backend.

---

## 3. CƠ CHẾ 2 TRẠNG THÁI GATEWAY (GATEWAY STATE)

Gateway hỗ trợ chuyển đổi runtime giữa 2 trạng thái hoạt động:

1. **Trạng Thái Standard (`GatewayMode: "Standard"` — Mặc định)**:
   - Áp dụng kiểm tra JWT và ma trận RBAC nghiêm ngặt.
   - Chưa đăng nhập (không token) $\rightarrow$ Trả mã `401 Unauthorized`.
   - Token không đủ quyền $\rightarrow$ Trả mã `403 Forbidden`.

2. **Trạng Thái Mock Bypass (`GatewayMode: "Bypass"` — Dành riêng cho Development)**:
   - Dành riêng cho Frontend kiểm thử giao diện độc lập với mock data.
   - Khi bật `Bypass`, Client gọi các mock API không cần token, Gateway tự động cấp danh tính giả lập tương ứng để vượt qua bộ lọc quyền hạn.
   - **Ngoại lệ an toàn**: Các endpoint quản trị hạ tầng Gateway (`/api/v1/gateway/...` và `/api/v1/mock-engine/...`) được gắn thuộc tính `[DisableMockAuthorizationBypass]`, bắt buộc phải có token thật với role `gateway-admin`, tuyệt đối không cho phép bypass.

---

## 4. QUY CHUẨN ĐỊNH DẠNG PHẢN HỒI (API RESPONSE ENVELOPES)

Mọi phản hồi từ hệ sinh thái Nexus bắt buộc tuân theo định dạng chuẩn đã quy định trong `input.md`:

### A. Phản Hồi Thành Công Đơn Lẻ (`ApiResponse<T>`)
```json
{
  "success": true,
  "statusCode": 200,
  "message": "User retrieved successfully.",
  "data": {
    "id": "usr_9981",
    "fullName": "Nguyen Van A",
    "email": "vana@example.com",
    "status": "Active"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```

### B. Phản Hồi Thành Công Phân Trang (`ApiResponse<PagedData<T>>`)
```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      { "id": "101", "name": "Bàn phím cơ", "price": "1250000.00" }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 245,
      "totalPages": 13,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```

### C. Phản Hồi Lỗi Chuẩn IETF RFC 9110 / RFC 6585 (`ApiErrorResponse`)
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Please refer to the errors property for additional details.",
  "errors": {
    "Email": ["The Email field is not a valid e-mail address."]
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-07T08:25:00Z"
}
```
*(Tuyệt đối không trả về status 200 kèm `isError: true` theo kiểu anti-pattern; status code trong envelope phải trùng với mã HTTP Status của response).*
