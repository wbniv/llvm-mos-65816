# dev/lit — staged upstream lit tests (tracked)

LLVM `lit` regression tests authored against the **from-source toolchain**, staged here
rather than in `vendor/llvm-mos/llvm/test/` because **`dev/regen-patch.sh` mirrors only
`llvm/lib/Target/MOS`** into the tracked `0002` patch — a file under `llvm/test/` would be
lost on a clean vendor rebuild. Keeping them here makes them durable and version-controlled.

## What's here

- `DebugInfo/MOS/dwarf-65816.ll` — ROADMAP step 6 / #321: llvm-mos emits correct 65816 DWARF
  under `+mos-a16` (4-byte address size, `DW_AT_frame_base = DW_OP_regx RS0`, 16-bit params/
  locals located in imaginary-register pairs `DW_OP_regx RSn`, line table, `--verify` clean).

## Running them

Full `llvm-lit` needs the `count` / `not` support tools, which the container-configured
`build/llvm-mos` tree doesn't build (and can't be built host-side — the ninja tree has
`/work` paths). Verify a test by running its `RUN:` pipeline by hand — `llc`, `FileCheck`,
and `llvm-dwarfdump` **are** present:

```sh
T=dev/lit/DebugInfo/MOS/dwarf-65816.ll
build/llvm-mos/bin/llc --filetype=obj -mtriple=mos -mcpu=mosw65816 -o /tmp/lit.o "$T"
build/llvm-mos-install/bin/llvm-dwarfdump --debug-info /tmp/lit.o | build/llvm-mos/bin/FileCheck "$T"
build/llvm-mos-install/bin/llvm-dwarfdump --debug-line /tmp/lit.o | build/llvm-mos/bin/FileCheck "$T" --check-prefix=LINE
build/llvm-mos-install/bin/llvm-dwarfdump --verify /tmp/lit.o
```

The **durable in-repo regression** is `dev/run.sh dwarf` (end-to-end: real `--config -g`
build, asserts the DWARF shapes *and* the `<output>.elf` companion). These lit tests are the
**upstream-PR form** — drop into `llvm/test/DebugInfo/MOS/` for an llvm-mos contribution
(see `docs/upstream-contribution-status.md`).
