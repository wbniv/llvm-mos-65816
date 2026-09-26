#!/usr/bin/env bash
# dev/farblit.sh — #321 Phase 2 inc 2 GATE: `lda [dp],y` / `sta [dp],y` with a RUNTIME index.
#
# Increment 2 (docs/plans/2026-09-25-dpy-indexed-phase2-increment2.md) folds a runtime byte offset
# into Y when known-bits prove it fits — 0..255 for an 8-bit Y, 0..65535 for a 16-bit Y
# (+mos-xy16 only) — replacing a 32-bit pointer add. examples/65816/farblit.c exercises every
# shape it selects, each one CROSSING A BANK BOUNDARY THROUGH Y so a Y that wrapped inside the bank
# would read or write the wrong byte:
#
#   rd8 / rdw8 / wr8 / cp8   8-bit Y (runtime-ptr loads incl. an 8-bit wrapping index, a WRAM store,
#                            a far -> far copy sharing one Y)
#   rd16 / rdw / rdw16 / wr16  16-bit Y under +mos-xy16 (u16 offsets, a u16 element at a u8 index,
#                            the 16-bit WRAPPING `o + j`); +mos-a16 alone keeps the pointer add.
#   rdg / rdw16g             an ABSOLUTE (global) base: declined by design (gate (d)) — correctness
#                            probes only; rdw16g is dev/dpy-shapes/loop.c's exact wrapping shape.
#
# Stores are read back through CONSTANT absolute-long addresses, never through Y.
#
# a16-only (no default leg): a far pointer is a 32-bit value, so the far access needs +mos-a16 —
# like farindex / farbank / far_*. The differential is host == +mos-a16 == +mos-a16 +mos-xy16, each
# ROM on MAME AND bsnes-jg.
#
#   1. CLEAN + FOLDED: -verify clean under both modes. +mos-a16: >= 3 b7 and >= 2 97 (the 8-bit-Y
#      folds). +mos-xy16: >= 6 b7, >= 3 97, a rep #$10 bracket, NO unindexed 87, and at most 2
#      unindexed a7 — exactly the two absolute-base probes; every runtime-base access folded.
#   2. HOST ORACLE: cc -DHOST computes the golden.
#   3-5. DIFFERENTIAL: corpus_result == golden for +mos-a16 and +mos-xy16 on MAME and bsnes-jg.
#   6. PRESSURE: examples/65816/farblit_press.c (a 16-bit-Y far load right after the spilled far base
#      is reloaded) == its host golden, +mos-a16 and +mos-xy16, on MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh farblit. Prereqs: from-source toolchain + SDK
# built WITH platforms/snes-hirom. bsnes-jg reuses build/jgxcheck.
set -euo pipefail

