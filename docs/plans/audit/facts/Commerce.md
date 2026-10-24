# Evidence pack — Commerce

- file .cs (không tính Migrations): **67**, LOC: **1856**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Commerce.Infrastructure | 19 | 894 |
| Commerce.Domain | 38 | 608 |
| Commerce.Application | 8 | 199 |
| Commerce.Api | 2 | 155 |

## 2. DbSet
`AuctionOrder`, `AuditLog`, `Cart`, `CartItem`, `DailyOrderSequence`, `DiscountCode`, `DiscountCodeScope`, `DiscountCodeUsage`, `Order`, `OrderCancellation`, `OrderInvoice`, `OrderRefund`, `OrderStatusHistory`, `SubOrder`, `SubOrderItem`, `SystemSetting`

## 3. Application classes
- CartService : ICartService
- OrderService : IOrderService

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
- AddCartItem, ClearCart, CreateOrder, GetCart, GetOrder, ListAllOrders, ListOrders, ListOrdersBySeller, RemoveCartItem, UpdateCartItem
