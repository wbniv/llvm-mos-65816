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
| 2 | **Phase 0** — DAP live-MAME verification (close the `[wip]`) | drdevtools | nothing | ✅ **DONE — V3–V6 PASS** |
| 3 | **Phase B** — drmon DWARF loader + committed ELF fixture + unit tests | drdevtools | Step 1 (fixture trust) | ✅ **DONE — loadElf, 3 ELF tests PASS** |
| 4 | **Phase C** — drmon end-to-end: breakpoint on real `-g` ROM in MAME | drdevtools | Steps 1, 3 | ✅ **DONE — 6/6, 3 runs** |
| — | **⏸ PAUSE FOR REVIEW** — stop here; hand back for review before any `vendor/` edits | — | Steps 1–4 done | **◀ HERE** |
| 5 | **Phase A** — DWARF regression tests (`dev/run.sh dwarf` + staged lit) | llvm-mos-65816 | review sign-off | ✅ **DONE — gate 7/7, lit verified** |
| 6 | **`<output>.elf` doc note** — draft the undocumented-companion upstream note | llvm-mos-65816, **docs-only** | Step 5 | ✅ **DONE 2026-06-19 — drafted + both gates re-verified** |

(The table has a 5th "status" column now.) Steps 1–4 are the "as much drmon as possible" block. **Stop
and hand back for review after Step 4** — do **not** begin Step 5 (the only compiler-source work) until
the drmon work is reviewed and approved. **Step 1 came back clean** (DWARF content correct *and* the
build already emits a `<rom>.elf` DWARF companion — see Step 1 KEY FINDING), so Step 5 is **not** an
emission fix and **not** a debug-ELF emission feature (both already work): it's just `.ll` regression
tests pinning the verified shapes. Optionally, a doc note upstream that `<output>.elf` is the debugger
artifact.

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

**Where the DWARF lives:** a normal `mos-clang --config mos-snes.cfg -g -o a16local.sfc` build emits the
ROM **and** a `a16local.sfc.elf` DWARF companion (see the KEY FINDING below — `ld.lld` auto-writes
`<output>.elf`). A bare `-c -g` object also carries DWARF (section-relative addrs) and is handy for
inspection. `--verify` on both: `No errors.` (exit 0).

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

### Step 1 — KEY FINDING (CORRECTED): the SNES build already emits a DWARF companion ELF 🔑

⚠️ **An earlier draft of this finding claimed the SNES build "discards the debug ELF." That was WRONG —
I named my probe output `a16local.elf` and never looked for the `<output>.elf` companion.** Corrected by
measurement (drdevtools `2344483`):

A normal `-g` build **does** emit a DWARF ELF. `mos-clang --config mos-snes.cfg -g -o a16local.sfc`
writes **two** files:
- `a16local.sfc` — the flat 32 KiB ROM (from `OUTPUT_FORMAT { FULL(rom) }` in `snes/lib/link.ld`)
- **`a16local.sfc.elf`** — a full `ELF 32-bit … with debug_info, not stripped` (arch `0x1966` = 6502/MOS)

llvm-mos's `ld.lld`, when the linker script uses the custom `OUTPUT_FORMAT { FULL(...) }`, writes the
binary to `-o` **and** an ELF companion to `<output>.elf`. So **there is no debug-ELF gap** — the
round-trip's debug artifact is produced by the stock build, automatically. The companion is byte-for-byte
the LTO build that ships, so its addresses match the ROM exactly (no consistency dance needed).

Verified companion DWARF (LTO build, `--verify` clean):

| Symbol / line | Address |
|---|---|
| `_start` (reset) | `$8000` |
| `main` (`DW_AT_low_pc`) | `$8059` |
| line 13 `t = a16v + b16v` (`prologue_end`) | **`$805b`** |
| line 17 `for (;;) {}` | **`$8074`** |
| local `t` | `loclist … DW_OP_regx RS1` (16-bit local in Imag16 pair) |

So a source breakpoint on `a16local.c:17` → PC `$8074` in MAME — the Phase C assertion (line 17, the
infinite loop, re-executes forever so the live breakpoint is deterministic; line 13 is one-shot).

