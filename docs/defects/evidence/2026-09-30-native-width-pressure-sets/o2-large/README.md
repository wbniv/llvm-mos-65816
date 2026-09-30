# `-O2` speed gate on the large programs (dither, packrec, mvscrl)

Canonical record: [`mos-native-width-pressure-sets`](../../../mos-native-width-pressure-sets.json). Plan section: [`-O2` speed gate on large programs](../../../../plans/2026-09-30-native-register-pressure-sets.md#-o2-speed-gate-on-large-programs). The earlier evidence directories are unchanged; this one only adds to them. Nothing was built or applied: no LLVM build, no change to the split series, `vendor/` or `0002`.

Attribution: Claude Code 2.1.285 (`claude --version`), model Claude Opus 5.5 (`claude-opus-5-5`), `medium` reasoning effort (t3-opus-med agent definition; not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## Question

On 15 small corpus sims at `-O2`, turning the appended `A16`/`X16`/`Y16` sets off (`memb1`) used about 0.2% fewer master clocks than the ungated design (`t4`). A sound `-O2` gate would need a per-level subtarget. Does the gain hold on the large fixed-set programs dither, packrec and mvscrl, which had no runtime harness?

## Harnesses (`harness/`)

Each harness compiles the **unchanged demo translation unit** (`examples/snes/<demo>.c`, `#include`d) and runs the demo's own `main`. There is one substitution. [`harness_hook.h`](harness/harness_hook.h) rewrites `display_frame`'s `snes_wait_vblank()` call into `harness_vblank(d)`, where `d` is `display_frame`'s own `Display *`, the first member of every demo's `App`. The hook does three things:

- It switches NMI and HDMA off and returns at once, so frames run back to back. The measured clocks are then CPU work plus the fixed-size, budgeted upload DMA, which is identical for every variant, instead of v-blank waiting.
- When the demo's own state reaches the end frame, it folds the demo's WRAM output into 16 bits and writes it to `corpus_result`. The output is the algorithm state, the 4 KB canvas `chr` shadow, the HUD text shadow and the gate CRC. The probe stops on that write.
- The fold never equals the demo's gate value, so the probe cannot stop early on the demo's own `corpus_result` write.

| Harness | End condition (deterministic demo state) | Short / long run | Folded |
|---|---|---|---|
| `dither_run.c` | `a.t == 3·K` (K frames of `dither_frame`) | K = 6 / 12 | `a.t`, `out[48×48]`, canvas `chr`, text shadow, gate |
| `mvscrl_run.c` | `a.t == 7·K` (K scroll steps, 8 frames each) | K = 32 / 128 | `a.t`, `pos`, `mv.upper/lower`, both HDMA tables, canvas, text, gate |
| `packrec_run.c` | `a.t == K` (K loop frames; a record every 5) | K = 240 / 960 | `a.t`, `pr_rec`, `pr_hold`, `pk_n`, `pk_odd_wide`, `pk_check`, canvas, text, gate |

The measured region is the whole `main` from its entry. It covers app setup, the title (its 90–110 held frames run back to back), the gate CRC and K loop iterations. The two lengths split it: **loop** = long − short, and **setup** = short − loop·K₁/(K₂−K₁).

**Host oracle** ([`tools/host-oracle.sh`](tools/host-oracle.sh)). The same harness source, demo and snesgfx headers are built with the host `cc`, and SNES MMIO is mapped onto a 64 KiB host array. Three MMIO pointers are formed by a raw cast, `(volatile uint8_t *)(uintptr_t)X`: `upq_flush`'s DMA channel, the HDMA arm, and the SDK's `snes_ppu_reset_blank`. The tool rewrites only those casts, in a copy, to the same array. DMA only reads WRAM, so the host's WRAM state equals the console's. Outputs are in [`runtime/oracle.txt`](runtime/oracle.txt). A debug build confirmed the folded gate values equal each demo's documented host value: 0x80C4, 0x72A7 and 0x4676.

**Validation.** Every measured ROM wrote exactly the host-oracle value, which is what the probe stops on. Each ran twice, and every pair was identical. That is 64 of 64 passing `-O2` rows (LTO) and 32 of 32 (non-LTO), plus the `-O3` rows listed below.

## Method (`tools/`)

[`runtime-clocks-large.py`](tools/runtime-clocks-large.py) is the frozen [`opt-levels/tools/runtime-clocks.py`](../opt-levels/tools/runtime-clocks.py) with only the harness sources, the `-D` length and the oracle file changed. Everything else is the same: bsnes-jg cycle probe (`jgxcycles` `3c04775f…`), master clocks from `main` to the expected `corpus_result` write, two runs per ROM, link with the installed SDK at `-Os`, and `ulimit -v 2000000` plus a timeout on every compiler run, with at most 3 jobs. The installed toolchain identity equals the opt-levels run's: `clang-23` `254624ba…` and `mos-snes.cfg` `f12c5b6a…` (`runtime/*/identity.json`). [`run-all.sh`](tools/run-all.sh) is the exact driver.

Two input paths:

- **`--lto` (primary, all three).** This is the SDK's real ROM build: `mos-clang -flto -O2` (or `-O3`) with `--save-temps`. Each variant's `llc` compiles the link's own precodegen module with the codegen options that the driver passes to the LTO link, including `-zp-avail=224`. [`final/lto/gate-real-builds.txt`](../final/lto/gate-real-builds.txt) shows that this reproduces the LTO object exactly. The primary path is needed because dither's **non-LTO object does not fit low WRAM**: `.noinit` overflows `ram` by 109 B. The unmodified demo does the same, whereas its LTO build fits.
- **Non-LTO (frozen method, mvscrl and packrec).** This is the opt-levels method unchanged, used as a cross-check.

**Is the LTO model the proposed gate?** A per-level subtarget would turn the sets off only for functions without `optsize`, and keep them in the `-Os` SDK library code. In every `-O2` LTO object, t4 and `memb1` have the same function set. Only demo and snesgfx functions change size (`_title_build`, `_title_emit`, `_title_reserve`, `main`, `build_bands`, `mv_step`, `pk_parse_at`), and no library function does ([`runtime/lto/fn-diff-O2-t4-memb1.txt`](runtime/lto/fn-diff-O2-t4-memb1.txt)). For these programs, `memb1` is therefore what the gate would produce.

Variants: `head` = unchanged `321-16` (`b8006489…`), `t4` = `321-16-t4` (`0f3f63bf…`), `final` = final split #321‑16 (`da1a6f4b…`), and `memb1` = `head-probe -mos-native-pressure-probe=1` (`d0e46c13…`). All hashes were checked against `opt-levels/binaries.sha256` before use. At `-O2`, `final` equals `t4` in every object and clock.

## Results

### Master clocks at `-O2`, sets off (`memb1`) against ungated (`t4` = `final`), LTO ([`runtime/lto/summary.txt`](runtime/lto/summary.txt))

| Mode | Program | whole | loop (steady state) | setup (title, gate, init) | object bytes |
|---|---|---|---|---|---|
| `+mos-a16` | dither | +79,432 (+0.02%) | +40 (0.00%) | +79,352 (+0.19%) | +27 B |
| `+mos-a16` | mvscrl | +41,088 (+0.04%) | −46,928 (−0.09%) | +103,659 (+0.32%) | +13 B |
| `+mos-a16` | packrec | +111,686 (+0.11%) | −24 (0.00%) | +111,718 (+0.20%) | +58 B |
| `+mos-a16` | **total** | **+232,206 (+0.04%)** of 654.3 M | −46,912 (−0.02%) | +294,729 (+0.22%) | +98 B |
| `+mos-a16,+mos-xy16` | dither | +79,820 (+0.02%) | +16 (0.00%) | +79,788 (+0.19%) | +20 B |
| `+mos-a16,+mos-xy16` | mvscrl | +43,672 (+0.04%) | −46,960 (−0.09%) | +106,286 (+0.32%) | +14 B |
| `+mos-a16,+mos-xy16` | packrec | +111,786 (+0.11%) | +280 (0.00%) | +111,413 (+0.19%) | +58 B |
| `+mos-a16,+mos-xy16` | **total** | **+235,278 (+0.03%)** of 688.6 M | −46,664 (−0.02%) | +297,487 (+0.22%) | +92 B |

Positive means `memb1` uses more clocks or bytes. Against unchanged `321-16`, `t4` is +87,546 (+0.01%) and +61,422 (+0.01%), and `memb1` is +319,752 (+0.05%) and +296,700 (+0.04%).

### Cross-check, non-LTO (frozen method), mvscrl + packrec, `-O2` ([`runtime/nolto/summary.txt`](runtime/nolto/summary.txt))

| Mode | whole | loop | setup |
|---|---|---|---|
| `+mos-a16` | +71,196 (+0.04%) | −47,266 (−0.06%) | +134,217 (+0.15%) |
| `+mos-a16,+mos-xy16` | +74,008 (+0.04%) | −45,674 (−0.06%) | +134,907 (+0.15%) |

The sign and size match the LTO path. mvscrl's loop is again −0.09%/−0.10%, and packrec's is flat.

### `-O3` (reference)

Only packrec measures at `-O3`:

- The LTO mvscrl `-O3` link does not fit the 32 KB near ROM bank (`.rodata` overlaps `.snes_header`), and neither does the non-LTO one.
- The dither `-O3` harness writes a wrong fold under every variant, the same value in each (0xA7D4 and 0xCD67 against 0x15CC and 0x21FF). See below.
- On packrec, `final` = `memb1` is +112,138 (+0.14%) against `t4` in `+mos-a16` and +110,580 (+0.13%) in `+mos-a16,+mos-xy16` (LTO). The non-LTO figure is +0.08%.

### Bytes at `-O2`

| Program | Mode | Fixed set (frozen `opt-levels/sizes/O2.*.tsv`): `321-16` / `t4` / `memb1` | Harness LTO object: `t4` → `memb1` |
|---|---|---|---|
| dither | `+mos-a16` | 16,642 / 16,651 / 16,747 (+96) | 18,074 → 18,101 (+27) |
| dither | `+mos-a16,+mos-xy16` | 16,799 / 16,809 / 16,822 (+13) | 18,227 → 18,247 (+20) |
| mvscrl | `+mos-a16` | 16,912 / 16,927 / 16,988 (+61) | 24,226 → 24,239 (+13) |
| mvscrl | `+mos-a16,+mos-xy16` | 16,850 / 16,866 / 16,928 (+62) | 24,186 → 24,200 (+14) |
| packrec | `+mos-a16` | 17,848 / 17,934 / 17,949 (+15) | 20,808 → 20,866 (+58) |
| packrec | `+mos-a16,+mos-xy16` | 17,578 / 17,588 / 17,603 (+15) | 20,539 → 20,597 (+58) |

## Verdict

**The `-O2` gain does not hold on the large programs.**

- With the appended sets off, all three programs use more clocks over the whole measured region in both modes: +0.02% (dither), +0.04% (mvscrl) and +0.11% (packrec). The totals are +0.04% and +0.03%, and the code is larger on every program.
- The loss is in the startup code the demos share: snesgfx `_title_emit`/`_title_build`/`_title_reserve` and the inlined setup in `main`, which grows by 16–54 B.
- The steady-state frame loops gain only on mvscrl (−0.09%, from `build_bands` and `mv_step`). dither's and packrec's loops are flat, and the loop total is −0.02%, an order of magnitude below the 0.2% seen on the small sims.
- Pooled with the 15 sims (`+mos-a16`: −665,982 on 310.7 M), the combined figure is about −0.045% (−433,776 of 965.0 M). That comes almost entirely from nmitally's −416 k.

**Recommendation: do not build the per-level subtarget.** Keep the ungated design at `-O2`, `-Os` and `-Oz`, and the existing `-O3` gate.

## Observed, not acted on

**The dither demo fails at `-O3` with the installed project toolchain.** This is independent of the harness and of these variants ([`o3-dither/report.txt`](o3-dither/report.txt)).

- **Build:** the unmodified `examples/snes/dither.c` (blob `1be807bc` at `origin/main` `b145a581`), built with `mos-clang --config mos-snes.cfg -O3` (LTO), toolchain `clang-23` `254624ba…`.
- **Result:** it never writes its gate CRC 0x80C4 (`got` 0 after 3000 frames), in both default `mosw65816` and `+mos-a16`. The same build at `-O2` passes in both modes.
- **Harness:** the harness `-O3` builds likewise write a wrong fold, the same value under all four llc variants.
- **Status:** no existing defect record or TODO covers it. It is not diagnosed here and is flagged for its own defect dispatch.

The mvscrl `-O3` ROM overflow is a size limit, not a defect.
