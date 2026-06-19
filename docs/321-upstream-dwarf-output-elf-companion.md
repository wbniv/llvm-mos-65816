# Upstream doc note — `ld.lld` writes a `<output>.elf` DWARF companion beside a `FULL`/`TRIM` ROM

> **Status: NOT filed.** Draft of the **"docs" half** of the ROADMAP-step-6 *test+docs* contribution to
> upstream llvm-mos. The **"test" half** is the staged lit test
> [`dev/lit/DebugInfo/MOS/dwarf-65816.ll`](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) (drops into
> `llvm/test/DebugInfo/MOS/`). This note documents an **undocumented, surprising-but-correct** lld
> behavior — no behavior change is proposed, only documentation. Posting is **user-triggered**.
> See [DWARF round-trip plan, Step 6](plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md)
> and the queue row in [`upstream-contribution-status.md`](upstream-contribution-status.md).

| | |
|---|---|
| **Project** | [`llvm-mos/llvm-mos`](https://github.com/llvm-mos/llvm-mos) (LLD ELF writer + linker-script extension) |
| **Kind** | documentation of existing behavior — **no functional change** |
| **Component** | `lld/ELF/Writer.cpp` (the `<output>.elf` companion), `lld/ELF/ScriptParser.cpp` (`OUTPUT_FORMAT { FULL/TRIM }`) |
| **Verified against** | current vendor tree (rolling `main`); cited by symbol/quote since line numbers drift |
| **Applies to** | **every** llvm-mos platform whose `link.ld` uses `OUTPUT_FORMAT { FULL/TRIM }` — snes, nes-*, atari8-cart-*, atari2600-*, supervision, dodo, eater, geos-cbm, osi-c1p, … (not 65816-specific) |
| **Fork patch** | **none** — the recommended change is a source comment + an SDK doc sentence (maintainer territory); this file is the rationale + the ready-to-apply snippet |
| **Bundle with** | the step-6 lit test, as a single *test+docs* PR (command at the bottom) |

---

## Title

```
[MOS][docs] Document the <output>.elf DWARF companion emitted for FULL/TRIM OUTPUT_FORMAT links
```

## Summary

When an llvm-mos linker script uses the fork's custom `OUTPUT_FORMAT { FULL(region) … }` /
`TRIM(region)` block to emit a **flat binary image** (a headerless ROM — `.sfc`, `.nes`, `.a26`, …),
`ld.lld` writes **two** files for a single `-o <output>`:

- **`<output>`** — the flat image walked out of the `OUTPUT_FORMAT` commands (what an emulator / a
  flasher loads).
- **`<output>.elf`** — the **complete, unstripped ELF** that the flat image was rendered from, including
  every `.debug_*` section when the program was built `-g`.

The `.elf` companion is **the** artifact a source-level debugger consumes: it carries the DWARF line
table, the subprogram/variable DIEs, and `--verify`-clean debug info, and — because it comes from the
**same** `ld.lld` link as the flat image — its addresses match the running ROM **exactly** (no objcopy,
no separate non-LTO link, no consistency dance). Today this is **undocumented**: nothing in the linker
output, the `--help`, or the platform docs tells an integrator the `.elf` exists or that it is the debug
artifact. A debugger author who only sees the `.sfc` reasonably concludes "llvm-mos discards debug info
for flat-binary targets" — which is wrong, and was a wrong turn we took before finding the companion.

## Mechanism (where it happens)

The companion is emitted **iff** the active linker script carries a custom `OUTPUT_FORMAT { … }` block,
i.e. `ctx.script->outputFormat` is non-empty. Two spots in `lld/ELF/Writer.cpp`:

**1. The normal ELF write is redirected to `<output>.elf`.** In `Writer<ELFT>::writeFile()`:

```cpp
SmallString<64> outputFile = customOutputFile;
if (!ctx.script->outputFormat.empty()) {
  outputFile += ".elf";          // <-- append .elf; the real ELF lands here
  ctx.arg.outputFile = outputFile;
}
// … openFile(); writeHeader(); writeSections(); …  (full ELF, .debug_* included)
```

So the standard, fully-sectioned ELF — with DWARF when `-g` — is written to `<output>.elf`, **not** to
`<output>`.

**2. `<output>` is then (re)written as the flat image.** `Writer<ELFT>::writeCustomOutputFormat()` opens
the original `<output>` path and walks the parsed `OUTPUT_FORMAT` commands — `BYTE`/`SHORT`/`LONG`/`QUAD`
constants and `FULL(region)` / `TRIM(region)` region dumps — emitting allocated `SHT_PROGBITS` by LMA:

```cpp
template <class ELFT> void Writer<ELFT>::writeCustomOutputFormat() {
  if (ctx.script->outputFormat.empty())
    return;
  raw_fd_ostream os(ctx.arg.outputFile, ec);          // <-- the bare <output>
  for (SectionCommand *command : ctx.script->outputFormat) { … }   // FULL/TRIM/BYTE
}
```

`FULL(region)` pads the region to its full `LENGTH`; `TRIM(region)` stops at the last byte actually used.
The commands are parsed in `ScriptParser.cpp` (`readMemoryRegionCommand` → `FULL`=1 / `TRIM`=0;
`ctx.script->outputFormat.push_back(...)`).

## A concrete instance (SNES, `+mos-a16`, `-g`)

`build/install/mos-platform/snes/lib/link.ld` (llvm-mos-sdk) ends with:

```ld
/* Emit the raw 32 KiB ROM image (headerless .sfc). */
OUTPUT_FORMAT {
  FULL(rom)
}
```

So `mos-clang --config mos-snes.cfg -g -Os -o game.sfc game.c` produces:

| File | What it is | Loaded by |
|------|-----------|-----------|
| `game.sfc` | flat 32 KiB headerless ROM (`FULL(rom)` padded) | MAME / bsnes-jg / a flash cart |
| **`game.sfc.elf`** | full `ELF 32-bit … with debug_info, not stripped` (e.MOS) | a source-level debugger (DWARF) |

`llvm-dwarfdump --verify game.sfc.elf` → `No errors.`; the line table maps `game.c` source lines to the
**same** `$8000`-range PCs the ROM runs at. (Multi-region platforms — e.g. `snes-far` with
`FULL(rom) FULL(rom_1)`, or banked NES — get one `.elf` covering all regions, addresses still exact.)

## Recommended change (documentation only — no behavior change)

1. **Source comment** at the `outputFile += ".elf"` site in `lld/ELF/Writer.cpp`, so the next reader of
   the writer learns why a second file appears:

   ```cpp
   if (!ctx.script->outputFormat.empty()) {
     // A custom OUTPUT_FORMAT { FULL/TRIM } script renders a flat binary image to
     // -o <output>; write the complete ELF (with DWARF under -g) to <output>.elf so
     // debug info is not lost. The companion shares this link, so its addresses match
     // the flat image exactly. See writeCustomOutputFormat() for the flat-image pass.
     outputFile += ".elf";
     ctx.arg.outputFile = outputFile;
   }
   ```

2. **One sentence in the platform/linking docs** (llvm-mos-sdk — its own repo/PR) under the flat-binary
   platforms: *"For platforms that emit a flat binary via `OUTPUT_FORMAT { FULL/TRIM }`, `ld.lld` also
   writes `<output>.elf`, the full ELF with DWARF; point your source-level debugger at the `.elf`."*

Neither changes a single output byte; they make a correct-but-hidden behavior discoverable.

## Why this matters (the round-trip)

ROADMAP step 6 closes *compile → optimized SNES ROM → DWARF → source-level debug*. The debugger
(drmon/DAP) loads `game.sfc.elf`, resolves a source breakpoint via the DWARF line table, and stops the
matching PC live in MAME — verified end-to-end (`a16local.c:17 → $8074`). That entire round-trip rests on
the companion `.elf` existing and being found; documenting it is what lets the *next* debugger integrator
find it without rediscovering it by accident.

---

## Posting — bundled *test + docs* PR

The step-6 contribution is one PR carrying the lit test **and** the doc change. The lit test is staged at
`dev/lit/DebugInfo/MOS/dwarf-65816.ll`; drop it at `llvm/test/DebugInfo/MOS/dwarf-65816.ll`, add the
`Writer.cpp` comment above, then:

```sh
# in a clean checkout of wbniv/llvm-mos off upstream main:
#   cp <this-repo>/dev/lit/DebugInfo/MOS/dwarf-65816.ll llvm/test/DebugInfo/MOS/
#   apply the lld/ELF/Writer.cpp comment from "Recommended change" above
#   git add llvm/test/DebugInfo/MOS/dwarf-65816.ll lld/ELF/Writer.cpp && git commit
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-dwarf-65816-test-docs --base main \
  --title "[MOS] DebugInfo/MOS: 65816 DWARF test + document the <output>.elf companion" \
  --body-file docs/321-upstream-dwarf-output-elf-companion.md   # strip this status block first
```

Split instead (if a reviewer prefers): the lit test alone is a pure backend-test PR; the doc comment +
SDK sentence is a separate docs PR (and the SDK sentence is a `llvm-mos-sdk` PR regardless). The lit test
needs no fork-source change; the doc comment is the only `lld/` touch and is comment-only.
