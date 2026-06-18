# DWARF Round-Trip — ROADMAP Step 6 (drmon tie-in)

## Context

ROADMAP step 6 closes the full toolchain loop: **a `-g` build emits correct DWARF that a source-level
debugger loads and uses for line/variable mapping.** Evidence gate: `llvm-dwarfdump --verify` exits 0 and
shows a line table + variable locations; drmon DAP resolves source-line breakpoints in MAME.

Two repos are in scope:
- **drdevtools** (`../drdevtools/`) — debugger side: finish DAP live-MAME verification, add ELF/DWARF loader
- **llvm-mos-65816** (`vendor/llvm-mos/`) — compiler side: audit emission, add regression tests, fix bugs

**This pass front-loads all drmon work and defers compiler-source changes.** The distinction that
makes this possible:

- **Read-only compiler use (do now):** the llvm-mos toolchain is *already built*
  (`build/llvm-mos-install/bin/mos-clang`, `llvm-dwarfdump`). *Running* it to produce a `-g` ELF and
  audit the DWARF is read-only — it edits no source and is **not** a "change here."
- **Compiler-source changes (deferred):** editing `vendor/llvm-mos/` — new `.ll` regression tests, any
  DWARF-emission bug fixes, `0002-*.patch` regeneration. These land *after* the drmon work.

The only hard dependency is *"is the current `-g` output correct?"* — resolved by a **read-only audit
(Step 1)** up front. If it's clean, every drmon step below (including the end-to-end MAME test) can
complete now, and the compiler repo is left with optional test-hardening. If it's broken, the loader is
still authored now; only the fixture/end-to-end test wait on the compiler fix.

---

## Execution order

| # | Step | Repo / nature | Blocks on |
|---|------|---------------|-----------|
| 1 | **Read-only DWARF audit** — run built `mos-clang -g` + `llvm-dwarfdump` | llvm-mos-65816, **read-only** | nothing | ✅ **DONE — CLEAN** |
| 2 | **Phase 0** — DAP live-MAME verification (close the `[wip]`) | drdevtools | nothing | ⏳ next |
| 3 | **Phase B** — drmon DWARF loader + committed ELF fixture + unit tests | drdevtools | Step 1 (fixture trust) | |
| 4 | **Phase C** — drmon end-to-end: breakpoint on real `-g` ROM in MAME | drdevtools | Steps 1, 3 | |
| — | **⏸ PAUSE FOR REVIEW** — stop here; hand back for review before any `vendor/` edits | — | Steps 1–4 done | |
| 5 | **Phase A** — vendor `.ll` regression tests + **debug-ELF emission path** (no emission *fix* needed); patch regen | llvm-mos-65816, **source edits** | review sign-off | |

(The table has a 5th "status" column now.) Steps 1–4 are the "as much drmon as possible" block. **Stop
and hand back for review after Step 4** — do **not** begin Step 5 (the only compiler-source work) until
the drmon work is reviewed and approved. **Step 1 came back clean**, so Step 5 is *not* an emission fix:
it's (a) regression tests for the already-correct DWARF, and (b) the new **debug-ELF emission** deliverable
(the SNES build currently discards the ELF — see Step 1 KEY FINDING).

---

## Current State

### drmon DAP (drdevtools)
- DAP adapter Tiers 1–3 **written**, offline tests PASS (commit 71dbba7); **live-MAME items unrecorded**
- `linux/dap/symbols.cpp` loads `.sld`, COFF, ca65 `.dbg`, WLA-DX `.sym`; **no ELF/DWARF loader**
- `libdwarf` not in Dockerfile or CMake
- `byAddr_`, `byName_`, `srcMap_` are `uint32_t`-keyed — compatible as-is with llvm-mos 32-bit ELF
  (24-bit SNES addresses zero-extended to 32 bits)
- `backend.cpp` speaks the same MAME TCP bridge protocol as `sliomame.cpp`
- Committed binary test assets already exist (`linux/test-roms/*.sfc`) — precedent for a committed fixture

### Compiler (llvm-mos-65816, already in place — no edits yet)
- `SupportsDebugInformation = true`, `CodePointerSize = 4` — `MCTargetDesc/MOSMCAsmInfo.cpp:50,41`
- DWARF reg numbers in `MOSRegisterInfo.td`: A(0), X(2), Y(4), A16(15), B(14), RC0–RC255 (16–526),
  RS0–RS127 (528–782)
