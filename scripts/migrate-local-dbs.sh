#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "================================================================="
echo " 1. KHỞI CHẠY HẠ TẦNG DATABASE POSTGRESQL (CỔNG 5433 -> 5440)"
echo "================================================================="

docker network create nexus-network 2>/dev/null || true

docker compose -f docker-compose.infra.yml up -d \
  user-db catalog-db commerce-db log-db \
  auction-db fulfillment-db notification-db wallet-db

echo ""
echo "Đang đợi 8 container cơ sở dữ liệu khởi động và vượt qua healthcheck..."
for i in {1..30}; do
  UNHEALTHY=$(docker compose -f docker-compose.infra.yml ps --format '{{.Service}} {{.Health}}' | grep -v 'healthy' || true)
  if [ -z "$UNHEALTHY" ]; then
    echo "Tất cả 8 database containers đã HEALTHY!"
    break
  fi
  echo "Chờ database sẵn sàng (giây $i/30)..."
  sleep 2
done

docker compose -f docker-compose.infra.yml ps

echo ""
echo "================================================================="
echo " 2. THỰC THI EF CORE DATABASE UPDATE CHO TỪNG MICROSERVICE"
echo "================================================================="

DOTNET_EF="$HOME/.dotnet/tools/dotnet-ef"
if [ ! -f "$DOTNET_EF" ]; then
  DOTNET_EF="dotnet ef"
fi

update_service() {
  local service_name="$1"
  local project_path="$2"
  local infra_csproj="$3"
  local api_csproj="$4"
  local conn_str="$5"

  echo "-----------------------------------------------------------------"
  echo ">>> Updating database migration for: $service_name"
  echo "-----------------------------------------------------------------"
  (
    cd "$REPO_ROOT/$project_path"
    $DOTNET_EF database update \
      --project "$infra_csproj" \
      --startup-project "$api_csproj" \
      --connection "$conn_str"
  )
  echo ">>> [SUCCESS] $service_name migration applied."
}

# 1. UserService (Port 5433, usermanagement_db)
update_service "UserService" \
  "src/Services/User" \
  "User.Infrastructure/User.Infrastructure.csproj" \
  "User.Api/User.Api.csproj" \
  "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"

# 2. CatalogService (Port 5434, catalog_db)
update_service "CatalogService" \
  "src/Services/Catalog" \
  "Catalog.Infrastructure/Catalog.Infrastructure.csproj" \
  "Catalog.Api/Catalog.Api.csproj" \
  "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"

# 3. CommerceService (Port 5435, commerce_db)
update_service "CommerceService" \
  "src/Services/Commerce" \
  "Commerce.Infrastructure/Commerce.Infrastructure.csproj" \
  "Commerce.Api/Commerce.Api.csproj" \
  "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"

# 4. LogService (Port 5436, log_db)
update_service "LogService" \
  "src/Services/Log" \
  "Log.Infrastructure/Log.Infrastructure.csproj" \
  "Log.Api/Log.Api.csproj" \
  "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"

# 5. AuctionService (Port 5437, auction_db)
update_service "AuctionService" \
  "src/Services/Auction" \
  "Auction.Infrastructure/Auction.Infrastructure.csproj" \
  "Auction.Api/Auction.Api.csproj" \
  "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"

# 6. FulfillmentService (Port 5438, fulfillment_db)
update_service "FulfillmentService" \
  "src/Services/Fulfillment" \
  "Fulfillment.Infrastructure/Fulfillment.Infrastructure.csproj" \
  "Fulfillment.Api/Fulfillment.Api.csproj" \
  "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"

# 7. NotificationService (Port 5439, notification_db)
update_service "NotificationService" \
  "src/Services/Notification" \
  "Notification.Infrastructure/Notification.Infrastructure.csproj" \
  "Notification.Api/Notification.Api.csproj" \
  "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"

# 8. WalletService (Port 5440, wallet_db)
update_service "WalletService" \
  "src/Services/Wallet" \
  "Wallet.Infrastructure/Wallet.Infrastructure.csproj" \
  "Wallet.Api/Wallet.Api.csproj" \
  "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"

echo ""
echo "================================================================="
echo " 3. KIỂM CHỨNG BẢNG DỮ LIỆU ĐÃ TẠO TRÊN 8 DATABASE"
echo "================================================================="

check_tables() {
  local container="$1"
  local dbname="$2"
  echo "--- [$container / $dbname] ---"
  docker exec "$container" psql -U postgres -d "$dbname" -c "\dt" | head -n 25
}

check_tables "nexus-user-db" "usermanagement_db"
check_tables "nexus-catalog-db" "catalog_db"
check_tables "nexus-commerce-db" "commerce_db"
check_tables "nexus-log-db" "log_db"
check_tables "nexus-auction-db" "auction_db"
check_tables "nexus-fulfillment-db" "fulfillment_db"
check_tables "nexus-notification-db" "notification_db"
check_tables "nexus-wallet-db" "wallet_db"

echo ""
echo "================================================================="
echo " [HOÀN TẤT] TẤT CẢ 8 CSDL ĐÃ ĐƯỢC MIGRATION THÀNH CÔNG!"
echo "================================================================="
