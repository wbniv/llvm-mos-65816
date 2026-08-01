#!/usr/bin/env bash
# dev/cartsize-canary.sh — the cartridge-size / mapper gate.
#
# Builds one canary ROM per milestone cartridge configuration and proves each one
# BOOTS and reads the right byte from every decoded window:
#
#   HiROM   4 MiB   ordinary map baseline: 64 KiB linear banks, header at file $00FFB0
#   ExHiROM 6 MiB   48 Mbit, physically 32 Mbit + 16 Mbit, header at file $40FFB0
#   ExHiROM 8 MiB   64 Mbit single device, incl. the WRAM-capped $3E/$3F tail windows
#
# Every address, segment list and expected value is generated from
# tools/snes_cartmap.py (the authoritative model) by tools/snes-cartcanary.py —
# nothing here restates the mapping.
#
#   1. HOST MODEL      the pure-host unit tests (no toolchain, no emulator).
#   2. LAYOUT+LINK     generate the per-size platform + descriptor header, link,
#                      fill the deterministic pattern, patch header/checksum.
#   3. STRUCTURAL      snes-checksum.py --inspect: exact length, physical
#                      decomposition, header only at the mapping's location, map
#                      mode, vectors into linked code, checksum/complement.
#   4. DISASM          the far reads really are 24-bit (`lda [dp]`, R_MOS_ADDR24).
#   5. MAME            corpus_result == the generated oracle, canary_status == 0.
#   6. bsnes-jg        the same two assertions, independently.
#
# a16-only (no default 8-bit leg): a runtime far pointer is a 32-bit value, so
# the far cursor needs +mos-a16 — exactly like every other far_* test here. The
# differential is host-model == +mos-a16 on MAME + bsnes-jg.
#
# JG_ONLY=1 skips the MAME leg (bsnes-jg needs no SPC700 IPL); see dev/_emu.sh.
# CANARY_ONLY=<tag> restricts the run to one configuration (hirom4/exhirom6/exhirom8).
#
# Runs INSIDE the dev container; drive: dev/run.sh cartsize-canary.
# Plan: docs/plans/2026-07-30-exhirom-video-boundary-test.md (Phase 0 + Phase 1).
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh cartsize-canary   # HiROM 4 MiB + ExHiROM 6/8 MiB canary ROMs: every decoded window, mirror and cross-bank/cross-device span reads the modelled byte (MAME + bsnes-jg)"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/cartsize-canary.c"
GEN="$BUILD/cartsize-gen"
A16=(-Xclang -target-feature -Xclang +mos-a16)
JG_FRAMES="${JG_FRAMES:-1800}"  # comfortably past the ~500-frame canary work; the
                                # 900-frame default used to capture the exact
                                # frame the verdict appeared
export SMOKE_SETTLE="${SMOKE_SETTLE:-600}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-14}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: dev/run.sh build)"; exit 1; }

mkdir -p "$GEN"
rc=0

echo "==> 1) host model + tooling unit tests"
python3 "$ROOT/test/snes/cartridge-maps/test_snes_cartmap.py" >"$GEN/model.log" 2>&1 \
  && echo "  PASS: $(grep -c '\.\.\. ok' "$GEN/model.log" || true) address-model tests" \
  || { echo "  FAIL: address-model tests"; tail -25 "$GEN/model.log"; rc=1; }
python3 "$ROOT/test/snes/cartridge-maps/test_snes_checksum.py" >"$GEN/checksum.log" 2>&1 \
  && echo "  PASS: $(grep -c '\.\.\. ok' "$GEN/checksum.log" || true) header/checksum fixture tests" \
  || { echo "  FAIL: header/checksum fixtures"; tail -25 "$GEN/checksum.log"; rc=1; }

source "$ROOT/dev/_emu.sh"
require_bios || bios_rc=$?
if [ "${bios_rc:-0}" -ne 0 ]; then
  echo "  NOTE: MAME leg unavailable (no SPC700 IPL) — continuing with the bsnes-jg leg only."
  export JG_ONLY=1
  require_bios
