#!/usr/bin/env bash
# GW-001..009: edge gateway invariants (port, statelessness, routing, pipeline).
# Spec: src/Services/Gateway/AGENTS.md, Gateway/specs/01_ARCHITECTURE.md, specs/06.

set -uo pipefail
CHECK_NAME="gateway"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

if [ -n "${SCRIPTTEST_SERVICE:-}" ] && [ "$SCRIPTTEST_SERVICE" != "Gateway" ]; then
  printf '%sgateway%s: skipped (--service %s)\n' "$C_DIM" "$C_RESET" "$SCRIPTTEST_SERVICE"
  exit 0
fi

gateway_root="$ROOT/src/Services/Gateway"
if [ ! -d "$gateway_root" ]; then
  printf '%sgateway%s: skipped (no src/Services/Gateway)\n' "$C_DIM" "$C_RESET"
  exit 0
fi

program="$gateway_root/Gateway/Program.cs"
appsettings="$gateway_root/Gateway/appsettings.json"
launchsettings="$gateway_root/Gateway/Properties/launchSettings.json"
client_context="$gateway_root/Gateway/Middlewares/Global/ClientContextMiddleware.cs"

# GW-001: the edge port is invariant.
if [ -f "$launchsettings" ]; then
  if ! grep -q 'localhost:8080' "$launchsettings"; then
    record ERROR GW-001 "$launchsettings" "$(line_of "$launchsettings" 'applicationUrl')" \
      "Gateway must listen on port 8080."
  fi
else
  record ERROR GW-001 "$gateway_root" 1 \
    "Gateway launchSettings.json is missing; port 8080 cannot be verified."
fi

# GW-002: the gateway is stateless and owns no database.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR GW-002 "$HIT_FILE" "$HIT_LINE" \
    "Gateway must stay stateless; no DbContext, EF Core or Npgsql."
done < <(
  find "$gateway_root" \
    \( -type d \( -name bin -o -name obj -o -name .git \) -prune \) \
    -o -type f \( -name '*.cs' -o -name '*.csproj' \) -print0 2>/dev/null \
    | xargs -0 grep -nE 'DbContext|EntityFrameworkCore|Npgsql' 2>/dev/null || true
)

# GW-003, GW-004, GW-005: reverse proxy routes.
if [ -f "$appsettings" ]; then
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    line_no="${entry%%:*}"
    path="$(printf '%s' "${entry#*:}" | sed -E 's/.*"Path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    [ -n "$path" ] || continue

    case "$path" in
      /api/v1/*|/health*|/swagger*|/) ;;
      *)
        record ERROR GW-003 "$appsettings" "$line_no" \
          "Proxy route '$path' must start with /api/v1/ (only health and docs may differ)."
        ;;
    esac

    case "$path" in
      *internal*)
        record ERROR GW-003 "$appsettings" "$line_no" \
          "Proxy route '$path' exposes internal service paths."
        ;;
    esac

    case "$path" in
      /api/v1/user/*|/api/v1/seller/*|/api/v1/product/*|/api/v1/category/*|/api/v1/cart/*|/api/v1/order/*|\
      /api/v1/sub-order/*|/api/v1/checkout/*|/api/v1/wallet/*|/api/v1/auction/*|/api/v1/bid/*|\
      /api/v1/notification/*|/api/v1/log/*|/api/v1/shipment/*|/api/v1/warehouse/*|/api/v1/inventory/*)
        record ERROR GW-004 "$appsettings" "$line_no" \
          "Proxy route '$path' uses a singular collection segment."
        ;;
    esac

    case "$path" in
      /api/v1/admin/'{**catch-all}')
        record ERROR GW-005 "$appsettings" "$line_no" \
          "Admin traffic must be split per domain, not one catch-all route."
        ;;
    esac
  done < <(grep -nE '"Path"[[:space:]]*:' "$appsettings" 2>/dev/null || true)
else
  record ERROR GW-003 "$gateway_root" 1 "Gateway appsettings.json is missing."
fi

# GW-006: the middleware pipeline must keep its ordering guarantees.
if [ -f "$program" ]; then
  for middleware in \
    ClientContextMiddleware \
    GlobalExceptionMiddleware \
    ResponseEnvelopeMiddleware \
    IdempotencyGuardMiddleware \
    AdminAuthorizationGuardMiddleware; do
    if ! grep -q "$middleware" "$program"; then
      record ERROR GW-006 "$program" 1 \
        "Gateway pipeline is missing $middleware."
    fi
  done

  if ! grep -q 'AddIdentityPropagation' "$program"; then
    record ERROR GW-006 "$program" 1 \
      "YARP must register AddIdentityPropagation for downstream identity headers."
  fi
else
  record ERROR GW-006 "$gateway_root" 1 "Gateway Program.cs is missing."
fi

# GW-007: anti-spoofing and internal route blocking.
if [ -f "$client_context" ]; then
  for header in \
    x-user-id \
    x-user-email \
    x-user-roles \
    x-user-role \
    x-user-permissions \
    x-user-permission \
    x-internal-service-key; do
    if ! grep -q "\"$header\"" "$client_context"; then
      record ERROR GW-007 "$client_context" 1 \
        "ClientContextMiddleware must reject the spoofed header '$header'."
    fi
  done

  if ! grep -q 'FORBIDDEN_HEADER_SPOOFING' "$client_context"; then
    record ERROR GW-007 "$client_context" 1 \
      "Spoofed headers must return errorCode FORBIDDEN_HEADER_SPOOFING."
  fi

  if ! grep -q '/api/v1/internal' "$client_context"; then
    record ERROR GW-007 "$client_context" 1 \
      "ClientContextMiddleware must block /api/v1/internal with 404."
  fi
else
  record ERROR GW-007 "$gateway_root" 1 "ClientContextMiddleware.cs is missing."
fi

# GW-008: Redis is shared infrastructure, never a local container.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR GW-008 "$HIT_FILE" "$HIT_LINE" \
    "Gateway must not declare its own Redis container."
done < <(
  find "$gateway_root" -maxdepth 3 -type f \( -name 'docker-compose*.yml' -o -name 'Dockerfile' \) -print0 2>/dev/null \
    | xargs -0 grep -nE 'image:[[:space:]]*.*redis' 2>/dev/null || true
)

# GW-009: contract tests are the executable source of truth for these invariants.
if [ ! -f "$gateway_root/Gateway.Tests/ArchitecturalContractInvariantTests.cs" ]; then
  record WARN GW-009 "$gateway_root" 1 \
    "Gateway.Tests/ArchitecturalContractInvariantTests.cs is missing."
fi

finish
exit $?
