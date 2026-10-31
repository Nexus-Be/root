# Removes comments and blanks the content of string/char literals.
# Line and column positions are preserved, so grep line numbers stay accurate.
# Set -v pfx=1 to prefix every output line with "FILENAME:FNR:".

BEGIN { state = 0 }

{
  s = $0
  n = length(s)
  i = 1
  out = ""

  while (i <= n) {
    c = substr(s, i, 1)
    if (state == 0) {
      if (c == "/" && substr(s, i + 1, 1) == "/") { state = 1; i = n + 1; continue }
      if (c == "/" && substr(s, i + 1, 1) == "*") { state = 2; i += 2; continue }
      if (c == "\"") { state = 3; out = out c; i++; continue }
      if (c == "\047") { state = 5; out = out c; i++; continue }
      out = out c
      i++
      continue
    }
    if (state == 1) { i = n + 1; continue }
    if (state == 2) {
      if (c == "*" && substr(s, i + 1, 1) == "/") { state = 0; i += 2; continue }
      i++
      continue
    }
    if (state == 3) {
      if (c == "\\") { out = out "  "; i += 2; continue }
      if (c == "\"") { state = 0; out = out c; i++; continue }
      out = out " "
      i++
      continue
    }
    if (state == 5) {
      if (c == "\\") { out = out "  "; i += 2; continue }
      if (c == "\047") { state = 0; out = out c; i++; continue }
      out = out " "
      i++
      continue
    }
  }

  print (pfx ? FILENAME ":" FNR ":" out : out)
}
