# BẢNG ĐỐI CHIẾU ROUTE API GATEWAY CHO FRONTEND
## (FRONTEND API ENDPOINT MAPPING)

> **Trạng thái triển khai (2026-10-31):** ✅ Đã đối chiếu với `src/Services/Gateway/Gateway/appsettings.json` và controller hiện tại của 9 service. Các endpoint từng được ghi trong tài liệu cũ nhưng không tồn tại đã bị xóa.
> **Nguồn sự thật:** `src/Services/Gateway/Gateway/appsettings.json`, `src/Services/*/*.Api/Controllers/**`, `docs/api/README.md`.
> **Cập nhật lần cuối:** 2026-10-31.

Frontend chỉ gọi một địa chỉ duy nhất: **`http://localhost:8080`** (hoặc domain Gateway khi deploy). Không gọi trực tiếp `8001`-`8009`.

---

## 1. QUY ƯỚC CHUNG

- Route bộ sưu tập dùng danh từ số nhiều: `/api/v1/users`, `/api/v1/products`, `/api/v1/orders`, `/api/v1/wallets`.
- Ngoại lệ contextual singleton: `/api/v1/me` và `/api/v1/auth`.
- Response bọc trong `ApiResponse<T>` hoặc `ApiResponse<PagedData<T>>`.
- Xóa hoặc thao tác không có body trả `204 NoContent`.
- JSON dùng `camelCase`; enum trả chuỗi `PascalCase`, ví dụ `"PendingPayment"`, `"Active"`, `"Delivered"`.
- Lỗi dùng `errorCode` `SCREAMING_SNAKE_CASE` và `message` tiếng Anh sentence case.

Chi tiết envelope và mã lỗi xem tại [docs/api/README.md](api/README.md).

---

## 2. BẢNG ROUTE THEO MODULE

Bảng dưới đây là các tiền tố Gateway đang chuyển tiếp thật. Route con cụ thể xem trong file API tương ứng.

| Module | Tiền tố qua Gateway | Service đích | Tài liệu chi tiết |
|:---|:---|:---|:---|
| Xác thực | `/api/v1/auth/**` | User `8001` | [A_Active/User](api/A_Active/User/) |
| Hồ sơ cá nhân | `/api/v1/me/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Người dùng | `/api/v1/users/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Người bán | `/api/v1/sellers/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Quản trị người dùng | `/api/v1/admin/users/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Vai trò và quyền | `/api/v1/admin/roles/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Hồ sơ đăng ký Seller | `/api/v1/admin/seller-registrations/**` | User `8001` | [B_none/User](api/B_none/User/) |
| Sản phẩm | `/api/v1/products/**` | Catalog `8002` | [B_none/Catalog](api/B_none/Catalog/) |
| Danh mục | `/api/v1/categories/**` | Catalog `8002` | [B_none/Catalog](api/B_none/Catalog/) |
| Giỏ hàng | `/api/v1/carts/**` | Commerce `8003` | [B_none/Commerce](api/B_none/Commerce/) |
| Đơn hàng | `/api/v1/orders/**` | Commerce `8003` | [B_none/Commerce](api/B_none/Commerce/) |
| Nhật ký | `/api/v1/logs/**` | Log `8004` | [B_none/Log](api/B_none/Log/) |
| Đấu giá | `/api/v1/auctions/**` | Auction `8005` | [B_none/Auction](api/B_none/Auction/) |
| Vận đơn | `/api/v1/shipments/**` | Fulfillment `8006` | [B_none/Fulfillment](api/B_none/Fulfillment/) |
| Kho bãi | `/api/v1/warehouses/**` | Fulfillment `8006` | [B_none/Fulfillment](api/B_none/Fulfillment/) |
| Tồn kho | `/api/v1/inventories/**` | Fulfillment `8006` | [B_none/Fulfillment](api/B_none/Fulfillment/) |
| Thông báo | `/api/v1/notifications/**` | Notification `8007` | [B_none/Notification](api/B_none/Notification/) |
| Quản trị thông báo | `/api/v1/admin/notifications/**` | Notification `8007` | [B_none/Notification](api/B_none/Notification/) |
| Ví và giao dịch | `/api/v1/wallets/**` | Wallet `8008` | [B_none/Wallet](api/B_none/Wallet/) |
| Quản trị ví | `/api/v1/admin/wallets/**` | Wallet `8008` | [B_none/Wallet](api/B_none/Wallet/) |
| Giám sát sức khỏe | `/api/v1/healthcheck/**` | CheckHeal `8009` | [B_none/CheckHeal](api/B_none/CheckHeal/) |

---

## 3. NHỮNG ROUTE FRONTEND CẦN LƯU Ý

### 3.1. Route chưa được Gateway chuyển tiếp

Các route dưới đây có trong controller nhưng chưa có trong `appsettings.json` của Gateway, nên gọi qua `8080` sẽ nhận `404`:

- `/api/v1/checkouts/**` (Commerce)
- `/api/v1/sub-orders/**` (Commerce)
- `/api/v1/variants/**` (Catalog)
- `/api/v1/admin/auctions/**` (Auction)
- `/api/v1/bids/**` (Auction)
- `/api/v1/reviews/**` (User)
- `/api/v1/reports/**` (User)

Frontend cần các route này thì phải bổ sung route YARP trước.

### 3.2. Route liên service đi qua Gateway

Trong giai đoạn Internal API tạm khóa, một số lời gọi service-to-service dùng route công khai và đi qua Gateway như API thường:

- `POST /api/v1/notifications/email/otp`
- `POST /api/v1/notifications/email/send`
- `POST /api/v1/wallets/checkout/direct`
- `POST /api/v1/inventories/initialize`
- `GET /api/v1/inventories/{skuId}`
- `POST /api/v1/logs/batch`

Đây là các route nội bộ. Frontend không nên gọi. Chi tiết xem [SERVICE_CONNECTIVITY_GUIDE.md](SERVICE_CONNECTIVITY_GUIDE.md).

---

## 4. MÃ LỖI FRONTEND CẦN XỬ LÝ

| HTTP | errorCode | Khi nào |
|:---:|:---|:---|
| `400` | `VAL_INVALID_INPUT` | Dữ liệu body sai định dạng hoặc thiếu trường bắt buộc |
| `400` | `VAL_INVALID_ARGUMENT` | Query hoặc route parameter không parse được |
| `401` | `UNAUTHORIZED` | Thiếu hoặc sai JWT |
| `403` | `FORBIDDEN` | Không có quyền trên tài nguyên |
| `403` | `FORBIDDEN_HEADER_SPOOFING` | Client tự gửi header `x-user-*` hoặc `x-internal-service-key` |
| `404` | `*_NOT_FOUND` | Không tìm thấy tài nguyên, hoặc Gateway thiếu route |
| `409` | `*_ALREADY_EXISTS` | Xung đột trạng thái hoặc dữ liệu trùng |
| `429` | `RATE_LIMIT_EXCEEDED` | Vượt giới hạn OTP hoặc đăng nhập |
| `500` | `INTERNAL_SERVER_ERROR` | Lỗi không mong đợi |
| `503` | `SERVICE_UNAVAILABLE` | Downstream không sẵn sàng |

---

## 5. ĐỒNG BỘ KHI THÊM ENDPOINT

1. Thêm action vào controller của service, đúng route số nhiều.
2. Thêm route YARP vào `src/Services/Gateway/Gateway/appsettings.json`.
3. Viết hoặc cập nhật file trong `docs/api/B_none/{Service}/`.
4. Cập nhật bảng module trong tài liệu này nếu có tiền tố mới.
5. Cập nhật `docs/SERVICE_CONNECTIVITY_GUIDE.md` nếu có lời gọi liên service mới.
