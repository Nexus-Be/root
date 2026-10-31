# 04 — AUDIT TRAIL, MUTATING ACTION LOGGING & LOG SERVICE INTEGRATION

## 1. Mandatory Audit Logging for Critical Mutating Operations
All state-modifying actions (`POST`, `PUT`, `PATCH`, `DELETE`) across the Nexus microservices must record immutable audit logs. Critical domains include:
* **User & Identity**:
  * User registration, email verification, password change, password reset.
  * Account lock/ban/unban, role/permission grant or revocation.
  * Seller registration submission, KYC review, approval, or rejection.
* **Financial & Wallet**:
  * VNPay topup initiation and webhook confirmation.
  * Balance withdrawal request, approval, processing, or rejection.
  * Peer-to-peer wallet transfer and order checkout debit/credit.
* **Commerce & Orders**:
  * Order placement, cancellation, price adjustment, and payment status update.
  * Sub-order delivery status progression.
* **Catalog & Inventory**:
  * Product creation, price changes, stock level updates, product archival/deletion.
* **Auctions**:
  * Auction creation, bid placement, cancellation, and settlement.
* **Fulfillment & Logistics**:
  * Warehouse creation, inventory stock-in/stock-out, shipment tracking dispatch.

## 2. Two-Tier Audit Tracking Standard
1. **Local Entity Auditing**:
   * All mutating domain entities inherit `AuditableEntity<Guid>`:
     * `CreatedAt`: `DateTimeOffset` (UTC)
     * `CreatedBy`: `Guid?` (Actor ID)
     * `UpdatedAt`: `DateTimeOffset?` (UTC)
     * `UpdatedBy`: `Guid?` (Actor ID)
   * The `DbContext.SaveChangesAsync` automatically populates these fields from `ICurrentUserService` or `HttpContextExtensions.GetUserId()`.

2. **Local Transactional Audit Row (Source of Truth)**:
   * Every audited operation writes one row into the service's own `AuditLogs` table through `_dbContext.AddAuditLog(...)` (`{Service}.Application/Common/Extensions/AuditLogExtensions.cs`).
   * The row is saved in the same transaction as the business change, so a rolled-back operation leaves no audit row.
   * Prohibit `new AuditLog { ... }` outside the extension. Prohibit `_logger.LogInformation` as a replacement for an audit row on a sensitive operation.
   * The row starts with `IsSynced = false`.
   * Column reference: `ServiceName`, `Action`, `EntityName`, `EntityId`, `UserId`, `UserName`, `OldValues`, `NewValues`, `ChangedColumns`, `TraceId`, `IpAddress`, `UserAgent`, `CreatedAt`, `IsSynced`.

3. **Optional Central Aggregation (`LogService`)**:
   * `LogService` is an aggregation sink for cross-service queries, not the transactional source of truth.
   * A background sync forwards rows with `IsSynced = false` to `POST /api/v1/logs/batch` without `X-Internal-Service-Key`, then marks them `IsSynced = true`.
   * Never call `LogService` over HTTP inside a business request or transaction. A network call there couples the business commit to another process and breaks the rollback guarantee.
   * Aggregated payload reference:
     ```json
     {
       "actorUserId": "11111111-1111-1111-1111-111111111111",
       "serviceName": "WalletService",
       "eventType": "WALLET_BALANCE_DEBITED",
       "action": "DEBIT",
       "entityName": "Wallet",
       "entityId": "22222222-2222-2222-2222-222222222222",
       "oldValue": "{\"balance\": 500000.00}",
       "newValue": "{\"balance\": 350000.00}",
       "clientIp": "192.168.1.10",
       "traceId": "0HNPGT7G285Q2",
       "occurredAt": "2026-10-31T05:30:00Z"
     }
     ```

## 3. Immutable Append-Only Invariant
* Audit records are permanent legal and diagnostic records.
* Both the per-service `AuditLogs` table and the `Logs` table in `LogService` are strictly **APPEND-ONLY**.
* Prohibit implementing any API endpoint or database query that modifies (`UPDATE`) or deletes (`DELETE`) audit records.
