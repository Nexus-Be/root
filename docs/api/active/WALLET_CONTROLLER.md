# 💳 ACTIVE APIS: WALLET CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế 100% qua Unit/Integration tests trên Gateway cổng `8080` và WalletService `8008`)  
> **Gateway Controller:** `src/Services/ApiGateway/Nexus.Gateway/Controllers/WalletController.cs`  
> **Backend Service:** `Wallet.Api` (Cổng `8008`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`wallet_db`), JWT Bearer Security, User Balance Ledger, Idempotency-Key support

---

## 1. XEM THÔNG TIN VÍ CỦA TÔI (GET MY WALLET)

- **Endpoint Gateway:** `GET /api/v1/wallets/me`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `GET http://wallet-service:8008/api/v1/wallets/me`
- **Luồng xử lý:**
  1. Client gửi request kèm Bearer JWT Token.
  2. Gateway thẩm định chữ ký JWT, trích xuất `sub` (UserId) và gán header `x-user-id: {sub}`.
  3. `Wallet.Api` nhận header `x-user-id`, truy vấn sổ cái số dư ví của người dùng trong PostgreSQL (`wallet_db`). Nếu người dùng mới chưa có ví, service tự động khởi tạo ví mặc định với số dư 0 VND.
  4. Trả về thông tin số dư khả dụng (`balance`), số dư đóng băng (`lockedBalance`), loại tiền tệ (`currency`) và trạng thái ví (`status`).

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `x-user-id` | Header | Có | Định dạng GUID hợp lệ từ Gateway |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_USER_ID` | "Missing or empty x-user-id header." | Header `x-user-id` rỗng hoặc sai format |
| `401` | `UNAUTHORIZED` | "Authentication is required to access wallet." | Không có Bearer token |

### Response (200 OK)
```json
{
  "statusCode": 200,
  "success": true,
  "data": {
    "id": "73c683ee-c02a-43d9-95e2-2591605ec686",
    "userId": "501d11e7-c3c4-44a3-8c07-6ef749d9dc86",
    "balance": 1500000.00,
    "lockedBalance": 200000.00,
    "currency": "VND",
    "status": "ACTIVE",
    "createdAt": "2026-10-30T06:00:00Z"
  }
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WalletService.cs`) tự khởi tạo ví nếu chưa có.
- [x] Thin Controller (`WalletsController.cs`) ghép cặp 1-to-1, route `/api/v1/wallets/me`.
- [x] Unit test (`WalletRequestValidatorTests.cs`) pass 100%.
- [x] Gateway routing & Seed fixture (`Seeds/wallet/wallet-me.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. NẠP TIỀN VÀO VÍ QUA VNPAY (TOPUP VNPAY)

- **Endpoint Gateway:** `POST /api/v1/wallets/topups/vnpay`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Customer)]`)
- **Forward downstream:** `POST http://wallet-service:8008/api/v1/wallets/topups/vnpay`
- **Luồng xử lý:**
  1. Client gửi request nạp tiền kèm số tiền `amount`.
  2. `Wallet.Api` kiểm tra số tiền tối thiểu (10,000 VND) và tối đa (100,000,000 VND).
  3. Tạo giao dịch tạm thời trong bảng `WalletTopups` với trạng thái `PENDING`.
  4. Sinh URL thanh toán VNPay kèm mã giao dịch duy nhất.

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `amount` | `decimal` | Có | Từ 10,000 VND đến 100,000,000 VND |
| `bankCode` | `string` | Không | Mã ngân hàng VNPay (ví dụ: "NCB", "VNPAYQR") |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_AMOUNT` | "Topup amount must be between 10,000 and 100,000,000 VND." | Số tiền ngoài khoảng quy định |
| `404` | `WALLET_NOT_FOUND` | "Wallet account not found for user." | Không tìm thấy ví tương ứng |

### Response (201 Created)
```json
{
  "statusCode": 201,
  "success": true,
  "message": "Topup request created successfully.",
  "data": {
    "topupId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "amount": 50000.00,
    "paymentUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?...",
    "status": "PENDING"
  }
}
```

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WalletService.cs`) sinh URL thanh toán & lưu topup record.
- [x] Thin Controller (`WalletsController.cs`) ghép cặp 1-to-1.
- [x] Unit test (`WalletRequestValidatorTests.TopupVnPayRequest_AcceptsValidAmount`) pass 100%.
- [x] Gateway routing & Seed fixture (`Seeds/wallet/topup-vnpay.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 3. RÚT TIỀN VỀ NGÂN HÀNG (REQUEST WITHDRAWAL)

- **Endpoint Gateway:** `POST /api/v1/wallets/withdrawals`
- **Quyền truy cập:** Người bán (`[Authorize(GatewayPolicies.Seller)]`)
- **Forward downstream:** `POST http://wallet-service:8008/api/v1/wallets/withdrawals`

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `amount` | `decimal` | Có | Tối thiểu 50,000 VND |
| `bankCode` | `string` | Có | Mã ngân hàng hợp lệ |
| `accountNumber` | `string` | Có | Số tài khoản ngân hàng thụ hưởng |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `INSUFFICIENT_BALANCE` | "Insufficient balance to complete the withdrawal." | Số dư khả dụng không đủ |
| `400` | `VAL_INVALID_AMOUNT` | "Withdrawal amount must be at least 50,000 VND." | Số tiền rút dưới hạn mức tối thiểu |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WalletService.cs`) kiểm tra số dư và đóng băng tiền rút.
- [x] Thin Controller (`WalletsController.cs`) ghép cặp 1-to-1.
- [x] Unit test (`WalletRequestValidatorTests.WithdrawalRequest_AcceptsValidData`) pass 100%.
- [x] Gateway routing & Seed fixture đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 4. CHUYỂN TIỀN NỘI BỘ (TRANSFER)

- **Endpoint Gateway:** `POST /api/v1/wallets/transfer`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `POST http://wallet-service:8008/api/v1/wallets/transfer`

### Quy chuẩn Validation (Input Rules)
| Trường | Kiểu | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `receiverUserId` | `Guid` | Có | ID người nhận tiền |
| `amount` | `decimal` | Có | Tối thiểu 1,000 VND |
| `note` | `string` | Không | Nội dung chuyển tiền (tối đa 255 ký tự) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `INSUFFICIENT_BALANCE` | "Insufficient balance to transfer." | Số dư người gửi không đủ |
| `400` | `VAL_INVALID_RECIPIENT` | "Cannot transfer funds to yourself." | Người nhận trùng người gửi |
| `404` | `RECEIVER_WALLET_NOT_FOUND` | "Receiver wallet account not found." | Không tìm thấy ví người nhận |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WalletService.cs`) xử lý transaction atomic trừ tiền bên gửi, cộng bên nhận.
- [x] Thin Controller (`WalletsController.cs`) ghép cặp 1-to-1.
- [x] Unit test pass 100%.
- [x] Gateway routing & Seed fixture đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 5. TRA CỨU BIẾN ĐỘNG SỐ DƯ (TRANSACTION HISTORY)

- **Endpoint Gateway:** `GET /api/v1/wallets/transactions`
- **Quyền truy cập:** Yêu cầu đăng nhập (`[Authorize(GatewayPolicies.Authenticated)]`)
- **Forward downstream:** `GET http://wallet-service:8008/api/v1/wallets/transactions`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |
| `transactionType` | Query | Không | Lọc loại giao dịch (DEPOSIT, WITHDRAW, TRANSFER, PAYMENT) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be >= 1 and pageSize between 1 and 100." | Tham số phân trang không hợp lệ |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WalletService.cs`) query phân trang trên `WalletTransactions`.
- [x] Thin Controller (`WalletsController.cs`) ghép cặp 1-to-1.
- [x] Unit test pass 100%.
- [x] Gateway routing & Seed fixture đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
