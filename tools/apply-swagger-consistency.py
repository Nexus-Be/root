#!/usr/bin/env python3
"""Apply the identical Swagger consistency patch and internal auth handling to every backend microservice.

Idempotent: running it twice changes nothing. Prints which files were rewritten.
"""

from __future__ import annotations

import re
from pathlib import Path

SERVICES = [
    "User",
    "Catalog",
    "Commerce",
    "Log",
    "Auction",
    "Fulfillment",
    "Notification",
    "Wallet",
]

ROOT = Path(__file__).resolve().parents[1] / "src" / "Services"

EXTENSIONS_TEMPLATE = """namespace __SERVICE__.Api.Extensions;

using System;
using System.IO;
using System.Linq;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using __SERVICE__.Api.Common.Converters;
using __SERVICE__.Api.Middleware;
using __SERVICE__.Api.Swagger;

public static class ServiceDefaultsExtensions
{
    public static IServiceCollection AddServiceDefaults(this IServiceCollection services, IConfiguration configuration, string serviceName)
    {
        services.AddServiceObservability(configuration, serviceName);
        services.AddHttpContextAccessor();
        services.AddEndpointsApiExplorer();

        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = $"Nexus {ToDisplayName(serviceName)} REST API",
                Version = "v1",
                Description = $"RESTful Web API for {serviceName}."
            });

            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Name = "Authorization",
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                Description = "Enter a valid JWT Bearer token."
            });

            options.AddSecurityDefinition("x-user-id", new OpenApiSecurityScheme
            {
                Name = "x-user-id",
                Type = SecuritySchemeType.ApiKey,
                In = ParameterLocation.Header,
                Description = "Header x-user-id forwarded from API Gateway (GUID format)."
            });

            options.AddSecurityDefinition("x-user-roles", new OpenApiSecurityScheme
            {
                Name = "x-user-roles",
                Type = SecuritySchemeType.ApiKey,
                In = ParameterLocation.Header,
                Description = "Header x-user-roles forwarded from API Gateway (e.g. buyer, seller, admin)."
            });

            options.AddSecurityDefinition("x-user-email", new OpenApiSecurityScheme
            {
                Name = "x-user-email",
                Type = SecuritySchemeType.ApiKey,
                In = ParameterLocation.Header,
                Description = "Header x-user-email forwarded from API Gateway."
            });

            options.AddSecurityDefinition("x-user-permissions", new OpenApiSecurityScheme
            {
                Name = "x-user-permissions",
                Type = SecuritySchemeType.ApiKey,
                In = ParameterLocation.Header,
                Description = "Header x-user-permissions forwarded from API Gateway."
            });

            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Bearer"
                        }
                    },
                    Array.Empty<string>()
                },
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "x-user-id"
                        }
                    },
                    Array.Empty<string>()
                },
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "x-user-roles"
                        }
                    },
                    Array.Empty<string>()
                }
            });

            options.OperationFilter<InternalOperationFilter>();

            var xmlDocumentationPath = Path.Combine(
                AppContext.BaseDirectory,
                $"{typeof(ServiceDefaultsExtensions).Assembly.GetName().Name}.xml");
            if (File.Exists(xmlDocumentationPath))
            {
                options.IncludeXmlComments(xmlDocumentationPath, includeControllerXmlComments: true);
            }
        });

        services.ConfigureHttpJsonOptions(options =>
        {
            options.SerializerOptions.Converters.Add(new PascalCaseJsonStringEnumConverter(allowIntegerValues: false));
        });
        services.Configure<Microsoft.AspNetCore.Mvc.JsonOptions>(options =>
        {
            options.JsonSerializerOptions.Converters.Add(new PascalCaseJsonStringEnumConverter(allowIntegerValues: false));
        });

        return services;
    }

    public static WebApplication UseServiceDefaults(this WebApplication app)
    {
        app.UseGlobalExceptionHandler();
        app.UseMiddleware<InternalServiceAuthMiddleware>();

        if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
        {
            app.UseSwagger();
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "v1");
                c.RoutePrefix = "swagger";
            });
            app.MapGet("/", () => Results.Redirect("/swagger"));
        }

        return app;
    }

    private static string ToDisplayName(string serviceName)
    {
        return string.Join(
            ' ',
            serviceName
                .Split('-', StringSplitOptions.RemoveEmptyEntries)
                .Select(part => char.ToUpperInvariant(part[0]) + part[1..]));
    }
}
"""

FILTER_TEMPLATE = """namespace __SERVICE__.Api.Swagger;

using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

public sealed class InternalOperationFilter : IOperationFilter
{
    private readonly string _serviceKey;

    public InternalOperationFilter(IConfiguration configuration)
    {
        _serviceKey = Environment.GetEnvironmentVariable("INTERNAL_SERVICE_SECRET")
            ?? configuration["INTERNAL_SERVICE_SECRET"]
            ?? configuration["InternalSecurity:ServiceKey"]
            ?? string.Empty;
    }

    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        if (context.ApiDescription.RelativePath is not { } path ||
            !path.StartsWith("api/v1/internal", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        operation.Parameters ??= new List<OpenApiParameter>();
        operation.Parameters.Add(new OpenApiParameter
        {
            Name = "X-Internal-Service-Key",
            In = ParameterLocation.Header,
            Required = true,
            Description = "Internal service secret key (pre-filled from environment).",
            Schema = new OpenApiSchema
            {
                Type = "string",
                Default = new OpenApiString(_serviceKey)
            }
        });
    }
}
"""

