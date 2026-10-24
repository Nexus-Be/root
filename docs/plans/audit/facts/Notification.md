# Evidence pack — Notification

- file .cs (không tính Migrations): **53**, LOC: **1324**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Notification.Infrastructure | 17 | 651 |
| Notification.Domain | 25 | 346 |
| Notification.Api | 2 | 146 |
| Notification.Application | 8 | 104 |
| Notification.Tests | 1 | 77 |

## 2. DbSet
`AuditLog`, `BrokerHealthCheck`, `DeviceToken`, `EventLog`, `NotificationChannel`, `NotificationDelivery`, `NotificationLog`, `NotificationPreference`, `NotificationRecord`, `NotificationTemplate`

## 3. Application classes
- EmailNotificationService : IEmailNotificationService

## 4. gRPC server thật
_KHÔNG có class kế thừa gRPC Base_

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/health`

## 6. Messaging
- consume: `SendOtpEmailIntegrationEvent`
- publish: không có

## 7. Test
- file: 1, `[Fact]/[Theory]`: 2

## 8. Observability
- không có

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- GetPreferences, ListNotifications, MarkNotificationRead, UpdatePreferences
