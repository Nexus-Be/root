#!/usr/bin/env bash
# =============================================================================
# NEXUS ECOSYSTEM - ENVIRONMENT SYNCHRONIZATION SCRIPT
# =============================================================================
# Khởi tạo các file .env từ mẫu .env.example chuẩn hóa.
# Bảo vệ an toàn: Không ghi đè các file .env đã chứa bí mật thực tế trừ khi có cờ --force.
# Cách dùng:
#   ./scripts/sync-env.sh          # Tạo mới .env nếu chưa có, giữ nguyên nếu đã có
#   ./scripts/sync-env.sh --force  # Ghi đè toàn bộ bằng template .env.example
# =============================================================================

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FORCE_OVERWRITE=false
if [ "$1" == "--force" ]; then
    FORCE_OVERWRITE=true
fi

echo "=================================================================="
if [ "$FORCE_OVERWRITE" = true ]; then
    echo ">>> [CẢNH BÁO] Chế độ --force: Ghi đè toàn bộ .env bằng .env.example..."
else
    echo ">>> Khởi tạo / kiểm tra các file cấu hình môi trường (.env.example -> .env)..."
fi
echo "=================================================================="

copy_env() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$src" ]; then
        echo "[WARN] Không tìm thấy template: $src"
        return
    fi

    if [ -f "$dst" ] && [ "$FORCE_OVERWRITE" = false ]; then
        echo "[EXISTS] Giữ nguyên $dst (đã tồn tại, bảo vệ bí mật thực tế)"
    else
        cp "$src" "$dst"
        echo "[CREATED] Đã sao chép: $src -> $dst"
    fi
}

# 1. Root
copy_env ".env.example" ".env"

# 2. Infrastructure
copy_env "src/Infrastructure/.env.example" "src/Infrastructure/.env"

# 3. 9 Microservices + CheckHeal
copy_env "src/Services/ApiGateway/.env.example" "src/Services/ApiGateway/.env"
copy_env "src/Services/User/.env.example" "src/Services/User/.env"
copy_env "src/Services/Catalog/.env.example" "src/Services/Catalog/.env"
copy_env "src/Services/Commerce/.env.example" "src/Services/Commerce/.env"
copy_env "src/Services/Log/.env.example" "src/Services/Log/.env"
copy_env "src/Services/Auction/.env.example" "src/Services/Auction/.env"
copy_env "src/Services/Fulfillment/.env.example" "src/Services/Fulfillment/.env"
copy_env "src/Services/Notification/.env.example" "src/Services/Notification/.env"
copy_env "src/Services/Wallet/.env.example" "src/Services/Wallet/.env"
copy_env "src/Services/CheckHeal/.env.example" "src/Services/CheckHeal/.env"

echo "=================================================================="
echo ">>> Hoàn tất xử lý cấu hình môi trường!"
echo "=================================================================="
