# `turtle-vm` / `truchet` / `lzdec` — discriminating the FROZEN flags

**Date:** 2026-07-31 · **Trigger:** the republish batch's `dev/display-check.py` full sweep flagged
three demos `FROZEN — identical to the gate frame at every late sample (loop never ran?)`.
**Verdict: all three flags are false positives. No demo is defective.** Two independent detector
defects and one detector-semantics gap produced them.

| demo | verdict | one-line evidence |
|---|---|---|
| `lzdec` | **detector artifact** — temporal phase aliasing | identical over frames 1400–1426, then a **different picture on every frame** 1427→1459 |
| `truchet` | **detector artifact** — spatial subsample aliasing | frames 800 vs 1700 differ by **2048 pixels**, of which the detector's stride‑4 grid sampled **0** |
| `turtle-vm` | **designed endpoint**, not a freeze | draws `nseg` segments then its `for(;;)` does nothing; the held picture is the complete rosette |

The precedent this follows is `lsystem`'s BLANKSCAN flag, root-caused the same day as a detector
false positive (commit `5587462`, `docs/plans/2026-07-30-blankscan-quiescence-gate.md`). Same
shape, same conclusion: **the demos are innocent; the detector was measuring badly.**

---

## What the detector actually tested

`check()` in `dev/display-check.py` captured three pictures — the gate frame `eff`, then
`eff+900` and `eff+2000` — and declared FROZEN when `same()` reported all three identical.
`same()` compared **every 4th pixel in x and y**.

Both halves of that turn out to alias.

```
eff = min(frames, max_gate);  late = [eff+900, eff+2000]
FROZEN  <=>  same(base, late[0]) and same(base, late[1])
same(a,b) <=> all(pa[x,y]==pb[x,y] for y in range(0,224,4) for x in range(0,256,4))
```

Gate frames: `turtle-vm` 600, `truchet` 800, `lzdec` 500 — all under `max_gate` (4000), so
`eff == frames` and the samples are exactly 600/1500/2600, 800/1700/2800, 500/1400/2500.

---

## `lzdec` — temporal aliasing (detector artifact)

### Mechanism

`examples/snes/lzdec.c` is a **cycling** demo, not a one-shot one:

```c
#define REVEAL_PER_FRAME 5u   // cells revealed per frame
#define HOLD_FRAMES     90u   // pause with the full image before re-decoding
```

with `LZ_OUTLEN 256` (`examples/65816/lzdec.h`). So the cycle is

- **reveal phase** — `ceil(256/5) = 52` frames, a different picture every frame;
- **hold phase** — `HOLD_FRAMES = 90` frames showing the finished image, byte-identical throughout;
- then `lz_decode()` re-runs on the same stream and the canvas is cleared — producing the
  *identical* image again next cycle.

**Period P = 52 + 90 = 142 frames**, of which **~90 (63 %) are a completely static plateau**, and
the plateau image is the *same bytes* every cycle.

### The aliasing arithmetic

The three samples are not three independent looks at the animation — they sit at **fixed offsets
from one base**, so modulo the demo's period their phases collapse into a narrow cluster:

```
900  mod 142 = 48        (900 = 142*6 + 48)
2000 mod 142 = 12        (2000 = 142*14 + 12)
```

So the sampled phases are `{φ, φ+48, φ+12}` — a cluster only **48 frames wide inside a 142-frame
cycle**. A 48-frame-wide cluster fits comfortably inside the 90-frame static plateau. Frame numbers
900 and 2000 apart bought no phase diversity at all.

Measured against the observed restart at frame 1427 (`φ(f) = (f − 1427) mod 142`):

| sample | φ | phase |
|---|---|---|
| 500 | 67 | plateau |
| 1400 | 115 | plateau |
| 2500 | 79 | plateau |

All three land on the plateau — deterministically, every run, because the emulation is
deterministic. Not bad luck: a structural consequence of fixed offsets.

### Dense-sample evidence

Stride‑1 capture, full-resolution PNG hashes (`build/jgxcheck` from the worktree, published ROM):

