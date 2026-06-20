#!/usr/bin/env bash
# dev/xcheck.sh — #320 second-emulator fidelity cross-check (ROADMAP step 3).
#
# Boots the far-pointer ROMs in bsnes-jg (cycle-accurate, independent of MAME)
# HEADLESS and asserts the same WRAM bytes MAME does — so the Increment-2b
# bank-$01 far read (`lda $018000`) is confirmed by a second, independent
# emulator, not just MAME. bsnes-jg's C++ API exposes WRAM directly
# (Bsnes::getMemoryRaw(MainRAM)), so the harness (dev/jgxcheck.cpp) reads
# corpus_result exactly like MAME's Lua read — no SDL, no X, no save-state.
#
# (Mesen2 was abandoned: its prebuilt crashes on the 26.04 glibc-2.43 base and
# its headless --testrunner won't run Lua. See the plan's Pivot section.)
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh xcheck.
# Prereqs: the from-source toolchain (dev/run.sh toolchain) + the SDK incl. the
# snes-far platform (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build).
# To rebuild the harness after editing dev/jgxcheck.cpp or bumping bsnes-jg:
# rm build/jgxcheck.
# See docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xcheck   # cross-check the far ROMs on bsnes-jg vs MAME"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
JGX="$BUILD/jgxcheck"
VENDOR="$ROOT/vendor/bsnes-jg"
BSNES_VER=2.1.0
BSNES_SHA=a8e0fd36711406198afe1110ddc6960c9d795f4ab73d0badd8878396ac3d0c42

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: SDK/snes-far not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Fetch (pinned) + build the bsnes-jg core + the jgxcheck harness (cached).
if [ ! -x "$JGX" ]; then
  if [ ! -d "$VENDOR/src" ]; then
    echo "==> fetch bsnes-jg $BSNES_VER (pinned) into vendor/ (gitignored)"
    mkdir -p "$VENDOR"
    curl -fsSL "https://gitlab.com/jgemu/bsnes/-/archive/$BSNES_VER/bsnes-$BSNES_VER.tar.gz" -o /tmp/bsnes-jg.tgz
    echo "$BSNES_SHA  /tmp/bsnes-jg.tgz" | sha256sum -c -
    tar xzf /tmp/bsnes-jg.tgz -C "$VENDOR" --strip-components=1
  fi
  echo "==> build bsnes-jg core (ENABLE_STATIC, no SDL/jg.h) + jgxcheck harness"
  ( cd "$VENDOR" && make ENABLE_STATIC=1 DISABLE_MODULE=1 -j"$(nproc)" >/dev/null )
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' | head -1)"
  [ -n "$ARCHIVE" ] || { echo "FATAL: bsnes-jg core archive not produced"; exit 1; }
  g++ -O2 -std=c++11 -I"$VENDOR/src" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
  g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi
DB="$VENDOR/Database"

# 2. Build-if-missing the far ROMs (so the target is self-contained).
build_rom() { # name cfg [extra-clang-flags...]
  local name="$1" cfg="$2"; shift 2
  [ -f "$BUILD/$name.sfc" ] && [ -f "$BUILD/$name.map" ] && return 0
  echo "==> build $name.sfc ($cfg -mcpu=mosw65816 $*)"
  "$TOOL/mos-clang" --config "$INSTALL/bin/$cfg" -mcpu=mosw65816 -Os "$@" \
    -Wl,-Map="$BUILD/$name.map" -o "$BUILD/$name.sfc" "$ROOT/examples/65816/$name.c"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$name.sfc" >/dev/null
}
build_rom far-run   mos-snes.cfg
build_rom far-bank1 mos-snes-far.cfg
# #320 Increment 3: runtime far deref needs +mos-a16 (32-bit value legalization).
build_rom far_indir mos-snes-far.cfg -Xclang -target-feature -Xclang +mos-a16
build_rom far_cast  mos-snes.cfg     -Xclang -target-feature -Xclang +mos-a16
build_rom far_arith mos-snes.cfg     -Xclang -target-feature -Xclang +mos-a16
build_rom far_store mos-snes.cfg     -Xclang -target-feature -Xclang +mos-a16
build_rom far_call  mos-snes-far.cfg
# #320 Inc 4 Ph2 (A0): far-ptr CC variant (a) — needs +mos-a16 (32-bit value) AND
# +mos-farcc-imag32 (the far-ptr-across-call CC rule).
build_rom farcc_imag32 mos-snes-far.cfg -Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-farcc-imag32
# #320 Inc 4 Ph2 (A1+): far-ptr CC variants (b)/(c)/(d) all build the SHARED round-trip
# source (farcc_imag32.c) with different +mos-farcc-* flags; build_rom keys on $name.c,
# so build these explicitly from the shared source.
build_farcc_variant() { # rom-name farcc-flag
  local name="$1" flag="$2"
  [ -f "$BUILD/$name.sfc" ] && [ -f "$BUILD/$name.map" ] && return 0
  echo "==> build $name.sfc (mos-snes-far.cfg +mos-a16 $flag, source farcc_imag32.c)"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 -Os \
    -Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang "$flag" \
    -Wl,-Map="$BUILD/$name.map" -o "$BUILD/$name.sfc" "$ROOT/examples/65816/farcc_imag32.c"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$name.sfc" >/dev/null
}
build_farcc_variant farcc_split +mos-farcc-split
build_farcc_variant farcc_axy   +mos-farcc-axy

