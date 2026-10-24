# Evidence pack — Catalog

- file .cs (không tính Migrations): **42**, LOC: **1343**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Catalog.Infrastructure | 12 | 709 |
| Catalog.Domain | 20 | 283 |
| Catalog.Application | 8 | 196 |
| Catalog.Api | 2 | 155 |

## 2. DbSet
`AuditLog`, `Category`, `Product`, `ProductImage`, `ProductRatingStats`, `ProductReview`, `ProductVariant`, `ProductVariantAttribute`, `PurchaseRecord`

## 3. Application classes
- CategoryService : ICategoryService
- ProductService : IProductService

## 4. gRPC server thật
_KHÔNG có class kế thừa gRPC Base_

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/health`

## 6. Messaging
- consume: không có
- publish: không có

## 7. Test
- file: 0, `[Fact]/[Theory]`: 0

## 8. Observability
- không có

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- AdjustInventory, CreateCategory, CreateProduct, DeleteCategory, DeleteProduct, GetCategory, GetInventory, GetProduct, ListCategories, ListProducts, ListProductsBySeller, UpdateCategory, UpdateProduct
