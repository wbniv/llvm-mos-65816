# SNES display-quality contract and enforcement

Date: 2026-07-27
Status: implemented

## Goal

Turn the recurring display regressions—unsafe PPU writes, force-blank flashes,
missed presentation deadlines, and torn frames—into explicit, automated
failures before a ROM is published.

## Contract

1. VRAM, CGRAM, and OAM are changed only during VBlank or the initial
   force-blank setup. HBlank is not a general upload window; scanline changes
   use HDMA.
2. Once application video is enabled, it stays enabled. A title may return to
   force blank exactly once as a documented handoff before application display
   initialization.
3. A 60 Hz presentation path does at most one display commit per VBlank and
   keeps its worst-case upload below the measured VBlank budget.
4. A visible frame is published atomically: computation may be incremental,
   but the displayed buffer changes only at a frame boundary.
5. OAM updates are complete shadow-OAM/DMA transactions; palette and tilemap
   changes that must agree are committed in the same VBlank.
6. Input sampling is once per frame and never waits behind long-running work.
7. DMA/HDMA channel ownership is explicit, and a channel is not reconfigured
   while active.
8. NTSC is the current 60 Hz target. PAL behavior must remain safe, but is not
   represented as 60 fps.

## Enforcement layers

### Fast gate (every commit and CI)

`dev/snes-display-quality.py` checks the source contract, known PPU-access
sites, force-blank writes, upload-budget constants, and the canonical
`display_frame()` order. Existing legacy access sites are captured in a
reviewed baseline; a new site fails until it is moved behind the display/upload
API or deliberately reviewed into the baseline.

The repository pre-commit wrapper runs the user's shared hook and then the
staged-aware fast gate. `task snes-display-quality` runs it directly.

### Emulator gate (build/release)

`task snes-display-quality-emulator SITE=...` runs the existing bsnes-jg
manifest self-check and per-frame force-blank-bleed detector across published
ROMs. It detects transient black bands caused by a DMA crossing into active
display. This remains slower and is intentionally not a commit hook.

The next emulator instrumentation increment will observe writes to `$2100`,
`$2104`, `$2118/$2119`, `$2122`, `$420b`, and `$420c`, tagging each with the
PPU scanline and force-blank state. That converts the source-level access rule
into a runtime assertion and can also report present cadence. It is deferred
until the bsnes callback has a stable public interface; the current gate does
not pretend framebuffer heuristics can prove every write was legal.

## Delivery

- [x] Write the durable display-quality contract.
- [x] Add a dependency-free fast checker and reviewed legacy baseline.
- [x] Add Taskfile entry points.
- [x] Add the fast gate to GitHub Actions.
- [x] Add a repository pre-commit wrapper without losing the shared hook.
- [x] Retain emulator manifest, checksum, and blank-bleed enforcement.
- [x] Document baseline review and emergency bypass.

## Acceptance

- A newly introduced direct VRAM/CGRAM/OAM write fails the fast gate.
- A newly introduced force-blank write fails the fast gate.
- Breaking the `wait VBlank -> flush -> enable` order fails the fast gate.
- Raising the declared tile upload above the VBlank budget fails the fast gate.
- The current tree passes without rewriting unrelated legacy demos.
- A commit can be made with `SNESDQ_SKIP=1` only as an explicit, visible
  emergency bypass; CI still runs the gate.
