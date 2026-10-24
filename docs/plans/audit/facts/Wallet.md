# Evidence pack — Wallet

- file .cs (không tính Migrations): **46**, LOC: **1755**

## 1. Phân bố theo project
| Project | files | LOC |
|---|---:|---:|
| Wallet.Application | 10 | 595 |
| Wallet.Infrastructure | 11 | 432 |
| Wallet.Domain | 21 | 366 |
| Wallet.Api | 4 | 362 |

## 2. DbSet
`AuditLog`, `BankAccount`, `DirectPaymentOrder`, `VnpayIpnLog`, `WalletAccount`, `WalletTopup`, `WalletTransaction`, `WithdrawalRequest`

## 3. Application classes
- DepositCommandHandler : IRequestHandler<DepositCommand, WalletTransactionDto>
- DepositCommandValidator : AbstractValidator<DepositCommand>
- GetWalletQueryHandler : IRequestHandler<GetWalletQuery, WalletDto>
- ListTransactionsQueryHandler : IRequestHandler<ListTransactionsQuery, WalletTransactionPage
- StockReservedConsumer : IConsumer<IStockReservedEvent>
- TransferCommandHandler : IRequestHandler<TransferCommand, WalletTransactionDto>
- TransferCommandValidator : AbstractValidator<TransferCommand>
- WithdrawCommandHandler : IRequestHandler<WithdrawCommand, WalletTransactionDto>
- WithdrawCommandValidator : AbstractValidator<WithdrawCommand>

## 4. gRPC server thật
- `WalletGrpcService` (Wallet.Api/Services/WalletGrpcService.cs): GetWallet, Deposit, Withdraw, Transfer, ListTransactions

## 5. REST / endpoint
- controllers: 0
- minimal endpoints: `/`, `/health`

## 6. Messaging
- consume: `IStockReservedEvent`
- publish: `IPaymentCompletedEvent`, `IPaymentFailedEvent`

## 7. Test
- file: 0, `[Fact]/[Theory]`: 0

## 8. Observability
- AddOpenTelemetry×1

## 9. Docs
- 10 file .md: 00_AGENT_MISSION_GUARDRAILS.md, 01_CLEAN_ARCHITECTURE_LAYERS.md, 02_API_GRPC_CONTRACTS.md, 03_EVENT_MESSAGING.md, 04_DATA_PERSISTENCE.md, 05_DEV_VERIFICATION_CHECKLIST.md, AGENTS.md, CLAUDE.md, README.md, README.md

## 10. Specs/02 rpc được hứa
- Deposit, GetWallet, ListTransactions, Transfer, Withdraw
