# BÁO CÁO ĐỐI SOÁT API AUCTION SERVICE VỚI FRONTEND (NEXUS)

> **Mục tiêu:** Hướng dẫn chi tiết cho đội ngũ Frontend (FE) tích hợp các API còn thiếu hoặc còn sót giao diện ở phân hệ Đấu giá (**AuctionService**), phục vụ demo trọn vẹn Phase 2.

---

## 📌 TỔNG QUAN HIỆN TRẠNG
- ✅ **Đã hoàn thiện tốt trên FE:**
  - Tạo phiên đấu giá (`POST /api/v1/auctions`), Sửa phiên (`PUT`), Huỷ phiên (`POST /cancel`), Tạo lại (`POST /recreate`).
  - Chọn sản phẩm của chính Seller (`GET /api/v1/seller/products/auctions`).
  - Đặt cọc ví (`POST /api/v1/auctions/{id}/deposits`) & Realtime Bidding qua SignalR.
  - Mua ngay (`POST /api/v1/auctions/{id}/buy-now`) qua `AuctionBuyNowPanel`.
  - Giá sàn (`POST /reserve-approval/accept` & `/decline`) qua `SellerReserveApprovalPanel`.
  - Lời mời người về nhì (`Second-Chance Offer`) qua `BuyerAuctionOffers`.
  - Admin tua nhanh thời gian phiên (`PATCH /schedule`, `PATCH /settlement-deadlines`) qua `TimeControlsPanel`.
  - Admin xem danh sách báo cáo & bác bỏ (`GET /api/v1/admin/auction-reports`, `POST /reports/dismiss`) qua `AuctionOpsScreen`.

---

## 🚨 DANH SÁCH API CÒN THIẾU TRÊN GIAO DIỆN FRONTEND

### 1. ⚠️ [QUAN TRỌNG NHẤT] API Buyer gửi tố cáo / khiếu nại phiên đấu giá
* **Vấn đề:** 
  - Bên **Admin** đã có màn xem danh sách tố cáo và bác bỏ.
  - Bên **Backend** đã có sẵn API nhận tố cáo.
  - **Nhưng bên màn hình chi tiết phiên của Buyer (`AuctionPages.tsx` / `AuctionDetail`) chưa có nút "Báo cáo vi phạm" hay form gửi báo cáo.**
* **API Backend đã cung cấp:**
  ```http
  POST /api/v1/auctions/{id}/reports
  ```
  - **Headers:** `Authorization: Bearer <buyer_token>`, `Content-Type: application/json`
  - **Path Param:** `{id}`: Guid phiên đấu giá.
  - **Body JSON:**
    ```json
    {
      "reason": "SuspectedShillBidding",
      "description": "Tôi nghi ngờ người bán dùng tài khoản clone để tự kích giá phiên này lên cao bất thường."
    }
    ```
    *Ghi chú danh sách Enum `reason` hợp lệ (PascalCase):*
    - `"SuspectedShillBidding"`: Nghi vấn kích giá ảo / thông đồng
    - `"CounterfeitOrFake"`: Nghi vấn hàng giả / hàng nhái
    - `"MisleadingInfo"`: Thông tin mô tả sai lệch / gian lận
    - `"ExternalContact"`: Lôi kéo giao dịch ngoài sàn
    - `"Other"`: Lý do khác
  - **Response (200 OK):**
    ```json
    {
      "success": true,
      "statusCode": 200,
      "message": "Report submitted successfully.",
      "data": {
        "reportId": "b1a2c3d4-...",
        "auctionId": "...",
        "reason": "SuspectedShillBidding",
        "status": "Pending",
        "createdAt": "2026-11-26T06:30:00Z"
      }
    }
    ```
* **Đề xuất FE cần thêm:**
  - Ở màn chi tiết phiên đấu giá phía Buyer (`AuctionRoomScreen`), thêm 1 nút nhỏ hoặc menu hành động: `[🚩 Báo cáo vi phạm phiên đấu giá]` khi `(active || scheduled) && auction.sellerId !== user.id`.
  - Bấm vào mở Modal gồm:
    - Dropdown chọn lý do (`reason`): `SuspectedShillBidding`, `CounterfeitOrFake`, `MisleadingInfo`, `ExternalContact`, `Other`.
    - Ô text mô tả (`description`): validate $10 \le \text{length} \le 1000$.
    - Nút `Gửi báo cáo` gọi `POST /api/v1/auctions/${id}/reports`.

---

### 2. API Buyer xem lại các báo cáo đấu giá của chính mình
* **Vấn đề:** Hiện tại trang `BuyerReportsScreen` ở FE chỉ đang kết nối sang UserService (`/api/v1/users/reports`), chưa có tab/phần xem lịch sử các báo cáo phiên đấu giá của Auction.
* **API Backend đã cung cấp:**
  ```http
  GET /api/v1/me/auction-reports?page=1&pageSize=20
  ```
  - **Headers:** `Authorization: Bearer <buyer_token>`
  - **Query:** `page`, `pageSize`
  - **Response (200 OK):**
    ```json
    {
      "success": true,
      "statusCode": 200,
      "data": {
        "items": [
          {
            "id": "b1a2c3d4-...",
            "auctionId": "...",
            "auctionTitle": "Vòng tay đá Ruby",
            "auctionStatus": "Running",
            "reason": "SuspectedShillBidding",
            "description": "...",
            "status": "Pending",
            "adminNote": "Đã xem xét và xử lý",
            "createdAt": "2026-11-26T06:30:00Z",
            "reviewedAt": null
          }
        ],
        "pagination": { "pageIndex": 1, "pageSize": 20, "totalCount": 1, "totalPages": 1, "hasPreviousPage": false, "hasNextPage": false }
      }
    }
    ```

---

### 3. API Seller xem thống kê hiệu suất đấu giá (`Auction Statistics`)
* **Vấn đề:** Màn hình Seller Dashboard có thể hiển thị thống kê tổng quan các phiên đấu giá nhưng chưa gắn endpoint này của AuctionService.
* **API Backend đã cung cấp:**
  ```http
  GET /api/v1/sellers/{sellerId}/auction-statistics
  ```
  - **Headers:** `Authorization: Bearer <token>`
  - **Path Param:** `{sellerId}` (Guid của Seller)
  - **Response (200 OK):**
    ```json
    {
      "success": true,
      "statusCode": 200,
      "data": {
        "sellerId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "successfulAuctions": 12,
        "failedAuctions": 2,
        "completedAuctions": 14,
        "successRate": 85.71
      }
    }
    ```

---

## ⚙️ LƯU Ý KỸ THUẬT VỀ TÍNH NĂNG ADMIN TUA THỜI GIAN (`TIME CONTROLS`)
- **Backend:** Đã cấu hình biến môi trường `AdminTimeControls__Enabled=true` trên Render.
- **Frontend:** Code `TimeControlsPanel.tsx` của FE có hàm kiểm tra feature:
  ```ts
  const enabled = useFeature("time-controls");
  ```
- **FE cần lưu ý:** Đảm bảo biến môi trường `FEATURES` ở FE có chứa `time-controls` (ví dụ `FEATURES=vouchers,ledger,time-controls`) để nút tua giờ hiển thị trên giao diện của Admin.
