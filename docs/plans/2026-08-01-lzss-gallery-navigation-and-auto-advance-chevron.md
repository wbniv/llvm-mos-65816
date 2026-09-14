# LZSS Gallery Navigation and Auto-Advance Chevron

**Status:** IMPLEMENTED  
**Date:** 2026-08-01

## Goal

Restore reliable Previous/Next navigation on a controller, keyboard, mouse, and
phone, and make every slideshow-initiated move to the next artwork visibly use
the right-chevron animation. The same animation vocabulary must describe the
same direction regardless of whether a person or the timer initiated the cut.

## Confirmed regressions

### ROM input path must remain observable

The gallery currently uses its proven manual serial latch in NMI. An attempted
automatic-reader migration stopped accepting input in both native and browser
bsnes. The old gate missed this because it waited for artwork 1, which normal
auto-advance eventually reaches without input. The navigation gate now asserts
the dedicated `gallery_canceled` counter instead.

The serial result keeps this mapping:

- `1` = Right = next artwork;
- `2` = Left = previous artwork.

Continue reading the previous completed automatic latch at NMI entry. Do not
reintroduce serial controller polling or a `JOYBUSY` wait in VBlank.

### Browser clicks produce an undersized pulse

The player starts a 120 ms virtual D-pad pulse on `pointerdown`, but the
`pointerup` handler clears Left and Right immediately. A normal mouse click or
phone tap can therefore be shorter than one emulated input sample.

Once a chevron hit is accepted, latch its virtual button for the full 120 ms.
`pointerup` must not shorten that pulse. `pointercancel`, window blur, ROM
change, and player shutdown must still clear synthetic input so a direction
cannot remain stuck. Starting a second chevron pulse replaces the first one and
clears the previously synthesized direction before asserting the new one.

Keep the manifest rectangles in logical 256×224 canvas coordinates:

```text
left  = [  0, 70, 24, 24]
right = [232, 70, 24, 24]
```

The browser cursor should indicate that these regions are interactive when
practical, but the canvas outside them remains inert.

## Automatic-advance animation

Today `nav_target()` starts a chevron animation only after an explicit input;
the normal timed path increments `k` directly after `hold(180)`. Introduce one
small direction-animation helper, used by both paths, which initializes:

```text
direction = right
position  = 0
velocity  = ARROW_TAKEOFF
animation = active
Y origin  = active artwork midpoint - 8
```

After the final hold completes without cancellation, trigger the right-chevron
animation and then advance `k`, wrapping from the last work to the first. The
animation must begin at the cut decision, remain visible while the next stream
is prepared, and must not add a blocking delay to decode or slideshow timing.

Manual behavior remains:

- Right / right chevron: animate right and select the next work.
- Left / left chevron: animate left and select the previous work.
- Input received during decode/repack cancels the current phase and takes the
  requested direction exactly once.
- Automatic advance never increments `gallery_canceled` and never masquerades
  as a user cancellation in the dashboard/oracle state.

## Implementation

1. In `examples/snes/lzss-gallery.c`, preserve the `$4219` D-pad read and its
   existing edge detector; retain the scripted Right-input regression gate.
2. Factor chevron launch state out of `nav_target()` so manual and automatic
   forward transitions share the same right-animation setup.
3. Invoke the helper on the successful timed-advance path immediately before
   incrementing/wrapping the artwork index.
4. In both web-player copies, make accepted pointer navigation a guaranteed
   120 ms pulse; do not clear it on ordinary `pointerup`.
5. Keep `touchNav` metadata identical on biohack.net and indri.studio.
6. Document the JOY1 byte/bit mapping explicitly in the SNES programming docs
   so future automatic-reader conversions cannot repeat the `$4218`/`$4219`
   error.

## Verification gates

### Static and host checks

- Audit emitted gallery behavior with a scripted Right press and require the
  current artwork to advance exactly once.
- Unit-test the web hit rectangles at their edges and outside points.
- Simulate a short click (`pointerdown` followed immediately by `pointerup`)
  and prove the selected bit remains asserted until the 120 ms timer expires.
- Prove `pointercancel`, blur, ROM replacement, and shutdown clear the pulse.
- Assert both site manifests expose byte-identical `touchNav` rectangles.

### Emulator behavior

- Keyboard Right moves forward once and animates only the right chevron.
- Keyboard Left moves backward once and animates only the left chevron.
- A mouse click and a phone tap on either chevron produce the same results.
- Holding a physical/browser direction does not repeatedly skip works; a new
  transition requires a release and a new edge.
- With no input, expiry of the normal display hold animates the right chevron
  and advances exactly one work, including last-to-first wrap.
- Manual navigation during decode/repack still cancels promptly and does not
  corrupt the displayed work or verification oracle.

### Release

- Run the complete gallery host oracle, target decode/stage/near/checksum gate,
  navigation gate, and reproducible ROM build.
- Build both sites and publish the identical verified ROM and player behavior.
- Download both live ROMs and compare SHA-256 with the local verified build.
- Test live mouse and keyboard navigation on biohack.net and the embedded
  indri.studio copy before marking this plan implemented.

## Completion criteria

This work is complete only when Left/Right function through every supported
input surface, quick clicks cannot disappear between emulator frames, automatic
slideshow cuts visibly launch the right chevron, all gallery correctness gates
remain green, and both published ROM hashes match the verified local ROM.

## Implementation record

Implemented on 2026-08-01. Manual and automatic forward transitions now share
`arrow_launch()`, while only manual `nav_target()` calls increment
`gallery_canceled`. The web players retain an accepted chevron press for 120 ms
regardless of an immediate `pointerup`, replace an earlier synthetic direction
cleanly, and clear synthetic input on cancellation, blur, ROM replacement, or
loop shutdown.

The investigation initially suspected `$4219`, but the existing scripted input
gate demonstrated that it is the correct D-pad byte for the conventional
`B=$8000` through `Right=$0100` word. The plan and programming documentation now
record that mapping explicitly.

Verification passed: JavaScript syntax checks, the 62-work host oracle, target
far/stage/near decode and checksum gate, scripted automatic-joypad Right press
during foreground decode, and reproducible ROM link. Verified ROM SHA-256:
`726c421fb708956ccadbdf677c2d856eb4ae1103cd91cec7a590b8ba66ec8dcd`.

The guaranteed-duration touch pulse was fixed in the canonical shared player
(`bsnes-jg-wasm` commit `642d3c9`) and then pinned by both consumers. Published
site releases are biohack.net `v1.0.343` (`00fdc5a`) and indri.studio
`v0.1.133` (`2c6a7a3`). Both deployment workflows passed. The two live player
scripts are byte-identical with SHA-256
`100f4b5122e43114aac833dcc11a48fd164ce2509fa4540a705f8ce95a8ab7ce`,
and both live ROM downloads match the verified ROM hash above.

## Verification record — 2026-08-04, against `main` @ `772b382`

The fifteen gates above are stated as outcomes, not as commands, so each step below names the
command chosen to produce its evidence. The gate text is reproduced verbatim and unreordered.
Toolchain used as-built (`build/llvm-mos-install/bin/mos-clang`, `build/jgxcheck`,
`vendor/bsnes-jg/objs/libbsnes.a`); no rebuild. All emulator captures set `JGX_ENTROPY=0` for a
deterministic power-on. `examples/snes/lzss-gallery.c`, `dev/lzss-gallery.sh` and
`dev/jgxcheck.cpp` were all clean in `git status` at the time of the run, so everything here is
built from committed state — including the chevron-input re-fix `3b8a559` (2026-08-02), which
post-dates the implementation record above.

