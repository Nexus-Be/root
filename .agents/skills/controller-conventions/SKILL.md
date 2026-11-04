---
name: controller-conventions
description: Canonical standards for ASP.NET Core thin controllers across Nexus microservices. Covers boundary validation, Application-layer shared request/response DTOs, English sentence-case error messages, HTTP status codes, and the structural reference controller blueprint.
---

# REST Controller Conventions & Standards

This skill defines the invariant structural and boundary rules for all ASP.NET Core REST API controllers across the Nexus microservice ecosystem.

Controllers serve strictly as **HTTP Transport Boundary Adapters**. They bind incoming HTTP protocol details, invoke application use cases, and translate results into standardized HTTP responses. They must never contain business decisions, database queries, or manual error formatting.

---

## 1. When to Use

Consult and follow this skill whenever you:
- Create a new controller or add action methods to an existing controller.
- Review controller code changes for architectural consistency.
- Define or bind request parameters (`[FromRoute]`, `[FromQuery]`, `[FromBody]`).
- Design validation placement for incoming client payloads.
- Format outbound responses, pagination metadata, or status codes.

---

## 2. Request and Response DTO Placement (Application Layer Sharing)

To prevent duplicate wrapper classes and maintain clean domain boundaries:

- **Declare DTOs in Application Layer**: All Request and Response records are declared directly in `{Service}.Application/Services/{Feature}/{Feature}Requests.cs` and `{Feature}Responses.cs` (or next to the use case in CQRS services).
- **Direct Consumption by Controller**: Controllers directly bind these Application-layer request records and return these Application-layer response records.
- **Prohibit Duplicate API DTOs**: Never create redundant DTOs in `{Service}.Api` (e.g. prohibited: creating `ApiCreateUserRequest` in Api only to map into `AppCreateUserRequest` in Application).
- **Domain Entities Stay Private**: Never expose EF Core entities or domain aggregate roots through the controller. Only immutable DTO records and `PagedData<T>` leave the application boundary.

---

## 3. Validation Placement (Boundary Discipline)

Validation is concentrated exclusively at system boundaries:

- **Boundary Validation on Request Records**: Place declarative validation attributes from `System.ComponentModel.DataAnnotations` directly on Request DTO records (`[Required]`, `[EmailAddress]`, `[StringLength]`, `[Range]`, `[RegularExpression]`).
- **CQRS Pipeline Validation**: For services utilizing MediatR (such as `WalletService`), commands pass through `ValidationBehavior<TRequest, TResponse>` before handler execution.
- **Automatic Model State Rejection**: Invalid inputs are intercepted automatically by ASP.NET Core model validation or `ApiValidationProblemFactory`, producing standardized RFC 9110 ProblemDetails with `errorCode = "VAL_INVALID_INPUT"`.
- **PROHIBIT Manual Validation in Controllers**: Never write ad-hoc validation checks inside controller action bodies (e.g. prohibited: `if (string.IsNullOrWhiteSpace(request.Email)) return BadRequest(new { ... });`).

---

## 4. Error Message Standards (Descriptive Sentence Case)

When domain exceptions, validation failures, or edge guards trigger errors:

- **100% English Language**: All error messages, failure details, and exception descriptions must be written in English.
- **Sentence Case Format**:
  - Capitalize ONLY the first letter of the sentence.
  - All subsequent words must be lowercase, except technical acronyms and identifiers (`ID`, `OTP`, `JWT`, `URL`, `UUID`, `Email`, `API`, `HTTP`).
  - Prohibit ALL-CAPS messages (e.g. prohibited: `"WALLET NOT FOUND"`, `"INVALID INPUT"`).
  - Prohibit Title Case (e.g. prohibited: `"Wallet Account Not Found"`).
- **Contextual Precision**: The message must precisely describe what condition failed so any developer or client can diagnose the issue immediately.
  - Correct: `"User account was not found for the specified identifier."`
  - Correct: `"Password must be at least 8 characters long and contain a digit."`
  - Correct: `"Insufficient wallet balance to complete the checkout transaction."`
