#!/usr/bin/env python3
"""Verify an F2 scroll-ring demo really moves 1 px EVERY frame (true 60 fps).

The #99c/#128 scroll-ring pattern replaces a repaint with an HDMA-banded scroll: content
translates 1 px per frame and only the off-screen staging row/column is repainted. Two things can
silently go wrong and neither is caught by a corpus gate (the gate asserts a WRAM CRC, not motion):

  * a STALL — one frame in N does no visible work because the paint iteration overran v-blank
    (#99c hit exactly this: every 9th frame, traced to 40 __mulsi3 libcalls in the painter);
  * a WRONG SHIFT — the band table is off, so the picture jumps or scrolls the wrong way/amount.

So we assert both, per band, over consecutive frames: every consecutive pair must differ (no
stall), and frame N+1 must equal frame N translated by the band's expected step.

Bands are given as `name:y0:y1:axis:step`, e.g. `upper:48:104:y:+1` (content moves DOWN 1 px) or
`ramp:48:160:x:-1` (moves LEFT 1 px). Compare hue CLASSES, not raw RGB, when the demo also breathes
its palette — a recolour is not a shift failure (the #99c checker learned this the hard way).

Usage:
  dev/scroll-ring-check.py --rom build/mvscrl.sfc --off 0x31 --want 0x72A7 \
      --band upper:48:104:y:+1 --band lower:104:160:y:-1
"""
import argparse, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def dump(rom, db, off, ln, want, frame, out, jg):
    subprocess.run([jg, rom, db, off, str(ln), want, str(frame), out],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if not os.path.exists(out):
        sys.exit(f"scroll-ring-check: jgxcheck produced no PNG for frame {frame}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", required=True)
    ap.add_argument("--off", required=True, help="corpus_result WRAM offset, e.g. 0x31")
    ap.add_argument("--want", required=True, help="expected CRC, e.g. 0x72A7")
    ap.add_argument("--len", type=int, default=2)
    ap.add_argument("--start", type=int, default=500)
    ap.add_argument("--frames", type=int, default=12, help="consecutive frames to dump (>=3)")
    ap.add_argument("--x0", type=int, default=64, help="canvas left px (BOX_COL*8)")
    ap.add_argument("--x1", type=int, default=192)
    ap.add_argument("--band", action="append", required=True,
                    metavar="name:y0:y1:axis:step")
    ap.add_argument("--min-match", type=float, default=90.0)
    a = ap.parse_args()

    try:
        from PIL import Image
    except ImportError:
        sys.exit("scroll-ring-check: needs Pillow")

    jg = os.path.join(ROOT, "build", "jgxcheck")
    db = os.path.join(ROOT, "vendor", "bsnes-jg", "Database")
    if not os.access(jg, os.X_OK):
        sys.exit("scroll-ring-check: build/jgxcheck missing — run dev/run.sh xcheck")

    bands = []
    for spec in a.band:
        name, y0, y1, axis, step = spec.split(":")
        bands.append((name, int(y0), int(y1), axis, int(step)))

    with tempfile.TemporaryDirectory() as td:
        frames = []
        for i in range(a.frames):
            p = os.path.join(td, f"f{i}.png")
            dump(a.rom, db, a.off, a.len, a.want, a.start + i, p, jg)
            frames.append(Image.open(p).convert("RGB").copy())

        rc = 0
        for name, y0, y1, axis, step in bands:
            crops = [f.crop((a.x0, y0, a.x1, y1)) for f in frames]
            stalls, matches = [], []
            for i in range(len(crops) - 1):
                pa, pb = crops[i].load(), crops[i + 1].load()
                w, h = crops[i].size
                if all(pa[x, y] == pb[x, y] for y in range(h) for x in range(w)):
                    stalls.append(a.start + i)
                ok = tot = 0
                for y in range(h):
                    for x in range(w):
                        sx, sy = (x - step, y) if axis == "x" else (x, y - step)
                        if 0 <= sx < w and 0 <= sy < h:
                            tot += 1
                            ok += (pb[x, y] == pa[sx, sy])
                matches.append(100.0 * ok / tot)
            worst = min(matches)
            bad = stalls or worst < a.min_match
            rc |= bool(bad)
            # Render the stall list to a string FIRST: `stalls or 'NONE'` yields a list when stalls
            # is non-empty, and `list.__format__` rejects a width spec — so the failure path crashed
            # with a TypeError instead of reporting the stalled frames. Only the passing path had
            # ever run (mvscrl), which is exactly how a checker that cannot report failure hides.
            stall_txt = ",".join(str(s) for s in stalls) if stalls else "NONE"
            print(f"{name:8s} axis={axis}{step:+d}  stalls={stall_txt:<10} "
                  f"shift-match min {worst:.1f}% mean {sum(matches)/len(matches):.1f}%  "
                  f"{'FAIL' if bad else 'PASS'}")
        print("60FPS CHECK:", "FAIL" if rc else "PASS")
        return rc


if __name__ == "__main__":
    sys.exit(main())
