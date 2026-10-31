---
name: new-feature-endpoint
description: End-to-end procedure for adding or changing a Nexus REST endpoint. Use when adding a feature service, controller action, request/response contract, database field, Gateway route, or cross-service typed client, or when changing an existing endpoint's route, validation, error matrix, or pagination.
---

# New Feature Endpoint

This skill is the canonical procedure for shipping one REST endpoint across the Nexus backend. It covers the database, the Application feature, the thin controller, tests, API documentation, the YARP route, and the verification gate.

When you work inside a service repository, also read that repository's local overlay at `.agents/skills/new-feature-endpoint/SKILL.md`. The overlay is self-contained and adds the service's ports, database, and variants. This root skill is the full procedure.

## 1. When to use

Use this skill when the task is any of the following:

- Add a new endpoint to an existing controller.
- Add a new feature controller and feature service.
- Change a route, HTTP method, request DTO, response DTO, or status code.
- Add validation, an error code, or an enum value that reaches the API.
- Add a database entity or column that backs an endpoint.
- Add a Gateway route for a new resource.
- Add or change a typed REST client that calls another service.

Do not use this skill for refactors that do not change the HTTP contract. Use the service's normal refactor workflow instead.

## 2. Source-of-truth precedence

Read in this order and stop if two sources disagree:

1. The operator's current explicit instruction.
2. Code that is running in the repository today.
3. `src/Services/{Service}/.agents/rules/*` and `src/Services/{Service}/specs/*`.
4. Root `AGENTS.md`, `.agents/rules/*`, and `specs/*`.
5. Older plans, session notes, and API docs.

Known current state that overrides older text:

- Microservices return pure DTOs. The Gateway `ResponseEnvelopeMiddleware` wraps them into `ApiResponse<T>` or `ApiResponse<PagedData<T>>`. Do not add a `ResultFilter` or a manual envelope inside a microservice.
- The Internal API model is frozen off since 2026-10-31. Inter-service routes use public prefixes such as `POST /api/v1/notifications/email/otp` and `POST /api/v1/wallets/checkout/direct`. Do not add `/api/v1/internal/*`, do not create `Controllers/Internal/`, and do not require `X-Internal-Service-Key`.
- `WalletService` is the only service allowed to use MediatR and classic CQRS.

## 3. Non-negotiables

- Route collections use lowercase plural nouns under `/api/v1/`. Only `/api/v1/me` and `/api/v1/auth` are singular.
- One official route attribute per action. Duplicate aliases are prohibited.
- JSON is camelCase. C# DTOs are PascalCase. Enums leave the API as PascalCase strings, never integers or SCREAMING_SNAKE_CASE.
- Error codes are SCREAMING_SNAKE_CASE. Messages are English sentence case. No `ERR_` prefix.
- Every list endpoint paginates at the database with `Skip`/`Take` and `CountAsync`. No unbounded lists.
- Never trust `userId`, `sellerId`, or `buyerId` from the client. Read identity from `HttpContext`.
- Never create `IRepository<T>`, `GenericRepository`, or `UnitOfWork`. Inject `I{Service}DbContext`.
- Never use gRPC, RabbitMQ, MassTransit, Saga, or Outbox/Inbox tables.
- Never query another service's database.
- Database enums are integers. JSON enums are PascalCase strings.
- Migrations are additive. No `DROP`, `TRUNCATE`, or `RENAME` without explicit approval.
- Secrets stay out of source. Do not add or echo credentials.

## 4. Phase map

Run the phases in order. A phase may be skipped only when it genuinely does not apply, and the skip must be recorded in the session plan.

- Phase 0: Preflight and impact.
- Phase 1: Contract design.
- Phase 2: Persistence.
- Phase 3: Application.
- Phase 4: Api.
- Phase 5: Tests.
- Phase 6: Documentation.
- Phase 7: Gateway.
- Phase 8: Verification.
- Phase 9: Handoff.

## 5. Phase 0 - Preflight and impact

