#!/usr/bin/env bash
# dev/seamdemo.sh — gate for the ExHiROM three-act boundary synthesis cartridge.
#
# PHASE 1: Act 1 only — "the cartridge is the program". A 16-opcode bytecode VM
# marches its 24-bit FILE program counter across the whole 6 MiB image and folds
# the traversal; the centrepiece is one VM instruction split across the physical
# device seam (opcode at file $3FFFFF = $FF:FFFF, operand at file $400000 =
# $40:0000).
#
# Everything the ROM compares against is generated from tools/snes_cartmap.py by
# tools/snes-seamdemo-gen.py, and the host leg is tools/snes_seamdemo_oracle.py
# reading BYTES back out of the built image. This script restates no addresses.
#
#   1. HOST         P0 self-check (miniature fold + decode-cell coverage) and the
#                   address-model unit tests.
#   2. LAYOUT+LINK  generate the ExHiROM 6 MiB platform + data header, link.
#   3. EXTENTS      the linked image's non-zero slots are inside the reserved set
#                   (this is what makes a PRE-LINK CRC prediction legitimate).
#   4. FILL+HEADER  inject the payload, patch header/checksum, structural inspect.
#   5. DISASM       -verify-machineinstrs clean; the three codegen shapes the act
#                   exists to stress really are in the object:
#                     a7            lda [dp]        24-bit far fetch
#                     7c            jmp (abs,X)     jump-table dispatch
#                     __call_indir                  function-pointer ALU table
#   5b. PACING      SEAMDEMO_BENCH build reports ops/frame achieved on target.
#   6. ORACLE       host oracle over the built .sfc == the header's baked CRCs.
#   7. bsnes-jg     act1_crc == the oracle, act1_status == 0.
#   7b. ENTROPY     one picture across None/Low/High x2 (the 6b fingerprint).
#
# a16-only (no default 8-bit leg): a runtime far pointer is a 32-bit value and
# 32-bit value legalization exists only under +mos-a16 — same as cartsize-canary.
# The differential is host oracle == +mos-a16 @ bsnes-jg.
#
# JG_ONLY=1 skips the MAME leg (bsnes-jg needs no SPC700 IPL); see dev/_emu.sh.
# SEAMDEMO_SKIP_BENCH=1 skips step 5b (it costs a second link + emulator run).
#
# Runs INSIDE the dev container; drive: dev/run.sh seamdemo.
# Plan: docs/plans/2026-08-01-exhirom-three-act-synthesis-cart.md (P0 + P1).
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh seamdemo   # ExHiROM 6 MiB Act-1 bytecode-VM boundary cartridge: the VM's 24-bit file PC marches the whole image and folds to the generated oracle, with one instruction split across the device seam"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/seamdemo.c"
GEN="$BUILD/seamdemo-gen"
MAPPING=exhirom
SIZE=6M
PLAT="snes-cart-seamdemo"
CFG="$INSTALL/bin/mos-$PLAT.cfg"
ROM="$BUILD/seamdemo.sfc"
MAP="$BUILD/seamdemo.map"
BROM="$BUILD/seamdemo-bench.sfc"
BMAP="$BUILD/seamdemo-bench.map"
HDR="$GEN/seamdemo-data.h"
A16=(-Xclang -target-feature -Xclang +mos-a16)

# MEASURED, not estimated: on target an executed op costs ~1/24 frame and a drawn
# drawing dominates, so the shipping payload's 10,494 ops / 367 segments put the
# verdict near frame 2,050 (~34 s, bisected on act1_laps). 2,400 leaves margin.
JG_FRAMES="${JG_FRAMES:-2400}"
# The entropy fingerprint only needs a STABLE picture at a fixed frame count, not
# a completed act, so it runs its six boots at a small budget — otherwise step 7b
# alone would be six 20,000-frame runs.
JG_ENTROPY_FRAMES="${JG_ENTROPY_FRAMES:-900}"
export SMOKE_SETTLE="${SMOKE_SETTLE:-1800}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-40}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: dev/run.sh build)"; exit 1; }

mkdir -p "$GEN"
rc=0

echo "==> 1) host: P0 generator self-check + address-model unit tests"
if python3 "$ROOT/tools/snes-seamdemo-gen.py" selfcheck >"$GEN/selfcheck.log" 2>&1; then
  echo "  PASS: $(grep -c '\[PASS\]' "$GEN/selfcheck.log") self-checks"
  grep -E '^  (decode cells|edges|slots)' "$GEN/selfcheck.log" | sed 's/^/    /'
