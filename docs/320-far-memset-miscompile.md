# #320 far-pointer defect — a far constant-fill is miscompiled to the near `__memset`

**Found:** 2026-06-26, building the #3 SNES Blossom renderer (the far hit-count grid clear).
**Status:** root-caused + minimal repro + workaround in place; **backend fix not yet attempted** (a
follow-up, like the [default-8bit coalescer miscompile](upstream-coalesce-rotate-ac-pr.md) before it).
**Severity:** silent miscompile (wrong bank written, no diagnostic) in the `+mos-a16` far-pointer path.

## Symptom

A constant fill of a far (`__attribute__((address_space(2)))`) buffer writes the **wrong bank**:

```c
#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;
do { grid[i] = 0x42; } while (++i != 4096);     // intends $7E2000..$7E2FFF
```

At `-Os` the loop is coalesced into `jsr __memset` with the 24-bit destination in the imaginary
registers — but libc `__memset` is a **near** (16-bit, DBR-relative) routine, so it writes
`$00:2000..` (PPU/APU **MMIO + open-bus** on the SNES) and `$7E2000` is never touched. The bytes are
silently lost; on hardware/bsnes `$7E2000` keeps its random power-on value.

Disassembly of the repro (`examples/65816/far_memset.c`):

```
10: a9 42        lda #$42                 ; fill value
...              stx __rc4/5/6/7          ; 24-bit dest $7E2000 in imaginary regs
1c: 20 00 00     jsr __memset             ; <-- NEAR memset; ignores the bank byte
```

## Why a CRC/round-trip gate misses it

The natural far-buffer gate (e.g. `examples/snes/mandel-mode7.c`'s `crc_fb`) **stores and loads
through the same far pointer**. If both the store and the load use the same wrong-but-consistent
address, the round-trip still agrees with the host reference — the gate passes. The bug only surfaces
when an **independent reader** checks the physical far address (here: `jgxcheck` reading WRAM offset
`0x2000` directly; the Blossom grid gate `dev/run.sh blossom-grid` reads the grid via the far pointer
*and* the harness reads physical `$7E2000`, so a divergence shows up as a host≠target hash).

## Root cause (where to fix)

The MOS backend lowers `llvm.memset`/`llvm.memcpy` (formed by the loop-idiom recognizer, or written
directly) to the near `__memset`/`__memcpy` libcalls **without honoring a non-zero (far/AS2) pointer
address space**. The correct behavior is one of:
1. when the dest (or src) is `addrspace(2)`, call a **far-aware** `__memset_far`/`__memcpy_far` that
   takes a 24-bit pointer; or
2. block the loop-idiom recognizer from forming `memset`/`memcpy` for far address spaces (fall back to
   the inline indirect-long store loop the backend already emits for non-constant far stores); or
3. expand far memset/memcpy inline in the backend.

(2) is the smallest correct change and matches how a *non-constant* far store already lowers
(`sta [dp]`). This is generic to the far-pointer feature → **upstream-worthy** (`wbniv/llvm-mos`).

## Workaround (in use)

A **volatile** far store is never coalesced into `__memset`, so each stays a real indirect-long
`sta [dp]`. `examples/65816/hopalong.h`'s `HOP_DEFINE_CLEAR` clears the grid through a
`volatile FAR uint8_t *` alias — correct on both host and target, at the cost of an un-vectorized
byte loop (fine for an infrequent one-time clear). Per-element far writes that compute each value
(the plot RMW, the colorize/de-linearize passes, `mandel-mode7`'s fill) are **not** memset-shaped, so
they are unaffected; only constant fills need the volatile alias.

## Repro / gate

- `examples/65816/far_memset.c` — minimal standalone repro (self-checks via an independent far read).
- The bug was caught in practice by `dev/run.sh blossom-grid` (host≠target before the workaround).

## Reproduce

```sh
TOOL=build/llvm-mos-install/bin; CFG=build/install/bin/mos-snes.cfg
$TOOL/mos-clang --config $CFG -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map=/tmp/fm.map -o /tmp/fm.sfc examples/65816/far_memset.c
python3 tools/snes-checksum.py /tmp/fm.sfc
# corpus_result want 0x2000 (0x42*4096 mod 2^16); physical $7E2000 want 0x42 — both FAIL today:
build/jgxcheck /tmp/fm.sfc vendor/bsnes-jg/Database 0x200 2 0x2000 300   # got != 0x2000
build/jgxcheck /tmp/fm.sfc vendor/bsnes-jg/Database 0x2000 1 0x42  300   # got != 0x42
```
