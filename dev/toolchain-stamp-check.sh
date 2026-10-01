#!/usr/bin/env bash
# dev/toolchain-stamp-check.sh — proves dev/build.sh rebuilds the SDK when the toolchain changes.
#
# Runs the REAL stamp block of dev/build.sh (extracted with sed, not re-implemented) against a fake
# toolchain prefix and a fake SDK build tree in a temp dir, so nothing under build/ is touched:
#   1. no stamp yet            -> no wipe, stamp written
#   2. toolchain unchanged     -> no wipe (the SDK is not rebuilt)
#   3. clang / llc / lld byte changed (one at a time), or a binary appearing -> wipe
#   4. a path-only stamp from before the hashes were added -> wipe (once)
#   5. the stamp of the real build/llvm-mos-install carries three sha256 values and matches sha256sum
set -euo pipefail

usage() {
  cat <<'EOF2'
Usage: dev/toolchain-stamp-check.sh   (or: dev/run.sh toolchain-stamp-check)
Host-only. Exit 0 = every case behaves: unchanged toolchain -> SDK build tree kept; any change to
the installed clang, llc or lld (or a new/removed one) -> SDK build tree wiped for a rebuild.
EOF2
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/toolchain-stamp-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

block="$(sed -n '/^STAMP=/,/^fi$/p' "$ROOT/dev/build.sh")"
write="$(grep -F 'echo "$NEW_STAMP" > "$STAMP"' "$ROOT/dev/build.sh" || true)"
[ -n "$block" ] && [ -n "$write" ] || { echo "FATAL: stamp block not found in dev/build.sh"; exit 1; }

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $*"; fail=$((fail + 1)); }

BUILD="$WORK/build"; INSTALL="$BUILD/install"; MOS_TOOLCHAIN="$WORK/tc"
mkdir -p "$MOS_TOOLCHAIN/bin" "$INSTALL"
for t in clang llc lld; do echo "$t v1" >"$MOS_TOOLCHAIN/bin/$t"; done

# build_step: what dev/build.sh does around the stamp. Prints "wiped" or "kept".
build_step() {
  touch "$INSTALL/libc.a"            # an installed SDK library the wipe would remove
  local out
  out="$(BUILD="$BUILD" INSTALL="$INSTALL" MOS_TOOLCHAIN="$MOS_TOOLCHAIN" ROOT="$ROOT" bash -c "set -euo pipefail; $block; $write")"
  if [ -e "$INSTALL/libc.a" ]; then echo kept; else echo wiped; fi
  [ -z "$out" ] || echo "$out" >&2
  mkdir -p "$INSTALL"
}
expect() { # expect WANT LABEL
  local got; got="$(build_step 2>"$WORK/msg")"
  if [ "$got" = "$1" ]; then ok "$2 -> $got"; else bad "$2 -> $got, wanted $1"; cat "$WORK/msg"; fi
}

expect kept  "first build, no stamp yet"
expect kept  "toolchain unchanged"
expect kept  "toolchain unchanged (second repeat)"
echo "clang v2" >"$MOS_TOOLCHAIN/bin/clang";  expect wiped "clang binary changed"
expect kept  "unchanged again after the rebuild"
echo "lld v2"   >"$MOS_TOOLCHAIN/bin/lld";    expect wiped "lld binary changed"
echo "llc v2"   >"$MOS_TOOLCHAIN/bin/llc";    expect wiped "llc binary changed"
rm "$MOS_TOOLCHAIN/bin/llc";                  expect wiped "llc binary removed"
echo "llc v2"   >"$MOS_TOOLCHAIN/bin/llc";    expect wiped "llc binary reappeared"
echo "$MOS_TOOLCHAIN" >"$BUILD/.mos-toolchain"; expect wiped "legacy path-only stamp"
expect kept  "unchanged after the legacy stamp was rewritten"

REAL="${REAL_TOOLCHAIN:-$ROOT/build/llvm-mos-install}"
if [ -x "$REAL/bin/clang" ]; then
  stamp="$("$ROOT/dev/toolchain-stamp.sh" "$REAL")"
  want="$REAL clang=$(sha256sum "$REAL/bin/clang-23" | cut -d' ' -f1) llc=$(sha256sum "$REAL/bin/llc" | cut -d' ' -f1) lld=$(sha256sum "$REAL/bin/lld" | cut -d' ' -f1)"
  if [ "$stamp" = "$want" ] && [ "$(grep -o '=[0-9a-f]\{64\}' <<<"$stamp" | wc -l)" -eq 3 ]; then
    ok "real toolchain stamp = prefix + sha256 of clang-23, llc, lld"
  else
    bad "real toolchain stamp unexpected: $stamp"
  fi
else
  echo "  SKIP  real-toolchain leg (no $REAL/bin/clang)"
fi

echo "==> toolchain stamp check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
