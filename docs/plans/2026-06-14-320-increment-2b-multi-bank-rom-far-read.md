# #320 Increment 2b — multi-bank ROM far-read (emulation mode)

**Date:** 2026-06-14 · **Status:** Complete — all 5 verification steps PASS. A far global placed in
ROM **bank $01** ($018000) is far-read via `lda $018000` (`af 00 80 01`) and the cross-bank result
round-trips through MAME (`SMOKE: PASS got=0xF3`); the default `snes` platform stays 32 KiB and the
corpus is still 7/7. · **Milestone:** M1 (ROADMAP step 3, the "≥2 banks" half). **Builds on:**
[Increment 2](2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md) (far load+store
executing in MAME, bank $00).

## Context

Increment 2 proved far-pointer codegen *executes* in MAME — but with the far data in **bank $00**
($00xxxx), the same 64 KiB the 6502 can already reach. That doesn't yet prove the thing far pointers
exist for: reaching data **past the 6502's 64 KiB**, in a higher ROM bank. Increment 2b closes that:
a 64 KiB LoROM with a far global placed in **bank $01** ($018000), far-read via absolute-long
(`lda $018000`, bank byte `01`, un-relaxable), with the result round-tripped through MAME. This is the
"≥2 banks" half of ROADMAP step 3 — the first test that genuinely needs far pointers.

Still **emulation mode** (no XCE/native mode — absolute-long ignores the DBR and carries the bank
byte). Still **no codegen change**: the far access lowers to absolute-long + `R_MOS_ADDR24` purely
from the addrspace; bank-$01 *placement* comes from a section attribute + a linker rule. Confirmed
via exploration of `patches/llvm-mos/0001-320-far-addrspace.patch` (selection is by addrspace, not
section) and `MOSTargetObjectFile.cpp` (no addrspace-2 section routing).

**Scope (user-confirmed):** keep the 64 KiB layout *scoped to this test* — the default `snes`
platform and the 6502 corpus stay 32 KiB and untouched.

## Approach

### Isolation mechanism — a child platform, not `-Wl,-T`

`-Wl,-T` does **not** override the link script: the driver already emits `-Tlink.ld` (confirmed via
`mos-clang -###`), and lld processes multiple `-T` scripts *in sequence* → conflicting `MEMORY`
blocks. The SDK's own idiom for "same runtime, different link script" is a **child platform**
(`platform(name COMPLETE PARENT parent)`; see `nes-nrom`/`atari2600-4k`). A child inherits the
parent's crt0/header/includes via cfg chaining (`mos-platform/derived.cfg` → `@mos-snes.cfg`) and
ships its own `link.ld`, found first on its own `-L` path. `atari2600-4k` (PARENT `atari2600-common`,
installs only `link.ld` + a header, no crt0 of its own) is the proof this works.

### 1. New child platform — `platforms/snes-far/` (2 files)

- `CMakeLists.txt`: `platform(snes-far COMPLETE PARENT snes)` + `install(FILES link.ld TYPE LIB)`.
  No crt0/header/snes.h — all inherited from `snes` (so the bring-up, cartridge header, and `snes.h`
  are byte-identical to the default platform).
- `link.ld`: the 64 KiB variant (below). `dev/build.sh`'s `for p in platforms/*/` loop auto-injects
  it and appends `add_subdirectory(snes-far)`; the SDK generates `mos-snes-far.cfg`.

### 2. 64 KiB LoROM link script — `platforms/snes-far/link.ld`

Mirror `platforms/snes/link.ld` (same `INCLUDE imag-regs.ld/text-sections.ld/rodata.ld/…`, resolved
via `-L` exactly as today), with three additions for bank $01:

```ld
MEMORY {
  zp    : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)
  ram   : ORIGIN = 0x0200,     LENGTH = 0x1E00
  rom   : ORIGIN = 0x8000,     LENGTH = 0x8000      /* bank $00 $8000-$FFFF */
  rom_1 : ORIGIN = 0x018000,   LENGTH = 0x8000      /* bank $01 $8000-$FFFF (far data) */
}
SECTIONS {
  /* …existing .text/.rodata/.data/.bss/header/vectors in `rom` (bank $00)… */
  .far_rodata : { *(.far_rodata .far_rodata.*) } >rom_1   /* VMA $018000 → R_MOS_ADDR24 bank $01 */
}
OUTPUT_FORMAT { FULL(rom) FULL(rom_1) }   /* 64 KiB image: file 0x8000 == CPU $018000 (LoROM) */
```

