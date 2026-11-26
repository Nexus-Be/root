#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Disable proxy for localhost
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"
export ASPNETCORE_ENVIRONMENT=Development
export REDIS_CONNECTION_STRING="localhost:6379"

mkdir -p /tmp/nexus_logs

cleanup() {
  echo "Shutting down services..."
  kill $(jobs -p) 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Helper function to convert postgresql:// URI to ADO.NET connection string with Channel Binding=Disable for Neon Cloud
format_neon_conn() {
  local uri="$1"
  if [[ "$uri" =~ ^Host= ]]; then
    if [[ ! "$uri" =~ "Channel Binding" ]]; then
      echo "${uri};Channel Binding=Disable"
    else
      echo "$uri"
    fi
    return
  fi
  # Parse URI: postgresql://user:pass@host/db?...
  python3 -c "
import urllib.parse, sys
u = urllib.parse.urlparse('''$uri''')
user = urllib.parse.unquote(u.username or '')
password = urllib.parse.unquote(u.password or '')
host = u.hostname or ''
port = u.port or 5432
db = u.path.lstrip('/')
print(f'Host={host};Port={port};Database={db};Username={user};Password={password};SSL Mode=Require;Trust Server Certificate=true;Channel Binding=Disable')
"
}

# 1. User (Port 8001, Neon Cloud DB)
RAW_USER_CONN=$(grep USER_DB_CONNECTION "$REPO_ROOT/src/Services/User/.env" | cut -d'=' -f2-)
USER_CONN=$(format_neon_conn "$RAW_USER_CONN")
(
  cd "$REPO_ROOT/src/Services/User"
  export ConnectionStrings__DefaultConnection="$USER_CONN"
  export USER_DB_CONNECTION="$USER_CONN"
  export REDIS_CONNECTION_STRING="localhost:6379"
  export JWT_ISSUER="http://localhost:8001"
  export JWT_AUDIENCE="shoppingcart-api"
  export JWT_SIGNATURE="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export NOTIFICATION_SERVICE_URL="http://localhost:8007"
  exec dotnet run --project User.Api/User.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/user.log 2>&1 &
echo "Started UserService (PID: $!)."

# 2. Catalog (Port 8002, Neon Cloud DB)
RAW_CATALOG_CONN=$(grep CATALOG_DB_CONNECTION "$REPO_ROOT/src/Services/Catalog/.env" | cut -d'=' -f2-)
CATALOG_CONN=$(format_neon_conn "$RAW_CATALOG_CONN")
(
  cd "$REPO_ROOT/src/Services/Catalog"
  export ConnectionStrings__DefaultConnection="$CATALOG_CONN"
  export CATALOG_DB_CONNECTION="$CATALOG_CONN"
  export FULFILLMENT_SERVICE_URL="http://localhost:8006"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  exec dotnet run --project Catalog.Api/Catalog.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/catalog.log 2>&1 &
echo "Started CatalogService (PID: $!)."

# 3. Fulfillment (Port 8006, Neon Cloud DB)
RAW_FULFILLMENT_CONN=$(grep FULFILLMENT_DB_CONNECTION "$REPO_ROOT/src/Services/Fulfillment/.env" | cut -d'=' -f2-)
FULFILLMENT_CONN=$(format_neon_conn "$RAW_FULFILLMENT_CONN")
(
  cd "$REPO_ROOT/src/Services/Fulfillment"
  export ConnectionStrings__DefaultConnection="$FULFILLMENT_CONN"
  export FULFILLMENT_DB_CONNECTION="$FULFILLMENT_CONN"
  export COMMERCE_SERVICE_URL="http://localhost:8003"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export GHN_BASE_URL="https://dev-online-gateway.ghn.vn"
  export GHN_TOKEN="1e2442e5-1e19-477b-8955-cffc3ce9dbf0"
  export GHN_SHOP_ID="241623"
  export GHN_WEBHOOK_SECRET="Matkhaumanh"
  export Carriers__DefaultCarrierCode="GHN"
  exec dotnet run --project Fulfillment.Api/Fulfillment.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/fulfillment.log 2>&1 &
echo "Started FulfillmentService (PID: $!)."

# 4. Wallet (Port 8008, Neon Cloud DB)
RAW_WALLET_CONN=$(grep WALLET_DB_CONNECTION "$REPO_ROOT/src/Services/Wallet/.env" | cut -d'=' -f2-)
WALLET_CONN=$(format_neon_conn "$RAW_WALLET_CONN")
(
  cd "$REPO_ROOT/src/Services/Wallet"
  export ConnectionStrings__DefaultConnection="$WALLET_CONN"
  export WALLET_DB_CONNECTION="$WALLET_CONN"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  exec dotnet run --project Wallet.Api/Wallet.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/wallet.log 2>&1 &
echo "Started WalletService (PID: $!)."

# 5. Notification (Port 8007, Neon Cloud DB)
RAW_NOTIFICATION_CONN=$(grep NOTIFICATION_DB_CONNECTION "$REPO_ROOT/src/Services/Notification/.env" | cut -d'=' -f2-)
NOTIFICATION_CONN=$(format_neon_conn "$RAW_NOTIFICATION_CONN")
(
  cd "$REPO_ROOT/src/Services/Notification"
  export ConnectionStrings__DefaultConnection="$NOTIFICATION_CONN"
  export NOTIFICATION_DB_CONNECTION="$NOTIFICATION_CONN"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  exec dotnet run --project Notification.Api/Notification.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/notification.log 2>&1 &
echo "Started NotificationService (PID: $!)."

# 6. Commerce (Port 8003, Neon Cloud DB)
RAW_COMMERCE_CONN=$(grep COMMERCE_DB_CONNECTION "$REPO_ROOT/src/Services/Commerce/.env" | cut -d'=' -f2-)
COMMERCE_CONN=$(format_neon_conn "$RAW_COMMERCE_CONN")
(
  cd "$REPO_ROOT/src/Services/Commerce"
  export ConnectionStrings__DefaultConnection="$COMMERCE_CONN"
  export COMMERCE_DB_CONNECTION="$COMMERCE_CONN"
  export FULFILLMENT_SERVICE_URL="http://localhost:8006"
  export USER_SERVICE_URL="http://localhost:8001"
  export CATALOG_SERVICE_URL="http://localhost:8002"
  export WALLET_SERVICE_URL="http://localhost:8008"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  exec dotnet run --project Commerce.Api/Commerce.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/commerce.log 2>&1 &
echo "Started CommerceService (PID: $!)."

# 7. Auction (Port 8005, Neon Cloud DB)
RAW_AUCTION_CONN=$(grep AUCTION_DB_CONNECTION "$REPO_ROOT/src/Services/Auction/.env" | cut -d'=' -f2-)
AUCTION_CONN=$(format_neon_conn "$RAW_AUCTION_CONN")
(
  cd "$REPO_ROOT/src/Services/Auction"
  export ConnectionStrings__DefaultConnection="$AUCTION_CONN"
  export AUCTION_DB_CONNECTION="$AUCTION_CONN"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export WALLET_SERVICE_URL="http://localhost:8008"
  export USER_SERVICE_URL="http://localhost:8001"
  exec dotnet run --project Auction.Api/Auction.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/auction.log 2>&1 &
echo "Started AuctionService (PID: $!)."

# 8. Log (Port 8004, Neon Cloud DB)
RAW_LOG_CONN=$(grep LOG_DB_CONNECTION "$REPO_ROOT/src/Services/Log/.env" | cut -d'=' -f2-)
LOG_CONN=$(format_neon_conn "$RAW_LOG_CONN")
(
  cd "$REPO_ROOT/src/Services/Log"
  export ConnectionStrings__DefaultConnection="$LOG_CONN"
  export LOG_DB_CONNECTION="$LOG_CONN"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  exec dotnet run --project Log.Api/Log.Api.csproj -c Release --no-build
) > /tmp/nexus_logs/log.log 2>&1 &
echo "Started LogService (PID: $!)."

# 9. Gateway (Port 8080)
(
  cd "$REPO_ROOT/src/Services/Gateway"
  export JWT_ISSUER="http://localhost:8001"
  export JWT_AUDIENCE="shoppingcart-api"
  export JWT_SIGNATURE="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export INTERNAL_SERVICE_SECRET="eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e"
  export REDIS_CONNECTION_STRING="localhost:6379"
  exec dotnet run --project Gateway/Gateway.csproj -c Release --no-build
) > /tmp/nexus_logs/gateway.log 2>&1 &
echo "Started Gateway (PID: $!)."

echo "All services launched. Waiting on child processes..."
wait
