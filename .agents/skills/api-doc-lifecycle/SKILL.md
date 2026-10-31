---
name: api-doc-lifecycle
description: Manage and synchronize API documentation across Nexus microservices. Scaffolds new API docs in docs/api/B_none/, synchronizes error matrices when C# service functions throw new errors, maps domain enums, and promotes completed APIs to docs/api/A_Active/ upon human verification. Use when authoring, updating, or reviewing API documentation.
---

# API Documentation Lifecycle & Governance Skill

This skill governs the entire lifecycle of REST API documentation in the Nexus ecosystem, ensuring 100% synchronization between C# implementation code, database enums, error matrices, and Frontend documentation.

---

## 1. The Dual-Stage Architecture

All API documentation is organized by service into two explicit lifecycle stages:

```text
docs/api/
├── README.md                     <-- Master index and integration guidelines
├── API_DOC_TEMPLATE.md           <-- Authoritative documentation structure template
├── B_none/                       <-- STAGE B: In-Progress / Backlog / Unverified APIs
│   ├── User/
│   ├── Catalog/
│   ├── Commerce/
│   ├── Auction/
│   ├── Fulfillment/
│   ├── Wallet/
│   ├── Notification/
│   ├── Log/
│   ├── CheckHeal/
│   └── Gateway/
└── A_Active/                     <-- STAGE A: Production-Ready / 100% Verified APIs
    ├── User/
    ├── Catalog/
    ├── Commerce/
    ├── Auction/
    ├── Fulfillment/
    ├── Wallet/
    ├── Notification/
    ├── Log/
    ├── CheckHeal/
    └── Gateway/
```

### Invariant Placement Rule
* When an API is being designed, scaffolded, coded, or mocked, its documentation **MUST** reside in `docs/api/B_none/{Service}/{ID}_{FEATURE}.md`.
* An API doc is moved to `docs/api/A_Active/{Service}/{ID}_{FEATURE}.md` **ONLY AFTER**:
  1. `dotnet build` succeeds with 0 errors.
  2. `dotnet test` passes 100% on the service solution.
  3. The Human Operator (Sếp) explicitly confirms the API is completed (e.g. *"API này đã xong, chuyển sang active"*).

---

## 2. Invariant API Design Standards

Every generated or modified API document must strictly conform to these rules:

