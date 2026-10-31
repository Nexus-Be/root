#!/usr/bin/env bash
# ENUM-001..008: enum serialization boundary and enum declaration rules.
# Spec: AGENTS.md (Enum Serialization Boundary Rule), specs/06 (invariants).

set -uo pipefail
CHECK_NAME="enum"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/csharp.sh
source "$SCRIPT_DIR/../lib/csharp.sh"

# ENUM-001: every API project must register the PascalCase converter, and the
# Minimal API JSON options must be covered whenever they are configured.
while IFS= read -r api; do
  [ -n "$api" ] || continue

  registrations="$(grep -rE 'new PascalCaseJsonStringEnumConverter\(' "$api" --include='*.cs' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${registrations:-0}" -lt 1 ]; then
    anchor="$(grep -rE -l 'AddControllers|ConfigureHttpJsonOptions' "$api" --include='*.cs' 2>/dev/null | head -1 || true)"
    [ -n "$anchor" ] || anchor="$api"
    line="$(line_of "$anchor" 'AddControllers|ConfigureHttpJsonOptions')"
    [ "$line" = "0" ] && line=1
    record ERROR ENUM-001 "$anchor" "$line" \
      "PascalCaseJsonStringEnumConverter is not registered in the JSON pipeline."
  fi

  minimal_api_files="$(grep -rE -l 'ConfigureHttpJsonOptions' "$api" --include='*.cs' 2>/dev/null || true)"
  if [ -n "$minimal_api_files" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if ! grep -q 'PascalCaseJsonStringEnumConverter' "$file"; then
        record ERROR ENUM-001 "$file" "$(line_of "$file" 'ConfigureHttpJsonOptions')" \
          "Minimal API JSON options must register PascalCaseJsonStringEnumConverter."
      fi
    done <<< "$minimal_api_files"
  fi

  if grep -rqE 'allowIntegerValues:[[:space:]]*true' "$api" --include='*.cs' 2>/dev/null; then
    anchor="$(grep -rlE 'allowIntegerValues:[[:space:]]*true' "$api" --include='*.cs' 2>/dev/null | head -1)"
    record ERROR ENUM-001 "$anchor" "$(line_of "$anchor" 'allowIntegerValues: true')" \
      "Integer enum values must stay disabled at the JSON boundary."
  fi
done < <(api_dirs)

# ENUM-002: the built-in converter emits camelCase names and accepts integers.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  case "$HIT_TEXT" in
    *PascalCaseJsonStringEnumConverter*) continue ;;
  esac
  record ERROR ENUM-002 "$HIT_FILE" "$HIT_LINE" \
    "JsonStringEnumConverter is prohibited. Use PascalCaseJsonStringEnumConverter."
done < <(grep_cs 'JsonStringEnumConverter')

# ENUM-003: enums must be persisted as integers, never as strings.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR ENUM-003 "$HIT_FILE" "$HIT_LINE" \
    "HasConversion<string> is prohibited. Persist enums as int32."
done < <(grep_cs 'HasConversion<[[:space:]]*string')

# ENUM-004..006: declaration shape of every enum.
while IFS= read -r file; do
  [ -n "$file" ] || continue
  grep -qE '(^|[[:space:]])enum[[:space:]]' "$file" 2>/dev/null || continue

  declare -A value_owner=()

  while IFS=$'\t' read -r line enum_name member explicit value; do
    [ -n "$member" ] || continue

    if ! [[ "$member" =~ ^[A-Z][A-Za-z0-9]*$ ]] || [[ "$member" =~ ^[A-Z0-9]+$ && ${#member} -gt 1 ]]; then
      record ERROR ENUM-004 "$file" "$line" \
        "Enum member '$member' must use PascalCase (no underscores, no all caps)."
    fi

    if [ "$explicit" = "0" ]; then
      record WARN ENUM-006 "$file" "$line" \
        "Enum member '$member' must declare an explicit integer value."
    fi

    key="$enum_name:$value"
    if [ -n "${value_owner[$key]:-}" ]; then
      record ERROR ENUM-005 "$file" "$line" \
        "Enum '$enum_name' reuses value $value (already assigned to '${value_owner[$key]}')."
    else
      value_owner[$key]="$member"
    fi
  done < <(enum_members "$file")

  unset value_owner
done < <(find_cs)

# ENUM-007: response DTOs must expose enums, not raw integers.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  case "$HIT_FILE" in
    *Responses.cs|*Dtos.cs) ;;
    *) continue ;;
  esac
  record WARN ENUM-007 "$HIT_FILE" "$HIT_LINE" \
    "Status/Type/State/Role response fields must be an enum, not int."
done < <(grep_cs 'public[[:space:]]+int\??[[:space:]]+[A-Za-z0-9_]*(Status|Type|State|Role)[[:space:]]*\{')

# ENUM-008: stringifying an enum with ToUpper is the classic casing leak.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record WARN ENUM-008 "$HIT_FILE" "$HIT_LINE" \
    "Do not uppercase enum names. Serialize with PascalCaseJsonStringEnumConverter instead."
done < <(grep_cs '\.ToString\(\)\.ToUpper')

finish
exit $?
