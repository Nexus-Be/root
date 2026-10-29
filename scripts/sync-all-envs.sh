#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Hàm cập nhật hoặc thêm key vào file .env
set_env_var() {
  local file="$1"
  local key="$2"
  local val="$3"

  if [ ! -f "$file" ]; then
    return 0
  fi

  if grep -q "^${key}=" "$file"; then
    # Dùng awk hoặc python hoặc sed an toàn với ký tự đặc biệt như $, &, /
    python3 -c "
import sys
fpath = sys.argv[1]
k = sys.argv[2]
v = sys.argv[3]
with open(fpath, 'r', encoding='utf-8') as f:
    lines = f.readlines()
new_lines = []
found = False
for line in lines:
    if line.startswith(k + '='):
        new_lines.append(f'{k}={v}\n')
        found = True
    else:
        new_lines.append(line)
if not found:
    new_lines.append(f'{k}={v}\n')
with open(fpath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
" "$file" "$key" "$val"
  else
    echo "${key}=${val}" >> "$file"
  fi
}

# Thay thế bất kỳ dòng nào chứa neon.tech trong file .env
clean_neon() {
  local file="$1"
  local new_conn="$2"
  if [ -f "$file" ]; then
    python3 -c "
import sys, re
fpath = sys.argv[1]
conn = sys.argv[2]
with open(fpath, 'r', encoding='utf-8') as f:
    content = f.read()
# Thay thế tất cả chuỗi kết nối chứa neon.tech
lines = content.splitlines(keepends=True)
res = []
for line in lines:
    if 'neon.tech' in line:
        k = line.split('=', 1)[0].strip()
        res.append(f'{k}={conn}\n')
    else:
        res.append(line)
with open(fpath, 'w', encoding='utf-8') as f:
    f.writelines(res)
" "$file" "$new_conn"
  fi
}

echo "================================================================="
echo " ĐỒNG BỘ CÁC THÔNG TIN CHUNG VÀ CƠ SỞ DỮ LIỆU LOCAL VÀO TẤT CẢ .ENV"
echo "================================================================="

JWT_KEY='$d)aam<_ze0E0bGB/5b7YE|^(sxQF_V(,dZusL*?$G{aqgXd&$M#+wd(R+<JN%eZ'
CHECKHEAL_KEY='j-E<34$h_R}K2[Q1&Yo:SbM6({I?6M88[23!nQ3bJinj@P5:u8?JRw3RKnMRm93E0Q*H1D=)]S#,=ZcEa+KmKC'

# 1. ROOT .ENV
ROOT_ENV="$REPO_ROOT/.env"
if [ ! -f "$ROOT_ENV" ]; then
  cp "$REPO_ROOT/.env.example" "$ROOT_ENV"
fi

clean_neon "$ROOT_ENV" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"

set_env_var "$ROOT_ENV" "USER_CONNECTION_STRING" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "CATALOG_CONNECTION_STRING" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "COMMERCE_CONNECTION_STRING" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "LOG_CONNECTION_STRING" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "AUCTION_CONNECTION_STRING" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "FULFILLMENT_CONNECTION_STRING" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "NOTIFICATION_CONNECTION_STRING" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_var "$ROOT_ENV" "WALLET_CONNECTION_STRING" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"

set_env_var "$ROOT_ENV" "USER_DB_PORT" "5433"
set_env_var "$ROOT_ENV" "CATALOG_DB_PORT" "5434"
set_env_var "$ROOT_ENV" "COMMERCE_DB_PORT" "5435"
set_env_var "$ROOT_ENV" "LOG_DB_PORT" "5436"
set_env_var "$ROOT_ENV" "AUCTION_DB_PORT" "5437"
set_env_var "$ROOT_ENV" "FULFILLMENT_DB_PORT" "5438"
set_env_var "$ROOT_ENV" "NOTIFICATION_DB_PORT" "5439"
set_env_var "$ROOT_ENV" "WALLET_DB_PORT" "5440"

set_env_var "$ROOT_ENV" "POSTGRES_USER" "postgres"
set_env_var "$ROOT_ENV" "POSTGRES_PASSWORD" "postgres"

set_env_var "$ROOT_ENV" "REDIS_CONNECTION_STRING" "localhost:6379"
set_env_var "$ROOT_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$ROOT_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$ROOT_ENV" "RABBITMQ_USER" "guest"
set_env_var "$ROOT_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$ROOT_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"

set_env_var "$ROOT_ENV" "JWT_ISSUER" "http://localhost:8001"
set_env_var "$ROOT_ENV" "JWT_AUDIENCE" "shoppingcart-api"
set_env_var "$ROOT_ENV" "JWT_SIGNATURE" "$JWT_KEY"
set_env_var "$ROOT_ENV" "JWT_EXPIRATION_IN_MINUTES" "60"
set_env_var "$ROOT_ENV" "CHECKHEAL_API_KEY" "$CHECKHEAL_KEY"

echo ">>> [OK] Root .env đã cập nhật."

# 2. USER SERVICE .ENV
USER_ENV="$REPO_ROOT/src/Services/User/.env"
if [ ! -f "$USER_ENV" ]; then
  cp "$REPO_ROOT/src/Services/User/.env.example" "$USER_ENV"
fi
clean_neon "$USER_ENV" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$USER_ENV" "CONNECTION_STRING" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$USER_ENV" "USER_CONNECTION_STRING" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$USER_ENV" "USER_DB_PORT" "5433"
set_env_var "$USER_ENV" "POSTGRES_USER" "postgres"
set_env_var "$USER_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$USER_ENV" "REDIS_CONNECTION_STRING" "localhost:6379"
set_env_var "$USER_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$USER_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$USER_ENV" "RABBITMQ_USER" "guest"
set_env_var "$USER_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$USER_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
set_env_var "$USER_ENV" "JWT_ISSUER" "http://localhost:8001"
set_env_var "$USER_ENV" "JWT_AUDIENCE" "shoppingcart-api"
set_env_var "$USER_ENV" "JWT_SIGNATURE" "$JWT_KEY"
set_env_var "$USER_ENV" "JWT_SECRET" "$JWT_KEY"
set_env_var "$USER_ENV" "JWT_EXPIRATION_IN_MINUTES" "60"
echo ">>> [OK] User Service .env đã sạch Neon & đồng bộ sang Localhost (5433)."

# 3. CATALOG SERVICE .ENV
CATALOG_ENV="$REPO_ROOT/src/Services/Catalog/.env"
if [ ! -f "$CATALOG_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Catalog/.env.example" "$CATALOG_ENV"
fi
clean_neon "$CATALOG_ENV" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_var "$CATALOG_ENV" "CONNECTION_STRING" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_var "$CATALOG_ENV" "CATALOG_CONNECTION_STRING" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_var "$CATALOG_ENV" "CATALOG_DB_PORT" "5434"
set_env_var "$CATALOG_ENV" "POSTGRES_USER" "postgres"
set_env_var "$CATALOG_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$CATALOG_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$CATALOG_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$CATALOG_ENV" "RABBITMQ_USER" "guest"
set_env_var "$CATALOG_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$CATALOG_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Catalog Service .env đã sạch Neon & đồng bộ sang Localhost (5434)."

# 4. COMMERCE SERVICE .ENV
COMMERCE_ENV="$REPO_ROOT/src/Services/Commerce/.env"
if [ ! -f "$COMMERCE_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Commerce/.env.example" "$COMMERCE_ENV"
fi
clean_neon "$COMMERCE_ENV" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_var "$COMMERCE_ENV" "CONNECTION_STRING" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_var "$COMMERCE_ENV" "COMMERCE_CONNECTION_STRING" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_var "$COMMERCE_ENV" "COMMERCE_DB_PORT" "5435"
set_env_var "$COMMERCE_ENV" "POSTGRES_USER" "postgres"
set_env_var "$COMMERCE_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$COMMERCE_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$COMMERCE_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$COMMERCE_ENV" "RABBITMQ_USER" "guest"
set_env_var "$COMMERCE_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$COMMERCE_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Commerce Service .env đã sạch Neon & đồng bộ sang Localhost (5435)."

# 5. LOG SERVICE .ENV
LOG_ENV="$REPO_ROOT/src/Services/Log/.env"
if [ ! -f "$LOG_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Log/.env.example" "$LOG_ENV"
fi
clean_neon "$LOG_ENV" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_var "$LOG_ENV" "CONNECTION_STRING" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_var "$LOG_ENV" "LOG_CONNECTION_STRING" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_var "$LOG_ENV" "LOG_DB_PORT" "5436"
set_env_var "$LOG_ENV" "POSTGRES_USER" "postgres"
set_env_var "$LOG_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$LOG_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$LOG_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$LOG_ENV" "RABBITMQ_USER" "guest"
set_env_var "$LOG_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$LOG_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Log Service .env đã sạch Neon & đồng bộ sang Localhost (5436)."

# 6. AUCTION SERVICE .ENV
AUCTION_ENV="$REPO_ROOT/src/Services/Auction/.env"
if [ ! -f "$AUCTION_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Auction/.env.example" "$AUCTION_ENV"
fi
clean_neon "$AUCTION_ENV" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_var "$AUCTION_ENV" "CONNECTION_STRING" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_var "$AUCTION_ENV" "AUCTION_CONNECTION_STRING" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_var "$AUCTION_ENV" "AUCTION_DB_PORT" "5437"
set_env_var "$AUCTION_ENV" "POSTGRES_USER" "postgres"
set_env_var "$AUCTION_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$AUCTION_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$AUCTION_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$AUCTION_ENV" "RABBITMQ_USER" "guest"
set_env_var "$AUCTION_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$AUCTION_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Auction Service .env đã sạch Neon & đồng bộ sang Localhost (5437)."

# 7. FULFILLMENT SERVICE .ENV
FULFILLMENT_ENV="$REPO_ROOT/src/Services/Fulfillment/.env"
if [ ! -f "$FULFILLMENT_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Fulfillment/.env.example" "$FULFILLMENT_ENV"
fi
clean_neon "$FULFILLMENT_ENV" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_var "$FULFILLMENT_ENV" "CONNECTION_STRING" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_var "$FULFILLMENT_ENV" "FULFILLMENT_CONNECTION_STRING" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_var "$FULFILLMENT_ENV" "FULFILLMENT_DB_PORT" "5438"
set_env_var "$FULFILLMENT_ENV" "POSTGRES_USER" "postgres"
set_env_var "$FULFILLMENT_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$FULFILLMENT_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$FULFILLMENT_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$FULFILLMENT_ENV" "RABBITMQ_USER" "guest"
set_env_var "$FULFILLMENT_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$FULFILLMENT_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Fulfillment Service .env đã sạch Neon & đồng bộ sang Localhost (5438)."

# 8. NOTIFICATION SERVICE .ENV
NOTIFICATION_ENV="$REPO_ROOT/src/Services/Notification/.env"
if [ ! -f "$NOTIFICATION_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Notification/.env.example" "$NOTIFICATION_ENV"
fi
clean_neon "$NOTIFICATION_ENV" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_var "$NOTIFICATION_ENV" "CONNECTION_STRING" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_var "$NOTIFICATION_ENV" "NOTIFICATION_CONNECTION_STRING" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_var "$NOTIFICATION_ENV" "NOTIFICATION_DB_PORT" "5439"
set_env_var "$NOTIFICATION_ENV" "POSTGRES_USER" "postgres"
set_env_var "$NOTIFICATION_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$NOTIFICATION_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$NOTIFICATION_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$NOTIFICATION_ENV" "RABBITMQ_USER" "guest"
set_env_var "$NOTIFICATION_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$NOTIFICATION_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Notification Service .env đã sạch Neon & đồng bộ sang Localhost (5439)."

# 9. WALLET SERVICE .ENV
WALLET_ENV="$REPO_ROOT/src/Services/Wallet/.env"
if [ ! -f "$WALLET_ENV" ]; then
  cp "$REPO_ROOT/src/Services/Wallet/.env.example" "$WALLET_ENV"
fi
clean_neon "$WALLET_ENV" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"
set_env_var "$WALLET_ENV" "CONNECTION_STRING" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"
set_env_var "$WALLET_ENV" "WALLET_CONNECTION_STRING" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"
set_env_var "$WALLET_ENV" "WALLET_DB_PORT" "5440"
set_env_var "$WALLET_ENV" "POSTGRES_USER" "postgres"
set_env_var "$WALLET_ENV" "POSTGRES_PASSWORD" "postgres"
set_env_var "$WALLET_ENV" "RABBITMQ_HOST" "localhost"
set_env_var "$WALLET_ENV" "RABBITMQ_PORT" "5672"
set_env_var "$WALLET_ENV" "RABBITMQ_USER" "guest"
set_env_var "$WALLET_ENV" "RABBITMQ_PASSWORD" "guest"
set_env_var "$WALLET_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
echo ">>> [OK] Wallet Service .env đã sạch Neon & đồng bộ sang Localhost (5440)."

# 10. CHECKHEAL SERVICE .ENV
CHECKHEAL_ENV="$REPO_ROOT/src/Services/CheckHeal/.env"
if [ ! -f "$CHECKHEAL_ENV" ]; then
  cp "$REPO_ROOT/src/Services/CheckHeal/.env.example" "$CHECKHEAL_ENV"
fi
clean_neon "$CHECKHEAL_ENV" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "USERS_DB_CONNECTION" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "CATALOG_DB_CONNECTION" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "COMMERCE_DB_CONNECTION" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "LOG_DB_CONNECTION" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "AUCTION_DB_CONNECTION" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "FULFILLMENT_DB_CONNECTION" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "NOTIFICATION_DB_CONNECTION" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "WALLET_DB_CONNECTION" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"
set_env_var "$CHECKHEAL_ENV" "CHECKHEAL_API_KEY" "$CHECKHEAL_KEY"
echo ">>> [OK] CheckHeal Service .env đã sạch Neon & đồng bộ 8 CSDL Localhost."

# 11. APIGATEWAY .ENV
GATEWAY_ENV="$REPO_ROOT/src/Services/ApiGateway/.env"
if [ ! -f "$GATEWAY_ENV" ]; then
  cp "$REPO_ROOT/src/Services/ApiGateway/.env.example" "$GATEWAY_ENV"
fi
set_env_var "$GATEWAY_ENV" "REDIS_CONNECTION_STRING" "localhost:6379"
set_env_var "$GATEWAY_ENV" "OTEL_EXPORTER_OTLP_ENDPOINT" "http://localhost:4317"
set_env_var "$GATEWAY_ENV" "JWT_ISSUER" "http://localhost:8001"
set_env_var "$GATEWAY_ENV" "JWT_AUDIENCE" "shoppingcart-api"
set_env_var "$GATEWAY_ENV" "JWT_SIGNATURE" "$JWT_KEY"
set_env_var "$GATEWAY_ENV" "CHECKHEAL_API_KEY" "$CHECKHEAL_KEY"
echo ">>> [OK] ApiGateway .env đã đồng bộ."

echo ""
echo "================================================================="
echo " [HOÀN TẤT] 100% CÁC FILE .ENV ĐÃ ĐỒNG BỘ THÔNG TIN CHUNG VÀ LOCAL DB!"
echo "================================================================="