- Existing passing tests: `vendor/llvm-mos/llvm/test/DebugInfo/MOS/dwarf-basics.ll`, `dwarf-basics-v5.ll`
- **Gap**: no 65816-specific debug-info tests

---

## Step 1 — Read-only DWARF audit (gate)

Pure read-only use of the already-built toolchain — **no `vendor/` edits.** Establishes whether the
`-g` output is trustworthy enough to be a drmon test fixture, and surfaces the highest risk (missing
`DW_AT_location`) before any drmon code is written against it.

**Check for:**
1. `.debug_info`: compile unit `addr_size = 0x04`; `DW_AT_frame_base (DW_OP_regx 528)` (RS0)
2. `.debug_line`: rows mapping `a16local.c` lines → non-zero SNES addresses
3. `DW_TAG_variable` / `DW_TAG_formal_parameter`: **must** carry `DW_AT_location` — `DW_OP_regx <N>`
   (imaginary-register-resident) or `DW_OP_fbreg <offset>` (soft-stack-spilled)
4. `--verify` clean (exit 0)

### Step 1 — RESULTS (2026-06-18): ✅ CLEAN. No DWARF-emission bug.

**The DWARF is correct and complete.** Audited `examples/65816/a16local.c` (`-g -Os +mos-a16`,
clang 23.0.0git `c798c31`). DWARF v5 (`-dwarf-version=5`, `-debugger-tuning=gdb`, `-gkey-instructions`,
constructor-level info — from the `-###` driver dump).

**Two artifact forms (the `--config` recipe in the original plan was wrong — see finding below):**
- **Object** (`-c -g`, no `--config`/LTO): `build/llvm-mos-install/bin/mos-clang --target=mos
  -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -g -Os -c a16local.c -o a16local.o`
  → real ELF object, DWARF present, **section-relative** addrs (main at 0x00).
- **Linked ELF** (real SNES addrs): see the **debug-ELF finding** below.

`--verify` on both: `No errors.` (exit 0).

`.debug_info` (object) — every check passes, incl. the **high-risk imaginary-register local**:
```
DW_TAG_compile_unit  DW_AT_name("examples/65816/a16local.c")  addr_size = 0x04
  DW_TAG_subprogram   DW_AT_low_pc(0x0) DW_AT_high_pc(0x1d)
                      DW_AT_frame_base (DW_OP_regx RS0)        ← frame base = RS0, as predicted
    DW_TAG_variable   DW_AT_name("t")  DW_AT_decl_line(13)  type "unsigned short" (byte_size 0x02)
      DW_AT_location  ([0x0d, 0x1d): DW_OP_regx RS1)          ← 16-bit local lives in Imag16 pair RS1 ✓
  DW_TAG_variable a16v..corpus_result  DW_AT_location(DW_OP_addrx N)   ← globals, indexed addrs ✓
```
`.debug_line` (object): rows for lines 12,13,14,15,16,17 + `end_sequence`; line 13 `prologue_end`;
addr 0x0d (line 0 marker) = where `t` goes live (matches the loclist range exactly).

**Verdict: Step 5 shrinks to "add regression tests" — no emission fix needed.** Risk 1 (missing
`DW_AT_location`) is **retired**: the imaginary-register local `t` gets a correct `DW_OP_regx RS1`
loclist. (NB: for *value* inspection a debugger must map DWARF reg RS1 → its ZP address; not needed for
the line-breakpoint gate, deferred per B4.)

### Step 1 — KEY FINDING: the SNES build discards the debug ELF 🔑

The original plan's `mos-clang --config mos-snes.cfg -g -o x.elf` does **not** produce a DWARF ELF — it
produces a **raw 32 KiB SNES ROM** (`file` → "Super NES ROM image"). Cause: the SNES linker script
`build/install/mos-platform/snes/lib/link.ld` ends with llvm-mos's custom
```
OUTPUT_FORMAT { FULL(rom) }     /* dumps the `rom` MEMORY region as a flat binary = the .sfc */
```
so `ld.lld` writes the flat ROM and the DWARF (computed during LTO codegen) is never written to disk.
**This is the real gap for ROADMAP step 6: the round-trip needs a debug-ELF emission path.**