`FULL(rom) FULL(rom_1)` concatenation is the SDK's multi-bank idiom (`atari2600-3e`, `nes-mmc3` emit
many banks this way). The header/vectors stay in `rom` (bank $00); `rom_1` always emits a full 32 KiB
(padded), so the image is deterministically 64 KiB.

### 3. ROM size + checksum — `tools/snes-checksum.py`

The inherited header has ROM-size byte `0x05` (32 KiB), but this image is 64 KiB. Rather than per-test
hackery, teach the tool (which already patches header bytes post-link) to **own the size byte**:
accept 32 KiB *or* 64 KiB (both power-of-two; the sum-all-bytes checksum is size-agnostic), and write
the ROM-size byte at file `0x7FD7` from the image length (`0x05` for 32 KiB, `0x06` for 64 KiB).
Idempotent for the existing 32 KiB ROMs (writes back `0x05`). This both fixes the inherited header for
bank-$01 and removes a hardcode. (Header stays in bank $00 → checksum offsets `0x7FDC/0x7FDE`
unchanged.)

### 4. Test program — `examples/65816/far-bank1.c` (new)

Like `far-run.c`, but the far source lives in bank $01 via the section attribute:

```c
#define FAR __attribute__((address_space(2)))
volatile const FAR unsigned char far_src
    __attribute__((section(".far_rodata"))) = 0xA9;   // -> rom_1, CPU $018000 (bank $01)
volatile FAR unsigned char corpus_result;             // bank $00 WRAM (read back by harness)
int main(void) { corpus_result = far_src ^ 0x5A; for (;;) {} }   // far LOAD bank $01 -> far STORE. 0xF3
```

The far load becomes `af 00 80 01` (`lda $018000`) — bank byte `01`, **un-relaxable** (a non-zero bank
can never zero-bank-relax). Expect `corpus_result == 0xF3`.

### 5. Harness — `dev/far-bank1.sh` (new) + `dev/run.sh far-bank1` target

Clone `dev/far-bank1.sh` from `dev/far-run.sh`, changing: `--config mos-snes-far.cfg`; assert the
64 KiB size (`stat` == 65536); a stronger disasm gate (far load opcode `af` **and bank byte `01`** in
the *linked* placement — check the `.map` shows `far_src` at `$018xxx`); then `run_assert` via the
unchanged `dev/_emu.sh` + `dev/smoke.lua`. Document the target in `dev/run.sh` (dispatch is generic →
`dev/far-bank1.sh`). Preconditions like `far-run.sh`: from-source toolchain + SDK build present.

## Critical files

| File | Change |
|------|--------|
| `platforms/snes-far/CMakeLists.txt` | **new** — `platform(snes-far COMPLETE PARENT snes)` + install `link.ld` |
| `platforms/snes-far/link.ld` | **new** — 32 KiB snes layout + `rom_1` bank $01 + `.far_rodata` + `FULL(rom) FULL(rom_1)` |
| `tools/snes-checksum.py` | accept 32K/64K; set ROM-size byte (`0x7FD7`) from image length |
| `examples/65816/far-bank1.c` | **new** — far global in `.far_rodata` (bank $01), far-load+store, 0xF3 |
| `dev/far-bank1.sh` | **new** — build `--config mos-snes-far.cfg -mcpu=mosw65816`, 64K/disasm/map gates, `run_assert` |
| `dev/run.sh` | document the `far-bank1` target |
| `TODO.md`, `docs/ROADMAP.md` | promote/annotate on completion (the Increment 2b item already exists) |

**Reused (no change):** `dev/_emu.sh` (`run_assert`, `require_bios`, $7E WRAM mapping), `dev/smoke.lua`,
`dev/build.sh` (platform injection loop), `platforms/snes/*` (inherited via PARENT), the Increment-1
codegen patch. No compiler/codegen change, no toolchain rebuild.

## Risks

- **MAME LoROM bank-$01 mapping (primary — this is what 2b proves).** A 64 KiB LoROM must map file
  `0x8000-0xFFFF` to bank $01 `$018000-$01FFFF`, and `lda $018000` must read it. If MAME instead
  mirrors bank $00 (e.g. keys off the header size byte), the far read returns the wrong byte →
  `SMOKE: FAIL`. Mitigated by setting the header ROM-size byte to `0x06` (step 3); if it still fails,
  investigate MAME's size detection (header byte vs file size vs the `0x20` map-mode). Verified by the
  run, not assumable.
- **Child-platform build / cfg chain.** `snes-far` must build after `snes`, inherit `crt0.o` via the
  chained `@mos-snes.cfg`, and have its own `link.ld` win the `-L` search. Verify the built ROM is
  64 KiB and `far_src` resolves to `$018xxx` in the map (R2).