1. **100% Plural Route Convention:**
   * All domain resource collection endpoints must use lowercase plural nouns:
     * `/api/v1/users`, `/api/v1/admin/users`, `/api/v1/sellers`
     * `/api/v1/products`, `/api/v1/categories`, `/api/v1/variants`
     * `/api/v1/carts`, `/api/v1/orders`, `/api/v1/sub-orders`, `/api/v1/checkouts`
     * `/api/v1/shipments`, `/api/v1/warehouses`, `/api/v1/inventories`
     * `/api/v1/auctions`, `/api/v1/bids`
     * `/api/v1/wallets`, `/api/v1/wallets/transactions`, `/api/v1/wallets/withdrawals`
     * `/api/v1/notifications`, `/api/v1/logs`
   * Singular collection paths (e.g. `/api/v1/cart`, `/api/v1/product`, `/api/v1/user`, `/api/v1/order`) are **STRICTLY PROHIBITED**.
   * Allowed singleton exceptions: `/api/v1/me` (current caller's profile/context) and `/api/v1/auth` (procedural auth actions).
2. **Error Standards:**
   * `errorCode`: Must be uppercase `SCREAMING_SNAKE_CASE` (e.g. `USER_NOT_FOUND`, `VAL_INVALID_INPUT`).
   * `message`: Must be 100% English `Sentence case` (e.g. `"User not found with the specified ID."`).
3. **Data Envelope Standard:**
   * Single entity read/write: `ApiResponse<T>` with `success: true`, `statusCode`, `message`, `data`, `traceId`, `timestamp`.
   * Paginated collection: `ApiResponse<PagedData<T>>` with `data: { items: [...], pagination: { pageIndex, pageSize, totalCount, totalPages, hasPreviousPage, hasNextPage } }`.
   * Deletion or empty result: HTTP `204 NoContent` without body.
4. **Enum Governance:**
   * PostgreSQL database: 100% `integer` (32-bit signed int). Prohibit strings in DB.
   * REST API Output/Input: 100% PascalCase string via `PascalCaseJsonStringEnumConverter`.

---

## 3. Workflow 1: Scaffold API Doc (`scaffold`)

When creating a new API doc:
1. Locate the feature's code in `{Service}.Api/Controllers/{Feature}Controller.cs` and `{Service}.Application/Services/{Feature}/`.
2. Determine the service folder: `docs/api/B_none/{Service}/`.
3. Choose the filename pattern: `{ID}_{ACTION_NAME}.md` (e.g. `01_AUTH_REGISTER.md`, `15_PRODUCTS_CREATE.md`).
4. Populate all 7 sections based on `docs/api/API_DOC_TEMPLATE.md`:
   - **Section 1: Description & RBAC**
   - **Section 2: Code Trace:**
     - Record Microservice path.
     - Record Controller action method name.
     - Record Application interface and implementation function name.
     - Record Domain Entity and database table name.
     - Record Typed REST Client if calling another service.
   - **Section 3: Validation & Input Schema**
   - **Section 4: Response Envelope Sample**
   - **Section 5: Error Handling Matrix**
   - **Section 6: Domain Enums Table**
   - **Section 7: Completion Checklist** (status marked as `⏳ IN_PROGRESS`).

---

## 4. Workflow 2: Synchronize Error Matrix (`sync-errors`)

Whenever a developer or agent edits a service function or controller:
1. Scan the C# function implementation for:
   - Thrown domain exceptions (e.g. `throw new NotFoundException(...)`, `throw new ConflictException(...)`, `throw new BusinessException(...)`).
   - FluentValidation rules and invalid argument conditions.
   - External client failures (e.g. `HttpResponseMessage.IsSuccessStatusCode == false`).
2. Open the corresponding API doc file in `docs/api/B_none/{Service}/` (or `docs/api/A_Active/{Service}/`).
3. Compare the detected error codes and trigger conditions with Section 5 (RFC 9110 Error Matrix).
4. If an error code is missing:
   - Add a new row to Section 5 with HTTP Status, `SCREAMING_SNAKE_CASE` code, English Sentence-case message, and the exact code trigger condition.
   - Maintain sorted order by HTTP Status Code (`400`, `401`, `403`, `404`, `409`, `500`).

---

## 5. Workflow 3: Extract Domain Enums (`extract-enums`)

Whenever an entity or DTO contains enum properties:
1. Locate the C# `enum` definition in `{Service}.Domain/Enums/` or `{Service}.Application/`.
2. Inspect the integer values assigned to each enum member (starting from `0`).
3. Open Section 6 of the API doc.
4. Populate the table with:
   - C# Enum Name (e.g. `OrderStatus`).
   - Database Value (e.g. `0`, `1`, `2`).
   - API String Value (e.g. `Pending`, `Processing`, `Delivered`).
   - Business meaning in Vietnamese.

---

## 6. Workflow 4: Promote to Active (`promote-active`)

When the user instructs that an API is verified or complete (e.g. *"API 01_AUTH_REGISTER đã xong"*):
1. **Verify automated tests:** Run `dotnet test src/Services/{Service}/{Service}.sln -c Release` and ensure 100% pass.
2. **Update Checklist:** In the API doc, check all items in Section 7 and update status to `✅ COMPLETED`.
3. **Move file:**
   ```bash
   mv docs/api/B_none/{Service}/{FileName}.md docs/api/A_Active/{Service}/{FileName}.md
   ```
4. **Update Master README:** Update `docs/api/README.md` catalog table to link to the new path in `A_Active/{Service}/`.
