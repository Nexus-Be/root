# [GET] /api/v1/auctions/{auctionId}/bids

> **Phân hệ thụ lý:** `AuctionService`  
> **Tên tính năng:** `Auctions`  
> **Mã tham chiếu Excel:** ``AUC-03``  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** User xem được lịch sử đặt giá của phiên đang tham gia
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/auctions/{auctionId}/bids`
* **Đường dẫn gốc trong Excel:** `/api/v1/auctions/{auctionId}/bids` (Đường dẫn đã tuân thủ chuẩn 100% số nhiều.)
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous`
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo HTTP spec)

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/Auction/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `auction-bids-route`)
* **Controller Action:** `Auction.Api/Controllers/AuctionsController.cs` $\rightarrow$ `GetAuctionBids()`
* **Application Interface:** `Auction.Application/Services/Auctions/IAuctionService.cs` $\rightarrow$ `GetAuctionBidsAsync()`
* **Service Implementation:** `Auction.Application/Services/Auctions/AuctionService.cs` $\rightarrow$ `GetAuctionBidsAsync()`
* **Thực thể & Bảng DB:** `Auction.Domain/Entities/Auction.cs` $\rightarrow$ Bảng `Auctions` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |
|:---|:---|:---:|:---|
| `auctionId` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |

### 3.2. Query Parameters (Tham số truy vấn)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |
|:---|:---|:---:|:---|
| `page` | `integer` | `1` | Số trang (tối thiểu 1) |
| `pageSize` | `integer` | `20` | Kích thước trang ($1 \le pageSize \le 100$) |

### 3.3. Request Body (JSON Payload)
```json
Path:
{ "auctionId": "UUID" }

Query:
{
"page": "int (optional, default 1)",
"pageSize": "int (optional, default 20, tối đa 100)"
}
```


---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<T>>`)
Áp dụng cho API tra cứu danh sách có phân trang:
```json
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

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "One or more validation errors occurred." | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |
| `401` | `UNAUTHORIZED` | "Authentication token is missing, expired, or invalid." | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |
| `404` | `AUCTION_NOT_FOUND` | "Auction was not found." | Điều kiện nghiệp vụ đặc thù: AUCTION_NOT_FOUND. |
| `400` | `VALIDATION_ERROR` | "Auctionid is not a valid UUID format or invalid pagination parameters." | Điều kiện nghiệp vụ đặc thù: VALIDATION_ERROR. |
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
- [ ] **6. Định tuyến Gateway:** Route YARP `auction-bids-route` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
