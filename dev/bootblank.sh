#!/usr/bin/env bash
# dev/bootblank.sh — measure the BOOT force-blank window of every snesgfx `Display` demo.
#
# Companion to dev/m7blank.sh, which measures the POST-TITLE window of the Mode 7 splash demos.
# This one measures the other window: the console powers on force-blanked (INIDISP = $8F), the
# drawables bulk-write VRAM inside that window via reserve(), and the first display_frame()
# releases it. Every frame in between is black.
#
# The question it answers: how much of that window is snesgfx, and how much is the demo's own
# first scene_emit()? display_frame() releases the blank at its END, after scene_emit() -- so an
# expensive first emit keeps the screen off for its whole duration.
#
# Method is dev/m7blank.sh's, retargeted at the frame-1 black run:
#   -DM7BLANK_PROBE  display_frame() paints CGRAM[0] white on the frame that releases the blank,
#                    so the measured black run is the FORCE-BLANK window and not a demo's black art.
#   JGX_ENTROPY=0    pin bsnes-jg's PPU entropy or mid-run frames are irreproducible.
#   JGX_FRAMESCAN=1  one run per demo; holding each change event forward reconstructs every frame.
#
# Usage:
#   dev/bootblank.sh                  # every examples/snes/*.c that calls display_init()
#   dev/bootblank.sh mandel-oop life
#   FRAMES=400 dev/bootblank.sh       # scan window (default 300)
#   OUT=... BASELINE=... dev/bootblank.sh    # write a TSV / print a before-after delta
#
# Host-side: uses build/llvm-mos-install + build/jgxcheck directly, no Docker.
set -euo pipefail

FIRSTFRAME=0
case "${1-}" in
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --firstframe)
    # SAFETY GATE for the release-only first display_frame(). That frame shows reserve()'s output
    # only -- emit() has not run yet -- so a layer that paints solely from emit() would display
    # whatever VRAM held before. bsnes-jg randomises power-on VRAM at its DEFAULT entropy, so such
    # a frame is nondeterministic run to run, while a correct one is byte-identical. Capture each
    # demo's first visible frame twice at default entropy and compare. Exit 5 on any mismatch.
    FIRSTFRAME=1; shift ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
DB="$ROOT/vendor/bsnes-jg/Database"
JGX="$BUILD/jgxcheck"
FRAMES="${FRAMES:-300}"
OUT="${OUT:-$BUILD/bootblank.tsv}"
BASELINE="${BASELINE:-}"
SCAN_DIR="$BUILD/bootblank"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -x "$JGX" ]           || { echo "FATAL: no jgxcheck harness at $JGX"; exit 1; }

# Derived, not hardcoded: any demo constructing a Display is in scope.
if [ "$#" -gt 0 ]; then
  DEMOS=("$@")
