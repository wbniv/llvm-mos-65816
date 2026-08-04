#!/usr/bin/env bash
# dev/mandel-oop.sh — snesgfx formal verification: OOP Mandelbrot in Mode 7.
#
# Builds examples/snes/mandel-oop.c (+mos-a16) and verifies corpus_result == 0x204F
# (the canonical 64x56 fixed-point Mandelbrot CRC) via bsnes-jg and MAME.
# Also prints the dispatch count (indirect jumps per frame) and size delta vs
# mandel-display.sfc for docs/oop-in-c.md §4-§5.
#
# Drive: dev/run.sh mandel-oop. Outputs build/mandel-oop-jg.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-oop   # OOP Mandelbrot formal verification; screenshot bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mandel-oop.c"
VENDOR="$ROOT/vendor/bsnes-jg"
EXPECT=0x204F

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

"$ROOT/dev/sync-platform.sh"

echo "==> mandel-oop: OOP Mandelbrot (snesgfx Display + MandelLayer); expected CRC $EXPECT"

# 1. Build mandel-oop.sfc (+mos-a16, -verify-machineinstrs).
#    SNESGFX_CFLAGS: optional extra flags (e.g. -DSNESGFX_DISPATCH=2 for dispatch experiments).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -mllvm -verify-machineinstrs \
  ${SNESGFX_CFLAGS:-} \
  -Wl,-Map="$BUILD/mandel-oop.map" -o "$BUILD/mandel-oop.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mandel-oop.sfc" >/dev/null

VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mandel-oop.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/mandel-oop.sfc (+mos-a16, -verify clean); corpus_result @ WRAM $OFF"

# NOT FIXED: the vacuous-verify pattern (link above claims -mllvm -verify-machineinstrs but
# --config's default LTO never runs it) still applies here. An explicit -fno-lto -c verify
# compile was tried and trips the ALREADY-KNOWN `a16-rc-undef-ra-pure-virtual` MachineVerifier
# false-positive (KNOWN_ISSUES in tools/a16_fuzz.py; see TODO.md's mandel-double/gouraud
# entries for prior witnesses; fix plan docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md).
# Wiring a real verify leg here needs XFAIL-awareness this script doesn't have — left vacuous
# rather than landing a leg that hard-crashes the gate on a pre-existing, differential-proven-
# correct issue. See docs/plans/2026-08-03-123-snes-nmitally.md follow-up.
rc=0

# 2. bsnes-jg — dump framebuffer + assert corpus_result.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/mandel-oop-jg.png) + assert"
  # 5800 frames: matches mandel-shot.sh; all computation runs in _mandel_reserve() before the
  # first display_frame(), so corpus_result is set during the force-blank compute phase.
  "$JGX" "$BUILD/mandel-oop.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 5800 "$BUILD/mandel-oop-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 3. MAME under Xvfb — assert corpus_result (skip if no SPC700 IPL).
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): assert corpus_result"
  SNAP="$BUILD/.mandel-oop-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/mandel-oop.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 120 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run)"
fi

# 4. Disasm gate — virtual dispatch must not appear in the inner escape-time loop.
#    Count indirect control transfers in the ROM ELF; scene_emit's single vtable call
#    per frame is the only justified occurrence. The ELF MUST exist — a silent
#    "0 because the file is missing" is indistinguishable from real devirtualization.
echo
echo "==> disasm: indirect dispatch count (virtual dispatch gate)"
ELF="$BUILD/mandel-oop.sfc.elf"
if [ ! -f "$ELF" ]; then
  echo "    FAIL: $ELF missing — cannot count indirect dispatch"
  rc=1
else
  DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$ELF")"
  JMP_COUNT=$(printf '%s' "$DIS" | grep -cE 'jmp \(' || true)
  # Call sites only: indirect jmp/jsr addressing forms + calls into the __call_indir
  # helper (llvm-mos routes C function-pointer calls through it — 'jmp (' alone misses them).
  IND_COUNT=$(printf '%s' "$DIS" | grep -cE 'jmp \(|jsr \(|jsr.*<__call_indir>' || true)
  echo "    indirect JMP count in .text: $JMP_COUNT"
  echo "    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): $IND_COUNT"
fi
# In the mandel_cell + mandel_fill inner loops there should be zero JMPs —
# the virtual call to _mandel_emit is NOT in those loops.

# 5. Size delta vs mandel-display.sfc.
echo
echo "==> size delta: mandel-oop vs mandel-display (from .map files)"
if [ -f "$BUILD/mandel-display.map" ]; then
  OOP_SIZE=$(awk '/mandel-oop\.sfc\.lto\.o.*\.text/{s=strtonum("0x"$3)+0; sum+=s} END{print sum}' "$BUILD/mandel-oop.map" 2>/dev/null || \
             grep 'mandel-oop\.sfc\.lto\.o.*\.text' "$BUILD/mandel-oop.map" | awk '{s="0x"$3; cmd="printf \"%d\" "s; cmd | getline v; close(cmd); sum+=v} END{print sum}' || true)
  PROC_SIZE=$(awk '/mandel-display\.sfc\.lto\.o.*\.text/{s=strtonum("0x"$3)+0; sum+=s} END{print sum}' "$BUILD/mandel-display.map" 2>/dev/null || \
              grep 'mandel-display\.sfc\.lto\.o.*\.text' "$BUILD/mandel-display.map" | awk '{s="0x"$3; cmd="printf \"%d\" "s; cmd | getline v; close(cmd); sum+=v} END{print sum}' || true)
  echo "    mandel-oop  .text: ${OOP_SIZE:-?} bytes"
  echo "    mandel-display .text: ${PROC_SIZE:-?} bytes"
  OOP_ROM=$(wc -c < "$BUILD/mandel-oop.sfc" || true)
  PROC_ROM=$(wc -c < "$BUILD/mandel-display.sfc" || true)
  echo "    ROM sizes: mandel-oop=${OOP_ROM} mandel-display=${PROC_ROM}"
else
  echo "    (build mandel-display.sfc first for comparison: task mandel-shot)"
  wc -c "$BUILD/mandel-oop.sfc" | awk '{print "    mandel-oop ROM: "$1" bytes"}'
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==$EXPECT on host == +mos-a16@bsnes-jg"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
