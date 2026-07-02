# #35 — fix `longjmp` on the 65816: a 65816-aware `platforms/snes/setjmp.S`

**Status:** implemented + verified 2026-07-02.
**Supplements:** `CLAUDE.md` (project) + `docs/agent-handoff.md`.
**Root-cause record:** [`docs/investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md`](../investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md).
**Analysis report** (the full engineering narrative — design decisions, the two detours, hardening): [`docs/investigations/2026-07-02-setjmp-longjmp-65816-fix-analysis.md`](../investigations/2026-07-02-setjmp-longjmp-65816-fix-analysis.md).
**Upstream queue:** [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md) §9.

## Problem

The SDK's common `mos-platform/common/c/setjmp.S` is a **6502** implementation: `longjmp` restores the hard
stack pointer with `tax; txs`. On the 65816 in native mode (SNES crt0 enters it via `XCE`) `txs` transfers
all 16 bits of `X`; with the codegen-default 8-bit index width `X`'s high byte is `0`, so `S` drops into
**page 0** and the following `rts` reads the return address from the wrong page → jumps to garbage →
`longjmp` never returns. Reproduces in **default-8-bit AND `+mos-a16`** (pre-existing upstream, not the #321
fork). This blocked stress-demo **#35** (`setjmp`/`longjmp`).

## Why the fix lives in the SNES platform, not `common/`

`common/c/setjmp.S` is compiled **once** with the 6502 default (`__mosw65816__` is undefined there) and the
resulting `common-c` archive is merged into every platform's `libc.a`. So an `#ifdef __mosw65816__` inside
the common file would never fire for the SNES. Instead we add a **`platforms/snes/setjmp.S`** built with
`-mcpu=mosw65816` (the `mem-far.c` shadow pattern) and rely on **archive member order**: `add_platform_library`
creates `snes-c` from its own sources first, then its POST-BUILD step appends `common-c`'s members — so the
snes `setjmp.S.obj` precedes common's 6502 one, and the linker resolves `setjmp`/`longjmp` from it (common's
copy is never pulled). `snes-far`/`snes-hirom` (`PARENT snes`) fall through to `snes/lib/libc.a` and inherit it.

## Design — no `jmp_buf` ABI change (page-1 reconstruct)

The SNES hardware stack is page-1 by platform contract (crt0 sets `S = $01FF`; the 256-byte page-1 stack
never leaves page 1). So the override keeps the common `jmp_buf` byte layout (`ret_addr[2], s[1], sp[2],
csrs[14]` = 19 bytes — **no `<setjmp.h>` change**): it saves only the low byte of `S` and **reconstructs**
`S = $01xx` on restore. `longjmp`'s hard-SP restore becomes `lda (saved); rep #$20; and #$00ff; ora #$0100;
tcs; sep #$20`, and both routines read/write the return address **stack-relative** (`1,s`/`2,s`) rather than
at a hardcoded `$0101`/`$0102`. Soft-SP + CSR handling is unchanged.

## Changes

- **`platforms/snes/setjmp.S`** (new) — the 65816 native-mode `setjmp`/`longjmp`.
- **`platforms/snes/CMakeLists.txt`** — add `setjmp.S` to `snes-c` with `-mcpu=mosw65816`; link
  `common-asminc` so the override's `.include "imag.inc"` resolves the `__rc*` registers.
- **`examples/snes/corpus/setjmp_sim.c`** (new) + **`examples/snes/corpus/expected.tsv`** row
  (`corpus_result = 0x2007`) — permanent regression guard. It mirrors the `setjmp`/`longjmp`/`jmp_buf`
  declarations from `<setjmp.h>` **inline** rather than `#include`-ing it: the corpus-a16
  `-verify-machineinstrs` gate compiles with `--target=mos` and **no `--config`**, so it has no `-isystem`
  path for platform libc headers (the same reason the Csmith path passes `verify=False`; see
  `tools/a16_fuzz.py`). A `#include <setjmp.h>` there fails with `'setjmp.h' file not found`, which the gate
  reports as a spurious `[CRASH]`. The inline form is codegen-identical to the header (verified by diffing
  `-S` output — only the module filename / internal-symbol GUIDs differ; `preserve_none` is a target-ignored
  no-op in both), and keeps the TU header-free so the full differential runs.

## Verification

### Step 1 — the override is the archive member the linker resolves (`snes` setjmp precedes common's)

```
$ llvm-ar t build/install/mos-platform/snes/lib/libc.a | nl -ba | grep -iE 'mem-far|setjmp'
     1	mem-far.c.obj
     2	setjmp.S.obj      <- snes override (built -mcpu=mosw65816), FIRST
     9	setjmp.S.obj      <- common 6502 copy (merged), never pulled

$ llvm-ar xN 1 …/libc.a setjmp.S.obj && llvm-objdump -d --section=.text.longjmp setjmp.S.obj
      5a: c2 20        	rep	#$20
      5c: 29 ff        	and	#$ff
      5e: 09 00 01     	ora	#$100        ; reconstruct page-1 high byte -> S = $01xx
      61: 1b           	tcs
      62: e2 20        	sep	#$20
      68: 83 01        	sta	$1,s         ; return address written stack-relative
      6d: 83 02        	sta	$2,s
```

PASS — the snes 65816 `setjmp.S.obj` is archive member 1 (before common's at 9), so the linker resolves
`setjmp`/`longjmp` from it; its `longjmp` reconstructs `S = $01xx` (`ora #$100; tcs`) and writes the return
address stack-relative — the fix, not the 6502 `tax; txs`.

### Step 2 — full differential: host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg

```
$ # single-file differential (setjmp_sim through tools/a16_fuzz.py check, in-container)
$ python3 tools/a16_fuzz.py check --src examples/snes/corpus/setjmp_sim.c \
      --name corpus-setjmp_sim --expected 0x2007
==> corpus-setjmp_sim: differential default vs +mos-a16  (expected 0x2007; bsnes=yes)
  [PASS] corpus-setjmp_sim  0x2007 (all agree)
RESULT: PASS — corpus-setjmp_sim: default == +mos-a16 == host on both emulators
```

PASS — `host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg = 0x2007`. Before the
fix `longjmp` never returned and `corpus_result` stayed at the pre-`longjmp` sentinel `0x1111`.

Note: the first `corpus-a16` run reported `setjmp_sim` as `[CRASH] verify-machineinstrs (+mos-a16) failed`.
That was **not** a compiler crash — it was `'setjmp.h' file not found` in the `--config`-less verify gate
(see the regression-guard note above). Rewriting the guard header-free resolved it; the runtime differential
then passes. (Unrelated: `nbody_sim` FAILs on a pre-existing manifest typo — `corpus/nbody_sim.c` vs the real
`n-body_sim.c` — and `multibase_sim` has its own pre-existing verify FAIL; neither is touched by this change.)
