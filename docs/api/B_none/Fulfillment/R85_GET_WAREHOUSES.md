# [GET] /api/v1/warehouses

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Warehouses`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy danh sách các kho hàng vật lý đang hoạt động trên hệ thống có phân trang.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/warehouses`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` / Public
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo chuẩn HTTP GET).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `warehouses-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/WarehousesController.cs` $\rightarrow$ `ListActive([FromQuery] int page = 1, [FromQuery] int pageSize = 20)`
* **Application Interface:** `Fulfillment.Application/Services/Warehouse/IWarehouseService.cs` $\rightarrow$ `ListActiveAsync()`
* **Thực thể & Bảng DB:** `Warehouse.cs` $\rightarrow$ Bảng `warehouses` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Query Parameters (Tham số truy vấn)
| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị | Ghi chú |
|:---|:---|:---:|:---|:---|
| `page` | `integer` | `1` | $\ge 1$ | Số trang |
| `pageSize` | `integer` | `20` | $1 \le pageSize \le 100$ | Kích thước trang |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<WarehouseDto>>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "items": [
      {
        "id": "b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e",
        "code": "WH_HCM_01",
        "name": "Kho Tong Tan Binh",
        "address": "123 Truong Chinh, Quan Tan Binh, TP. Ho Chi Minh",
        "contactPhone": "0901234567",
        "provinceName": "TP. Ho Chi Minh",
        "districtId": 1442,
        "wardCode": "20101",
        "ghnShopId": 5550559,
        "isDisabled": false,
        "sellerId": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống nội bộ. |