- [ ] Read root `AGENTS.md`, `.agents/rules/01` through `06`, and the service `AGENTS.md`, `.agents/rules/01` through `06`, and `specs/00` through `05`.
- [ ] Read the closest existing controller, feature service, request/response records, and tests.
- [ ] Run GitNexus impact on every symbol that will change: `node .gitnexus/run.cjs impact "<symbol>" --direction upstream --repo .`. Record callers and risk.
- [ ] If risk is `HIGH` or `CRITICAL`, stop and report before editing. If risk is `UNKNOWN`, resolve it with text search.
- [ ] Decide the contract: method, path, RBAC policy, ownership rule, idempotency, pagination, cross-service calls, and database changes.
- [ ] Create `.agents/plan/PLAN-YYYYMMDD-HHMM-<NAME>.md` with objective, files, impact, checklist, and verification commands.
- [ ] If the contract is ambiguous, ask the operator. Do not guess a route or an error code.

## 6. Phase 1 - Contract design

- [ ] Path is `/api/v1/{plural-resource}` or the documented `/me` / `/auth` exception.
- [ ] Admin routes are namespaced per domain (`/api/v1/admin/users`, `/api/v1/admin/wallets`, `/api/v1/admin/auctions`, ...) and never a single catch-all.
- [ ] HTTP method matches RFC 9110 semantics. `GET` is safe, `POST` creates or acts, `PUT` replaces, `PATCH` partially updates, `DELETE` removes.
- [ ] Status codes are explicit: `200`, `201`, `204`, `400`, `401`, `403`, `404`, `409`, `500`.
- [ ] Request and response records live in the feature folder and use camelCase on the wire.
- [ ] Every error has a stable `errorCode` and an English sentence-case message.
- [ ] Every enum that crosses the boundary is documented with its integer database value and its PascalCase API value.
- [ ] List endpoints accept `page` and `pageSize`, clamp them, and return `PagedData<T>` with full pagination metadata.
- [ ] Mutating inter-service calls accept `Idempotency-Key` when the downstream operation can be retried.
- [ ] New inter-service route uses a public prefix and the internal model stays off.
- [ ] Write the contract block from `references/checklist.md` into the session plan before coding.

## 7. Phase 2 - Persistence

Skip only when no entity, column, index, or seed changes.

- [ ] Entity lives in `{Service}.Domain/Entities/` and inherits `BaseEntity<Guid>` or `AuditableEntity<Guid>`.
- [ ] Enum values are explicit integers starting at `0`. No `HasConversion<string>()`.
- [ ] `EntityTypeConfiguration<T>` defines table name, keys, indexes, and relations.
- [ ] Soft delete uses `IsDeleted` and `DeletedAt`, with `HasQueryFilter(x => !x.IsDeleted)`.
- [ ] Foreign keys use `DeleteBehavior.Restrict` or `SetNull`. Avoid `Cascade` unless the aggregate truly owns the child.
- [ ] Money and balances use `HasPrecision(18, 2)`.
- [ ] Frequently filtered or joined columns have indexes. Unique nullable columns use filtered indexes.
- [ ] Migration name is timestamped and describes the business change.
- [ ] `AppDbContextModelSnapshot.cs` and the generated `*.Designer.cs` match the entity.
- [ ] Seed data uses deterministic GUIDs and BCrypt-hashed sample passwords. No `Guid.NewGuid()` in `HasData`.
- [ ] Startup migration is guarded by `IsRelational()` and wrapped in try/catch with a warning log.
- [ ] No destructive SQL without explicit approval.

## 8. Phase 3 - Application

- [ ] Feature folder is `{Service}.Application/Services/{Feature}/`.
- [ ] Files are `I{Feature}Service.cs`, `{Feature}Service.cs`, `{Feature}Requests.cs`, `{Feature}Responses.cs`, and optional `{Feature}Dtos.cs`.
- [ ] The service injects `I{Service}DbContext` directly. No repository, no unit of work.
- [ ] Reads use `AsNoTracking()`. Writes load tracked entities and save once.
- [ ] Multi-step writes and audit records share one transaction.
- [ ] Mutating sensitive operations call `_dbContext.AddAuditLog(...)`. Do not use `_logger` as an audit substitute.
- [ ] Pagination is computed in SQL, not in memory.
- [ ] Exceptions carry a stable code and an English message.
- [ ] Return response records, not entities.
- [ ] Cross-service interface lives in `{Service}.Application/Interfaces/`. Implementation lives in `{Service}.Infrastructure/Services/`. DI registration lives in `Infrastructure/DependencyInjection.cs`.
- [ ] The typed client has a timeout, retry policy, and a graceful fallback.

