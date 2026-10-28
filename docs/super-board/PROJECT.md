# Nexus Microservices Ecosystem

## Overview
Distributed e-commerce and online auction ecosystem built on **.NET 8 LTS (C# 12)** using Clean Architecture and a 3-tier decoupling API Gateway.

## Architecture
- **Single Entry Point**: ApiGateway running on port `8080` handles routing, mock fixtures, JWT/RBAC, and rate limiting.
- **Backend Microservices**:
  - `UserService` (`8001`, DB: `5433` `usermanagement_db`)
  - `CatalogService` (`8002`, DB: `5434` `category_db`)
  - `CommerceService` (`8003`, DB: `5435` `commerce_db`)
  - `LogService` (`8004`, DB: `5436` `log_db`)
  - `AuctionService` (`8005`, DB: `5437` `auction_db`)
  - `FulfillmentService` (`8006`, DB: `5438` `fulfillment_db`)
  - `NotificationService` (`8007`, DB: `5439` `notification_db`)
  - `WalletService` (`8008`, DB: `5440` `wallet_db`)
- **Shared Infrastructure**:
  - RabbitMQ (`5672` AMQP, `15672` UI)
  - Redis (`6379`) for rate limiting and cache
  - Grafana Tempo (`4317` / `4318` / `3200`) and Grafana Dashboard (`3000`)

## Inter-Service Communication
- **Synchronous**: 100% RESTful HTTP/JSON (RFC 9110). gRPC is strictly forbidden for inter-service synchronous communication.
- **Asynchronous**: RabbitMQ via MassTransit for event publishing, consuming, and Saga orchestration.

## Verification & Commands
- **Build**: `dotnet build <Solution>.sln -c Release`
- **Test**: `dotnet test <Solution>.sln -c Release`
- **Health check**: `GET /health` on all services

## Core Guardrails
- **Inward-Only Scoping**: Submodules do not reference root or sibling services.
- **No-Repository Pattern**: Application layer uses `DbContext` and `DbSet<T>` directly.
- **Database Isolation**: Database-per-service; never cross-query another service's database directly.
- **Error Standards**: 100% English Sentence case error messages and SCREAMING_SNAKE_CASE error codes.
