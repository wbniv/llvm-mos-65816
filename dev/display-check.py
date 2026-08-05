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
     not for a wholly black or dead screen -- and since 2026-07-30 it additionally requires the
     spike to sit on a quiescent baseline, so it is silent while a demo wipes or rebuilds its
     picture (docs/plans/2026-07-30-blankscan-quiescence-gate.md). Neither restriction overlaps
     what this tool checks, so the two are complementary rather than redundant; and
  2. it runs each ROM at the manifest's `frames`, which is chosen so `corpus_result` is ready --
     and that is typically still DURING the title. Checking there inspects the title card, not the
     demo. So we deliberately sample well PAST that frame.

WHAT IT CATCHES  (be precise about this -- do not oversell it)
  * a blank/black screen after the title  -- the truncstair class;
  * a crash/reset loop, detected without needing a screenshot: `corpus_result` is written once per
    boot, so if it is unstable across late samples the program restarted (this is exactly the
    signal that proved truncstair was resetting -- it read partial folds 0x01F0/0x01FC);
  * a display frozen on the title card, i.e. the demo loop never started.

THE TWO WAYS THE FROZEN CHECK USED TO LIE  (2026-07-31 -- docs/investigations/
2026-07-31-frozen-trio-frozen-flag-discriminator.md; see same() and check() for the arithmetic)
  * SPATIALLY -- `same()` decimated to every 4th pixel, which samples one phase in 16. truchet's
    diagonal Truchet tiles change only in the other 15, so 2048 changed pixels registered as 0.
    Fixed: `same()` now compares every pixel.
  * TEMPORALLY -- the late samples sit at FIXED offsets from one base, so against a demo of period
    P their phases collapse to a cluster of width max(margins mod P). For lzdec (P = 142) the
    default margins reduce to 48 and 12, a 48-frame cluster that fits inside its 90-frame "holding
    the finished image" plateau. Fixed: a trip is now confirmed by an anti-aliasing phase burst.
And a third case that was never a defect at all: a demo that renders and then legitimately holds
forever (turtle-vm draws `nseg` segments and its loop then does nothing). That is reported as
STATIC, not FROZEN, distinguished by comparing against a near-boot anchor.

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
    """Do two captures show the same picture? Compares EVERY pixel -- deliberately.

    This used to decimate to every 4th pixel in x and y, which is safe for `ink_pct` (a dead screen
    is uniformly dead) but NOT for a difference test: a 4x4 decimation grid samples one phase of a
    16-pixel cell, so any content whose changes live in the other 15 phases is invisible. truchet
    is exactly that shape -- its Truchet tiles are 2-pixel-wide diagonal runs on an 8-pixel grid, so
    the pixels that change fall on a diagonal lattice with EXACTLY ZERO overlap with {x%4==0 and
    y%4==0}. Measured 2026-07-31 between truchet frames 800 and 1700: 2048 pixels differ at full
    resolution, and the old test saw 0 of them, so it called the demo FROZEN while it was animating
    (stride 1 -> 2048 visible, 2 -> 512, 3 -> 210, 4 -> 0, 5 -> 86; stride 4 is the pathological one).

    Full comparison costs ~57k pixel reads instead of ~3.6k. It runs a handful of times per demo,
    not per frame, so the sweep's cost is dominated by emulation and this is not worth aliasing for.
    """
    from PIL import Image
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    return ia.size == ib.size and ia.tobytes() == ib.tobytes()


def burst_probe(demo, rom, off, ln, want, start, base, td, n, stride):
    """Re-sample `n` frames from `start` at `stride`, looking for ANY departure from `base`.

    Returns the first differing frame number, or None if the picture held across the whole burst.
    Sizing rule: `stride` must be SMALLER than the narrowest moving phase and `n*stride` LARGER than
    the longest plausible period, or the burst can alias exactly like the cheap samples did. The
    defaults (8 x 25 = a 175-frame span) clear lzdec's worst case with room to spare -- its moving
    phase is 52 frames wide (52 > 25) inside a 142-frame period (142 < 175)."""
    for k in range(n):
        f = start + k * stride
        p = os.path.join(td, f"{demo}_burst{k}.png")
        run(rom, off, ln, want, f, p)
        if os.path.exists(p) and not same(base, p):
            return f
    return None


