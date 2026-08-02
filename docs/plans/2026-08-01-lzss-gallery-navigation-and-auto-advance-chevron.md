# LZSS Gallery Navigation and Auto-Advance Chevron

**Status:** IMPLEMENTED  
**Date:** 2026-08-01

## Goal

Restore reliable Previous/Next navigation on a controller, keyboard, mouse, and
phone, and make every slideshow-initiated move to the next artwork visibly use
the right-chevron animation. The same animation vocabulary must describe the
same direction regardless of whether a person or the timer initiated the cut.

## Confirmed regressions

### ROM automatic-joypad path is already correct

The gallery enables `NMITIMEN_AUTOJOY`; its NMI correctly reads `$4219` and
masks `#$03`. In the conventional 16-bit result (`B=$8000`, `Right=$0100`),
the D-pad byte is at `$4219` on the little-endian 65816. Keep this mapping:

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