```
frames 500, 1400 … 1426   ->  96c625b5   (27 consecutive frames, all identical — the plateau)
frame  1427               ->  ce9e33c3   <- canvas cleared, cycle restarts
frame  1428               ->  1ad4ae4e
frame  1429               ->  8434bcfe
frame  1430               ->  6da809db
… a DIFFERENT hash on every single frame through 1459 …
frame  1459               ->  0e8c5933
frames 1465, 1475         ->  e58e5e90, b23d6109   (still revealing)
frames 1485, 1495         ->  96c625b5   <- back to the SAME plateau image as frame 500
```

Thirty-three consecutive frames each showing a different picture is not a frozen display. The
return to the *exact* hash `96c625b5` at 1485/1495 also confirms the cycle model: the demo
re-decodes an identical stream to an identical image, which is precisely why every plateau sample
matches every other plateau sample.

Frame 1400 (plateau, complete image) versus frame 1431 (mid-reveal, four partial rows painted in)
were also inspected visually and are obviously different pictures.

**Verdict: `lzdec` is live and cycling. The FROZEN flag is a temporal sampling artifact.**

---

## `truchet` — spatial aliasing (detector artifact)

### Mechanism

`truchet` genuinely differs between the gate frame and the late samples — the detector simply could
not see it. Comparing frames 800 and 1700 at full resolution:

```
total differing px: 2048

joint (x%4, y%4) histogram of the 2048 differing pixels:
  y%4=0: x%4=0:   0  x%4=1: 256  x%4=2: 256  x%4=3:   0
  y%4=1: x%4=0:   0  x%4=1: 256  x%4=2: 256  x%4=3:   0
  y%4=2: x%4=0: 256  x%4=1:   0  x%4=2:   0  x%4=3: 256
  y%4=3: x%4=0: 256  x%4=1:   0  x%4=2:   0  x%4=3: 256

pixels the detector actually samples (x%4==0 and y%4==0): 0
```

`same()` sampled `{x%4==0 and y%4==0}` — the one cell of that table containing **zero** of the 2048
changed pixels. The changed pixels form a diagonal 2×2-blocked lattice, which is exactly the shape
of a Truchet tiling: 2‑pixel-wide diagonal runs on an 8‑pixel tile grid. The decimation grid and the
content grid are commensurate and out of phase, so the test was blind by construction, not by luck.

Sensitivity to the stride confirms it is the stride and not the content:

```
  stride 1: 2048 differing pixels visible
  stride 2:  512
  stride 3:  210
  stride 4:    0     <- the value the detector used
  stride 5:   86
```

The changes themselves are real content: 1672 px went `(84,0,181)` purple → `(181,181,181)` white
and 376 px went `(255,0,122)` → `(122,0,255)`, i.e. the energy-band cells of the maze
(`cycle_palette()` rewrites `pal[2]`/`pal[3]` and `draw_maze()` redraws every `STEP_EVERY = 6`
vblanks).

### Late-region liveness

`truchet`'s late cadence is slow — roughly one visible change per 40–50&nbsp;frames — which is why a
short window looked static:

```
frames 1700 … 1732  ->  177fcfc5
frames 1748, 1764, 1780  ->  7e108a52
frame  1900  ->  544d3f50
frame  2000  ->  6da0b129
```

Four distinct pictures across the late window. **Verdict: `truchet` is live. The FROZEN flag is a
spatial subsampling artifact**, and it would have fired even with a perfect sampling schedule,
because the base-vs-late comparison itself was blind.

---

## `turtle-vm` — a designed endpoint, not a freeze

### The picture really is constant

Unlike the other two, `turtle-vm`'s display genuinely never changes again. Full-resolution hashes
are a single value across every frame sampled:

```
frames 600, 900, 1500, 2600, 2601 … 2615  ->  23f23e7dbcc0009dc8dc2e59cab50225   (one distinct image)
```

### …and that is what the demo is written to do

```c
uint16_t drawn = 0;
for (;;) {
  for (uint8_t k = 0; k < SEGS_PER_FRAME && drawn < a.nseg; k++, drawn++) {
    Seg s = a.segs[drawn];
    canvas_line(&a.canvas, …);
  }
  display_frame(&a.screen);
}
```