def check(demo, rom, off, ln, want, frames, min_ink, margins, td, max_gate,
          burst=8, burst_stride=25, early=180):
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
    # 3. still showing the title card long after the gate frame.
    #
    # The three cheap samples are NOT three independent looks at the animation. They sit at fixed
    # offsets from one base, so against a demo of period P their phases collapse to
    # {0, m mod P for m in margins} -- for lzdec (P = 142: 52 reveal frames + 90 hold frames) the
    # default margins reduce to 900 mod 142 = 48 and 2000 mod 142 = 12, a phase cluster only 48
    # frames wide inside a 142-frame cycle. That fits entirely inside lzdec's 90-frame "full image,
    # holding" plateau, so all three samples show the byte-identical held picture and the demo looks
    # frozen while it is in fact cycling (2026-07-31 discrimination probe: lzdec is identical over
    # frames 1400-1426 and then changes on EVERY frame 1427-1436).
    #
    # So a trip here is only a SUSPICION. Confirm it with a phase burst that cannot alias: stride
    # `burst_stride` (smaller than any plausible moving phase) across a span longer than any
    # plausible period. This runs only for demos that already tripped, so the sweep's cost is
    # unchanged; and it can only ever turn a FAIL into a PASS, never invent one.
    if os.path.exists(base) and all(same(base, p) for p in pngs if os.path.exists(p)):
        moved = burst_probe(demo, rom, off, ln, want, eff + margins[0], base, td,
                            burst, burst_stride)
        if moved is not None:
            return True, (f"ink {min(inks):.1f}–{max(inks):.1f}%  [CYCLIC: the cheap samples aliased "
                          f"the demo's period; frame {moved} differs from the gate frame]")
        # Nothing moved across a full-period burst either: the picture really is constant. Two very
        # different causes, and the pixels alone cannot separate them -- so ask whether the demo ever
        # rendered ANYTHING. `early` is captured close to boot; if the held picture differs from it,
        # the demo drew and then reached a fixed point (turtle-vm replays `nseg` segments at
        # SEGS_PER_FRAME and its `for(;;)` does nothing once `drawn == a.nseg` -- a DESIGNED endpoint,
        # the same "compute-then-hold" class the 60fps sweep records for lsystem/julia/fn-plot).
        # Only when the picture never changed from boot onward is this the failure the check was
        # built for: the demo loop never ran.
        epng = os.path.join(td, f"{demo}_early.png")
        run(rom, off, ln, want, early, epng)
        if os.path.exists(epng) and not same(epng, base):
            return True, (f"ink {min(inks):.1f}–{max(inks):.1f}%  [STATIC: rendered by frame {eff}, "
                          f"then holds — differs from frame {early}; compute-then-hold, not a freeze]")
        return False, (f"FROZEN — identical from frame {early} through every late sample "
                       f"(and across a {burst}x{burst_stride} phase burst): the loop never ran")
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
    ap.add_argument("--burst", type=int, default=8,
                    help="samples in the anti-aliasing confirmation burst (only for demos that "
                         "already look frozen; see burst_probe())")
    ap.add_argument("--burst-stride", type=int, default=25,
                    help="frame stride within the confirmation burst; burst*stride must exceed the "
                         "longest plausible demo period and stride must be under the narrowest "
                         "moving phase")
    ap.add_argument("--early", type=int, default=180,
                    help="near-boot anchor frame: a held picture that DIFFERS from it was rendered "
                         "and then held (compute-then-hold), which is not a freeze")
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
            ok, note = check(demo, rom, off, ln, want, frames, a.min_ink, margins, td, a.max_gate,
                             a.burst, a.burst_stride, a.early)
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
