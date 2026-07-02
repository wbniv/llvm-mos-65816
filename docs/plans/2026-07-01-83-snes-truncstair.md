# #83 — SNES Truncation Staircase: Round-Toward-Zero Quantizer

**Status:** ⚠️ **BLOCKED ON A REAL COMPILER BUG** (this is the demo doing its job).
Demo **#83** of the **compiler stress-test demo battery** (Round 5). The gate surfaced a
**whole-program-dependent ZP-allocation miscompile** — host/corpus = `0x02CA`, full display
ROM = `0x1EB5`. NOT shipped/published until the compiler is fixed (per the "never work around
the compiler" rule). See **§Compiler bug** below.

## ⚠️ Compiler bug (2026-07-01)

**Differential FAIL** — the success condition of a stress-test demo:

| Build | Gate ZP frame base | `corpus_result` | Verdict |
|-------|--------------------|-----------------|---------|
| host oracle (x86) | — | `0x02CA` | ground truth |
| corpus slice `truncstair_sim.c` (+mos-a16) | `$20` | `0x02CA` | ✅ correct |
| bare full ROM (gate + spin, no display) | `$20` | `0x02CA` | ✅ correct |
| full display ROM `truncstair.c` (+mos-a16) | `$69` | `0x1EB5` | ❌ **WRONG** |

**Diagnosis (isolate → shrink):**
1. The generated `truncstair_gate_crc` assembly is **byte-identical** between the passing
   (corpus) and failing (full-ROM) LTO builds — only basic-block label numbers differ
   (`.LBB1_*` vs `.LBB4_*`). Same instructions, same `mos8(.Ltruncstair_gate_crc_zp_stk+N)`
   offsets.
2. The **only** difference is the linker-assigned base of the function's persistent static ZP
   frame: **`$20` (corpus, h at `$26:$27`) vs `$69` (full ROM, h at `$6F:$70`).** The frame is
   pushed to `$69` by the higher whole-program ZP pressure once the display/title code links in.
3. **No ISR runs during the gate** — `snes_wait_vblank()` (snes_cpu.h:127) is a poll loop
   (`while(!(REG_RDNMI & RDNMI_FLAG)){}`), so nothing fires asynchronously to clobber the frame.
4. **None** of the soft-float call-tree routines (`__floatsisf` @0xabf3, `__fixsfsi` @0xab3b,
   `__mulsf3` @0xb18b/2311 B, `__subsf3` @0xba92, `__mulhi3` @0xaff2) write `$69–$74` — they use
   `$7B–$7F` as scratch (verified by full-extent disasm scan of each routine).
5. Therefore: identical code + no concurrent writer, yet frame-at-`$69` computes wrong while
   frame-at-`$20` computes right. This is a **whole-program-dependent ZP-allocation / aliasing
   miscompile** in the backend — the value `h`, held in the static ZP frame across the
   soft-float call chain, is corrupted only at the `$69` placement.

**Suspected root cause:** `MOSZeroPageAlloc` static-frame interference analysis vs. the
soft-float call tree — a persistent ZP frame placed at `$69` aliases ZP that the soft-float
call chain (transitively, possibly via soft-stack/scratch or a helper not caught by a direct
store scan) actually uses, an interference edge the allocator missed. Only the full program's
ZP layout puts the frame there, which is why the isolated corpus + bare ROM pass.

**Minimal reproducer:** `docs/plans/spikes/2026-07-01-83-truncstair-zpalloc-miscompile-repro.c`.

**Status:** diagnosis reached the project's 3-hypothesis debugging cap without a pinned one-line
fix; a fix requires deeper `MOSZeroPageAlloc` tracing on a throwaway `vendor/llvm-mos` worktree
plus a shared-toolchain rebuild (coordinated action). **Escalated to the user for direction**
(fix now vs. log + continue the demo loop). The G_FPTOSI/G_SITOFP codegen this demo targets is
itself correct (corpus is bit-exact) — the bug is orthogonal ZP allocation.

### Update — DEFINITIVE root-cause class (2026-07-01, deeper investigation)

Extended cross-emulator testing proves this is a **read of uninitialized memory in the
generated code** — the same UB-free source (bit-exact on host) produces **three different
deterministic results** depending on machine power-on RAM state:

| Config (full display ROM) | Result | vs host `0x02CA` |
|---------------------------|--------|-------------------|
| host oracle (x86)         | `0x02CA` | — |
| **MAME**, +mos-a16        | `0x02CA` | ✅ matches (MAME zero-inits WRAM) |
| **bsnes-jg**, +mos-a16    | `0x1EB5` | ❌ differs |
| **bsnes-jg**, default-8bit| `0x0736` | ❌ differs *again* |

Same ROM bytes → MAME and bsnes-jg disagree; and the default-8-bit build (no `rep`/`sep`, so
not an a16 CPU-emulation edge case) diverges to yet a third value. The only variable is the
**power-on WRAM pattern** (MAME fills 0x00 → matches the host's zeroed state; bsnes-jg uses a
non-zero power-on pattern). Therefore the generated code **reads a WRAM location before writing
it**, and the demo happens to pass only when that location reads as zero. This is a genuine
backend miscompile (the C never reads uninitialized storage), exposed by the gate's static ZP
frame landing in the higher-pressure region (`$69`) only when the display/title code is linked.

**Diagnostic wall hit:** the gate's own frame slots are all write-before-read (verified by a
first-touch trace of the generated `.s`), so the uninitialized read is in a **callee's scratch**
or a frame/soft-stack slot the gate reads across the soft-float call chain — not visible at the
gate-`.s` level. MAME lua `install_read_tap` did not fire in this MAME build, and bsnes-jg is not
lua-instrumentable, so an emulator read-watchpoint could not pinpoint the exact address. The next
step is **MIR-level**: build a failing repro through `llc -print-after-all -debug-only=…` on a
throwaway `vendor/llvm-mos` worktree to find the pass that emits the undef read (candidates:
`MOSZeroPageAlloc` static-frame coloring vs. the soft-float call tree, or a spill/reload of an
`undef` lane). That requires a shared-toolchain rebuild — pending user go-ahead.