`SEGS_PER_FRAME` is 2 and the guard is `drawn < a.nseg`. Once the recorded path is fully replayed
the inner loop is a no-op forever: the loop is still running, it simply has nothing left to draw.
The held picture was inspected and is the **complete rosette** — the finished artwork, not a
partial or corrupted screen. The corpus gate is green at `0x4007` on the same frames, so the VM ran
to completion.

This is the same **compute-then-hold** class the 60&nbsp;fps sweep already records for `lsystem`,
`julia`, `fn-plot` and `mandel-float` (`docs/investigations/2026-07-27-60fps-demo-sweep.md`, rows
with `d1`/`d60` of `0.0`/`0.0`). The sweep's `d60 = 0.73` for `turtle-vm` was measured at frames
500→560, i.e. while it was still drawing; drawing completes between frame 560 and frame 600, which
is why the gate frame (600) already shows the final image.

**Verdict: not a defect and not a detector-sampling artifact — a detector-*semantics* gap.** The
check cannot tell "rendered, then holds" from "never rendered" by pixels alone, because both look
constant. No demo change is warranted; `turtle-vm.c` is left untouched.

---

## Fixes

`dev/display-check.py` has no script callers (`dev/*.sh`, `Taskfile.yml`, CI are all clean of it) —
it is a hand-run tool, so the blast radius is the tool itself.

### Coordination note — the patch is NOT applied on `main`

`dev/display-check.py` is **dirty on `main` with another session's in-flight edits** (a docstring
change recording the 2026‑07‑30 BLANKSCAN quiescence gate — comment-only, and it does **not**
address sampling or aliasing, so it does not overlap this fix). Per the hot-shared-tree rule the
change was made on the throwaway worktree only and is recorded here as a patch for whoever owns
that file to apply.

### Three changes

1. **`same()` compares every pixel** instead of every 4th. Kills the `truchet` class outright.
   `ink_pct()` keeps its decimation — a dead screen is uniformly dead, so decimation is safe there;
   a *difference* test is the one place it is not.
2. **A FROZEN trip is only a suspicion, confirmed by an anti-aliasing phase burst.** `burst_probe()`
   re-samples 8 frames at stride 25 (a 175-frame span) from the first late margin. Sizing rule:
   stride below the narrowest moving phase, span above the longest plausible period — for `lzdec`,
   25 < 52 and 175 > 142, so a hit is guaranteed. This runs **only for demos that already tripped**,
   so the sweep's cost is unchanged.
3. **A near-boot anchor separates `STATIC` from `FROZEN`.** If the picture held across the burst but
   *differs* from an early frame (`--early`, default 180), the demo rendered and then reached a
   fixed point — reported as a passing `STATIC` note. Only a picture unchanged from boot through
   every late sample is the failure the check was built for.

All three are conservative in the required direction: each can only ever turn a FAIL into a PASS,
never invent one.

### Patch (against `dev/display-check.py` at `2343db7`)

