# [POST] /api/v1/shipping/quote

> **Phân hệ thụ lý:** `FulfillmentService`  
> **Tên tính năng:** `Shipping`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `✅ VERIFIED`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** Tính toán tạm tính phí vận chuyển động từ kho người bán tới địa chỉ người nhận cho trang Chi tiết sản phẩm (PDP), Giỏ hàng (Cart) hoặc bước thanh toán (Checkout) mà không cần tạo trước đơn hàng nháp.
* **HTTP Method:** `POST`
* **Đường dẫn chuẩn:** `/api/v1/shipping/quote`
* **Quyền hạn truy cập (RBAC):** `AllowAnonymous` / Public
* **Yêu cầu Idempotency:** Không áp dụng (Read-only calculation).

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

* **Microservice thụ lý:** `src/Services/Fulfillment/` (Cổng 8006)
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `shipping-quote-route`)
* **Controller Action:** `Fulfillment.Api/Controllers/Public/ShippingController.cs` $\rightarrow$ `Quote([FromBody] ShopShippingQuoteRequest request)`
* **Application Interface:** `Fulfillment.Application/Services/Shipment/IShipmentService.cs` $\rightarrow` `CalculateShippingFeeAsync()`
* **Carrier Gateway:** `Fulfillment.Infrastructure/Carriers/Ghn/GhnGateway.cs` $\rightarrow$ `CalculateFeeAsync()`

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

### 3.1. Request Body Record DTO
- **Vị trí file:** `Fulfillment.Application/Services/Shipping/ShippingDtos.cs`
- **Tên C# Record:** `ShopShippingQuoteRequest`
```csharp
public sealed record ShopShippingQuoteRequest(
    [Required] Guid SellerId,
    [Range(0, int.MaxValue)] int FromDistrictId, // 0: Tu dong lay theo quan huyen cua kho Seller
    [Range(1, int.MaxValue)] int ToDistrictId,
    [Required] string ToWardCode,
    [Range(1, int.MaxValue)] int WeightInGrams,
    IReadOnlyList<ShippingQuoteItem>? Items = null
);
```

### 3.2. JSON Request Body mẫu (camelCase)
```json
{
  "sellerId": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
  "fromDistrictId": 1442,
  "toDistrictId": 1450,
  "toWardCode": "20804",
  "weightInGrams": 500,
  "items": [
    {
      "skuId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "quantity": 1,
      "weightInGrams": 500
    }
  ]
}
```

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<ShippingQuoteResponse>`)
```json
// 200 OK
{
  "success": true,
  "statusCode": 200,
  "data": {
    "fee": 28000.0,
    "isEstimatedFallback": false,
    "serviceName": "GHN_STANDARD"
  },
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "timestamp": "2026-11-19T09:00:00Z"
}
```

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "ToDistrictId and ToWardCode are required for calculating GHN shipping fee." | Thiếu quận huyện hoặc phường xã đích. |
| `400` | `INVALID_FROM_DISTRICT` | "FromDistrictId is required for calculating shipping fee." | Không xác định được quận huyện gửi hàng từ kho của seller. |
| `500` | `INTERNAL_SERVER_ERROR` | "An unexpected error occurred while processing the request." | Lỗi hệ thống. |
