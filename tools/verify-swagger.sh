#!/usr/bin/env bash
set -u

GATEWAY="http://localhost:8080"
SERVICES=(
  "user:8001"
  "catalog:8002"
  "commerce:8003"
  "log:8004"
  "auction:8005"
  "fulfillment:8006"
  "notification:8007"
  "wallet:8008"
  "checkheal:8009"
)

pass=0
fail=0

report() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf 'PASS  %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

status_of() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$1"
}

redirect_of() {
  curl -s -o /dev/null -w '%{redirect_url}' --max-time 8 "$1"
}

openapi_ok() {
  local url="$1"
  local min_paths="${2:-1}"
  curl -s --max-time 8 "$url" | python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'openapi' not in doc:
    sys.exit(1)
if len(doc.get('paths', {})) < $min_paths:
    sys.exit(1)
"
}

gateway_doc_ok() {
  python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'openapi' not in doc:
    sys.exit(1)
if any('/swagger/downstream' in path for path in doc.get('paths', {})):
    sys.exit(1)
"
}

no_identity_schemes_ok() {
  python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)
schemes = set(doc.get('components', {}).get('securitySchemes', {}))
forbidden = {'x-user-id', 'x-user-roles', 'x-user-email', 'x-user-permissions', 'X-Internal-Service-Key'}
sys.exit(0 if not (schemes & forbidden) else 1)
"
}

no_internal_paths_ok() {
  python3 -c "
import json, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)
paths = doc.get('paths', {})
has_internal = any('/internal/' in p or p.startswith('/api/v1/internal') for p in paths)
sys.exit(1 if has_internal else 0)
"
}

echo "Backend services"
for entry in "${SERVICES[@]}"; do
  name="${entry%%:*}"
  port="${entry##*:}"
  base="http://localhost:$port"

  report "$name /swagger/index.html" "200" "$(status_of "$base/swagger/index.html")"
  report "$name swagger-ui-bundle.js" "200" "$(status_of "$base/swagger/swagger-ui-bundle.js")"
  openapi_ok "$base/swagger/v1/swagger.json"
  report "$name swagger.json valid" "0" "$?"
  report "$name / redirect code" "302" "$(status_of "$base/")"
  report "$name / redirect target" "$base/swagger" "$(redirect_of "$base/")"
done

echo
echo "Gateway"
report "gateway /swagger/index.html" "200" "$(status_of "$GATEWAY/swagger/index.html")"
report "gateway / redirect code" "302" "$(status_of "$GATEWAY/")"
report "gateway / redirect target" "$GATEWAY/swagger" "$(redirect_of "$GATEWAY/")"

gateway_doc_ok < <(curl -s --max-time 8 "$GATEWAY/swagger/v1/swagger.json")
report "gateway doc valid and no proxy path" "0" "$?"

url_count=$(curl -s --max-time 8 "$GATEWAY/swagger/index.html" | grep -o '"url":"/swagger[^"]*"' | wc -l | tr -d ' ')
report "gateway swagger url count" "10" "$url_count"

doc_expansion=$(curl -s --max-time 8 "$GATEWAY/swagger/index.html" | grep -o '"docExpansion":"list"' | wc -l | tr -d ' ')
report "gateway docExpansion is list" "1" "$doc_expansion"

first_url=$(curl -s --max-time 8 "$GATEWAY/swagger/index.html" | grep -o '"url":"/swagger/downstream/user/swagger.json"' | head -1)
report "gateway first swagger endpoint is user" '"url":"/swagger/downstream/user/swagger.json"' "$first_url"

for entry in "${SERVICES[@]}"; do
  name="${entry%%:*}"
  document_url="$GATEWAY/swagger/downstream/$name/swagger.json"

  report "downstream $name status" "200" "$(status_of "$document_url")"

  openapi_ok "$document_url"
  report "downstream $name valid" "0" "$?"

  no_identity_schemes_ok < <(curl -s --max-time 8 "$document_url")
  report "downstream $name no identity schemes" "0" "$?"

  no_internal_paths_ok < <(curl -s --max-time 8 "$document_url")
  report "downstream $name no internal paths" "0" "$?"
done

echo
echo "Summary: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