else
  echo "  FAIL: P0 self-check"; tail -30 "$GEN/selfcheck.log"; rc=1
fi
python3 "$ROOT/test/snes/cartridge-maps/test_snes_cartmap.py" >"$GEN/model.log" 2>&1 \
  && echo "  PASS: $(grep -c '\.\.\. ok' "$GEN/model.log" || true) address-model tests" \
  || { echo "  FAIL: address-model tests"; tail -25 "$GEN/model.log"; rc=1; }

source "$ROOT/dev/_emu.sh"
require_bios || bios_rc=$?
if [ "${bios_rc:-0}" -ne 0 ]; then
  echo "  NOTE: MAME leg unavailable (no SPC700 IPL) — continuing with the bsnes-jg leg only."
  export JG_ONLY=1
  require_bios
fi

echo
echo "==> 2) generate the ExHiROM 6 MiB platform + data header, link"
python3 "$ROOT/tools/snes-cartcanary.py" emit-platform \
  --mapping "$MAPPING" --size "$SIZE" --name "$PLAT" --install "$INSTALL"
python3 "$ROOT/tools/snes-seamdemo-gen.py" emit-header \
  --mapping "$MAPPING" --size "$SIZE" --out "$HDR"
python3 "$ROOT/tools/snes-seamdemo-gen.py" report \
  --mapping "$MAPPING" --size "$SIZE" --out "$GEN/seamdemo-layout.json"

"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os \
  -I "$GEN" -I "$ROOT/examples/snes" \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC" || { echo "  FAIL: link"; exit 1; }
echo "  linked $ROM: $(stat -c%s "$ROM") bytes"

echo
echo "==> 3) extents: everything the linker wrote is inside the reserved slots"
# CAUTION 1+2+5 from the P0 plan section: the act CRCs are predicted BEFORE the
# ROM exists, which is only sound if no traversal reads a byte the linker owns.
# This is that proof on the real artefact -- and it is also the --far-slots
# headroom report, so a ROM that outgrows the far arena is a named failure rather
# than a payload quietly overwriting .far_text.
if python3 "$ROOT/tools/snes-seamdemo-gen.py" check-extents \
     --mapping "$MAPPING" --size "$SIZE" --rom "$ROM" \
     --json "$GEN/extents.json" 2>&1 | sed 's/^/  /'; then
  :
else
  rc=1
fi

echo
echo "==> 4) fill the payload, patch header + checksum, structural inspect"
python3 "$ROOT/tools/snes-seamdemo-gen.py" fill --mapping "$MAPPING" --size "$SIZE" \
  --rom "$ROM" --report "$GEN/fill.json" || { echo "  FAIL: fill"; exit 1; }
python3 "$ROOT/tools/snes-checksum.py" --mapping "$MAPPING" "$ROM"
if python3 "$ROOT/tools/snes-checksum.py" --inspect --mapping "$MAPPING" "$ROM" >"$GEN/inspect.log" 2>&1; then
  echo "  PASS: $(grep -E '^(file length|physical devices|header at file|map mode byte)' "$GEN/inspect.log" | tr -s ' ' | paste -sd'; ')"
else
  echo "  FAIL: structural inspection"; cat "$GEN/inspect.log"; rc=1
fi

echo
echo "==> 5) disasm: far fetch + jump-table dispatch + function-pointer ALU table"
OBJ="$GEN/seamdemo.o"
# --config (not a bare --target) so <snes.h> resolves from the platform include
# path; -fno-lto because mos-common.cfg turns LTO on and `-c` under LTO emits
# bitcode llvm-objdump cannot disassemble.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto \
  -mllvm -verify-machineinstrs -I "$GEN" -I "$ROOT/examples/snes" \
  -c -o "$OBJ" "$SRC" 2>"$GEN/verify.log" && verify_rc=0 || verify_rc=$?

# The 'PH $p uses an undefined physical register' tolerance that used to live here
# is GONE: the defect it named is fixed (MOSRegisterInfo::saveScavengerRegister now
# flags the PHP's $p operand undef whenever no sub-register of $p holds an
# available value, matching the verifier's own forward availability set instead of
# a reaching-definition scan). Regression test:
# llvm/test/CodeGen/MOS/scavenger-p-undef.mir. This gate is now strict again.
if [ "$verify_rc" -eq 0 ]; then
  echo "  PASS: -verify-machineinstrs clean"
