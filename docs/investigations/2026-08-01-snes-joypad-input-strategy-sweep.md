# SNES Joypad Input Strategy Sweep

**Date:** 2026-08-01  
**Status:** Audit complete; remediation implemented, verification in progress  
**Scope:** `examples/snes/` ROM sources and their shared SNES input/display headers

## Question

Do the existing SNES ROM demos follow the proposed programming rule that ordinary VBlank-driven
programs should use the hardware automatic joypad reader (`$4200.AUTOJOY` plus `$4218–$421F`) and
reserve manual `$4016/$4017` serial polling for documented exceptions?

## Conclusion

No. Seven current ROM sources consume controller input. One—the SVX2 video reel under active
development—uses automatic joypad reading. Five use the shared manual-poll helper even though their
frame structure has no evident need for manual serial timing. The LZSS gallery contains a sixth
manual implementation inside NMI; that path has a real architectural constraint and must be
redesigned rather than mechanically replaced.

The other SNES examples do not consume controller input, so this policy does not apply to them.

## Remediation applied

- Added `snes_wait_autojoy()` and `snes_read_pad1_auto()` to the joypad HAL.
- Converted the shared `snesgfx` controller and display initialization to automatic reading.
- Converted Blossom to the automatic helper.
- Removed the gallery's inline serial loop. Its NMI consumes the previous completed `JOY1H` latch
  without waiting on the current frame's JOYBUSY interval, preserving decode-cancellation capture
  while reducing the VBlank instruction budget.
- Updated shared splash/title NMI restoration to retain AUTOJOY.
- Added the default-selection and readiness rules to the hardware summary and demo cookbook.
- Added `dev/snes-joypad-audit.sh`, which rejects new manual polling in ROM sources unless the
  source carries the explicit reviewed marker `SNES_MANUAL_JOYPAD_OK`.

## Audit method

The sweep searched C, headers, and assembly sources for:

- `snes_read_pad1()` and `controller_poll()`;
- direct `REG_JOYSER0`, `$4016`, and `$4017` access;
- direct `REG_JOY1` / `$4218` access;
- `NMITIMEN_AUTOJOY`; and
- writes to `REG_NMITIMEN` / `$4200` that can enable, disable, or accidentally discard AUTOJOY.

Representative commands:

```sh
rg -n "snes_read_pad1|controller_poll|REG_JOYSER|REG_JOY1|NMITIMEN_AUTOJOY" \
  examples/snes platforms/snes
rg -n -i "4016|4017|4218|4219|joyser|joy1" \
  examples/snes -g '*.c' -g '*.h' -g '*.s' -g '*.S'
rg -n "REG_NMITIMEN" examples/snes platforms/snes
```

The result was then traced through shared headers so indirect users of
`snesgfx/controller.h` were not missed.

## Inventory

| ROM | Input path | Timing location | Classification |
|---|---|---|---|
| `snes-video-reel` | `REG_JOY1`, AUTOJOY enabled | Playback loop | Conforming |
| `1d-ca` | `controller_poll()` → manual `$4016` | Before render/VBlank wait | Nonconforming; straightforward conversion |
| `invaders` | `controller_poll()` → manual `$4016` | Before game update/render | Nonconforming; straightforward conversion |
| `spirograph` | `controller_poll()` → manual `$4016` | Before plotting/render/VBlank wait | Nonconforming; straightforward conversion |
| `wireframe` | `controller_poll()` → manual `$4016` | Before drawing/render/VBlank wait | Nonconforming; straightforward conversion |
| `blossom` | Direct `snes_read_pad1()` | Before frame work/VBlank wait | Nonconforming; straightforward conversion |
| `lzss-gallery` | Inline-assembly `$4016` serial read | Inside NMI | Scoped manual exception; automatic-reader migration dropped every edge |

## Evidence by implementation family

### Shared `snesgfx` controller: four ROMs

`examples/snes/snesgfx/controller.h` documents and implements manual serial polling:

```c
static inline void controller_poll(Controller *c) {
  c->prev = c->cur;
  c->cur = snes_read_pad1();
}
```

It is used by:

