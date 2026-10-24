# Evidence pack — User

- file .cs (không tính Migrations): **65**, LOC: **2434**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| User.Infrastructure | 19 | 949 |
| User.Domain | 34 | 521 |
| User.Application | 8 | 374 |
| User.Api | 3 | 324 |
| User.Tests | 1 | 266 |

## 2. DbSet
`AuditLog`, `Permission`, `RefreshToken`, `ReputationLog`, `ReputationScore`, `Role`, `RolePermission`, `SellerProfile`, `SystemConfig`, `User`, `UserPenalty`, `UserReport`, `UserReview`, `UserRole`

## 3. Application classes
- AuthService : IAuthService

## 4. gRPC server thật
- `UsersGrpcService` (User.Api/Services/UsersGrpcService.cs): Register, VerifyOtp, ResendOtp, GetProfile

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/health`

## 6. Messaging
- consume: không có
- publish: `SendOtpEmailIntegrationEvent`

## 7. Test
- file: 1, `[Fact]/[Theory]`: 9

## 8. Observability
- không có

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- ApproveSeller, AssignRoles, CreateUser, GetProfile, ListPermissions, ListRoles, ListUsers, Login, Register, RequestSellerUpgrade, UpdateProfile