usage() { echo "Usage: dev/run.sh farblit   # [dp],y (b7/97) with a RUNTIME index (8-bit Y, and 16-bit Y under +mos-xy16), loads + stores crossing banks; host==+mos-a16==+mos-xy16 (MAME+bsnes-jg)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/farblit.c"
LUTASM="$BUILD/farblit_tbl.s"   # own path: farindex/farbank generate the same table; don't race them
HOSTBIN="$BUILD/farblit_host"
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)
HIROMCFG="$INSTALL/bin/mos-snes-hirom.cfg"
export SMOKE_SETTLE="${SMOKE_SETTLE:-120}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-4}"
JG_FRAMES="${JG_FRAMES:-240}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$HIROMCFG" ] || { echo "FATAL: snes-hirom platform not built (rebuild SDK: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }
[ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ] || {
  echo "FATAL: both emulators are required (run dev/run.sh xcheck first)"; exit 1;
}

rc=0

echo "==> 0) generate the far table asm (tbl[i] = (i + (i>>16)) & 0xFFFF, 3 banks \$C1..\$C3)"
python3 "$ROOT/tools/gen-farindex-lut-asm.py" "$LUTASM"

# count <disasm> <opcode-byte>
count() { grep -ciE "^\s*[0-9a-f]+:\s*$2\b" <<< "$1" || true; }

echo "==> 1) -verify clean + the runtime-index fold fired"
for mode in a16 xy16; do
  flags=("${A16[@]}"); [ "$mode" = xy16 ] && flags+=("${XY16[@]}")
  obj="$BUILD/farblit_$mode.o"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${flags[@]}" -Os -mllvm -verify-machineinstrs \
    -c -o "$obj" "$SRC" 2>"$BUILD/farblit_$mode.vlog" \
    || { echo "  FAIL[$mode]: verify-machineinstrs"; grep -iE "error|Bad machine" "$BUILD/farblit_$mode.vlog" | head -3; rc=1; continue; }
  DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$obj")"
  nb7="$(count "$DIS" b7)"; n97="$(count "$DIS" 97)"; na7="$(count "$DIS" a7)"; n87="$(count "$DIS" 87)"
  nrep10="$(grep -ciE '^\s*[0-9a-f]+:\s*c2 10\b' <<< "$DIS" || true)"
  echo "  [$mode] b7=$nb7 97=$n97 a7=$na7 87=$n87 rep#\$10=$nrep10"
  if [ "$mode" = a16 ]; then
    [ "$nb7" -ge 3 ] && [ "$n97" -ge 2 ] \
      && echo "  PASS[a16]: 8-bit-Y runtime folds present (rd8/rdw8/cp8 loads, wr8/cp8 stores)" \
      || { echo "  FAIL[a16]: want >= 3 b7 and >= 2 97"; rc=1; }
  else
    [ "$nb7" -ge 6 ] && [ "$n97" -ge 3 ] && [ "$na7" -le 2 ] && [ "$n87" -eq 0 ] && [ "$nrep10" -ge 1 ] \
      && echo "  PASS[xy16]: every runtime-base far access folded (16-bit Y via rep #\$10); a7 only on the 2 absolute-base probes" \
      || { echo "  FAIL[xy16]: want >= 6 b7, >= 3 97, <= 2 a7, 0 87, a rep #\$10"; rc=1; }
  fi
done

echo "==> 2) host oracle"
command -v cc >/dev/null 2>&1 || { echo "  FAIL: no host cc (the golden comes from the host oracle)"; exit 1; }
cc -DHOST -O2 -o "$HOSTBIN" "$SRC"
WANT="$("$HOSTBIN")"
echo "  host oracle corpus_result=$WANT"

source "$ROOT/dev/_emu.sh"
require_bios || exit $?
for mode in a16 xy16; do
  flags=("${A16[@]}"); [ "$mode" = xy16 ] && flags+=("${XY16[@]}")
  rom="$BUILD/farblit_$mode.sfc"; map="$BUILD/farblit_$mode.map"
  echo "==> 3) [$mode] build the HiROM ROM (far table) + checksum"
  "$TOOL/mos-clang" --config "$HIROMCFG" -mcpu=mosw65816 "${flags[@]}" -Os \
    -Wl,-Map="$map" -o "$rom" "$SRC" "$LUTASM"
  python3 "$ROOT/tools/snes-checksum.py" --hirom "$rom" >/dev/null
  echo "==> 4) [$mode] MAME: corpus_result == $WANT"
  run_assert "$rom" "$map" corpus_result "$WANT" || rc=1
  if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
    echo "==> 5) [$mode] bsnes-jg: corpus_result == $WANT (independent confirmation)"
    read -r vma size < <(_emu_map_lookup "$map" corpus_result) || true
    len=$((0x$size)); [ "$len" -ge 1 ] || len=1
    if line="$("$BUILD/jgxcheck" "$rom" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" "$JG_FRAMES" 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
  else
    echo "==> 5) [$mode] bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
  fi
done

# 6. The 16-bit-Y fold under REGISTER PRESSURE (examples/65816/farblit_press.c). A runtime far
#    base is spilled across a call in every iteration and reloaded right before a 16-bit-Y far load.
#    With the index loaded into Y by a SEPARATE instruction, register allocation could put that
#    reload between the `ldy` and the `lda [dp],y`, and MOSInsertREPSEP's `sep #$10` for it zeroes
#    Y's high byte. The fused LDIndirLongYIdx keeps the pair
#    adjacent; this leg is the runtime regression guard. host == +mos-a16 == +mos-xy16.
PSRC="$ROOT/examples/65816/farblit_press.c"
cc -DHOST -O2 -o "$BUILD/farblit_press_host" "$PSRC"
PWANT="$("$BUILD/farblit_press_host")"
echo "==> 6) [press] 16-bit-Y far load under register pressure: host golden = $PWANT"
for mode in a16 xy16; do
  flags=("${A16[@]}"); [ "$mode" = xy16 ] && flags+=("${XY16[@]}")
  prom="$BUILD/farblit_press_$mode.sfc"; pmap="$BUILD/farblit_press_$mode.map"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${flags[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$pmap" -o "$prom" "$PSRC"
  python3 "$ROOT/tools/snes-checksum.py" "$prom" >/dev/null
  if [ "$mode" = xy16 ]; then
    pdis="$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${flags[@]}" -Os -c -o - "$PSRC" \
            | "$TOOL/llvm-objdump" -d --mcpu=mosw65816 -)"
    pb7="$(count "$pdis" b7)"; p97="$(count "$pdis" 97)"
    [ "$pb7" -ge 1 ] && [ "$p97" -ge 1 ] \
      && echo "  PASS[xy16]: the 16-bit-Y fold fired (b7=$pb7 in sample, 97=$p97 in fill)" \
      || { echo "  FAIL[xy16]: expected the 16-bit-Y fold (b7=$pb7, 97=$p97)"; rc=1; }
  fi
  echo "  [$mode] MAME:"
  SMOKE_SETTLE=600 SMOKE_SECONDS=15 run_assert "$prom" "$pmap" corpus_result "$PWANT" || rc=1
  if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
    pvma=$(awk '$NF=="corpus_result"{print $1; exit}' "$pmap")
    if line="$("$BUILD/jgxcheck" "$prom" "$ROOT/vendor/bsnes-jg/Database" "0x$pvma" 2 "$PWANT" 900 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
  fi
done

echo
emu_verdict "$rc" "runtime-indexed far loads/stores via [dp],y (8-bit Y, and 16-bit Y under +mos-xy16) crossing banks fold to $WANT, and under register pressure to $PWANT; host == +mos-a16 == +mos-xy16 (both emulators)"
exit $rc
