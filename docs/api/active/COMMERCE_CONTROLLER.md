# 🛒 ACTIVE APIS: COMMERCE CONTROLLERS (CARTS & ORDERS)

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua REST Controller & Gateway cổng `8080` ngày 2026-10-30)  
> **Gateway Controllers:** `Nexus.Gateway/Controllers/CartController.cs`, `Nexus.Gateway/Controllers/OrdersController.cs`  
> **Backend Service:** `Commerce.Api` (Cổng `8003`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`commerce_db`), Typed REST HTTP Clients

---

## 1. LẤY GIỎ HÀNG CỦA NGƯỜI DÙNG (GET MY CART)

- **Endpoint Gateway:** `GET /api/v1/cart`
- **Quyền truy cập:** Khách hàng (`[Authorize(GatewayPolicies.Customer)]`)
- **Forward downstream:** `GET http://commerce-service:8003/api/v1/carts/me`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `x-user-id` | Header | Có | GUID người mua hàng |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_USER_ID` | "Invalid user identifier." | Header `x-user-id` rỗng hoặc sai format |
| `401` | `UNAUTHORIZED` | "Authentication is required to view cart." | Thiếu Bearer Token |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`CartService.cs`) tự khởi tạo giỏ hàng nếu chưa có.
- [x] Thin Controller (`CartsController.cs`) ghép cặp 1-to-1.
- [x] Gateway routing & Seed fixture (`Seeds/commerce/cart.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. DANH SÁCH ĐƠN HÀNG (LIST ORDERS)

- **Endpoint Gateway:** `GET /api/v1/orders`
- **Quyền truy cập:** Khách hàng (`[Authorize(GatewayPolicies.Customer)]`)
- **Forward downstream:** `GET http://commerce-service:8003/api/v1/orders`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |
| `status` | Query | Không | Lọc trạng thái đơn hàng (PENDING, PAID, SHIPPING, COMPLETED, CANCELLED) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be at least 1 and page size between 1 and 100." | Tham số phân trang không hợp lệ |
| `400` | `ORDER_INVALID_STATUS` | "Provided order status is not valid." | Trạng thái lọc không nằm trong enum |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`OrderService.cs`) query danh sách đơn hàng của user.
- [x] Thin Controller (`OrdersController.cs`) ghép cặp 1-to-1, route chính thức duy nhất `/api/v1/orders`.
- [x] Gateway routing & Seed fixture (`Seeds/commerce/order-list.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
