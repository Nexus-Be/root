#!/usr/bin/env bash
# ERRS-001..007: error message language and casing rules.
# Spec: AGENTS.md (Error Handling & Message Standards) - English, sentence case.

set -uo pipefail
CHECK_NAME="error-messages"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/csharp.sh
source "$SCRIPT_DIR/../lib/csharp.sh"

AWK_EXTRACT="$SCRIPT_DIR/../lib/exception_literals.awk"

ACRONYMS=" ID OTP JWT URL UUID Email API HTTP VNPay IP SMTP TTL GUID "

is_title_case() {
  local msg="$1"
  local -a words
  local n i token prefix first caps
  local allowed=0

  read -r -a words <<< "$msg"
  n="${#words[@]}"
  [ "$n" -ge 3 ] || return 1

  caps=0
  for ((i = 1; i < n; i++)); do
    token="${words[i]}"
    prefix="${token%%[A-Za-z]*}"
    token="${token:${#prefix}}"
    [ -n "$token" ] || continue

    first="${token:0:1}"
    if [[ "$first" =~ [A-Z] ]]; then
      case "$ACRONYMS" in
        *" $token "*) continue ;;
      esac
      caps=$((caps + 1))
    fi
  done

  allowed=$((n - 1))
  if [ "$caps" -ge 2 ] && [ "$caps" -eq "$allowed" ]; then
    return 0
  fi
  return 1
}

check_message() {
  local file="$1"
  local line="$2"
  local msg="$3"
  local first_letter

  [ -n "$msg" ] || return 0

  # Single tokens are identifiers, not sentences.
  case "$msg" in
    *" "*) ;;
    *) return 0 ;;
  esac

  # Structured payloads such as "{orderId}|{amount}" are not user-facing prose.
  case "$msg" in
    *'{'*'}'*) return 0 ;;
  esac

  if printf '%s' "$msg" | LC_ALL=C grep -q '[^ -~]'; then
    record ERROR ERRS-001 "$file" "$line" \
      "Message contains non-ASCII characters; error messages must be English: '$msg'."
    return 0
  fi

  first_letter="$(printf '%s' "$msg" | sed -E 's/^[^A-Za-z]*//' | cut -c1)"

  if [ -n "$first_letter" ] && [[ "$first_letter" =~ [a-z] ]]; then
    record ERROR ERRS-002 "$file" "$line" \
      "Message must start with an uppercase letter: '$msg'."
  fi

  if printf '%s' "$msg" | grep -qE '[[:alpha:]]' && ! printf '%s' "$msg" | grep -qE '[[:lower:]]'; then
    record ERROR ERRS-003 "$file" "$line" \
      "Message must not be written in all caps: '$msg'."
  fi

  if is_title_case "$msg"; then
    record ERROR ERRS-004 "$file" "$line" \
      "Message must use sentence case, not title case: '$msg'."
  fi

  case "$msg" in
    " "*|*" "|*"  "*)
      record ERROR ERRS-005 "$file" "$line" \
        "Message must not contain leading, trailing, or repeated spaces."
      ;;
  esac

  case "$msg" in
    *.|*?|*!) ;;
    *)
      record WARN ERRS-006 "$file" "$line" \
        "Message should end with a period: '$msg'."
      ;;
  esac

  if [ "${#msg}" -lt 5 ]; then
    record WARN ERRS-007 "$file" "$line" \
      "Message is too short to be meaningful: '$msg'."
  fi
}

# Messages passed to exception constructors (all exception types).
while IFS=$'\t' read -r file line type code message; do
  [ -n "$file" ] || continue
  check_message "$file" "$line" "$message"
done < <(
  base="$(services_base)" || exit 0
  find "$base" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print0 2>/dev/null \
    | xargs -0 awk -f "$AWK_EXTRACT" 2>/dev/null
)

# Literal message assignments in middlewares, guards and problem factories.
while IFS= read -r file; do
  [ -n "$file" ] || continue
  while IFS=$'\t' read -r line message; do
    [ -n "$message" ] || continue
    check_message "$file" "$line" "$message"
  done < <(message_candidates "$file")
done < <(find_cs)

finish
exit $?