else
  echo "  FAIL: -verify-machineinstrs"
  grep -iE 'error|Bad machine' "$GEN/verify.log" | head -5
  rc=1
fi

# The disasm probe needs an object; -Oz emits the same three shapes, so it is what
# the probe reads if the -Os compile above failed to produce one.
if [ ! -s "$OBJ" ]; then
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Oz -fno-lto \
    -I "$GEN" -I "$ROOT/examples/snes" -c -o "$OBJ" "$SRC" 2>/dev/null \
    && echo "  NOTE: disasm probe reads the -Oz object (the -Os one was not emitted)"
fi
if [ -s "$OBJ" ]; then
  if DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ" 2>/dev/null)"; then
    n_far=$(grep -ciE '^\s*[0-9a-f]+:\s*a7\b' <<< "$DIS" || true)
    n_jmp=$(grep -ciE '^\s*[0-9a-f]+:\s*7c\b' <<< "$DIS" || true)
    n_ind=$(grep -c '__call_indir' <<< "$DIS" || true)
    [ "$n_far" -gt 0 ] \
      && echo "  PASS: $n_far far fetch(es) (lda [dp], a7) — the 24-bit cartridge cursor" \
      || { echo "  FAIL: no indirect-long far load in the VM"; rc=1; }
    [ "$n_jmp" -gt 0 ] \
      && echo "  PASS: $n_jmp jump-table dispatch (jmp (abs,X), 7c) — the 16-way switch" \
      || { echo "  FAIL: the opcode switch did not lower to a jump table"; rc=1; }
    [ "$n_ind" -gt 0 ] \
      && echo "  PASS: $n_ind __call_indir reference(s) — the function-pointer ALU table" \
      || { echo "  FAIL: the ALU table did not lower to an indirect call"; rc=1; }
  else
    echo "  FAIL: llvm-objdump could not read $OBJ"; rc=1
  fi
else
  echo "  FAIL: no object to disassemble at either -Os or -Oz"
  rc=1
fi

echo
echo "==> 6) host oracle over the BUILT image == the header's baked CRCs"
WANT_A1=0x$(sed -n 's/^#define SEAMDEMO_ACT1_CRC 0x\([0-9A-F]*\)u$/\1/p' "$HDR")
if python3 "$ROOT/tools/snes_seamdemo_oracle.py" --rom "$ROM" \
     --desc "$GEN/seamdemo-layout.json" >"$GEN/oracle.log" 2>&1; then
  sed 's/^/  /' "$GEN/oracle.log"
  got=$(sed -n 's/^act1 CRC \$\([0-9A-F]*\).*/0x\1/p' "$GEN/oracle.log")
  [ "$got" = "$WANT_A1" ] \
    && echo "  PASS: oracle act1 $got == header $WANT_A1" \
    || { echo "  FAIL: oracle act1 $got != header $WANT_A1"; rc=1; }
else
  echo "  FAIL: oracle"; cat "$GEN/oracle.log"; rc=1
fi

echo
echo "==> 6b) host C: the SAME VM source the ROM runs, over the built image"
# examples/65816/seamdemo_vm.h is compiled twice -- once by mos-clang for the
# 65816, once by the host cc here. This leg is the cheap one and it is the one
# that catches an ISA transcription slip in the shared header before any emulator
# run; the Python oracle is the independent third implementation.
if cc -O2 -Wall -Wextra -Wno-unused-function -I "$ROOT/examples/65816" -I "$GEN" \
      -o "$GEN/seamdemo-sim" "$ROOT/tools/seamdemo-sim.c" 2>"$GEN/sim-build.log"; then
  if "$GEN/seamdemo-sim" "$ROM" >"$GEN/sim.log" 2>&1; then
    sed 's/^/  /' "$GEN/sim.log"
    echo "  PASS: host C == Python oracle == the header's baked CRC"
  else
    echo "  FAIL: host C harness"; cat "$GEN/sim.log"; rc=1
  fi
else
  echo "  FAIL: could not build the host harness"; tail -10 "$GEN/sim-build.log"; rc=1
fi

