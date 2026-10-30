# 🔐 ACTIVE APIS: AUTH CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế 100% qua Unit/Integration tests trên Gateway cổng `8080`, UserService `8001`, và NotificationService `8007`)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/AuthController.cs`  
> **Backend Service:** `User.Api` (Cổng `8001`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`usermanagement_db`), Redis (`nexus-shared-redis:6379`), Notification Service REST Client (`POST /api/v1/notifications/email/otp`)  
> **Cấu trúc thư mục Controller:** Các đặc tả chi tiết của từng API được lưu trữ độc lập tại [`docs/api/active/auth/`](./auth/).

---

## 📌 BẢNG DANH MỤC 10 ENDPOINT AUTHENTICATION HOÀN TẤT (10/10 COMPLETED)

| STT | Phương thức | Endpoint Gateway | RBAC | Tài liệu chi tiết | Trạng thái |
|:---:|:---:|:---|:---:|:---|:---:|
| 1 | `POST` | `/api/v1/auth/register` | `AllowAnonymous` | [`01_REGISTER.md`](./auth/01_REGISTER.md) | ✅ COMPLETED |
| 2 | `POST` | `/api/v1/auth/otp/verify` | `AllowAnonymous` | [`02_VERIFY_OTP.md`](./auth/02_VERIFY_OTP.md) | ✅ COMPLETED |
| 3 | `POST` | `/api/v1/auth/otp/resend` | `AllowAnonymous` | [`03_RESEND_OTP.md`](./auth/03_RESEND_OTP.md) | ✅ COMPLETED |
| 4 | `POST` | `/api/v1/auth/login` | `AllowAnonymous` | [`04_LOGIN.md`](./auth/04_LOGIN.md) | ✅ COMPLETED |
| 5 | `POST` | `/api/v1/auth/refresh` | `AllowAnonymous` | [`05_REFRESH.md`](./auth/05_REFRESH.md) | ✅ COMPLETED |
| 6 | `POST` | `/api/v1/auth/password/forgot` | `AllowAnonymous` | [`06_FORGOT_PASSWORD.md`](./auth/06_FORGOT_PASSWORD.md) | ✅ COMPLETED |
| 7 | `PUT` | `/api/v1/auth/password/reset` | `AllowAnonymous` | [`07_RESET_PASSWORD.md`](./auth/07_RESET_PASSWORD.md) | ✅ COMPLETED |
| 8 | `PATCH` | `/api/v1/auth/password` | `Authenticated` | [`08_CHANGE_PASSWORD.md`](./auth/08_CHANGE_PASSWORD.md) | ✅ COMPLETED |
| 9 | `POST` | `/api/v1/auth/logout` | `Authenticated` | [`09_LOGOUT.md`](./auth/09_LOGOUT.md) | ✅ COMPLETED |
| 10 | `POST` | `/api/v1/auth/logout-all` | `Authenticated` | [`10_LOGOUT_ALL.md`](./auth/10_LOGOUT_ALL.md) | ✅ COMPLETED |

---

## 1. ĐĂNG KÝ TÀI KHOẢN MỚI (REGISTER)

- **Endpoint Gateway:** `POST /api/v1/auth/register`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/register`
- **Tài liệu chi tiết:** Xem [`01_REGISTER.md`](./auth/01_REGISTER.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 2. XÁC THỰC MÃ OTP (VERIFY OTP)

- **Endpoint Gateway:** `POST /api/v1/auth/otp/verify`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/otp/verify`
- **Tài liệu chi tiết:** Xem [`02_VERIFY_OTP.md`](./auth/02_VERIFY_OTP.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 3. GỬI LẠI MÃ OTP (RESEND OTP)

- **Endpoint Gateway:** `POST /api/v1/auth/otp/resend`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/otp/resend`
- **Tài liệu chi tiết:** Xem [`03_RESEND_OTP.md`](./auth/03_RESEND_OTP.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 4. ĐĂNG NHẬP (LOGIN)

- **Endpoint Gateway:** `POST /api/v1/auth/login`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/login`
- **Tài liệu chi tiết:** Xem [`04_LOGIN.md`](./auth/04_LOGIN.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 5. LÀM MỚI ACCESS TOKEN (REFRESH TOKEN ROTATION)

- **Endpoint Gateway:** `POST /api/v1/auth/refresh`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/refresh`
- **Tài liệu chi tiết:** Xem [`05_REFRESH.md`](./auth/05_REFRESH.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 6. YÊU CẦU QUÊN MẬT KHẨU (FORGOT PASSWORD)

- **Endpoint Gateway:** `POST /api/v1/auth/password/forgot`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/password/forgot`
- **Tài liệu chi tiết:** Xem [`06_FORGOT_PASSWORD.md`](./auth/06_FORGOT_PASSWORD.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 7. ĐẶT LẠI MẬT KHẨU BẰNG OTP (RESET PASSWORD)

- **Endpoint Gateway:** `PUT /api/v1/auth/password/reset`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `PUT http://user-service:8001/api/v1/auth/password/reset`
- **Tài liệu chi tiết:** Xem [`07_RESET_PASSWORD.md`](./auth/07_RESET_PASSWORD.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 8. ĐỔI MẬT KHẨU (CHANGE PASSWORD)

- **Endpoint Gateway:** `PATCH /api/v1/auth/password`
- **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)
- **Forward downstream:** `PATCH http://user-service:8001/api/v1/auth/password`
- **Tài liệu chi tiết:** Xem [`08_CHANGE_PASSWORD.md`](./auth/08_CHANGE_PASSWORD.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 9. ĐĂNG XUẤT PHIÊN ĐƠN LẺ (LOGOUT)

- **Endpoint Gateway:** `POST /api/v1/auth/logout`
- **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/logout`
- **Tài liệu chi tiết:** Xem [`09_LOGOUT.md`](./auth/09_LOGOUT.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`

---

## 10. ĐĂNG XUẤT TOÀN BỘ PHIÊN (LOGOUT ALL SESSIONS)

- **Endpoint Gateway:** `POST /api/v1/auth/logout-all`
- **Quyền truy cập:** Bắt buộc đăng nhập (`GatewayPolicies.Authenticated`)
- **Forward downstream:** `POST http://user-service:8001/api/v1/auth/logout-all`
- **Tài liệu chi tiết:** Xem [`10_LOGOUT_ALL.md`](./auth/10_LOGOUT_ALL.md)
- **Checklist trạng thái:** `[x]` Triển khai đầy đủ | `[x]` Tests Passed | `[x]` Gateway Aligned | `✅ COMPLETED`