else
  mapfile -t DEMOS < <(grep -ln 'display_init' "$ROOT"/examples/snes/*.c \
                       | xargs -n1 basename | sed 's/\.c$//' | sort)
fi

mkdir -p "$SCAN_DIR"
: > "$OUT"
FF_BAD=0
printf '%-18s %8s  %s\n' demo blank note
printf -- '------------------------------------------------\n'

for demo in "${DEMOS[@]}"; do
  src="$ROOT/examples/snes/$demo.c"
  [ -f "$src" ] || { printf '%-18s %8s  %s\n' "$demo" - "no source"; continue; }

  cfg="$CFG"
  grep -q 'snes-far-platform' "$src" && [ -f "$BUILD/install/bin/mos-snes-far.cfg" ] \
    && cfg="$BUILD/install/bin/mos-snes-far.cfg"

  if ! "$TOOL/mos-clang" --config "$cfg" -mcpu=mosw65816 \
        -Xclang -target-feature -Xclang +mos-a16 -Os -DM7BLANK_PROBE \
        -Wl,-Map="$SCAN_DIR/$demo.map" -o "$SCAN_DIR/$demo.sfc" "$src" \
        > "$SCAN_DIR/$demo.buildlog" 2>&1; then
    printf '%-18s %8s  %s\n' "$demo" - "BUILD FAILED"
    continue
  fi
  python3 "$ROOT/tools/snes-checksum.py" "$SCAN_DIR/$demo.sfc" >/dev/null

  JGX_ENTROPY=0 JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=20000 \
    "$JGX" "$SCAN_DIR/$demo.sfc" "$DB" 0x0 2 0x0000 "$FRAMES" \
    > "$SCAN_DIR/$demo.scan" 2>/dev/null || true

  if [ "$FIRSTFRAME" = 1 ]; then
    # The probe run above located the release; the first VISIBLE frame is the one after it.
    R=$(FRAMES="$FRAMES" python3 - "$SCAN_DIR/$demo.scan" <<'PY'
import os, re, sys
frames = int(os.environ["FRAMES"]); ev = []
for line in open(sys.argv[1]):
    m = re.match(r"FRAMESCAN: f=(\d+) hash=\w+ dom=#(\w+) pct=(\d+)", line)
    if m: ev.append((int(m.group(1)), m.group(2), int(m.group(3))))
runs, cur = [], None
for i, (f, dom, pct) in enumerate(ev):
    end = ev[i + 1][0] - 1 if i + 1 < len(ev) else frames
    if dom == "000000" and pct >= 99: cur = [f, end] if cur is None else [cur[0], end]
    elif cur: runs.append(tuple(cur)); cur = None
if cur: runs.append(tuple(cur))
boot = [r for r in runs if r[0] == 1]
print((boot[0][1] + 1) if boot else 1)
PY
)
    # Rebuild WITHOUT the probe: the probe itself writes CGRAM, which would mask the very
    # uninitialised-memory dependence this gate is looking for.
    "$TOOL/mos-clang" --config "$cfg" -mcpu=mosw65816 \
      -Xclang -target-feature -Xclang +mos-a16 -Os \
      -o "$SCAN_DIR/$demo-ff.sfc" "$src" >/dev/null 2>&1
    python3 "$ROOT/tools/snes-checksum.py" "$SCAN_DIR/$demo-ff.sfc" >/dev/null
    h=""; mismatch=0
    for run in 1 2; do
      # NO JGX_ENTROPY: bsnes-jg's default entropy randomises power-on VRAM/CGRAM/OAM.
      "$JGX" "$SCAN_DIR/$demo-ff.sfc" "$DB" 0x0 2 0x0000 "$R" "$SCAN_DIR/$demo-ff$run.png" \
        >/dev/null 2>&1 || true
      s=$(sha256sum "$SCAN_DIR/$demo-ff$run.png" 2>/dev/null | cut -c1-16 || echo MISSING)
      [ -z "$h" ] && h="$s" || { [ "$h" = "$s" ] || mismatch=1; }
    done
    if [ "$mismatch" = 1 ]; then
      printf '%-18s %8s  %s\n' "$demo" "f=$R" "NONDETERMINISTIC first visible frame"
      echo "$demo	-1" >> "$OUT"; FF_BAD=$((FF_BAD + 1))
    else
      printf '%-18s %8s  %s\n' "$demo" "f=$R" "ok ($h)"
      echo "$demo	0" >> "$OUT"
    fi
    continue
  fi

  FRAMES="$FRAMES" DEMO="$demo" OUT="$OUT" python3 - "$SCAN_DIR/$demo.scan" <<'PY'
import os, re, sys
frames = int(os.environ["FRAMES"]); demo = os.environ["DEMO"]; out = os.environ["OUT"]
ev = []
for line in open(sys.argv[1]):
    m = re.match(r"FRAMESCAN: f=(\d+) hash=\w+ dom=#(\w+) pct=(\d+)", line)
    if m: ev.append((int(m.group(1)), m.group(2), int(m.group(3))))

# Hold each event's state forward; the BOOT window is the all-black run that starts at frame 1.
runs, cur = [], None
for i, (f, dom, pct) in enumerate(ev):
    end = ev[i + 1][0] - 1 if i + 1 < len(ev) else frames
    if dom == "000000" and pct >= 99:
        cur = [f, end] if cur is None else [cur[0], end]
    elif cur:
        runs.append(tuple(cur)); cur = None
if cur: runs.append(tuple(cur))

boot = [r for r in runs if r[0] == 1]
if boot:
    n = boot[0][1]
    note = "STILL BLACK at f=%d — raise FRAMES" % frames if boot[0][1] >= frames else ""
else:
    n, note = 0, "never black (probe did not fire?)"
print("%-18s %8d  %s" % (demo, n, note))
open(out, "a").write("%s\t%d\n" % (demo, n))
PY
done

if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
  echo
  echo "delta vs $BASELINE:"
  BASE="$BASELINE" NEW="$OUT" python3 - <<'PY'
import os
def load(p):
    return {l.split("\t")[0]: int(l.split("\t")[1]) for l in open(p) if l.strip()}
base, new = load(os.environ["BASE"]), load(os.environ["NEW"])
rows = [(k, base.get(k), new.get(k)) for k in sorted(set(base) | set(new))]
changed = [r for r in rows if r[1] != r[2]]
print("%-18s %8s %8s %8s" % ("demo", "before", "after", "delta"))
for k, b, n in changed:
    print("%-18s %8s %8s %8s" % (k, b, n, (n - b) if b is not None and n is not None else "?"))
print("(%d of %d demos changed)" % (len(changed), len(rows)))
tb = sum(b for _, b, _ in rows if b is not None)
tn = sum(n for _, _, n in rows if n is not None)
print("total boot force-blank frames: %d -> %d" % (tb, tn))
PY
fi
if [ "$FIRSTFRAME" = 1 ]; then
  echo
  if [ "$FF_BAD" -gt 0 ]; then
    echo "FAIL: $FF_BAD demo(s) have a nondeterministic first visible frame — a layer is showing"
    echo "      VRAM that no reserve() wrote. See snesgfx/display.h display_add()'s contract."
    echo
    echo "wrote $OUT"
    exit 5
  fi
  echo "PASS: every first visible frame is byte-identical across two default-entropy runs."
fi

echo
echo "wrote $OUT"