**Recovery recipe (proven):** link with the `OUTPUT_FORMAT { … }` block stripped → a normal ELF
executable with real addresses + DWARF:
```bash
awk 'BEGIN{p=1} /^OUTPUT_FORMAT \{/{p=0} p{print}' \
  build/install/mos-platform/snes/lib/link.ld > /tmp/link-elf.ld
build/llvm-mos-install/bin/ld.lld --gc-sections --sort-section=alignment \
  -Lbuild/install/mos-platform/snes/lib -Lbuild/install/mos-platform/common/lib \
  -l:crt0.o a16local.o -lcrt0 -lcrt -lc -T /tmp/link-elf.ld -o a16local-debug.elf
```
Result: `ELF 32-bit LSB executable, *unknown arch 0x1966* (=6502/MOS), with debug_info, not stripped`,
`--verify` clean. **Real SNES addresses** (LoROM bank $00, ROM at $8000):

| Symbol / line | Address |
|---|---|
| `_start` (reset) | `$8000` |
| `main` (`DW_AT_low_pc`/line 12) | `$802f` |
| line 13 `t = a16v + b16v` (`prologue_end`) | **`$8031`** |
| lines 14/15/16 | `$803e` / `$8042` / `$8046` |
| `main` end (`DW_AT_high_pc`) | `$804c` |
| local `t` loclist (linked) | `[$803c,$804c): DW_OP_regx RS1` |

So a source breakpoint on `a16local.c:13` → PC **`$8031`** ($008031 with bank) in MAME — the Phase C
assertion. (Caveat: this used the **non-LTO object**, so the instruction stream differs slightly from
the shipped LTO `.sfc`; internally consistent — DWARF matches its own code — so the round-trip holds.
Faithful-to-ROM debug ELF = emit it from the *same LTO link*, which is the proper fix below.)

**Implications folded into later steps:**
- **B7 fixture** now has a concrete recipe (the stripped-link above); `make-fixture.sh` wraps it.
- **New Step 5 candidate (upstreamable):** give the SNES platform a debug-ELF output — e.g. a
  `mos-snes-debug.cfg` / linker-script variant without `OUTPUT_FORMAT{FULL(rom)}`, or a driver option
  that emits both ROM and `.elf` from one LTO link. This is the *toolchain* deliverable for step 6
  (the DWARF *content* is already correct). Belongs in `docs/upstream-contribution-status.md`.

---

## Step 2 — Phase 0: DAP live-MAME verification (drdevtools)

The DAP adapter (Tiers 1–3) is written and offline-tested; the live-MAME items have never been run or
recorded. Close them before layering the DWARF loader on top.

**Open items** (from `drdevtools/docs/plans/2026-06-12-phase-3-*.md`):

| Step | Plan | What to verify |
|------|------|----------------|
| Tier 1 V3 | phase-3-dap.md | Attach → connected session; no error |
| Tier 1 V4 | phase-3-dap.md | Instruction breakpoint fires; PC lands at the right address |
| Tier 1 V5 | phase-3-dap.md | `variables` (Registers scope) matches MAME's register display |
| Tier 1 V6 | phase-3-dap.md | `readMemory $7E0000` bytes match snesmon's Memory window |
| Tier 2 V4 | phase-3-…-tier-2-disassembly-view.md | VS Code disassembly pane shows correct 65816 mnemonics |
| Tier 3 V6 | phase-3-…-tier-3-symbol-loading.md | Source-level breakpoint fires; VS Code highlights line |

**Approach:**
- V3–V6 (protocol-level, no VS Code): write `linux/dap/test_dap.py` — pipes DAP JSON to a
  `drmon-dap-snes` subprocess and checks responses; launch MAME via the existing `test_bridge.py`
  harness (headless MAME + `drmon-test.sfc`). Reuse its MAME-boot-retry and teardown logic.
- Tier 2 V4 + Tier 3 V6 (VS Code pane views): manual walk-through with a `launch.json` and `--symbols`
  pointed at an `.sld`/COFF for the test ROM.

**ROM:** `linux/test-roms/drmon-test.sfc` (purpose-built NOP-sled + known addresses) for V3–V6.

**Record:** paste raw output into each plan's Verification section (PASS/FAIL); if a step fails, fix it
in the DAP code (regression guard: add the failing case to `test_dap.py`) and re-run. Promote the
`[wip]` Phase 3 TODO item to `[x]` when all pass.

---

## Step 3 — Phase B: drmon DWARF loader (drdevtools)

All drmon-side source. Authored independent of the compiler; unit-tested against a fixture generated by
Step 1's read-only `mos-clang` run.

