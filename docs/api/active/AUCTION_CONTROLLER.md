# 🔨 ACTIVE APIS: AUCTION CONTROLLER

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua REST Controller & Gateway cổng `8080` ngày 2026-10-30)  
> **Gateway Controller:** `Nexus.Gateway/Controllers/AuctionController.cs`  
> **Backend Service:** `Auction.Api` (Cổng `8005`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`auction_db`), Concurrency control, Clean Architecture

---

## 1. DANH SÁCH PHIÊN ĐẤU GIÁ ĐANG DIỄN RA (LIST ACTIVE AUCTIONS)

- **Endpoint Gateway:** `GET /api/v1/auctions`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://auction-service:8005/api/v1/auctions`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |
| `status` | Query | Không | Lọc trạng thái phiên (UPCOMING, ACTIVE, ENDED, CANCELLED) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be >= 1 and pageSize between 1 and 100." | Tham số phân trang không hợp lệ |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`AuctionService.cs`) query danh sách phiên đấu giá.
- [x] Thin Controller (`AuctionsController.cs`) ghép cặp 1-to-1, route chính thức duy nhất `/api/v1/auctions`.
- [x] Gateway routing & Seed fixture (`Seeds/auction/auctions.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. XEM CHI TIẾT PHIÊN ĐẤU GIÁ (GET AUCTION BY ID)

- **Endpoint Gateway:** `GET /api/v1/auctions/{id}`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://auction-service:8005/api/v1/auctions/{id}`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `id` | Route | Có | GUID định danh phiên đấu giá |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_AUCTION_ID` | "Invalid auction identifier format." | ID phiên đấu giá không phải GUID |
| `404` | `AUCTION_NOT_FOUND` | "Auction session not found with the specified ID." | Phiên đấu giá không tồn tại |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`AuctionService.cs`) tìm kiếm theo ID.
- [x] Thin Controller (`AuctionsController.cs`) ghép cặp 1-to-1.
- [x] Gateway routing & Seed fixture (`Seeds/auction/auction-detail.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 3. LỊCH SỬ ĐẶT GIÁ CỦA PHIÊN (LIST BIDS BY AUCTION ID)

- **Endpoint Gateway:** `GET /api/v1/auctions/{id}/bids`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://auction-service:8005/api/v1/auctions/{id}/bids`

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`BidService.cs`) truy vấn lịch sử đặt giá.
- [x] Thin Controller (`BidsController.cs`) ghép cặp 1-to-1, route `/api/v1/auctions/{auctionId:guid}/bids`.
- [x] Gateway routing & Seed fixture (`Seeds/auction/auction-bids.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