```diff
diff --git a/dev/display-check.py b/dev/display-check.py
index 3381535..587b4e0 100755
--- a/dev/display-check.py
+++ b/dev/display-check.py
@@ -26,6 +26,19 @@ WHAT IT CATCHES  (be precise about this -- do not oversell it)
     signal that proved truncstair was resetting -- it read partial folds 0x01F0/0x01FC);
   * a display frozen on the title card, i.e. the demo loop never started.
 
+THE TWO WAYS THE FROZEN CHECK USED TO LIE  (2026-07-31 -- docs/investigations/
+2026-07-31-frozen-trio-frozen-flag-discriminator.md; see same() and check() for the arithmetic)
+  * SPATIALLY -- `same()` decimated to every 4th pixel, which samples one phase in 16. truchet's
+    diagonal Truchet tiles change only in the other 15, so 2048 changed pixels registered as 0.
+    Fixed: `same()` now compares every pixel.
+  * TEMPORALLY -- the late samples sit at FIXED offsets from one base, so against a demo of period
+    P their phases collapse to a cluster of width max(margins mod P). For lzdec (P = 142) the
+    default margins reduce to 48 and 12, a 48-frame cluster that fits inside its 90-frame "holding
+    the finished image" plateau. Fixed: a trip is now confirmed by an anti-aliasing phase burst.
+And a third case that was never a defect at all: a demo that renders and then legitimately holds
+forever (turtle-vm draws `nseg` segments and its loop then does nothing). That is reported as
+STATIC, not FROZEN, distinguished by comparing against a near-boot anchor.
+
 WHAT IT DOES NOT CATCH
   * a picture that is live and plausible but WRONG -- the mvscrl class. Detecting that needs a
     demo-specific claim about what the pixels mean, which this tool has no way to know. Do not
@@ -62,13 +75,44 @@ def ink_pct(png):
 
 
 def same(a, b):
+    """Do two captures show the same picture? Compares EVERY pixel -- deliberately.
+
+    This used to decimate to every 4th pixel in x and y, which is safe for `ink_pct` (a dead screen
+    is uniformly dead) but NOT for a difference test: a 4x4 decimation grid samples one phase of a
+    16-pixel cell, so any content whose changes live in the other 15 phases is invisible. truchet
+    is exactly that shape -- its Truchet tiles are 2-pixel-wide diagonal runs on an 8-pixel grid, so
+    the pixels that change fall on a diagonal lattice with EXACTLY ZERO overlap with {x%4==0 and
+    y%4==0}. Measured 2026-07-31 between truchet frames 800 and 1700: 2048 pixels differ at full
+    resolution, and the old test saw 0 of them, so it called the demo FROZEN while it was animating
+    (stride 1 -> 2048 visible, 2 -> 512, 3 -> 210, 4 -> 0, 5 -> 86; stride 4 is the pathological one).
+
+    Full comparison costs ~57k pixel reads instead of ~3.6k. It runs a handful of times per demo,
+    not per frame, so the sweep's cost is dominated by emulation and this is not worth aliasing for.
+    """
     from PIL import Image
-    pa = Image.open(a).convert("RGB").load()
-    pb = Image.open(b).convert("RGB").load()
-    return all(pa[x, y] == pb[x, y] for y in range(0, 224, 4) for x in range(0, 256, 4))
+    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
+    return ia.size == ib.size and ia.tobytes() == ib.tobytes()
+
+
+def burst_probe(demo, rom, off, ln, want, start, base, td, n, stride):
+    """Re-sample `n` frames from `start` at `stride`, looking for ANY departure from `base`.
+
+    Returns the first differing frame number, or None if the picture held across the whole burst.
+    Sizing rule: `stride` must be SMALLER than the narrowest moving phase and `n*stride` LARGER than
+    the longest plausible period, or the burst can alias exactly like the cheap samples did. The
+    defaults (8 x 25 = a 175-frame span) clear lzdec's worst case with room to spare -- its moving
+    phase is 52 frames wide (52 > 25) inside a 142-frame period (142 < 175)."""
+    for k in range(n):
+        f = start + k * stride
+        p = os.path.join(td, f"{demo}_burst{k}.png")
+        run(rom, off, ln, want, f, p)
+        if os.path.exists(p) and not same(base, p):
+            return f
+    return None
 
 
-def check(demo, rom, off, ln, want, frames, min_ink, margins, td, max_gate):
+def check(demo, rom, off, ln, want, frames, min_ink, margins, td, max_gate,
+          burst=8, burst_stride=25, early=180):
     """One demo. Returns (ok, note).
 
     Sampling is capped: emulation costs ~85 fps here, and a few demos have huge gate frames
@@ -96,9 +140,42 @@ def check(demo, rom, off, ln, want, frames, min_ink, margins, td, max_gate):
     # 2. blank screen
     if max(inks) < min_ink:
         return False, f"BLANK screen after title (ink {max(inks):.1f}% < {min_ink}%)"
-    # 3. still showing the title card long after the gate frame
+    # 3. still showing the title card long after the gate frame.
+    #
+    # The three cheap samples are NOT three independent looks at the animation. They sit at fixed
+    # offsets from one base, so against a demo of period P their phases collapse to
+    # {0, m mod P for m in margins} -- for lzdec (P = 142: 52 reveal frames + 90 hold frames) the
+    # default margins reduce to 900 mod 142 = 48 and 2000 mod 142 = 12, a phase cluster only 48
+    # frames wide inside a 142-frame cycle. That fits entirely inside lzdec's 90-frame "full image,
+    # holding" plateau, so all three samples show the byte-identical held picture and the demo looks
+    # frozen while it is in fact cycling (2026-07-31 discrimination probe: lzdec is identical over
+    # frames 1400-1426 and then changes on EVERY frame 1427-1436).
+    #
+    # So a trip here is only a SUSPICION. Confirm it with a phase burst that cannot alias: stride
+    # `burst_stride` (smaller than any plausible moving phase) across a span longer than any
+    # plausible period. This runs only for demos that already tripped, so the sweep's cost is
+    # unchanged; and it can only ever turn a FAIL into a PASS, never invent one.
     if os.path.exists(base) and all(same(base, p) for p in pngs if os.path.exists(p)):
-        return False, "FROZEN — identical to the gate frame at every late sample (loop never ran?)"
+        moved = burst_probe(demo, rom, off, ln, want, eff + margins[0], base, td,
+                            burst, burst_stride)
+        if moved is not None:
+            return True, (f"ink {min(inks):.1f}–{max(inks):.1f}%  [CYCLIC: the cheap samples aliased "
+                          f"the demo's period; frame {moved} differs from the gate frame]")
+        # Nothing moved across a full-period burst either: the picture really is constant. Two very
+        # different causes, and the pixels alone cannot separate them -- so ask whether the demo ever
+        # rendered ANYTHING. `early` is captured close to boot; if the held picture differs from it,
+        # the demo drew and then reached a fixed point (turtle-vm replays `nseg` segments at
+        # SEGS_PER_FRAME and its `for(;;)` does nothing once `drawn == a.nseg` -- a DESIGNED endpoint,
+        # the same "compute-then-hold" class the 60fps sweep records for lsystem/julia/fn-plot).
+        # Only when the picture never changed from boot onward is this the failure the check was
+        # built for: the demo loop never ran.
+        epng = os.path.join(td, f"{demo}_early.png")
+        run(rom, off, ln, want, early, epng)
+        if os.path.exists(epng) and not same(epng, base):
+            return True, (f"ink {min(inks):.1f}–{max(inks):.1f}%  [STATIC: rendered by frame {eff}, "
+                          f"then holds — differs from frame {early}; compute-then-hold, not a freeze]")
+        return False, (f"FROZEN — identical from frame {early} through every late sample "
+                       f"(and across a {burst}x{burst_stride} phase burst): the loop never ran")
     tag = "" if do_corpus else "  [ink-only: gate frame > max-gate, reset check skipped]"
     return True, f"ink {min(inks):.1f}–{max(inks):.1f}%{tag}"
 
@@ -115,6 +192,16 @@ def main():
                     help="cap the gate frame used as the sampling base (see check() docstring)")
     ap.add_argument("--margins", default="900,2000",
                     help="frames to add to the gate frame when sampling (past title_end)")
+    ap.add_argument("--burst", type=int, default=8,
+                    help="samples in the anti-aliasing confirmation burst (only for demos that "
+                         "already look frozen; see burst_probe())")
+    ap.add_argument("--burst-stride", type=int, default=25,
+                    help="frame stride within the confirmation burst; burst*stride must exceed the "
+                         "longest plausible demo period and stride must be under the narrowest "
+                         "moving phase")
+    ap.add_argument("--early", type=int, default=180,
+                    help="near-boot anchor frame: a held picture that DIFFERS from it was rendered "
+                         "and then held (compute-then-hold), which is not a freeze")
     a = ap.parse_args()
 
     if not os.access(JGX, os.X_OK):
@@ -141,7 +228,8 @@ def main():
         for demo, rom, off, ln, want, frames in rows:
             if not os.path.exists(rom):
                 print(f"  {demo:<18} MISSING {rom}"); bad.append(demo); continue
-            ok, note = check(demo, rom, off, ln, want, frames, a.min_ink, margins, td, a.max_gate)
+            ok, note = check(demo, rom, off, ln, want, frames, a.min_ink, margins, td, a.max_gate,
+                             a.burst, a.burst_stride, a.early)
             # flush per demo: a full sweep is ~100 ROMs x 4 emulator runs, so buffered output
             # would show nothing for many minutes and look like a hang.
             print(f"  {demo:<18} {'PASS' if ok else 'FAIL'}  {note}", flush=True)
```

