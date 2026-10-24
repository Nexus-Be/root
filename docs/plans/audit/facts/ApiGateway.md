# Evidence pack — ApiGateway

- file .cs (không tính Migrations): **98**, LOC: **7468**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Nexus.Gateway | 79 | 5456 |
| Nexus.Gateway.Tests | 19 | 2012 |

## 2. DbSet
_không có_

## 3. Application classes
_không có_

## 4. gRPC server thật
- `WalletController` (Nexus.Gateway/Controllers/WalletController.cs): không override method nào
- `LogController` (Nexus.Gateway/Controllers/LogController.cs): không override method nào
- `AdminUsersController` (Nexus.Gateway/Controllers/AdminUsersController.cs): không override method nào
- `NotificationController` (Nexus.Gateway/Controllers/NotificationController.cs): không override method nào
- `UsersController` (Nexus.Gateway/Controllers/UsersController.cs): không override method nào
- `OrdersController` (Nexus.Gateway/Controllers/OrdersController.cs): không override method nào
- `AuctionController` (Nexus.Gateway/Controllers/AuctionController.cs): không override method nào
- `InventoryController` (Nexus.Gateway/Controllers/InventoryController.cs): không override method nào
- `CategoriesController` (Nexus.Gateway/Controllers/CategoriesController.cs): không override method nào
- `AuthController` (Nexus.Gateway/Controllers/AuthController.cs): không override method nào
- `FulfillmentController` (Nexus.Gateway/Controllers/FulfillmentController.cs): không override method nào
- `GatewayControlController` (Nexus.Gateway/Controllers/GatewayControlController.cs): không override method nào
- `HealthProberController` (Nexus.Gateway/Controllers/HealthProberController.cs): không override method nào
- `ProductsController` (Nexus.Gateway/Controllers/ProductsController.cs): không override method nào
- `CartController` (Nexus.Gateway/Controllers/CartController.cs): không override method nào
- `TestUsers` (Nexus.Gateway.Tests/GatewayTests.cs): Login, GetProfile
- `StubUsers` (Nexus.Gateway.Tests/GatewaySurfaceTests.cs): GetProfile

## 5. REST / endpoint
- controllers: 15: `WalletController.cs`, `LogController.cs`, `AdminUsersController.cs`, `NotificationController.cs`, `UsersController.cs`, `OrdersController.cs`, `AuctionController.cs`, `InventoryController.cs`, `CategoriesController.cs`, `AuthController.cs`, `FulfillmentController.cs`, `GatewayControlController.cs`, `HealthProberController.cs`, `ProductsController.cs`, `CartController.cs`
- minimal endpoints: `/`, `/health/ready`

## 6. Messaging
- consume: không có
- publish: không có

## 7. Test
- file: 19, `[Fact]/[Theory]`: 62

## 8. Observability
- Serilog×5, x-trace-id×7, AddOpenTelemetry×1, ActivitySource×2

## 9. Docs
- 23 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_ARCHITECTURAL_BLUEPRINT.md, 02_GATEWAY_CONTROLLERS_ROUTING.md, 03_GATEWAY_STATE_SECURITY.md, 04_MOCK_ENGINE_SEED_DATA.md, 05_DEV_VERIFICATION_CHECKLIST.md, ADR.md, AGENTS.md, CLAUDE.md, CONFIG_REFERENCE.md, DEV_GUIDE.md, MOCK_GUIDE.md, PLAN.md, README.md, README.md, README.md, README.md, README.md, README.md, README.md, SETUP_GUIDE_SERVICES.md, dac_ta.md, input.md

