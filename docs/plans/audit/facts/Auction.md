# Evidence pack — Auction

- file .cs (không tính Migrations): **47**, LOC: **1182**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Auction.Infrastructure | 16 | 502 |
| Auction.Domain | 21 | 327 |
| Auction.Application | 8 | 198 |
| Auction.Api | 2 | 155 |

## 2. DbSet
`Auction`, `AuctionConfig`, `AuctionExtension`, `AuctionResult`, `AuctionSettlement`, `AuctionState`, `AuctionStatusHistory`, `AuditLog`, `Bid`, `BidHistory`, `BidInvalidation`, `IdempotencyKey`, `ProductOpenAuction`

## 3. Application classes
- AuctionService : IAuctionService
- BidService : IBidService

## 4. gRPC server thật
_KHÔNG có class kế thừa gRPC Base_

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/health`

## 6. Messaging
- consume: không có
- publish: không có

## 7. Test
- file: 0, `[Fact]/[Theory]`: 0

## 8. Observability
- không có

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- CreateAuction, GetAuction, ListAuctions, ListBids, PlaceBid