### B1. Dockerfile — add libdwarf
`linux/Dockerfile`: add `libdwarf-dev libelf-dev` to the apt-get install line. **Verify the package
version** the image pulls (expect 0.11.x) and use the matching API — `dwarf_init_path` / `dwarf_finish`,
not deprecated `dwarf_init`.

### B2. CMakeLists.txt — link libdwarf
`devsys/tools/drmon/CMakeLists.txt`, in `drmon_dap_target`:
```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBDWARF REQUIRED libdwarf)
target_link_libraries(${TARGET} PRIVATE ... ${LIBDWARF_LIBRARIES})
target_include_directories(${TARGET} PRIVATE ${LIBDWARF_INCLUDE_DIRS})
```

### B3. symbols.hpp — declare `loadElf`
Add: `bool loadElf(const char* path);`

### B4. symbols.cpp — implement `loadElf`
~100-line function, libdwarf C API:
```
1. Check ELF magic (\x7fELF); return false immediately if not ELF
2. dwarf_init_path(path, ..., &dbg, &err)
3. Pass 1 — line table: iterate CUs, dwarf_srclines_b per CU,
   addSrc({addr, filename, lineno}) for every non-end-sequence row
4. Pass 2 — symbols: walk DIE tree per CU; DW_TAG_subprogram with
   DW_AT_low_pc → add(low_pc, name); skip location-expression decoding
5. Sort each srcMap_ vector by line number (for nearest-line fallback)
6. dwarf_finish(dbg)
```
`DW_AT_location` decoding (variable values in watch/evaluate) is **deferred** — not needed for the
source-line-breakpoint gate. Future follow-on adds `DW_OP_regx` / `DW_OP_fbreg` decoding.

### B5. addrForSrc — nearest-following-line fallback
After exact-line lookup fails, `lower_bound(line)` in the sorted vector → next mapped line within 5
lines. `-Os` line tables have gaps (blank lines, braces → no row).

### B6. session.cpp — wire into dispatch chain
```cpp
symtab_.loadSld(path) || symtab_.loadCoff(path) ||
symtab_.loadCa65Dbg(path) || symtab_.loadWlaSym(path) ||
symtab_.loadElf(path);
```
ELF magic check lives inside `loadElf`; non-ELF files fall through to `false`. Existing formats unaffected.

### B7. Fixture + test
- **Fixture:** commit `linux/test-roms/a16local-debug.elf` (the linked debug ELF, real $8000 addrs) +
  the `.c` source + a `make-fixture.sh` that regenerates it (consistent with the existing committed
  `*.sfc` assets). `make-fixture.sh` = the **proven Step-1 recovery recipe**: `mos-clang -c -g` (no LTO)
  → object, then `ld.lld -T <link.ld minus the OUTPUT_FORMAT{FULL(rom)} block>` → DWARF ELF. Regenerates
  from `$MOS_CLANG` when present; the committed ELF keeps the test runnable without the llvm-mos tree.
  The unlinked **object** form is also a valid parser fixture (section-relative addrs, DWARF intact).
- **Test:** extend `linux/dap/test_symbols.py` (host) with an ELF case — `loadElf` returns true on the
  fixture; `setBreakpoints a16local.c:13` resolves to **`0x8031`**; `loadElf` returns false on a
  non-ELF file.