---

**(Original plan below — the demo design is complete; only the compiler fix blocks publication.)**

## Context

`G_FPTOSI` (float→int) and `G_SITOFP` (int→float) are the fundamental float↔integer conversion
nodes. On 65816 they lower to `__fixsfsi` (trunc toward zero) and `__floatsisf` respectively.

**Critical SDK gap documented here:** `truncf`, `floorf`, `ceilf` are all `.unsupported()` in
the MOS legalizer — calling them directly would fail to link (no symbol in the SDK). The pattern
`(float)(int)x` achieves `truncf(x)` via G_FPTOSI + G_SITOFP without any libcall.

Distinct from:
- **#82 speedcap** — uses G_FPTOSI/G_SITOFP incidentally for velocity→pixel updates; primary
  corner is G_FMINNUM/G_FMAXNUM.
- **#77 satcast** — uses G_FPTOSI as the saturating-cast output after fmin/fmax clamping.
- **#55 triwave** — integer modular arithmetic, no float→int conversion.

## Algorithm

```
For i in [0, GATE_N=48):
    x_int = i - 24                         // integer offset
    x_f   = (float)x_int * 0.375f         // G_SITOFP → __floatsisf; G_FMUL → __mulsf3
    q     = (int16_t)x_f                  // G_FPTOSI → __fixsfsi  (trunc toward zero)
    qf    = (float)q                      // G_SITOFP → __floatsisf
    diff  = x_f - qf                      // G_FSUB   → __subsf3  (fractional remainder)
    d16   = (int16_t)(diff * 16.0f)       // G_FMUL + G_FPTOSI    (scale for CRC)
    fold(q, d16) → CRC

TS_STEP = 0.375f = 3/8 (exact in IEEE 754); x in [-9.0, 8.625], q in [-9..8].
Trunc-vs-floor diverge for negative non-integers (e.g. x=-0.75 → trunc=0, floor=-1).
```

## Screen layout

```
 col: 0         8         16        24        32
row 1: [HUD top: "TRUNCSTAIR CRC=XXXX  F=XXXX"]
row 2: ┌────────────────┐  (canvas top at tile row 2, col 8)
...    │  trunc band    │  rows 2-6 (tiles 0-4 in canvas = top 40px)
row 7: │  divider       │
row 8: │  floor band    │  rows 8-12
row13: │  divider       │
row14: │  round band    │  rows 14-17
       │  (unused)      │  rows 18-17
row17: └────────────────┘  (canvas bot at tile row 17, col 23)
row25: [HUD bot: "G_FPTOSI __FIXSFSI"]
```

Canvas: 128×128 (16×16 tiles) placed at BOX_COL=8, BOX_ROW=2.

## Display architecture