### Wallet variant

Wallet does not use feature services. Add a use case under `Wallet.Application/Features/{Area}/Commands|Queries/{UseCase}/` with the command or query record, the handler, and the response record. Handler injects `IWalletDbContext`. Controller injects `ISender`. Run `src/Services/Wallet/scripts/verify-wallet-architecture.sh` before and after the change.

## 9. Phase 4 - Api

- [ ] Controller lives in `{Service}.Api/Controllers/Public/` and is named `{Feature}Controller`.
- [ ] Controller inherits `ControllerBase`, has `[ApiController]`, and one `[Route]`.
- [ ] Each action has exactly one route attribute and one single-line XML `<summary>`.
- [ ] Controller injects only `I{Feature}Service` (or `ISender` in Wallet).
- [ ] Input uses `[FromRoute]`, `[FromQuery]`, `[FromBody]`, and `CancellationToken`.
- [ ] Identity comes from `this.TryGetUserId(...)`. Ownership uses `this.EnsureOwnership(...)`. Admin uses the service's role helper.
- [ ] Read and write actions return the DTO directly with `Ok(...)` or `StatusCode(201, ...)`.
- [ ] Delete or empty actions return `NoContent()`.
- [ ] No `ResultFilter`, no manual envelope, no business branching in the controller.
- [ ] Logging is structured and does not include secrets or tokens.

## 10. Phase 5 - Tests

- [ ] Unit tests cover the happy path and every error code the feature can emit.
- [ ] Boundary tests cover pagination clamps, empty results, and maximum page size.
- [ ] Ownership tests cover `401` for anonymous and `403` for a different owner.
- [ ] Controller or REST tests cover route, status code, payload shape, and enum serialization as PascalCase strings.
- [ ] Swagger tests confirm the route and query parameters are advertised correctly.
- [ ] `dotnet test {Service}.sln -c Release` passes 100%.
- [ ] If the repository has no test project, record the gap in the session plan and report it. Do not claim coverage that does not exist.

## 11. Phase 6 - Documentation

- [ ] Create `docs/api/B_none/{Service}/{ID}_{FEATURE}.md` from `docs/api/API_DOC_TEMPLATE.md`.
- [ ] Fill all seven sections: RBAC, code trace, validation, envelope samples, RFC 9110 error matrix, enum table, completion checklist.
- [ ] Error matrix rows are sorted by status and use SCREAMING_SNAKE_CASE codes with sentence-case messages.
- [ ] Update `docs/api/README.md` and `docs/FRONTEND_API_ENDPOINT_MAPPING.md`.
- [ ] Update `src/Services/{Service}/specs/02_API_REST_CONTRACTS.md`.
- [ ] Update `specs/02_INTER_SERVICE_COMMUNICATION_MATRIX.md` when a new inter-service call is added.
- [ ] Update `src/Services/Gateway/specs/02_ROUTING_CATALOG.md` when a new Gateway route is added.
- [ ] Move the API doc to `docs/api/A_Active/{Service}/` only after tests pass and the operator accepts the API.
- [ ] When a service function gains a new error or enum, update the existing API doc in the same change.

## 12. Phase 7 - Gateway

- [ ] Add a route and a cluster entry in `src/Services/Gateway/Gateway/appsettings.json` and the example file.
- [ ] Route path is `/api/v1/{resource}/{**catch-all}`.
- [ ] Route order does not shadow a more specific route.
- [ ] Admin routes are split per domain. No single admin catch-all.
- [ ] No route targets `/internal`.
- [ ] Confirm `ClientContextMiddleware` still rejects spoofed identity headers and strips the internal key.
- [ ] Confirm `ResponseEnvelopeMiddleware` wraps the service DTO and leaves pagination intact.
- [ ] Add or update Gateway tests for the new route.
- [ ] Confirm the Gateway Swagger aggregation does not expose internal paths.
- [ ] `dotnet test src/Services/Gateway/Gateway.sln -c Release` passes.