- `examples/snes/1d-ca.c`;
- `examples/snes/invaders.c`;
- `examples/snes/spirograph.c`; and
- `examples/snes/wireframe.c`.

These programs poll before their render work and eventual VBlank wait. Manual polling therefore
does not currently appear to violate a measured VBlank upload budget, but it adds avoidable CPU
work and establishes the wrong default for future deadline-sensitive clients.

Changing only `controller_poll()` is insufficient. `examples/snes/snesgfx/display.h` currently
writes `REG_NMITIMEN = NMITIMEN_NMI`, and the shared title code also disables and restores NMI with
literal values that omit AUTOJOY. The display/input lifecycle must be converted as one unit.

### Blossom: one direct manual user

`examples/snes/blossom.c` enables NMI alone, calls `snes_read_pad1()` before its compute work, then
waits for VBlank before DMA and PPU writes. This is a straightforward candidate for automatic
reading, provided startup establishes one valid completed sample before edge detection begins.

### LZSS gallery: manual input inside NMI

`examples/snes/lzss-gallery.c` contains an inline-assembly serial latch and eight-bit read inside its
NMI handler. The handler records Left/Right edges and cancellation requests while the foreground
may be occupied by long decode work. This explains why input capture lives in the interrupt path.

It is not automatically a good reason to retain manual serial polling. The read consumes part of
the same VBlank window used for palette restoration, OAM work, and raster setup. However, automatic
results are not safe to consume until `$4212.JOYBUSY` clears, and waiting for that window inside NMI
would itself spend valuable VBlank time. The conversion therefore needs an explicit ownership
design, for example:

1. enable AUTOJOY continuously;
2. consume the most recent completed latch outside the time-critical beginning of NMI, or in a
   bounded late-NMI phase proven to occur after JOYBUSY clears;
3. retain a tiny NMI-visible navigation mailbox for foreground decode cancellation; and
4. prove that a direction press is not lost while foreground decoding is active.

This path needs its existing scripted navigation and VBlank-budget gates, not a search-and-replace.

### SVX2 video reel: conforming reference client

The transport implementation enables:

```c
REG_NMITIMEN = NMITIMEN_NMI | NMITIMEN_AUTOJOY;
```

and consumes `REG_JOY1`. An initial implementation used `snes_read_pad1()` in the decode/present
loop. The exact 4,000-frame regression immediately reported 41 deadline slips. Switching to the
automatic latch restored the existing zero-slip result. This is concrete evidence that manual
polling can convert apparently available headroom into presentation failures.

Automatic reading is not literally free: the hardware reader remains busy for a bounded interval
after VBlank begins, and software must not treat `$4218–$421F` as a fresh sample until JOYBUSY has
cleared. It is nevertheless the correct default here because it removes serial polling work from
the 65816 decode path.

### Follow-up: byte selection is part of the interface

The automatic result uses the conventional 16-bit masks (`B=$8000`, `Right=$0100`). Because the
65816 is little-endian, byte-sized D-pad code reads `$4219`, where Right/Left are bits 0/1;
`$4218` contains A/X/L/R in its upper nibble. Automatic-reader migrations must verify both timing
and this exact register/bit mapping. Prefer a 16-bit shared abstraction; any byte-sized hot path
needs a scripted input gate for the intended address.

## Shared infrastructure gaps

### No safe automatic-read helper

`platforms/snes/snes_joypad.h` exposes the automatic-read registers but supplies only the manual
`snes_read_pad1()` helper. The easiest API is therefore the non-default mechanism. Add helpers that
make readiness explicit, for example:

```c
static inline void snes_wait_autojoy(void) {
  while (REG_HVBJOY & HVBJOY_JOYBUSY) {}
}

static inline uint16_t snes_read_pad1_auto(void) {
  snes_wait_autojoy();
  return REG_JOY1;
}
```

Callers that intentionally use the previous completed sample at a documented safe point may read
the latch directly, but the general helper should not hide the readiness requirement.

### `$4200` ownership is fragmented

`REG_NMITIMEN` is write-only from the program's perspective. Literal assignments in display,
title, gallery, and demo code can silently discard AUTOJOY or IRQ configuration. Introduce an
owned shadow or a small API that composes the desired NMI/IRQ/AUTOJOY mask, and require subsystems
to restore the shadow rather than a hard-coded `NMITIMEN_NMI` value.