**Implications folded into later steps:**
- **B7 fixture** = the auto-emitted `a16local.sfc.elf` companion (drmon loads it; MAME runs `a16local.sfc`).
  `make-fixture.sh` is just the normal `--config -g` build. No stripped-link hack.
- **Step 5 debug-ELF deliverable is WITHDRAWN** — it already exists in the stock toolchain. Step 5 is now
  only `.ll` regression tests (hygiene). The single remaining upstream-worthy note: *document* that
  `<output>.elf` is the debugger artifact (it's undocumented behavior a debugger integrator must know).

---

## Step 2 — Phase 0: DAP live-MAME verification (drdevtools) — ✅ DONE (2026-06-18)

**Result: V3–V6 automated + PASS, 3/3 runs 11/11.** New harness `task test-dap` (`linux/test_dap.sh`
+ `linux/dap/test_dap.py`); committed in drdevtools `1a5c05f`. Headless MAME + SNES Lua bridge on the
host; `drmon-dap-snes` driven over DAP stdio in the build container (`--network=host`); every read
cross-checked against a direct bridge connection.

**VS Code GUI confirmation — ✅ DONE (2026-06-19, drdevtools `545723a`).** Tier 3 V6 confirmed **live**:
the `vscode-drmon` extension loads (via `--extensionDevelopmentPath`), attaches, and a source breakpoint
on `a16local.c:17` **fires** → CPU **halts** at PC=`$8074` → VS Code **highlights line 17** (CALL STACK
mapped to `a16local.c:17`, `A=0x1122`). Screenshots + detail in drdevtools
`docs/plans/2026-06-12-phase-3-drmon-dap-tier-3-symbol-loading.md` (v6). The GUI exercise found + fixed
**two adapter bugs** — (#5) `configurationDone` now issues the bridge "go" (attach never sends a continue,
so nothing fired/paused); (#6) `stackTrace` now reverse-maps PC → source line — both regression-tested by
`phasec` (8/8). (Tier 2 V4 disassembly *pane* = a GUI view of an already-verified `disassemble` request.)

**Three hard-won harness lessons (apply to any headless MAME+bridge automation, incl. Phase C):**
1. **`-skip_gameinfo` is required headless** — without it MAME stalls on the disclaimer screen, emulated
   time never advances, and the autoboot Lua bridge never binds its socket (port stays closed).
2. **Run throttled (no `-nothrottle`)** — `-nothrottle` pegs a core and starves the bridge's per-frame
   socket accept/handshake, so the adapter's attach-time `connect()` hangs. Throttled 60fps = reliable.
3. **DAP requests must always carry `arguments`** — cppdap silently drops `attach`/`configurationDone`
   (no response) if the field is absent; the test client now always sends `"arguments": {}`.

Also: the Tier-1 Lua bridge (`-debugger none`) **pseudo-holds a NOP or two past** the breakpoint (stop
is marker-detected on the next periodic tick); the Tier-2 C++ gdbstub freezes exactly. drmon faithfully
reports MAME's PC (cross-check confirms), so this is a bridge property, not a DAP bug. Phase C's
breakpoint assertion must allow "at or just past" the line address accordingly.

<details><summary>Original open items (now closed except GUI panes)</summary>

The DAP adapter (Tiers 1–3) was written and offline-tested; the live-MAME items had never been run.

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
in the DAP code (regression guard: add the failing case to `test_dap.py`) and re-run.

</details>

---

## Step 3 — Phase B: drmon DWARF loader (drdevtools) — ✅ DONE (2026-06-18, `9b378ba`)

**Result: `SymbolTable::loadElf` (libdwarf) lands; 3 new ELF tests in `test_symbols.py` PASS**, existing
COFF/.sld/ca65/WLA + junk-fallthrough still pass. Against the committed fixture `a16local-debug.elf`:
`a16local.c:13 → 0x8031` (line table), `evaluate main → 0x802f` (subprogram DIE), and the nearest-line
fallback resolves line 12 into ROM. Implementation matched the plan below (B1–B7) with two deviations
worth noting:
- **libdwarf header path quirk** — Ubuntu 26.04's `libdwarf-dev` pkg-config advertises
  `-I/usr/include/libdwarf-1` but that dir is *empty*; headers are in `/usr/include/libdwarf/`. So the
  code includes `<libdwarf/libdwarf.h>` / `<libdwarf/dwarf.h>` (resolved via default `/usr/include`),
  not `<libdwarf.h>`. (`pkg_check_modules` still supplies `-ldwarf` for linking.)
- **fixture is the auto-emitted DWARF companion** `a16local.sfc.elf` (committed with `a16local.c` +
  the `a16local.sfc` ROM; `make-fixture.sh` is just a normal `--config -g` build). *(Initially built via
  a non-LTO stripped-`OUTPUT_FORMAT` link before discovering the `<rom>.elf` companion — corrected in
  drdevtools `2344483`; see Step 1 KEY FINDING.)*

Plan as executed:

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

## Step 4 — Phase C: end-to-end (drdevtools; live MAME) — ✅ DONE (2026-06-18, `bdf0af0`)

**Result: the full DWARF round-trip works — 6/6, 3 consecutive runs (`bash linux/test_dap.sh phasec`).**
drmon loads `a16local.sfc.elf` (the auto-emitted DWARF companion), `setBreakpoints a16local.c:17`
resolves via the DWARF line table to **`$8074`** (the `for(;;)` loop), the breakpoint **fires live in
MAME** running `a16local.sfc`, PC lands at/just past `$8074`, and a direct bridge `G` read confirms the
same PC. ROADMAP step 6's debugger half is demonstrated end-to-end on fully-open tooling.

**Address consistency is free:** the ROM (`a16local.sfc`) and the DWARF companion (`a16local.sfc.elf`)
come from the **same** `ld.lld` link, so their addresses are identical by construction — no objcopy, no
LTO/non-LTO pairing. *(An initial attempt linked a non-LTO object twice with a stripped `OUTPUT_FORMAT`;
the companion makes that unnecessary — corrected in drdevtools `2344483`/`bdf0af0`→final.)* Breakpoint
target is **line 17** (the infinite loop), not line 13 — line 13 is one-shot (runs once before the loop),
so by attach time the CPU has passed it; line 17 re-executes forever, making the live breakpoint
deterministic.

<details><summary>Original Phase C design notes (superseded by the above)</summary>

⚠️ The Step-1 debug ELF was built **non-LTO**; the normal `.sfc` is **LTO** → different addresses. Two
ways to keep them consistent:
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

</details>

---

## ⏸ Review checkpoint — before Step 5

**Steps 1–4 (all drmon work) complete here. STOP and hand back for review.** Summarize: Step 1 audit
outcome (clean / which bug), Phase 0 verification results, the loader + fixture + tests, and the Phase C
end-to-end result. **Do not touch `vendor/llvm-mos/` until this is reviewed and approved** — Step 5 is
the only compiler-source work and begins only after sign-off.

---

## Step 5 — Phase A: compiler-source changes (llvm-mos-65816; deferred, gated on review)

**✅ DONE (2026-06-19) — and it needed NO `vendor/` edits after all.** Step 1 came back clean and the
toolchain already emits the `<rom>.elf` companion, so Step 5 is purely regression hygiene. The plan
assumed vendor `.ll` lit tests, but two facts redirected the form (justified deviation — measure / fix
forward):
- **`dev/regen-patch.sh` mirrors only `llvm/lib/Target/MOS`** → a file under `llvm/test/` is lost on a
  clean vendor rebuild (not patch-durable). The project already classes lit tests as an upstreaming concern.
- **Full `llvm-lit` can't run here** — the container-configured `build/llvm-mos` tree lacks `count`/`not`
  and can't be rebuilt host-side (`/work` paths).

Delivered instead:
- **`dev/dwarf.sh` + `dev/run.sh dwarf`** — the durable, tracked, in-repo regression. Runs the real
  `--config -g` build and asserts SHAPES (not addresses): the `<output>.elf` companion is emitted +
  has `.debug_info`, `--verify` clean, `addr_size 0x04`, `frame_base DW_OP_regx RS0`, the 16-bit local
  has a `DW_OP_regx RSn` location, subprogram low/high_pc, line table + `end_sequence`. **Gate 7/7 PASS.**
- **`dev/lit/DebugInfo/MOS/dwarf-65816.ll`** (+ `dev/lit/README.md`) — the upstream-PR lit form, staged in
  a *tracked* dir, **verified via the manual `llc | llvm-dwarfdump | FileCheck` pipeline** (all RUN lines
  pass). Queued in `docs/upstream-contribution-status.md` (with the `<output>.elf` doc note).

No `vendor/llvm-mos/` source changed ⇒ **no `0002` patch regen needed.** The A2/A3/A4/A5 sub-steps below
are the superseded original plan, kept for the record.

### A1b. Debug-ELF emission path — ❌ WITHDRAWN (already exists)
An earlier draft proposed adding a debug-ELF output to the SNES platform. **Unnecessary:** `ld.lld`
already writes `<output>.elf` (full DWARF) beside the ROM on every `-g` build (Step 1 KEY FINDING). The
only residual upstream-worthy item is a **doc note** that `<output>.elf` is the debugger artifact — it is
undocumented today, so a debugger integrator wouldn't know to look for it. Record that (not a feature) in
`docs/upstream-contribution-status.md` if pursued.

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

## Step 6 — `<output>.elf` doc note (llvm-mos-65816; docs-only) — ✅ DONE (2026-06-19)

The last residual flagged by Step 5/A1b ("the single remaining upstream-worthy note: *document* that
`<output>.elf` is the debugger artifact") existed only as a *description* — the lit-test ("test") half of
the step-6 contribution was drafted, but the doc-note ("docs") half had no concrete artifact. Drafted it:

- **[`docs/321-upstream-dwarf-output-elf-companion.md`](../321-upstream-dwarf-output-elf-companion.md)** —
  upstream doc note in the house artifact format (status block, metadata table, title, summary,
  source-quoted mechanism, the SNES instance, the recommended documentation-only change, and the bundled
  *test+docs* `gh pr create`). Cites the exact emission points — `lld/ELF/Writer.cpp` `writeFile()`
  (`outputFile += ".elf"` when `ctx.script->outputFormat` is non-empty) and `writeCustomOutputFormat()`
  (the flat-image pass) — and frames the behavior as **general to every `OUTPUT_FORMAT { FULL/TRIM }`
  platform** (nes-*, atari8-cart-*, supervision, …), not 65816-specific.
- **No upstream *behavior* change** — `<output>.elf` already works; the note proposes only a `Writer.cpp`
  source comment + an SDK doc sentence (both maintainer territory). **No `vendor/` edit here** (the note is
  the rationale + ready-to-apply snippet); nothing to regen in `0002`.
- **`docs/upstream-contribution-status.md`** updated: the DWARF item moves from *Future/blocked* to
  *Ready to post now* (both halves drafted) with the bundled test+docs PR command; **TODO.md** DWARF
  bullet's "Left:" line updated.

### Step 6 — Verification (re-ran both step-5 gates on the current tree; 2026-06-19)

**V1. Staged lit test — all four `RUN:` lines pass** (manual `llc | llvm-dwarfdump | FileCheck`, since
full `llvm-lit` lacks `count`/`not` here):
```
$ T=dev/lit/DebugInfo/MOS/dwarf-65816.ll
$ build/llvm-mos/bin/llc --filetype=obj -mtriple=mos -mcpu=mosw65816 -o /tmp/lit.o "$T"          # OK
$ build/llvm-mos-install/bin/llvm-dwarfdump --debug-info /tmp/lit.o | build/llvm-mos/bin/FileCheck "$T"                       # CHECK PASS
$ build/llvm-mos-install/bin/llvm-dwarfdump --debug-line /tmp/lit.o | build/llvm-mos/bin/FileCheck "$T" --check-prefix=LINE   # LINE PASS
$ build/llvm-mos-install/bin/llvm-dwarfdump --verify    /tmp/lit.o
… Verifying .debug_line... Verifying .debug_str_offsets...
No errors.
```
**PASS** — CHECK + LINE + `--verify` clean.

**V2. `dev/run.sh dwarf` — end-to-end gate 7/7** (real `--config -g` build, companion ELF asserted):
```
==> 1. ld.lld emitted the DWARF companion <output>.elf   PASS: companion dwarf-a16local.sfc.elf exists and has .debug_info
==> 2. llvm-dwarfdump --verify is clean                  PASS: --verify: No errors
==> 3. compile unit addr_size = 0x04                     PASS: addr_size = 0x04
==> 4. main DW_AT_frame_base = DW_OP_regx RS0            PASS: frame_base = DW_OP_regx RS0
==> 5. 16-bit local 't' has a DW_OP_regx location        PASS: local 't' has DW_AT_location with DW_OP_regx RSn
==> 6. DW_TAG_subprogram main has low_pc + high_pc       PASS: subprogram has low_pc + high_pc
==> 7. .debug_line maps a16local.c with end_sequence     PASS: line table has 8 rows + end_sequence
RESULT: PASS — -g DWARF is correct + the <output>.elf debug companion is emitted
```
**PASS** — 7/7, the companion `.elf` (the doc note's subject) is emitted and `--verify`-clean.

ROADMAP step 6 is now **complete on the compiler side**: implementation + the durable in-repo guard
(`dev/run.sh dwarf`) + both upstream-PR halves (lit test + doc note) drafted and re-verified. Only
user-triggered upstream *posting* remains.

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
| drdevtools | `devsys/tools/drmon/linux/test-roms/{a16local.c,a16local.sfc,a16local.sfc.elf}` + `make-fixture.sh` | **new** — committed fixtures (ROM + auto-emitted DWARF companion) |
| llvm-mos-65816 | `dev/lit/DebugInfo/MOS/dwarf-65816.ll` (+ `dev/lit/README.md`) | **new** staged lit test (Step 5; the `vendor/llvm-mos/llvm/test/` form is the drop-in target) |
| llvm-mos-65816 | `docs/321-upstream-dwarf-output-elf-companion.md` | **new** `<output>.elf` doc note (Step 6) — the *docs* half of the test+docs PR |
| ~~llvm-mos-sdk~~ | ~~`snes/lib/link-debug.ld` + `mos-snes-debug.cfg`~~ | ~~debug-ELF emission~~ **withdrawn** — `<rom>.elf` companion already exists |
| llvm-mos-65816 | ~~`MOS{LegalizerInfo,InsertREPSEP}.cpp`~~ | ~~emission fix~~ **not needed** (Step 1 clean) |
| llvm-mos-65816 | `patches/llvm-mos/0002-321-accum16.patch` | Regenerate only if a vendor `.cpp`/`.td` changes |

---

## Risks

1. ~~**`DW_AT_location` absent** (high)~~ — **RETIRED by Step 1.** The imaginary-register local `t` gets
   a correct `DW_OP_regx RS1` loclist; `--verify` clean. No emission fix needed.
2. ~~**Debug-ELF/ROM address mismatch** (high)~~ — **RETIRED.** Premised on the (wrong) belief that the
   debug ELF had to be a separate non-LTO link. The `<rom>.elf` companion is emitted from the *same*
   link as the ROM, so addresses match by construction; no objcopy and no LTO/non-LTO pairing risk.
3. ~~**libdwarf API/version** (medium)~~ — **RESOLVED.** Ubuntu 26.04 ships `0.11.1`; used
   `dwarf_init_path`/`dwarf_finish`. (Quirk: headers are in `/usr/include/libdwarf/`, not the empty
   pkg-config dir — `#include <libdwarf/libdwarf.h>`.)
4. ~~**Docker-built binary vs host-run tests** (medium)~~ — **RESOLVED.** ELF test runs inside the
   container (`task test-symbols` / `test_dap.sh` already containerized); no host libdwarf needed.
5. **Line-table gaps under `-Os`** (medium, residual) — nearest-line fallback (B5) mitigates for
   breakpoints; documented limitation for optimized builds. Exercised by the ELF nearest-line test.
