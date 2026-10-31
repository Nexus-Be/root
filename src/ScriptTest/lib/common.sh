#!/usr/bin/env bash
# Shared helpers for ScriptTest rule checkers.
# This file is sourced by every checks/*.sh script and must stay side-effect free.

SCRIPTTEST_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v git >/dev/null 2>&1 && git -C "$SCRIPTTEST_HOME" rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git -C "$SCRIPTTEST_HOME" rev-parse --show-toplevel)"
else
  ROOT="$(cd "$SCRIPTTEST_HOME/../.." && pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"

CHECK_NAME="${CHECK_NAME:-check}"
ERRORS=0
WARNINGS=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[0;33m'
  C_DIM=$'\033[2m'
else
  C_RESET=''
  C_BOLD=''
  C_RED=''
  C_YELLOW=''
  C_DIM=''
fi

# record <ERROR|WARN> <RULE-ID> <file> <line> <message...>
record() {
  local severity="$1"
  local rule="$2"
  local file="$3"
  local line="$4"
  shift 4
  local message="$*"
  local rel="${file#"$ROOT"/}"
  local color="$C_YELLOW"

  message="${message//$'\t'/ }"

  if [ "$severity" = "ERROR" ]; then
    ERRORS=$((ERRORS + 1))
    color="$C_RED"
  else
    WARNINGS=$((WARNINGS + 1))
  fi

  if [ -z "${CHECK_QUIET:-}" ]; then
    printf '%s%-5s%s %s:%s %s[%s]%s %s\n' \
      "$color" "$severity" "$C_RESET" "$rel" "$line" "$C_BOLD" "$rule" "$C_RESET" "$message"
  fi

  if [ -n "${SCRIPTTEST_FINGERPRINTS:-}" ]; then
    local digest
    digest="$(printf '%s' "$message" | cksum | awk '{print $1}')"
    printf '%s\t%s\t%s\t%s\n' "$severity" "$rule" "$rel" "$digest" >> "$SCRIPTTEST_FINGERPRINTS"
  fi

  if [ -n "${SCRIPTTEST_DETAILS:-}" ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$severity" "$rule" "$rel" "$line" "$message" >> "$SCRIPTTEST_DETAILS"
  fi
}

finish() {
  printf '%s%s%s: %d error(s), %d warning(s)\n' \
    "$C_BOLD" "$CHECK_NAME" "$C_RESET" "$ERRORS" "$WARNINGS"
  if [ "$ERRORS" -gt 0 ]; then
    return 1
  fi
  return 0
}

# Root path that every check must scan. Honours --service to scope a single service.
services_base() {
  if [ -n "${SCRIPTTEST_SERVICE:-}" ]; then
    local scoped="$ROOT/src/Services/$SCRIPTTEST_SERVICE"
    if [ -d "$scoped" ]; then
      printf '%s\n' "$scoped"
      return 0
    fi
    return 1
  fi
  printf '%s\n' "$ROOT/src/Services"
  return 0
}

# find_cs [extra find args...] - all C# sources, skipping build output.
find_cs() {
  local base
  base="$(services_base)" || return 0
  find "$base" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules -o -name .agents \) -prune \) \
    -o -type f -name '*.cs' -print "$@"
}

# find_cs_under <dir> [extra find args...] - C# sources inside one directory.
find_cs_under() {
  local dir="$1"
  shift
  [ -d "$dir" ] || return 0
  find "$dir" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print "$@"
}

# grep_cs <grep -E pattern> - grep all C# sources, prints path:line:content.
grep_cs() {
  local base
  base="$(services_base)" || return 0
  find "$base" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print0 2>/dev/null \
    | xargs -0 grep -nE "$@" 2>/dev/null || true
}

# grep_cs_under <dir> <grep -E pattern> - same, scoped to one directory.
grep_cs_under() {
  local dir="$1"
  shift
  [ -d "$dir" ] || return 0
  find "$dir" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print0 2>/dev/null \
    | xargs -0 grep -nE "$@" 2>/dev/null || true
}

# grep_cs_code <grep -E pattern> - grep C# code with comments and literals stripped.
# Prints path:line:content with accurate line numbers.
grep_cs_code() {
  local base
  base="$(services_base)" || return 0
  find "$base" \
    \( -type d \( -name bin -o -name obj -o -name .git -o -name node_modules \) -prune \) \
    -o -type f -name '*.cs' -print0 2>/dev/null \
    | xargs -0 awk -v pfx=1 -f "$SCRIPTTEST_HOME/lib/strip_literals.awk" 2>/dev/null \
    | grep -E "$@" || true
}

# split_hit <path:line:content> - sets HIT_FILE, HIT_LINE, HIT_TEXT.
split_hit() {
  HIT_FILE="${1%%:*}"
  local rest="${1#*:}"
  HIT_LINE="${rest%%:*}"
  HIT_TEXT="${rest#*:}"
}

# api_dirs - every {Service}.Api project directory.
api_dirs() {
  local base
  base="$(services_base)" || return 0
  find "$base" -mindepth 1 -maxdepth 2 -type d -name '*.Api' 2>/dev/null | sort
}

# service_name <path> - top-level service name under src/Services.
service_name() {
  local path="${1#"$ROOT"/}"
  local rest="${path#src/Services/}"
  printf '%s\n' "${rest%%/*}"
}

# is_wallet_path <path>
is_wallet_path() {
  case "$1" in
    */src/Services/Wallet/*) return 0 ;;
  esac
  return 1
}

# line_of <file> <pattern> - first matching line number, 0 when absent.
line_of() {
  local file="$1"
  local pattern="$2"
  local hit
  hit="$(grep -nE -- "$pattern" "$file" 2>/dev/null | head -1 || true)"
  if [ -z "$hit" ]; then
    printf '0\n'
  else
    printf '%s\n' "${hit%%:*}"
  fi
}

# make_tmp - create a scratch directory. Callers must register their own EXIT trap.
make_tmp() {
  mktemp -d "${TMPDIR:-/tmp}/scripttest.XXXXXX"
}

# json_escape <string>
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
