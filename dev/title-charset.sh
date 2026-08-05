#!/usr/bin/env bash
# dev/title-charset.sh — gate every demo title string against what the title fonts can actually draw.
#
# A character the font has no art for renders as a SPACE, silently. That is not hypothetical: six
# demo titles shipped with their underscore missing (G_FCOPYSIGN read as "G FCOPYSIGN"), julia's
# "Z^2 + C" lost its caret, and five more lost lowercase letters — none of it visible except by
# looking at a screenshot of the title card, which nothing gates on.
#
# This scans every title_begin/title_begin16/m7splash call site in examples/snes/*.c and
# checks each string against the glyphs that are actually non-blank in the GENERATED font headers
# (line0 → font8.h, line1 → font16.h). Reading the headers rather than a hardcoded list means the
# gate stays honest as glyphs are added or removed.
#
# Lowercase is fine: title_layer.h folds a-z to A-Z at render time (see _title_glyph).
#
# Exit 1 if any title contains an unrenderable character.
#   dev/title-charset.sh            # gate the whole battery
#   dev/title-charset.sh --list     # also print each font's blank slots
set -euo pipefail

case "${1-}" in -h|--help)
  cat <<'USAGE'
Usage: dev/title-charset.sh [--list]

Check every SNES demo title against the glyphs present in examples/snes/font8.h (line0, 8x8) and
font16.h (line1, 16x16). Exits non-zero if a title uses a character that would render as a blank.

  --list   also report which slots in each font are still empty

Fixing a failure, in order of preference:
  1. draw the glyph — add its art to tools/gen-font8.py / tools/gen-font16.py and regenerate.
     Slots 0x20..0x5F already exist in both tables, so filling one costs ZERO bytes;
  2. reword the title;
  3. only if the character is outside 0x20..0x5F and genuinely needed, extend the font range
     (font16 is 4 KB for 64 glyphs — that is a real cost in the near-code window).
USAGE
  exit 0;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST=0
[ "${1-}" = "--list" ] && LIST=1

LIST=$LIST python3 - "$ROOT" <<'PY'
import os, re, sys, pathlib

root = pathlib.Path(sys.argv[1])
ex   = root / "examples/snes"
show_blank = os.environ.get("LIST") == "1"

def font(path, words_per_glyph):
    """(set of renderable codepoints, set of declared-but-blank ones) from a generated header."""
    body = (root / path).read_text().split("= {", 1)[1]
    w = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{4})", body)]
    n = len(w) // words_per_glyph
    ok, blank = set(), set()
    for g in range(n):
        code = 0x20 + g
        (ok if any(w[g*words_per_glyph:(g+1)*words_per_glyph]) else blank).add(code)
    ok.add(0x20)                      # space is legitimately blank
    blank.discard(0x20)
    return ok, blank, n

ok8,  blank8,  n8  = font("examples/snes/font8.h",  8)
ok16, blank16, n16 = font("examples/snes/font16.h", 32)

def chars(s):
    return " ".join(chr(c) for c in sorted(s)) or "(none)"

if show_blank:
    print(f"font8   0x20..0x{0x20+n8-1:02X}: {len(blank8):2d} empty slots: {chars(blank8)}")
    print(f"font16  0x20..0x{0x20+n16-1:02X}: {len(blank16):2d} empty slots: {chars(blank16)}")
    print()

CALL = re.compile(r'\b(?:title_begin16|title_begin|m7splash)\s*\(([^;]*?)\)\s*;', re.S)
STR  = re.compile(r'"((?:[^"\\]|\\.)*)"')

bad, sites = [], 0
for f in sorted(ex.glob("*.c")):
    for m in CALL.finditer(f.read_text()):
        args = STR.findall(m.group(1))
        if len(args) < 2:
            continue
        sites += 1
        for which, s, ok in (("line0 (8x8)", args[0], ok8), ("line1 (16x16)", args[1], ok16)):
            offenders = []
            for ch in s:
                c = ord(ch.upper()) if 'a' <= ch <= 'z' else ord(ch)   # render-time fold
                if c not in ok:
                    why = "no glyph" if 0x20 <= c <= 0x5F else "outside font range"
                    offenders.append(f"{ch!r} ({why})")
            if offenders:
                bad.append((f.name, which, s, offenders))

print(f"checked {sites} title call sites across {len(list(ex.glob('*.c')))} demo sources")
if not bad:
    print("PASS  every title character has a glyph")
    sys.exit(0)

print(f"FAIL  {len(bad)} title(s) use characters that would render as blanks:\n")
for name, which, s, offenders in bad:
    print(f"  {name:22s} {which:14s} {s!r}")
    print(f"  {'':22s} {'':14s} -> {', '.join(offenders)}")
print("\nsee dev/title-charset.sh --help for how to fix")
sys.exit(1)
PY
