# [GET] /api/v1/shipping/locations/provinces (Địa danh hành chính GHN)

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipping`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tra cứu danh mục địa danh hành chính chuẩn của Giao Hàng Nhanh (Tỉnh/Thành phố, Quận/Huyện, Phường/Xã) có cơ chế bộ đệm in-memory cache 24h để tối ưu hiệu năng gọi API đối tác.
* **HTTP Method:** `GET`
* **Đường dẫn chuẩn:**
  * `GET /api/v1/shipping/locations/provinces`: Lấy toàn bộ danh sách Tỉnh / Thành phố.
  * `GET /api/v1/shipping/locations/districts?provinceId={provinceId}`: Lấy danh sách Quận / Huyện theo Tỉnh.
  * `GET /api/v1/shipping/locations/wards?districtId={districtId}`: Lấy danh sách Phường / Xã theo Huyện.
  * `GET /api/v1/shipping/services?fromDistrictId={from}&toDistrictId={to}`: Lấy gói dịch vụ vận chuyển khả dụng.
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` / Public

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipping-locations-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShippingController.cs` $\rightarrow$ `GetProvinces()`, `GetDistricts()`, `GetWards()`, `GetServices()`
* **Application Interface:** `Fulfillment.Application/Interfaces/Shipping/IShippingLocationService.cs`
* **Service Implementation:** `Fulfillment.Infrastructure/Shipping/GhnLocationService.cs`

---

## 3. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 3.1. Phản hồi Danh sách Tỉnh / Thành phố (`ApiResponse<IReadOnlyList<ProvinceDto>>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": [
    {
      "provinceId": 201,
      "provinceName": "Hà Nội",
      "code": "HAN"
    },
    {
      "provinceId": 202,
      "provinceName": "Hồ Chí Minh",
      "code": "SGN"
    }
  ],
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 4. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Province ID must be greater than zero." | `provinceId <= 0` khi tra cứu quận huyện. |
| `400` | `VAL_INVALID_INPUT` | "District ID must be greater than zero." | `districtId <= 0` khi tra cứu phường xã. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống. |
