#!/usr/bin/env bash
# ROUTE-001..007: route naming, controller placement and alias collision rules.
# Spec: AGENTS.md (REST API & Routing Standards), specs/06.

set -uo pipefail
CHECK_NAME="routes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/csharp.sh
source "$SCRIPT_DIR/../lib/csharp.sh"

SINGULAR_SEGMENTS=" user seller product category cart order sub-order checkout wallet auction bid notification log shipment warehouse inventory role device preference "
ALLOWED_SINGULAR=" auth me health healthcheck vnpay otp password "

tmp="$(make_tmp)"
trap 'rm -rf "$tmp"' EXIT
routes_file="$tmp/routes.txt"
: > "$routes_file"

base="$(services_base)" || exit 0

while IFS= read -r controller; do
  [ -n "$controller" ] || continue

  case "$controller" in
    */Controllers/Public/*|*/Controllers/Internal/*) ;;
    *)
      record ERROR ROUTE-003 "$controller" 1 \
        "Controllers must live in Controllers/Public/ or Controllers/Internal/."
      ;;
  esac

  route_count="$(count_class_routes "$controller")"
  route_template="$(class_route "$controller")"

  if [ "${route_count:-0}" -eq 0 ]; then
    record ERROR ROUTE-001 "$controller" 1 \
      "Controller is missing a [Route(\"api/v1/...\")] attribute."
    continue
  fi

  if [ "${route_count:-0}" -gt 1 ]; then
    record ERROR ROUTE-001 "$controller" "$(line_of "$controller" '\[Route\(')" \
      "Controller declares $route_count [Route] attributes; only one is allowed."
  fi

  if [ -z "$route_template" ]; then
    continue
  fi

  case "$route_template" in
    api/v1/*) ;;
    *)
      record ERROR ROUTE-001 "$controller" "$(line_of "$controller" '\[Route\(')" \
        "Route '$route_template' must start with api/v1/."
      ;;
  esac

  case "$route_template" in
    */)
      record ERROR ROUTE-001 "$controller" "$(line_of "$controller" '\[Route\(')" \
        "Route '$route_template' must not end with a slash."
      ;;
  esac

  case "$controller" in
    */Controllers/Internal/*)
      case "$route_template" in
        api/v1/internal/*) ;;
        *)
          record ERROR ROUTE-004 "$controller" "$(line_of "$controller" '\[Route\(')" \
            "Internal controller route '$route_template' must start with api/v1/internal/."
          ;;
      esac
      ;;
    */Controllers/Public/*)
      case "$route_template" in
        *internal*)
          record ERROR ROUTE-004 "$controller" "$(line_of "$controller" '\[Route\(')" \
            "Public controller route '$route_template' must not expose internal paths."
          ;;
      esac
      ;;
  esac

  # ROUTE-002: collection nouns must be plural.
  remainder="${route_template#api/v1/}"
  IFS='/' read -r -a segments <<< "$remainder"
  for segment in "${segments[@]}"; do
    [ -n "$segment" ] || continue
    case "$segment" in
      admin|internal) continue ;;
      *'{'*|*'}'*) continue ;;
    esac
    case "$ALLOWED_SINGULAR" in
      *" $segment "*) continue ;;
    esac
    case "$SINGULAR_SEGMENTS" in
      *" $segment "*)
        record ERROR ROUTE-002 "$controller" "$(line_of "$controller" '\[Route\(')" \
          "Singular resource segment '$segment' is prohibited; use the plural form."
        ;;
    esac
  done

  # ROUTE-005: exactly one HTTP verb attribute per action.
  while IFS=$'\t' read -r line count; do
    [ -n "$count" ] || continue
    record ERROR ROUTE-005 "$controller" "$line" \
      "Action declares $count HTTP verb attributes; an action must expose one route."
  done < <(duplicate_http_attributes "$controller")

  # Collect full paths for duplicate detection.
  while IFS=$'\t' read -r line verb template; do
    [ -n "$verb" ] || continue
    full="$(join_route "$route_template" "$template")"
    printf '%s\t%s\t%s:%s\n' "$verb" "$full" "$controller" "$line" >> "$routes_file"
  done < <(http_attributes "$controller")

  # ROUTE-007: resource-ownership guard heuristic for parameterised public routes.
  case "$controller" in
    */Controllers/Public/*)
      if [[ "$route_template" =~ \{[A-Za-z0-9_]*[Ii]d ]] \
        && ! grep -qE 'GetUserId\(|HasRole\(|RequireRole' "$controller"; then
        record WARN ROUTE-007 "$controller" 1 \
          "Parameterised public route should verify resource ownership via GetUserId() or a role check."
      fi
      ;;
  esac
done < <(find "$base" -type f -name '*Controller.cs' -path '*/Controllers/*' | sort)

# ROUTE-006: duplicate verb + path pairs across the service.
if [ -s "$routes_file" ]; then
  while IFS=$'\t' read -r verb path; do
    [ -n "$verb" ] || continue
    location="$(awk -F'\t' -v v="$verb" -v p="$path" '$1 == v && $2 == p { print $3; exit }' "$routes_file")"
    record ERROR ROUTE-006 "${location%:*}" "${location##*:}" \
      "Duplicate route $verb /$path."
  done < <(cut -f1,2 "$routes_file" | sort | uniq -d)
fi

finish
exit $?
