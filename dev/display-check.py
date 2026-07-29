#!/usr/bin/env python3
"""Post-title display check: does the demo actually put a live picture on screen?

WHY THIS EXISTS
---------------
A green corpus gate says nothing about the picture. Every demo sets `corpus_result` and the gate
asserts it -- but that value is computed DURING THE TITLE, before the display loop matters. Two
demos in two days shipped with a passing gate and a broken display:

  * truncstair -- rendered a 100% BLACK screen and reset in a loop for weeks (a one-row canvas
    overflow clobbered the canvas's own VRAM base addresses). Gate: green at 0x02CA throughout.
  * mvscrl     -- rendered a decorative pattern instead of the memmove buffers it exists to show.
    Gate: green at 0x72A7 throughout.

`dev/verify-web-roms.sh` could not catch either, for two structural reasons this tool fixes:
  1. its BLANKSCAN looks for force-blank BLEED (a one-frame black band at the top of the picture),
     not for a wholly black or dead screen; and
  2. it runs each ROM at the manifest's `frames`, which is chosen so `corpus_result` is ready --
     and that is typically still DURING the title. Checking there inspects the title card, not the
     demo. So we deliberately sample well PAST that frame.

WHAT IT CATCHES  (be precise about this -- do not oversell it)
  * a blank/black screen after the title  -- the truncstair class;
  * a crash/reset loop, detected without needing a screenshot: `corpus_result` is written once per
    boot, so if it is unstable across late samples the program restarted (this is exactly the
    signal that proved truncstair was resetting -- it read partial folds 0x01F0/0x01FC);
  * a display frozen on the title card, i.e. the demo loop never started.

WHAT IT DOES NOT CATCH
  * a picture that is live and plausible but WRONG -- the mvscrl class. Detecting that needs a
    demo-specific claim about what the pixels mean, which this tool has no way to know. Do not
    read a PASS here as "the visual is correct"; read it as "something is on screen and running".

Usage:
  dev/display-check.py                      # sweep every demo in biohack.net's manifest
  dev/display-check.py --only truncstair,mvscrl
  dev/display-check.py --rom build/foo.sfc --off 0x31 --want 0x02CA --frames 500
"""
import argparse, json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JGX = os.path.join(ROOT, "build", "jgxcheck")
DB = os.path.join(ROOT, "vendor", "bsnes-jg", "Database")


def run(rom, off, ln, want, frame, png=None):
    """Return (got_hex_or_None, png_path_or_None) after emulating `frame` frames."""
    args = [JGX, rom, DB, str(off), str(ln), str(want), str(frame)]
    if png:
        args.append(png)
    p = subprocess.run(args, capture_output=True, text=True)
    m = re.search(r"got=(0x[0-9A-Fa-f]+)", p.stdout + p.stderr)
    return (m.group(1).lower() if m else None), png


def ink_pct(png):
    from PIL import Image
    px = Image.open(png).convert("RGB").load()
    # Subsample: a dead screen is uniformly dead, and this runs over ~100 ROMs.
    n = sum(1 for y in range(0, 224, 2) for x in range(0, 256, 2) if px[x, y] != (0, 0, 0))
    return 100.0 * n / (128 * 112)


def same(a, b):
    from PIL import Image
    pa = Image.open(a).convert("RGB").load()
    pb = Image.open(b).convert("RGB").load()
    return all(pa[x, y] == pb[x, y] for y in range(0, 224, 4) for x in range(0, 256, 4))