fi

# tag  mapping  size  platform-name
CONFIGS="hirom4:hirom:4M exhirom6:exhirom:6M exhirom8:exhirom:8M"
for entry in $CONFIGS; do
  tag="${entry%%:*}"; rest="${entry#*:}"; mapping="${rest%%:*}"; size="${rest##*:}"
  [ -z "${CANARY_ONLY:-}" ] || [ "${CANARY_ONLY}" = "$tag" ] || continue

  ROM="$BUILD/cartsize-$tag.sfc"; MAP="$BUILD/cartsize-$tag.map"
  HDR="$GEN/cartsize-canary-data.h"; OBJ="$GEN/cartsize-$tag.o"
  PLAT="snes-cart-$tag"; CFG="$INSTALL/bin/mos-$PLAT.cfg"

  echo
  echo "######## $tag — $mapping $size ########"

  echo "==> 2) generate the platform layout + descriptor header, link, fill, checksum"
  python3 "$ROOT/tools/snes-cartcanary.py" emit-platform \
    --mapping "$mapping" --size "$size" --name "$PLAT" --install "$INSTALL"
  python3 "$ROOT/tools/snes-cartcanary.py" emit-header \
    --mapping "$mapping" --size "$size" --out "$HDR" --label "$tag $mapping $size"

  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os \
    -I "$GEN" -I "$ROOT/examples/snes" \
    -Wl,-Map="$MAP" -o "$ROM" "$SRC" || { echo "  FAIL: link"; rc=1; continue; }
  actual=$(stat -c%s "$ROM")
  echo "  linked $ROM: $actual bytes"

  python3 "$ROOT/tools/snes-cartcanary.py" fill --mapping "$mapping" --size "$size" \
    --rom "$ROM" --json "$GEN/$tag.json" || { echo "  FAIL: fill"; rc=1; continue; }
  python3 "$ROOT/tools/snes-checksum.py" --mapping "$mapping" "$ROM"

  echo "==> 3) structural inspection"
  if python3 "$ROOT/tools/snes-checksum.py" --inspect --mapping "$mapping" "$ROM" >"$GEN/$tag-inspect.log" 2>&1; then
    echo "  PASS: $(grep -E '^(file length|physical devices|header at file|map mode byte)' "$GEN/$tag-inspect.log" | tr -s ' ' | paste -sd'; ')"
  else
    echo "  FAIL: structural inspection"; cat "$GEN/$tag-inspect.log"; rc=1
  fi

  echo "==> 4) disasm: the far cursor is a real 24-bit indirect-long read"
  # --config (not a bare --target) so <snes.h> resolves from the platform include
  # path; -fno-lto because mos-common.cfg turns LTO on, and `-c` under LTO emits
  # LLVM bitcode that llvm-objdump cannot disassemble.
  if "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto -mllvm -verify-machineinstrs \
       -I "$GEN" -I "$ROOT/examples/snes" -c -o "$OBJ" "$SRC" 2>"$GEN/$tag-verify.log"; then
    echo "  PASS: -verify-machineinstrs clean"
    if DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ" 2>/dev/null)"; then
      grep -qiE '^\s*[0-9a-f]+:\s*a7\b' <<< "$DIS" \
        && echo "  PASS: far load (lda [dp], a7) present" \
        || { echo "  FAIL: no indirect-long far load"; rc=1; }
    else
      echo "  FAIL: llvm-objdump could not read $OBJ"; rc=1
    fi
  else
    echo "  FAIL: -verify-machineinstrs"
    grep -iE 'error|Bad machine' "$GEN/$tag-verify.log" | head -3
    rc=1
  fi

  WANT=0x$(python3 -c "
import re,sys
m=re.search(r'#define CANARY_ORACLE 0x([0-9A-F]+)u', open('$HDR').read())
print(m.group(1))")
  echo "  generated oracle: $WANT"

  echo "==> 5) MAME: corpus_result == $WANT and canary_status == 0x0000"
  run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1
  run_assert "$ROM" "$MAP" canary_status 0x0000 || rc=1

  if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
    echo "==> 6) bsnes-jg: the same two assertions, independently"
    for sym_want in "corpus_result:$WANT" "canary_status:0x0000"; do
      sym="${sym_want%%:*}"; want="${sym_want##*:}"
      read -r vma size2 < <(_emu_map_lookup "$MAP" "$sym") || true
      if [ -z "${vma:-}" ]; then echo "  FAIL: $sym not in the map"; rc=1; continue; fi
      len=$((0x$size2)); [ "$len" -ge 1 ] || len=1
      # The corpus_result pass also dumps the framebuffer: the ROM prints its own
      # verdict on screen, so the PNG is both the publication preview and a
      # second, human-readable witness that the WRAM value is not a fluke.
      png=""; [ "$sym" = "corpus_result" ] && png="$BUILD/cartsize-$tag.png"
      if line="$(JGX_ENTROPY=0 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$want" "$JG_FRAMES" ${png:+"$png"} 2>&1)"; then
        echo "  $sym: $line"
        [ -n "$png" ] && [ -f "$png" ] && echo "  screenshot: $png"
      else
        echo "  $sym: $line"; rc=1
      fi
    done

    # 6b) THE PICTURE MUST NOT DEPEND ON POWER-ON STATE.
    #
    # bsnes-jg reseeds from clock() at every power-on (settings.hpp entropy
    # defaults to 1 = Low) and fills the PPU control registers the ROM never
    # wrote with noise -- BG/OBJ enables, mosaic, window masks, colour math. A
    # ROM that inherits any of them renders a different picture every single
    # boot while its computed WRAM result stays perfectly deterministic, so the
    # assertions above cannot see it. That is exactly how the unstable backdrop
    # got mistaken for a jgxcheck capture artifact
    # (docs/plans/2026-08-01-cartsize-canary-display-nondeterminism.md).
    #
    # So: fingerprint the picture across None/Low/High, twice each at the SAME
    # frame count. All six must be the one hash. This fails on any register the
    # ROM depends on but does not set, and it does not care which random value
    # happened to come up. Repeats matter -- a single Low run agrees with None
    # by luck often enough to be useless as evidence.
    echo "==> 6b) picture is independent of power-on entropy (None/Low/High x2)"
    fps=""
    for ent in 0 0 1 1 2 2; do
      fp="$(JGX_ENTROPY=$ent JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=0 \
            "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" 0x0 1 0x00 "$JG_FRAMES" 2>/dev/null \
            | sed -n 's/.*final hash=\([0-9A-F]*\) dom=#\([0-9A-F]*\).*/\1:#\2/p')"
      fps="$fps $ent=${fp:-NONE}"
    done
    uniq_n=$(printf '%s\n' $fps | sed 's/^[0-9]*=//' | sort -u | wc -l)
    if printf '%s\n' $fps | grep -q '=NONE$'; then
      # An older jgxcheck ignores JGX_FRAMESCAN and prints nothing, which would make all six
      # "agree" on the empty string and pass this guard vacuously. Say so instead.
      echo "  FAIL: jgxcheck printed no FRAMESCAN line -- rebuild it (dev/run.sh xcheck)"
      rc=1
    elif [ "$uniq_n" = 1 ]; then
      echo "  PASS: one picture across all six boots ($(printf '%s\n' $fps | head -1 | sed 's/^[0-9]*=//'))"
    else
      echo "  FAIL: $uniq_n distinct pictures across six boots -- the ROM inherits PPU state it"
      echo "        never sets. Call snes_ppu_reset_blank() before touching the screen."
      for f in $fps; do echo "          entropy $f"; done
      rc=1
    fi
  else
    echo "==> 6) bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
  fi

  sha=$(sha256sum "$ROM" | cut -c1-64)
  echo "  ROM SHA-256: $sha"
done

echo
emu_verdict "$rc" "every decoded window, accepted mirror and cross-bank/cross-device span of the HiROM 4 MiB and ExHiROM 6/8 MiB canary cartridges reads the modelled byte, both emulators agree"
exit $rc
