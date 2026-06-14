# #321 — native-mode crt0 (the SNES platform enters 65816 native mode)

## Context

#321 Increment 1a ([plan](2026-06-14-321-increment-1-16bit-accumulator.md), commit `a7ce88a`) landed
the first real 16-bit-accumulator codegen: a 16-bit store-of-zero fuses to `rep #$20; stz; sep #$20`
via the `MOSInsertREPSEP` pass. But 16-bit accumulator mode **only takes effect in 65816 native mode**
(`E=0`) — the SNES powers on in 6502-emulation mode, where the M/X width bits are forced to 8 and
`REP #$20` is a no-op. 1a worked around this with a **test-local `clc; xce`** inside `a16.c`'s `main()`
(safe only because that program masks interrupts and never returns). That hack is exactly what this
phase removes.

**This phase:** the `snes` platform crt0 enters native mode during bring-up, with M/X defaulting to
8-bit, so **every** program runs native. The existing 8-bit codegen (corpus, far pointers) must stay
byte-for-byte correct in native 8-bit mode, and `a16.c` drops its inline `clc; xce` (the crt0 now owns
the mode). This is the platform foundation that lets *all* future 16-bit codegen run on the emulators
without per-test mode entry — the enabling prerequisite for Increment 1b (dual-width accumulator
register) and the eventual M2 native platform.

## Why native mode is safe for the existing 8-bit codegen

The 65816 in native mode with M=1/X=1 executes 8-bit accumulator/index ops **identically** to emulation
mode. The differences that matter here, and why each is already handled:

