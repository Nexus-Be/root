# 🛍️ ACTIVE APIS: CATALOG CONTROLLERS (CATEGORIES & PRODUCTS)

> **Trạng thái:** ✅ CÓ (Đã kiểm chứng thực tế qua REST Controller & Gateway cổng `8080` ngày 2026-10-30)  
> **Gateway Controllers:** `Nexus.Gateway/Controllers/CategoriesController.cs`, `Nexus.Gateway/Controllers/ProductsController.cs`  
> **Backend Service:** `Catalog.Api` (Cổng `8002`)  
> **Hạ Tầng Liên Quan:** PostgreSQL (`category_db`), EF Core direct queries (No Repository), Clean Architecture

---

## 1. DANH MỤC SẢN PHẨM (LIST PRODUCTS)

- **Endpoint Gateway:** `GET /api/v1/products`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://catalog-service:8002/api/v1/products`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `page` | Query | Không | Mặc định 1 (>= 1) |
| `pageSize` | Query | Không | Mặc định 20 (1 - 100) |
| `keyword` | Query | Không | Từ khóa tìm kiếm sản phẩm |
| `categoryId` | Query | Không | GUID danh mục sản phẩm |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_INPUT` | "Page must be at least 1 and page size between 1 and 100." | Tham số phân trang không hợp lệ |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ProductService.cs`) query phân trang trực tiếp `ICatalogDbContext`.
- [x] Thin Controller (`ProductsController.cs`) ghép cặp 1-to-1, route chính thức duy nhất `/api/v1/products`.
- [x] Gateway routing & Seed fixture (`Seeds/catalog/products.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 2. CHI TIẾT SẢN PHẨM (GET PRODUCT BY ID)

- **Endpoint Gateway:** `GET /api/v1/products/{id}`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://catalog-service:8002/api/v1/products/{id}`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `id` | Route | Có | Định dạng GUID hợp lệ |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `400` | `VAL_INVALID_PRODUCT_ID` | "Invalid product identifier format." | ID sản phẩm không phải GUID |
| `404` | `PRODUCT_NOT_FOUND` | "Product not found with the specified ID." | Không tìm thấy sản phẩm trong hệ thống |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`ProductService.cs`) tìm kiếm theo ID.
- [x] Thin Controller (`ProductsController.cs`) ghép cặp 1-to-1.
- [x] Gateway routing & Seed fixture (`Seeds/catalog/product-detail.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`

---

## 3. DANH SÁCH DANH MỤC (LIST CATEGORIES)

- **Endpoint Gateway:** `GET /api/v1/categories`
- **Quyền truy cập:** Công khai (`AllowAnonymous`)
- **Forward downstream:** `GET http://catalog-service:8002/api/v1/categories`

### Quy chuẩn Validation (Input Rules)
| Trường | Vị trí | Bắt buộc | Ràng buộc validation |
|:---|:---:|:---:|:---|
| `parentId` | Query | Không | Lọc theo danh mục cha (GUID) |

### Ma trận Mã Lỗi (RFC 9110 Error Matrix)
| Mã HTTP | Mã lỗi (`errorCode`) | Thông báo tiếng Anh (`message`) | Điều kiện kích hoạt |
|:---:|:---|:---|:---|
| `200` | - | - | Thành công trả về danh sách danh mục |

### Checklist Xác Nhận Hoàn Thành
- [x] Application Service (`CategoryService.cs`) query cây danh mục.
- [x] Thin Controller (`CategoriesController.cs`) ghép cặp 1-to-1.
- [x] Gateway routing & Seed fixture (`Seeds/catalog/categories.json`) đồng bộ.
- [x] Trạng thái: `✅ COMPLETED`
