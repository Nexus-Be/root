# Code Skeletons

These skeletons mirror the code that exists in the repositories today. Adapt names and namespaces to the service you are working in. Do not copy placeholders into production unchanged.

## 1. Application interface

```csharp
namespace {Service}.Application.Services.{Feature};

using System;
using System.Threading;
using System.Threading.Tasks;

public interface I{Feature}Service
{
    Task<{Feature}Response> GetAsync(Guid id, CancellationToken cancellationToken = default);
    Task<PagedData<{Feature}ListItemDto>> ListAsync(
        Guid ownerId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task<{Feature}Response> CreateAsync(
        Guid ownerId,
        Create{Feature}Request request,
        CancellationToken cancellationToken = default);
}
```

## 2. Application service

```csharp
namespace {Service}.Application.Services.{Feature};

using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using {Service}.Application.Common.Models;
using {Service}.Application.Interfaces;
using {Service}.Domain.Entities;
using {Service}.Domain.Exceptions;

public sealed class {Feature}Service : I{Feature}Service
{
    private readonly I{Service}DbContext _dbContext;
    private readonly ILogger<{Feature}Service> _logger;

    public {Feature}Service(I{Service}DbContext dbContext, ILogger<{Feature}Service> logger)
    {
        _dbContext = dbContext;
        _logger = logger;
    }

    public async Task<{Feature}Response> GetAsync(Guid id, CancellationToken cancellationToken = default)
    {
        if (id == Guid.Empty)
        {
            throw new BusinessRuleValidationException("VAL_INVALID_INPUT", "Identifier is required.");
        }

        var entity = await _dbContext.{Entities}
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (entity is null)
        {
            throw new DomainException("{RESOURCE}_NOT_FOUND", "{Resource} not found with the specified ID.");
        }

        return Map(entity);
    }

    public async Task<PagedData<{Feature}ListItemDto>> ListAsync(
        Guid ownerId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.{Entities}
            .AsNoTracking()
            .Where(x => x.OwnerId == ownerId);

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(x => x.CreatedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new {Feature}ListItemDto(x.Id, x.Name, x.CreatedAt))
            .ToListAsync(cancellationToken);

        return PagedData<{Feature}ListItemDto>.From(items, pageIndex, pageSize, totalCount);
    }

    public async Task<{Feature}Response> CreateAsync(
        Guid ownerId,
        Create{Feature}Request request,
        CancellationToken cancellationToken = default)
    {
        if (ownerId == Guid.Empty)
        {
            throw new BusinessRuleValidationException("UNAUTHORIZED", "Authentication is required to perform this action.");
        }

        await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);

        var entity = new {Entity}
        {
            Id = Guid.NewGuid(),
            OwnerId = ownerId,
            Name = request.Name.Trim(),
            CreatedAt = DateTimeOffset.UtcNow
        };

        _dbContext.{Entities}.Add(entity);
        _dbContext.AddAuditLog(
            action: "CREATE",
            entityName: nameof({Entity}),
            entityId: entity.Id.ToString(),
            newValues: entity);

        await _dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return Map(entity);
    }

    private static {Feature}Response Map({Entity} entity)
        => new(entity.Id, entity.Name, entity.CreatedAt);
}
```

Notes:

- `AddAuditLog` is the service's existing extension method. If the service does not have one, use the service's audit pattern, not `new AuditLog`.
- `I{Service}DbContext` exposes `DbSet<T>` and `Database`. Confirm the exact member names in the repository.
- Wallet handlers inject `IWalletDbContext` and implement `IRequestHandler<TRequest, TResponse>` instead of this shape.

## 3. Request and response records

```csharp
namespace {Service}.Application.Services.{Feature};

using System;

public sealed record Create{Feature}Request(string Name);

public sealed record {Feature}Response(Guid Id, string Name, DateTimeOffset CreatedAt);

public sealed record {Feature}ListItemDto(Guid Id, string Name, DateTimeOffset CreatedAt);
```

Use `sealed record` for contracts. Keep C# property names PascalCase; the JSON serializer emits camelCase.

## 4. Thin controller

