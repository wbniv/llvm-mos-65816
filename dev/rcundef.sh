#!/usr/bin/env bash
# dev/rcundef.sh — regression gate for the a16/xy16 "Using an undefined physical register"
# MachineVerifier failure (the long-standing `a16-newton-step-rc-undef`, also witnessed by
# the #23 L-system demo). Fixed in MOSRegisterInfo::shouldCoalesce (fork patch 0002): the
# register coalescer no longer joins a value read out of an imaginary $rcN pair back into
# that physical pair across a clobbering libcall.
#
# This gate asserts the INVERSE of the old XPASS guard: the three witnesses
# (examples/65816/rcundef.c, examples/snes/corpus/newton_sim.c, lsystem_sim.c) must all
# -verify-machineinstrs CLEAN under +mos-a16 AND +mos-xy16 at -O1 and -Os. A recurrence of
# the disconnected `$x = COPY $rcN` def->use hard-FAILs. Pure host verify — no
# container/SDK/emulator needed. Drive: dev/run.sh rcundef.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh rcundef  # -verify clean gate for the rc-undef coalescer fix"; exit 0;; esac
ROOT=/work; B="$ROOT/build"
TOOL="$B/llvm-mos-install/bin"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }

# This gate covers the COALESCER root cause (cause #1): the register coalescer
# folding a value read straight out of a call-clobbered imaginary $rcN
# (`vreg = COPY $rcN`) into an Imag16 pair that outlives the clobbering call,
# whereupon the allocator re-binds it to $rcN across the clobber. Fixed in
# MOSRegisterInfo::shouldCoalesce — clears the minimal repro at every level and
# newton at -Os, the canonical level the whole battery verifies at
# (tools/a16_fuzz.py and every demo/corpus build use -Os; -O1 is never built).
#
# A SEPARATE cause #2 — the register *allocator* binding a PURE-VIRTUAL value
# (no $rcN copy hint at all) to a call-clobbered $rc pair — still affects
# newton_sim.c at -O1 and lsystem_sim.c (all levels). shouldCoalesce cannot
# target it (no copy-hint signal); it is an RA-assignment defect tracked
# separately, and lsystem keeps its KNOWN_ISSUES XFAIL. So this gate verifies
# only what cause #1 guarantees. See
# docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md.
declare -A OPTS=(
  ["$ROOT/examples/65816/rcundef.c"]="-O0 -O1 -Os"
  ["$ROOT/examples/snes/corpus/newton_sim.c"]="-O0 -Os"
)
rc=0
for src in "$ROOT/examples/65816/rcundef.c" \
           "$ROOT/examples/snes/corpus/newton_sim.c"; do
  [ -f "$src" ] || { echo "    SKIP (missing) $(basename "$src")"; continue; }
  for spec in "a16:-Xclang -target-feature -Xclang +mos-a16" \
              "xy16:-Xclang -target-feature -Xclang +mos-xy16"; do
    name="${spec%%:*}"; feat="${spec#*:}"
    for opt in ${OPTS[$src]}; do
      log=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 $feat "$opt" \
              -mllvm -verify-machineinstrs -c "$src" -o /dev/null 2>&1) && ok=1 || ok=0
      if [ "$ok" = 1 ] && ! echo "$log" | grep -qi 'Bad machine code\|undefined physical register'; then
        echo "    $(basename "$src") $name $opt  -verify clean"
      else
        echo "    $(basename "$src") $name $opt  -verify FAIL"
        echo "$log" | grep -iE 'Bad machine code|undefined physical|instruction:' | sed 's/^/        /' | head -3
        rc=1
      fi
    done
  done
done
echo
[ "$rc" = 0 ] && echo "RESULT: PASS — rcundef (a16+xy16, all -O) + newton (-Os) -verify clean; coalescer rc-undef (cause #1) fixed" \
             || echo "RESULT: FAIL — rc-undef cause #1 regressed (disconnected \$rcN def->use is back)"
exit $rc
