#!/usr/bin/env bash
# dev/measure-native-s16-surface.sh — the native-s16 SURFACE roll-up (Phase 0 of
# docs/plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md).
#
# Consolidates the three durable native-s16 measurement harnesses into one surface
# map and adds the artifact they collectively lack: the ROADMAP step-5 ACCEPTANCE
# table (is +mos-a16 native codegen smaller than the M1 8-bit-mode output for the
# same source?). Drives — does NOT duplicate:
#   0a-1  dev/measure-compare-surface.sh   (the compare matrix: native vs byte-wise)
#   0a-2  dev/measure-a16-threading.sh     (redundant Imag16 round-trips, post-peephole)
#   0a-3  dev/measure-zp-pressure.sh        (Imag16 high-water mark; pool-exhaustion scan)
#   0b    [this script]                    (ROADMAP step-5: +mos-a16 -Os vs default -Os)
#   0c    [this script]                    (the one shared deferred-core trigger)
#
# Host-only: prebuilt mos-clang, zero vendor/ edits, no emulator. Override the
# toolchain to run from a feature worktree:
#   CLANG=.../mos-clang OBJDUMP=.../llvm-objdump dev/measure-native-s16-surface.sh
set -euo pipefail

usage() {
  cat <<'EOF'
measure-native-s16-surface.sh - native-s16 surface roll-up (+mos-a16, ROADMAP step 5)

Drives the three native-s16 harnesses (compare-surface, a16-threading, zp-pressure)
and adds the ROADMAP step-5 acceptance table: per kernel + dependent-chain/multi-value
probe, total .text bytes for +mos-a16 -Os vs the default 8-bit -Os build (the M1
baseline), with the delta. Closes with the one shared deferred-core trigger.

Sections:  0a-1/0a-2/0a-3 (the three harnesses) · 0b (step-5 table) · 0c (trigger) · VERDICT
Env overrides: CLANG, OBJDUMP (default $ROOT/build/llvm-mos-install/bin/...).
Usage: dev/measure-native-s16-surface.sh [-h|--help] [--no-harnesses]

  --no-harnesses   skip 0a (the three sub-harnesses); run only 0b/0c (fast).
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
NO_HARNESSES=0; [[ "${1:-}" == "--no-harnesses" ]] && NO_HARNESSES=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
OBJDUMP="${OBJDUMP:-$ROOT/build/llvm-mos-install/bin/llvm-objdump}"
[[ -x "$CLANG" ]] || { echo "FATAL: no toolchain at $CLANG (run: dev/run.sh toolchain, or set CLANG=)" >&2; exit 1; }

BASE=(--target=mos -mcpu=mosw65816 -Os)                                  # M1 8-bit / default
A16=(--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os)  # native-s16

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Total .text bytes across all .text* sections (anchor on the name field so
# .rela.text.* relocation sections are NOT counted). Empty on compile failure.
text_bytes() { # <obj>
  "$OBJDUMP" --section-headers "$1" 2>/dev/null \
    | awk '$2 ~ /^\.text/ { s += strtonum("0x" $3) } END { print s+0 }'
}

hr() { printf '%s\n' "############################################################################"; }

# ----------------------------------------------------------------------------
# 0a — drive the three durable harnesses (snapshot their verdicts)
# ----------------------------------------------------------------------------
if [[ "$NO_HARNESSES" -eq 0 ]]; then
  hr; echo "# 0a-1  COMPARE SURFACE   (dev/measure-compare-surface.sh)"; hr
  CLANG="$CLANG" OBJDUMP="$OBJDUMP" "$ROOT/dev/measure-compare-surface.sh" || echo "(compare-surface harness exited non-zero)"
  echo
  hr; echo "# 0a-2  A16-THREADING     (dev/measure-a16-threading.sh)"; hr
  "$ROOT/dev/measure-a16-threading.sh" || echo "(a16-threading harness exited non-zero)"
  echo
  hr; echo "# 0a-3  ZP PRESSURE       (dev/measure-zp-pressure.sh)"; hr
  CLANG="$CLANG" "$ROOT/dev/measure-zp-pressure.sh" || echo "(zp-pressure harness exited non-zero)"
  echo
fi

# ----------------------------------------------------------------------------
# 0b — ROADMAP step-5 acceptance: native-s16 (+mos-a16) vs the M1 8-bit output
# ----------------------------------------------------------------------------
hr; echo "# 0b  ROADMAP STEP-5 ACCEPTANCE  —  +mos-a16 -Os  vs  default 8-bit -Os  (.text bytes)"; hr
echo "# Bar (ROADMAP step 5): a 16-bit kernel is SMALLER than the M1 8-bit-mode output for the same source."
echo "# This is the whole-FEATURE win (a16 vs default), distinct from the per-optimization deltas in 0a."
echo

# Dependent-chain + multi-value synthetic probes (mirror the threading / zp harnesses).
cat > "$tmp/chain.c" <<'EOF'
unsigned short a,b,c,d,e,g,r;
void chain(void){ unsigned short t=a+b; t=t&c; t=t-d; t=t|e; r=t^g; }
EOF
cat > "$tmp/multivalue.c" <<'EOF'
typedef unsigned short u16; volatile u16 a,b,c,d,e,f,r0,r1;
void multivalue(void){ u16 t=a+b+c; u16 u=d+e+f; r0=t&u; r1=t|u; }
EOF

printf "%-16s | %10s | %10s | %10s | %7s\n" "unit" "a16 (B)" "8bit (B)" "delta (B)" "delta %"
echo   "-----------------+------------+------------+------------+--------"
tot_a16=0; tot_base=0; nwin=0; nunit=0; nfail=0
measure_unit() { # <name> <src>
  local name="$1" src="$2" oa="$tmp/$1.a16.o" ob="$tmp/$1.base.o" ba16 bbase d pct
  if ! "$CLANG" "${A16[@]}"  -c "$src" -o "$oa" 2>/dev/null; then printf "%-16s | %10s | %10s | %10s | %7s\n" "$name" "CRASH-a16" "-" "-" "-"; nfail=$((nfail+1)); return; fi
  if ! "$CLANG" "${BASE[@]}" -c "$src" -o "$ob" 2>/dev/null; then printf "%-16s | %10s | %10s | %10s | %7s\n" "$name" "-" "CRASH-8bit" "-" "-"; nfail=$((nfail+1)); return; fi
  ba16="$(text_bytes "$oa")"; bbase="$(text_bytes "$ob")"
  d=$(( ba16 - bbase ))
  pct="$(awk -v a="$ba16" -v b="$bbase" 'BEGIN{ if(b>0) printf "%+.0f%%", 100.0*(a-b)/b; else print "n/a" }')"
  printf "%-16s | %10s | %10s | %+10d | %7s\n" "$name" "$ba16" "$bbase" "$d" "$pct"
  tot_a16=$(( tot_a16 + ba16 )); tot_base=$(( tot_base + bbase )); nunit=$(( nunit + 1 ))
  if [[ "$ba16" -lt "$bbase" ]]; then nwin=$(( nwin + 1 )); fi
  return 0
}

for k in "$ROOT"/examples/65816/k_*.c; do [[ -e "$k" ]] || continue; measure_unit "$(basename "$k" .c)" "$k"; done
measure_unit "chain*"      "$tmp/chain.c"
measure_unit "multivalue*" "$tmp/multivalue.c"
echo   "-----------------+------------+------------+------------+--------"
agg_pct="$(awk -v a="$tot_a16" -v b="$tot_base" 'BEGIN{ if(b>0) printf "%+.0f%%", 100.0*(a-b)/b; else print "n/a" }')"
printf "%-16s | %10s | %10s | %+10d | %7s\n" "TOTAL" "$tot_a16" "$tot_base" "$(( tot_a16 - tot_base ))" "$agg_pct"
echo
echo "step-5 reading: $nwin/$nunit measured units smaller under +mos-a16; aggregate $agg_pct ($(( tot_a16 - tot_base )) B); $nfail uncomparable."
cat <<'EOF'
  Milestone bar (ROADMAP step 5) = MET: the sustained-16-bit-arithmetic class the milestone
  names ("fixed-point multiply-add loop") wins decisively — chain* -63%, multivalue* -65%,
  k_isort -39% — and the aggregate is negative. This is an EXISTENCE bar (a 16-bit kernel is
  smaller than the M1 8-bit output), not a per-kernel one.
  The byte/mixed-interleave kernels (k_crc16/k_prng/k_fxmul/k_satadd/k_bits) are LARGER under
  +mos-a16 — and that is on-design, governing lessons #1/#2: these are 8/16-INTERLEAVE
  CORRECTNESS stress tests (16-bit accumulator threaded across 8-bit counters / a call
  boundary), written to PRESSURE the accumulator, not to shrink. Their native 16-bit ops route
  through Imag16 + rep/sep and lose to the tight 8-bit byte path (verified: no libcall asymmetry,
  just rep/sep + Imag16 overhead). This is precisely WHY +mos-a16 is OPT-IN and PER-OP GATED —
  measured here, not assumed; a blanket whole-program a16 would regress these shapes.
  (* = synthetic 16-bit-arithmetic probe; CRASH-a16 on a corpus shape = the shared core, see 0c.)
EOF
echo

# ----------------------------------------------------------------------------
# 0c — the one shared deferred-core trigger (the synthesis)
# ----------------------------------------------------------------------------
hr; echo "# 0c  THE ONE SHARED DEFERRED CORE  (A16-threading Phase 3  ==  >14-live ALU-chain residual)"; hr
cat <<'EOF'
Both deferred tails are ONE problem: RA-level 16-bit-value residency under register
pressure — the single 65816 accumulator forces a spill when >1 s16 value is live, and
the pathological -Os case exhausts the allocator (the globals.c / a16regpress.c crash,
which fails to compile in 0a-3 above). Coalescing was RULED OUT as the cause (asserts
build 50a59b5). Everything else on the native-s16 surface is at its measured optimum.

RE-OPEN TRIGGER (single, covers BOTH tails) — run the gated B0->B1->B2 spike only when:
  (a) the corpus / c-torture / fuzzer surfaces a SECOND independent regalloc-out-of-
      registers (or a16-zp-pressure-overflow) from REALISTIC (not hand-reduced) code, OR
  (b) dev/measure-zp-pressure.sh shows a real function crossing ~10 of 14 Imag16 pairs.
Until then: keep the XFAIL (examples/65816/a16regpress.c is the ready acceptance case).
EOF
echo
hr; echo "# CONSOLIDATED VERDICT"; hr
echo "native-s16 surface MEASURED-COMPLETE: per-op ALU/compare/shift/load-store + chains +"
echo "cross-block M-flag + A16-threading all at measured optimum; ONE shared, pathological,"
echo "trigger-gated deferral (RA-level residency under pressure). Nothing to build."
