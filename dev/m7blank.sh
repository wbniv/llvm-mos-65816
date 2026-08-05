#!/usr/bin/env bash
# dev/m7blank.sh — measure the post-title FORCE-BLANK WINDOW of the Mode 7 splash demos.
#
# The `m7splash*()` demos hand off from the title to their own render with the screen
# force-blanked (`m7splash_end()` returns with INIDISP=$80). Every frame between that
# hand-off and the demo's first visible frame is an all-black panel the viewer sees as a
# stall. This script measures that panel, per demo, reproducibly.
#
# Method (the #121 re-verify method, generalised):
#   JGX_ENTROPY=0        — pin bsnes-jg's PPU entropy. WITHOUT this, registers the ROM never
#                          writes are seeded from clock(), so mid-run frames are irreproducible
#                          (the same frame renders black on one run and 85% non-black on the next).
#   JGX_FRAMESCAN=1      — one emulator run emits a change event per frame whose fingerprint
#                          differs from the previous frame, with the dominant colour + its share.
#                          Holding the last event's state forward reconstructs EVERY frame, so a
#                          single run yields the whole timeline (no per-frame PNG sweep).
#   black frame          := dominant colour #000000 at >= BLACK_PCT (default 99) percent.
#
# The SMOKE assertion is deliberately ignored: these runs are short (the demos' corpus_result
# lands thousands of frames later) and the picture timeline is the only thing being measured.
#
# Usage:
#   dev/m7blank.sh                       # all Mode 7 splash demos
#   dev/m7blank.sh mandel-oop mandel-display
#   FRAMES=900 dev/m7blank.sh julia      # widen the window (default 700)
#   BASELINE=/path/to/base.tsv dev/m7blank.sh   # print a before/after delta column
#
# Writes a TSV (demo, first_black, last_black, length) to $OUT (default build/m7blank.tsv)
# so a later run can diff against it.
#
# Host-side: uses build/llvm-mos-install + build/jgxcheck directly, no Docker.
set -euo pipefail

PROBE=0
GATE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --gate)
      # Enforce the committed per-demo force-blank budgets (implies --probe). Exit 4 on any
      # demo over budget. This is the regression guard for m7title.h's handoff contract: put
      # compute back after m7splash_end() and this turns red.
      GATE=1; PROBE=1; shift
      ;;
    --probe)
      # Build with -DM7BLANK_PROBE so CGRAM[0] turns white the instant force-blank is released
      # (mode7.h m7_show / snesgfx display_frame). The measured all-black run is then EXACTLY the
      # force-blank window, with a demo's deliberately-black art excluded. Never ship a probe ROM.
      PROBE=1; shift
      ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
DB="$ROOT/vendor/bsnes-jg/Database"
JGX="$BUILD/jgxcheck"
FRAMES="${FRAMES:-700}"
BLACK_PCT="${BLACK_PCT:-99}"
OUT="${OUT:-$BUILD/m7blank.tsv}"
BASELINE="${BASELINE:-}"