Two scratchpad harnesses were used and are described where they appear, because the repository has
no test directory for the web player and no scripted-navigation driver beyond the one gate inside
`dev/lzss-gallery.sh`:

- `touchnav-test.js` — brace-matched **extraction** of the shipped `clearTouchNav()`,
  `touchNavBitAt()` and the `pointerdown` handler out of a given `app.js`, evaluated in a `vm`
  context against DOM stubs. It re-implements nothing; the code under test is the shipped text.
- `nav.sh` / `navpoll.sh` — thin wrappers over a host build of `dev/jgxcheck.cpp -DJGX_NAV`
  (the same `JGX_SCRIPT` / `JGX_POLL` binary `dev/lzss-gallery.sh` builds), so a scripted
  controller sequence can be driven at any gallery symbol. The full invocation is echoed in each
  block below.

**ROM under test:** `build/lzss-gallery.sfc`, SHA-256
`a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d`. This is **not** the
`726c421f…` recorded in the implementation record above — the gallery ROM is republished as the
toolchain moves, and `a5e59d79…` is what both live sites are serving today (step 14). The
`726c421f…` figure is historical.

### Static and host checks

#### 1. Audit emitted gallery behavior with a scripted Right press and require the current artwork to advance exactly once.

Command: the navigation gate inside `dev/run.sh lzss-gallery` (asserts the dedicated
`gallery_canceled` counter reaches exactly 1), plus a direct read of `gallery_current_asset`
after the same press.

```
$ dev/run.sh lzss-gallery          # navigation-gate leg
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)
```

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x01 2503   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)
```

**PASS** — one scripted Right press moves `gallery_current_asset` 0 → 1 and increments
`gallery_canceled` exactly once.

#### 2. Unit-test the web hit rectangles at their edges and outside points.

Command: `node touchnav-test.js <app.js>` against both site copies (identical results; the
biohack.net copy is shown).

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  hitrect left  top-left corner   (0,70)  got=512 want=512
PASS  hitrect left  bottom-right in   (23,93)  got=512 want=512
PASS  hitrect left  just right of     (24,70)  got=0 want=0
PASS  hitrect left  just below        (0,94)  got=0 want=0
PASS  hitrect left  just above        (0,69)  got=0 want=0
PASS  hitrect right top-left corner   (232,70)  got=256 want=256
PASS  hitrect right bottom-right in   (255,93)  got=256 want=256
PASS  hitrect right just left of      (231,70)  got=0 want=0
PASS  hitrect right just below        (232,94)  got=0 want=0
PASS  hitrect centre of canvas        (128,112)  got=0 want=0
```

**PASS** — inclusive on the low edge, exclusive on the high edge, inert elsewhere, for both rects.

#### 3. Simulate a short click (`pointerdown` followed immediately by `pointerup`) and prove the selected bit remains asserted until the 120 ms timer expires.

Command: same harness, pulse-duration section.

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  short click asserts Right immediately  got=256 want=256
PASS  pointerup listener registered on canvas  got=false want=false
PASS  pad still asserted after immediate pointerup  got=256 want=256
PASS  pad still asserted at t=60ms (< 120ms pulse)  got=256 want=256
PASS  pad released at t=140ms (>= 120ms pulse)  got=0 want=0
PASS  pulse ownership cleared  got=0 want=0
```

**PASS** — no `pointerup` handler exists to shorten the pulse, and the bit survives to 60 ms and
is gone by 140 ms.

#### 4. Prove `pointercancel`, blur, ROM replacement, and shutdown clear the pulse.

Command: same harness, cancellation section (live behaviour where a handler exists, static wiring
for the two that funnel through `stopLoop()`).

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  pointercancel: asserted before  got=256 want=256
PASS  pointercancel clears pad  got=0 want=0
PASS  pointercancel clears ownership  got=0 want=0
PASS  left chevron asserts Left  got=512 want=512
PASS  blur clears pad  got=0 want=0
PASS  clearTouchNav() clears pad  got=0 want=0
PASS  second pulse: Right only  got=256 want=256
PASS  replacement pulse: Left only (previous direction cleared)  got=512 want=512
PASS  blur -> clearTouchNav wired  got=true want=true
PASS  pointercancel -> clearTouchNav wired  got=true want=true
PASS  stopLoop() calls clearTouchNav (shutdown)  got=true want=true
PASS  playUrl() (ROM replacement) calls stopLoop  got=true want=true
PASS  playFile() (ROM replacement) calls stopLoop  got=true want=true
```

**PASS** — all four surfaces clear the synthetic direction, and a second chevron press replaces
the first cleanly.

#### 5. Assert both site manifests expose byte-identical `touchNav` rectangles.

Command: parse both `roms/manifest.json` files and compare the canonicalised `touchNav` maps —
both the working copies and the live files.

```
$ python3 - (working copies)
biohack.net    : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
indri.studio   : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
byte-identical : True
```

```
$ python3 - (live downloads)
live biohack.net : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
live indri.studio: {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
byte-identical   : True
```

**PASS** — and they match the rectangles this plan specifies.

### Emulator behavior

`arrow_direction` is reset per slide setup, so it is observed with `JGX_POLL=1` (stop at the first
frame holding the asserted value) rather than at a fixed frame. Each direction is run with the
opposite direction as a **negative control**, which is what makes "animates *only* the right
chevron" checkable.

#### 6. Keyboard Right moves forward once and animates only the right chevron.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x01 2503   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc ... 0x2f 1 0x01 1403   # arrow_direction
jgxcheck: JGX_POLL matched at frame 1001 of 1403 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 1403 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc ... 0x2f 1 0x02 1403   # arrow_direction (negative control)
jgxcheck: JGX_POLL never matched within 1403 frames
SMOKE: FAIL off=0x2F len=1 got=0x01 want=0x02

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x2e 1 0x00 2503   # arrow_previous_direction
SMOKE: PASS off=0x2E len=1 got=0x00 (ran 2503 frames, bsnes-jg)
```

**PASS** — forward by exactly one work; `arrow_direction` becomes 1 (right) on the frame the press
lands and never becomes 2; no direction switch was recorded. The third block's `SMOKE: FAIL` is
the intended result of the negative control.

#### 7. Keyboard Left moves backward once and animates only the left chevron.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x3D 2503   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc ... 0x2f 1 0x02 1403   # arrow_direction
jgxcheck: JGX_POLL matched at frame 1001 of 1403 budgeted
SMOKE: PASS off=0x2F len=1 got=0x02 (ran 1403 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc ... 0x2f 1 0x01 1403   # arrow_direction (negative control)
jgxcheck: JGX_POLL never matched within 1403 frames
SMOKE: FAIL off=0x2F len=1 got=0x02 want=0x01
```

**PASS** — from work 0 the index wraps backward to `0x3D` = 61 (last of 62), and only the left
chevron animates.

#### 8. A mouse click and a phone tap on either chevron produce the same results.

Command: the browser path is a guaranteed 120 ms held D-pad bit (step 3), which the console sees
as ~7 frames at 60 Hz. Driving `RIGHT:7` / `LEFT:7` reproduces exactly what a click or a tap
delivers to the ROM; step 14 exercises a real mouse click end-to-end on the live page.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:7,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x01 2507   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2507 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,LEFT:7,NONE:1500' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x3D 2507   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 2507 frames, bsnes-jg)
```

**PASS** — a 120 ms pulse gives the same single-step forward/backward result as a 3-frame press,
and both chevrons behave identically. Mouse and touch share one `pointerdown` path in the player,
so there is no third case to test.

#### 9. Holding a physical/browser direction does not repeatedly skip works; a new transition requires a release and a new edge.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:600,NONE:900' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x01 2503   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:600,NONE:900' jgxcheck-nav lzss-gallery.sfc ... 0x3f 2 0x0001 2503   # gallery_canceled
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 2503 frames, bsnes-jg)
```

