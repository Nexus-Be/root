#!/usr/bin/env bash
# ARCH-001..009: clean architecture, feature co-location and banned technology rules.
# Spec: AGENTS.md (Unified Microservice Architecture Standards), specs/01, specs/06.

set -uo pipefail
CHECK_NAME="architecture"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

base="$(services_base)" || exit 0

# ARCH-001: the Domain layer must stay dependency free.
while IFS= read -r domain_proj; do
  [ -n "$domain_proj" ] || continue
  first_ref="$(grep -nE '<PackageReference' "$domain_proj" 2>/dev/null | head -1 || true)"
  if [ -n "$first_ref" ]; then
    record ERROR ARCH-001 "$domain_proj" "${first_ref%%:*}" \
      "Domain projects must not reference any NuGet package."
  fi
done < <(find "$base" -type f -name '*.Domain.csproj' | sort)

# ARCH-002: repository pattern and unit of work are prohibited over EF Core.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR ARCH-002 "$HIT_FILE" "$HIT_LINE" \
    "Repository/UnitOfWork abstractions are prohibited; inject I{Service}DbContext directly."
done < <(grep_cs_code 'IRepository<|GenericRepository|UnitOfWork')

# ARCH-003: MediatR/CQRS is frozen to WalletService only.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  is_wallet_path "$HIT_FILE" && continue
  record ERROR ARCH-003 "$HIT_FILE" "$HIT_LINE" \
    "MediatR/CQRS is only allowed in WalletService."
done < <(grep_cs_code '(^|[^A-Za-z])using[[:space:]]+MediatR|IRequestHandler<|ISender[[:space:]]+[A-Za-z_]')

while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"
  rest="${hit#*:}"
  line="${rest%%:*}"
  is_wallet_path "$file" && continue
  record ERROR ARCH-003 "$file" "$line" \
    "MediatR is only allowed in WalletService."
done < <(find "$base" -type f -name '*.csproj' -print0 2>/dev/null \
  | xargs -0 grep -nE 'Include="MediatR' 2>/dev/null | grep -v '/Wallet/' || true)

# ARCH-004: no gRPC, no message brokers, no saga/outbox infrastructure.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  record ERROR ARCH-004 "$HIT_FILE" "$HIT_LINE" \
    "gRPC and message brokers are decommissioned; use typed REST clients."
done < <(grep_cs_code '(^|[^A-Za-z])using[[:space:]]+Grpc|MassTransit|RabbitMQ|IOutbox|OutboxMessage|InboxMessage|SagaState')

while IFS= read -r proto; do
  [ -n "$proto" ] || continue
  record ERROR ARCH-004 "$proto" 1 \
    "Protocol Buffers are prohibited; use RESTful JSON contracts."
done < <(find "$base" \( -type d \( -name bin -o -name obj \) -prune \) -o -type f -name '*.proto' -print 2>/dev/null)

# ARCH-005: API controllers must never touch a DbContext.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  split_hit "$hit"
  case "$HIT_FILE" in
    */Controllers/*) ;;
    *) continue ;;
  esac
  record ERROR ARCH-005 "$HIT_FILE" "$HIT_LINE" \
    "Controllers must not reference a DbContext; delegate to the feature service."
done < <(grep_cs_code 'DbContext')

# ARCH-006: each controller injects its own feature service only.
# WalletService is the frozen MediatR exception and legitimately injects ISender.
while IFS= read -r controller; do
  [ -n "$controller" ] || continue
  is_wallet_path "$controller" && continue
  if ! grep -qE '\bI[A-Z][A-Za-z0-9]*(Service|Manager)\b' "$controller"; then
    record ERROR ARCH-006 "$controller" 1 \
      "Controller must inject an I{Feature}Service abstraction."
  fi
done < <(find "$base" -type f -name '*Controller.cs' -path '*/Controllers/*' | sort)

# ARCH-007: ProjectReference must never leave the owning service.
while IFS= read -r proj; do
  [ -n "$proj" ] || continue
  svc_dir="$ROOT/src/Services/$(service_name "$proj")"

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    line_no="${entry%%:*}"
    include="$(printf '%s' "${entry#*:}" | sed -E 's/.*Include="([^"]+)".*/\1/')"

    target_dir="$(cd "$(dirname "$proj")" && cd "$(dirname "$include")" 2>/dev/null && pwd -P)"
    if [ -z "$target_dir" ]; then
      record ERROR ARCH-007 "$proj" "$line_no" \
        "ProjectReference '$include' does not resolve to an existing directory."
    elif [ "${target_dir#"$svc_dir"/}" = "$target_dir" ]; then
      record ERROR ARCH-007 "$proj" "$line_no" \
        "Cross-service ProjectReference '$include' breaks service self-containment."
    fi
  done < <(grep -nE '<ProjectReference' "$proj" 2>/dev/null || true)
done < <(find "$base" -type f -name '*.csproj' | sort)

# ARCH-008: Application/Services/{Feature} co-location file set.
while IFS= read -r feature_dir; do
  [ -n "$feature_dir" ] || continue
  feature="$(basename "$feature_dir")"

  contract=""
  implementation=""

  while IFS= read -r candidate; do
    base_name="$(basename "$candidate")"
    case "$base_name" in
      I[A-Z]*)
        [ -n "$contract" ] || contract="$candidate"
        ;;
      *)
        [ -n "$implementation" ] || implementation="$candidate"
        ;;
    esac
  done < <(find "$feature_dir" -maxdepth 1 -name '*Service.cs' | sort)

  if [ -z "$contract" ]; then
    record WARN ARCH-008 "$feature_dir" 1 \
      "Feature '$feature' is missing its I{Feature}Service contract."
  fi

  if [ -z "$implementation" ]; then
    record WARN ARCH-008 "$feature_dir" 1 \
      "Feature '$feature' is missing its service implementation."
  fi

  requests="$(find "$feature_dir" -maxdepth 1 -name '*Requests.cs' -print -quit)"
  if [ -z "$requests" ]; then
    record WARN ARCH-008 "$feature_dir" 1 \
      "Feature '$feature' is missing its request records."
  fi

  responses="$(find "$feature_dir" -maxdepth 1 -name '*Responses.cs' -print -quit)"
  if [ -z "$responses" ]; then
    record WARN ARCH-008 "$feature_dir" 1 \
      "Feature '$feature' is missing its response records."
  fi
done < <(find "$base" -type d -path '*.Application/Services/*' -not -path '*.Application/Services/*/*' 2>/dev/null | sort)

# ARCH-009: delegate the frozen Wallet CQRS contract to its own verifier.
wallet_verifier="$ROOT/src/Services/Wallet/scripts/verify-wallet-architecture.sh"
if [ -f "$wallet_verifier" ]; then
  if ! bash "$wallet_verifier" >/dev/null 2>&1; then
    record ERROR ARCH-009 "$wallet_verifier" 1 \
      "Wallet architecture verifier failed; run it directly for details."
  fi
fi

finish
exit $?
