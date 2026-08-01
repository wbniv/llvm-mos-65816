#!/usr/bin/env bash
# Build and verify demo #119: the on-SNES LZSS compression/decompression gallery benchmark.
set -euo pipefail

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes-gallery.cfg"
SRC="$ROOT/examples/snes/lzss-gallery.c"
ROM="$BUILD/lzss-gallery.sfc"
MAP="$BUILD/lzss-gallery.map"
EXPECT=$(python3 -c 'import json
r=json.load(open("/work/assets/snes/lzss-gallery/derived/report.json"));h=0xffff
for a in r:
  for x in (a["checksum"]&255,a["checksum"]>>8,a["compressed_bytes"]&255,a["compressed_bytes"]>>8):
    h=(((h<<1)|(h>>15))&65535)^x
print(f"0x{h:04X}")')
WORKS=$(python3 -c 'import json; print(len(json.load(open("/work/assets/snes/lzss-gallery/derived/report.json"))))')

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: missing toolchain; run dev/run.sh build"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: missing snes-gallery SDK platform; run dev/run.sh build"; exit 1; }

echo "==> host codec oracle (-O0 and -O2)"
for opt in 0 2; do
  cc "-O$opt" -I"$ROOT/examples/65816" "$ROOT/tools/lzss-gallery-sim.c" \
    -o "$BUILD/lzss-gallery-sim-O$opt"
  : >"$BUILD/lzss-gallery-host-O$opt.txt"
  for frame in "$ROOT"/assets/snes/lzss-gallery/derived/*.idx; do
    printf '%s ' "$(basename "$frame")" >>"$BUILD/lzss-gallery-host-O$opt.txt"
    "$BUILD/lzss-gallery-sim-O$opt" "$frame" >>"$BUILD/lzss-gallery-host-O$opt.txt"
  done
done
cmp "$BUILD/lzss-gallery-host-O0.txt" "$BUILD/lzss-gallery-host-O2.txt"
cat "$BUILD/lzss-gallery-host-O2.txt"

echo "==> target build (+mos-a16, 1 MiB LoROM)"
EXTRA_DEFS=()
if [ -n "${GALLERY_RUN_COLOR:-}" ]; then
  EXTRA_DEFS+=("-DGALLERY_RUN_COLOR=$GALLERY_RUN_COLOR")
fi
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Oz \
  -DGALLERY_START="${GALLERY_START:-0}" \
  "${EXTRA_DEFS[@]}" \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"
[ "$(stat -c %s "$ROM")" = 1048576 ]
# The MOS assembler currently neither diagnoses a resolved wrapped PCRel8
# fixup nor tracks 65816 M width through REP/SEP. Fail this build if the NMI's
# deliberately safe branch-over-JMP or explicit ADC #$0010 encoding regresses.
NMI_VMA=$(awk '$NF=="nmi"{print $1; exit}' "$MAP")
python3 - "$ROM" "$NMI_VMA" <<'PY'
from pathlib import Path
import sys
rom = Path(sys.argv[1]).read_bytes()
start = int(sys.argv[2], 16) & 0x7fff
nmi = rom[start:start + 0x400]
required = {
    "branch-over-JMP": bytes.fromhex("d0 03 4c"),
    "16-bit ADC #$0010": bytes.fromhex("69 10 00"),
}
missing = [name for name, opcode in required.items() if opcode not in nmi]
if missing:
    raise SystemExit("FATAL: NMI opcode audit failed: missing " + ", ".join(missing))
if bytes.fromhex("f0 a2") in nmi:
    raise SystemExit("FATAL: NMI opcode audit found the formerly wrapped BEQ")
print("NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)")
PY

# decode_bank7e must set DB=$7E WITHOUT touching the accumulator.  The MOS
# convention passes decode_near's `slen` in A:X, so the natural
# `lda #$7e / pha / plb` idiom silently truncated every stream whose
# (lz_len & 0xFF) > $7E to (lz_len & 0xFF00) | $7E -- 29 of the 62 works, each
# leaving the tail of FB_A un-decoded and failing its own repack self-check.
# Assert the A-safe PEA/PLB form is what shipped.
BANK7E_VMA=$(awk '$NF=="decode_bank7e"{print $1; exit}' "$MAP")
[ -n "$BANK7E_VMA" ]
python3 - "$ROM" "$BANK7E_VMA" <<'PY'
from pathlib import Path
import sys
rom = Path(sys.argv[1]).read_bytes()
start = int(sys.argv[2], 16) & 0x7fff
# The thunk is a dozen bytes; 32 covers it without running into the callee.
thunk = rom[start:start + 32]
end = thunk.find(b"\x60")            # first RTS terminates the thunk
if end < 0:
    raise SystemExit("FATAL: decode_bank7e audit: no RTS found")
thunk = thunk[:end + 1]
if bytes.fromhex("f4 7e 7e") not in thunk:
    raise SystemExit(f"FATAL: decode_bank7e must use PEA $7E7E; got {thunk.hex(' ')}")
if b"\xa9" in thunk:
    raise SystemExit(
        "FATAL: decode_bank7e contains LDA #imm -- it clobbers the A-passed "
        f"`slen` argument; got {thunk.hex(' ')}")
print(f"decode_bank7e ABI audit: PASS (A-safe PEA/PLB; {thunk.hex(' ')})")
PY

python3 "$ROOT/tools/snes-rom-map.py" "$MAP" \
  "$ROOT/assets/snes/lzss-gallery/derived/report.json" \
  "$ROOT/assets/snes/lzss-gallery/derived/rom-map.md"
python3 - "$MAP" <<'PY'
import re, sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
symbols={}
high=0
for line in lines:
    m=re.match(r"\s*([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)\s+\d+\s+(\S+)$",line)
    if not m:
        continue
    addr,size,name=int(m[1],16),int(m[2],16),m[3]
    if name in ("FONT8","FONT16"):
        symbols[name]=(addr,size)
    if 0x8000 <= addr < 0xffb0 and not name.startswith(".snes_"):
        high=max(high,addr+size)
expected={"FONT16":4096,"FONT8":1024}
if set(symbols) != set(expected) or any(
        symbols[name][1] != size or symbols[name][0] >> 16 == 0
        for name,size in expected.items()):
    raise SystemExit(f"FATAL: immutable font placement changed: {symbols!r}")
margin=0xffb0-high
if margin < 4096:
    raise SystemExit(f"FATAL: bank $00 safety margin {margin} B is below 4096 B")
placed=", ".join(f"{name}=${addr>>16:02X}:{addr&0xffff:04X}"
                 for name,(addr,_) in sorted(symbols.items()))
print(f"bank $00 asset gate: PASS ({placed}; {margin} B before header)")
PY

# ---------------------------------------------------------------------------
# Fast all-62-work decode gate (~6 min, vs ~2.5 h for the full visual corpus).
#
# The near-decode ABI bug this guards was invisible to every cheap check in
# this script: the host oracle passed, the ROM linked, the header was valid,
# and `QUICK=1` only asserts that gallery_progress is still 0.  It needed the
# target to actually decode a stream and check the result.
#
# GALLERY_BENCH_ONLY strips the presentation and runs unpack_slide over every
# work -- far decode, stage, near decode, and both fold_far checksums -- then
# latches corpus_result to 0x5CF0 (all pass) or 0xA50F (any failure).  One
# unambiguous value, full corpus coverage of the codec paths, no repack/hold
# time.  Prefer this over sampling gallery_last_ok on the visual ROM, which is
# a rolling per-work field a later work can overwrite.
echo "==> fast decode gate (GALLERY_BENCH_ONLY, all $WORKS works)"
BENCH_ROM="$BUILD/lzss-gallery-bench.sfc"
BENCH_MAP="$BUILD/lzss-gallery-bench.map"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Oz \
  -DGALLERY_BENCH_ONLY=1 "${EXTRA_DEFS[@]}" \
  -Wl,-Map="$BENCH_MAP" -o "$BENCH_ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BENCH_ROM"
BENCH_VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BENCH_MAP")
[ -n "$BENCH_VMA" ]
"$BUILD/jgxcheck" "$BENCH_ROM" "$ROOT/vendor/bsnes-jg/Database" \
  "0x$BENCH_VMA" 2 0x5CF0 "${BENCH_FRAMES:-30000}" "$BUILD/lzss-gallery-bench-jg.png"
echo "fast decode gate: PASS (all $WORKS works far-decoded, staged, near-decoded, checksummed)"

# Script a real Right press through bsnes-jg and poll until the target accepts
# asset 1. This proves the automatic-latch NMI path remains responsive while
# foreground decode is active; the no-input corpus gate cannot cover that path.
NAV_JGX="$BUILD/jgxcheck-nav"
ARCHIVE=$(find "$ROOT/vendor/bsnes-jg/objs" -name '*.a' | head -1)
g++ -O2 -std=c++11 -DJGX_NAV -I"$ROOT/vendor/bsnes-jg/src" -I"$ROOT/tools" \
  -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-nav.o"
g++ "$BUILD/jgxcheck-nav.o" "$ARCHIVE" -lsamplerate -lm -o "$NAV_JGX"
NAV_VMA=$(awk '$NF=="gallery_current_asset"{print $1; exit}' "$MAP")
[ -n "$NAV_VMA" ]
JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:30000' JGX_POLL=1 \
  "$NAV_JGX" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$NAV_VMA" 1 0x01 40000
echo "automatic joypad navigation gate: PASS (Right accepted during foreground decode)"

VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
[ -n "$VMA" ]
OFF="0x$VMA"
echo "==> corpus_result @ WRAM $OFF; oracle $EXPECT"

if [ "${QUICK:-0}" = 1 ]; then
  FRAMES=1000
  CHECK_OFF=$(awk '$NF=="gallery_progress"{print $1; exit}' "$MAP")
  CHECK_WANT=0x00
  CHECK_LEN=1
  OUT="$BUILD/lzss-gallery-quick-jg.png"
else
  # 62 works complete in ~620k frames (measured 2026-07-28: gallery_progress
  # reached 10 works at 100k frames, i.e. ~10k frames/work). 200000 only
  # covered about 20 works, so the gate was asserting an oracle the ROM had not
  # finished computing and reported got=0x0000. 700000 leaves ~13% headroom;
  # overshooting is free because corpus_result stays latched once written.
  FRAMES="${FRAMES:-700000}"
  CHECK_OFF="$VMA"
  CHECK_WANT="$EXPECT"
  CHECK_LEN=2
  OUT="$BUILD/lzss-gallery-jg.png"
fi

JGX="$BUILD/jgxcheck"
if [ -x "$JGX" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  "$JGX" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$CHECK_OFF" "$CHECK_LEN" "$CHECK_WANT" "$FRAMES" "$OUT"
else
  echo "FATAL: bsnes-jg harness/core missing; run dev/run.sh xcheck"
  exit 1
fi

# A bare `sha256sum "$ROM"` here read as a provenance stamp, which it was not:
# this ROM did not build reproducibly. MOSZeroPageAlloc broke benefit ties for
# zero-page placement in heap-address order, so identical sources produced one
# of two stable images (~18/12 over 30 links) -- the delta being one 1-byte
# global moving in or out of .zp.bss, worth +/-2 B in one function and a +2 B
# shift in 1476 of 2291 linked symbols. See
# docs/plans/2026-08-01-gallery-nonreproducible-build.md and the upstream fix
# patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch.
#
# Rather than print a hash that may or may not mean anything, relink once and
# say so. Non-fatal by default so a toolchain predating 0021 still completes the
# gate; set GALLERY_REPRO_STRICT=1 to make a non-reproducible build an error.
echo "==> reproducible-build check (relink and compare)"
REPRO_ROM="$BUILD/lzss-gallery-repro.sfc"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Oz \
  -DGALLERY_START="${GALLERY_START:-0}" \
  "${EXTRA_DEFS[@]}" \
  -o "$REPRO_ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$REPRO_ROM" >/dev/null
ROM_SHA=$(sha256sum "$ROM" | cut -d' ' -f1)
REPRO_SHA=$(sha256sum "$REPRO_ROM" | cut -d' ' -f1)
rm -f "$REPRO_ROM"
if [ "$ROM_SHA" = "$REPRO_SHA" ]; then
  echo "reproducible build: PASS ($ROM_SHA)"
else
  echo "reproducible build: FAIL — two links of identical sources disagree"
  echo "  $ROM_SHA (gated ROM)"
  echo "  $REPRO_SHA (relink)"
  echo "  known cause + fix: docs/plans/2026-08-01-gallery-nonreproducible-build.md"
  if [ "${GALLERY_REPRO_STRICT:-0}" = 1 ]; then
    echo "FATAL: GALLERY_REPRO_STRICT=1 and the build is not reproducible"
    exit 1
  fi
fi
echo "RESULT: PASS — $WORKS-work LZSS gallery host oracle, relink, header and bsnes-jg gate"