| Concern | Emulation mode | Native mode | Status |
|---|---|---|---|
| Hardware stack | page 1 ($01xx), wraps in-page | full 16-bit SP, no page-1 wrap | crt0 sets `SP=$01FF`; soft-stack ABI keeps the C stack off the hardware stack, so JSR/RTS stay in page 1 |
| `ldx #$ff; txs` | SP←$01FF | with 8-bit X, SP←**$00FF** (high byte 0) | crt0 loads SP via a transient 16-bit `ldx #$01ff` |
| Interrupt vectors | `$FFF0-$FFFF` | `$FFE0-$FFEF` | both already populated in `link.ld` (native points at the `irq`/`nmi` stubs); `sei` + `NMITIMEN=0` means none fire |
| Interrupt stack frame | pushes P,PCH,PCL | also pushes PB (one extra byte) | irrelevant — interrupts are masked |
| Data bank (DBR) | n/a (bank follows PC) | absolute data uses DBR | DBR=0 at reset; all near data is bank $00 (WRAM/MMIO) — unchanged |
| Program bank (PB) | n/a | code fetches use PB | PB=0 at reset; ROM/code is bank $00 (32 KiB) or bank $00 code + bank $01 *data* (snes-far) |
| Far load/store (`af`/`8f`) | absolute-long, bank in operand | same — DBR/PB-independent | already mode-independent (proven in #320 Inc 2/2b) |

So native 8-bit mode is a strict superset for the current codegen, provided the crt0 (a) sets a page-1
hardware stack with a 16-bit load and (b) leaves M=1/X=1. The risk is residual (a missed mode subtlety),
and the guard is the full green-tree re-run **in native mode** (corpus + far + xcheck + a16).

## Approach

### 1. crt0 native-mode entry (`platforms/snes/crt0.c`, `.init.50`)

Replace the emulation-mode stack setup with native-mode entry. New `.init.50`:

```asm
sei                 ; mask IRQ
cld                 ; binary mode
clc
xce                 ; E=0 -> 65816 native mode (M=1,X=1 retained from reset)
rep #$10            ; 16-bit index regs so txs takes a full 16-bit value
ldx #$01ff
txs                 ; hardware stack pointer -> $01FF (page 1)
sep #$30            ; M=1, X=1: 8-bit accumulator + index (the codegen default)
lda #$00
sta $4200           ; NMITIMEN: no NMI/IRQ/auto-joypad
lda #$8f
sta $2100           ; INIDISP: force blank
```

`rep #$10` / `ldx #$01ff` / `txs` loads a 16-bit stack pointer (an 8-bit `txs` would set `SP=$00FF`,
colliding with the direct page). `sep #$30` then pins **both** width bits to 8 — the explicit "we are
8-bit now" contract the rest of the codegen depends on, robust regardless of the M/X values XCE leaves.
The `rep`/`sep` immediates (`c2`/`e2`) are the same MC instructions the `MOSInsertREPSEP` pass emits.

**Encoding note (`.byte`).** The SDK assembles `crt0.c` for the **6502** (user C defaults to the 6502
code generator; only the crt0 needs 65816 instructions, and `add_platform_object_file`'s relocatable-
object indirection doesn't honor a per-target `-mcpu=mosw65816`). So the four 65816-only opcodes —
`xce` (`fb`), `rep #$10` (`c2 10`), the 16-bit `ldx #$01ff` (`a2 ff 01`), `sep #$30` (`e2 30`) — are
emitted as `.byte`; `clc`/`txs` stay as plain-6502 mnemonics. The bytes execute on the SNES 65816 (a
5A22) exactly as the mnemonics, and `llvm-objdump --mcpu=mosw65816` decodes them back (it can't track
the runtime REP/SEP mode, so the 16-bit `ldx #$01ff` statically mis-prints as `ldx #$ff` + a stray
`01` — a disassembler cosmetic; the raw bytes and runtime behavior are correct, see Verification §1).

### 2. Drop the test-local mode entry from `a16.c`

Remove the `__asm__ volatile("clc\n\txce")` line and its comment; the crt0 now provides native mode.
The 16-bit STZ fusion is unchanged — it now runs native because the whole program does.

### 3. No backend / linker / checksum change

`MOSInsertREPSEP`, the `0002` patch, `link.ld` (native vectors already present), `header.s`, and
`snes-checksum.py` are untouched. This is a crt0-only platform change → rebuild the **SDK** only
(`dev/run.sh build`), not the from-source toolchain.

## Critical files

| File | Change |
|---|---|
| `platforms/snes/crt0.c` | `.init.50`: `clc; xce` + 16-bit `txs` + `sep #$30` (native entry, 8-bit default) |
| `examples/65816/a16.c` | remove the inline `clc; xce` (crt0 owns the mode now) |

`platforms/snes-far` inherits the crt0 via `PARENT snes`, so the snes-far (64 KiB) ROMs enter native
mode too — `far-bank1` re-run covers it.

## Risks

- **Platform-wide mode flip.** Every program now runs native. A missed mode subtlety would surface as a
  wrong runtime value — caught by re-running the *entire* green tree in native mode (not just a16).
- **Native stack must be page-1.** A wrong `txs` (8-bit) would put SP at $00FF, corrupting the direct
  page on the first JSR. Mitigated by the transient 16-bit `ldx`; verified by corpus (which exercises
  calls/recursion) passing.
- **snes-far cross-bank.** The far-bank1 ROM puts code in bank $00 and data in bank $01; PB stays 0
  (code never leaves bank $00), so native mode doesn't change the far read. Re-run confirms.

## Verification (all in native mode)

**Status: COMPLETE — all five steps PASS** (2026-06-14, from-source toolchain + rebuilt SDK).

1. **crt0 enters native mode** — disassemble the linked reset path; `.init.50` shows `clc` (`18`),
   `xce` (`fb`), a 16-bit `ldx #$01ff` + `txs`, and `sep #$30` (`e2 30`). (Evidence: `llvm-objdump`
   excerpt of the reset fragment.)

```
Contents of section .init.50:
 0000 78d818fb c210a2ff 019ae230 a9008d00  x..........0....
 0010 42a98f8d 0021                        B....!
# 78=sei d8=cld 18=clc fb=XCE c2 10=REP #$10 a2 ff 01=LDX #$01ff 9a=txs
# e2 30=SEP #$30 a9 00=lda #$00 8d 00 42=sta $4200 a9 8f=lda #$8f 8d 00 21=sta $2100
```

PASS — the native-mode preamble is encoded exactly (the disassembler's mnemonic view mis-prints the
16-bit `ldx #$01ff` as `ldx #$ff` + `01` because it can't track REP/SEP state; the raw bytes above are
correct).

2. **Corpus non-breaking in native mode** — `dev/run.sh corpus` 7/7 PASS. The corpus exercises ALU,
   control flow, arrays/.rodata, structs/pointers, calls/recursion, crt0 init — now all in native
   8-bit. (Evidence: `corpus: 7/7 passed`.)

```
  hello      PASS  sentinel=0x42  liveness: main runs (the smoke ROM)
  arith      PASS  corpus_result=0xA9E9  8/16/32-bit integer ALU
  control    PASS  corpus_result=0x1DFB  loops / if / switch
  arrays     PASS  corpus_result=0x03E1  arrays + .rodata lookup table
  structs    PASS  corpus_result=0x0340  struct layout + pointer deref
  funcs      PASS  corpus_result=0x011E  calls + recursion (soft stack)
  globals    PASS  corpus_result=0xAB55  crt0 .data copy + .bss clear
==> corpus: 7/7 passed
```

PASS — calls/recursion + crt0 .data/.bss all correct in native mode (the page-1 native stack holds).

3. **Far pointers still round-trip in native mode (MAME)** — `dev/run.sh far-run` and
   `dev/run.sh far-bank1` both `SMOKE: PASS got=0xF3`. (Evidence: SMOKE lines.)

```
far-run:   SMOKE: PASS addr=0x7E0200 len=1 got=0xF3 (ran 60 ticks)
far-bank1: PASS: far_src @ 0x18000 (bank $01)
far-bank1: SMOKE: PASS addr=0x7E0200 len=1 got=0xF3 (ran 60 ticks)
```

PASS — absolute-long (`af`/`8f`) is DBR/PB-independent, so the far read (incl. the cross-bank $01 case)
is unchanged by native mode.

4. **Far pointers still agree on bsnes-jg in native mode** — `dev/run.sh xcheck`: far-run + far-bank1
   both `got=0xF3`. (Evidence: xcheck table.)

```
  PASS  hello.sfc:      SMOKE: PASS off=0x20  len=1 got=0x42 (ran 180 frames, bsnes-jg)
  PASS  far-run.sfc:    SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far-bank1.sfc:  SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
```

PASS — the second, cycle-accurate emulator confirms native mode didn't perturb the far ROMs.

5. **a16 passes WITHOUT its inline XCE** — `dev/run.sh a16` with the `clc; xce` removed from `a16.c`:
   the fused `rep #$20; stz; sep #$20` zeroes g16 and `corpus_result == 0x0042` on **both** MAME and
   bsnes-jg, driven solely by the native crt0. (Evidence: both SMOKE lines.)

```
       0: c2 20        	rep	#$20
       2: 9c 00 00     	stz	$0
       5: e2 20        	sep	#$20
  PASS: rep #$20 / single fused stz / sep #$20
MAME:     SMOKE: PASS addr=0x7E0202 len=2 got=0x0042 (ran 60 ticks)
bsnes-jg: SMOKE: PASS off=0x202 len=2 got=0x0042 (ran 180 frames, bsnes-jg)
RESULT: PASS — 16-bit STZ zeroes g16; both emulators read 0x0042
```

PASS — the 16-bit codegen now runs native purely from the crt0; the 1a test-local `clc; xce` is gone.

## Out of scope (later)

- **Increment 1b** — dual-width accumulator register (16-bit `lda`/`sta` flowing a real value). This
  phase only provides the mode; 1b provides the data path.
- **xy16 mode + hardware-stack ABI + calling convention** — the bulk of #321 stage 1.
- **Native interrupt service** (16-bit-aware NMI/IRQ handlers, P save/restore) — the stubs stay `rti`;
  real handlers come with the platform's display/input work, not codegen.
