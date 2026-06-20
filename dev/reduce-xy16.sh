#!/usr/bin/env bash
# dev/reduce-xy16.sh — cvise/creduce interestingness test for the #321 +mos-xy16 runtime
# value miscompile (Csmith seeds 247 + 445; xy16-only — a16/default are correct).
#
# Returns 0 (INTERESTING — keep) iff the candidate TU still exhibits the xy16-only
# divergence, decided by a TARGET-ONLY multi-config differential (no x86 host oracle is
# possible: Csmith's int is 16-bit but x86's is 32-bit, so a native build computes a
# different value — see docs/plans/2026-06-20-321-xy16-seed445-cvise-reduction.md):
#
#     V(default-Os) == V(default-O0) == V(a16-Os)        (trusted oracle, self-consistent
#                                                          across opt-level AND the
#                                                          maximally-different a16 codegen
#                                                          — a strong UB filter)
#     AND  V(xy16-Os) != V(default-Os)                   (the miscompile persists)
#
# All four values are read from bsnes-jg headless (build/jgxcheck) — load-insensitive, so
# safe under cvise's parallel workers; MAME is NOT used here (flaky under load). A compile
# fail, a missing corpus_result, an xy16 hang/crash (no value), or the oracle configs
# disagreeing all ⇒ NOT interesting, which keeps cvise on *this value bug* and steers it
# away from UB and from drifting into a different (crash) defect.
#
# cand.c must be a PREPROCESSED, standalone TU (the Csmith adapter + csmith.h inlined) so
# cvise's clang_delta can reduce the whole program. Produce it once with:
#   mos-clang --config build/install/bin/mos-snes.cfg -mcpu=mosw65816 \
#     -include examples/65816/csmith/csmith_snes.h -I vendor/csmith/include \
#     -E -P build/fuzz-triage/csmith-seed-00445.c -o cand.c
# (the adapter's suppression macros must be present at preprocess time, so it is force-
# included here; that inlines corpus_result/platform_main_end too — this script therefore
# builds cand.c standalone, with NO -include/-I, to avoid a double definition.)
#
# Usage:
#   cvise --n "$(nproc)" "$(pwd)/dev/reduce-xy16.sh" cand.c     # reduce ./cand.c in place
#
# Prereqs: prebuilt toolchain (build/llvm-mos-install) + SDK (build/install/bin/mos-snes.cfg)
# + build/jgxcheck + vendor/bsnes-jg/Database. Override the toolchain with MOS_TOOLCHAIN,
# the frame budget with XY16_FRAMES (default 90 — covers the slowest config: -O0 of the full
# seed 445 completes by frame ~45; the -Os/xy16/a16 builds by frame ~5. Reductions only get
# faster, so 90 is a safe upper bound. A too-low budget only ever rejects a real candidate
# (the slow -O0 oracle reads its init 0 → "disagrees") — a harmless false-negative, never a
# false-positive, since the -Os xy16-vs-default fast path compares two equally-fast builds).
set -euo pipefail

usage() { echo "Usage: cvise --n \$(nproc) \$(pwd)/dev/reduce-xy16.sh cand.c   # exit 0 = still miscompiles"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
CFG="$ROOT/build/install/bin/mos-snes.cfg"
JGX="$ROOT/build/jgxcheck"
JGDB="$ROOT/vendor/bsnes-jg/Database"
CAND="${1:-cand.c}"                 # cvise runs us in a temp cwd holding the candidate
FRAMES="${XY16_FRAMES:-90}"

# Build $CAND in one config and echo its corpus_result value (UPPERCASE hex, no 0x) or ""
# (build/link fail, no corpus_result symbol, hang/no-boot → no value). Always returns 0 so
# `set -e` never aborts on an expected build failure. Writes outputs into the (cvise-isolated)
# cwd, so parallel workers don't collide.
val() {  # $1=tag  $2..=clang opt + feature flags
  local tag="$1"; shift
  local sfc="./$tag.sfc" map="./$tag.map" off sz out
  if ! "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "$@" \
        -Wl,-Map="$map" -o "$sfc" "$CAND" 2>/dev/null; then
    return 0
  fi
  read -r off sz < <(awk '$NF=="corpus_result"{print $1, $3; exit}' "$map") || true
  [ -n "${off:-}" ] || return 0
  out=$(timeout 40 "$JGX" "$sfc" "$JGDB" "0x$off" "$((16#$sz))" 0x0 "$FRAMES" 2>&1 || true)
  printf '%s' "$out" | grep -oiE 'got=0x[0-9a-f]+' | head -1 | sed 's/.*[xX]//' | tr 'a-f' 'A-F' || true
  return 0
}

# Fast path: the dominant "killed the bug" reduction makes xy16 agree with default — catch it
# after just 2 builds before paying for the oracle cross-checks.
xy=$(val xy16  -Os -Xclang -target-feature -Xclang +mos-xy16)
df=$(val defOs -Os)
[ -n "$xy" ] && [ -n "$df" ] && [ "$xy" != "$df" ] || exit 1

# Oracle must be self-consistent across opt-level and the a16 path (UB filter).
o0=$(val defO0 -O0)
a1=$(val a16   -Os -Xclang -target-feature -Xclang +mos-a16)
[ -n "$o0" ] && [ -n "$a1" ] && [ "$df" = "$o0" ] && [ "$df" = "$a1" ] || exit 1

exit 0   # INTERESTING: default-Os == default-O0 == a16-Os, all != xy16-Os