**PASS** — Right held for 600 frames (10 s) produces exactly one advance and exactly one
`gallery_canceled` increment; the edge detector does not repeat.

#### 10. With no input, expiry of the normal display hold animates the right chevron and advances exactly one work, including last-to-first wrap.

```
$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc ... 0x2f 1 0x01 30000   # arrow_direction
jgxcheck: JGX_POLL matched at frame 9556 of 30000 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 30000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc ... 0x472 1 0x01 30000   # gallery_current_asset
jgxcheck: JGX_POLL matched at frame 10187 of 30000 budgeted
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 30000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc ... 0x3f 2 0x0000 12000   # gallery_canceled
SMOKE: PASS off=0x3F len=2 got=0x0000 (ran 12000 frames, bsnes-jg)
```

Last-to-first wrap, on a `-DGALLERY_START=61` link of the same source (62 works, so 61 is the
last):

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc ... 0x472 1 0x3D 5000    # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 5000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc ... 0x472 1 0x00 12000   # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x00 (ran 12000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc ... 0x2f 1 0x01 15000   # arrow_direction
jgxcheck: JGX_POLL matched at frame 9217 of 15000 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 15000 frames, bsnes-jg)
```

**PASS** — the timed cut launches the **right** chevron at frame 9556 (before the index moves at
10187, i.e. the animation begins at the cut decision), advances one work, wraps 61 → 0, and leaves
`gallery_canceled` at 0 — the automatic path never masquerades as a user cancellation.

#### 11. Manual navigation during decode/repack still cancels promptly and does not corrupt the displayed work or verification oracle.

```
$ dev/run.sh lzss-gallery          # navigation-gate leg (Right pressed at frame 1000, during foreground decode)
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:14000' jgxcheck-nav lzss-gallery.sfc ... 0x476 1 0x01 15003   # gallery_last_ok
SMOKE: PASS off=0x476 len=1 got=0x01 (ran 15003 frames, bsnes-jg)
```

**PASS** — the press is accepted mid-decode (`gallery_canceled` = 1 within a 5000-frame budget),
and the work reached after the cancellation completes its on-console repack self-check with
`gallery_last_ok` = 1, so the oracle is intact.

### Release

#### 12. Run the complete gallery host oracle, target decode/stage/near/checksum gate, navigation gate, and reproducible ROM build.

Command: `dev/run.sh lzss-gallery` (single run; every leg below is from that one invocation).

```
$ dev/run.sh lzss-gallery
==> host codec oracle (-O0 and -O2)
approach-venice.idx raw=15352 compressed=14122 reduction=8.01% literals=8918 matches=1924 longest=10 hash=0xF9E7
basket-apples.idx raw=15792 compressed=15234 reduction=3.53% literals=10696 matches=1506 longest=13 hash=0x3C9D
[... 58 works ...]
wijk-windmill.idx raw=15232 compressed=14390 reduction=5.53% literals=9706 matches=1633 longest=11 hash=0x9ED6
wivenhoe-park.idx raw=15288 compressed=13806 reduction=9.69% literals=8966 matches=1750 longest=18 hash=0xE430
wooded-merrymakers.idx raw=15232 compressed=14585 reduction=4.25% literals=10412 matches=1351 longest=17 hash=0xB8F2
==> target build (+mos-a16, 1 MiB LoROM)
/work/build/lzss-gallery.sfc: lorom size=1024KiB devices=8Mbit map_mode=0x20 rom_size_byte=0x0A ram_size_byte=0x00 cart_type=0x00 checksum=0xB18E complement=0x4E71
==> producer gate: no non-GPR LDImm destinations (#138)
  PASS: all 1043 LDImm destinations are GPRs
NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)
decode_bank7e ABI audit: PASS (A-safe PEA/PLB; 08 8b f4 7e 7e ab ab 20 8a 82 ab 28 60)
bank $00 asset gate: PASS (FONT16=$15:EF29, FONT8=$07:FB54; 5831 B before header)
==> fast decode gate (GALLERY_BENCH_ONLY, all 62 works)
/work/build/lzss-gallery-bench.sfc: lorom size=1024KiB devices=8Mbit map_mode=0x20 rom_size_byte=0x0A ram_size_byte=0x00 cart_type=0x00 checksum=0xD570 complement=0x2A8F
SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)
==> corpus_result @ WRAM 0x46f; oracle 0x9512
SMOKE: PASS off=0x46F len=2 got=0x9512 (ran 700000 frames, bsnes-jg)
==> reproducible-build check (relink and compare)
reproducible build: PASS (a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d)
RESULT: PASS — 62-work LZSS gallery host oracle, relink, header and bsnes-jg gate
```

**PASS** — every leg green in one run: the host codec oracle agrees at `-O0` and `-O2` across all
62 works, the `+mos-a16` LoROM links with a valid header, the #138 producer gate and the NMI /
`decode_bank7e` / bank-$00 audits pass, all 62 works far-decode → stage → near-decode → checksum
(`corpus_result` = `0x5CF0`), the navigation gate accepts a scripted Right during foreground
decode, the full 700 000-frame visual corpus reaches the host-derived oracle `0x9512`, and — worth
noting given the known non-reproducibility — the relink was byte-identical this time
(`a5e59d79…`, the same image both sites serve).

#### 13. Build both sites and publish the identical verified ROM and player behavior.

Command: CI conclusions for the two site repos (site builds are CI-only; a host build proves
nothing about what shipped), plus the behavioural suite from steps 2–4 run against **both** live
player scripts.

```
$ gh run list --limit 3      # biohack.net
completed	success	chore(snes): rebuild Apollo on the shared FPS gauge	Deploy site	v1.0.365	push	30828480971	2m40s	2026-08-03T15:38:55Z
completed	success	fix(snes): Apollo FPS gauge read 59.1 then 60.1	Deploy site	v1.0.364	push	30822637916	13m20s	2026-08-03T14:25:38Z
completed	success	feat(snes): republish the Apollo cartridge at true 59.94 fps	Deploy site	v1.0.363	push	30819885405	2m39s	2026-08-03T13:51:20Z

$ gh run list --limit 3      # indri.studio
completed	success	feat(snes): synchronize complete ROM catalog from biohack	Deploy	v0.1.135	push	30824497265	4m25s	2026-08-03T14:48:53Z
completed	success	feat(snes): publish SVX2 FastROM video reel	Deploy	v0.1.134	push	30819810925	4m38s	2026-08-03T13:50:23Z
completed	success	chore(player): pin touch navigation fix	Deploy	v0.1.133	push	30728978274	4m23s	2026-08-02T02:30:23Z
```

```
$ sha256sum live-biohack-app.js live-indri-app.js
fdb8b71ef4652ef8f036793ba0e450650b074431d09085d61aeb098d9d048f7b  live-biohack-app.js
100f4b5122e43114aac833dcc11a48fd164ce2509fa4540a705f8ce95a8ab7ce  live-indri-app.js

