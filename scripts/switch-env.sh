#!/usr/bin/env bash
# =============================================================================
# NEXUS ECOSYSTEM - ENVIRONMENT SWITCHER SCRIPT (switch-env.sh)
# =============================================================================
# Tiện ích chuyển đổi môi trường CSDL (Local DB vs Server Neon Cloud DB)
#
# Cách dùng:
#   ./scripts/switch-env.sh local             # Chuyển toàn bộ hệ thống sang Local DB (Port 5433-5440)
#   ./scripts/switch-env.sh server            # Chuyển toàn bộ hệ thống sang Server DB (Neon Cloud)
#   ./scripts/switch-env.sh local <service>   # Chuyển riêng 1 service sang Local DB (ví dụ: user, catalog)
#   ./scripts/switch-env.sh server <service>  # Chuyển riêng 1 service sang Server DB
#   ./scripts/switch-env.sh status            # Xem trạng thái cấu hình hiện tại của các service
# =============================================================================

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="$1"
TARGET_SERVICE="$2"

usage() {
    echo "================================================================="
    echo "Nexus Environment Switcher"
    echo "================================================================="
    echo "Lệnh sử dụng:"
    echo "  $0 local             - Chuyển tất cả services sang Local PostgreSQL DB"
    echo "  $0 server            - Chuyển tất cả services sang Server Neon Cloud DB"
    echo "  $0 local <service>   - Chuyển riêng 1 service sang Local DB (vd: user, catalog, commerce...)"
    echo "  $0 server <service>  - Chuyển riêng 1 service sang Server DB"
    echo "  $0 status            - Kiểm tra trạng thái kết nối CSDL hiện tại"
    echo "================================================================="
    exit 1
}

if [ -z "$MODE" ]; then
    usage
fi

SERVICES=(
    "User:src/Services/User"
    "Catalog:src/Services/Catalog"
    "Commerce:src/Services/Commerce"
    "Log:src/Services/Log"
    "Auction:src/Services/Auction"
    "Fulfillment:src/Services/Fulfillment"
    "Notification:src/Services/Notification"
    "Wallet:src/Services/Wallet"
    "CheckHeal:src/Services/CheckHeal"
    "Gateway:src/Services/Gateway"
)

show_status() {
    echo "================================================================="
    echo "TRẠNG THÁI CẤU HÌNH CSDL HIỆN TẠI (.env)"
    echo "================================================================="
    for item in "${SERVICES[@]}"; do
        NAME="${item%%:*}"
        DIR="${item##*:}"
        if [ -f "$DIR/.env" ]; then
            if grep -q "neon.tech" "$DIR/.env" 2>/dev/null; then
                printf "%-15s : \033[1;36mSERVER DB (Neon Cloud)\033[0m\n" "$NAME"
            elif grep -q "localhost:54" "$DIR/.env" 2>/dev/null || grep -q "Port=54" "$DIR/.env" 2>/dev/null; then
                PORT=$(grep -o "Port=54[0-9][0-9]" "$DIR/.env" | head -n 1 || echo "Local")
                printf "%-15s : \033[1;32mLOCAL DB (%s)\033[0m\n" "$NAME" "$PORT"
            else
                printf "%-15s : \033[1;33mCUSTOM / UNKNOWN\033[0m\n" "$NAME"
            fi
        else
            printf "%-15s : \033[1;31mCHƯA CÓ .env\033[0m\n" "$NAME"
        fi
    done
    echo "================================================================="
}

if [ "$MODE" == "status" ]; then
    show_status
    exit 0
fi

if [ "$MODE" != "local" ] && [ "$MODE" != "server" ]; then
    echo "[LỖI] Chế độ '$MODE' không hợp lệ! Chỉ chấp nhận 'local', 'server' hoặc 'status'."
    usage
fi

switch_service() {
    local NAME="$1"
    local DIR="$2"
    local PROFILE="$3"
    local SRC_FILE="$DIR/.env.$PROFILE.example"
    local DST_FILE="$DIR/.env"

    if [ ! -f "$SRC_FILE" ]; then
        echo "  [BỎ QUA] $NAME: Không tìm thấy $SRC_FILE"
        return
    fi

    cp "$SRC_FILE" "$DST_FILE"
    echo "  [OK] $NAME -> Đã kích hoạt hồ sơ $PROFILE ($SRC_FILE -> $DST_FILE)"
}

echo "================================================================="
echo ">>> Đang chuyển đổi cấu hình sang hồ sơ: \033[1;32m$MODE\033[0m"
echo "================================================================="

if [ -n "$TARGET_SERVICE" ]; then
    FOUND=false
    for item in "${SERVICES[@]}"; do
        NAME="${item%%:*}"
        DIR="${item##*:}"
        LOWER_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
        LOWER_TARGET=$(echo "$TARGET_SERVICE" | tr '[:upper:]' '[:lower:]')
        if [ "$LOWER_NAME" == "$LOWER_TARGET" ]; then
            switch_service "$NAME" "$DIR" "$MODE"
            FOUND=true
            break
        fi
    done
    if [ "$FOUND" = false ]; then
        echo "[LỖI] Không tìm thấy service: '$TARGET_SERVICE'"
        exit 1
    fi
else
    # 1. Chuyển đổi Root .env
    if [ -f ".env.$MODE.example" ]; then
        cp ".env.$MODE.example" ".env"
        echo "  [OK] Root -> .env.$MODE.example -> .env"
    fi

    # 2. Chuyển đổi 10 Services (bao gồm Gateway)
    for item in "${SERVICES[@]}"; do
        NAME="${item%%:*}"
        DIR="${item##*:}"
        switch_service "$NAME" "$DIR" "$MODE"
    done
fi

echo "================================================================="
echo ">>> Chuyển đổi thành công!"
echo "================================================================="
show_status
