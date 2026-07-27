# LZSS gallery: evacuate immutable graphics from Bank `$00`

Status: planned
Target: retain the ordinary **8 Mbit (1 MiB) LoROM** layout while making Bank
`$00` runtime/code-only and recovering several KiB of near ROM space.

## Why

Bank `$00` is the only bank shared by startup, runtime code, the SNES header,
vectors, near constants, and near-pointer metadata. The 62-work gallery links,
but the general all-demo build already shows that small toolchain/optimization
changes can push its `.rodata` across the header at `$00:FFB0`.

The current focused link map identifies these large immutable residents:

| Bank `$00` item | Current size | Intended destination |
|---|---:|---|
| Waldo `FONT16` | 4,096 B | packed asset bank |
| `FONT8` | 1,024 B | packed asset bank |
| `SINCOS` | 512 B | packed asset bank if far reads are cheap enough |
| `GALLERY_ASSETS` descriptors | 1,736 B | remain near initially; compact separately |
| strings | about 2,689 B | evaluate generated far string pool |

Moving both fonts alone recovers **5,120 bytes**. Bank `$1F` currently has
**8,105 bytes free**, enough for both fonts and the 512-byte sine table without
increasing cartridge size. Placement must nevertheless be decided by romopt,
not hard-coded to `$1F`.

## Scope

Move immutable graphics and CHR source material out of Bank `$00`:

- 16×16 Waldo font;
- 8×8 font;
- prebuilt Previous/Next chevron sprite CHR;
- title-screen tiles, tilemap, palette, and background art if any copy is
  linked into Bank `$00`;
- other static BG/OBJ CHR or palettes discovered by the map audit;
- optionally `SINCOS`, after measuring the cost of far reads.

Do **not** move:

- executable code, vectors, header, startup records, or HDMA tables that must
  be writable;
- `chrbuf`, `objchr`, framebuffers, OAM staging, or other WRAM work areas;
- data merely because its name contains `bg`—`bgmode_tab` and `tm_tab` are
  runtime-generated writable HDMA tables.

## Design

### 1. Make generated assets authoritative

Add a generated shared-asset manifest alongside the artwork report. Each entry
records:

- symbolic name and source/generator;
- raw byte count and alignment;
- required representation (`2bpp CHR`, `4bpp OBJ CHR`, tilemap, palette, or
  lookup table);
- assigned romopt bank and offset;
- SHA-256.

Feed shared assets and artwork streams/palettes into one stable
first-fit-decreasing romopt pass. Bank `$00` remains ineligible. Assert that
all resulting banks are `$01–$1F`.

### 2. Prefer VRAM-ready blobs

Generate the fonts and chevrons in the exact byte order VRAM consumes. This
avoids keeping the source font tables near merely so startup C code can
reformat them.

- `FONT16`: generate the four 8×8 tiles per Waldo glyph in final 2bpp order.
- `FONT8`: retain the generated glyph appearance, but emit final 2bpp CHR.
- chevrons: generate all animation poses as final 4bpp OBJ CHR rather than
  synthesizing pixels into `objchr` at startup.
- title/background resources: preserve their native tile, map, and palette
  files and link those bytes directly.

Keep the existing generated headers as declarations only. Large definitions
must live in explicitly assigned `.gallery_XX`/shared-asset sections.

### 3. Add a far-ROM-to-VRAM upload primitive

Introduce one audited helper accepting:

- VRAM word destination;
- far source pointer (16-bit address plus ROM bank);
- byte/word count;
- VMAIN increment mode.

The helper programs DMA source bank explicitly and runs only while forced
blank or in a bounded VBlank transfer. It must not create a near pointer from
a far asset. Fonts and static CHR should upload once during startup force
blank.

For very small tables used continuously by the CPU, compare:

1. direct far loads;
2. one startup copy to WRAM;
3. leaving the table near.

Move `SINCOS` only if code size plus access cost remains a net Bank `$00`
improvement and the frame benchmark does not regress.

### 4. Audit title/background ownership

Trace `m7splash_begin/end`, title-card helpers, and every binary/array referenced
by gallery startup. Classify each object:

- code;
- immutable ROM graphic;
- immutable CPU lookup table;
- writable WRAM state.

Any immutable graphic in `.rodata` becomes a packed far asset. Document “none”
explicitly if the title background is procedurally generated and therefore has
no ROM blob to move.

### 5. Keep metadata compact and intentional

After graphics move, evaluate the remaining `GALLERY_ASSETS` and string pool:

- keep the hot fixed-width descriptor near if it avoids repeated far loads;
- replace repeated pointer fields with offsets/indices where profitable;
- consider a generated far UTF/ASCII string pool with a small near descriptor;
- do not trade several hundred bytes of access code for negligible data
  savings.

This is a second pass, not a prerequisite for moving CHR.

## Enforcement

Add a post-link Bank `$00` budget check that:

- parses `build/lzss-gallery.map`;
- rejects `FONT8`, `FONT16`, chevron/title/BG/OBJ CHR, palettes, or known binary
  graphic symbols in Bank `$00`;
- reports code, strings, descriptors, lookup tables, writable initializers,
  header/vectors, and remaining free bytes separately;
- enforces a minimum Bank `$00` safety margin (initial proposal: **4 KiB**
  before `$00:FFB0`);
- confirms shared assets occupy only banks `$01–$1F`;
- feeds the existing HTML ROM-map renderer, so the visual map matches linked
  symbol addresses rather than generator guesses.

Wire the check into the focused gallery task and the repository SNES quality
gate.

## Validation

1. Regenerate assets twice and compare hashes and bank assignments.
2. Build with `-Oz` and the normal all-demo build configuration.
3. Verify an exact **8 Mbit (1 MiB)** file, map mode `$20`, checksum, complement,
   header, and vectors.
4. Inspect the ROM map: Bank `$00` contains no immutable graphics.
5. Capture the title, first artwork, both chevrons, captions, and at least one
   later artwork after repacking.
6. Run the VBlank/forced-blank write gate; no VRAM/CGRAM/OAM write may occur
   during active display.
7. Run navigation cancellation in both directions during decode, compress,
   compare, and second decode.
8. Run the complete 62-work SNES oracle and verify corpus result.
9. Compare per-stage frame counts before/after; record any `SINCOS` or far-load
   regression.
10. Re-render `rom-map.html`, update the implementation record with exact
    before/after Bank `$00` bytes, and publish the identical ROM SHA-256 to
    biohack.net and indri.studio.

## Completion record

Fill in during implementation:

- Bank `$00` used/free before:
- Bank `$00` used/free after:
- assets moved, sizes, banks, and offsets:
- final cartridge: **8 Mbit (1 MiB)**:
- final Bank `$1F` free:
- ROM SHA-256:
- checksum/complement:
- complete oracle result and frame count:
- biohack.net release:
- indri.studio release:
