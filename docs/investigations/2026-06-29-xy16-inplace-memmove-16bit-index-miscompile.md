# `+mos-xy16` miscompile: iterative in-place `memmove`/`memcpy` rewrite over a 16-bit-indexed buffer

**Status: FIXED — real compiler bug, fixed in `MOSInsertREPSEP::placeIntraBlock` (patch `0002`, commit
`e643329`).** The original X-width-lattice hypothesis (this "Summary"/"Isolation" section, "across loop
iterations … an X-width lattice / register-allocation interaction") was **correct**; the later trunc
hypothesis was wrong. A differential **regression gate** locks the fix in (`dev/run.sh xy16inplace`).

> **Correction (note to self).** An earlier revision of this section (commit `b46aa2b`) wrongly declared this
> "RESOLVED — no compiler bug, isolated-toolchain artifact." That was an **error of measurement sequencing**:
> I re-ran the repro against the shared `build/llvm-mos-install` and saw `0x90AA` (correct) — but that build had
> **already been rebuilt at 18:38 with the fix** (`MOSInsertREPSEP.cpp.o` @ 18:38:20, `clang-23` @ 18:38:21),
> committed 9 min later as `e643329`. I measured the *fixed* toolchain and mistook it for "never broken." The
> bug was real. Lesson: on the hot shared tree, pin the toolchain's build time against the fix before concluding
> "not reproducible" (cf. [[stress-demos-fix-compiler-not-workaround]], governing lesson #1 "verify a rebuild
> actually took / measure in realistic context").

## Root cause + fix (commit `e643329`, `MOSInsertREPSEP`)

The genuine 16-bit buffer index *does* lower through the dedicated `G_*_ABS_IDX16` path (B2) — that part of my
MIR reading was right. The defect was one level down, in **X-register width management**: `MOSInsertREPSEP`
placed a `sep #$10` (narrowing X/Y to 8-bit, e.g. ahead of a `ldy #imm`) **between** the `ldx __rcN` that loads
the 16-bit index and the `lda buf,X16` that consumes it. On the 65816 `SEP` physically **zeroes X's high byte**,
so `lda abs,X16` then indexed from `X.lo` only — reading `buf[i & 0xFF]` instead of `buf[i]` for `i ≥ 256`
(exactly: needs `+mos-xy16` + a 16-bit index + the iterative loop that keeps the index live across the
narrowing). **Fix:** track the last `XW_X16` X-writer per block; when an 8→16 `REP` is inserted for an X-reader
after a 16→8 narrowing, clone that writer and insert it `[REP, reload, reader]` so X is restored to the full
16-bit value before the indexed load. Default/`+mos-a16` unaffected (no 16-bit index register).

This is a sibling of the earlier `requiredXWidth`/X-lattice fixes (`4d8a2bd`, `321-xy16-track-a`,
`321-xy16-seed247-445`) — a new omission they didn't cover. `8c928b8` (the legalizer-domination fix) is
**unrelated** (it only moved B1's MERGE insert point; B1 isn't on the 16-bit-index path).

| test (shipping toolchain, post-fix) | CAP=1700 (16-bit idx) | CAP=200 (8-bit idx) |
|---|---|---|
| host == default == `+mos-a16` == `+mos-xy16` @ bsnes-jg | `0x90AA` | `0xDEBD` |

`-verify-machineinstrs` clean; real #23 L-System demo gate passes (`0x79C3`). Gate: `dev/run.sh xy16inplace`
(commit `64b7431`). **Impact:** #23 L-System ships 5-way-green.

## Relationship to `8c928b8` (legalizer indexed-addressing domination fix)

`8c928b8` (branch `wt/fix-legalizer-indexed-domination`, merge-pending) fixes a **different symptom in the
same function** `MOSLegalizerInfo::tryAbsoluteIndexedAddressing`: its seed-56 workaround built
`Explicit16 = G_MERGE(trunc(NewOffset), G_CONSTANT 0)` at the `G_PtrAdd`'s block, which failed
`-verify-machineinstrs` ("defs don't dominate all uses") when `NewOffset` is used in a sibling block. The
fix relocates that `MERGE` to `NewOffset`'s SSA def — and is **explicitly codegen-neutral for `-verify-off`
builds** ("NOT a miscompile, -verify-off codegen is correct").

**Tested:** built an isolated worktree toolchain (`throwaway/lsystem-xy16-verify`) with `8c928b8`'s fixed
`0002` applied (verified active: their `legalindexdom.c` `-verify` gate is clean in both modes on it). My
repro **still diverges** (`CAP=1700` xy16 `0x1CC6` vs `0x90AA`). So this is a **distinct defect** the
domination fix does not cover.

## Root cause (hypothesis)

The seed-56 workaround itself — `Explicit16 = G_MERGE(trunc(NewOffset, s8), G_CONSTANT 0)` — **truncates the
offset to 8 bits and zero-extends**, i.e. it keeps only the *low byte* of the index. That is correct when
the index is `<256` (matches `CAP=200` passing) but **drops the high byte of a genuine 16-bit index** under
`+mos-xy16` (matches `CAP=1700` diverging, only in xy16, only with the iterative loop that keeps the index
16-bit through LTO). The `8c928b8` domination fix moved *where* this truncating MERGE is emitted but kept
the **`trunc`**, so the high-byte loss — a real miscompile — remains. The fix is likely to widen/zero-extend
`NewOffset` to 16 bits (not `trunc`) when the index is genuinely 16-bit (`HasIndex16` / the xy16 path),
emitting a proper `G_ZEXT`/16-bit merge instead of `G_MERGE(trunc(...), 0)`.

## Summary

Under **`+mos-xy16`** (16-bit X/Y index registers), a loop that rewrites a `>256`-byte buffer **in place**
— shifting the tail with `memmove` and writing a production with `memcpy`, with the destination/source
pointers and length **derived from a 16-bit loop index** — produces the **wrong bytes**. The same code is
correct under `default` (8-bit) and `+mos-a16`. The toolchain commit is
`c798c31416f72b395c658b5502d281a162387ab1` (freshly rebuilt — **not** a stale-`build/` artifact, the class
of false alarm seen in [`321-xy16-cmove-stale-xfail`] and [`321-pr15296-zp-overflow`]).

## Evidence (built-string CRC, bsnes-jg, via the L-system build `lsystem_build`)

| mode | CRC | |
|---|---|---|
| host (x86) | `0x90AA` | ground truth |
| default (8-bit) | `0x90AA` | ✅ |
| `+mos-a16` | `0x90AA` | ✅ |
| **`+mos-xy16`** | **`0x1CC6`** | ❌ wrong |

## Isolation (each row a separate on-target run, a16 vs xy16)

| Variant | a16 | xy16 | conclusion |
|---|---|---|---|
| full in-place build, `CAP=1700` (indices ≥256 → 16-bit X/Y) | `0x90AA` | `0x1CC6` | **diverges** |
| full in-place build, `CAP=200` (indices <256 → 8-bit) | `0xDEBD` | `0xDEBD` | match → **needs 16-bit index** |
| ping-pong build (two buffers, `memcpy` only, monotonic index) | `0x3857` | `0x3857` | match → **needs in-place `memmove`** |
| one in-place `memmove`+`memcpy` at a 16-bit offset (no loop) | `0xD919` | `0xD919` | match → **needs the iterative loop** |
| plain overlapping `memmove`, computed args, no loop | `0x08BB` | `0x08BB` | match |

So the trigger is the **conjunction**: `+mos-xy16` **AND** a 16-bit buffer index **AND** the iterative
in-place `memmove`/`memcpy` expansion loop. It is **not** a single mis-widthed addressing instruction (a
single expansion is fine) — it emerges across loop iterations, consistent with an X-width lattice /
register-allocation interaction (cf. the `requiredXWidth` family fixes `4d8a2bd`, `321-xy16-xflag-lattice`,
`321-xy16-track-a` which each claimed to close "the last omission" — this is a *new* one they don't cover).
`-verify-machineinstrs` is **clean**.

## Minimal repro

`build/lstight_sim.c` (gitignored; canonical copy below). `CAP=1700` diverges, `CAP=200` matches.

```c
#include <stdint.h>
#ifndef CAP
#define CAP 1700
#endif
volatile uint16_t corpus_result;
static char buf[CAP];
static const char *rule(char c){ switch(c){case 'X':return "F-[[X]+X]+F[+FX]-X";case 'F':return "FF";default:return 0;} }
int main(void){
  buf[0]='X'; uint16_t len=1;
  for(uint8_t g=0;g<5u;g++){
    uint16_t i=0;
    while(i<len){
      const char*p=rule(buf[i]);
      if(!p){i++;continue;}
      uint16_t pl=(uint16_t)__builtin_strlen(p);
      if((uint16_t)(len+(pl-1u))>(uint16_t)(CAP-1)) goto done;
      __builtin_memmove(&buf[i+pl], &buf[i+1], (uint16_t)(len-(i+1u)));
      __builtin_memcpy(&buf[i], p, pl);
      len=(uint16_t)(len+(pl-1u)); i=(uint16_t)(i+pl);
    }
  }
done:;
  uint16_t h=0; for(uint16_t i=0;i<len;i++) h=(uint16_t)((uint16_t)(((unsigned)h<<1)|((unsigned)h>>15))^(uint16_t)(uint8_t)buf[i]);
  corpus_result=h; for(;;){} return 0;
}
```

Repro commands (in the dev container, `TOOL=$B/llvm-mos-install/bin`, `CFG=$B/install/bin/mos-snes.cfg`):

```sh
for CAP in 1700 200; do for mode in a16 xy16; do
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-$mode \
    -DCAP=$CAP -Os -Wl,-Map=m.map -o r.sfc lstight_sim.c
  VMA=$(awk '$NF=="corpus_result"{print $1;exit}' m.map)
  "$B/jgxcheck" r.sfc vendor/bsnes-jg/Database "0x$VMA" 2 0xFFFF 500 x.png   # prints got=0x....
done; done
# expect: CAP=1700 a16=0x90AA xy16=0x1CC6 (DIVERGE);  CAP=200 both 0xDEBD (match)
```

## Next steps (not yet done)

1. Build an LTO-surviving single-function repro (the linked `--config` path is where the divergence shows;
   small globals can LTO-narrow a 16-bit index back to X8 — see `321-xy16-xflag-lattice` note).
2. Dump MIR after `mos-insert-rep-sep` for the xy16 build; find the indexed buffer op (or the
   memmove/memcpy argument-pointer computation) running at the wrong X width across the loop back-edge.
3. Fix in `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` (`requiredXWidth` / the X lattice),
   on a **throwaway compiler worktree** (per `CLAUDE.md`), then re-verify corpus + torture + fuzz + the
   xy16 suite + `-verify-machineinstrs`, and add this repro as a `dev/` differential gate (like
   `xy16call`) so a recurrence hard-FAILs.

## Impact on the #23 L-System demo

The demo's in-place `memmove` build is the vehicle that found this. It cannot ship 5-way-green until the
bug is fixed (or the demo is moved to the ping-pong build, which is 5-way clean but loses the `memmove`
probe — a workaround, to be avoided per the battery's "fix the compiler, don't work around" rule).
