# Plan — SNES hardware reference docs + subsystem-split `snes.h` + generators

## Context

The project is an llvm-mos fork adding 16-bit-accumulator 65816 codegen with a SNES platform. The
on-screen renderer (Blossom Phase 2) is **parked** pending the sibling branch `wt/321-mandelbrot`'s
Track 3 merge. In the meantime the user wants durable **reference documentation** plus a restructured
HAL header:

1. A **SNES hardware summary** (narrative).
2. A **complete CPU-visible MMIO register map** — every register, every bit.
3. A **compact 65816 reference** — omitting 8-bit-only detail *except* the 8↔16-bit mode switching
   for A and X/Y.
4. An **updated `snes.h`**.

Two cross-cutting requirements from the user:
- **Generate the docs from source**, not hand-maintained: the MMIO docs from the `.h` files; the 65816
  reference **from the in-tree LLVM-MOS backend TableGen**, **validated against the canonical
  (CC-BY-SA) opcode matrix as a correctness oracle** ("#2 but test correctness against #3").
- This validation **doubles as a correctness audit of our LLVM backend's 65816 instruction
  encodings** — any TableGen-vs-canonical mismatch is a candidate backend defect, surfaced as a
  first-class report (the project's "differential gate" philosophy applied to the ISA).

### Constraints discovered during research
- **Hot shared tree.** The sibling branch is *actively* editing the single-file `snes.h`
  (`platforms/snes/snes.h`, 114 lines on `wt/321-mandelbrot`, 35 lines on `main`). I will **adopt its
  exact symbol names verbatim** (`REG_*`, `_SNES_REG8/16`, `SNES_RGB/BGSC/M7`, `snes_vram_addr`,
  `snes_ppu_reset_blank`, `INIDISP_*`, `VMAIN_*`, `TM_*`, `BGMODE_*`) so the eventual merge is a union,
  not a rename war. Work happens on a **feature worktree** off `main`.
- **License caution.** The repo treats external refs as cite-don't-redistribute
  (`docs/refs/65816-c-abi/SOURCES.md`: vendored locally, gitignored, sha256-pinned, cited by
  page/line). The 65816 output must stay **permissive** (generated from in-tree Apache-2.0-w-LLVM-
  exception TableGen); the canonical matrix is used only as a *correctness oracle*, vendored + cited,
  **never copied** into output.
- **House style.** Generators follow `tools/gen-sqrt-lut.py` (argparse, type hints, top docstring
  naming the generator, emit to stdout, `sys.exit("msg")` on error). Reference docs live under
  `docs/refs/<topic>/`.

## Locked decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Subsystem-split headers under a thin umbrella `snes.h`** | 1:1 header→doc-section mapping for the generator; idiomatic SNES-SDK layout (pvsneslib/libSFX); less contention on the hot tree; `#include <snes.h>` still pulls everything (zero ergonomic cost). |
| 2 | **MMIO register-map `.md` generated from annotated headers** | Single source of truth = the `.h`; the generator also cross-checks each `@reg` address against its `_SNES_REG8/16(0x…)` literal (free typo-catcher). |
| 3 | **Register scope = CPU-visible MMIO only** (`$2100–$21FF`, `$4016–$43FF`) | User-chosen. S-DSP/SPC700 are a separate processor behind the four `$214x` ports — noted, not mapped. |
| 4 | **65816 ref generated from LLVM-MOS TableGen via `llvm-tblgen --dump-json`, validated against the canonical matrix** | User-chosen (#2 + oracle #3). Permissive, authoritative, toolchain-consistent; validation = backend audit. |
| 5 | **Hardware summary = authored narrative** | Prose/architecture overview isn't header-derivable; cross-links the generated register map + 65816 ref. |

## Header layout (subsystem split)

Seed from the sibling's `snes.h` (the superset), then partition by the six canonical address ranges.
**All existing symbol names kept byte-identical** — this is a *reorganization + completion*, no renames.

| New header | Address range | Contents |
|------------|---------------|----------|
| `snes_ppu.h` | `$2100–$213F` | Display (INIDISP/SETINI), OBSEL + OAM (`$2102–$2104`), BGMODE/MOSAIC, BGnSC, BG12/34NBA, scroll BGnH/VOFS, VRAM (VMAIN/VMADD/VMDATA 8+16), Mode 7 (`$211A–$2120`), CGRAM (CGADD/CGDATA), windows (`$2123–$212B`), TM/TS/TMW/TSW, color math (CGWSEL/CGADSUB/COLDATA), read ports (`$2134–$213F`). **Plus PPU helpers/constants** (`snes_vram_addr`, `snes_ppu_reset_blank`, `SNES_RGB`, `SNES_BGSC`, `SNES_M7`, `INIDISP_*`, `VMAIN_*`, `TM_*`, `BGMODE_*`). |
| `snes_dma.h` | `$4300–$437F` + `$420B/$420C` | **All 8 channels** (DMAPx, BBADx, A1TxL/H, A1Bx, DASxL/H, DASBx, A2AxL/H, NLTRx) — current `snes.h` has only ch0; expand to ch0–7 (design for N). MDMAEN/HDMAEN triggers + DMAP bit constants. |
| `snes_cpu.h` | `$4200–$421F` | NMITIMEN, WRIO, **hardware mul/div** (WRMPYA/B, WRDIVL/H/B, RDMPYL/H, RDDIVL/H), IRQ timers (HTIME/VTIME), MEMSEL, RDNMI, TIMEUP, HVBJOY, RDIO. |
| `snes_joypad.h` | `$4218–$421F`, `$4016/7` | Auto-read JOY1–4, old-style `$4016/$4017`, cross-ref the NMITIMEN auto-joypad bit. |
| `snes_apu.h` | `$2140–$2143` | The four APU I/O ports + a note that S-DSP/SPC700 internals are out of scope (separate address space behind these ports). |
| `snes_wram.h` | `$2180–$2183` | WMDATA, WMADDL/M/H. |
| `snes.h` (umbrella) | — | Keeps the include guard; `#include`s the six subsystem headers. Preserves `#include <snes.h>` for all current users (`hello.c`, and `mandel-display.c` post-merge). |

### Annotation schema (drives the register-map generator)

```c
/* @reg INIDISP $2100 W  Display control 1 — force-blank + master brightness.
 * @bit  7     FBLANK   force blank (1 = screen off; VRAM/CGRAM/OAM writable)
 * @bits 3-0   BRIGHT   master brightness 0..15  ((N+1)/16 intensity)
 */
#define REG_INIDISP _SNES_REG8(0x2100)
```

- `@reg NAME $ADDR R|W|RW  one-line purpose` immediately precedes the `#define`.
- `@bit N LABEL desc` / `@bits HI-LO LABEL desc` for the bitfields.
- Generator asserts: annotation `$ADDR` == the `_SNES_REG8/16(0x…)` literal; bit ranges in 0–7, no
  overlap. Mismatch → non-zero exit (catches header edits that drift from their docs).
- Bit-level facts sourced from fullsnes / SNESdev wiki / anomie (facts, cited in the summary's SOURCES).

## Generators (`tools/`, gen-sqrt-lut.py style)

**`tools/gen-snes-regmap.py`** — parse the annotated subsystem headers → emit
`docs/refs/snes-hardware/snes-register-map.md`: one section per header, a register table
(`addr | name | R/W | purpose`) + a per-register bitfield table. Leads with
`<!-- generated by tools/gen-snes-regmap.py — edit the headers, not this file -->`. Runs the
self-consistency assertions above.

**`tools/gen-65816-ref.py`** — emit `docs/refs/65816/65816-reference.md`:
1. Locate the build tree's `llvm-tblgen` (same discovery as dev scripts find `mos-clang`; FATAL with
   "run dev/run.sh toolchain" if absent). Run `llvm-tblgen --dump-json` on the MOS target `.td` to get
   structured instruction records.
2. Per instruction extract: mnemonic, **opcode byte** (`op` field / `aaabbbcc`), **addressing mode**
   (`AddressingMode.OperandsStr`), **size**, and feature predicate (to tag 65816-only / accum16).
3. **Filter per the user's brief:** lead with the 16-bit programming model (E/M/X flags, `XCE`,
   `REP`/`SEP`), then the instruction table focused on native-mode/16-bit-relevant ops; explicitly
   flag the mode-switching and M/X-width-dependent instructions. Drop emulation-mode-only minutiae.
4. **Validate against the oracle** (vendored canonical matrix, gitignored, sha256 in
   `docs/refs/65816/SOURCES.md`): per opcode compare mnemonic + addressing mode + length; write
   `docs/refs/65816/65816-opcode-audit.md` (the **backend correctness audit** — ideally 0 discrepancies;
   any real divergence is a backend finding to file). Output `.md` carries a permissive header noting
   "validated against <oracle> (cited, not copied)".

**Oracle vendoring** — extend `dev/fetch-refs.sh` (or mirror its pattern) to fetch the canonical matrix
locally + record sha256 in `docs/refs/65816/SOURCES.md` (same shape as `docs/refs/65816-c-abi/SOURCES.md`).

## Authored doc

**`docs/refs/snes-hardware/snes-hardware-summary.md`** — narrative: CPU (5A22/65816, clocks, NTSC/PAL),
WRAM (128 KB, `$7E/$7F` + low-RAM mirror), PPU1/2 (VRAM 64 KB word-addressed, CGRAM 512 B, OAM 544 B),
BG modes 0–7 incl. Mode 7, DMA/HDMA (8 ch), APU overview, memory map (LoROM/HiROM), timing/V-blank/NMI.
Cross-links the generated register map + 65816 reference. Facts cited (fullsnes/SNESdev/anomie/Copetti).

## Wiring & verification

**Wiring:** `Taskfile.yml` gets `gen-docs` (regenerate all three) and `check-docs` (regenerate +
assert `git diff` clean — drift guard). Optional `dev/run.sh` sub-task to run the 65816 audit in-container.

**Verification steps (run + paste raw output + PASS/FAIL into the executed plan):**
1. **Headers compile** — build `examples/snes/hello.c` against the umbrella `snes.h`; `-verify-machineinstrs` clean.
2. **No renames vs sibling** — diff symbol names: new headers ⊇ `wt/321-mandelbrot:snes.h`, zero removed/renamed (merge stays additive).
3. **Register-map generator** — `tools/gen-snes-regmap.py` exits 0 (self-consistency passes); `check-docs` shows committed `.md` == regenerated (no drift).
4. **65816 generator + audit** — `tools/gen-65816-ref.py` runs; `65816-opcode-audit.md` reports 0 discrepancies vs the oracle (or enumerates genuine backend findings to triage).
5. **Markdown preview** — `task md -- <each generated/authored .md>` renders cleanly.

## Verification results (executed 2026-06-25, on `wt/321-snes-hwref`)

Generators run host-side; `LLVM_TBLGEN`/`MOS_TD` pointed at the main checkout's `build/`+`vendor/`
(the worktree has neither — see `docs/howto-feature-worktree.md`).

**1. Headers compile** — `mos-clang --config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -mllvm -verify-machineinstrs -I platforms/snes -Os -c examples/snes/hello.c`

```
PASS: hello.c compiles, verifier clean
```
Also confirmed each subsystem header compiles standalone, and that `<snes.h>` resolves to the new
umbrella (a new-only symbol `REG_HDMAEN`/`REG_DMAP7` compiles with `-I platforms/snes`, fails without).
**PASS**

**2. No renames vs sibling** — every `#define`/helper symbol in `wt/321-mandelbrot:platforms/snes/snes.h` present in the new headers.

```
sibling symbols: 58   present in new headers: 58
MISSING: (none)
PASS — every sibling snes.h symbol survives verbatim; merge stays a union
```
**PASS**

**3. Register-map generator** — self-consistency gate + no drift.

```
exit=0  -> wrote 599 lines   (203 registers across 6 subsystems: PPU 66, DMA 90, CPU 25, joypad 14, APU 4, WRAM 4)
diff (committed .md vs fresh `tools/gen-snes-regmap.py`): no output
PASS: register map in sync (generator self-consistency gate passed)
```
**PASS**

**4. 65816 generator + audit** — live `llvm-tblgen` (2.5 s), no drift, audit verdict.

```
PASS: 65816 reference in sync       (254 opcodes)
PASS: 65816 audit in sync
**254 / 255 defined opcodes agree** (exact, width-rule, or synonym).
  ✓ exact 253 | ≈ width/signature 1 ($00 BRK, 1 vs 2 bytes) | ✗ missing 1 | — reserved 1 ($42 WDM)
```
**PASS with one genuine backend finding:** opcode **`$02 COP`** (coprocessor software-interrupt) is
**absent from the llvm-mos MC layer** — no `cop` in any `MOS*.td`; `$02` defines only other variants'
CLE/NXT/SXY. A real, low-severity 65816 assembler gap surfaced by the audit (exactly its purpose). The
BRK byte-count is the known signature-byte modelling choice (backend 1 B vs datasheet 2 B), not a defect.

**5. Markdown preview** — `task md` rendered each deliverable to HTML (browser).

```
snes-register-map.html (69 KB) | snes-hardware-summary.html (31 KB) | 65816-reference.html (52 KB) | 65816-opcode-audit.html (24 KB)
```
**PASS**

## Coordination note (sibling branch)

The **only** edit that conflicts with `wt/321-mandelbrot` is converting `snes.h` into the umbrella.
Mitigation: adopt its exact symbol names; when it merges, reconciliation = "move its (already-present)
symbols into the right subsystem header" — mechanical. New subsystem headers + generators + docs are
all *new files* → no conflict. Build on a feature worktree off `main`.

## Critical files

- **New:** `platforms/snes/snes_{ppu,dma,cpu,apu,wram,joypad}.h`; `tools/gen-snes-regmap.py`;
  `tools/gen-65816-ref.py`; `docs/refs/snes-hardware/{snes-hardware-summary,snes-register-map}.md`;
  `docs/refs/65816/{65816-reference,65816-opcode-audit,SOURCES}.md`.
- **Modified:** `platforms/snes/snes.h` (→ umbrella); `Taskfile.yml`; possibly `dev/run.sh`, `dev/fetch-refs.sh`.
- **Reused:** `tools/gen-sqrt-lut.py` (generator style); `docs/refs/65816-c-abi/SOURCES.md` (vendoring
  pattern); `vendor/llvm-mos/llvm/lib/Target/MOS/*.td` (65816 source of truth — `MOSInstrFormats.td`
  defines `Opcode`/`OpcodeABC`/`AddressingMode`; `MOSInstrInfo*.td` the instruction records).
- **Step 0 on execution:** copy this plan to `docs/plans/2026-06-25-snes-hardware-reference.md` and add
  the `TODO.md` entry (per the SRC plan-first workflow).
