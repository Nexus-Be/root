# Evidence pack — Fulfillment

- file .cs (không tính Migrations): **46**, LOC: **1184**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Fulfillment.Infrastructure | 13 | 492 |
| Fulfillment.Domain | 23 | 334 |
| Fulfillment.Application | 8 | 204 |
| Fulfillment.Api | 2 | 154 |

## 2. DbSet
`AuditLog`, `Carrier`, `InventoryItem`, `InventoryLedger`, `InventoryReservation`, `InventoryReservationItem`, `Shipment`, `ShipmentEvent`, `ShipmentItem`, `Warehouse`

## 3. Application classes
- ShipmentService : IShipmentService
- WarehouseService : IWarehouseService

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
- CalculateShippingFee, GetInventory, GetShipmentTracking
