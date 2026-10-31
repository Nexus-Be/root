# Extracts the first two string literals of every `new XxxException(...)` call.
# Output: FILENAME<TAB>LINE<TAB>TYPE<TAB>FIRST_LITERAL<TAB>SECOND_LITERAL
# Handles calls whose arguments span multiple lines and ignores single-argument calls.

function collect(s, arr,   n, rest) {
  n = 0
  rest = s
  while (match(rest, /"[^"\\]+"/)) {
    n++
    arr[n] = substr(rest, RSTART + 1, RLENGTH - 2)
    rest = substr(rest, RSTART + RLENGTH)
  }
  return n
}

BEGIN {
  state = 0
  startline = 0
  type = ""
  code = ""
}

FNR == 1 {
  state = 0
  startline = 0
  type = ""
  code = ""
}

{
  if (state == 0) {
    if (match($0, /new[ \t]+[A-Za-z_][A-Za-z0-9_]*Exception[ \t]*\(/)) {
      matched = substr($0, RSTART, RLENGTH)
      type = matched
      sub(/^new[ \t]+/, "", type)
      sub(/[ \t]*\($/, "", type)

      rest = substr($0, RSTART + RLENGTH)
      cnt = collect(rest, S)

      if (cnt >= 1) {
        code = S[1]
        startline = FNR
        if (cnt >= 2) {
          printf "%s\t%d\t%s\t%s\t%s\n", FILENAME, startline, type, code, S[2]
          state = 0
        } else if (rest ~ /\)/) {
          state = 0
        } else {
          state = 2
        }
      } else if (rest ~ /\)/) {
        state = 0
      } else {
        startline = FNR
        state = 1
      }
      next
    }
    next
  }

  cnt = collect($0, S)

  if (state == 1) {
    if (cnt >= 1) {
      code = S[1]
      if (cnt >= 2) {
        printf "%s\t%d\t%s\t%s\t%s\n", FILENAME, startline, type, code, S[2]
        state = 0
      } else {
        state = 2
      }
    } else if ($0 ~ /\)/) {
      state = 0
    }
  } else if (state == 2) {
    if (cnt >= 1) {
      printf "%s\t%d\t%s\t%s\t%s\n", FILENAME, startline, type, code, S[1]
      state = 0
    } else if ($0 ~ /\)/) {
      state = 0
    }
  }
}
