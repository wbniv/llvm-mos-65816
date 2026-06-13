# #320 Increment 2 — far-pointer emulator end-to-end (minimal, emulation-mode)

**Date:** 2026-06-14 · **Status:** Complete — all 5 verification steps PASS. A `-mcpu=mosw65816`
program far-loads a ROM constant and far-stores the result to WRAM; it boots in MAME and the
far-stored byte reads back `0xF3` (`SMOKE: PASS`). First Increment-1 codegen executing on emulated
silicon. · **Milestone:** M1 (ROADMAP step 3, execution half).

## Context

Increment 1 landed far-pointer codegen and proved it **at the disassembly level**: a far
(`address_space(2)`) access lowers to 65816 absolute-long (`LDA/STA $xxxxxx`, AF/8F). What it did
**not** do is prove the instruction *executes correctly on silicon*. Increment 2 closes that gap
(ROADMAP step 3): a 65816 program that actually performs a far load and a far store **boots and runs
in MAME**, and the harness reads back the far-written byte.

The TODO framed Increment 2 as "native-mode crt0 (XCE/DBR/reg widths) + multi-bank ROM." Phase-1
research **overturned that premise**:

- **Absolute-long works in plain emulation mode.** It carries the full 24-bit address and ignores the
  data bank register, so far loads/stores execute on the *existing* single-bank, emulation-mode crt0.
  `XCE`/native mode and 16-bit registers are an M2/#321 concern, unrelated to the far-pointer proof.
  (Confirmed: `MOSInstrInfo.h:63-70`, `MOSInstrFormats.td:361-364`; crt0 stays in emulation mode,
  `platforms/snes/crt0.c:14-22`.)
- **The harness already reads results from WRAM bank $7E** (`0x7E0000 + vma`, `dev/_emu.sh:53`), and
  SNES WRAM `$7E0xxx` physically aliases low-RAM `$000xxx` — so a far store at bank $00/$7E lands
  exactly where the harness reads.
- **The SDK + programs build from source each `dev/run.sh build`** (`dev/build.sh:44-65`), so enabling
  far codegen for the test is a per-program `-mcpu=mosw65816` flag, not a toolchain rebuild.

**Scope decision (user-confirmed):** do the *minimal honest* end-to-end proof now (emulation mode,
single 32 KiB bank, existing crt0); re-scope native mode → M2/#321 and split multi-bank ROM into a
separate follow-on (2b). Wire it via a **dedicated `far-run` target**, keeping the 6502 corpus pure.

## Outcome

`dev/run.sh far-run` builds a `-mcpu=mosw65816` program whose result is produced by a **far load** (of
a ROM constant) and written by a **far store** (to WRAM), boots it headless in MAME on the existing
SNES platform, and asserts the far-stored byte via the existing `run_assert` path → **SMOKE: PASS**.
That is the first time Increment-1 codegen runs on emulated silicon.

## Approach

### 1. Test program — `examples/65816/far-run.c` (new)

8-bit accesses only (single-byte far load + single-byte far store — no scalar narrowing, no far
pointer arithmetic, which Increment 1 deferred). Both operands are far **globals**, so they match
Increment-1's `matchAbsoluteAddressing` (constant/global addresses only).

```c
#define FAR __attribute__((address_space(2)))

// far_src is const -> rodata -> ROM bank $00 ($8000-$FFFF); far-loaded as LDA $00xxxx.
// volatile so the load is not constant-folded away.
volatile const FAR unsigned char far_src = 0xA9;

// corpus_result is bss -> low WRAM ($0200-$1FFF, bank $00); far-stored as STA $00020C.
// Bank $00 offset aliases the $7E mirror the harness reads, so no native mode needed.
volatile FAR unsigned char corpus_result;

int main(void) {
  corpus_result = far_src ^ 0x5A;   // far load + far store, both absolute-long. Expect 0xF3.
  for (;;) {}                        // stay alive while MAME settles, then the harness samples.
}
```

Expected: `0xA9 ^ 0x5A = 0xF3`, length 1 (8-bit global → map Size 1 → `run_assert` reads 1 byte).

### 2. Build + run harness — `dev/far-run.sh` (new), dispatched by `dev/run.sh far-run`

Mirror `dev/build.sh:60-62`'s program-compile step but **add `-mcpu=mosw65816`**, then reuse the
existing emulator path verbatim:

```bash
set -euo pipefail
ROOT=/work; BUILD=$ROOT/build; INSTALL=$BUILD/install
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"      # far patch lives only in the from-source build
# Preconditions (clear errors, like dev/far.sh:19): from-source mos-clang + a built SDK (mos-snes.cfg).
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$BUILD/far-run.map" -o "$BUILD/far-run.sfc" "$ROOT/examples/65816/far-run.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/far-run.sfc"

# Disassembly gate (reuse far.sh's intent): confirm the LINKED ROM still has absolute-long far ops.
"$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$BUILD/far-run.sfc" ... | grep -E '\b(af|8f) '   # AF/8F present

# Emulator gate: reuse run_assert + require_bios unchanged.
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$BUILD/far-run.sfc" "$BUILD/far-run.map" corpus_result 0xF3
```