```csharp
namespace {Service}.Api.Controllers;

using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using {Service}.Api.Common;
using {Service}.Api.Extensions;
using {Service}.Application.Common.Models;
using {Service}.Application.Services.{Feature};

[ApiController]
[Route("api/v1/{plural-resource}")]
public sealed class {Feature}Controller : ControllerBase
{
    private readonly I{Feature}Service _{feature}Service;
    private readonly ILogger<{Feature}Controller> _logger;

    public {Feature}Controller(I{Feature}Service {feature}Service, ILogger<{Feature}Controller> logger)
    {
        _{feature}Service = {feature}Service;
        _logger = logger;
    }

    /// <summary>Lists the current user's {resource} records.</summary>
    [HttpGet]
    [RequireRole]
    public async Task<IActionResult> List(
        [FromQuery] PageQuery pagination,
        CancellationToken cancellationToken)
    {
        if (!this.TryGetUserId(out var userId, out var authError))
        {
            return authError;
        }

        var (page, pageSize) = pagination.Normalize();
        var result = await _{feature}Service.ListAsync(userId, page, pageSize, cancellationToken);
        return Ok(result);
    }

    /// <summary>Creates a {resource} record for the current user.</summary>
    [HttpPost]
    [RequireRole]
    public async Task<IActionResult> Create(
        [FromBody] Create{Feature}Request request,
        CancellationToken cancellationToken)
    {
        if (!this.TryGetUserId(out var userId, out var authError))
        {
            return authError;
        }

        var created = await _{feature}Service.CreateAsync(userId, request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Deletes a {resource} record owned by the current user.</summary>
    [HttpDelete("{id:guid}")]
    [RequireRole]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        if (!this.TryGetUserId(out var userId, out var authError))
        {
            return authError;
        }

        await _{feature}Service.DeleteAsync(userId, id, cancellationToken);
        return NoContent();
    }
}
```

Notes:

- Return DTOs directly. Do not wrap in `ApiResponse<T>` inside the service.
- `PageQuery` exists in UserService. Other services may use their own query type; keep the wire names `page` and `pageSize`.
- `RequireRole` is the service's existing filter. Use the service's actual authorization attribute.
- `TryGetUserId` is the service's existing controller extension. Do not read `userId` from route or query.

## 5. Shared pagination types

```csharp
public sealed record PagedData<T>(
    IReadOnlyList<T> Items,
    PaginationMetadata Pagination)
{
    public static PagedData<T> From(IReadOnlyList<T> items, int pageIndex, int pageSize, int totalCount)
        => new(items, PaginationMetadata.Create(pageIndex, pageSize, totalCount));
}

public sealed record PaginationMetadata(
    int PageIndex,
    int PageSize,
    int TotalCount,
    int TotalPages,
    bool HasPreviousPage,
    bool HasNextPage)
{
    public static PaginationMetadata Create(int pageIndex, int pageSize, int totalCount)
    {
        var totalPages = pageSize > 0 ? (int)Math.Ceiling(totalCount / (double)pageSize) : 0;
        return new PaginationMetadata(
            PageIndex: pageIndex,
            PageSize: pageSize,
            TotalCount: totalCount,
            TotalPages: totalPages,
            HasPreviousPage: pageIndex > 1,
            HasNextPage: pageIndex < totalPages);
    }
}
```

## 6. Unit test skeleton

```csharp
namespace {Service}.Tests;

using System;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using {Service}.Application.Services.{Feature};
using {Service}.Domain.Exceptions;
using {Service}.Infrastructure.Persistence;
using Xunit;

public sealed class {Feature}ServiceTests
{
    private static AppDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"feature_test_{Guid.NewGuid():N}")
            .Options;

        return new AppDbContext(options);
    }

    [Fact]
    public async Task GetAsync_returns_not_found_for_missing_record()
    {
        using var dbContext = CreateDbContext();
        var service = new {Feature}Service(dbContext, NullLogger<{Feature}Service>.Instance);

        var exception = await Assert.ThrowsAsync<DomainException>(
            () => service.GetAsync(Guid.NewGuid()));

        Assert.Equal("{RESOURCE}_NOT_FOUND", exception.ErrorCode);
    }
}
```

Add at least one test per error code, one pagination boundary test, and one ownership test. Use the repository's existing xUnit style and in-memory provider.