MIDDLEWARE_TEMPLATE = """namespace __SERVICE__.Api.Middleware;

using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public sealed class InternalServiceAuthMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _configuration;
    private readonly IHostEnvironment _environment;
    private readonly ILogger<InternalServiceAuthMiddleware> _logger;

    public const string HeaderKeyInternalService = "X-Internal-Service-Key";

    public InternalServiceAuthMiddleware(
        RequestDelegate next,
        IConfiguration configuration,
        IHostEnvironment environment,
        ILogger<InternalServiceAuthMiddleware> logger)
    {
        _next = next;
        _configuration = configuration;
        _environment = environment;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/api/v1/internal", StringComparison.OrdinalIgnoreCase))
        {
            var expectedKey = Environment.GetEnvironmentVariable("INTERNAL_SERVICE_SECRET")
                ?? _configuration["INTERNAL_SERVICE_SECRET"]
                ?? _configuration["InternalSecurity:ServiceKey"];

            if (string.IsNullOrWhiteSpace(expectedKey))
            {
                _logger.LogError("Internal service key is not configured.");
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsync("{\\"errorCode\\":\\"INTERNAL_CONFIGURATION_ERROR\\",\\"message\\":\\"Internal service authentication is not configured.\\"}");
                return;
            }

            var isDevOrSwagger = _environment.IsDevelopment()
                || _configuration.GetValue<bool>("Swagger:Enabled");

            var isSwaggerReferer = isDevOrSwagger &&
                (context.Request.Headers.TryGetValue("Referer", out var referer) &&
                 referer.ToString().Contains("/swagger", StringComparison.OrdinalIgnoreCase));

            if (context.Request.Headers.TryGetValue(HeaderKeyInternalService, out var providedKey))
            {
                if (!string.Equals(providedKey.ToString(), expectedKey, StringComparison.Ordinal))
                {
                    _logger.LogWarning("Access denied to internal endpoint with invalid key: {Path}", context.Request.Path);
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync("{\\"errorCode\\":\\"FORBIDDEN\\",\\"message\\":\\"Access denied to internal service resource.\\"}");
                    return;
                }
            }
            else if (!isSwaggerReferer)
            {
                _logger.LogWarning("Access denied to internal endpoint (missing key): {Path}", context.Request.Path);
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsync("{\\"errorCode\\":\\"FORBIDDEN\\",\\"message\\":\\"Access denied to internal service resource.\\"}");
                return;
            }
            else
            {
                _logger.LogInformation("Permitting internal endpoint access for Swagger test in development: {Path}", context.Request.Path);
            }
        }

        await _next(context);
    }
}
"""

DOC_PROPS = (
    "<GenerateDocumentationFile>true</GenerateDocumentationFile>",
    "<NoWarn>$(NoWarn);1591</NoWarn>",
)

DEAD_PACKAGE = re.compile(
    r'^[ \t]*<PackageReference Include="Microsoft\.AspNetCore\.OpenApi".*\r?\n',
    re.MULTILINE,
)


def patch_extensions(service: str) -> bool:
    path = ROOT / service / f"{service}.Api" / "Extensions" / "ServiceDefaultsExtensions.cs"
    expected = EXTENSIONS_TEMPLATE.replace("__SERVICE__", service)
    if path.read_text(encoding="utf-8") == expected:
        return False
    path.write_text(expected, encoding="utf-8")
    return True


def patch_filter(service: str) -> bool:
    folder = ROOT / service / f"{service}.Api" / "Swagger"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "InternalOperationFilter.cs"
    expected = FILTER_TEMPLATE.replace("__SERVICE__", service)
    if path.exists() and path.read_text(encoding="utf-8") == expected:
        return False
    path.write_text(expected, encoding="utf-8")
    return True


def patch_middleware(service: str) -> bool:
    path = ROOT / service / f"{service}.Api" / "Middleware" / "InternalServiceAuthMiddleware.cs"
    expected = MIDDLEWARE_TEMPLATE.replace("__SERVICE__", service)
    if path.exists() and path.read_text(encoding="utf-8") == expected:
        return False
    path.write_text(expected, encoding="utf-8")
    return True


def patch_csproj(service: str) -> bool:
    path = ROOT / service / f"{service}.Api" / f"{service}.Api.csproj"
    original = path.read_text(encoding="utf-8")
    updated = original

    if "GenerateDocumentationFile" not in updated:
        target = re.search(r"^([ \t]*)<TargetFramework>[^<]*</TargetFramework>", updated, re.MULTILINE)
        if target is None:
            raise SystemExit(f"Cannot locate TargetFramework in {path}")
        indent = target.group(1)
        injected = "".join(f"\n{indent}{prop}" for prop in DOC_PROPS)
        updated = updated[: target.end()] + injected + updated[target.end() :]

    updated = DEAD_PACKAGE.sub("", updated)

    if updated == original:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> None:
    for service in SERVICES:
        changed = []
        if patch_extensions(service):
            changed.append("ServiceDefaultsExtensions.cs")
        if patch_filter(service):
            changed.append("InternalOperationFilter.cs")
        if patch_middleware(service):
            changed.append("InternalServiceAuthMiddleware.cs")
        if patch_csproj(service):
            changed.append(f"{service}.Api.csproj")
        status = ", ".join(changed) if changed else "already up to date"
        print(f"{service}: {status}")


if __name__ == "__main__":
    main()
