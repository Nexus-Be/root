# 01 — CLEAN ARCHITECTURE & MICROSERVICE BOUNDARIES

## 1. 4-Layer Clean Architecture
Every backend microservice in Nexus (`User`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Notification`, `Log`, `CheckHeal`) strictly enforces four layers:
* `{Service}.Domain`: Pure business entities, value objects, domain enums, domain exceptions. Zero external library dependencies (no EF Core, no MediatR, no ASP.NET).
* `{Service}.Application`: Business use cases, `I{Service}DbContext` interface, Feature Co-location services, typed request/response records, and downstream client interfaces.
* `{Service}.Infrastructure`: Database context implementation (`AppDbContext`), EF Core `EntityTypeConfiguration<T>`, migrations, seeds, external integrations, and typed REST HTTP clients.
* `{Service}.Api`: Thin REST controllers (`Controllers/Public/`; `Controllers/Internal/` frozen off since 2026-10-31), middleware, DI composition root (`Program.cs`). Never place business logic or direct DB queries here.

## 2. Feature Co-Location (Mandatory)
All use case components for a business feature must be located together inside `{Service}.Application/Services/{Feature}/`:
* `I{Feature}Service.cs`: Feature contract interface.
* `{Feature}Service.cs`: Service implementation injecting `I{Service}DbContext` directly.
* `{Feature}Requests.cs`: All request records for the feature.
* `{Feature}Responses.cs`: All response records for the feature.
* `{Feature}Dtos.cs` (optional): Internal sub-DTOs if needed.

**Wallet-only exception (classic CQRS).** `WalletService` is the single service allowed to use MediatR. Its use cases live at `Wallet.Application/Features/{Area}/Commands|Queries/{UseCase}/`, each folder holding `{UseCase}Command.cs` or `{UseCase}Query.cs`, `{UseCase}Handler.cs`, and the response record. There is no `I{Feature}Service` facade. See `src/Services/Wallet/AGENTS.md` for the full contract.

## 3. Thin 1-to-1 Controller Pairing
Each feature service must be paired 1-to-1 with a thin controller at `{Service}.Api/Controllers/{Feature}Controller.cs`:
* At Backend Microservices: Inherits `ControllerBase`, injects ONLY `I{Feature}Service`.
* At ApiGateway: Reverse proxy forwarding via Microsoft YARP.

## 4. Absolute Architectural Prohibitions
* 🛑 **PROHIBIT Repository Pattern over EF Core**: Never create `IRepository<T>`, `GenericRepository`, or `UnitOfWork`. Inject `I{Service}DbContext` and query `DbSet<T>` directly.
* 🛑 **PROHIBIT MediatR & CQRS in every backend service EXCEPT `WalletService`**: Feature logic must reside in Feature Services, not split across `Features/Commands` and `Features/Queries`. WalletService is the documented exception and must use classic CQRS through MediatR.
* 🛑 **PROHIBIT gRPC**: All inter-service and gateway synchronous communication must be 100% RESTful HTTP/JSON.
* 🛑 **PROHIBIT Message Brokers & Events**: RabbitMQ, MassTransit, Saga state machines, and transactional Outbox/Inbox tables are decommissioned. All inter-service communication must use synchronous typed REST clients via `IHttpClientFactory`.
* 🛑 **PROHIBIT Cross-Database Queries**: Database-per-service isolation is absolute. Never query another service's database directly.