---

## Verification

### 1. Reproduce the sweep's flags with the unpatched detector (`2343db7`)

```
$ python3 dev/.display-check-HEAD.py --only turtle-vm,truchet,lzdec
  turtle-vm          FAIL  FROZEN — identical to the gate frame at every late sample (loop never ran?)
  truchet            FAIL  FROZEN — identical to the gate frame at every late sample (loop never ran?)
  lzdec              FAIL  FROZEN — identical to the gate frame at every late sample (loop never ran?)

display-check: 0 passed, 3 failed — turtle-vm, truchet, lzdec
```

**PASS** — all three flags reproduce exactly, against the published ROMs, so the probe below is
measuring the same thing the sweep did.

### 2. The same three demos through the patched detector

```
$ python3 dev/display-check.py --only turtle-vm,truchet,lzdec
  turtle-vm          PASS  ink 7.6–7.6%  [STATIC: rendered by frame 600, then holds — differs from frame 180; compute-then-hold, not a freeze]
  truchet            PASS  ink 6.9–6.9%
  lzdec              PASS  ink 22.9–22.9%  [CYCLIC: the cheap samples aliased the demo's period; frame 1450 differs from the gate frame]

display-check: 3 passed, 0 failed
```

**PASS** — and each clears by the mechanism its diagnosis predicts, which is the real check here:

