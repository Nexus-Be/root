# Endpoint Checklist and Templates

Copy this file into the session plan or use it as a review sheet. Tick every box that applies and write `N/A - <reason>` for the ones that do not.

## 1. Copy-paste checklist

### Preflight

- [ ] Read root `AGENTS.md` and `.agents/rules/01` through `06`.
- [ ] Read the service `AGENTS.md`, `.agents/rules/01` through `06`, and `specs/00` through `05`.
- [ ] Read the nearest existing controller, feature service, requests/responses, and tests.
- [ ] Run GitNexus impact for every symbol to change and recorded the risk.
- [ ] Contract is unambiguous.
- [ ] Session plan file created.

### Contract

- [ ] Route is `/api/v1/{plural}` or a documented `/me` / `/auth` exception.
- [ ] HTTP method matches RFC 9110.
- [ ] RBAC policy and ownership rule are named.
- [ ] Request and response records are defined.
- [ ] Status codes are listed.
- [ ] Error codes and messages are listed.
- [ ] Enums are listed with integer DB value and PascalCase API value.
- [ ] Pagination is defined for list endpoints.
- [ ] Idempotency is defined for retryable mutations.
- [ ] Internal API remains off.

### Persistence

- [ ] Entity and configuration are correct.
- [ ] Enum values are explicit integers.
- [ ] Soft delete filter is present.
- [ ] Indexes and precision are present.
- [ ] Migration is additive and named with a timestamp.
- [ ] Snapshot and designer are synchronized.
- [ ] Seeds use deterministic GUIDs.
- [ ] No destructive SQL.

### Application

- [ ] Feature folder has interface, service, requests, responses.
- [ ] Service injects `I{Service}DbContext` directly.
- [ ] Reads use `AsNoTracking()`.
- [ ] Writes use one transaction where multiple rows change.
- [ ] Audit log is written for sensitive mutations.
- [ ] Pagination runs in SQL.
- [ ] Errors use stable codes and English messages.
- [ ] Typed client interface, implementation, and DI registration are correct.

### Api

- [ ] Controller is in `Controllers/Public/` and named `{Feature}Controller`.
- [ ] `[ApiController]`, one `[Route]`, one route attribute per action.
- [ ] One-line XML `<summary>` per action.
- [ ] Only the feature service (or `ISender`) is injected.
- [ ] Identity comes from `HttpContext`, never from the client.
- [ ] Ownership and admin checks are present.
- [ ] DTO is returned directly.
- [ ] Delete returns `204`.
- [ ] No `ResultFilter` and no manual envelope.

### Tests

- [ ] Happy path covered.
- [ ] Every error code covered.
- [ ] Pagination boundaries covered.
- [ ] Ownership `401` and `403` covered.
- [ ] Enum serialization covered.
- [ ] Swagger route and query covered.
- [ ] `dotnet test` passes 100%, or the missing test project is recorded.

### Documentation

- [ ] `docs/api/B_none/{Service}/{ID}_{FEATURE}.md` created from the template.
- [ ] Seven sections are complete.
- [ ] Error matrix is complete and sorted.
- [ ] Enum table is complete.
- [ ] `docs/api/README.md` updated.
- [ ] `docs/FRONTEND_API_ENDPOINT_MAPPING.md` updated.
- [ ] Service `specs/02_API_REST_CONTRACTS.md` updated.
- [ ] Inter-service matrix updated when needed.
- [ ] Gateway routing catalog updated when needed.
- [ ] Promotion to `A_Active` is left for operator acceptance.

### Gateway

- [ ] Route and cluster added to `appsettings.json` and the example file.
- [ ] Path and order are correct.
- [ ] Admin routes are split per domain.
- [ ] No `/internal` route.
- [ ] Anti-spoofing and identity propagation are intact.
- [ ] Envelope and pagination wrapping are intact.
- [ ] Gateway tests updated and passing.
- [ ] Swagger aggregation hides internal paths.

### Verification and handoff

- [ ] Service build has 0 errors.
- [ ] Service tests pass 100%, or the gap is recorded.
- [ ] Relevant probe scripts pass.
- [ ] Gateway curl checks pass.
- [ ] GitNexus `detect_changes` reviewed.
- [ ] No build output or secret is staged.
- [ ] Session plan and history updated.

## 2. Contract block

Fill this block before coding and keep it in the session plan.

```text
Endpoint: <METHOD> /api/v1/<plural-resource>
Service: <Service>Service (port <port>)
Feature: <Feature>
RBAC: <AllowAnonymous | Buyer | Seller | StaffOrAdmin | Admin>
Ownership: <none | owner-only | owner-or-admin>
Idempotency: <none | optional Idempotency-Key>
Pagination: <none | page/pageSize, default 1/20, max 100>

Request:
<field>: <type>, <required|optional>, <constraint>

Response:
<status>: <shape>

Errors:
<status> <CODE> - <message> - <trigger>

Database:
<entity/table>: <change>

Downstream:
<service>: <METHOD path>, <timeout>, <fallback>

Docs:
docs/api/B_none/<Service>/<ID>_<FEATURE>.md
```

## 3. Error matrix template

| HTTP | errorCode | Message | Trigger |
|:---|:---|:---|:---|
| 400 | `VAL_INVALID_INPUT` | `Input validation failed.` | A request field violates its constraint. |
| 401 | `UNAUTHORIZED` | `Authentication is required to access this resource.` | The caller has no valid identity. |
| 403 | `FORBIDDEN` | `You do not have permission to access or modify this resource.` | The caller is not the owner and is not admin or staff. |
| 404 | `<RESOURCE>_NOT_FOUND` | `<Resource> not found with the specified ID.` | The record does not exist or is deleted. |
| 409 | `<RESOURCE>_CONFLICT` | `<Resource> is already in the requested state.` | A uniqueness or state transition rule fails. |
| 500 | `INTERNAL_SERVER_ERROR` | `An unexpected error occurred while processing the request.` | An unhandled server failure occurs. |

Rules: SCREAMING_SNAKE_CASE codes, English sentence-case messages, no `ERR_` prefix, no Vietnamese, sorted by HTTP status.

## 4. Enum table template

| Enum | Database value | API value | Meaning |
|:---|:---:|:---|:---|
| `<EnumName>.<Member>` | `0` | `"<Member>"` | <short business meaning> |

Rules: database stores integers from `0`; API emits PascalCase strings; inbound JSON accepts PascalCase and rejects integers.

## 5. Verification evidence block

```text
dotnet build <Service>.sln -c Release
  result: <0 errors / 0 warnings>

dotnet test <Service>.sln -c Release
  result: <N/N passed | no test project in this repo>

bash tools/verify-swagger.sh
  result: <PASS/FAIL summary>

curl -s -o /dev/null -w '%{http_code}' <url>
  result: <status>

git status --short
  result: <clean | expected files only>
```

## 6. Handoff block for a service repository

A service repository must not link to the root workspace. Copy this block into the handoff message so the root owner can file the API doc.

```text
Service: <Service>Service (port <port>)
Endpoint: <METHOD> /api/v1/<plural-resource>
Feature: <Feature>
Controller: <File> -> <Action>
Application: <File> -> <Method>
Entity/Table: <Entity> / <Table>
RBAC: <policy>
Ownership: <rule>
Pagination: <none | page/pageSize>
Request: <fields and constraints>
Response: <status and shape>
Errors: <status, code, message, trigger>
Enums: <enum, int, PascalCase>
Tests: <file names and result>
Build: <result>
Notes: <migration, downstream call, deferred item>
```