def check(demo, rom, off, ln, want, frames, min_ink, margins, td, max_gate):
    """One demo. Returns (ok, note).

    Sampling is capped: emulation costs ~85 fps here, and a few demos have huge gate frames
    (lzss-gallery is 200_000), so sampling at `frames + margin` for those would cost ~800k frames
    for one ROM. Display liveness does not need the gate frame at all -- it only needs to be past
    title_end. So we sample at min(frames, max_gate) + margins. The corpus_result reset check DOES
    need the gate to have completed, so it is skipped (and said so) when frames > max_gate."""
    eff = min(frames, max_gate)
    do_corpus = frames <= max_gate
    base = os.path.join(td, f"{demo}_base.png")
    run(rom, off, ln, want, eff, base)             # the gate's own frame (often the title)
    late = [eff + m for m in margins]
    inks, gots, pngs = [], [], []
    for i, f in enumerate(late):
        png = os.path.join(td, f"{demo}_{i}.png")
        got, _ = run(rom, off, ln, want, f, png)
        pngs.append(png)
        gots.append(got)
        inks.append(ink_pct(png) if os.path.exists(png) else 0.0)

    # 1. reset loop: corpus_result is written once per boot, so late samples must agree with `want`
    w = want.lower()
    if do_corpus and any(g is not None and g != w for g in gots):
        return False, f"RESET/UNSTABLE corpus_result {gots} (want {w}) — program is restarting"
    # 2. blank screen
    if max(inks) < min_ink:
        return False, f"BLANK screen after title (ink {max(inks):.1f}% < {min_ink}%)"
    # 3. still showing the title card long after the gate frame
    if os.path.exists(base) and all(same(base, p) for p in pngs if os.path.exists(p)):
        return False, "FROZEN — identical to the gate frame at every late sample (loop never ran?)"
    tag = "" if do_corpus else "  [ink-only: gate frame > max-gate, reset check skipped]"
    return True, f"ink {min(inks):.1f}–{max(inks):.1f}%{tag}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default=os.path.expanduser("~/biohack.net"))
    ap.add_argument("--only", default="")
    ap.add_argument("--rom"); ap.add_argument("--off"); ap.add_argument("--want")
    ap.add_argument("--len", type=int, default=2); ap.add_argument("--frames", type=int, default=500)
    ap.add_argument("--min-ink", type=float, default=0.5,
                    help="percent of non-black pixels required at some late sample")
    ap.add_argument("--max-gate", type=int, default=4000,
                    help="cap the gate frame used as the sampling base (see check() docstring)")
    ap.add_argument("--margins", default="900,2000",
                    help="frames to add to the gate frame when sampling (past title_end)")
    a = ap.parse_args()

    if not os.access(JGX, os.X_OK):
        sys.exit("display-check: build/jgxcheck missing — run dev/run.sh xcheck")
    margins = [int(x) for x in a.margins.split(",")]

    if a.rom:
        rows = [(os.path.basename(a.rom).replace(".sfc", ""), a.rom, a.off, a.len, a.want, a.frames)]
    else:
        man = os.path.join(a.site, "public", "play", "roms", "manifest.json")
        if not os.path.exists(man):
            sys.exit(f"display-check: no manifest at {man}")
        only = {s for s in a.only.split(",") if s}
        rows = []
        for r in json.load(open(man))["roms"]:
            sc = r.get("selfcheck")
            if not sc or (only and r["id"] not in only):
                continue
            rom = os.path.join(a.site, "public", "play", "roms", f"{r['id']}.sfc")
            rows.append((r["id"], rom, sc["off"], sc["len"], sc["want"], sc["frames"]))

    bad = []
    with tempfile.TemporaryDirectory() as td:
        for demo, rom, off, ln, want, frames in rows:
            if not os.path.exists(rom):
                print(f"  {demo:<18} MISSING {rom}"); bad.append(demo); continue
            ok, note = check(demo, rom, off, ln, want, frames, a.min_ink, margins, td, a.max_gate)
            # flush per demo: a full sweep is ~100 ROMs x 4 emulator runs, so buffered output
            # would show nothing for many minutes and look like a hang.
            print(f"  {demo:<18} {'PASS' if ok else 'FAIL'}  {note}", flush=True)
            if not ok:
                bad.append(demo)
    print(f"\ndisplay-check: {len(rows)-len(bad)} passed, {len(bad)} failed"
          + (f" — {', '.join(bad)}" if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