# 3. Cross-check each ROM on bsnes-jg. Offset/len derived from the .map exactly
# like the MAME path (dev/_emu.sh's _emu_map_lookup) — WRAM offset == symbol VMA.
source "$ROOT/dev/_emu.sh"
rc=0
xassert() { # rom map symbol want
  local rom="$1" map="$2" sym="$3" want="$4" vma size len line
  [ -f "$rom" ] && [ -f "$map" ] || { echo "  SKIP $(basename "$rom") (not built — run dev/run.sh build/far-run/far-bank1)"; return 0; }
  read -r vma size < <(_emu_map_lookup "$map" "$sym") || true
  [ -n "${vma:-}" ] || { echo "  FAIL $(basename "$rom"): symbol '$sym' not in map"; rc=1; return 0; }
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$JGX" "$rom" "$DB" "0x$vma" "$len" "$want" 180 2>&1)"; then
    echo "  PASS  $(basename "$rom"): $line"
  else
    echo "  FAIL  $(basename "$rom"): $line"; rc=1
  fi
}

echo "==> bsnes-jg cross-check (independent of MAME)"
xassert "$BUILD/hello.sfc"     "$BUILD/hello.map"     sentinel      0x42   # liveness (from dev/run.sh build)
xassert "$BUILD/far-run.sfc"   "$BUILD/far-run.map"   corpus_result 0xF3   # bank $00
xassert "$BUILD/far-bank1.sfc" "$BUILD/far-bank1.map" corpus_result 0xF3   # bank $01 (the fidelity point)
xassert "$BUILD/far_indir.sfc" "$BUILD/far_indir.map" corpus_result 0xF3   # bank $01, RUNTIME far ptr via lda [dp]
xassert "$BUILD/far_cast.sfc"  "$BUILD/far_cast.map"  corpus_result 0xF3   # bank $00, near->far cast then lda [dp]
xassert "$BUILD/far_arith.sfc" "$BUILD/far_arith.map" corpus_result 0xF3   # bank $00, fp++ (G_PTR_ADD) then lda [dp]
xassert "$BUILD/far_store.sfc" "$BUILD/far_store.map" corpus_result 0xF3   # bank $00, sta [dp] store then near read-back
xassert "$BUILD/far_call.sfc"  "$BUILD/far_call.map"  corpus_result 0xF3   # bank $01, far call (JSL) + RTL return
xassert "$BUILD/farcc_imag32.sfc" "$BUILD/farcc_imag32.map" corpus_result 0xF3 # bank $01, far PTR returned+passed across calls (variant a Imag32/RL)
xassert "$BUILD/farcc_split.sfc"  "$BUILD/farcc_split.map"  corpus_result 0xF3 # bank $01, far PTR split offset(RS#)+bank(RC#) across calls (variant b)
xassert "$BUILD/farcc_axy.sfc"    "$BUILD/farcc_axy.map"    corpus_result 0xF3 # bank $01, far PTR in A:X(offset)+Y(bank) across calls (variant c)

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)" \
             || echo "RESULT: FAIL"
exit $rc
