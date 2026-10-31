#!/usr/bin/env bash
# ERRC-001..006: error code format (SCREAMING_SNAKE_CASE) and handler coverage.
# Spec: AGENTS.md (Error Handling & Message Standards).

set -uo pipefail
CHECK_NAME="error-codes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

AWK_EXTRACT="$SCRIPT_DIR/../lib/exception_literals.awk"

is_domain_exception() {
  case "$1" in
    DomainException|EntityNotFoundException|BusinessRuleValidationException|RequestValidationException)
      return 0
      ;;
  esac
  return 1
}

is_valid_code() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$ ]]
}

declare -A code_message=()

# ERRC-001..004 from exception constructor literals.
while IFS=$'\t' read -r file line type code message; do
  [ -n "$file" ] || continue
  is_domain_exception "$type" || continue
  [ -n "$code" ] || continue

  if ! is_valid_code "$code"; then
    record ERROR ERRC-001 "$file" "$line" \
      "errorCode '$code' must be SCREAMING_SNAKE_CASE."
  fi

  case "$code" in
    ERR_*)
      record ERROR ERRC-002 "$file" "$line" \
        "errorCode '$code' must not use the ERR_ prefix."
      ;;
  esac

  case "$code" in
    VAL_*)
      case "$type" in
        DomainException|EntityNotFoundException)
          record WARN ERRC-004 "$file" "$line" \
            "errorCode '$code' is a validation code but is thrown as $type."
          ;;
      esac
      ;;
  esac

  if [ -n "$message" ]; then
    case "$code" in
      VAL_*) ;;
      *)
        previous="${code_message[$code]:-}"
        if [ -n "$previous" ] && [ "$previous" != "$message" ]; then
          record ERROR ERRC-003 "$file" "$line" \
            "errorCode '$code' is reused with a different message ('$message' vs '$previous')."
        elif [ -z "$previous" ]; then
          code_message[$code]="$message"
        fi
        ;;
    esac
  fi
done < <(
  base="$(services_base)" || exit 0
  find "$base" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print0 2>/dev/null \
    | xargs -0 awk -f "$AWK_EXTRACT" 2>/dev/null
)

# ERRC-001..003 for object-initializer error codes (Gateway responses, guards).
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  code="$(printf '%s' "$HIT_TEXT" | sed -nE 's/.*[Ee]rrorCode[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p')"
  [ -n "$code" ] || continue

  if ! is_valid_code "$code"; then
    record ERROR ERRC-001 "$HIT_FILE" "$HIT_LINE" \
      "errorCode '$code' must be SCREAMING_SNAKE_CASE."
  fi

  case "$code" in
    ERR_*)
      record ERROR ERRC-002 "$HIT_FILE" "$HIT_LINE" \
        "errorCode '$code' must not use the ERR_ prefix."
      ;;
  esac
done < <(grep_cs '\b[Ee]rrorCode[[:space:]]*=[[:space:]]*"[^"]+"')

# ERRC-005: codes must be static literals so the error matrix stays auditable.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record WARN ERRC-005 "$HIT_FILE" "$HIT_LINE" \
    "errorCode must be a static literal; dynamic composition cannot be documented."
done < <(grep_cs '\b[Ee]rrorCode[[:space:]]*=[[:space:]]*(\$"|[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\+)')

# ERRC-006: every API project must map unhandled and argument failures.
while IFS= read -r api; do
  [ -n "$api" ] || continue
  handler="$api/Middleware/GlobalExceptionHandlerMiddleware.cs"

  if [ ! -f "$handler" ]; then
    record ERROR ERRC-006 "$api" 1 \
      "GlobalExceptionHandlerMiddleware.cs is missing."
    continue
  fi

  if ! grep -q 'VAL_INVALID_ARGUMENT' "$handler"; then
    line="$(line_of "$handler" 'ArgumentException')"
    [ "$line" = "0" ] && line=1
    record ERROR ERRC-006 "$handler" "$line" \
      "Argument failures must map to VAL_INVALID_ARGUMENT."
  fi

  if ! grep -q 'INTERNAL_SERVER_ERROR' "$handler"; then
    record ERROR ERRC-006 "$handler" 1 \
      "Unhandled failures must map to INTERNAL_SERVER_ERROR."
  fi
done < <(api_dirs)

finish
exit $?