- `truchet` passes **without tripping at all** — the full-pixel `same()` sees the 2048 changed
  pixels, so the burst never runs. Fix 1 alone accounts for it.
- `lzdec` still trips the cheap test (its three samples genuinely are the identical plateau image),
  and the burst resolves it at **frame 1450** — the third burst sample, `1400 + 2*25`, which the
  dense probe independently places inside the reveal phase (`1427…~1479`). Fix 2.
- `turtle-vm` trips and the burst finds nothing, correctly — the picture really is constant — and
  the near-boot anchor then separates "rendered, then holds" from "never rendered". Fix 3.

### 3. The three demos still pass their own corpus gates

Display liveness was the question, not correctness, but the gates confirm the ROMs are unchanged
and green:

```
$ dev/run.sh lzdec
==> host oracle: lzdec gate hash = 0x0100
==> built build/lzdec.sfc (+mos-a16); corpus_result @ WRAM 0x14e9
==> disasm gate (LZ77 back-reference byte-stream decoder, native-16, no libcall)
    PASS  LZ_STREAM-refs=6  sta=27  arith-libcalls=0  rep/sep=52  (LZ back-ref decoder)
==> bsnes-jg: render + framebuffer dump (build/lzdec-jg.png) + assert
SMOKE: PASS off=0x14E9 len=2 got=0x0100 (ran 500 frames, bsnes-jg)
    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)
RESULT: PASS — LZ77 image-decompress reveal rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x0100 host == +mos-a16

$ dev/run.sh truchet
==> host oracle: Truchet bitfields gate hash = 0xB3E6
==> built build/truchet.sfc (+mos-a16); corpus_result @ WRAM 0x15e6
==> disasm gate (packed-bitfield insert/extract codegen)
    PASS  and=13  ora=8  shift=32  rep/sep=59  libcalls=0  (bitfield insert/extract, native-16)
==> bsnes-jg: render + framebuffer dump (build/truchet-jg.png) + assert
SMOKE: PASS off=0x15E6 len=2 got=0xB3E6 (ran 800 frames, bsnes-jg)
    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)
RESULT: PASS — Truchet bitfields rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xB3E6 host == +mos-a16

$ dev/run.sh turtle-vm
==> host oracle: Bytecode-VM Turtle gate hash = 0x4007
==> built build/turtle-vm.sfc (+mos-a16); corpus_result @ WRAM 0x171f
==> disasm gate (jump-table + function-pointer dispatch codegen)
    PASS  jump-table=1  __call_indir=1  __mulsi3=2  rep/sep=155  (indirect dispatch, native-16)
==> bsnes-jg: render + framebuffer dump (build/turtle-vm-jg.png) + assert
SMOKE: PASS off=0x171F len=2 got=0x4007 (ran 600 frames, bsnes-jg)
    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)
RESULT: PASS — Bytecode-VM Turtle rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x4007 host == +mos-a16
```