- BG3 2bpp via BitmapCanvas (chr=0x0000, map=0x4000).
- TextLayer: HUD top row 1, HUD bot row 25.
- TitleLayer: "G_FPTOSI" / "TRUNC STAIRCASE".

**Palette (CGRAM[0..3]):**
- 0 = SNES_RGB( 1,  2,  3) — dark background
- 1 = SNES_RGB( 4, 22, 18) — teal (positive stair region)
- 2 = SNES_RGB(28,  8,  4) — red-orange (negative stair region)
- 3 = SNES_RGB(28, 28, 28) — light (zero / divider)

## Files

| File | Purpose |
|------|---------|
| `examples/65816/truncstair.h` | Algorithm + gate CRC |
| `examples/snes/truncstair.c` | SNES ROM (3-band staircase, scrolling phase) |
| `examples/snes/corpus/truncstair_sim.c` | Corpus slice |
| `tools/truncstair-sim.c` | Host oracle |
| `dev/truncstair.sh` | Gate script |
| `dev/truncstair.lua` | MAME Lua assert |

## Differential gate

- `corpus_result = truncstair_gate_crc()` — 48 trunc/sitofp cycles, position fold.
- **EXPECT `0x????`** — fill after first run.
- **5-way bar** — no far pointers.
- **Disasm probes:** `__fixsfsi ≥ 1`, `__floatsisf ≥ 1`, `__mulsf3 ≥ 1`, `rep/sep ≥ 1`.

## Verification steps

1. Host oracle compiles and prints a plausible CRC.
2. ROM builds clean; snes-checksum.py exits 0.
3. Corpus slice host-compiles; exits 0.
4. `dev/run.sh truncstair` — gate PASS.
5. `dev/run.sh corpus-a16` — all slices PASS.
6. Inspect `build/truncstair-jg.png` — three-band staircase visible, trunc/floor/round diverge.
7. Copy screenshot → `docs/plans/screenshots/truncstair.png`.
8. /snes-rom-page publishes.

### Update 2 — mechanism pinned to `.zp.noinit` ZP-allocation collision (2026-07-01)

Linker-map + SDK-linkscript inspection nails the mechanism class:

- `corpus_result` lives at ZP `$67:$68` in **`.zp.bss`** (crt0 **zeroes** it) — the observed value is genuine.
- The gate's static frame `.Ltruncstair_gate_crc_zp_stk` and every other function's static ZP
  frame live in **`.zp` / `.zp.noinit`** (`>zp`, `NOLOAD` — crt0 does **NOT** zero it; it is
  power-on garbage on real hardware and on bsnes-jg). In the failing full ROM the gate frame is
  colored to `$69–$74` (40-byte `.zp.noinit` region begins at `$69`).
- The gate's own frame slots are all write-before-read (verified). So the uninitialized read is a
  **soft-float callee's `.zp.noinit` frame overlapping the gate's live frame** — an interference
  edge (gate → `__floatsisf`/`__mulsf3`/`__fixsfsi`/`__subsf3`) the ZP allocator **failed to
  record**, so lld placed the two frames on top of each other. MAME fills `.zp.noinit` with `0x00`
  at power-on, so the collided read returns 0 and the gate still lands on `0x02CA` (masking the
  bug); bsnes-jg's non-zero power-on pattern turns the same read into garbage → `0x1EB5`
  (`+mos-a16`) / `0x0736` (default-8-bit). At the `$20` placement (corpus / bare ROM) there is no
  overlap, so all emulators agree.

**Fix locus (candidate):** `MOSZeroPageAlloc` / the llvm-mos `.zp` interference model — the static
ZP frame of a function must be treated as **live across its soft-float (compiler-rt) libcalls**, so
its frame cannot be colored over a (transitive) callee's `.zp.noinit` frame. Requires backend work
on a throwaway `vendor/llvm-mos` worktree + a shared-toolchain rebuild.

**Instrumentation wall (why the exact overlapping slot isn't pinned yet):** MAME's zero-init masks
the read (so its write/read taps show a clean, correct run); MAME `install_read_tap` did not fire in
this build; bsnes-jg has no lua scripting. Pinpointing the exact colliding slot needs either a
working emulator read-watchpoint or MIR/`.zp`-layout tracing from a rebuilt debug toolchain. **This
is where I paused for direction** — the fix is a substantial backend + toolchain-rebuild effort and
I did not want to burn shared-tree rebuilds on a guess.