## 13. Phase 8 - Verification

- [ ] `dotnet build {Service}.sln -c Release` has 0 errors.
- [ ] `dotnet test {Service}.sln -c Release` passes 100%, or the missing test project is recorded.
- [ ] `dotnet build src/Services/Gateway/Gateway.sln -c Release` when a route changed.
- [ ] Run the relevant probes: `tools/verify-swagger.sh`, `tools/probe_gateway_contract.sh`, `tools/probe_validation_contract.sh`, `tools/auth_e2e_test.sh`.
- [ ] Curl through the Gateway and verify status, envelope, error code, pagination, `204` empty body, `401`, and `403`.
- [ ] Run GitNexus `detect_changes` before any commit.
- [ ] `git status` shows no `bin/`, `obj/`, `.vs/`, `.idea/`, or secret file.
- [ ] Record the exact commands and outputs in the session plan.

## 14. Phase 9 - Handoff

- [ ] Tick the session plan checklist.
- [ ] Append a session summary to `.agents/history/YYYY-MM-DD_session_summary.md`.
- [ ] If the change introduced a new invariant, update `AGENTS.md`, `.agents/rules/*`, and the service `AGENTS.md`.
- [ ] When the work happened inside a service repo, hand the filled contract block to the root workspace owner. Do not link outward from the service.
- [ ] Report changed files, verification evidence, and deferred items.

## 15. Variants

- Wallet: classic CQRS with MediatR. The controller set is frozen: `WalletsController` and `AdminWalletsController` while the internal API is off. Run the Wallet architecture script. Adding a use case changes the frozen count; get explicit approval and update the count and script.
- Gateway: route-only. No controller, no DbContext, no pagination math.
- CheckHeal: no database, in-memory state, control endpoints protected by `X-Api-Key`, health probes bypass the key check.
- Log: append-only. Never expose update or delete for log entries.
- Paginated list: database pagination, `PagedData<T>`, shared query type when the service has one.
- Cross-service call: typed interface in Application, HttpClient in Infrastructure, DI registration, timeout/retry/fallback.
- Migration: plan first, additive only, snapshot and designer synchronized.

## 16. Anti-pattern gate

Reject the change if any of these appear:

- `IRepository<T>`, `GenericRepository`, or `UnitOfWork`.
- MediatR or CQRS outside Wallet.
- gRPC, RabbitMQ, MassTransit, Saga, Outbox, or Inbox.
- A query against another service's database.
- A singular collection route or a duplicate route alias.
- A new `/api/v1/internal/*` endpoint or a new `Controllers/Internal/` folder.
- `HasConversion<string>()` or a PostgreSQL enum type.
- Magic integers instead of named enum values.
- An `ERR_` prefix, a Title Case message, or a Vietnamese message.
- Raw integers or SCREAMING_SNAKE_CASE enum values in JSON.
- An unbounded list endpoint.
- Trusting a client-supplied user or owner identifier.
- Blanket `DeleteBehavior.Cascade`.
- `Guid.NewGuid()` in `HasData`.
- A secret in `appsettings.json` or source.
- A `ResultFilter` or manual envelope inside a microservice.

## 17. Definition of Done

The endpoint is done only when all of these are true:

- [ ] Contract is written and matches the code.
- [ ] Route, DTOs, validation, and error matrix are implemented.
- [ ] Pagination and ownership are enforced where relevant.
- [ ] Build passes with 0 errors.
- [ ] Tests pass, or the missing test project is explicitly recorded.
- [ ] API documentation is filed in the correct stage.
- [ ] Gateway route is added and verified when the endpoint is public.
- [ ] No forbidden pattern from section 16 is present.
- [ ] Session plan and history are updated.

See `references/checklist.md` for the copy-paste checklist, contract block, error matrix, and enum table. See `references/code-skeletons.md` for C# skeletons.