- **Build/run wrinkle to resolve:** the binary is built in Docker (against Docker's libdwarf); the
  offline symbol tests run on host. Either run the new ELF test inside the container (preferred) or
  install host libdwarf. Decide during execution; note it in the plan's verification.

---

## Step 4 — Phase C: end-to-end (drdevtools; needs live MAME)

Runnable now (Step 1 was clean) with no `vendor/` edits — but **MAME runs the `.sfc` while drmon loads
the ELF, so their addresses must match.** ⚠️ The Step-1 debug ELF was built **non-LTO**; the normal
`.sfc` is **LTO** → different instruction streams, different addresses. Don't pair them. Two ways to
keep them consistent:
- **(a) Derive the `.sfc` *from* the debug ELF** (do now, no compiler change): objcopy the debug ELF's
  loadable image → flat ROM → `tools/snes-checksum.py` → bootable `.sfc`. MAME runs this; drmon loads
  the same ELF; addresses match by construction. *Verify objcopy reconstructs a valid 32 KiB LoROM.*
- **(b) Emit ROM + debug ELF from one LTO link** (the proper fix — the Step 5 debug-ELF deliverable).
  Faithful to the shipped ROM. Preferred long-term.

```bash
# (a) consistent pair from the SAME non-LTO link:
#   make-fixture.sh → a16local-debug.elf  (DWARF, main@$802f, line13@$8031)
#   llvm-objcopy -O binary a16local-debug.elf a16local.bin && pad/checksum → a16local.sfc
task mame SYS=snes CART=/path/a16local.sfc            # Terminal 1 (drdevtools)
drmon-dap-snes --host 127.0.0.1 --port 41816 \
  --symbols /path/a16local-debug.elf                  # Terminal 2
```
In VS Code / Emacs DAP: breakpoint at `a16local.c:13` (`t = a16v + b16v`). **Assert:** breakpoint
verified with `instructionReference` **`0x8031`**; MAME stops; PC == `$8031` (`$008031` with bank).

A protocol-only slice (verified breakpoint + `instructionReference==0x8031`, no live MAME) goes in
`test_dap.py` for CI; the live-MAME stop-PC match is the manual `[verify]` step.

---

## ⏸ Review checkpoint — before Step 5

**Steps 1–4 (all drmon work) complete here. STOP and hand back for review.** Summarize: Step 1 audit
outcome (clean / which bug), Phase 0 verification results, the loader + fixture + tests, and the Phase C
end-to-end result. **Do not touch `vendor/llvm-mos/` until this is reviewed and approved** — Step 5 is
the only compiler-source work and begins only after sign-off.

---

## Step 5 — Phase A: compiler-source changes (llvm-mos-65816; deferred, gated on review)

The only `vendor/llvm-mos/` edits. **Begin only after the review checkpoint above.** Step 1 came back
clean, so this is **regression tests + the debug-ELF emission path — NOT an emission fix.**

### A1b. Debug-ELF emission path (the real step-6 toolchain deliverable) 🔑
Step 1 found the DWARF *content* correct but the SNES build *discards* it (`OUTPUT_FORMAT{FULL(rom)}`
emits only the flat ROM). Give the platform a way to emit a debug ELF. Options, cheapest first:
- **Linker-script variant** — ship `snes/lib/link-debug.ld` (= `link.ld` minus the `OUTPUT_FORMAT{}`
  block) + a `mos-snes-debug.cfg` that selects it. `mos-clang --config mos-snes-debug.cfg` → DWARF ELF.
  Note this is in **mos-platform** (`build/mos-platform/...`), not the LLVM tree — likely an
  **llvm-mos-sdk** contribution, separate from `0002-*.patch`.
- **Driver/linker option** — emit both ROM and `.elf` from one (LTO) link; faithful to the shipped ROM.
  Bigger change; the right long-term answer. Discuss upstream.
- Until then, `make-fixture.sh` (B7) carries the strip-`OUTPUT_FORMAT` recipe for non-LTO builds.

Record whichever path in `docs/upstream-contribution-status.md`.

### A2. Add `.ll` regression tests — `vendor/llvm-mos/llvm/test/DebugInfo/MOS/`
Pin the **now-verified** shapes: `addr_size 0x04`, `DW_AT_frame_base (DW_OP_regx RS0)`, line table with
`prologue_end` + `end_sequence`, and a 16-bit local with `DW_AT_location (… DW_OP_regx <RSn>)`.
**`dwarf-65816-line-table.ll`**
```
; RUN: llc --filetype=obj -mtriple=mos -mcpu=mosw65816 -o %t < %s
; RUN: llvm-dwarfdump --debug-line %t | FileCheck %s --check-prefix=LINE
; RUN: llvm-dwarfdump --verify %t
; LINE: address_size: 4
; LINE: a16local.c, line {{[0-9]+}}, {{.*}}addr {{0x[0-9a-f]+}}
; LINE: end_sequence
```
**`dwarf-65816-local-var.ll`** — `DW_AT_location` present on a 16-bit local under `+mos-a16`; loose
checks (accept `DW_OP_regx` *or* `DW_OP_fbreg`; RA not pinned); add `--verify`.
**`dwarf-65816-subprogram.ll`** — subprogram `DW_AT_low_pc`/`DW_AT_high_pc` + `DW_AT_frame_base
(DW_OP_regx 0x210)` (RS0). Model on `dwarf-basics.ll`; IR snapshot via `-S -emit-llvm`, pared to
minimal `!DICompileUnit`/`!DISubprogram`/`!DILocalVariable`/`!DILocation`.

### A3. Run tests
```bash
build/llvm-mos/bin/llvm-lit vendor/llvm-mos/llvm/test/DebugInfo/MOS/
```
Baseline `dwarf-basics.ll` still passes; new tests pass.

### A4. Emission fix — ❌ NOT NEEDED (Step 1 clean)
The anticipated bug (missing `DW_AT_location` for imaginary-register locals) **did not occur** —
`t` correctly gets `DW_OP_regx RS1`. No `MOSLegalizerInfo.cpp` / `MOSInsertREPSEP.cpp` change. Kept here
only as the contingency record. (If a *future* shape regresses, the fix would be `setDebugLoc` /
`!dbg`-preservation on new register copies; the generic LLVM DWARF pipeline is otherwise correct.)

### A5. Regenerate patch
After any `vendor/` edit: `dev/regen-patch.sh`. Sanity-check `0002-321-accum16.patch` didn't absorb a
foreign patch's hunks before staging.

---

## Critical Files

| Repo | File | Change |
|------|------|--------|
| drdevtools | `devsys/tools/drmon/linux/dap/test_dap.py` | **new** — Phase 0 live-MAME DAP test (Step 2) |
| drdevtools | `devsys/tools/drmon/docs/plans/2026-06-12-phase-3-*.md` | Record live-MAME verification results |
| drdevtools | `devsys/tools/drmon/linux/Dockerfile` | +libdwarf-dev libelf-dev |
| drdevtools | `devsys/tools/drmon/CMakeLists.txt` | +LIBDWARF pkg_check + link |
| drdevtools | `devsys/tools/drmon/linux/dap/symbols.hpp` | +loadElf declaration |
| drdevtools | `devsys/tools/drmon/linux/dap/symbols.cpp` | +loadElf impl, nearest-line fallback |
| drdevtools | `devsys/tools/drmon/linux/dap/session.cpp` | +loadElf in dispatch chain |
| drdevtools | `devsys/tools/drmon/linux/dap/test_symbols.py` | +ELF test case |
| drdevtools | `devsys/tools/drmon/linux/test-roms/a16local-debug.{elf,c}` + `make-fixture.sh` | **new** — committed fixture (strip-`OUTPUT_FORMAT` recipe) |
| llvm-mos-65816 | `vendor/llvm-mos/llvm/test/DebugInfo/MOS/dwarf-65816-*.ll` | **new** tests (Step 5/A2) |
| llvm-mos-sdk *(or mos-platform)* | `snes/lib/link-debug.ld` + `mos-snes-debug.cfg` | **new** — debug-ELF emission (Step 5/A1b) 🔑 |
| llvm-mos-65816 | ~~`MOS{LegalizerInfo,InsertREPSEP}.cpp`~~ | ~~emission fix~~ **not needed** (Step 1 clean) |
| llvm-mos-65816 | `patches/llvm-mos/0002-321-accum16.patch` | Regenerate only if a vendor `.cpp`/`.td` changes |

---

## Risks

1. ~~**`DW_AT_location` absent** (high)~~ — **RETIRED by Step 1.** The imaginary-register local `t` gets
   a correct `DW_OP_regx RS1` loclist; `--verify` clean. No emission fix needed.
2. **Debug-ELF/ROM address mismatch** (high — *new, from Step 1*) — the only way to get DWARF is a
   non-`OUTPUT_FORMAT` link; that fixture is **non-LTO** and its addresses differ from the LTO `.sfc`.
   Phase C **must** pair the debug ELF with a ROM derived from the *same* link (objcopy the ELF → `.sfc`),
   or emit both from one LTO link (Step 5 / A1b). Pairing mismatched LTO-ROM + non-LTO-ELF → breakpoints
   land at the wrong PC.
3. **libdwarf API/version** (medium) — confirm the Dockerfile pulls 0.11.x and use `dwarf_init_path`.
4. **Docker-built binary vs host-run tests** (medium) — the ELF unit test may need to run inside the
   container, or host libdwarf installed. Resolve in B7.
5. **Line-table gaps under `-Os`** (medium) — nearest-line fallback (B5) mitigates for breakpoints;
   documented limitation for optimized builds.
6. **objcopy → bootable `.sfc`** (low) — Phase C path (a) assumes `llvm-objcopy -O binary` + checksum
   reconstructs a valid 32 KiB LoROM from the debug ELF; verify before relying on it.