- **Error Codes**: Always `SCREAMING_SNAKE_CASE` without arbitrary `ERR_` prefixes (`USER_NOT_FOUND`, `INSUFFICIENT_BALANCE`, `VAL_INVALID_INPUT`).

---

## 5. Inbound Identity & Role Resolution (`UserContextMiddleware`)

Gateway forwards verified identity claims via HTTP headers (`x-user-id`, `x-user-roles`, `x-user-email`, `x-user-permissions`). The pipeline's `UserContextMiddleware` automatically decodes these headers and assigns a strongly typed `ClaimsPrincipal` to `HttpContext.User`.

Controllers interact with user identity strictly through these conventions:
1. **Extract Caller ID**: Use `if (!this.TryGetUserId(out var userId, out var authError)) return authError;`
   - Returns HTTP 401 ProblemDetails with `errorCode = "UNAUTHORIZED"` if caller is unauthenticated.
2. **Enforce Role Constraints**:
   - Declarative: Decorate action/controller with `[RequireRole("buyer", "seller")]` or `[RequireRole("admin", "staff")]`.
   - Imperative: Use `this.HasRole("admin")` or `this.IsAdmin()` for branching logic within authorized methods.
   - Non-qualifying roles automatically receive HTTP 403 ProblemDetails with `errorCode = "FORBIDDEN"`.
3. **Enforce Resource Ownership**:
   - Use `this.EnsureOwnership(resource.OwnerId, out var ownershipError)` or pass `userId` directly from context into the feature service.
   - **Prohibit Client-Supplied User IDs**: Never accept `userId`, `sellerId`, or `buyerId` from query string or request body to establish identity. Always bind the actor from `HttpContext`.
4. **Outbound Propagation**:
   - When the controller calls a downstream service via a typed REST client, `IdentityPropagationHandler` (registered in `DependencyInjection.cs`) automatically propagates `x-user-id`, `x-user-roles`, and `x-user-email` to the target service without manual header manipulation.

---

## 6. Canonical Reference Controller Blueprint

The following structural skeleton represents the standardized pattern for any controller in Nexus. It is modeled after stable controllers such as `UsersController.cs` and `MeController.cs`:

```csharp
namespace {Service}.Api.Controllers.Public;

using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using {Service}.Api.Extensions;
using {Service}.Api.Filters;
using {Service}.Application.Common.Models;
using {Service}.Application.Services.{Feature}; // Application-layer Request & Response records

[ApiController]
[Route("api/v1/{plural-resources}")]
public sealed class {Feature}Controller : ControllerBase
{
    private readonly I{Feature}Service _service; // Or ISender for CQRS services
    private readonly ILogger<{Feature}Controller> _logger;

    public {Feature}Controller(
        I{Feature}Service service,
        ILogger<{Feature}Controller> logger)
    {
        _service = service;
        _logger = logger;
    }

    /// <summary>Lists resources with pagination and optional filtering.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedData<{Feature}Dto>>> List(
        [FromQuery] PageQuery query,
        CancellationToken cancellationToken)
    {
        var (page, pageSize) = query.Normalize();
        _logger.LogInformation("[REST {Feature}] Querying page: {Page}, size: {Size}", page, pageSize);

        var result = await _service.ListAsync(page, pageSize, cancellationToken);
        return Ok(result);
    }

    /// <summary>Gets a single resource by its unique identifier.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<{Feature}Dto>> GetById(
        [FromRoute] Guid id,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("[REST {Feature}] Fetching by Id: '{Id}'", id);
        var result = await _service.GetByIdAsync(id, cancellationToken);
        return Ok(result);
    }

    /// <summary>Creates a new resource from an Application-layer request record.</summary>
    [HttpPost]
    [RequireRole("buyer", "seller")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    public async Task<IActionResult> Create(
        [FromBody] Create{Feature}Request request,
        CancellationToken cancellationToken)
    {
        if (!this.TryGetUserId(out var userId, out var authError))
        {
            return authError;
        }

        _logger.LogInformation("[REST {Feature}] Creating resource for UserId: '{UserId}'", userId);
        var result = await _service.CreateAsync(userId, request, cancellationToken);

        return StatusCode(StatusCodes.Status201Created, result);
    }

    /// <summary>Deletes a resource by its unique identifier.</summary>
    [HttpDelete("{id:guid}")]
    [RequireRole("admin", "staff")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(
        [FromRoute] Guid id,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("[REST {Feature}] Deleting resource Id: '{Id}'", id);
        await _service.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
```

