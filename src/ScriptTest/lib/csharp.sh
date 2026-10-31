#!/usr/bin/env bash
# C# source helpers: comment/literal stripping and controller route extraction.
# All functions read from files and never modify them.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# strip_comments - stdin to stdout, removes // and /* */ comments, keeps line count.
strip_comments() {
  awk -v pfx=0 -f "$LIB_DIR/strip_comments.awk"
}

# strip_literals - stdin to stdout, removes comments and blanks string/char contents.
strip_literals() {
  awk -v pfx=0 -f "$LIB_DIR/strip_literals.awk"
}

# class_route <file> - first [Route("...")] template on the controller.
class_route() {
  strip_comments < "$1" \
    | grep -oE '\[Route\("[^"]*"\)\]' \
    | head -1 \
    | sed -E 's/^\[Route\("//; s/"\)\]$//'
}

# count_class_routes <file> - number of [Route("...")] declarations.
count_class_routes() {
  strip_comments < "$1" | grep -cE '\[Route\("[^"]*"\)\]' || true
}

# http_attributes <file> - prints "line<TAB>VERB<TAB>template" per HTTP verb attribute.
http_attributes() {
  strip_comments < "$1" | awk '
    {
      if (match($0, /\[Http(Get|Post|Put|Patch|Delete|Head|Options)(\([^)]*\))?\]/)) {
        attr = substr($0, RSTART, RLENGTH)
        verb = attr
        sub(/^\[Http/, "", verb)
        sub(/[^A-Za-z].*$/, "", verb)
        tmpl = ""
        if (match(attr, /"[^"]*"/)) {
          tmpl = substr(attr, RSTART + 1, RLENGTH - 2)
        }
        printf "%d\t%s\t%s\n", FNR, toupper(verb), tmpl
      }
    }
  '
}

# join_route <base> <template> - normalised full path without leading or trailing slash.
join_route() {
  local base="$1"
  local tmpl="$2"
  local path

  if [ -z "$tmpl" ]; then
    path="$base"
  else
    path="$base/$tmpl"
  fi

  printf '%s' "$path" \
    | sed -E 's#//+#/#g' \
    | sed -E 's#^/##; s#/$##' \
    | sed -E 's/\{([A-Za-z_][A-Za-z0-9_]*):[^}]+\}/{\1}/g'
}

# duplicate_http_attributes <file> - prints "line<TAB>count" where an action has more than one.
duplicate_http_attributes() {
  strip_comments < "$1" | awk '
    BEGIN { count = 0 }
    {
      if ($0 ~ /^[[:space:]]*\[/) {
        if ($0 ~ /^[[:space:]]*\[Http(Get|Post|Put|Patch|Delete|Head|Options)/) { count++ }
        next
      }
      if ($0 ~ /^[[:space:]]*$/) { next }
      if ($0 ~ /^[[:space:]]*(public|private|protected|internal)[[:space:]]/) {
        if (count > 1) { printf "%d\t%d\n", FNR, count }
        count = 0
        next
      }
    }
  '
}

# enum_members <file> - prints "line<TAB>enum<TAB>member<TAB>explicit(0|1)<TAB>value".
enum_members() {
  strip_comments < "$1" | awk '
    BEGIN { OFS = "\t"; inenum = 0; depth = 0; expected = 0; enumname = "" }
    {
      line = $0

      if (!inenum) {
        if (match(line, /(^|[[:space:]])enum[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
          inenum = 1
          depth = 0
          expected = 0
          enumname = substr(line, RSTART, RLENGTH)
          sub(/^.*enum[[:space:]]+/, "", enumname)
          sub(/[^A-Za-z0-9_].*$/, "", enumname)
        } else {
          next
        }
      }

      tmp = line
      opens = gsub(/\{/, "{", tmp)
      tmp = line
      closes = gsub(/\}/, "}", tmp)

      if (depth > 0 || opens > 0) {
        if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/)) {
          token = substr(line, RSTART, RLENGTH)
          member = token
          sub(/^[[:space:]]*/, "", member)
          rest = substr(line, RSTART + RLENGTH)
          sub(/^[[:space:]]+/, "", rest)
          if (rest != "" && rest !~ /^(=|,)/) { next }

          explicit = 0
          value = ""
          if (match(line, /=[[:space:]]*-?[0-9]+/)) {
            value = substr(line, RSTART, RLENGTH)
            sub(/=[[:space:]]*/, "", value)
            explicit = 1
            expected = value + 1
          } else {
            value = expected
            expected = expected + 1
          }

          printf "%d\t%s\t%s\t%d\t%s\n", FNR, enumname, member, explicit, value
        }
      }

      depth += opens - closes
      if (depth <= 0 && closes > 0) { inenum = 0 }
    }
  '
}

# message_candidates <file> - prints "line<TAB>text" for literal message assignments.
message_candidates() {
  strip_comments < "$1" | grep -nE \
    -e '\bMessage[[:space:]]*=[[:space:]]*"[^"]+"' \
    -e '\bmessage[[:space:]]*=[[:space:]]*"[^"]+"' \
    -e '\bdetail[[:space:]]*=[[:space:]]*"[^"]+"' \
    -e '"message"[[:space:]]*:[[:space:]]*"[^"]+"' \
    -e '"detail"[[:space:]]*:[[:space:]]*"[^"]+"' \
    2>/dev/null | while IFS= read -r hit; do
      local line="${hit%%:*}"
      local content="${hit#*:}"
      local value
      value="$(printf '%s' "$content" | grep -oE '"[^"]+"' | head -1 | sed -E 's/^"//; s/"$//')"
      [ -n "$value" ] && printf '%s\t%s\n' "$line" "$value"
    done
}