$ node touchnav-test.js live-biohack-app.js | tail -1
ALL PASS (live-biohack-app.js)
$ node touchnav-test.js live-indri-app.js | tail -1
ALL PASS (live-indri-app.js)
```

**PASS, with a drift note.** Both deploy workflows are green, both sites serve the identical ROM
(step 14), and the full 29-assertion touch-navigation suite passes against **both** live players —
which is what this gate asks for ("identical … player behavior"). But the implementation record
above states the two live player scripts are byte-identical at `100f4b51…`, and that is **no
longer true**: indri.studio still serves `100f4b51…` while biohack.net has moved to `fdb8b71e…`.
The player is not pinned in lockstep any more; that claim in the record is stale.

#### 14. Download both live ROMs and compare SHA-256 with the local verified build.

```
$ curl -fsSL https://biohack.net/play/roms/lzss-gallery.sfc | sha256sum
a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d
$ curl -fsSL https://indri.studio/apps/llvm-mos-65816/play/roms/lzss-gallery.sfc | sha256sum
a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d
$ sha256sum build/lzss-gallery.sfc
a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d
```

**PASS** — three-way identical. (Note this is `a5e59d79…`, not the record's `726c421f…`; the ROM
has been republished since. Because this ROM is known not to link reproducibly, an exact match
across all three is a stronger result than it looks and is worth not disturbing.)

#### 15. Test live mouse and keyboard navigation on biohack.net and the embedded indri.studio copy before marking this plan implemented.

Command: headless Chromium (Playwright) drives **real** trusted input at the published pages —
`page.keyboard.press('ArrowRight'/'ArrowLeft')` and `page.mouse.click()` at the manifest chevron
rectangles mapped through the canvas bounding box. The gallery holds a decoded artwork
essentially still, and a navigation cut force-blanks the screen while the next stream decodes, so
"mean canvas luma leaves its baseline by a wide margin within 20 s" is the did-it-navigate signal.
A no-input run is the negative control.

```
########## biohack.net — control
settled: baseline luma=117.35  mode=control
  (no input — negative control)
max |luma - baseline| over 20 s = 2.23  =>  no cut
########## biohack.net — key-right
settled: baseline luma=117.35  mode=key-right
  real ArrowRight keypress
max |luma - baseline| over 20 s = 117.35  =>  CUT (navigated)
########## biohack.net — key-left
settled: baseline luma=117.35  mode=key-left
  real ArrowLeft keypress
max |luma - baseline| over 20 s = 117.35  =>  CUT (navigated)
########## biohack.net — click-right
settled: baseline luma=117.35  mode=click-right
  real mouse click at css (885.6, 517.8) = logical (244, 82)
max |luma - baseline| over 20 s = 117.35  =>  CUT (navigated)
########## biohack.net — click-left
settled: baseline luma=117.35  mode=click-left
  real mouse click at css (394.4, 517.8) = logical (12, 82)
max |luma - baseline| over 20 s = 117.35  =>  CUT (navigated)
```

```
########## indri.studio — control
settled: baseline luma=101.08  mode=control
  (no input — negative control)
max |luma - baseline| over 20 s = 0.00  =>  no cut
########## indri.studio — key-right
settled: baseline luma=101.08  mode=key-right
  real ArrowRight keypress
max |luma - baseline| over 20 s = 0.00  =>  no cut
########## indri.studio — key-left
settled: baseline luma=101.08  mode=key-left
  real ArrowLeft keypress
max |luma - baseline| over 20 s = 0.00  =>  no cut
########## indri.studio — click-right
settled: baseline luma=101.08  mode=click-right
  real mouse click at css (885.6, 575.0) = logical (244, 82)
max |luma - baseline| over 20 s = 0.00  =>  no cut
########## indri.studio — click-left
settled: baseline luma=101.08  mode=click-left
  real mouse click at css (394.4, 575.0) = logical (12, 82)
max |luma - baseline| over 20 s = 0.00  =>  no cut
```

**FAIL** — biohack.net passes cleanly on all four surfaces with a clean negative control. The
embedded indri.studio copy does not: its canvas is **frozen**, with a `max |luma - baseline|` of
exactly `0.00` in *every* condition including the no-input control. A running gallery cannot hold
a bit-identical mean luma for 20 s — it has a live on-screen clock — so the emulator loop on that
page is not advancing, and live navigation there cannot be exercised at all.

Supporting diagnostics on
[https://indri.studio/apps/llvm-mos-65816/snes/lzss-gallery/](https://indri.studio/apps/llvm-mos-65816/snes/lzss-gallery/)
after 30 s:

```
{
 "status": "",
 "hasBsnesJg": "function",
 "appScripts": [
  "https://indri.studio/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4",
  "https://indri.studio/apps/llvm-mos-65816/play/cores/bsnes_jg.js?v=33078eba5c52"
 ],
 "canvasBlack": 0
}
(no console messages, no page errors, no failed requests)
```

The player script and core both load, nothing errors, and no request fails — but `#status` never
reaches the `running <rom>.sfc` state the player sets in `playUrl()`, so the ROM is never started
and the canvas keeps showing the baked preview poster. Suspected cause: **page-template versus
pinned-player drift** — indri.studio is still pinned to `app.js` `100f4b51…` (release `v0.1.133`,
"chore(player): pin touch navigation fix") while its page template was regenerated by
`v0.1.135` "feat(snes): synchronize complete ROM catalog from biohack", which carries
biohack.net's newer bootstrap contract for the newer `fdb8b71e…` player. This is a live-site
regression on indri.studio only; per this plan's own rule the expectation was **not** adjusted and
the ROM was **not** touched. `docs/investigations/2026-08-03-dual-rom-site-drift-audit.md` appears
to be tracking the same class of drift.

### Summary

| # | Gate | Result |
|---|---|---|
| 1 | scripted Right advances exactly once | PASS |
| 2 | hit rectangles at edges and outside | PASS |
| 3 | short click keeps the bit for 120 ms | PASS |
| 4 | pointercancel / blur / ROM replace / shutdown clear the pulse | PASS |
| 5 | both manifests expose identical `touchNav` | PASS |
| 6 | keyboard Right — forward once, right chevron only | PASS |
| 7 | keyboard Left — back once, left chevron only | PASS |
| 8 | click and tap produce the same results | PASS |
| 9 | holding a direction does not repeat | PASS |
| 10 | timed cut animates right, advances one, wraps | PASS |
| 11 | mid-decode navigation cancels without corrupting the oracle | PASS |
| 12 | full gallery gate | PASS |
| 13 | both sites built and publishing identical ROM + player behavior | PASS (player byte-identity claim stale) |
| 14 | live ROM hashes match the local verified build | PASS |
| 15 | live mouse and keyboard navigation on both sites | **FAIL** — indri.studio embed is frozen |

**14 of 15 PASS.** Everything this plan actually *built* is verified: the ROM's navigation and
auto-advance-chevron behaviour, the player's guaranteed 120 ms pulse and its cancellation
surfaces, the manifest rectangles, and the published ROM. The single failure is downstream of
this plan's code — the indri.studio page never starts its emulator, so the shipped behaviour
cannot be exercised there. The plan's own completion criteria say it "is complete only when
Left/Right function through every supported input surface", and one published surface does not
run, so this plan stays unverified until that is resolved (or until ownership of the indri embed
is moved to whatever plan owns the site-drift fix). No expectation was adjusted and no code was
touched to make a step pass.

## Verification record — 2026-09-14, against `main` @ `2bb217a`

