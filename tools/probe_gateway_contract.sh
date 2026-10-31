#!/usr/bin/env bash
# Proves the gateway edge contract against a running stack.
# Requires: curl, the gateway on :8080 and at least the user service on :8001.
set -uo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://localhost:8080}"
SERVICE_URL="${SERVICE_URL:-http://localhost:8001}"
REQUIRE_SIGNATURE="${GATEWAY_REQUIRE_SIGNATURE:-false}"
TEST_USER_ID="11111111-1111-1111-1111-111111111111"

failures=0

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1 (expected $2, got $3)"; failures=$((failures + 1)); }
info() { echo "INFO  $1"; }

status() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"
}

echo "Gateway contract probe"
echo "gateway=${GATEWAY_URL} service=${SERVICE_URL} require_signature=${REQUIRE_SIGNATURE}"
echo

# 1. Spoofed identity header must be rejected at the edge before routing.
code=$(status -H "x-user-id: ${TEST_USER_ID}" -H "x-user-roles: admin" \
  "${GATEWAY_URL}/api/v1/users/${TEST_USER_ID}")
if [ "$code" = "403" ]; then
  pass "spoofed identity header rejected at gateway"
else
  fail "spoofed identity header rejected at gateway" "403" "$code"
fi

# 2. Direct call with spoofed identity must fail once signature enforcement is on.
code=$(status -H "x-user-id: ${TEST_USER_ID}" -H "x-user-roles: admin" \
  "${SERVICE_URL}/api/v1/users/${TEST_USER_ID}")
if [ "$REQUIRE_SIGNATURE" = "true" ]; then
  if [ "$code" = "401" ]; then
    pass "unsigned direct call refused by user service"
  else
    fail "unsigned direct call refused by user service" "401" "$code"
  fi
else
  info "signature enforcement is off in this environment, direct call returned ${code}"
fi

# 3. Internal service routes are unreachable through the gateway.
code=$(status "${GATEWAY_URL}/api/v1/internal/wallets/checkout/direct")
if [ "$code" = "404" ]; then
  pass "internal path blocked at gateway"
else
  fail "internal path blocked at gateway" "404" "$code"
fi

# 4. Password reset email request is rate limited at the edge.
body='{"email":"probe@example.com"}'
for attempt in 1 2 3 4; do
  code=$(status -X POST -H "Content-Type: application/json" -d "$body" \
    "${GATEWAY_URL}/api/v1/auth/password/forgot")
  if [ "$attempt" -lt 4 ] && [ "$code" = "429" ]; then
    fail "forgot-password allowed before the limit" "not 429 on attempt ${attempt}" "$code"
    break
  fi
done
if [ "$code" = "429" ]; then
  pass "forgot-password rate limited on attempt 4"
else
  fail "forgot-password rate limited on attempt 4" "429" "$code"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "OK: gateway contract holds"
  exit 0
fi

echo "FAILED: ${failures} probe(s)"
exit 1