### Reference material is descriptive, not prescriptive

The register map correctly lists both access mechanisms but does not tell programmers which one to
choose. Add this rule to the hardware summary and SNES demo cookbook:

> Use automatic joypad reading by default for ordinary frame-driven games and demos. Use manual
> serial polling only when a documented timing or peripheral requirement makes automatic reading
> unsuitable.

Also document:

- the JOYBUSY readiness rule;
- the prohibition on simultaneous automatic and manual access;
- preservation of all `$4200` control bits;
- initial-sample and edge-detection behavior at startup;
- focus/reset behavior for browser-driven held buttons; and
- input-cost regression gates for deadline-sensitive loops.

Historical plans that explicitly selected manual input should remain historical records. Current
reference documentation and reusable headers should establish the new default.

## Remediation order

1. Add automatic-read helpers and the `$4200` ownership convention to the HAL and reference docs.
2. Convert `snesgfx/display.h`, `snesgfx/controller.h`, and title transitions together.
3. Rebuild and run scripted-input plus visual gates for `1d-ca`, `invaders`, `spirograph`, and
   `wireframe`.
4. Convert Blossom and rerun its controller differential, bloom, HDMA, and screenshot gates.
5. Design the gallery mailbox/late-sample conversion separately; measure NMI cycles before and
   after and rerun navigation, cancellation, palette, OAM, and long-decode tests.
6. Add a static audit that rejects new `snes_read_pad1()` or `$4016/$4017` use unless the source
   carries an explicit reviewed exception annotation.

## Required verification

For each converted ROM:

- held, pressed, and released edges match the previous behavior;
- the first sample after title/reset cannot create a false edge;
- input remains responsive under the longest compute/decode path;
- no DMA, HDMA, or presentation deadline budget regresses;
- existing host/target controller CRCs remain exact where present;
- MAME and bsnes-jg scripted-input checks pass; and
- screenshots and existing corpus/self-check results remain unchanged unless the visible control
  UI was intentionally altered.

For the gallery specifically, additionally prove that Left/Right can cancel or redirect an active
decode without waiting for it to finish and that the NMI VBlank budget improves or remains safely
bounded.

## Verification record

| Gate | Result |
|---|---|
| Static ROM-source audit | PASS — no manual access remains outside the HAL |
| SNES display-quality audit | PASS — 239 reviewed sensitive sites |
| `1d-ca` | PASS — target hash `$AB2C`, screenshot gate |
| `spirograph` | PASS — target hash `$32D4`, three deterministic captures |
| `wireframe` | PASS — target hash `$E737`, three deterministic captures |
| `blossom` | PASS — grid `$9047`, 64/64 nonzero scripted input frames, host/ROM controller replay `$EC5A` |
| `invaders` | bsnes-jg PASS for default and `+mos-a16`, target hash `$9D57`, three deterministic captures; MAME unavailable because the out-of-band SPC700 IPL is absent |
| `lzss-gallery` fast 62-work decode gate | PASS — `$5CF0` after 30,000 frames |
| `lzss-gallery` scripted navigation | PASS — a three-frame Right press increments the input-only `gallery_canceled` counter at frame 1,001; the former asset-1 check was vacuous because auto-advance also reaches asset 1 |
| `lzss-gallery` complete 700,000-frame visual/corpus gate | Running at time of this record |

The gallery NMI replacement reduces the input-capture path from approximately 48 dynamically
executed 65816 instructions (including eight five-instruction serial-bit iterations) to three
instructions (`LDA $4219`, `AND #$03`, `STA nav_pad_now`). From documented instruction timings,
that removes approximately 150 CPU cycles from every NMI before the existing palette/OAM work.

## Final assessment

| Category | Count |
|---|---:|
| Automatic-read interactive ROMs | 1 |
| Manual-read ROMs suitable for shared/direct conversion | 5 |
| Manual-read ROM requiring architectural review | 1 |
| Input-consuming ROMs audited | 7 |

The sweep found no other direct `$4016/$4017` or `$4218/$4219` users in the SNES example sources.