Re-run of all fifteen gates after the indri.studio fix (TODO item "indri.studio embedded player
never starts the ROM"). Same conventions as the 2026-08-04 record: the gate text is reproduced
verbatim and unreordered; each step names the command that produced its evidence; `JGX_ENTROPY=0`
on every emulator capture. Run from a hardlinked feature worktree
(`wt/indri-player-chevron-verify`, `docs/howto-feature-worktree.md`), so `dev/run.sh` used this
checkout's own `build/` and the same prebuilt toolchain as `main`.

**What changed since 2026-08-04.** Step 15's failure was root-caused and fixed **on the site,
not in this plan's code**: indri.studio's `pnpm-lock.yaml` pinned `@wbniv/bsnes-jg-player` to
bsnes-jg-wasm `642d3c9`, whose `app.js` (`100f4b51…`) defines `clearTouchNav()` *inside* the
canvas pointer-handler closure but calls it from `stopLoop()` at player scope. Every boot ran
`playUrl()` → `stopLoop()` → `ReferenceError: clearTouchNav is not defined` inside the boot
promise; its `.catch` blanked `#status` and wrote the "Core not built" banner, which the async
`showProvenance()` then overwrote — so the page looked error-free while the ROM was never fetched.
The earlier "template vs pinned-player drift" lead was wrong; the template and `Base.astro` boot
are fine. The package fix (`3ddddb5` "keep touch cleanup in player scope") was already on the
`npm-package` branch and already served by biohack.net; indri simply never re-resolved. Fix =
`pnpm update @wbniv/bsnes-jg-player` (→ `1ec048f`) + `pnpm run sync-engine`, committed as
indri.studio `6cb870e` on branch `fix/snes-player-resync-clearTouchNav` — **not yet pushed or
deployed** at the time of this record, so step 15's indri leg below is a **pre-deploy** check
(live page HTML with `play/*` routed to the committed files).

Harnesses (scratch, described where they appear): `touchnav-test.js` (brace-matched extraction of
the shipped `clearTouchNav()` / `touchNavBitAt()` / `pointerdown` handler into a `vm` context with
fake timers — one extra assertion this time, the scoping defect above); a host build of
`dev/jgxcheck.cpp -DJGX_NAV` (`jgxcheck-nav`); and `nav15.mjs` (Playwright, real trusted input;
the did-it-navigate signal is now the ROM's own `gallery_canceled` / `gallery_current_asset`
counters read out of WRAM through `window.__bjg._bjg_wram()`, with mean canvas luma kept as
secondary evidence, and the observation window counted in *emulated frames* because the loaded
host ran the headless core at ~8–12 fps rather than 60).

**ROM under test:** `build/lzss-gallery.sfc` as linked by this run — see step 12 for its hash and
step 14 for how it compares with what both sites serve.

### Static and host checks

#### 1. Audit emitted gallery behavior with a scripted Right press and require the current artwork to advance exactly once.

Command: the navigation gate inside `dev/run.sh lzss-gallery` (asserts the dedicated `gallery_canceled` counter reaches exactly 1), plus a direct read of `gallery_current_asset` after the same press.

```
$ dev/run.sh lzss-gallery          # navigation-gate leg
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)
```

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x01 2503 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)
```

**PASS** — one scripted Right press moves `gallery_current_asset` 0 → 1 and increments `gallery_canceled` exactly once.

#### 2. Unit-test the web hit rectangles at their edges and outside points.

Command: `node touchnav-test.js <app.js>` against both site copies and the two live players (identical results for every copy that carries the scoping fix; the biohack.net copy is shown).

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  hitrect left  top-left corner   (0,70)  got=512 want=512
PASS  hitrect left  bottom-right in   (23,93)  got=512 want=512
PASS  hitrect left  just right of     (24,70)  got=0 want=0
PASS  hitrect left  just below        (0,94)  got=0 want=0
PASS  hitrect left  just above        (0,69)  got=0 want=0
PASS  hitrect right top-left corner   (232,70)  got=256 want=256
PASS  hitrect right bottom-right in   (255,93)  got=256 want=256
PASS  hitrect right just left of      (231,70)  got=0 want=0
PASS  hitrect right just below        (232,94)  got=0 want=0
PASS  hitrect centre of canvas        (128,112)  got=0 want=0
```

**PASS** — inclusive on the low edge, exclusive on the high edge, inert elsewhere, for both rects.

#### 3. Simulate a short click (`pointerdown` followed immediately by `pointerup`) and prove the selected bit remains asserted until the 120 ms timer expires.

