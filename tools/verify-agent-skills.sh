#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES=(
  "User"
  "Catalog"
  "Commerce"
  "Log"
  "Auction"
  "Fulfillment"
  "Notification"
  "Wallet"
  "Gateway"
  "CheckHeal"
)

pass=0
fail=0

ok() {
  pass=$((pass + 1))
  printf 'PASS  %s\n' "$1"
}

bad() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
}

check_file() {
  local file="$1"
  local label="$2"
  if [ -f "$file" ]; then
    ok "$label exists"
  else
    bad "$label missing: $file"
    return 1
  fi
}

check_frontmatter() {
  local file="$1"
  local label="$2"
  if ! head -5 "$file" | grep -q '^name: new-feature-endpoint$'; then
    bad "$label frontmatter name"
  elif ! head -10 "$file" | grep -q '^description: '; then
    bad "$label frontmatter description"
  else
    ok "$label frontmatter"
  fi
}

check_no_outward_refs() {
  local file="$1"
  local label="$2"
  if grep -nE 'Nexus-Be/|docs/api|src/Services/|\.\./\.\./|tools/|root skill|root workspace' "$file" >/dev/null 2>&1; then
    bad "$label contains an outward path reference"
    grep -nE 'Nexus-Be/|docs/api|src/Services/|\.\./\.\./|tools/|root skill|root workspace' "$file" | head -3
  else
    ok "$label has no outward path reference"
  fi
}

check_phase_markers() {
  local file="$1"
  local label="$2"
  local last="$3"
  local missing=""
  local i
  for i in $(seq 0 "$last"); do
    if ! grep -qE "^### ${i}\." "$file"; then
      missing="$missing $i"
    fi
  done
  if [ -n "$missing" ]; then
    bad "$label missing phase markers:$missing"
  else
    ok "$label has phase markers 0-$last"
  fi
}

ROOT_SKILL="$ROOT_DIR/.agents/skills/new-feature-endpoint/SKILL.md"
if check_file "$ROOT_SKILL" "root skill"; then
  check_frontmatter "$ROOT_SKILL" "root skill"
  missing=""
  for i in 0 1 2 3 4 5 6 7 8 9; do
    if ! grep -q "Phase ${i}" "$ROOT_SKILL"; then
      missing="$missing $i"
    fi
  done
  if [ -n "$missing" ]; then
    bad "root skill missing phases:$missing"
  else
    ok "root skill has phases 0-9"
  fi
  if grep -q '^## 17. Definition of Done' "$ROOT_SKILL"; then
    ok "root skill has Definition of Done"
  else
    bad "root skill missing Definition of Done"
  fi
fi

for service in "${SERVICES[@]}"; do
  OVERLAY="$ROOT_DIR/src/Services/$service/.agents/skills/new-feature-endpoint/SKILL.md"
  if ! check_file "$OVERLAY" "$service overlay"; then
    continue
  fi
  check_frontmatter "$OVERLAY" "$service overlay"
  check_no_outward_refs "$OVERLAY" "$service overlay"

  if [ "$service" = "Gateway" ]; then
    check_phase_markers "$OVERLAY" "$service overlay" 6
  else
    check_phase_markers "$OVERLAY" "$service overlay" 7
  fi

  if grep -q '^## Done when' "$OVERLAY"; then
    ok "$service overlay has Done when"
  else
    bad "$service overlay missing Done when"
  fi
done

if grep -nE 'BEGIN (RSA|OPENSSH) PRIVATE KEY|"Signature"[[:space:]]*:' \
  "$ROOT_DIR/.agents/skills/new-feature-endpoint" \
  "$ROOT_DIR"/src/Services/*/.agents/skills/new-feature-endpoint 2>/dev/null | grep -q .; then
  bad "skill files contain a secret pattern"
else
  ok "skill files contain no secret pattern"
fi

if command -v git >/dev/null 2>&1; then
  if git -C "$ROOT_DIR" check-ignore -q ".agents/skills/new-feature-endpoint/SKILL.md"; then
    bad "root skill is ignored by git"
  else
    ok "root skill is trackable by git"
  fi

  if git -C "$ROOT_DIR" check-ignore -q ".agents/history" 2>/dev/null; then
    ok "root history stays ignored"
  else
    bad "root history is not ignored"
  fi

  if git -C "$ROOT_DIR/src/Services/User" check-ignore -q ".agents/skills/new-feature-endpoint/SKILL.md"; then
    bad "User skill is ignored by git"
  else
    ok "User skill is trackable by git"
  fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
