# Nexus API Gateway — Frontend Developer & Intern Quickstart Guide
## Standalone Mock Mode, Auth Bypass & Local Infrastructure

> **Target Audience**: Frontend Developers, Interns, Freshers, and QA Engineers.  
> **Prerequisites**: Docker Desktop (or .NET 8 SDK if running locally). No backend microservices or database knowledge required!  
> **Last Updated**: 2026-10-26  

---

## Table of Contents
1. [Overview: The Frontend Mental Model](#1-overview-the-frontend-mental-model)
2. [Gateway Infrastructure Architecture](#2-gateway-infrastructure-architecture)
3. [The Two Core Switches](#3-the-two-core-switches)
   - [Switch 1: Mock Mode vs. Real Mode](#switch-1-mock-mode-vs-real-mode-stateless-vs-stateful)
   - [Switch 2: Authentication Mode (Enforce vs. Bypass)](#switch-2-authentication-mode-enforce-vs-bypass)
4. [Step-by-Step: How to Run the Gateway](#4-step-by-step-how-to-run-the-gateway)
   - [Option A: Running via Docker Compose (Recommended)](#option-a-running-via-docker-compose-recommended)
   - [Option B: Running via .NET 8 CLI / IDE](#option-b-running-via-net-8-cli--ide)
5. [Configuration Deep Dive (Where and How to Change Settings)](#5-configuration-deep-dive)
   - [Method 1: Environment Variables in `.env`](#method-1-environment-variables-in-env)
   - [Method 2: Runtime Configuration File (`gateway.runtime.json`)](#method-2-runtime-configuration-file-gatewayruntimejson)
   - [Method 3: Per-Request HTTP Header Overrides](#method-3-per-request-http-header-overrides)
6. [CORS Configuration (Connecting Your Frontend Dev Server)](#6-cors-configuration-connecting-your-frontend-dev-server)
7. [API Response Envelope Format](#7-api-response-envelope-format)
8. [Troubleshooting & FAQ](#8-troubleshooting--faq)

---

## 1. Overview: The Frontend Mental Model

As a frontend developer on the Nexus project:
- **You do NOT need to run 8+ microservices** (`User`, `Catalog`, `Commerce`, `Wallet`, `Auction`, `Fulfillment`, `Notification`, `Log`).
- **You do NOT need to install or run PostgreSQL databases**.
- **You do NOT need RabbitMQ message brokers**.
- **You only ever talk to ONE endpoint: The Nexus API Gateway on `http://localhost:8080`**.

```
┌────────────────────────────────────────────────────────┐
│                   YOUR FRONTEND APP                    │
│   (React / Next.js / Vue / Vite running on localhost)   │
└───────────────────────────┬────────────────────────────┘
                            │ HTTP Requests
                            ▼
┌────────────────────────────────────────────────────────┐
│               NEXUS API GATEWAY (Port 8080)            │
│  - Single entry point for all URLs: /api/v1/...        │
│  - Built-in Mock Engine (stateless sample data)        │
│  - Authentication Bypass for testing                   │
└──────────────┬──────────────────────────┬──────────────┘
               │                          │
       [ If Mode = Mock ]         [ If Mode = Real ]
               │                          │
               ▼                          ▼
      ┌─────────────────┐       ┌───────────────────┐
      │  Seeds/*.json   │       │ Real Backends     │
      │ (Instant mock   │       │ (REST Services    │
      │  responses)     │       │  & Cloud DBs)     │
      └─────────────────┘       └───────────────────┘
```

The Gateway includes a built-in **Stateless Mock Engine**. When running in Mock mode, the Gateway intercepts your requests and immediately returns pre-seeded, realistic sample JSON data (from `Seeds/`) matching the exact production API contracts.

This allows you to develop, test, and polish the user interface and user experience (UI/UX) without depending on unfinished backend code or volatile database states.

---

## 2. Gateway Infrastructure Architecture

When running the Gateway independently for frontend testing, only a minimal set of supporting infrastructure services is needed:

| Service | Container Name | Port | Required for Frontend Mock? | Description |
| :--- | :--- | :--- | :--- | :--- |
| **API Gateway** | `nexus-apigateway` | `8080` | **Mandatory** | The primary HTTP entry point and mock server. Exposes Swagger at `/swagger`. |
| **Redis** | `nexus-shared-redis` | `6379` | **Recommended** | High-speed cache used for distributed rate limiting and User OTP/Cache (capped at 500MB). *(Note: in development mode, Gateway fails-open if Redis is absent, but running Redis prevents rate-limit warnings).* |
| **Tempo** | `nexus-shared-tempo` | `3200`, `4317` | Optional | Distributed tracing backend. |
| **RabbitMQ** | `nexus-shared-rabbitmq` | `5672` | **Not Needed** | Message broker for backend async event buses. Gateway does not need it. |
| **PostgreSQL** | — | — | **Not Needed** | Database storage. All real databases are hosted remotely on Neon Cloud; in Mock mode, no database connection is touched at all. |

---

## 3. The Two Core Switches

The Gateway provides two independent switches designed specifically for frontend integration and testing.

### Switch 1: Mock Mode vs. Real Mode (Stateless vs. Stateful)

This switch determines whether an API endpoint returns **stateless mock fixture data** or calls the **real backend microservice via RESTful HTTP**.

| Setting Value | Mode | Description |
| :--- | :--- | :--- |
| `"Mock"` | **Stateless Mock (Default for FE)** | Gateway reads realistic JSON fixture files from `src/Services/ApiGateway/Nexus.Gateway/Seeds/{service}/{operation}.json`. It returns standard `ApiResponse<T>` envelopes immediately without calling any backend. |
| `"Real"` | **Stateful Backend** | Gateway forwards the request to the corresponding microservice via HTTP REST. Requires the backend service to be running. |

Each service has its own independent switch:
- `users`: User profiles, registration, OTP.
- `catalog`: Product list, categories, brands, inventory.
- `commerce`: Shopping carts, checkout, order management.
- `wallet`: Balances, transactions, deposits, withdrawals.
- `auction`: Bidding, auction item listings.
- `fulfillment`: Shipping estimates, tracking, warehouses.
- `notification`: User notifications, system alerts.
- `log`: Activity logs.

---

### Switch 2: Authentication Mode (Enforce vs. Bypass)

This switch controls whether the Gateway strictly enforces JWT Bearer tokens and role-based permissions (`[Authorize]`).

```
                    Incoming HTTP Request
                              │
                    [ Check Gateway:AuthMode ]
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
       [ "Enforce" ]                 [ "Bypass" ]
       (Production)                (Development Only)
               │                             │
    Does request have valid                  │
    Authorization: Bearer <jwt>?             │
         ├── Yes ──► Proceed to Controller   │
         └── No  ──► 401 Unauthorized        │
                                             ▼
                               Automatically synthesize a
                               Mock Identity (ClaimsPrincipal):
                               - UserId: 11111111-1111-1111-1111-000000000004
                               - Roles: Buyer, Seller, Staff, Admin
                                             │
                                             ▼
                               Proceed to Controller without 401/403!
```

| Setting Value | Behavior | Use Case |
| :--- | :--- | :--- |
| `"Enforce"` *(Default)* | Strict mode. Requires a valid JWT token on protected endpoints. Missing token results in `401 Unauthorized`. Insufficient role permissions results in `403 Forbidden`. | Use when testing the complete authentication and login flow with real tokens. |
| `"Bypass"` | **Bypass mode (Development only)**. If no token is provided, Gateway automatically injects a mock identity with full privileges (`Buyer`, `Seller`, `Staff`, `Admin`). | **Ideal for Interns & Frontend UI devs!** Allows you to test protected pages (Cart, Checkout, User Settings, Seller Dashboard) without needing to log in first. |

> 🔒 **Security Guardrail**: `AuthMode: "Bypass"` is strictly prohibited in production and will cause the Gateway to fail fast on startup if `ASPNETCORE_ENVIRONMENT != Development`. Internal gateway administrative endpoints (`/api/v1/gateway/*`) are never bypassed.

---

## 4. Step-by-Step: How to Run the Gateway

### Option A: Running via Docker Compose (Recommended)

This is the fastest method because you don't need to install the .NET SDK.

#### Step 1: Clone the repository and navigate to root
```bash
git clone https://github.com/Nexus-Be/root.git Nexus-Be
cd Nexus-Be
git checkout dev
```

#### Step 2: Configure your `.env` file
Ensure your `.env` file in the root directory contains the following settings:
```dotenv
# Run in Development mode
ASPNETCORE_ENVIRONMENT=Development

# Enable Authentication Bypass so you don't need login tokens
GATEWAY_AUTH_MODE=Bypass

# Gateway Port
GATEWAY_PORT=8080
```

#### Step 3: Start the Gateway and supporting containers
Run this single command from the root folder:
```bash
docker compose up -d gateway
```

*What happens behind the scenes?*
- Docker Compose detects that `gateway` depends on `redis` and `tempo`.
- It will automatically launch `redis`, `tempo`, and build/start `gateway`.
- It will **not** start any microservices or databases.

#### Step 4: Verify that Gateway is running
Open your browser and navigate to:
👉 **`http://localhost:8080/swagger`**

You should see the Swagger UI listing all API endpoints (Catalog, Commerce, Users, Wallet, etc.). You can click **Try it out** on any endpoint (e.g. `GET /api/v1/catalog/products`) and see mock data returned immediately!

#### Useful Docker commands:
```bash
# View Gateway live logs:
docker compose logs -f gateway

# Restart the Gateway after editing configuration:
docker compose restart gateway

# Stop all containers when done:
docker compose down
```

---

### Option B: Running via .NET 8 CLI / IDE

If you have `.NET 8 SDK` installed and prefer running natively for instant code changes or faster startup:

#### Step 1: Start Redis using Docker
The Gateway uses Redis for distributed rate limiting. Start just Redis in the background:
```bash
docker compose up -d redis
```

#### Step 2: Run the Gateway project
From the root directory:
```bash
dotnet run --project src/Services/ApiGateway/Nexus.Gateway
```
Or open `Nexus.Gateway.sln` inside `src/Services/ApiGateway/` using Visual Studio / JetBrains Rider / VS Code and press **F5 (Debug)** or **Ctrl+F5 (Run)**.

#### Step 3: Access Swagger UI
Open: `http://localhost:8080/swagger`

---

## 5. Configuration Deep Dive

You can configure the switches using any of the following 3 methods:

### Method 1: Environment Variables in `.env`

In Docker Compose, environment variables override any JSON files.

Create or update `.env` in the root of the project:

```dotenv
# =============================================================================
# FRONTEND MOCK CONFIGURATION
# =============================================================================
ASPNETCORE_ENVIRONMENT=Development

# Switch 2: Bypass authentication (No JWT required)
GATEWAY_AUTH_MODE=Bypass

# Switch 1: Explicitly force services to Mock mode (optional, already default in runtime.json)
Gateway__Services__catalog__Mode=Mock
Gateway__Services__commerce__Mode=Mock
Gateway__Services__users__Mode=Mock
Gateway__Services__wallet__Mode=Mock
Gateway__Services__auction__Mode=Mock
Gateway__Services__fulfillment__Mode=Mock
Gateway__Services__notification__Mode=Mock
```

Apply changes:
```bash
docker compose up -d gateway
```

---

### Method 2: Runtime Configuration File (`gateway.runtime.json`)

The Gateway loads `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`. This file supports **Hot-Reloading** (changes take effect without restarting the server!).

Open `src/Services/ApiGateway/Nexus.Gateway/gateway.runtime.json`:

```json
{
  "Gateway": {
    "AuthMode": "Bypass",
    "AllowClientModeOverrideInDevelopment": true,
    "AllowAnonymousMockAuthInDevelopment": true,
    "DefaultMockUserId": "11111111-1111-1111-1111-000000000004",
    "DefaultMockRole": "Buyer",
    "Services": {
      "catalog": {
        "Mode": "Mock"
      },
      "commerce": {
        "Mode": "Mock"
      },
      "users": {
        "Mode": "Mock"
      },
      "wallet": {
        "Mode": "Mock"
      },
      "auction": {
        "Mode": "Mock"
      },
      "fulfillment": {
        "Mode": "Mock"
      },
      "notification": {
        "Mode": "Mock"
      },
      "log": {
        "Mode": "Mock"
      }
    }
  }
}
```

- To switch a service to real backend later: change `"Mode": "Mock"` to `"Mode": "Real"`.
- To enforce tokens: change `"AuthMode": "Bypass"` to `"AuthMode": "Enforce"`.

---

### Method 3: Per-Request HTTP Header Overrides

During testing, you can override settings for a single request without modifying any config files:

#### 1. Override Service Mode:
Send the header `X-Service-Mode-{service-name}`:
```http
GET /api/v1/catalog/products HTTP/1.1
Host: localhost:8080
X-Service-Mode-catalog: Real
```
*Result*: Even if `catalog` is configured as `Mock` globally, this specific request will try to call the real backend service.

#### 2. Enforce Authentication on a Mock Endpoint:
When `AuthMode` is `Bypass`, you can test how your frontend handles a missing token by sending:
```http
X-Mock-Enforce-Auth: true
```
*Result*: The Gateway will reject the request with `401 Unauthorized` if no `Authorization: Bearer <token>` header is attached.

---

## 6. CORS Configuration (Connecting Your Frontend Dev Server)

By default, the Gateway allows cross-origin requests (CORS) from standard local frontend ports.

In `gateway.runtime.json`:
```json
"CorsOrigins": [
  "http://localhost:3000",
  "http://localhost:3001",
  "http://localhost:5173"
]
```

| Frontend Framework | Typical Default URL | Included by Default? |
| :--- | :--- | :--- |
| Next.js / Create React App | `http://localhost:3000` | ✅ Yes |
| Secondary React Instance | `http://localhost:3001` | ✅ Yes |
| Vite (React / Vue / Svelte) | `http://localhost:5173` | ✅ Yes |
| Angular | `http://localhost:4200` | ⚠️ Add to `CorsOrigins` if needed |

If your frontend runs on a different port (e.g., `8080` or `4200`), simply add your port to the `"CorsOrigins"` array in `gateway.runtime.json`.

---

## 7. API Response Envelope Format

All responses returned by the Gateway are wrapped in a standard, consistent envelope:

### Successful Response (`200 OK`, `201 Created`):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Products retrieved successfully.",
  "data": {
    "items": [
      {
        "id": "22222222-2222-2222-2222-000000000001",
        "name": "Nexus Pro Wireless Mechanical Keyboard",
        "price": 1250000,
        "status": "Active"
      }
    ],
    "pagination": {
      "pageIndex": 1,
      "pageSize": 20,
      "totalCount": 1,
      "totalPages": 1,
      "hasPreviousPage": false,
      "hasNextPage": false
    }
  },
  "traceId": "0HNPGT7G285Q2",
  "timestamp": "2026-10-26T14:30:00Z"
}
```

### Error Response (RFC 9110 ProblemDetails):
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errorCode": "VAL_INVALID_INPUT",
  "detail": "Product name is required.",
  "errors": {
    "name": [
      "Product name is required."
    ]
  },
  "traceId": "0HNPGT7G285Q2",
  "timestamp": "2026-10-26T14:30:00Z"
}
```

---

## 8. Troubleshooting & FAQ

### Q1: I am receiving `401 Unauthorized` on my requests!
- **Reason**: The Gateway is running with `AuthMode: "Enforce"`, and your frontend is not sending an `Authorization: Bearer <token>` header.
- **Solution**: Set `GATEWAY_AUTH_MODE=Bypass` in `.env` (or `"AuthMode": "Bypass"` in `gateway.runtime.json`), then restart or re-save.

### Q2: I am receiving `502 Bad Gateway` or `Connection refused`!
- **Reason**: The service you are calling is set to `"Mode": "Real"`, but the backend microservice is not running on your machine.
- **Solution**: Open `gateway.runtime.json` or check your `.env`. Make sure the service has `"Mode": "Mock"`.

### Q3: My browser console reports a CORS error: `Access to fetch at ... from origin ... has been blocked by CORS policy`!
- **Reason**: Your frontend is running on a port not listed in `"CorsOrigins"`.
- **Solution**: Open `gateway.runtime.json` and add your frontend origin (e.g., `"http://localhost:4200"`) to `"CorsOrigins"`.

### Q4: I receive `429 Too Many Requests`!
- **Reason**: Distributed rate limiting has been triggered due to too many rapid requests.
- **Solution**: The default limit is 100 requests per minute. You can increase `PermitLimit` in `gateway.runtime.json` under `"RateLimits"`.

### Q5: How do I change the mock data returned by an endpoint?
- **Answer**: The mock JSON files are stored under:
  ```
  src/Services/ApiGateway/Nexus.Gateway/Seeds/{service}/{operation}.json
  ```
  Edit the JSON file directly. Because Mock Engine reads from disk or in-memory seeds, the updated data will be returned on subsequent calls.

---

## Summary Checklist for Interns

```markdown
- [ ] Run `docker compose up -d gateway` from the root folder.
- [ ] Confirm `GATEWAY_AUTH_MODE=Bypass` in `.env`.
- [ ] Verify `http://localhost:8080/swagger` is accessible.
- [ ] Configure frontend API client base URL to `http://localhost:8080`.
- [ ] Start building and testing frontend UI with 100% Mock data!
```