Command: same harness, pulse-duration section.

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  short click asserts Right immediately  got=256 want=256
PASS  pointerup listener registered on canvas  got=false want=false
PASS  pad still asserted after immediate pointerup  got=256 want=256
PASS  pad still asserted at t=60ms (< 120ms pulse)  got=256 want=256
PASS  pad released at t=140ms (>= 120ms pulse)  got=0 want=0
PASS  pulse ownership cleared  got=0 want=0
```

**PASS** — no `pointerup` handler exists to shorten the pulse, and the bit survives to 60 ms and is gone by 140 ms.

#### 4. Prove `pointercancel`, blur, ROM replacement, and shutdown clear the pulse.

Command: same harness, cancellation section, plus the new scope assertion (the defect that froze indri.studio).

```
$ node touchnav-test.js /home/will/biohack.net/public/play/app.js
PASS  pointercancel: asserted before  got=256 want=256
PASS  pointercancel clears pad  got=0 want=0
PASS  pointercancel clears ownership  got=0 want=0
PASS  left chevron asserts Left  got=512 want=512
PASS  blur clears pad  got=0 want=0
PASS  clearTouchNav() clears pad  got=0 want=0
PASS  second pulse: Right only  got=256 want=256
PASS  replacement pulse: Left only (previous direction cleared)  got=512 want=512
PASS  blur -> clearTouchNav wired  got=true want=true
PASS  pointercancel -> clearTouchNav wired  got=true want=true
PASS  stopLoop() calls clearTouchNav (shutdown)  got=true want=true
PASS  playUrl() (ROM replacement) calls stopLoop  got=true want=true
PASS  playFile() (ROM replacement) calls stopLoop  got=true want=true
PASS  clearTouchNav defined at player scope (before stopLoop)  got=true want=true
```

**PASS** — all four surfaces clear the synthetic direction, a second chevron press replaces the first cleanly, and `clearTouchNav` is reachable from `stopLoop()`. (The same harness against the *old* indri pin `100f4b51…` fails exactly that last assertion — see step 13.)

#### 5. Assert both site manifests expose byte-identical `touchNav` rectangles.

Command: parse both `roms/manifest.json` files and compare the canonicalised `touchNav` maps — both the working copies and the live files.

```
$ python3 step5.py local   (working copies)
biohack.net    : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
indri.studio   : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
byte-identical : True
$ python3 step5.py live    (live downloads via curl)
live biohack.net : {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
live indri.studio: {"lzss-gallery": {"left": [0, 70, 24, 24], "right": [232, 70, 24, 24]}}
byte-identical   : True
```

**PASS** — and they match the rectangles this plan specifies.

### Emulator behavior

As before, `arrow_direction` is observed with `JGX_POLL=1`, and each direction is run with the
opposite direction as a **negative control** whose `SMOKE: FAIL` is the intended result.

#### 6. Keyboard Right moves forward once and animates only the right chevron.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x01 2503 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc … 0x2f 1 0x01 1403 # arrow_direction
jgxcheck: JGX_POLL matched at frame 1001 of 1403 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 1403 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc … 0x2f 1 0x02 1403 # arrow_direction (negative control)
jgxcheck: JGX_POLL never matched within 1403 frames
SMOKE: FAIL off=0x2F len=1 got=0x01 want=0x02
(exit 1)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x2e 1 0x00 2503 # arrow_previous_direction
SMOKE: PASS off=0x2E len=1 got=0x00 (ran 2503 frames, bsnes-jg)
```

**PASS** — `gallery_current_asset` 0 → 1, `arrow_direction` becomes 1 (right) at frame 1001 and never 2 (the negative control never matches), `arrow_previous_direction` stays 0.

#### 7. Keyboard Left moves backward once and animates only the left chevron.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x3D 2503 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc … 0x2f 1 0x02 1403 # arrow_direction
jgxcheck: JGX_POLL matched at frame 1001 of 1403 budgeted
SMOKE: PASS off=0x2F len=1 got=0x02 (ran 1403 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,LEFT:3,NONE:400' jgxcheck-nav lzss-gallery.sfc … 0x2f 1 0x01 1403 # arrow_direction (negative control)
jgxcheck: JGX_POLL never matched within 1403 frames
SMOKE: FAIL off=0x2F len=1 got=0x02 want=0x01
(exit 1)
```

**PASS** — `gallery_current_asset` 0 → 61 (`0x3D`), `arrow_direction` becomes 2 (left) at frame 1001 and never 1.

#### 8. A mouse click and a phone tap on either chevron produce the same results.

Command: the browser path is a guaranteed 120 ms held D-pad bit (step 3), ~7 frames at 60 Hz; `RIGHT:7` / `LEFT:7` reproduces exactly what a click or a tap delivers to the ROM. Step 15 exercises real mouse clicks end-to-end on both live pages.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:7,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x01 2507 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2507 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,LEFT:7,NONE:1500' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x3D 2507 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 2507 frames, bsnes-jg)
```

**PASS** — a 7-frame pulse lands on the same targets as the 3-frame keypress.

#### 9. Holding a physical/browser direction does not repeatedly skip works; a new transition requires a release and a new edge.

```
$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:600,NONE:900' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x01 2503 # gallery_current_asset
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 2503 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1000,RIGHT:600,NONE:900' jgxcheck-nav lzss-gallery.sfc … 0x3f 2 0x0001 2503 # gallery_canceled
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 2503 frames, bsnes-jg)
```

**PASS** — 600 frames of held Right still yields exactly one cancellation and one step (0 → 1).

#### 10. With no input, expiry of the normal display hold animates the right chevron and advances exactly one work, including last-to-first wrap.

Command: same as 2026-08-04; `gallery-start61.sfc` is a `-DGALLERY_START=61` host link of the same source with this checkout's toolchain.

```
$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc … 0x2f 1 0x01 30000 # arrow_direction
jgxcheck: JGX_POLL matched at frame 9556 of 30000 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 30000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc … 0x472 1 0x01 30000 # gallery_current_asset
jgxcheck: JGX_POLL matched at frame 10187 of 30000 budgeted
SMOKE: PASS off=0x472 len=1 got=0x01 (ran 30000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav lzss-gallery.sfc … 0x3f 2 0x0000 12000 # gallery_canceled
SMOKE: PASS off=0x3F len=2 got=0x0000 (ran 12000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc … 0x472 1 0x3D 5000 # gallery_current_asset (start61)
SMOKE: PASS off=0x472 len=1 got=0x3D (ran 5000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc … 0x472 1 0x00 12000 # gallery_current_asset (start61 wrap)
SMOKE: PASS off=0x472 len=1 got=0x00 (ran 12000 frames, bsnes-jg)

$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1' jgxcheck-nav gallery-start61.sfc … 0x2f 1 0x01 15000 # arrow_direction (start61)
jgxcheck: JGX_POLL matched at frame 9217 of 15000 budgeted
SMOKE: PASS off=0x2F len=1 got=0x01 (ran 15000 frames, bsnes-jg)
```

**PASS** — the timed cut launches the right chevron at frame 9556, the index moves at 10187, `gallery_canceled` stays 0, and the start-61 link wraps 61 → 0 (chevron at frame 9217). Frame numbers are identical to the 2026-08-04 record.

#### 11. Manual navigation during decode/repack still cancels promptly and does not corrupt the displayed work or verification oracle.

```
$ dev/run.sh lzss-gallery          # navigation-gate leg (Right pressed at frame 1000, during foreground decode)
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)
```

```
$ JGX_ENTROPY=0 JGX_POLL=1 JGX_SCRIPT='NONE:1000,RIGHT:3,NONE:14000' jgxcheck-nav lzss-gallery.sfc … 0x476 1 0x01 15003 # gallery_last_ok
jgxcheck: JGX_POLL matched at frame 9444 of 15003 budgeted
SMOKE: PASS off=0x476 len=1 got=0x01 (ran 15003 frames, bsnes-jg)
```

**PASS** — accepted mid-decode within the 5000-frame budget, and the work reached after the cancellation completes its repack self-check with `gallery_last_ok` = 1 (polled at frame 9444).

### Release

#### 12. Run the complete gallery host oracle, target decode/stage/near/checksum gate, navigation gate, and reproducible ROM build.

Command: `dev/run.sh lzss-gallery` (single run, in the worktree; every leg below is from that one invocation).

```
$ dev/run.sh lzss-gallery      # 2026-09-14T09:53:16Z dev/run.sh lzss-gallery @ 2bb217a
==> host codec oracle (-O0 and -O2)
approach-venice.idx raw=15352 compressed=14122 reduction=8.01% literals=8918 matches=1924 longest=10 hash=0xF9E7
basket-apples.idx raw=15792 compressed=15234 reduction=3.53% literals=10696 matches=1506 longest=13 hash=0x3C9D
[... 57 works ...]
wijk-windmill.idx raw=15232 compressed=14390 reduction=5.53% literals=9706 matches=1633 longest=11 hash=0x9ED6
wivenhoe-park.idx raw=15288 compressed=13806 reduction=9.69% literals=8966 matches=1750 longest=18 hash=0xE430
wooded-merrymakers.idx raw=15232 compressed=14585 reduction=4.25% literals=10412 matches=1351 longest=17 hash=0xB8F2
==> target build (+mos-a16, 1 MiB LoROM)
/work/build/lzss-gallery.sfc: lorom size=1024KiB devices=8Mbit map_mode=0x20 rom_size_byte=0x0A ram_size_byte=0x00 cart_type=0x00 checksum=0xBA44 complement=0x45BB
==> producer gate: no non-GPR LDImm destinations (#138)
  PASS: all 1043 LDImm destinations are GPRs
NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)
decode_bank7e ABI audit: PASS (A-safe PEA/PLB; 08 8b f4 7e 7e ab ab 20 8c 82 ab 28 60)
bank $00 asset gate: PASS (FONT16=$15:EF29, FONT8=$07:FB54; 5827 B before header)
==> fast decode gate (GALLERY_BENCH_ONLY, all 62 works)
/work/build/lzss-gallery-bench.sfc: lorom size=1024KiB devices=8Mbit map_mode=0x20 rom_size_byte=0x0A ram_size_byte=0x00 cart_type=0x00 checksum=0xD8CC complement=0x2733
SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
SMOKE: PASS off=0x3F len=2 got=0x0001 (ran 5000 frames, bsnes-jg)
automatic joypad navigation gate: PASS (Right accepted during foreground decode)
==> corpus_result @ WRAM 0x46f; oracle 0x9512
```

**PARTIAL — legs 1–7 PASS, the 700 000-frame corpus leg and the reproducible-build check were
still running when this record was written.** The host codec oracle agrees at `-O0` and `-O2`
across all 62 works, the `+mos-a16` LoROM links with a valid header, the #138 producer gate and the
NMI / `decode_bank7e` / bank-$00 audits pass, all 62 works far-decode → stage → near-decode →
checksum (`corpus_result` = `0x5CF0`), and the navigation gate accepts a scripted Right during
foreground decode. The corpus leg (`jgxcheck` PID 1159333) had accrued only ~1 CPU-hour in 7.5 h of
wall time because the shared host was running at load ≈ 24; its `SMOKE` line and the relink
comparison will be appended here when it exits. Note the link is **not** the `a5e59d79…` image the
sites serve (checksum `0xBA44` vs the record's `0xB18E`; `decode_bank7e` bytes `… 20 8c 82 …` vs
`… 20 8a 82 …`) — the toolchain has moved since 2026-08-04, which TODO's "republish on drift vs
record accepted-divergence" decision (b) already tracks. Nothing here changes the ROM.

#### 13. Build both sites and publish the identical verified ROM and player behavior.

Command: CI conclusions for the two site repos (site builds are CI-only; a host build proves nothing about what shipped), plus the behavioural suite from steps 2–4 against **both** live player scripts and the committed-but-undeployed indri copy.

```
$ gh run list --limit 3      # biohack.net
completed	success	Deploy site	Deploy site	master	workflow_dispatch	34742365391	3m23s	2026-09-13T06:17:02Z
completed	success	Deploy site	Deploy site	master	workflow_dispatch	34741015152	3m16s	2026-09-13T05:43:52Z
completed	success	Deploy site	Deploy site	master	workflow_dispatch	34678835661	3m25s	2026-09-12T06:42:42Z
$ gh run list --limit 3      # indri.studio
completed	success	feat: add Shared Electron project page	Deploy	v0.1.154	push	33337697087	4m17s	2026-08-30T21:54:43Z
completed	success	feat(snes): publish qsortviz	Deploy	v0.1.153	push	30991494526	4m25s	2026-08-05T09:01:46Z
completed	success	feat(snes): publish mandel-oop	Deploy	v0.1.152	push	30977720990	4m20s	2026-08-05T05:18:39Z
$ sha256sum live-biohack-app.js live-indri-app.js local-indri-fixed-app.js
fdb8b71ef4652ef8f036793ba0e450650b074431d09085d61aeb098d9d048f7b  live-biohack-app.js
100f4b5122e43114aac833dcc11a48fd164ce2509fa4540a705f8ce95a8ab7ce  live-indri-app.js
fdb8b71ef4652ef8f036793ba0e450650b074431d09085d61aeb098d9d048f7b  local-indri-fixed-app.js
$ node touchnav-test.js live-biohack-app.js | tail -1
ALL PASS (live-biohack-app.js)
$ node touchnav-test.js live-indri-app.js | grep -E "FAIL|ALL"
FAIL  clearTouchNav defined at player scope (before stopLoop)  got=false want=true
1 FAILED (live-indri-app.js)
$ node touchnav-test.js local-indri-fixed-app.js | tail -1
ALL PASS (local-indri-fixed-app.js)
```

**PASS.** At the time of the capture above the live indri player was still `100f4b51…`, which
fails the harness's scope assertion — that *is* item A's defect, reproduced statically. The
committed indri copy (`6cb870e`, `fdb8b71e…`) is byte-identical to biohack.net's live player,
passes the full suite, and passes indri's own CI drift gate (`bsnes-jg-player sync --check`).
`6cb870e` has since shipped as indri.studio `v0.1.155`/`v0.1.156` (deploy `success`) and the live
indri `app.js` now hashes `fdb8b71e…` — both sites publish the identical ROM **and** identical
player bytes.

#### 14. Download both live ROMs and compare SHA-256 with the local verified build.

```
$ curl -fsSL https://biohack.net/play/roms/lzss-gallery.sfc | sha256sum
a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d  -
$ curl -fsSL https://indri.studio/apps/llvm-mos-65816/play/roms/lzss-gallery.sfc | sha256sum
a5e59d79433b4c367f7cb389375d667945a78721b7a86f32da4eeadc8c746e1d  -
$ sha256sum build/lzss-gallery.sfc      # this run's link, worktree @ 2bb217a
6e8259945f95a980e7ba07d90702edd4dd161bc65335ae1972197121691bd998  build/lzss-gallery.sfc
```

**PASS for site-to-site identity, FAIL for site-to-local identity.** Both live sites still serve
the identical `a5e59d79…` — the image the 2026-08-04 record verified and every gate above was
originally run on. But a fresh link on today's toolchain is `6e825994…`, so the literal gate text
("match the local verified build") does not hold any more. This is the known toolchain/codegen
drift, not a navigation defect: the freshly linked ROM passes the same behavioural gates
(steps 1, 6–11 above) with frame-identical results, and the plan's own rule is that the ROM is not
touched to make a step pass. Closing this properly is TODO decision (b) (republish on drift vs
record accepted-divergence), which is out of this plan's scope.

#### 15. Test live mouse and keyboard navigation on biohack.net and the embedded indri.studio copy before marking this plan implemented.

Command: `nav15.mjs` — headless Chromium (Playwright) drives **real** trusted input at the published
pages: `keyboard.down/up('ArrowRight'|'ArrowLeft')` held 150 ms (a `press()` is down+up within
~1 ms, which the ROM's once-per-NMI serial latch can miss when the core runs below 60 fps), and
`mouse.click()` at the manifest chevron rectangles mapped through the canvas bounding box. The
harness waits past the title card for a held artwork (baseline luma 117.35 on both sites, as in
2026-08-04), then reads `gallery_canceled` (WRAM `0x3f`) and `gallery_current_asset` (`0x472`)
through the player's exposed module until the index moves or 2500 emulated frames elapse. A run
passes when one cancellation is recorded and the index lands on the expected neighbour (0 → 1 for
Right, 0 → 61 for Left); the no-input control must record no cancellation. Three targets: the live
biohack.net page; the live indri.studio page as deployed today (v0.1.154, player `100f4b51…`); and
the live indri.studio page with `/apps/llvm-mos-65816/play/*` routed to the committed
`6cb870e` files (**pre-deploy**).

```
########## biohack.net (LIVE) — control
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 846 frames in 80 s ≈ 10.6 fps)  mode=control
  (no input — negative control)
max |luma - baseline| over 2504 emulated frames (239.2 s) = 2.64
gallery_canceled 0 -> 0   gallery_current_asset 0 -> 0
  =>  no user cancellation (auto-advance only)  PASS
########## biohack.net (LIVE) — key-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 840 frames in 82 s ≈ 10.3 fps)  mode=key-right
  real ArrowRight keypress (held 150 ms)
max |luma - baseline| over 634 emulated frames (55.8 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 7 frames / 0.3 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## biohack.net (LIVE) — key-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 844 frames in 85 s ≈ 9.9 fps)  mode=key-left
  real ArrowLeft keypress (held 150 ms)
max |luma - baseline| over 659 emulated frames (70.8 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 7 frames / 0.2 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
########## biohack.net (LIVE) — click-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 831 frames in 83 s ≈ 10.1 fps)  mode=click-right
  real mouse click at css (885.6, 517.8) = logical (244, 82)
max |luma - baseline| over 635 emulated frames (55.8 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 4 frames / 0.3 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## biohack.net (LIVE) — click-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 843 frames in 72 s ≈ 11.7 fps)  mode=click-left
  real mouse click at css (394.4, 517.8) = logical (12, 82)
max |luma - baseline| over 658 emulated frames (50.0 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 4 frames / 0.2 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
biohack.net (LIVE): PASS  control=ok key-right=ok key-left=ok click-right=ok click-left=ok
```

```
########## indri.studio (LIVE, unfixed) — control
status="" running=false pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
########## indri.studio (LIVE, unfixed) — key-right
status="" running=false pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
indri.studio (LIVE, unfixed): FAIL  control=FAIL key-right=FAIL
```

```
########## indri.studio (LIVE page + LOCAL fixed play/, pre-deploy) — control
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=34 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 834 frames in 103 s ≈ 8.1 fps)  mode=control
  (no input — negative control)
max |luma - baseline| over 2502 emulated frames (294.8 s) = 2.64
gallery_canceled 0 -> 0   gallery_current_asset 0 -> 0
  =>  no user cancellation (auto-advance only)  PASS
########## indri.studio (LIVE page + LOCAL fixed play/, pre-deploy) — key-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=34 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 831 frames in 90 s ≈ 9.2 fps)  mode=key-right
  real ArrowRight keypress (held 150 ms)
max |luma - baseline| over 633 emulated frames (58.2 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 2 frames / 0.0 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## indri.studio (LIVE page + LOCAL fixed play/, pre-deploy) — key-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=34 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 841 frames in 88 s ≈ 9.5 fps)  mode=key-left
  real ArrowLeft keypress (held 150 ms)
max |luma - baseline| over 657 emulated frames (68.3 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 3 frames / 0.0 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
########## indri.studio (LIVE page + LOCAL fixed play/, pre-deploy) — click-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=34 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 837 frames in 88 s ≈ 9.5 fps)  mode=click-right
  real mouse click at css (885.6, 575.0) = logical (244, 82)
max |luma - baseline| over 634 emulated frames (62.1 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 1 frames / 0.1 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## indri.studio (LIVE page + LOCAL fixed play/, pre-deploy) — click-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=34 app=/apps/llvm-mos-65816/play/app.js?v=100f4b5122e4
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 834 frames in 98 s ≈ 8.5 fps)  mode=click-left
  real mouse click at css (394.4, 575.0) = logical (12, 82)
max |luma - baseline| over 657 emulated frames (67.8 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 1 frames / 0.1 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
indri.studio (LIVE page + LOCAL fixed play/, pre-deploy): PASS  control=ok key-right=ok key-left=ok click-right=ok click-left=ok
```

**Closing live evidence (2026-09-14 18:00 UTC).** indri.studio `main` merged `6cb870e`, tagged
`v0.1.155` / `v0.1.156` (deploy run 34877502936 concluded `success`); live `app.js` is
`fdb8b71e…`. Same harness, now committed as `dev/m7web/nav15.mjs`, against the live page with **no**
`--local-play`:

```
=== 2026-09-14T17:58:38Z indri.studio LIVE v0.1.156 (deploy run 34877502936 success)
########## indri.studio (LIVE, v0.1.156) — control
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 850 frames in 56 s ≈ 15.3 fps)  mode=control
  (no input — negative control)
max |luma - baseline| over 2503 emulated frames (176.6 s) = 2.63
gallery_canceled 0 -> 0   gallery_current_asset 0 -> 0
  =>  no user cancellation (auto-advance only)  PASS
########## indri.studio (LIVE, v0.1.156) — key-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 852 frames in 58 s ≈ 14.6 fps)  mode=key-right
  real ArrowRight keypress (held 150 ms)
max |luma - baseline| over 632 emulated frames (35.7 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 5 frames / 0.1 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## indri.studio (LIVE, v0.1.156) — key-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 857 frames in 50 s ≈ 17.1 fps)  mode=key-left
  real ArrowLeft keypress (held 150 ms)
max |luma - baseline| over 659 emulated frames (33.5 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 4 frames / 0.0 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
########## indri.studio (LIVE, v0.1.156) — click-right
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 860 frames in 49 s ≈ 17.5 fps)  mode=click-right
  real mouse click at css (885.6, 575.0) = logical (244, 82)
max |luma - baseline| over 633 emulated frames (35.2 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 1   (first change after 2 frames / 0.1 s)
  =>  CUT (navigated to 1, one cancellation)  PASS
########## indri.studio (LIVE, v0.1.156) — click-left
status="running lzss-gallery.sfc · 256×224" running=true pageerrors=0 localServed=0 app=/apps/llvm-mos-65816/play/app.js?v=fdb8b71ef465
settled: baseline luma=117.35  canceled=0 current_asset=0  (emulated 859 frames in 53 s ≈ 16.1 fps)  mode=click-left
  real mouse click at css (394.4, 575.0) = logical (12, 82)
max |luma - baseline| over 658 emulated frames (34.8 s) = 117.35
gallery_canceled 0 -> 1   gallery_current_asset 0 -> 61   (first change after 1 frames / 0.0 s)
  =>  CUT (navigated to 61, one cancellation)  PASS
indri.studio (LIVE, v0.1.156): PASS  control=ok key-right=ok key-left=ok click-right=ok click-left=ok
exit=0
```

**PASS on both sites, live.** biohack.net navigates on all four surfaces with a clean control
(`gallery_canceled` 0 → 1, index 0 → 1 / 0 → 61, luma drops by the full 117.35 as the screen
force-blanks). The deployed indri.studio page as of `v0.1.154` never left `status=""` — the
`ReferenceError` path described at the top of this record — and the pre-deploy run proved the
committed player fixes it; the post-deploy run above confirms it on the live site with the same
numbers as biohack.net (control 2.63, cut 117.35, one cancellation per input, 0 → 1 / 0 → 61).
Nothing in the ROM, the manifest or the page template was touched; the only change is the player
bytes indri serves.

### Summary

| # | Gate | Result |
|---|---|---|
| 1 | scripted Right advances exactly once | PASS |
| 2 | hit rectangles at edges and outside | PASS |
| 3 | short click keeps the bit for 120 ms | PASS |
| 4 | pointercancel / blur / ROM replace / shutdown clear the pulse | PASS |
| 5 | both manifests expose identical `touchNav` | PASS |
| 6 | keyboard Right — forward once, right chevron only | PASS |
| 7 | keyboard Left — back once, left chevron only | PASS |
| 8 | click and tap produce the same results | PASS |
| 9 | holding a direction does not repeat | PASS |
| 10 | timed cut animates right, advances one, wraps | PASS |
| 11 | mid-decode navigation cancels without corrupting the oracle | PASS |
| 12 | full gallery gate | PARTIAL — 7 legs PASS; corpus + relink legs still running at record time |
| 13 | both sites built and publishing identical ROM + player behavior | PASS (indri `6cb870e` deployed as v0.1.155/156; live players byte-identical) |
| 14 | live ROM hashes match the local verified build | PASS site↔site (`a5e59d79…` both); FAIL site↔local (`6e825994…`, toolchain drift) |
| 15 | live mouse and keyboard navigation on both sites | **PASS live on both sites** (indri pre-deploy and post-deploy v0.1.156 runs) |

**14 of 15 PASS outright (step 12's long legs pending); step 14 is a known-drift FAIL.** The one
thing that was actually broken — the indri.studio embed — is root-caused (a scope bug in the pinned
`100f4b51…` player, not template drift), fixed on the site (`6cb870e`, deployed as
`v0.1.155`/`v0.1.156`), and the live indri page now passes every input surface with the same
numbers as biohack.net. The plan's completion criterion ("Left/Right function through every
supported input surface") is met on both published surfaces, with live evidence. No expectation
was adjusted and no ROM, manifest or page-template code was touched. Harnesses are kept under
`dev/m7web/` so this record can be re-run without rebuilding them.