**PASS** — three green gates, MAME legs SKIP for the usual missing-IPL reason. As expected: this
was never a correctness question.

---

## Method / reproduction

Ran from a throwaway worktree (`throwaway/frozen-trio`) with `build/llvm-mos-install`,
`build/install`, `build/jgxcheck` and `vendor/bsnes-jg` hard-linked in from the main checkout, per
`docs/howto-feature-worktree.md`. Probes drove `build/jgxcheck` directly against the **published**
ROMs in `~/biohack.net/public/play/roms/` — the exact artifacts the sweep flagged:

```
build/jgxcheck <rom.sfc> vendor/bsnes-jg/Database <off> <len> <want> <frame> <out.png>
```

Each invocation emulates from reset to `<frame>` and dumps one PNG, so emulation is deterministic
and a frame number uniquely identifies a picture. Frames were compared by full-resolution hash,
never by the detector's decimated view (that being the thing under test).

`dev/roms` is absent in this environment, so the MAME legs SKIP; bsnes-jg carries the verdicts, per
repo convention.

## Not done / follow-ups

- The patch is **not applied on `main`** — see the coordination note above. It needs to land on
  `dev/display-check.py` once the concurrent session's edits are committed.
- A **full 100-ROM sweep with the patched detector was not run**. The patch only ever downgrades
  FAILs, so it cannot introduce a new failure, but the sweep is the way to confirm no *other* demo
  was passing only because `same()` was blind (a demo genuinely stuck could have been reported as
  passing for an unrelated reason — the same-stride blindness cuts both ways for the RESET and BLANK
  checks it does not touch).
- `turtle-vm`'s `STATIC` outcome is reported as a passing note. If the roster grows many
  compute-then-hold demos it may be worth a manifest field so the intent is declared rather than
  inferred, but that is a schema decision and is deliberately not taken here.

---

## 2026-08-01 — full sweep with the patched detector, vs the 2026-07-31 baseline

The follow-up above ("a full 100-ROM sweep ... was not run") is now closed. Ran the patched
`dev/display-check.py` (commit `d3000d7`, plus another session's still-unstaged docstring-only
hunk — verified with `git diff dev/display-check.py` to touch comment prose only, not `same()` /
`check()` / `burst_probe()`, so it does not affect this result and was deliberately left untouched)
against the full live manifest:

```
$ python3 dev/display-check.py
  <118 demo lines>
display-check: 117 passed, 1 failed — svx2-fastrom-video
```

### Baseline scope

The 2026-07-31 baseline (this doc's own reproduction, and `docs/plans/2026-07-30-blankscan-quiescence-gate.md`
line 213: "the batch's `display-check.py` sweep flagged `turtle-vm`/`truchet`/`lzdec` as FROZEN")
ran against the 114-ROM manifest published by `~/biohack.net`'s `530bf5c` (2026-07-28) and was not
touched again until `7890ce3` (2026-07-31 09:53) — after the baseline sweep. No other failure was
named in either doc, so the baseline is: **114 ROMs, 111 implicit PASS, 3 FROZEN-FAIL** (the trio).

Between the baseline sweep and this one, `~/biohack.net`'s manifest grew by 4 ROMs with no prior
`display-check.py` verdict to diff against (confirmed via `git log -- public/play/roms/manifest.json`):
`09eb0fb` (13:44) added the three `cartsize-*` ROMs, `cdaa6f4` (15:10) added `svx2-fastrom-video`.
114 baseline + 4 new = 118, matching this sweep's total.

### Delta table (114 baseline-covered demos)

