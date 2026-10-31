# 02 — API ROUTING, ENVELOPES & PAGINATION GOVERNANCE

## 1. 100% Plural Route Convention
All resource collection routes across the Nexus ecosystem must strictly use lowercase plural nouns (kebab-case for compound words):
* User & Identity: `/api/v1/users`, `/api/v1/users/{userId}`, `/api/v1/admin/users`, `/api/v1/sellers`.
* Catalog & Products: `/api/v1/products`, `/api/v1/products/{productId}`, `/api/v1/categories`, `/api/v1/variants`.
* Commerce & Orders: `/api/v1/carts`, `/api/v1/orders`, `/api/v1/orders/{orderId}`, `/api/v1/sub-orders`, `/api/v1/checkouts`.
* Fulfillment & Logistics: `/api/v1/shipments`, `/api/v1/warehouses`, `/api/v1/inventories`.
* Auction & Bidding: `/api/v1/auctions`, `/api/v1/bids`.
* Financials & Wallet: `/api/v1/wallets`, `/api/v1/wallets/transactions`, `/api/v1/wallets/withdrawals`.
* Observability: `/api/v1/notifications`, `/api/v1/logs`.
* **Contextual Singleton Exceptions**:
  * `/api/v1/me`: Represents the authenticated calling user.
  * `/api/v1/auth`: Non-resource authentication actions (`login`, `register`, `otp/verify`).
* **Strict Prohibition**: Prohibit singular nouns for collections (`/api/v1/cart`, `/api/v1/product`, `/api/v1/user`, `/api/v1/order`).

## 2. No Duplicate Route Aliases & XML Summaries
* Never declare duplicate route attributes on the same action (e.g. prohibited: `[HttpGet("log/logs")]` and `[HttpGet("admin/logs")]` on a single method).
* Use single-line XML `<summary>` tags directly on controller action methods. Do not write multiline section banners.

## 3. Pure DTO Return & Zero ResultFilter at Microservices
* Backend microservices return pure domain DTOs:
  * Single Read / Write: `return Ok(dto);` or `return StatusCode(201, dto);`.
  * Deletion or Empty Operations: Return HTTP `204 NoContent` (`return NoContent();`).
  * Paginated Collections: `return Ok(pagedData);`.
* **Zero ResultFilter at Microservices**: Do NOT implement or register `ResultFilter` or manual envelope factories inside microservices.
* **Gateway Edge Envelope Wrapping**: Gateway's `ResponseEnvelopeMiddleware` automatically wraps raw 200/201 JSON into `ApiResponse<T>` / `ApiResponse<PagedData<T>>`. If downstream response contains a `"message"` property, Gateway automatically propagates it into the envelope.

## 4. System Pagination Governance
* **100% Database-Level Calculation**: Only the microservice owning the database computes pagination via `.Skip((page - 1) * pageSize).Take(pageSize)` and `.CountAsync()`.
* **Standard PagedData Envelope**:
  ```json
  {
    "items": [ ... ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 100,
      "totalPages": 5,
      "hasPreviousPage": false,
      "hasNextPage": true
    }
  }
  ```
* **Stateless Gateway**: Gateway never buffers raw unpaginated records in RAM to slice pages. It passes through or wraps the microservice's `PagedData<T>`.
