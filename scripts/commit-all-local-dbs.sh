#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH_NAME="feature/local-databases"

echo "================================================================="
echo " 1. KIỂM TRA BUILD TẤT CẢ 10 SOLUTIONS (RELEASE)"
echo "================================================================="

SERVICES=(
  "ApiGateway:src/Services/ApiGateway:ApiGateway.sln"
  "UserService:src/Services/User:User.sln"
  "CatalogService:src/Services/Catalog:Catalog.sln"
  "CommerceService:src/Services/Commerce:Commerce.sln"
  "LogService:src/Services/Log:Log.sln"
  "AuctionService:src/Services/Auction:Auction.sln"
  "FulfillmentService:src/Services/Fulfillment:Fulfillment.sln"
  "NotificationService:src/Services/Notification:Notification.sln"
  "WalletService:src/Services/Wallet:Wallet.sln"
  "CheckHeal:src/Services/CheckHeal:CheckHeal.sln"
)

for item in "${SERVICES[@]}"; do
  IFS=":" read -r sname spath sln <<< "$item"
  echo ">>> Building $sname ($sln)..."
  (
    cd "$REPO_ROOT/$spath"
    dotnet build "$sln" -c Release --nologo -v q
  )
  echo ">>> [OK] $sname build passed."
done

echo ""
echo "================================================================="
echo " 2. COMMIT TRÊN TỪNG SUBMODULE (BRANCH: $BRANCH_NAME, KO PUSH)"
echo "================================================================="

SUBMODULES=(
  "src/Services/ApiGateway"
  "src/Services/User"
  "src/Services/Catalog"
  "src/Services/Commerce"
  "src/Services/Log"
  "src/Services/Auction"
  "src/Services/Fulfillment"
  "src/Services/Notification"
  "src/Services/Wallet"
  "src/Services/CheckHeal"
)

for sm in "${SUBMODULES[@]}"; do
  echo ">>> Checking submodule: $sm"
  (
    cd "$REPO_ROOT/$sm"
    # Đảm bảo đang ở nhánh feature/local-databases
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
      git checkout -B "$BRANCH_NAME"
    fi

    # Kiểm tra nếu có thay đổi thì commit
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "feat(config): switch environment variables and connection defaults to local database

Co-Authored-By: Claude Code <noreply@anthropic.com>"
      echo ">>> [COMMITTED] $sm on branch $BRANCH_NAME"
    else
      echo ">>> [CLEAN] No uncommitted changes in $sm"
    fi
  )
done

echo ""
echo "================================================================="
echo " 3. COMMIT TRÊN ROOT REPO (BRANCH: $BRANCH_NAME, KO PUSH)"
echo "================================================================="

CURRENT_ROOT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_ROOT_BRANCH" != "$BRANCH_NAME" ]; then
  git checkout -B "$BRANCH_NAME"
fi

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "feat(docker,db): add dedicated databases compose folders and standardize all repos to local databases

- Created standalone compose folders infra/databases and docker/databases for one-command db startup
- Updated all submodules .env.example and docker-compose.yml to use local PostgreSQL databases (ports 5433-5440)
- Synchronized common configurations (JWT key, Redis, RabbitMQ, OTel, CheckHeal) across all .env.example files
- Configured CheckHeal appsettings.Development.json to monitor local database instances
- Removed Neon Cloud references and created scripts/sync-all-envs.sh and scripts/migrate-local-dbs.sh

Co-Authored-By: Claude Code <noreply@anthropic.com>"
  echo ">>> [COMMITTED] Root repo on branch $BRANCH_NAME"
else
  echo ">>> [CLEAN] No uncommitted changes in Root repo"
fi

echo ""
echo "================================================================="
echo " 4. TỔNG KẾT TRẠNG THÁI TOÀN BỘ REPOSITORIES"
echo "================================================================="
git status
echo ""
git submodule foreach 'echo "[$name] Branch: $(git rev-parse --abbrev-ref HEAD), Commit: $(git rev-parse --short HEAD)"'