- **`.far_rodata` placement.** The section attribute must land `far_src` in `rom_1` (bank $01), not the
  default rodata (bank $00). A bank-$00 placement would still pass functionally but wouldn't prove the
  boundary crossing — so the disasm/map gate asserts the **bank byte is `01`**, not just `af`.

## Verification (end-to-end)

Each step pastes raw output + PASS/FAIL into this plan (project rule). Run 2026-06-14, from-source
toolchain (`build/llvm-mos-install`), `snes-far` platform built by `dev/run.sh build`.

1. **Build the 64 KiB ROM:** `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh far-bank1` →
   `far-bank1.sfc` is **65536 bytes**, checksum tool accepts it, header byte `0x7FD7 == 0x06`.

   ```
   far-bank1.sfc: size=64KiB rom_size_byte=0x06 checksum=0x33CE complement=0xCC31
       far-bank1.sfc   65536 bytes
     PASS: 64 KiB (65536 bytes)
   ```
   **PASS** — the `snes-far` child platform links a 64 KiB image; the checksum tool accepts it and set
   the ROM-size byte to `0x06`. (Default `snes` corpus ROMs still build at 32 KiB / `0x05`, idempotent.)

2. **Far global really lands in bank $01:** the `.map` shows `far_src` at a `$018xxx` address; the
   disasm shows `af 00 80 01` (`lda $018000`) — opcode `af` + **bank byte `01`** + `R_MOS_ADDR24`.

   ```
     PASS: far_src @ 0x18000 (bank $01)                 # from the link map
   0: af 00 00 00   lda $0   00000001: R_MOS_ADDR24 far_src   # object: absolute-long + reloc
   8f 00 00 00   sta $0   00000007: R_MOS_ADDR24 corpus_result
   # linked ROM bytes at main ($8036): af 00 80 01  49 5a  8f 00 02 00  80 fe
   #   -> lda $018000 (bank $01!)   eor #$5a   sta $000200   bra
   ```
   **PASS** — `far_src` resolves to `$018000` (bank $01); the *linked* far load is `af 00 80 01`
   (`lda $018000`, bank byte `01`) — a true cross-bank absolute-long, never zero-bank-relaxable.

3. **Bank-$01 far read executes in MAME (the deliverable):** `SMOKE: PASS addr=0x7E0200 len=1
   got=0xF3` — the far load crossed into bank $01, read `0xA9`, and the round-tripped result is correct.

   ```
   ==> execution gate: boot in MAME, assert corpus_result == 0xF3 (the bank-$01 read)
   SMOKE: PASS addr=0x7E0200 len=1 got=0xF3 (ran 60 ticks)
   RESULT: PASS — far read crossed into bank $01 and round-tripped == 0xF3
   ```
   **PASS** — resolves the primary risk: MAME maps bank $01 of a 64 KiB LoROM and `lda $018000` reads
   it. `got=0xF3` = `0xA9 ^ 0x5A`, so the byte came from bank $01 (not a mirror of bank $00).

4. **Negative control:** assert a wrong byte → `SMOKE: FAIL got=0xF3`, proving the harness samples the
   far-stored value.

   ```
   $ run_assert build/far-bank1.sfc build/far-bank1.map corpus_result 0x00
   SMOKE: FAIL addr=0x7E0200 len=1 got=0xF3 want=0x00
   ```
   **PASS** — asserting the wrong value FAILs with `got=0xF3`; the PASS in step 3 reflects the real
   bank-$01 byte.

5. **No regression:** the default `snes` platform is untouched — `MOS_TOOLCHAIN=… dev/run.sh corpus`
   still **7/7**, and `dev/run.sh far-run` (Increment 2, bank $00) still PASS.

   ```
   ==> corpus: 7/7 passed
   far-run.sfc: size=32KiB rom_size_byte=0x05 ...   SMOKE: PASS ... got=0xF3   RESULT: PASS
   ```
   **PASS** — 6502 corpus 7/7 and Increment-2 far-run both green through the changed checksum tool;
   the new platform + 64 KiB layout are fully isolated to `far-bank1`.

## Out of scope (later)

- **Native-mode crt0** (XCE/DBR/native vectors) and **16-bit registers / REP-SEP** — M2/#321.
- **Runtime far pointers** (near→far casts, far pointer arithmetic, indirect-long `[dp]`) — a later
  #320 increment; Increment 1 fails these to legalize rather than miscompile.
- **General multi-bank codegen** (far *code* / `JSL` across banks, automatic bank assignment, far data
  >2 banks) — the broader M1 "working multi-bank compiler" goal; 2b proves the single boundary-crossing
  read that anchors it.
