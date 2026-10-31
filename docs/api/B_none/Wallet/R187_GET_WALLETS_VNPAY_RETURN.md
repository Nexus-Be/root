# [GET] /api/v1/wallets/vnpay/return

> **Phân hệ thụ lý:** `WalletService`  
> **Tên tính năng:** `VnPay`  
> **Mã tham chiếu Excel:** `N/A (không có trong Excel mapping; bổ sung sau)`  
> **Trạng thái tài liệu:** `B_none (Chờ nghiệm thu của Sếp)`  
> **Trạng thái triển khai:** `✅ COMPLETED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tiếp nhận callback trình duyệt của VNPay sau khi người dùng hoàn tất hoặc hủy thanh toán nạp ví. Endpoint xác thực chữ ký checksum và trả về kết quả đọc được cho Frontend để hiển thị màn hình kết quả. Endpoint này **không** cộng tiền vào ví; việc ghi có do IPN (`POST /api/v1/wallets/vnpay/ipn`) đảm nhiệm.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/wallets/vnpay/return`
* **Đường dẫn gốc trong Excel:** `/api/v1/wallets/vnpay/return` (Đường dẫn tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` (controller không gắn `[RequireRole]` vì VNPay redirect trình duyệt kèm query string)
* **Yêu cầu Idempotency:** Không áp dụng (thao tác chỉ đọc, không thay đổi trạng thái)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Wallet/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `wallet-wallets-route`)
* **Controller Action:** `Wallet.Api/Controllers/Public/WalletsController.cs` $\rightarrow$ `VnPayReturn()`
* **Query:** `Wallet.Application/Features/VnPay/Queries/ProcessVnPayReturn/ProcessVnPayReturnQuery.cs` $\rightarrow$ `ProcessVnPayReturnQuery`
* **Query Handler:** `Wallet.Application/Features/VnPay/Queries/ProcessVnPayReturn/ProcessVnPayReturnQueryHandler.cs` $\rightarrow$ `ProcessVnPayReturnQueryHandler.Handle()`
* **Response DTO:** `Wallet.Application/Features/VnPay/Queries/ProcessVnPayReturn/ProcessVnPayReturnQuery.cs` $\rightarrow$ `VnPayReturnResponse`
* **Thực thể & Bảng DB:** Không truy cập cơ sở dữ liệu (Handler chỉ inject `IVnPayService`)
* **Typed HTTP Client (nếu có):** `Wallet.Infrastructure/Payments/VnPayService.cs` (`IVnPayService.ValidateSignature`) xác thực checksum
* **Hành vi nghiệp vụ:** Sai chữ ký trả `400` kèm `{ "errorCode": "VAL_INVALID_SIGNATURE", "message": "Invalid signature" }`. Chữ ký hợp lệ thì trả `200` với `success = (vnp_ResponseCode == "00")`; message tương ứng `"VNPay payment completed successfully."` hoặc `"VNPay payment failed or was cancelled."`.

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (do VNPay gắn vào URL redirect)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `vnp_TxnRef` | `string` | Không | Mã tham chiếu giao dịch nạp tiền, ví dụ `TOPUP-20261030153000-...`; được trả lại nguyên văn trong `transactionReference`. |
| `vnp_ResponseCode` | `string` | Không | `"00"` là thành công, giá trị khác là thất bại/hủy. |
| `vnp_TransactionNo` | `string` | Không | Số giao dịch phía VNPay, trả lại trong `transactionNumber`. |
| các tham số `vnp_*` còn lại | `string` | Có (để xác thực) | Toàn bộ query string được đưa vào `IVnPayService.ValidateSignature` để kiểm tra `vnp_SecureHash`. |

### 3.3. Request Body (JSON Payload)
*Không có body.*

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
```json
200 OK:
{
  "success": true,
  "statusCode": 200,
  "message": "Operation completed successfully.",
  "data": {
    "success": true,
    "transactionReference": "TOPUP-20261030153000-a1b2c3",
    "responseCode": "00",
    "transactionNumber": "14072026",
    "message": "VNPay payment completed successfully."
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-30T15:30:00Z"
}
```

### 4.2. Phản hồi Sai chữ ký (`400 Bad Request`)
Controller trả object rút gọn thay vì problem details đầy đủ:
```json
400 Bad Request:
{
  "errorCode": "VAL_INVALID_SIGNATURE",
  "message": "Invalid signature"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_SIGNATURE` | "Invalid signature" | `IVnPayService.ValidateSignature` trả `false`; controller trả `BadRequest` khi `!result.Success && result.ResponseCode == "97"`. |
| `200` | Không có `errorCode` | "VNPay payment failed or was cancelled." | Chữ ký hợp lệ nhưng `vnp_ResponseCode != "00"`; trả `success = false` trong envelope để Frontend hiển thị màn hình thất bại. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Endpoint không trả về trường enum nào. Bảng dưới đây liệt kê enum nghiệp vụ liên quan để đối chiếu khi Frontend cần hiển thị trạng thái nạp tiền từ dữ liệu khác.

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` (`WalletTopup`) | `TopupStatus` | `0` | `Pending` | **Chờ thanh toán**: Topup vừa tạo, chưa có IPN xác nhận. Badge vàng. |
| `status` (`WalletTopup`) | `TopupStatus` | `1` | `Success` | **Thành công**: IPN đã xác nhận và cộng tiền vào ví. Badge xanh lá. |
| `status` (`WalletTopup`) | `TopupStatus` | `2` | `Failed` | **Thất bại**: VNPay trả mã lỗi hoặc người dùng hủy. Badge đỏ. |
| `status` (`WalletTopup`) | `TopupStatus` | `3` | `Expired` | **Hết hạn**: Topup quá thời gian chờ xác nhận. Badge xám. |
| `vnp_ResponseCode` (raw) | `string` (không phải enum C#) | N/A | `"00"` | **Thành công phía VNPay**: Giá trị thô do VNPay trả, không serialize lại thành enum. |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [x] **1. Tầng Application:** `ProcessVnPayReturnQuery.cs` và `ProcessVnPayReturnQueryHandler.cs` đã được triển khai hoàn chỉnh (CQRS + MediatR, không dùng Repository).
- [x] **2. Tầng Api:** `WalletsController.cs` (`Controllers/Public/`) chỉ inject `ISender` và `ILogger`, route số nhiều, summary XML ngắn gọn.
- [x] **3. Bắt lỗi & Validation:** Xác thực checksum qua `IVnPayService.ValidateSignature`; sai chữ ký trả `VAL_INVALID_SIGNATURE` 400, các mã VNPay còn lại trả trong envelope `200`.
- [x] **4. Enum Mapping:** Endpoint không trả enum C#; các enum `TopupStatus`/`TransactionStatus` liên quan vẫn lưu integer trong DB và serialize PascalCase ở API.
- [x] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `WalletUseCaseBehaviorTests.cs` - `ProcessVnPayReturn_InvalidSignature_ReturnsFailure`).
- [x] **6. Định tuyến Gateway:** Route YARP `wallet-wallets-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
