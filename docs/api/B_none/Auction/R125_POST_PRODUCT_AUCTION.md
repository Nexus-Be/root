# [POST] /api/v1/products/auction

> **Phân hệ thụ lý:** `AuctionService`  
> **Tên tính năng:** `Auctions`  
> **Mã tham chiếu Excel:** ``CAT-43 (mới)``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** thêm sản phẩm đấu giá
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/products/auction`
* **Đường dẫn gốc trong Excel:** `/api/v1/product/auction` (Chuẩn hóa từ '/api/v1/product/auction' sang chuẩn 100% số nhiều '/api/v1/products/auction'.)
* **Quyền hạn truy cập (RBAC):** `Seller`
* **Yêu cầu Idempotency:** Tùy chọn (Khuyến nghị gửi header `Idempotency-Key: UUIDv4` để tránh gửi lặp)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Auction/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `auction-auctions-route`)
* **Controller Action:** `Auction.Api/Controllers/AuctionsController.cs` $\rightarrow$ `CreateAuction()`
* **Application Interface:** `Auction.Application/Services/Auctions/IAuctionService.cs` $\rightarrow$ `CreateAuctionAsync()`
* **Service Implementation:** `Auction.Application/Services/Auctions/AuctionService.cs` $\rightarrow$ `CreateAuctionAsync()`
* **Thực thể & Bảng DB:** `Auction.Domain/Entities/Auction.cs` $\rightarrow$ Bảng `Auctions` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
*Không có tham số đường dẫn.*

### 3.2. Query Parameters (Tham số truy vấn)
*Không có tham số truy vấn.*

### 3.3. Request Body (JSON Payload)
```json
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


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)
Áp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:
```json
201 Created:
{
  "success": true,
  "statusCode": 201,
  "data": {
    "productId": "uuid",
    "status": "Draft",
    "saleType": "Auction",
    "variant": {
      "variantId": "uuid",
      "skuCode": "string"
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-10-26T00:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `503` | `USER_SERVICE_UNAVAILABLE` | "Failed to verify seller account with user service." | Điều kiện nghiệp vụ đặc thù: USER_SERVICE_UNAVAILABLE. |
| `409` | `SKU_CODE_DUPLICATED` | "Skucode already exists on an active variant." | Điều kiện nghiệp vụ đặc thù: SKU_CODE_DUPLICATED. |
| `403` | `SELLER_NOT_ALLOWED` | "Account is not an approved seller or has insufficient reputation for auctions." | Điều kiện nghiệp vụ đặc thù: SELLER_NOT_ALLOWED. |
| `401` | `UNAUTHORIZED` | "Token is missing, expired, or invalid." | Điều kiện nghiệp vụ đặc thù: UNAUTHORIZED. |
| `400` | `CATEGORY_INVALID` | "Specified categoryid does not exist, is deactivated, or deleted." | Điều kiện nghiệp vụ đặc thù: CATEGORY_INVALID. |
| `400` | `VALIDATION_ERROR` | "Name is empty, variant definition invalid, or unexpected price field for auction product." | Điều kiện nghiệp vụ đặc thù: VALIDATION_ERROR. |
| `403` | `FORBIDDEN` | "You do not have permission to perform this action." | Người dùng không đủ quyền RBAC theo quy định. |
| `404` | `AUCTION_NOT_FOUND` | "Auction not found with the specified ID." | Không tìm thấy bản ghi trong Database tương ứng. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred. Please try again later." | Lỗi hệ thống nội bộ chưa được xử lý. |

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

Bảng đối chiếu toàn diện giữa trường dữ liệu trong Payload (JSON Field), định dạng lưu trữ Database và chuỗi trả về API để Frontend hiển thị và binding giao diện chính xác:

| Tên trường Payload (JSON Field) | Kiểu C# Enum | Giá trị DB (`integer`) | Giá trị API (`string PascalCase`) | Ý nghĩa nghiệp vụ & Hướng dẫn hiển thị Frontend |
|:---|:---|:---:|:---|:---|
| `status` | `AuctionStatus` | `0` | `Draft` | **Bản nháp**: Phiên đấu giá đang cấu hình, chưa lên lịch. Badge xám (Secondary). |
| `status` | `AuctionStatus` | `1` | `Scheduled` | **Đã lên lịch bắt đầu**: Đã công bố, đếm ngược tới giờ mở phiên. Badge xanh dương (Info). |
| `status` | `AuctionStatus` | `2` | `Running` | **Đang diễn ra sôi động**: Đang mở cổng cho người mua vào đấu giá (Bid). Badge đỏ nhấp nháy / xanh lá (Live). |
| `status` | `AuctionStatus` | `3` | `Ended` | **Đã kết thúc phiên**: Đã dừng nhận giá, đang chốt người thắng cuộc. Badge cam (Warning). |
| `status` | `AuctionStatus` | `4` | `Settled` | **Đã thanh toán & Tạo đơn**: Người thắng đã thanh toán đơn đấu giá thành công. Badge xanh lá (Success). |
| `status` | `AuctionStatus` | `5` | `Failed` | **Đấu giá thất bại**: Không có ai tham gia đặt giá hoặc không đạt giá sàn. Badge xám (Muted). |
| `status` | `AuctionStatus` | `6` | `Cancelled` | **Bị hủy bỏ**: Seller hủy trước giờ G hoặc Admin cưỡng chế hủy. Badge đỏ (Danger). |

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `IAuctionService.cs` và `AuctionService.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `AuctionsController.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `AuctionsTests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `auction-auctions-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
