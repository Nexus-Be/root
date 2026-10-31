# 06 — DATABASE PERSISTENCE, MIGRATIONS & SEED GOVERNANCE

## 1. Database-per-Service Isolation
* Each microservice strictly owns an independent PostgreSQL database on port range `5433`-`5440`:
  * `User`: `usermanagement_db:5433`
  * `Catalog`: `category_db:5434`
  * `Commerce`: `commerce_db:5435`
  * `Log`: `log_db:5436`
  * `Auction`: `auction_db:5437`
  * `Fulfillment`: `fulfillment_db:5438`
  * `Notification`: `notification_db:5439`
  * `Wallet`: `wallet_db:5440`
  * `CheckHeal`: In-memory state, zero local database.
  * `Gateway`: Edge reverse proxy, zero database.
* Prohibit cross-database joins, dblink, foreign data wrappers, or shared DbContext.

## 2. Entity & Fluent API Configuration Standards
* **Table Naming**: Default PascalCase matching DbSet entity name.
* **Primary Key**: Mandatory `Guid` for all business entities (`BaseEntity<Guid>`, `AuditableEntity<Guid>`).
* **Foreign Keys & DeleteBehavior**: Prefer `DeleteBehavior.Restrict` or `DeleteBehavior.SetNull`. Prohibit unconstrained `DeleteBehavior.Cascade` causing cycle errors or unintentional data cascading.
* **Soft Delete**: Every entity must declare `IsDeleted` (boolean) and `DeletedAt` (DateTimeOffset?). Enforce global query filter:
  ```csharp
  builder.HasQueryFilter(x => !x.IsDeleted);
  ```
* **Performance Indexes**: All foreign keys and frequently filtered columns (`Email`, `Username`, `Status`, `CreatedAt`) must have explicit indexes. Use filtered unique index for nullable unique columns:
  ```csharp
  builder.HasIndex(x => x.Email).IsUnique().HasFilter("\"Email\" IS NOT NULL");
  ```
* **Currency Precision**: Monetary columns (`Balance`, `Price`, `Amount`) must explicitly configure `HasPrecision(18, 2)`.

## 3. Seed Data Standards
* Seed data must be declared via `HasData()` in `OnModelCreating` or seed helper classes.
* **Deterministic GUIDs**: Primary keys in seed data must use fixed deterministic GUIDs (`Guid.Parse("11111111-1111-1111-1111-111111111111")`). Prohibit `Guid.NewGuid()` in seeds causing migration snapshot churn.
* **Password Hashing**: Sample passwords must be hashed with BCrypt with salt (`$2a$11$...`). Never commit plain text passwords.

## 4. EF Core Migration Lifecycle
* **Zero Destructive Migrations**: Prohibit adding `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, or `RENAME COLUMN` without explicit human authorization.
* **Safe Startup Auto-Migration**: Service calls `db.Database.Migrate()` only when `db.Database.IsRelational()` is true, wrapped inside a `try-catch` block logging warnings to avoid crashing when DB is initializing.
