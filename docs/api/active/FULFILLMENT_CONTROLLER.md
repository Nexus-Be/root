# 📦 ACTIVE APIS: FULFILLMENT CONTROLLERS (WAREHOUSES & SHIPMENTS)

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua REST Controller & Gateway cổng `8080` ngày 2026-10-30)  
> **Gateway Controller:** `Nexus.Gateway/Controllers/FulfillmentController.cs`  
> **Backend Service:** `Fulfillment.Api` (Cổng `8006`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`fulfillment_db`), Physical Warehouse Ledger, Carrier Integrations

---

## 1. DANH SÁCH KHO BÃI VẬT LÝ (LIST WAREHOUSES)

- **Endpoint Gateway:** `GET /api/v1/warehouses`
- **Quyền truy cập:** Công khai (`AllowAnonymous`) hoặc Nhân viên kho
- **Forward downstream:** `GET http://fulfillment-service:8006/api/v1/warehouses`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be at least 1 and page size between 1 and 100." | Tham số phân trang không hợp lệ |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`WarehouseService.cs`) query danh sách kho.
- [x] Thin Controller (`WarehousesController.cs`) ghép cặp 1-to-1, route chính thức duy nhất `/api/v1/warehouses`.
- [x] Gateway routing & Seed fixture (`Seeds/fulfillment/warehouses.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. TRA CỨU VẬN ĐƠN (TRACK SHIPMENT)

- **Endpoint Gateway:** `GET /api/v1/shipments/track/{trackingNumber}`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://fulfillment-service:8006/api/v1/shipments/track/{trackingNumber}`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `trackingNumber` | Route | Có | Mã vận đơn giao vận |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_TRACKING_NUMBER` | "Tracking number cannot be empty." | Mã tracking rỗng |
| `404` | `SHIPMENT_NOT_FOUND` | "Shipment not found with the provided tracking number." | Không tìm thấy vận đơn |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ShipmentService.cs`) tra cứu mã tracking.
- [x] Thin Controller (`ShipmentsController.cs`) ghép cặp 1-to-1.
- [x] Gateway routing & Seed fixture (`Seeds/fulfillment/shipment-track.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