- `dev/run.sh`'s dispatch already runs `dev/<TARGET>.sh` generically; `far-run` → `dev/far-run.sh`
  with no dispatch change. `MOS_TOOLCHAIN` is already forwarded into the container (`dev/run.sh:54`).
- **Reused as-is:** `dev/_emu.sh` (`run_assert`, `require_bios`, WRAM-$7E mapping), `dev/smoke.lua`
  (the periodic WRAM sampler), `tools/snes-checksum.py`, the `mos-snes.cfg` + `platforms/snes`
  install from `dev/build.sh`. No emulator/Lua/crt0 changes.

### 3. Document the target — `dev/run.sh` (modify)

Add `far-run` to the usage line and the targets list (one entry, mirroring the `far` entry added in
Increment 1): "build examples/65816/far-run.c with `-mcpu=mosw65816`, boot in MAME, assert the
far-stored result (needs `toolchain` + `build` first)."

### 4. Re-scope the roadmap — `docs/ROADMAP.md`, `TODO.md` (modify)

The research corrected a premise, so per the "keep docs current in the same turn" rule:

- **ROADMAP step 3 / risks:** state that far pointers run in emulation mode; native-mode crt0
  (`XCE`/DBR/native vectors) and 16-bit registers move to **M2/#321**, not #320.
- **TODO Increment 2:** redefine to this minimal far round-trip; **remove** "native-mode crt0
  (XCE/DBR/reg widths)" from its body.
- **Add a new follow-on item** — "**#320 Increment 2b — multi-bank ROM far-read (emulation mode)**":
  a >32 KiB LoROM placing far rodata in bank $01, proving a far read crosses a real ROM bank boundary
  (header ROM-size byte, LoROM bank mapping, checksum over the larger image) — still no native mode.

### 5. Plan-first artifact — `docs/plans/2026-06-14-320-increment-2-far-emulator-run.md` (new, on execution)

Per the project workflow, the first execution step writes this plan into the repo (this file is its
source) and adds the TODO entry, before any code.

## Critical files

| File | Change |
|------|--------|
| `examples/65816/far-run.c` | **new** — far-load ROM const + far-store to WRAM; `corpus_result` = 0xF3 |
| `dev/far-run.sh` | **new** — compile `-mcpu=mosw65816`, checksum, disasm gate, `run_assert` via `_emu.sh` |
| `dev/run.sh` | document the `far-run` target (dispatch is already generic) |
| `docs/ROADMAP.md`, `TODO.md` | re-scope Increment 2; native mode → M2/#321; add Increment 2b |
| `docs/plans/2026-06-14-320-increment-2-far-emulator-run.md` | **new** — in-repo plan + TODO entry |

**Reused (no change):** `dev/_emu.sh`, `dev/smoke.lua`, `dev/build.sh` (SDK build), `tools/snes-checksum.py`,
`platforms/snes/*`, `patches/llvm-mos/0001-320-far-addrspace.patch` (Increment-1 codegen).

## Risks

- **LTO with mixed subtarget features.** `mos-snes.cfg` sets `-flto`; `far-run.c` is compiled
  `-mcpu=mosw65816` but links against generic-mos libc/crt0. Per-function target-feature attributes
  should keep `W65816` only on `far-run`'s functions (where the far pseudos live), so LTO links
  cleanly. **Fallback if it balks:** add `-fno-lto` for this one program (codegen `far-run.c`
  standalone with `mosw65816`, link the object against libc). Verification step 3 catches this.
- **`R_MOS_ADDR24` bank byte at link time.** The far-global relocations must resolve to a 3-byte
  value with bank `$00` (rodata in $8000-$FFFF; bss in $0200-$1FFF). If the linker mis-sizes the
  reloc, the disasm gate (step 4) and the run (step 3) fail loudly rather than miscompiling.
- **Far store placement of an addrspace-2 bss global.** Increment 1 left addrspace-2 globals in the
  default section (no `.far.*` routing yet), so `corpus_result` lands in low WRAM (bank $00) as
  intended. If a future section-routing change moves it out of the $7E-mirrored low RAM, the harness
  address math breaks — call out in the plan; verify the map VMA is in `$0200-$1FFF`.

## Verification (end-to-end)

Run from the host; each step pastes raw output + PASS/FAIL into the in-repo plan (project rule).
Run 2026-06-14, from-source toolchain (`build/llvm-mos-install`, llvm-mos `c798c31`).

1. **From-source toolchain present** (Increment-1 prerequisite):
   `dev/run.sh toolchain` (skip if `build/llvm-mos-install` exists). Expect `mos-clang --version` OK.

   ```
   $ build/llvm-mos-install/bin/mos-clang --version
   clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git c798c31416f72b395c658b5502d281a162387ab1)
   ```
   **PASS** — `build/llvm-mos-install` present (built in M1 Phase 0 + Increment 1); the SDK install
   (`build/install`, stamp `/work/build/llvm-mos-install`) was built against it, so layouts match.