---

## 7. Architecture Decoupling (Feature Services vs CQRS)

The controller boundary convention is decoupled from the internal dispatch architecture:

### Clean Architecture Feature Services
Used by: `UserService`, `CatalogService`, `CommerceService`, `FulfillmentService`, `NotificationService`, `LogService`, `AuctionService`, `CheckHealService`.
- Controller injects `I{Feature}Service` and `ILogger<{Feature}Controller>`.
- Actions call `await _service.MethodAsync(..., cancellationToken)`.

### Classic CQRS with MediatR
Used by: `WalletService` (frozen architectural exception).
- Controller injects `ISender` and `ILogger<{Feature}Controller>`.
- Actions instantiate Command/Query records, inject server-resolved identity (`command with { UserId = userGuid.ToString(), ClientIp = clientIp }`), and call `await _sender.Send(command, cancellationToken)`.
- The outer HTTP attributes, parameter bindings, cancellation token passing, and return types remain identical to the standard pattern.

---

## 8. HTTP Status & Return Conventions

- **GET Single Item**: Return `Task<ActionResult<T>>` with `Ok(dto)` (HTTP 200).
- **GET Paginated List**: Return `Task<ActionResult<PagedData<T>>>` with `Ok(pagedData)` (HTTP 200).
- **POST Creation**: Return `Task<IActionResult>` with `StatusCode(StatusCodes.Status201Created, dto)` (HTTP 201).
- **PUT / PATCH Update**: Return `Task<IActionResult>` with `Ok(dto)` (HTTP 200).
- **DELETE or Empty Operations**: Return `Task<IActionResult>` with `NoContent()` (HTTP 204, 0-byte payload).
- **No Manual Outer Envelopes**: Microservice controllers return pure payloads. Wrapping into `ApiResponse<T>` is performed by Gateway `ResponseEnvelopeMiddleware`.
- **Automatic Error Responses**: All exceptions bubble up to `GlobalExceptionHandlerMiddleware` to format RFC 9110 ProblemDetails (`type`, `title`, `status`, `errorCode`, `detail`, `traceId`, `timestamp`).

---

## 9. Anti-Pattern Checklist (Bad vs Good)

| Anti-Pattern (PROHIBITED) | Standard Pattern (MANDATORY) |
| :--- | :--- |
| Writing manual `if (string.IsNullOrEmpty(...)) return BadRequest(...)` in action | Annotate Request DTO with `[Required]`, let model validation emit RFC 9110 ProblemDetails |
| Trusting `buyerId` or `userId` from client query string or body | Extract identity via `this.TryGetUserId(out var userId, out var authError)` and `this.EnsureOwnership(...)` |
| Writing manual integer clamping `if (page < 1) page = 1;` in action | Bind via `[FromQuery] PageQuery query` and call `var (page, pageSize) = query.Normalize();` |
| Wrapping payload manually: `return Ok(new ApiResponse<T>(data));` | Return pure DTO: `return Ok(data);` (Gateway wraps automatically) |
| Returning domain entity: `return Ok(userEntity);` | Return immutable DTO record: `return Ok(userProfileDto);` |
| Catching exceptions in action to return `StatusCode(500, ex.Message)` | Let exceptions bubble up to `GlobalExceptionHandlerMiddleware` |
| Declaring multiple route aliases on one action `[HttpGet("list")] [HttpGet("all")]` | Exactly one route attribute per action |
| Returning raw integer enums or uppercase strings in JSON | Serialize as PascalCase string (`"Active"`, `"PendingVerification"`) |
