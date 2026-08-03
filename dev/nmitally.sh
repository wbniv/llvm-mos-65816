#!/usr/bin/env bash
# dev/nmitally.sh — #123 VBlank Interrupt Tally: the battery's first __attribute__((interrupt))
# handler. Builds examples/snes/nmitally.c three ways (default / +mos-a16 / +mos-xy16), runs the
# MANDATORY ISR disasm gate (tools/nmitally-isr-gate.py) on the handler's real disassembly, then
# asserts corpus_result == the host oracle (tools/nmitally-sim.c) on bsnes-jg (3x, byte-identical
# framebuffer) and MAME.
#
# The disasm gate is not optional garnish here: this demo's failure class is legal MIR + wrong
# machine code (an ISR that assumes an M/X width the 65816 never establishes on interrupt entry),
# which a value gate can miss entirely on a lucky interleaving.
#
# Drive: dev/run.sh nmitally. Outputs build/nmitally-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh nmitally   # #123 NMI tally: ISR disasm gate + 5-way CRC on MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/nmitally.c"
SLICE="$ROOT/examples/snes/corpus/nmitally_sim.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

# 1. Host oracle — ground truth for both the corpus slice and the interrupt-driven ROM.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/nmitally-sim.c" -o "$BUILD/nmitally-sim"
EXPECT=$("$BUILD/nmitally-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: nmitally gate CRC = $EXPECT"

# 2. Build the ROM three ways; each must expose corpus_result at the same-ish WRAM slot.
build_variant() {  # name flags...
  local name="$1"; shift
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "$@" -Os \
    -Wl,-Map="$BUILD/nmitally-$name.map" -o "$BUILD/nmitally-$name.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/nmitally-$name.sfc" >/dev/null
  awk '$NF=="corpus_result"{print "0x"$1; exit}' "$BUILD/nmitally-$name.map"
}
DVMA=$(build_variant default)
AVMA=$(build_variant a16  -Xclang -target-feature -Xclang +mos-a16)
XVMA=$(build_variant xy16 -Xclang -target-feature -Xclang +mos-xy16)
cp "$BUILD/nmitally-a16.sfc" "$BUILD/nmitally.sfc"
cp "$BUILD/nmitally-a16.map" "$BUILD/nmitally.map"
ADDR=$(printf '0x%X' $(( 0x7E0000 + AVMA )))
echo "==> built build/nmitally-{default,a16,xy16}.sfc; corpus_result @ WRAM default=$DVMA a16=$AVMA xy16=$XVMA"

# 3. -verify-machineinstrs, both feature modes, on BOTH the corpus slice and the ROM translation
# unit (the ROM is the one that contains the interrupt handler — the slice has no ISR at all).
#
# -fno-lto is LOAD-BEARING, not decoration. `mos-clang --config … -c` defaults to LTO and emits
# LLVM IR BITCODE, so codegen never runs in that process and `-mllvm -verify-machineinstrs`
# silently verifies NOTHING. Confirmed here: `file` reports "LLVM IR bitcode" for the -c output
# without -fno-lto, and llvm-objdump rejects it as "not a valid object file". Any gate script that
# omits -fno-lto is reporting a vacuous PASS (dev/_demo5.sh and the /snes-demo template both do).
echo "==> -verify-machineinstrs (-fno-lto, so codegen actually runs)"
for feat in +mos-a16 +mos-xy16; do
  ok=1
  for tu in "$SLICE" "$SRC"; do
    "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang $feat -Os \
      -fno-lto -mllvm -verify-machineinstrs -c "$tu" -I"$ROOT/examples" \
      -o "$BUILD/nmitally_verify.o" 2>>"$BUILD/nmitally_verify.log" || ok=0
    # Prove the verify was not vacuous: the output must be a real object, not bitcode.
    "$TOOL/llvm-objdump" -h "$BUILD/nmitally_verify.o" >/dev/null 2>&1 || ok=0
  done
  if [ "$ok" -eq 1 ]; then
    echo "    PASS  $feat verify clean (slice + ROM TU, real object emitted)"
  else
    echo "    FAIL  $feat verify"; tail -20 "$BUILD/nmitally_verify.log"; rc=1
  fi
done

# 4a. MANDATORY ISR disasm gate — on the ROM object (the corpus slice has no handler).
echo "==> ISR disasm gate (the interrupt CC's prologue/epilogue on real disassembly)"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -fno-lto -c "$SRC" -o "$BUILD/nmitally_rom.o"
"$TOOL/llvm-objdump" -dr --mcpu=mosw65816 --section=.text.nmi "$BUILD/nmitally_rom.o" \
  > "$BUILD/nmitally-nmi.dis"
python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/nmitally-nmi.dis" || rc=1

# 4b. Arithmetic probes on the corpus slice — the shared logic must really be native-16 + 32-bit mul.
echo "==> arithmetic disasm probe (corpus slice)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$SLICE" -I"$ROOT/examples" -o "$BUILD/nmitally_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/nmitally_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs"
else
  echo "    FAIL  __mulsi3=$mul  rep/sep=$rs  (expected both >= 1)"; rc=1
fi

# 5. bsnes-jg — the arbiter. a16 three times (byte-identical framebuffer), plus default and xy16.
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
  echo "==> bsnes-jg: 5-way differential (default == a16 == xy16 == host $EXPECT)"
  "$JGX" "$BUILD/nmitally-default.sfc" "$VENDOR/Database" "$DVMA" 2 "$EXPECT" 700 "$BUILD/nmitally-d.png" || rc=1
  "$JGX" "$BUILD/nmitally-xy16.sfc"    "$VENDOR/Database" "$XVMA" 2 "$EXPECT" 700 "$BUILD/nmitally-x.png" || rc=1
  echo "==> bsnes-jg: +mos-a16 x3 (framebuffer must be byte-identical — the interleaving flake screen)"
  got=""
  for n in 1 2 3; do
    out="$("$JGX" "$BUILD/nmitally-a16.sfc" "$VENDOR/Database" "$AVMA" 2 "$EXPECT" 700 \
            "$BUILD/nmitally-jg$n.png" 2>/dev/null || true)"
    printf '%s\n' "$out" | grep '^SMOKE:' || true
    printf '%s\n' "$out" | grep -q '^SMOKE: PASS' || rc=1
    got="$got $(printf '%s\n' "$out" | grep -oE 'got=0x[0-9A-Fa-f]{4}' | head -1)"
  done
  # Two independent stability checks: the rendered frame AND the observed corpus_result.
  if cmp -s "$BUILD/nmitally-jg1.png" "$BUILD/nmitally-jg2.png" && \
     cmp -s "$BUILD/nmitally-jg2.png" "$BUILD/nmitally-jg3.png"; then
    echo "    PASS  bsnes-jg 3x framebuffer byte-identical"
  else
    echo "    FAIL  bsnes-jg 3x framebuffers differ"; rc=1
  fi
  if [ "$(printf '%s\n' $got | sort -u | wc -l)" -eq 1 ]; then
    echo "    PASS  bsnes-jg 3x corpus_result stable ($got )"
  else
    echo "    FAIL  bsnes-jg 3x corpus_result VARIES ($got ) — the run is not reproducible"; rc=1
  fi
  cp "$BUILD/nmitally-jg1.png" "$BUILD/nmitally-jg.png" 2>/dev/null || true
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 6. MAME under Xvfb — bonus leg; SKIPs without the SPC700 IPL.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  # Both the DEFAULT-8-bit and the +mos-a16 build are run: the default build is the CONTROL that
  # proves the interrupt CC itself works when there is no 16-bit mode state to inherit or destroy.
  mame_leg() {  # variant vma
    local variant="$1" vma="$2" addr line SNAP
    addr=$(printf '0x%X' $(( 0x7E0000 + vma )))
    SNAP="$BUILD/.nmitally-snap-$variant"; rm -rf "$SNAP"; mkdir -p "$SNAP"
    line="$(SHOT_ADDR="$addr" SHOT_WANT="$EXPECT" SHOT_AT=700 \
      xvfb-run -a mame snes -cart "$BUILD/nmitally-$variant.sfc" -rompath "$ROOT/dev/roms" \
        -autoboot_script "$ROOT/dev/nmitally.lua" -skip_gameinfo \
        -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 16 \
        -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
    echo "    $variant: $line"
    if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/nmitally-mame-$variant.png"; fi
    case "$line" in "SHOT: PASS"*) return 0 ;; *) return 1 ;; esac
  }
  echo "==> MAME (under Xvfb): snapshot + assert (build/nmitally-mame-{default,a16}.png)"
  mame_leg default "$DVMA" || rc=1
  mame_leg a16     "$AVMA" || rc=1
  cp "$BUILD/nmitally-mame-a16.png" "$BUILD/nmitally-mame.png" 2>/dev/null || true
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — NMI tally on SNES; ISR disasm gate + corpus hash $EXPECT host == default == a16 == xy16"
else
  echo "RESULT: FAIL — see the per-leg lines above"
fi
exit $rc
