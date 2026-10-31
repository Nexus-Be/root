#!/usr/bin/env bash
# Verifies that every microservice answers model binding failures with
# 400 / application problem shape carrying errorCode=VAL_INVALID_INPUT,
# and never leaks CLR type names from System.Text.Json.
set -u

INTERNAL_KEY="${INTERNAL_SERVICE_SECRET:-eaT0Ombups70WJzd85CBBpp8rAno55SxKn1qvYBGH9e}"
CHECKHEAL_KEY="${CHECKHEAL_API_KEY:-nexus_dev_checkheal_api_key_2026}"
GATEWAY="${GATEWAY:-http://localhost:8080}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LEAK_PATTERN='(User|Catalog|Commerce|Auction|Fulfillment|Log|Notification|Wallet|CheckHeal)\.(Application|Domain|Api|Infrastructure)|LineNumber|BytePositionInLine'

TOTAL=0
FAILED=0

check() {
    local label="$1" method="$2" url="$3" header="$4" data="$5"
    local args=(-s -o "$TMP/body" -w '%{http_code}' -X "$method" "$url" -H 'Content-Type: application/json')
    [ -n "$header" ] && args+=(-H "$header")
    [ -n "$data" ] && args+=(--data-binary "$data")

    local http error_code leaks verdict
    http=$(curl "${args[@]}" 2>/dev/null)
    error_code=$(jq -r '.errorCode // ""' "$TMP/body" 2>/dev/null)
    leaks=0
    grep -Eq "$LEAK_PATTERN" "$TMP/body" 2>/dev/null && leaks=1

    TOTAL=$((TOTAL + 1))
    if [ "$http" = "400" ] && [ "$error_code" = "VAL_INVALID_INPUT" ] && [ "$leaks" = "0" ]; then
        verdict=PASS
    else
        verdict=FAIL
        FAILED=$((FAILED + 1))
    fi

    printf '%-6s %-14s http=%-4s errorCode=%-18s leaks=%s\n' \
        "$verdict" "$label" "${http:-none}" "${error_code:-none}" "$leaks"

    if [ "$verdict" = "FAIL" ]; then
        printf '       body: %s\n' "$(head -c 240 "$TMP/body" | tr -d '\n')"
    fi
}

check "User"         POST "$GATEWAY/api/v1/auth/refresh" "" '{}'
check "Wallet"       POST "http://localhost:8008/api/v1/wallets/checkout/direct" "X-Internal-Service-Key: $INTERNAL_KEY" '[{'
check "Notification" POST "http://localhost:8007/api/v1/notifications/email/otp" "X-Internal-Service-Key: $INTERNAL_KEY" '[{'
check "Log"          POST "http://localhost:8004/api/v1/logs/batch" "X-Internal-Service-Key: $INTERNAL_KEY" '[{'
check "Fulfillment"  POST "http://localhost:8006/api/v1/inventories/initialize" "X-Internal-Service-Key: $INTERNAL_KEY" '[{'
check "Catalog"      GET  "http://localhost:8002/api/v1/products?page=abc" "" ""
check "Auction"      GET  "http://localhost:8005/api/v1/auctions?page=abc" "" ""
check "CheckHeal"    PUT  "http://localhost:8009/api/v1/healthcheck/bulk-toggle" "X-Api-Key: $CHECKHEAL_KEY" '[{'

echo
echo "Probes: $TOTAL  Failed: $FAILED"
[ "$FAILED" -eq 0 ]
