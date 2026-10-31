#!/usr/bin/env bash
# ScriptTest runner: executes every rule checker and enforces the baseline ratchet.
#
# Exit codes:
#   0  no new violations
#   1  new violations detected (or new warnings with --strict)
#   2  invalid invocation or configuration

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE="$DIR/baseline/violations.txt"

if command -v git >/dev/null 2>&1 && git -C "$DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git -C "$DIR" rev-parse --show-toplevel)"
else
  ROOT="$(cd "$DIR/../.." && pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"

STRICT=0
JSON=0
CI=0
UPDATE=0
SERVICE=""

usage() {
  cat <<'EOF'
Usage: run-all.sh [options]

Options:
  --strict            Treat new warnings as failures too.
  --json              Print a machine-readable summary at the end.
  --ci                Print GitHub Actions annotations for new violations.
  --update-baseline   Replace the baseline with the current violations and exit 0.
  --service <Name>    Only scan src/Services/<Name>.
  -h, --help          Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --json) JSON=1 ;;
    --ci) CI=1 ;;
    --update-baseline) UPDATE=1 ;;
    --service)
      shift
      SERVICE="${1:-}"
      ;;
    --service=*) SERVICE="${1#*=}" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ -n "$SERVICE" ] && [ ! -d "$ROOT/src/Services/$SERVICE" ]; then
  printf 'Unknown service: %s\n' "$SERVICE" >&2
  exit 2
fi

mkdir -p "$(dirname "$BASELINE")"
[ -f "$BASELINE" ] || : > "$BASELINE"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/scripttest.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fingerprints="$tmp/fingerprints.txt"
details="$tmp/details.txt"
: > "$fingerprints"
: > "$details"

export SCRIPTTEST_FINGERPRINTS="$fingerprints"
export SCRIPTTEST_DETAILS="$details"
export SCRIPTTEST_SERVICE="$SERVICE"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[0;33m'
  C_GREEN=$'\033[0;32m'
  C_DIM=$'\033[2m'
else
  C_RESET=''
  C_BOLD=''
  C_RED=''
  C_YELLOW=''
  C_GREEN=''
  C_DIM=''
fi

for check in "$DIR"/checks/*.sh; do
  [ -f "$check" ] || continue
  bash "$check"
done

sort -u "$fingerprints" > "$tmp/current.txt"
sort -u "$BASELINE" > "$tmp/baseline.txt"
comm -13 "$tmp/baseline.txt" "$tmp/current.txt" > "$tmp/new.txt"

total_errors="$(awk -F'\t' '$1 == "ERROR"' "$tmp/current.txt" | wc -l | tr -d ' ')"
total_warnings="$(awk -F'\t' '$1 == "WARN"' "$tmp/current.txt" | wc -l | tr -d ' ')"
new_errors="$(awk -F'\t' '$1 == "ERROR"' "$tmp/new.txt" | wc -l | tr -d ' ')"
new_warnings="$(awk -F'\t' '$1 == "WARN"' "$tmp/new.txt" | wc -l | tr -d ' ')"

if [ "$UPDATE" -eq 1 ]; then
  cp "$tmp/current.txt" "$BASELINE"
  printf '%sBaseline updated%s: %s error(s), %s warning(s) recorded in %s\n' \
    "$C_GREEN" "$C_RESET" "$total_errors" "$total_warnings" "${BASELINE#"$ROOT"/}"
  exit 0
fi

printf '\n%sSummary%s: %s error(s), %s warning(s); %s new error(s), %s new warning(s).\n' \
  "$C_BOLD" "$C_RESET" "$total_errors" "$total_warnings" "$new_errors" "$new_warnings"

if [ -s "$tmp/new.txt" ]; then
  printf '\n%sNew violations (not in baseline)%s\n' "$C_BOLD" "$C_RESET"

  while IFS=$'\t' read -r severity rule rel digest; do
    [ -n "$severity" ] || continue

    detail="$(awk -F'\t' -v s="$severity" -v r="$rule" -v p="$rel" \
      '$1 == s && $2 == r && $3 == p { print; exit }' "$details")"
    line="$(printf '%s' "$detail" | cut -f4)"
    message="$(printf '%s' "$detail" | cut -f5-)"
    [ -n "$line" ] || line=1

    color="$C_YELLOW"
    [ "$severity" = "ERROR" ] && color="$C_RED"

    printf '%s%-5s%s %s:%s %s[%s]%s %s\n' \
      "$color" "$severity" "$C_RESET" "$rel" "$line" "$C_BOLD" "$rule" "$C_RESET" "$message"

    if [ "$CI" -eq 1 ]; then
      annotation="error"
      [ "$severity" = "ERROR" ] || annotation="warning"
      printf '::%s file=%s,line=%s::[%s] %s\n' "$annotation" "$rel" "$line" "$rule" "$message"
    fi
  done < <(sort "$tmp/new.txt")
fi

if [ -z "$SERVICE" ] && [ -s "$tmp/baseline.txt" ]; then
  resolved="$(comm -23 "$tmp/baseline.txt" "$tmp/current.txt" | wc -l | tr -d ' ')"
  if [ "$resolved" -gt 0 ]; then
    printf '%s%s baseline entr(y/ies) no longer reproduce; run --update-baseline to lock the win.%s\n' \
      "$C_DIM" "$resolved" "$C_RESET"
  fi
fi

status=0
if [ "$new_errors" -gt 0 ]; then
  status=1
fi
if [ "$STRICT" -eq 1 ] && [ "$new_warnings" -gt 0 ]; then
  status=1
fi

if [ "$JSON" -eq 1 ]; then
  json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
  }

  printf '{"errors":%s,"warnings":%s,"newErrors":%s,"newWarnings":%s,"newViolations":[' \
    "$total_errors" "$total_warnings" "$new_errors" "$new_warnings"

  separator=""
  if [ -s "$tmp/new.txt" ]; then
    while IFS=$'\t' read -r severity rule rel digest; do
      [ -n "$severity" ] || continue
      detail="$(awk -F'\t' -v s="$severity" -v r="$rule" -v p="$rel" \
        '$1 == s && $2 == r && $3 == p { print; exit }' "$details")"
      line="$(printf '%s' "$detail" | cut -f4)"
      message="$(printf '%s' "$detail" | cut -f5-)"
      [ -n "$line" ] || line=1

      printf '%s{"severity":"%s","rule":"%s","path":"%s","line":%s,"message":"%s"}' \
        "$separator" "$severity" "$rule" "$(json_escape "$rel")" "$line" "$(json_escape "$message")"
      separator=","
    done < <(sort "$tmp/new.txt")
  fi

  printf ']}\n'
fi

if [ "$status" -eq 0 ]; then
  printf '%sOK%s: no new rule violations.\n' "$C_GREEN" "$C_RESET"
fi

exit "$status"
