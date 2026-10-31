# 03 — SECURITY HEADERS, INTERNAL API STATUS & IDENTITY GOVERNANCE

## 1. Public Controllers While the Internal API Is Frozen

Since 2026-10-31 the Internal API model is temporarily disabled. All new endpoints live in `{Service}.Api/Controllers/Public/` and use public route prefixes.

- `{Service}.Api/Controllers/Public/`: endpoints served through the API Gateway under `/api/v1/{resources}`.
- `{Service}.Api/Controllers/Internal/`: legacy folders may still exist, but their actions must not be registered, routed, or extended while the freeze is active.
- Do not create a new `Controllers/Internal/` folder and do not add a new `/api/v1/internal/*` endpoint.
- Never combine public and internal actions into a single controller file.

## 2. Inter-Service Communication During the Freeze

Inter-service calls use public REST routes, not an internal prefix:

- `POST /api/v1/notifications/email/otp` and `POST /api/v1/notifications/email/send`
- `POST /api/v1/wallets/checkout/direct`
- `POST /api/v1/inventories/initialize` and `GET /api/v1/inventories/{skuId:guid}`
- `POST /api/v1/logs/batch`

Rules:

- `InternalServiceAuthMiddleware` and `InternalServiceAuthHandler` remain in the repository, but their pipeline and DI registrations are commented out.
- Do not require `X-Internal-Service-Key` for these routes.
- The Gateway still strips any external `X-Internal-Service-Key` header as part of anti-spoofing.
- Path blocking for `/api/v1/internal` and `/internal/` is commented out. Those paths reach the backend like normal API routes instead of returning HTTP `404 Not Found`.
- YARP configuration must never declare a route for `/internal/`.
- Do not put new sensitive data on a public inter-service route while there is no service authentication.
- Re-enabling the old model requires explicit human approval and a synchronized change to middleware, handler, Gateway blocking, and documentation.

## 3. Active Anti-Spoofing & Identity Propagation

- **Active Anti-Header-Spoofing**: Gateway checks (case-insensitive) all untrusted external headers (`x-user-id`, `x-user-email`, `x-user-roles`, `x-user-permissions`, `x-internal-service-key`). If present, Gateway immediately aborts with HTTP `403 Forbidden` (`FORBIDDEN_HEADER_SPOOFING`).
- **Identity Propagation**: Gateway verifies the JWT Bearer token and injects verified claims downstream:
  - `x-user-id`: Unique user GUID.
  - `x-user-email`: User email address.
  - `x-user-roles`: Lowercase comma-separated roles (`buyer,seller,admin`).
  - `x-user-permissions`: Uppercase comma-separated permissions.
  - `x-client-ip`: Verified client IP.
  - `x-trace-id`: Distributed trace identifier.

## 4. Fine-Grained Authorization & Resource Ownership

- **Never trust client-supplied IDs**: Prohibit trusting `buyerId`, `userId`, `sellerId` passed via query parameters or route data.
- **Mandatory Ownership Guard**: Microservice controllers must use extension helpers:
  ```csharp
  if (!this.TryGetUserId(out var currentUserId, out var authError))
      return authError;

  if (!this.EnsureOwnership(resource.OwnerId, out var forbidError))
      return forbidError;
  ```
- If `currentUserId != resource.OwnerId` and the caller lacks role `admin` or `staff`, return HTTP `403 Forbidden` (`FORBIDDEN`, `"You do not have permission to access or modify this resource."`).
- If unauthenticated, return HTTP `401 Unauthorized` (`UNAUTHORIZED`).