if [ "${SEAMDEMO_SKIP_BENCH:-0}" != "1" ] && [ -x "$BUILD/jgxcheck" ]; then
  echo
  echo "==> 5b) pacing: ops/frame achieved on target"
  OPSPF=$(sed -n 's/^#define OPS_PER_FRAME \([0-9]*\)$/\1/p' "$SRC")
  # Same VM, same -Os, but the frame loop is replaced by "run flat out, count
  # v-blanks". The HVBJOY poll between ops is inside the measurement, so the
  # number is a LOWER bound on the ceiling -- the safe direction to size
  # OPS_PER_FRAME against.
  # -DSEAMDEMO_NO_DRAW so this really is the VM alone: the bench loop passes the
  # canvas through like any other build, and without it `canvas_line` would be
  # inside the number this step calls "VM alone".
  if "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os \
       -DSEAMDEMO_BENCH=1 -DSEAMDEMO_NO_DRAW=1 \
       -I "$GEN" -I "$ROOT/examples/snes" -Wl,-Map="$BMAP" -o "$BROM" "$SRC" 2>/dev/null \
     && python3 "$ROOT/tools/snes-seamdemo-gen.py" fill --mapping "$MAPPING" --size "$SIZE" \
          --rom "$BROM" >/dev/null \
     && python3 "$ROOT/tools/snes-checksum.py" --mapping "$MAPPING" "$BROM" >/dev/null; then
    read -r bvma bsize < <(_emu_map_lookup "$BMAP" bench_ops) || true
    if [ -n "${bvma:-}" ]; then
      # A deliberately impossible `want` so jgxcheck reports the value it read.
      line="$(JGX_ENTROPY=0 "$BUILD/jgxcheck" "$BROM" "$ROOT/vendor/bsnes-jg/Database" \
              "0x$bvma" 4 0xFFFFFFFF 300 2>&1 || true)"
      ops=$(sed -n 's/.*got=0x\([0-9A-F]*\).*/\1/p' <<< "$line")
      [ -n "$ops" ] && vm_per=$(( 0x$ops / 60 )) || vm_per=0
      echo "  VM alone (no drawing) : $vm_per ops/frame"
    else
      echo "  WARN: bench_ops not in $BMAP"; vm_per=0
    fi

    # The rate that actually decides the act's duration is the SHIPPING build's,
    # with canvas_line drawing. act1_ops is updated every frame for exactly this.
    read -r ovma osize < <(_emu_map_lookup "$MAP" act1_ops) || true
    if [ -n "${ovma:-}" ]; then
      # `|| true` INSIDE the substitution: the probe deliberately asks for a value
      # that cannot match, so jgxcheck exits non-zero, and `pipefail` would
      # otherwise make `set -e` kill the gate here.
      a=$( { JGX_ENTROPY=0 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
               "0x$ovma" 4 0x1 600 2>&1 || true; } | sed -n 's/.*got=0x\([0-9A-F]*\).*/\1/p')
      b=$( { JGX_ENTROPY=0 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
               "0x$ovma" 4 0x1 1800 2>&1 || true; } | sed -n 's/.*got=0x\([0-9A-F]*\).*/\1/p')
      if [ -n "$a" ] && [ -n "$b" ]; then
        # Centi-ops/frame: at ~5 ops/frame a plain integer divide truncates by up
        # to 20%, which is the difference between a 25 s and a 42 s projection.
        run_c=$(( (0x$b - 0x$a) * 100 / 1200 ))
        [ "$run_c" -ge 1 ] || run_c=1
        run_per=$(( run_c / 100 ))
        total_ops=$(sed -n 's/^#define SEAMDEMO_ACT1_OPS \([0-9]*\)UL$/\1/p' "$HDR")
        frames=$(( total_ops * 100 / run_c ))
        echo "  shipping build        : $(( run_c / 100 )).$(( run_c % 100 )) ops/frame"
        echo "                          (canvas_line is the cost: the VM alone manages $vm_per)"
        echo "  projected act length  : ~$frames frames = ~$(( frames / 60 )) s"
        # What this step CAN assert is that the frame loop is not asking for far
        # more ops than a frame can carry -- that is a P1 setting, and getting it
        # wrong makes the ticker stutter. The 20-30 s DURATION target is a
        # contract-level question (op count + MOVE density are set by the P0
        # generator) and is escalated in the plan, not asserted here.
        if [ "$OPSPF" -le $(( run_per * 4 )) ]; then
          echo "  PASS: OPS_PER_FRAME=$OPSPF is matched to the achievable $run_per ops/frame"
        else
          echo "  FAIL: OPS_PER_FRAME=$OPSPF asks for >4x the achievable $run_per ops/frame;"
          echo "        every loop iteration overruns v-blank and the ticker stutters"
          rc=1
        fi
        if [ "$(( frames / 60 ))" -gt 40 ]; then
          echo "  NOTE: the act is ~$(( frames / 60 )) s against the plan's 20-30 s. That gap is"
          echo "        ESCALATED (see the plan's P1 section): it needs a smaller op count or"
          echo "        a lower MOVE density from the P0 generator, which moves act1_crc."
        fi
      else
        echo "  WARN: could not read act1_ops"
      fi
    fi
  else
    echo "  WARN: bench build failed — pacing not measured this run"
  fi