# The Mode 7 splash demos: every examples/snes/*.c that calls m7splash / m7splash_begin.
# Derived, not hardcoded — a new splash demo joins the measurement automatically (the count
# has already drifted once: the "seven Mode-7 demo main()s" note in docs/agent-handoff.md).
default_demos() {
  grep -ln 'm7splash' "$ROOT"/examples/snes/*.c \
    | xargs -n1 basename | sed 's/\.c$//' | sort
}

if [ "$#" -gt 0 ]; then DEMOS=("$@"); else mapfile -t DEMOS < <(default_demos); fi

# --gate budgets: the maximum FORCE-BLANK frames (--probe measurement) a demo may spend between
# m7splash_end() and its blank release. One line per demo with the reason it is not 1. Tighten a
# budget when a demo improves; never loosen one without saying why here.
#
# 1 = the floor: _m7t_wipe_vram()'s two 16 KB DMAs + the demo's Mode 7 / CGRAM mode switch. Nothing
# else may live in the window (snesgfx/m7title.h, THE HANDOFF CONTRACT).
budget_for() {
  case "$1" in
    # apollo-reel measures under a synthetic stand-in corpus (build_wide_demo() generates one —
    # the real footage lives outside the repo), so this is the HiROM DMA setup + first packed-far
    # frame's codec dispatch, same shape as snes-video-reel below.
    apollo-reel)     echo 6 ;;   # 5 measured
    avalanche)      echo 2 ;;
    blossom)        echo 5 ;;   # 4 measured: vram_clear_all + hud_begin's BG3/HDMA setup + CGRAM DMA
    buddha)         echo 3 ;;   # 2 measured: vram_clear_all's two 32 KB DMAs + CGRAM DMA
    julia)          echo 2 ;;
    # 253 measured: on-SNES LZSS decompression of the gallery's first work before any panel is
    # drawn — decode dominates, not DMA setup. By far the widest window of the twelve; a
    # regression here is likely a codec change, not a handoff-contract one.
    lzss-gallery)   echo 254 ;;
    mandel-display) echo 2 ;;
    mandel-double)  echo 2 ;;
    mandel-float)   echo 2 ;;
    # 11 measured, and only 4 of it is the handoff (splash exit + display_init + _mandel_reserve).
    # The other 7 are inside snesgfx's FIRST display_frame(): bisecting _mandel_emit shows 6 of them
    # are build_step()'s far-memory work (2 in the 512-far-store row expansion, 4 in build_chr_row's
    # far loads + the queue copy). That is the Display first-frame path, not the splash contract —
    # tracked separately. Budgeted at the measured value so a splash-side regression still trips.
    mandel-oop)     echo 12 ;;
    # 20 measured: the ExHiROM 6 MiB bytecode-VM cartridge's act-1 dispatch setup before its
    # title clears — the generated seamdemo-data.h layout plus the VM's own init, not DMA.
    seamdemo)       echo 21 ;;
    # snes-video-reel measures against the checked-in assets/snes/video/svx2-full-reel.bin
    # corpus (real asset, real build) — the HiROM DMA setup + first packed-far frame decode.
    snes-video-reel) echo 5 ;;   # 4 measured
    *)              echo 2 ;;   # a new splash demo must land at the floor
  esac
}

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ]           || { echo "FATAL: no SDK config at $CFG"; exit 1; }
[ -x "$JGX" ]           || { echo "FATAL: no jgxcheck harness at $JGX"; exit 1; }
[ -d "$DB" ]            || { echo "FATAL: no bsnes-jg Database at $DB"; exit 1; }

SCAN_DIR="$BUILD/m7blank"
mkdir -p "$SCAN_DIR"

# Four demos are not a single self-contained examples/snes/<demo>.c: they need a
# generated asset header, extra source files, and/or a post-link pack/fill step, so
# the generic single-file build below can never reach them. Each case reproduces the
# REAL recipe its own dev/<demo>.sh gate uses (same sources, same cfg, same pack
# tool) — except apollo-reel, whose footage corpus lives outside the repo entirely
# (dev/apollo-reel.sh defaults to an out-of-tree /tmp path). The force-blank window
# is a function of CODE SHAPE (DMA setup + first-frame dispatch order), not pixel
# content, so a tiny deterministic synthetic corpus in the same shape the real baker
# expects (4480-byte tile-major frames, 448-byte BGR555 palette) reproduces the real
# code path without vendoring footage into the repo or reaching into /tmp.
build_wide_demo() { # <demo> <extra-cflags> -> writes $BUILD/$demo.sfc + $BUILD/$demo.map
  local demo=$1 extra=$2
  case "$demo" in
    snes-video-reel)
      local stream="$ROOT/assets/snes/video/svx2-full-reel.bin"
      [ -f "$stream" ] || { echo "missing checked-in $stream" >&2; return 1; }
      "$TOOL/mos-clang" --config "$BUILD/install/bin/mos-snes-hirom.cfg" -mcpu=mosw65816 \
        -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM $extra \
        -I"$ROOT/examples/snes" \
        -Wl,-Map="$BUILD/$demo.map" -o "$BUILD/$demo.sfc" \
        "$ROOT/examples/snes/snes-video-reel.c" \
        "$ROOT/examples/snes/snes-video-reel-fast.s" \
        "$ROOT/examples/snes/snes-video-codec.c" \
        "$ROOT/examples/snes/snes-video-dma.c" \
        "$ROOT/examples/snes/snes-video-codec-fast.s" || return 1
      python3 "$ROOT/tools/snes-video-pack-hirom.py" "$BUILD/$demo.sfc" "$stream" >/dev/null || return 1
      python3 "$ROOT/tools/snes-checksum.py" --hirom "$BUILD/$demo.sfc" >/dev/null
      ;;
    apollo-reel)
      local stubdir="$SCAN_DIR/apollo-reel-stub"
      mkdir -p "$stubdir"
      python3 - "$stubdir" <<'PY'
import struct, sys
from pathlib import Path
out = Path(sys.argv[1])
FRAMES = 8   # small and deterministic: only the code path is being measured
with open(out / "stub.tiles", "wb") as f:
    for i in range(FRAMES):
        f.write(bytes((i * 37 + j) & 0xFF for j in range(4480)))
with open(out / "stub.pal", "wb") as f:
    for i in range(224):
        f.write(struct.pack("<H", (i * 3) & 0x7FFF))
PY
      python3 "$ROOT/tools/snes-video-reel-assets.py" --frames 8 --packed-far --keyframe-interval 4 \
        --frame-checks --dashboard-palette-fixup \
        --palette-output "$stubdir/eff.pal" --stream-output "$stubdir/stream.bin" \
        "$stubdir/stub.tiles" "$stubdir/stub.pal" "$stubdir/apollo-reel-assets.h" >/dev/null || return 1
      "$TOOL/mos-clang" --config "$BUILD/install/bin/mos-snes-hirom.cfg" -mcpu=mosw65816 \
        -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM \
        -DAPOLLO_REEL_VBLANKS_PER_FRAME=2 $extra \
        -I"$stubdir" -I"$ROOT/examples/snes" \
        -Wl,-Map="$BUILD/$demo.map" -o "$BUILD/$demo.sfc" \
        "$ROOT/examples/snes/apollo-reel.c" \
        "$ROOT/examples/snes/apollo-reel-fast.s" \
        "$ROOT/examples/snes/snes-video-codec.c" \
        "$ROOT/examples/snes/snes-video-dma.c" \
        "$ROOT/examples/snes/snes-video-codec-fast.s" || return 1
      python3 "$ROOT/tools/snes-video-pack-hirom.py" "$BUILD/$demo.sfc" "$stubdir/stream.bin" >/dev/null || return 1
      python3 "$ROOT/tools/snes-checksum.py" --hirom "$BUILD/$demo.sfc" >/dev/null
      ;;
    seamdemo)
      local gen="$SCAN_DIR/seamdemo-gen" cfg="$BUILD/install/bin/mos-snes-cart-seamdemo.cfg"
      mkdir -p "$gen"
      [ -f "$cfg" ] || python3 "$ROOT/tools/snes-cartcanary.py" emit-platform \
        --mapping exhirom --size 6M --name snes-cart-seamdemo --install "$BUILD/install" >/dev/null || return 1
      python3 "$ROOT/tools/snes-seamdemo-gen.py" emit-header \
        --mapping exhirom --size 6M --out "$gen/seamdemo-data.h" >/dev/null || return 1
      "$TOOL/mos-clang" --config "$cfg" -mcpu=mosw65816 \
        -Xclang -target-feature -Xclang +mos-a16 -Os $extra \
        -I"$gen" -I"$ROOT/examples/snes" \
        -Wl,-Map="$BUILD/$demo.map" -o "$BUILD/$demo.sfc" \
        "$ROOT/examples/snes/seamdemo.c" || return 1
      python3 "$ROOT/tools/snes-seamdemo-gen.py" fill --mapping exhirom --size 6M \
        --rom "$BUILD/$demo.sfc" --report "$gen/fill.json" >/dev/null || return 1
      python3 "$ROOT/tools/snes-checksum.py" --mapping exhirom "$BUILD/$demo.sfc" >/dev/null
      ;;
    *) return 1 ;;
  esac
}

printf '%-18s %8s %8s %8s %s\n' demo first last frames note
printf -- '---------------------------------------------------------------\n'
: > "$OUT"

for demo in "${DEMOS[@]}"; do
  src="$ROOT/examples/snes/$demo.c"
  [ -f "$src" ] || { printf '%-18s %8s %8s %8s %s\n' "$demo" - - - "no source"; continue; }

  # Build (+mos-a16, the shipped configuration). Extra flags via M7BLANK_CFLAGS.
  # Per-demo flags that its own dev/<demo>.sh gate uses and the ROM will not link without.
  # Per-demo build shape its own dev/<demo>.sh gate uses and the ROM will not link without.
  extra=""
  cfg="$CFG"
  case "$demo" in
    mandel-double) extra="-Oz" ;;   # .far_rodata overflows the 32 KiB LoROM at -Os
    lzss-gallery)  cfg="$BUILD/install/bin/mos-snes-gallery.cfg" ;;
  esac
  # A demo that opts into the far platform needs its linker config, or .far_rodata overflows.
  grep -q 'snes-far-platform' "$src" && [ -f "$BUILD/install/bin/mos-snes-far.cfg" ] \
    && cfg="$BUILD/install/bin/mos-snes-far.cfg"
  [ "$PROBE" = 1 ] && extra="$extra -DM7BLANK_PROBE"
  case "$demo" in
    apollo-reel|snes-video-reel|seamdemo)
      if ! build_wide_demo "$demo" "$extra" > "$SCAN_DIR/$demo.buildlog" 2>&1; then
        printf '%-18s %8s %8s %8s %s\n' "$demo" - - - "BUILD FAILED (see $SCAN_DIR/$demo.buildlog)"
        continue
      fi
      ;;
    *)
      if ! "$TOOL/mos-clang" --config "$cfg" -mcpu=mosw65816 \
            -Xclang -target-feature -Xclang +mos-a16 -Os $extra \
            ${M7BLANK_CFLAGS:-} \
            -Wl,-Map="$BUILD/$demo.map" -o "$BUILD/$demo.sfc" "$src" \
            > "$SCAN_DIR/$demo.buildlog" 2>&1; then
        printf '%-18s %8s %8s %8s %s\n' "$demo" - - - "BUILD FAILED (see $SCAN_DIR/$demo.buildlog)"
        continue
      fi
      python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$demo.sfc" >/dev/null
      ;;
  esac

  # corpus_result is only used to satisfy jgxcheck's argument list; the SMOKE verdict is ignored.
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/$demo.map" || true)
  [ -n "$VMA" ] || VMA=0

  JGX_ENTROPY=0 JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=20000 \
    "$JGX" "$BUILD/$demo.sfc" "$DB" "0x$VMA" 2 0x0000 "$FRAMES" \
    > "$SCAN_DIR/$demo.scan" 2>/dev/null || true

  FRAMES="$FRAMES" BLACK_PCT="$BLACK_PCT" DEMO="$demo" OUT="$OUT" \
    python3 - "$SCAN_DIR/$demo.scan" <<'PY'
import os, re, sys

frames   = int(os.environ["FRAMES"])
blackpct = int(os.environ["BLACK_PCT"])
demo     = os.environ["DEMO"]
out      = os.environ["OUT"]

ev = []
for line in open(sys.argv[1]):
    m = re.match(r"FRAMESCAN: f=(\d+) hash=\w+ dom=#(\w+) pct=(\d+)", line)
    if m:
        ev.append((int(m.group(1)), m.group(2), int(m.group(3))))

# Hold each change event's state forward to reconstruct every frame, then coalesce
# maximal runs of all-black frames.
runs, cur = [], None
for i, (f, dom, pct) in enumerate(ev):
    end = ev[i + 1][0] - 1 if i + 1 < len(ev) else frames
    if dom == "000000" and pct >= blackpct:
        cur = [f, end] if cur is None else [cur[0], end]
    elif cur:
        runs.append(tuple(cur)); cur = None
if cur:
    runs.append(tuple(cur))

# The boot black (starts at frame 1) is the console powering on blanked — not the defect.
# The POST-TITLE window is the first all-black run that does not start at frame 1.
post = [r for r in runs if r[0] > 1]
if post:
    a, b = post[0]
    note = "" if len(post) == 1 else "(+%d later black run(s))" % (len(post) - 1)
    n = b - a + 1
    if b >= frames:
        note = (note + " STILL BLACK at f=%d — raise FRAMES" % frames).strip()
else:
    a = b = n = 0
    note = "no post-title black window"

print("%-18s %8s %8s %8s %s" % (demo, a or "-", b or "-", n or "-", note))
with open(out, "a") as fh:
    fh.write("%s\t%d\t%d\t%d\n" % (demo, a, b, n))
PY
done

rc=0
if [ "$GATE" = 1 ]; then
  echo
  echo "gate: force-blank frames vs committed budget"
  printf '%-18s %8s %8s  %s\n' demo measured budget verdict
  while IFS=$'\t' read -r demo first last n; do
    b=$(budget_for "$demo")
    if [ "$n" -le "$b" ]; then v=ok; else v="OVER BUDGET"; rc=4; fi
    printf '%-18s %8s %8s  %s\n' "$demo" "$n" "$b" "$v"
  done < "$OUT"
  if [ "$rc" -ne 0 ]; then
    echo
    echo "FAIL: a demo spends more than its budget force-blanked after the title."
    echo "      Compute belongs BETWEEN m7splash_begin() and m7splash_end() — see the handoff"
    echo "      contract at the top of examples/snes/snesgfx/m7title.h."
  else
    echo
    echo "PASS: every demo is within its post-title force-blank budget."
  fi
fi

if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
  echo
  echo "delta vs $BASELINE:"
  BASE="$BASELINE" NEW="$OUT" python3 - <<'PY'
import os
def load(p):
    d = {}
    for line in open(p):
        k, a, b, n = line.split("\t")
        d[k] = (int(a), int(b), int(n))
    return d
base, new = load(os.environ["BASE"]), load(os.environ["NEW"])
print("%-18s %8s %8s %8s" % ("demo", "before", "after", "delta"))
for k in sorted(set(base) | set(new)):
    bn = base.get(k, (0, 0, -1))[2]
    nn = new.get(k, (0, 0, -1))[2]
    print("%-18s %8s %8s %8s" % (k, bn, nn, (nn - bn) if bn >= 0 and nn >= 0 else "?"))
PY
fi

echo
echo "wrote $OUT"
exit $rc
