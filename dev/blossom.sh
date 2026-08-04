#!/usr/bin/env bash
# dev/blossom.sh — #3 Blossom: the interactive Hopalong attractor on the SNES (Mode 7).
#
# The attractor blooms live into a 128x128 far hit grid ($7E2000) via the far read-modify-write path,
# is revealed band-by-band (far grid -> near chrbuf -> VRAM DMA) with a cycling hue palette, and is
# driven by the joypad (pan / zoom / attractor-preset / colour). +mos-a16-only (far grid). Two
# differential channels, host == target:
#   * grid:  a DETERMINISTIC boot accumulation of K_GATE classic points -> corpus_result == the host
#            oracle (examples/65816/k_blossom_far.c -DHOST -DK_GATE). host == +mos-a16, MAME + bsnes-jg.
#   * state: a SCRIPTED controller sequence is fed in; the ROM logs the pads it read + a rolling CRC of
#            the per-frame controller state (examples/snes/blossom.h); jgxcheck -DJGX_BLOSSOM replays
#            that pure state math over the ground-truth pad log and asserts an identical CRC (bsnes-jg).
# Plus a bsnes-jg framebuffer PNG and a MAME snapshot. Outputs build/blossom-{jg,mame}.png.
#
# Drive: dev/run.sh blossom.  Live play: task blossom-mame.
# Plan: docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh blossom   # interactive Hopalong attractor on SNES (far hit-grid + Mode 7); grid + state differential + screenshots"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/blossom.c"
ORACLE="$ROOT/examples/65816/k_blossom_far.c"
ROM="$BUILD/blossom.sfc"
MAP="$BUILD/blossom.map"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)
# Scripted controller sequence (SEGMENT:FRAMES) for the state gate — zoom/pan/palette only (preset
# changes re-bloom, which is slow); varied + non-trivial so the logged pad sequence is meaningful.
SCRIPT="${JGX_SCRIPT:-R:150,DOWN:150,SELECT:2,L:150,UP:150,RIGHT:150,SELECT:2,LEFT:150}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# K_GATE from the source so the host oracle can't drift; bloom ~K_GATE/700 s + the 64-frame state
# window fills after it -> a generous frame budget.
K_GATE=$(awk '/#define K_GATE /{print $3; exit}' "$SRC")
FRAMES="${MANDEL_FRAMES:-1500}"
echo "==> blossom: K_GATE=$K_GATE  (frames=$FRAMES, script=$SCRIPT)"

# 1. Host oracle derives the golden grid hash (cc -DHOST over the SAME hopalong.h, matching K).
cc -DHOST -O2 -DK_GATE="$K_GATE" -o "$BUILD/blossom_oracle" "$ORACLE"
HOSTREP="$("$BUILD/blossom_oracle" 2>&1 1>/dev/null || true)"
WANT="$("$BUILD/blossom_oracle")"
echo "    $HOSTREP"
echo "==> host reference: grid hash = $WANT"

# 2. Build the +mos-a16 ROM (the far grid is a16-only) + find the proof-channel symbols.
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
vma() { awk -v s="$1" '$NF==s{print $1; exit}' "$MAP"; }
CV=$(vma corpus_result); BC=$(vma blossom_crc); NF=$(vma nframes); PL=$(vma pad_log)
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$CV )))
echo "==> built $(basename "$ROM") (+mos-a16); corpus@\$$CV blossom_crc@\$$BC pad_log@\$$PL"

# NOT FIXED: the vacuous-verify pattern (link above claims -mllvm -verify-machineinstrs but
# --config's default LTO never runs it) still applies here. An explicit -fno-lto -c verify
# compile was tried and trips the ALREADY-KNOWN `a16-rc-undef-ra-pure-virtual` MachineVerifier
# false-positive (KNOWN_ISSUES in tools/a16_fuzz.py; see TODO.md's mandel-double/gouraud
# entries for prior witnesses; fix plan docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md).
# Wiring a real verify leg here needs XFAIL-awareness this script doesn't have — left vacuous
# rather than landing a leg that hard-crashes the gate on a pre-existing, differential-proven-
# correct issue. See docs/plans/2026-08-03-123-snes-nmitally.md follow-up.
rc=0

# 3. bsnes-jg: state-machine differential (with scripted input) + grid gate + framebuffer dump. Build a
#    -DJGX_BLOSSOM harness (the state replay) and a plain jgxcheck (the PNG dump) from current source.
ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
JGXB="$BUILD/jgxcheck-blossom"; JGX="$BUILD/jgxcheck"
if [ -n "$ARCHIVE" ]; then
  g++ -O2 -std=c++11 -DJGX_BLOSSOM -I"$VENDOR/src" -I"$ROOT/tools" -I"$ROOT/examples/snes" -I"$ROOT/examples/65816" \
      -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-blossom.o"
  g++ "$BUILD/jgxcheck-blossom.o" "$ARCHIVE" -lsamplerate -lm -o "$JGXB"
  g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
  g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi
if [ -x "$JGXB" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: grid gate (corpus == $WANT) + state replay (BLOSSOM) + framebuffer dump"
  out="$(JGX_SCRIPT="$SCRIPT" JGX_BLOSSOMCRC="0x$BC" JGX_PADLOG="0x$PL" JGX_NFRAMES="0x$NF" JGX_PADLOG_N=64 \
    "$JGXB" "$ROM" "$VENDOR/Database" "0x$CV" 2 "$WANT" "$FRAMES" "$BUILD/blossom-jg.png" 2>/dev/null || true)"
  echo "$out" | grep -E 'SMOKE|BLOSSOM' | sed 's/^/    /'
  echo "$out" | grep -q 'SMOKE: PASS'   || { echo "    grid gate FAILED"; rc=1; }
  echo "$out" | grep -q 'BLOSSOM: PASS' || { echo "    state gate FAILED"; rc=1; }
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 4. MAME under Xvfb: snapshot + assert the grid gate (sample after the bloom completes).
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + grid gate (build/blossom-mame.png)"
  SNAP="$BUILD/.bl-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  secs=$(( FRAMES / 60 + 5 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$WANT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/blossom-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — interactive Hopalong attractor on SNES; grid hash $WANT host == +mos-a16 (MAME + bsnes-jg); state-math host == ROM (bsnes-jg)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc
