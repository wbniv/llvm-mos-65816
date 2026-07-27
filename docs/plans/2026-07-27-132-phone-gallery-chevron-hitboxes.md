# 132 — Phone Gallery Chevron Hitboxes

**Status:** Ready to implement
**Surfaces:** biohack.net and indri.studio SNES players
**ROM:** unchanged; web input mapping only
**Mockup:** [phone-chevron-hitbox-mockups.html](2026-07-27-132-phone-gallery-chevron-hitboxes/phone-chevron-hitbox-mockups.html)

## Goal

Stop treating the left and right halves of the SNES canvas as Previous/Next controls. On phones,
only a small square centered on each visible in-ROM chevron should emit a momentary SNES Left or
Right press.

## Current defect

The shared player currently chooses direction solely from the pointer's horizontal half:

```js
e.clientX < r.left + r.width / 2 ? JOY.Left : JOY.Right
```

Consequences:

- tapping artwork unexpectedly changes slides;
- tapping status text changes slides;
- nearly every fullscreen tap becomes navigation;
- the interaction area does not visually correspond to the controls.

## ROM geometry contract

The gallery draws 16×16 OBJ chevrons at:

| Control | Sprite X | Sprite Y |
|---|---:|---:|
| Previous | 2 | 72 or 76 |
| Next | 238 | 72 or 76 |

Y is `display_height / 2 - 8`; the 26 works use display heights 160 or 168.

Define fixed 24×24 logical hit squares:

| Control | Logical X | Logical Y |
|---|---:|---:|
| Previous | `[0, 24)` | `[70, 94)` |
| Next | `[232, 256)` | `[70, 94)` |

This contains either 16×16 sprite position with approximately four logical pixels of touch padding,
without extending into the artwork body. The squares scale with the canvas in portrait, landscape,
embedded, and fullscreen modes.

## Coordinate mapping

On `pointerdown`:

1. Require `current === "lzss-gallery"`.
2. Read `canvas.getBoundingClientRect()`.
3. Convert client coordinates to the canvas's 256×224 logical coordinate system:

   ```text
   x = (clientX - rect.left) × canvas.width / rect.width
   y = (clientY - rect.top)  × canvas.height / rect.height
   ```

4. Hit-test the two logical squares.
5. If neither square is hit, return without calling `preventDefault()` and without changing `pad`.
6. If hit, prevent default, apply the corresponding joypad bit, and retain the existing 120 ms
   momentary-release behavior.

Pointer-up and pointer-cancel continue clearing both directional bits.

## Mockups

The mockup shows:

- portrait phone;
- landscape phone;
- fullscreen safe-area framing;
- visible 24×24 logical hit squares for review only;
- rejected half-screen regions crossed out.

Hitbox outlines are debug visualization and must not ship in the player.

## Implementation

1. Add a pure logical-coordinate hit-test helper to both player copies.
2. Replace the half-canvas ternary with scaled X/Y mapping and helper invocation.
3. Do not add DOM overlay buttons; the ROM chevrons remain the only visible controls.
4. Preserve keyboard Left/Right behavior.
5. Preserve pointer capture/release timing and fullscreen click handling.
6. Keep the biohack and indri player-specific code outside this shared block unchanged.

## Verification

Test logical points:

| Point | Expected |
|---|---|
| `(12, 82)` | Previous |
| `(244, 82)` | Next |
| `(24, 82)` | none |
| `(231.9, 82)` | none |
| `(128, 82)` | none |
| `(12, 69.9)` | none |
| `(244, 94)` | none |
| artwork center | none |
| status-text area | none |

Then verify:

1. `node --check` passes for both player files.
2. The shared hit-test block is byte-identical between sites.
3. Portrait embedded mode maps both squares correctly.
4. Landscape fullscreen maps both squares correctly after orientation change.
5. Tapping outside a chevron does not navigate or suppress unrelated fullscreen behavior.
6. Pressing a chevron still produces the ROM's bounce/glow feedback.
7. Both site builds pass.

## Cartridge-map impact

None. This changes browser input mapping, not SNES ROM bytes or linker placement. The latest
linker-generated cartridge quadtree remains authoritative and is not regenerated for this web-only
change.

## Delivery

1. Commit the plan/mockup in the llvm-mos-65816 repository.
2. Commit each site's player change independently.
3. Push all three repositories.
4. Publish patch releases for both sites.
5. Wait for both deployment workflows.
6. Verify the live player JavaScript contains bounded 24×24 hitboxes and no half-screen ternary.

## Acceptance

- Only the visible chevron squares trigger Previous/Next.
- The rest of the canvas is inert for gallery navigation.
- Hitboxes remain aligned in portrait, landscape, embedded, and fullscreen modes.
- Keyboard controls and ROM animation remain unchanged.
- Both live sites serve the bounded-hitbox player.
