#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo ">>> Tệp .env chưa tồn tại. Đang sao chép từ .env.example..."
  cp "$REPO_ROOT/.env.example" "$ENV_FILE"
  echo ">>> [OK] Đã tạo .env với cấu hình local database mặc định."
  exit 0
fi

echo ">>> Đang cập nhật chuỗi kết nối 8 CSDL sang Localhost trong tệp .env..."

# Hàm thay thế hoặc bổ sung key trong file .env
set_env_key() {
  local key="$1"
  local val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

set_env_key "USER_DB_PORT" "5433"
set_env_key "CATALOG_DB_PORT" "5434"
set_env_key "COMMERCE_DB_PORT" "5435"
set_env_key "LOG_DB_PORT" "5436"
set_env_key "AUCTION_DB_PORT" "5437"
set_env_key "FULFILLMENT_DB_PORT" "5438"
set_env_key "NOTIFICATION_DB_PORT" "5439"
set_env_key "WALLET_DB_PORT" "5440"

set_env_key "POSTGRES_USER" "postgres"
set_env_key "POSTGRES_PASSWORD" "postgres"

set_env_key "USER_CONNECTION_STRING" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_key "CATALOG_CONNECTION_STRING" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_key "COMMERCE_CONNECTION_STRING" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_key "LOG_CONNECTION_STRING" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_key "AUCTION_CONNECTION_STRING" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_key "FULFILLMENT_CONNECTION_STRING" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_key "NOTIFICATION_CONNECTION_STRING" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_key "WALLET_CONNECTION_STRING" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"

# Đồng bộ luôn biến CONNECTION_STRING ngắn
set_env_key "USERS_DB_CONNECTION" "Host=localhost;Port=5433;Database=usermanagement_db;Username=postgres;Password=postgres"
set_env_key "CATALOG_DB_CONNECTION" "Host=localhost;Port=5434;Database=catalog_db;Username=postgres;Password=postgres"
set_env_key "COMMERCE_DB_CONNECTION" "Host=localhost;Port=5435;Database=commerce_db;Username=postgres;Password=postgres"
set_env_key "LOG_DB_CONNECTION" "Host=localhost;Port=5436;Database=log_db;Username=postgres;Password=postgres"
set_env_key "AUCTION_DB_CONNECTION" "Host=localhost;Port=5437;Database=auction_db;Username=postgres;Password=postgres"
set_env_key "FULFILLMENT_DB_CONNECTION" "Host=localhost;Port=5438;Database=fulfillment_db;Username=postgres;Password=postgres"
set_env_key "NOTIFICATION_DB_CONNECTION" "Host=localhost;Port=5439;Database=notification_db;Username=postgres;Password=postgres"
set_env_key "WALLET_DB_CONNECTION" "Host=localhost;Port=5440;Database=wallet_db;Username=postgres;Password=postgres"

echo ">>> [THÀNH CÔNG] Tệp .env đã được cập nhật 100% sang Local Databases (cổng 5433-5440)!"
