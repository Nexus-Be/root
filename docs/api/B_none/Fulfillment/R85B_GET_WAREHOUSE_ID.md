# [GET] /api/v1/warehouses/{id}

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Warehouses`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Lấy thông tin chi tiết một kho bãi vật lý theo mã định danh `id`.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:** `/api/v1/warehouses/{id}`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` / Public
* **Yêu cầu Idempotency:** Không áp dụng (Idempotent theo chuẩn HTTP GET).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `warehouses-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/WarehousesController.cs` $\rightarrow$ `GetById([FromRoute] Guid id)`
* **Application Interface:** `Fulfillment.Application/Services/Warehouse/IWarehouseService.cs` $\rightarrow$ `GetByIdAsync()`
* **Thực thể & Bảng DB:** `Warehouse.cs` $\rightarrow$ Bảng `warehouses` trong PostgreSQL

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Route Parameters (Tham số đường dẫn)
| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng | Ghi chú |
|:---|:---|:---:|:---|:---|
| `id` | `Guid (UUID)` | Có | UUIDv4 format | Mã kho hàng |

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<WarehouseDto>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
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
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `404` | `WAREHOUSE_NOT_FOUND` | "Warehouse not found with ID '{id}'." | Không tìm thấy kho trong database. |
