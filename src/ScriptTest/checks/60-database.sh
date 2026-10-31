#!/usr/bin/env bash
# DB-001..007: database governance (enum persistence, migrations, isolation).
# Spec: AGENTS.md (Database Governance & Migration Rules), specs/04.

set -uo pipefail
CHECK_NAME="database"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

base="$(services_base)" || exit 0

expected_port() {
  case "$1" in
    User) printf '5433' ;;
    Catalog) printf '5434' ;;
    Commerce) printf '5435' ;;
    Log) printf '5436' ;;
    Auction) printf '5437' ;;
    Fulfillment) printf '5438' ;;
    Notification) printf '5439' ;;
    Wallet) printf '5440' ;;
    *) printf '' ;;
  esac
}

expected_database() {
  case "$1" in
    User) printf 'user' ;;
    Catalog) printf 'catalog' ;;
    Commerce) printf 'commerce' ;;
    Log) printf 'log' ;;
    Auction) printf 'auction' ;;
    Fulfillment) printf 'fulfillment' ;;
    Notification) printf 'notification' ;;
    Wallet) printf 'wallet' ;;
    *) printf '' ;;
  esac
}

# DB-001: enums are persisted as int32, never as database strings.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR DB-001 "$HIT_FILE" "$HIT_LINE" \
    "HasConversion<string> is prohibited; enums must persist as int32."
done < <(grep_cs 'HasConversion<[[:space:]]*string' | grep -v '/Migrations/')

# DB-002: seed data must use deterministic GUIDs so the model snapshot stays stable.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"
  rest="${hit#*:}"
  line="${rest%%:*}"
  case "$file" in
    *Tests/*) ;;
    *Tests.cs) ;;
    *Configuration.cs|*/Seeds/*|*/Seeds.cs)
      record ERROR DB-002 "$file" "$line" \
        "Seed data must use deterministic GUIDs, not Guid.NewGuid()."
      ;;
  esac
done < <(grep_cs 'Guid\.NewGuid\(\)' | grep -v '/Migrations/')

# DB-003: schema must come from migrations only.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  case "$HIT_FILE" in
    *Tests/*) continue ;;
  esac
  record ERROR DB-003 "$HIT_FILE" "$HIT_LINE" \
    "EnsureCreated() is prohibited; use EF Core migrations."
done < <(grep_cs 'EnsureCreated\(' | grep -v '/Migrations/')

# DB-004 and DB-005: configuration must cover decimal precision and soft delete.
while IFS= read -r config; do
  [ -n "$config" ] || continue
  entity="$(basename "$config" Configuration.cs)"
  entity_file="$(find "$base" -type f -name "${entity}.cs" -path '*/Domain/*' 2>/dev/null | head -1 || true)"

  [ -n "$entity_file" ] || continue

  if grep -qE '\bdecimal[[:space:]]+[A-Za-z_]' "$entity_file"; then
    if ! grep -q 'HasPrecision(' "$config"; then
      record WARN DB-004 "$config" 1 \
        "Entity '$entity' has decimal properties but the configuration sets no HasPrecision(18, 2)."
    fi
  fi

  if grep -qE '\bIsDeleted\b' "$entity_file"; then
    if ! grep -q 'HasQueryFilter' "$config"; then
      record WARN DB-005 "$config" 1 \
        "Entity '$entity' has IsDeleted but the configuration declares no soft-delete query filter."
    fi
  fi
done < <(find "$base" -type f -name '*Configuration.cs' | sort)

# DB-006: cascading deletes are opt-in only.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record WARN DB-006 "$HIT_FILE" "$HIT_LINE" \
    "DeleteBehavior.Cascade is discouraged; prefer Restrict or SetNull."
done < <(grep_cs 'DeleteBehavior\.Cascade' | grep -v '/Migrations/')

# DB-007: each service must point at its own database port and name.
while IFS= read -r appsettings; do
  [ -n "$appsettings" ] || continue
  service="$(service_name "$appsettings")"
  want_port="$(expected_port "$service")"
  want_db="$(expected_database "$service")"
  [ -n "$want_db" ] || continue

  connection_line="$(grep -nE '"DefaultConnection"' "$appsettings" 2>/dev/null | head -1 || true)"
  [ -n "$connection_line" ] || continue
  line_no="${connection_line%%:*}"

  port="$(printf '%s' "$connection_line" | grep -oE 'Port=[0-9]+' | head -1 | cut -d= -f2)"
  if [ -n "$port" ] && [ -n "$want_port" ] && [ "$port" != "$want_port" ]; then
    record ERROR DB-007 "$appsettings" "$line_no" \
      "Service '$service' must connect to port $want_port, found $port."
  fi

  database="$(printf '%s' "$connection_line" | grep -oE '/[A-Za-z0-9_]+(\?|"|$)' | head -1 | sed -E 's#^/##; s#(\?|"|$)##g')"
  case "$database" in
    ""|*"<"*|*"{"*) ;;
    *)
      if [ "$database" != "$want_db" ]; then
        record ERROR DB-007 "$appsettings" "$line_no" \
          "Service '$service' must connect to database '$want_db', found '$database'."
      fi
      ;;
  esac
done < <(find "$base" -type f -path '*.Api/appsettings.json' | sort)

finish
exit $?