fi

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo
  echo "==> 7) bsnes-jg: act1_crc == $WANT_A1, act1_status == 0x0000"
  for sym_want in "act1_crc:$WANT_A1" "act1_status:0x0000" "corpus_result:$WANT_A1"; do
    sym="${sym_want%%:*}"; want="${sym_want##*:}"
    read -r vma size2 < <(_emu_map_lookup "$MAP" "$sym") || true
    if [ -z "${vma:-}" ]; then echo "  FAIL: $sym not in the map"; rc=1; continue; fi
    len=$((0x$size2)); [ "$len" -ge 1 ] || len=1
    png=""; [ "$sym" = "act1_crc" ] && png="$BUILD/seamdemo.png"
    if line="$(JGX_ENTROPY=0 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
               "0x$vma" "$len" "$want" "$JG_FRAMES" ${png:+"$png"} 2>&1)"; then
      echo "  $sym: $line"
      [ -n "$png" ] && [ -f "$png" ] && echo "  screenshot: $png"
    else
      echo "  $sym: $line"; rc=1
    fi
  done

  # 7b) The picture must not depend on power-on state. Verbatim in intent from
  # dev/cartsize-canary.sh §6b — bsnes-jg randomises every PPU control register
  # the ROM does not write, so a ROM that inherits one renders a different
  # picture every boot while its WRAM verdict stays perfectly deterministic.
  echo "==> 7b) picture is independent of power-on entropy (None/Low/High x2)"
  fps=""
  for ent in 0 0 1 1 2 2; do
    # `|| true` INSIDE the substitution. This probe only wants the FRAMESCAN
    # line, so it asks for a WRAM value it does not care about -- and WRAM $0000
    # is imaginary register rc0, which is not zero, so jgxcheck exits non-zero and
    # `pipefail` would otherwise let `set -e` kill the gate here. (The canary's
    # copy of this block survives only because its rc0 happens to read back 0.)
    fp="$( { JGX_ENTROPY=$ent JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=0 \
             "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" 0x0 1 0x00 \
             "$JG_ENTROPY_FRAMES" 2>/dev/null || true; } \
          | sed -n 's/.*final hash=\([0-9A-F]*\) dom=#\([0-9A-F]*\).*/\1:#\2/p')"
    fps="$fps $ent=${fp:-NONE}"
  done
  uniq_n=$(printf '%s\n' $fps | sed 's/^[0-9]*=//' | sort -u | wc -l)
  if printf '%s\n' $fps | grep -q '=NONE$'; then
    echo "  FAIL: jgxcheck printed no FRAMESCAN line — rebuild it (dev/run.sh xcheck)"
    rc=1
  elif [ "$uniq_n" = 1 ]; then
    echo "  PASS: one picture across all six boots ($(printf '%s\n' $fps | head -1 | sed 's/^[0-9]*=//'))"
  else
    echo "  FAIL: $uniq_n distinct pictures across six boots — the ROM inherits PPU state it"
    echo "        never sets. Call snes_ppu_reset_blank() before touching the screen."
    for f in $fps; do echo "          entropy $f"; done
    rc=1
  fi
else
  echo "==> 7) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
echo "  ROM SHA-256: $(sha256sum "$ROM" | cut -c1-64)"
emu_verdict "$rc" "Act 1's bytecode VM marched its 24-bit file PC across the whole 6 MiB ExHiROM image, executed the instruction split across the physical device seam, and folded to the generated oracle"
exit $rc
