# Evidence pack — Log

- file .cs (không tính Migrations): **40**, LOC: **1359**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Log.Application | 9 | 430 |
| Log.Infrastructure | 9 | 349 |
| Log.Api | 4 | 328 |
| Log.Domain | 18 | 252 |

## 2. DbSet
`AppLogFileCatalog`, `AuditSyncBatch`, `CentralAuditLog`, `LogEntry`, `LogEventType`, `SecurityAuditAlert`

## 3. Application classes
- GetLogQueryHandler : IRequestHandler<GetLogQuery, LogEntryDto
- GlobalLogConsumer : IConsumer<ILogEventOccurred>
- ListLogEventTypesQueryHandler : IRequestHandler<ListLogEventTypesQuery, LogEventTypeListDto>
- QueryLogsQueryHandler : IRequestHandler<QueryLogsQuery, LogPageDto>
- SetLogEventTypeEnabledCommandHandler : IRequestHandler<SetLogEventTypeEnabledCommand, LogEventTypeD
- SetLogEventTypeEnabledCommandValidator : AbstractValidator<SetLogEventTypeEnabledCommand>

## 4. gRPC server thật
- `LogGrpcService` (Log.Api/Services/LogGrpcService.cs): QueryLogs, GetLog, ListLogEventTypes, SetLogEventTypeEnabled

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/`, `/health`

## 6. Messaging
- consume: `ILogEventOccurred`
- publish: không có

## 7. Test
- file: 0, `[Fact]/[Theory]`: 0

## 8. Observability
- AddOpenTelemetry×1

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- GetLog, ListLogEventTypes, QueryLogs, SetLogEventTypeEnabled