| class | count | demos |
|---|---|---|
| (a) expected trio fix (FAIL→PASS, by predicted mechanism) | 3 | `turtle-vm`, `truchet`, `lzdec` |
| (b) new FAIL exposed by full-pixel `same()` (previously blind PASS) | 0 | none |
| (c) FROZEN/STATIC reclassification (tag changed, PASS/FAIL didn't) | 0 | none |
| (d) unchanged (PASS before, PASS now, no tag) | 111 | all remaining baseline demos |

Verdict-change rate: 3/114 = 2.6% — well under the 20% threshold that would suggest a detector bug
rather than reclassification.

**(a) — the trio, each clearing by its diagnosed mechanism, exactly as predicted above:**

| demo | baseline | new | evidence |
|---|---|---|---|
| `turtle-vm` | FAIL FROZEN | PASS | `ink 7.6–7.6% [STATIC: rendered by frame 600, then holds — differs from frame 180; compute-then-hold, not a freeze]` |
| `truchet` | FAIL FROZEN | PASS | `ink 6.9–6.9%` — full-pixel `same()` now sees the late samples differ, so it never even enters the FROZEN-suspicion branch |
| `lzdec` | FAIL FROZEN | PASS | `ink 22.9–22.9% [CYCLIC: the cheap samples aliased the demo's period; frame 1450 differs from the gate frame]` |

**(b) — none.** The fix's own "not done" note worried that some *other* demo might have been
PASSing only because the old decimated `same()` happened to see the sampled points move while the
demo was actually stuck. Not the case: zero baseline PASS demos flipped to FAIL.

**(c) — none.** Grepping every bracket-tagged line in the full output, the only `STATIC`/`CYCLIC`
tags belong to the trio itself (already counted in (a)). No other baseline demo tripped the new
suspicion → confirmation branch (`all(same(base, p) ...)` in `check()`). The four
`[ink-only: gate frame > max-gate, reset check skipped]` tags seen on `buddhabrot`, `mandel-display`,
`mandel-oop`, `lzss-gallery` are pre-existing, unrelated behavior (gated on `frames > max_gate`,
unchanged by this patch).

**(d) — 111 demos**, PASS in both sweeps with the same plain `ink X–Y%` shape.

### New ROMs (no baseline verdict — added to the manifest after the baseline sweep)

| demo | result | evidence |
|---|---|---|
| `cartsize-hirom-4m` | PASS | `ink 95.7–96.4%` |
| `cartsize-exhirom-6m` | PASS | `ink 47.5–95.7%` |
| `cartsize-exhirom-8m` | PASS | `ink 95.7–96.4%` |
| `svx2-fastrom-video` | **FAIL** | `RESET/UNSTABLE corpus_result ['0x4f', '0x4f'] (want 0x00) — program is restarting` |

### The one FAIL — a finding, not a fix

`svx2-fastrom-video` fails the very first check in `check()` (`corpus_result` vs `want`), a code
path that is byte-for-byte unchanged by this patch — unrelated to `same()`, `STATIC`, or `CYCLIC`.
Both late samples read a *stable* `0x4f` against a manifest that expects `0x00`, so this is a
consistently-wrong self-check value rather than literal frame-to-frame instability; the branch name
("RESET/UNSTABLE") covers both shapes. This ROM's `selfcheck` (`off=0x29`, `want=0x00`,
`frames=1200`) was last revised in `~/biohack.net` commit `d28abc3` (2026-07-31 21:54, "fix SVX2 FPS
and dashboard alignment"), same day as this sweep, and has no prior `display-check.py` result to
compare against. **Reporting only — not investigated or fixed here**, per the svx2 cartridge work's
own plan (`docs/plans/2026-07-31-svx2-animated-video-cartridge.md`), which is still in progress
("60 fps optimization and ExHiROM follow-up remain") and out of this task's scope.

### Verdict

The patched detector's full-sweep behavior matches its design intent exactly: it downgraded only
the three demos it was built to fix, by their diagnosed mechanisms, and introduced zero new FAILs
or reclassifications among the 111 demos it left alone. The one FAIL in the sweep belongs to a ROM
that postdates the baseline entirely and fails on an unrelated, pre-existing check.