2. **SDK + 6502 programs still build on the patched toolchain (regression):**
   `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build` → every SNES program builds; then
   `MOS_TOOLCHAIN=… dev/run.sh corpus` → **corpus 7/7** (far work doesn't disturb 6502).

   ```
   ==> built 7 program(s)          (arith/arrays/control/funcs/globals/structs/hello, 32768 bytes each)
   ==> corpus: expected.tsv
     hello      PASS  sentinel=0x42         arith   PASS  corpus_result=0xA9E9
     control    PASS  corpus_result=0x1DFB  arrays  PASS  corpus_result=0x03E1
     structs    PASS  corpus_result=0x0340  funcs   PASS  corpus_result=0x011E
     globals    PASS  corpus_result=0xAB55
   ==> corpus: 7/7 passed
   ```
   **PASS** — SDK + all 7 programs build on the patched from-source toolchain; 6502 corpus 7/7. No
   regression from adding the `far-run` path.

3. **Far program boots and the far store round-trips (the deliverable):**
   `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh far-run` →
   `SMOKE: PASS addr=0x7E0??? len=1 got=0xF3`. This is ROADMAP step 3 — Increment-1 codegen executing
   in MAME.

   ```
   ==> compile+link far-run.c -> far-run.sfc  (--config mos-snes.cfg -mcpu=mosw65816 -Os)
   far-run.sfc: checksum=0x3431 complement=0xCBCE          far-run.sfc  32768 bytes
   ==> execution gate: boot in MAME, assert corpus_result == 0xF3
   SMOKE: PASS addr=0x7E0200 len=1 got=0xF3 (ran 60 ticks)
   RESULT: PASS — far load+store executed in MAME; far-stored byte read back == 0xF3
   ```
   **PASS** — a `-mcpu=mosw65816` program whose result is produced by a far LOAD (of `far_src` in ROM)
   and written by a far STORE (to `corpus_result` at WRAM `$7E0200`) boots and runs correctly in MAME;
   `got=0xF3` = `0xA9 ^ 0x5A`. First Increment-1 codegen executing on emulated silicon. (`corpus_result`
   VMA `$0200` ∈ `$0200-$1FFF` — clears the addrspace-2-bss-placement risk; LTO linked
   `-mcpu=mosw65816` against generic-mos libc with no layout/feature conflict.)

4. **Linked ROM really uses absolute-long (not relaxed 16-bit):** `llvm-objdump -dr` the ROM/object
   shows `af .. .. 00` (far load of `far_src`) and `8f 0c 02 00`-shape (far store to `corpus_result`),
   i.e. opcodes AF/8F, 4-byte, bank byte present. (Reuses the `dev/far.sh` assertion style.)

   ```
   00000000 <main>:
          0: af 00 00 00   lda  $0          00000001:  R_MOS_ADDR24  far_src
          4: 49 5a         eor  #$5a
          6: 8f 00 00 00   sta  $0          00000007:  R_MOS_ADDR24  corpus_result
          a: 80 fe         bra  $a
     PASS: far load  far_src       -> LDA AbsoluteLong (opcode af)
     PASS: far store corpus_result -> STA AbsoluteLong (opcode 8f)
     PASS: far globals carry 24-bit relocations (R_MOS_ADDR24)
   ```
   **PASS** — far accesses are absolute-long (AF/8F, 4-byte) carrying `R_MOS_ADDR24` relocations. Far
   *globals* (relocatable symbols) keep absolute-long even though they link at bank `$00`: the
   assembler can't prove a zero bank for a symbol, so it never zero-bank-relaxes them to 16-bit.

5. **Negative control:** flip the expected byte in `far-run.sh` (e.g. `0xF3`→`0x00`) → `SMOKE: FAIL`,
   proving the PASS reflects the far-stored value, not a coincidental zero/uninitialised read. Revert.

   ```
   $ run_assert build/far-run.sfc build/far-run.map corpus_result 0x00
   SMOKE: FAIL addr=0x7E0200 len=1 got=0xF3 want=0x00          (run_assert rc=1)
   ```
   **PASS** — asserting the wrong value FAILs with `got=0xF3`, proving the harness genuinely samples the
   far-stored byte (ran against the already-built ROM, so `far-run.sh` is left at `WANT=0xF3`).

## Out of scope (later)

- **Increment 2b** — multi-bank ROM far-read (far rodata in bank $01; >32 KiB LoROM). Still emulation
  mode.
- **Native-mode crt0** (`XCE`/DBR/native vectors) and **16-bit registers / REP-SEP** (#321) — **M2**.
- **Runtime far pointers** (near→far casts, far pointer arithmetic / indirect-long `[dp]`) — a later
  #320 increment; Increment 1 deliberately fails these to legalize rather than miscompile.