## 7. Wallet CQRS skeleton

```csharp
namespace Wallet.Application.Features.{Area}.Queries.{UseCase};

using MediatR;

public sealed record {UseCase}Query(string UserId) : IRequest<{UseCase}Response>;
```

```csharp
namespace Wallet.Application.Features.{Area}.Queries.{UseCase};

using System;
using System.Threading;
using System.Threading.Tasks;
using MediatR;
using Microsoft.EntityFrameworkCore;
using global::Wallet.Application.Interfaces;

internal sealed class {UseCase}QueryHandler : IRequestHandler<{UseCase}Query, {UseCase}Response>
{
    private readonly IWalletDbContext _context;

    public {UseCase}QueryHandler(IWalletDbContext context)
    {
        _context = context;
    }

    public async Task<{UseCase}Response> Handle({UseCase}Query request, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(request.UserId, out var userId) || userId == Guid.Empty)
        {
            throw new ArgumentException("User ID must be a valid UUID.", nameof(request));
        }

        var wallet = await _context.Wallets
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.UserId == userId, cancellationToken);

        if (wallet is null)
        {
            throw new InvalidOperationException("Wallet account not found for the specified user.");
        }

        return new {UseCase}Response(wallet.Id.ToString(), wallet.Balance);
    }
}
```

Controller for Wallet:

```csharp
[HttpGet("me")]
[RequireRole]
public async Task<IActionResult> GetMyWallet(CancellationToken cancellationToken)
{
    if (!this.TryGetUserId(out var userId, out var authError))
    {
        return authError;
    }

    var result = await _sender.Send(new GetMyWalletQuery(userId.ToString()), cancellationToken);
    return Ok(result);
}
```

Do not add a feature service facade, do not split controllers, and do not remove MediatR. Adding a use case changes the frozen count in `Wallet/AGENTS.md`; get approval and update the count and the architecture script.

## 8. Typed REST client

```csharp
namespace {Service}.Application.Interfaces;

using System.Threading;
using System.Threading.Tasks;

public interface I{Downstream}Client
{
    Task<bool> SendAsync(string payload, CancellationToken cancellationToken = default);
}
```

```csharp
namespace {Service}.Infrastructure.Services.{Downstream};

using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using {Service}.Application.Interfaces;

public sealed class {Downstream}Client : I{Downstream}Client
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<{Downstream}Client> _logger;

    public {Downstream}Client(HttpClient httpClient, ILogger<{Downstream}Client> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<bool> SendAsync(string payload, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _httpClient.PostAsJsonAsync(
                "api/v1/{downstream-resource}",
                new { value = payload },
                cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                return true;
            }

            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            _logger.LogWarning(
                "Downstream call failed. Status: {StatusCode}, Body: {Body}",
                response.StatusCode,
                body);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Downstream call failed with a connection error.");
            return false;
        }
    }
}
```

DI registration:

```csharp
var baseUrl = Environment.GetEnvironmentVariable("DOWNSTREAM_SERVICE_URL")
    ?? configuration["Services:Downstream:BaseUrl"]
    ?? "http://localhost:{port}/";

services.AddHttpClient<I{Downstream}Client, {Downstream}Client>(client =>
{
    client.BaseAddress = new Uri(baseUrl);
    client.Timeout = TimeSpan.FromSeconds(10);
});
```

Environment variables take precedence over `appsettings.json`. Do not call `localhost` from inside a container.

## 9. YARP route and cluster

```json
{
  "ReverseProxy": {
    "Routes": {
      "{plural-resource}-route": {
        "ClusterId": "{service}-cluster",
        "Match": {
          "Path": "/api/v1/{plural-resource}/{**catch-all}"
        }
      }
    },
    "Clusters": {
      "{service}-cluster": {
        "Destinations": {
          "{service}-destination": {
            "Address": "http://{service}-service:{port}/"
          }
        }
      }
    }
  }
}
```

Rules:

- Add the same route to `appsettings.json` and the example file.
- Keep admin routes split per domain.
- Never add a route for `/internal`.
- Confirm the route order does not shadow a more specific path.
- Do not add pagination logic to the Gateway.
