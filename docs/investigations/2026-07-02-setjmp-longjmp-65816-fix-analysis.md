# Analysis report — fixing `longjmp` on the 65816 (#35), end to end

**Date:** 2026-07-02  **Status:** fixed, verified, committed (`04a8495`); Round 6 hardening drafted (`aacc8fa`).

This is the engineering narrative for the `setjmp`/`longjmp` fix — the *why* behind each decision, the two
non-obvious architectural facts that shaped it, and the two detours that looked like compiler bugs but were
not. The bug's minimal root-cause record is
[2026-06-30-setjmp-longjmp-65816-native-stack-bug.md](2026-06-30-setjmp-longjmp-65816-native-stack-bug.md)
(now with a Fix section); the numbered verification lives in the
[fix plan](../plans/2026-07-02-35-setjmp-longjmp-65816-fix.md). This report ties them together and records the
reasoning that neither of those captures.

---

## 1. TL;DR

`longjmp` never returned on the 65816. The SDK's common `mos-platform/common/c/setjmp.S` is a **6502**
implementation; its `longjmp` restores the hardware stack pointer with `tax; txs`, which in **native mode**
(the SNES runs native, `E=0`, entered by crt0's `XCE`) transfers all **16 bits** of `X`. With the
codegen-default **8-bit index width**, `X`'s high byte is `0`, so `S` lands in **page 0**; the subsequent
`rts` reads the return address from the wrong page and jumps to garbage. Failed in **default-8-bit AND
`+mos-a16`** → a pre-existing upstream `llvm-mos-sdk` defect, not the #321 fork.

**Fix:** a 65816-aware **`platforms/snes/setjmp.S`** that reconstructs the invariant page-1 16-bit `S = $01xx`
(`ora #$0100; tcs`) and reads/writes the return address **stack-relative** (`1,s`/`2,s`). It shadows the
common 6502 object by **archive member order** and requires **no `jmp_buf` ABI change**. Verified
`host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg = 0x2007`.

---

## 2. The bug at instruction level

The common `longjmp` restore, and why each line is 6502-only:

```asm
  ; ... (soft-SP __rc0/__rc1 and CSRs __rc18..__rc31 restored correctly) ...
  lda (__rc2),y     ; the saved 8-bit hard SP     <- only 8 bits were ever saved (setjmp: tsx; txa)
  tax               ; X = saved low byte; high byte of X = 0 in 8-bit-index mode
  txs               ; S <- X  — NATIVE MODE: 16-bit transfer, so S := $00xx   *** BUG ***
  ...
  sta $102,x        ; write return addr hi at hardcoded page 1
  sta $101,x        ; write return addr lo at hardcoded page 1
  rts               ; pops from S+1,S+2 = $00xx+1 = page 0 -> garbage -> hang
```

The three 6502 assumptions, only the third of which actually bites on the SNES:

1. **Saves only 8 bits of `S`** (`tsx; txa`). Latent — see below.
2. **Reads/writes the return address at a hardcoded `$0101`/`$0102`.** Fine *on the SNES* because the stack
   physically sits in page 1, but not page-agnostic.
3. **Restores `S` via `tax; txs`.** This is the live defect. On a 6502 (or a 65816 in *emulation* mode) `txs`
   is an 8-bit transfer confined to page 1. In native mode it is a full 16-bit transfer, and because the
   index width is 8-bit the high byte of `X` is 0 → `S = $00xx`. The stack pointer leaves page 1, and `rts`
   reads garbage.

`setjmp` + an ordinary `rts` return works — the corruption is entirely in the `longjmp` **restore**. That
asymmetry was the first clue: the save side survives a normal return, so the fault is in how the save is
*undone*.

---

## 3. The decisive architectural fact: the fix cannot live in `common/`

The obvious fix — make `common/c/setjmp.S` CPU-conditional with `#ifdef __mosw65816__` — **does not work**,
and understanding why determined the entire shape of the fix.

`common/c/setjmp.S` is compiled **once**, with the common platform's toolchain. common's `clang.cfg` is
empty, so it builds as the **6502 default** — `__mosw65816__` is *undefined* there. The resulting
`common-c` archive is then **merged** into every derived platform's `libc.a`
(`add_platform_library` → `_merge_parent_library` → `merge_libraries`, an `ar qL` append). So the SNES does
not recompile `setjmp.S` for the 65816 — it inherits common's 6502 object. A `#ifdef __mosw65816__` inside
the common file would compile the 6502 branch and never the 65816 one for the SNES. (Confirmed empirically:
`__mosw65816__` is defined only when `-mcpu=mosw65816` is on the compile line.)

Therefore the fix must be a **platform override** compiled with `-mcpu=mosw65816`. The SDK already has the
pattern: `mem-far.c` is added to `snes-c` for exactly this reason. The one wrinkle `mem-far.c` doesn't face —
it defines *new* symbols, whereas `setjmp.S` *overrides* symbols already in `common-c` — is resolved by
**archive member order**, see §5.

---

## 4. The design fact that avoids an ABI change: the SNES stack is page-1 by contract

The general-correct 65816 `setjmp.S` would save the full 16-bit `S` (`tsc`/`tcs`) and widen `jmp_buf`'s `s`
field from 1 byte to 2 — an `<setjmp.h>` ABI change. That is unnecessary on the SNES: the platform contract
pins the hardware stack to page 1. crt0 sets `S = $01FF` and the stack is the 256-byte page-1 region; the
high byte of `S` is **invariantly `$01`**. So the override saves only the **low byte** (byte-layout-identical
to the 6502 `jmp_buf`: `ret_addr[2], s[1], sp[2], csrs[14]` = 19 bytes) and **reconstructs** the high byte on
restore:

```asm
  ldy #2
  lda (__rc2),y     ; saved low byte of S
  rep #$20
  and #$00ff        ; A = $00xx
  ora #$0100        ; A = $01xx   (reconstruct the invariant page-1 high byte)
  tcs               ; S = $01xx   (16-bit transfer, the correct native-mode restore)
  sep #$20
```

and reads/writes the return address stack-relative (`1,s`/`2,s`) rather than at a hardcoded `$0101`/`$0102`.
Only the accumulator is toggled to 16-bit (`rep`/`sep #$20`); the index width — and thus the 8-bit `jmp_buf`
offset held in `Y` — is left untouched. Keeping `jmp_buf` byte-identical means the fix is a **pure shadow**:
no `<setjmp.h>` change, no size change, no risk to any other platform.

Trade-off recorded honestly: this override is **SNES-specific** (page-1-assuming). A hypothetical 65816
platform whose stack leaves page 1 would need the full-16-bit-`S` variant + the header change. No such
platform exists; the SNES contract makes the reconstruct correct and the minimal-diff choice the right one.

---

## 5. How the shadow resolves without a duplicate-symbol error

`snes-c` is built from its own sources first (`mem-far.c`, then `setjmp.S`), and `add_platform_library`'s
POST-BUILD step **appends** `common-c`'s members. So in the final `libc.a`:

```
member 1: mem-far.c.obj
member 2: setjmp.S.obj      <- snes override (built -mcpu=mosw65816)
   ...
member 9: setjmp.S.obj      <- common's 6502 copy (merged)
```

Both members define `setjmp`/`longjmp`, but the linker pulls the **first** member that satisfies an undefined
reference — the snes one at index 2 — and common's copy at index 9 is **never pulled** (it provides no unique
symbol). No multiply-defined error, because the second definition is simply never extracted. `snes-far` /
`snes-hirom` (`PARENT snes`) fall through to `snes/lib/libc.a` and inherit the same fix. One detail:
`snes-c` must link `common-asminc` so the override's `.include "imag.inc"` resolves the `__rc*` registers
(common-c gets this via its own `target_link_libraries`; `mem-far.c` never needed it).

---

## 6. Verification

**Structural** — the linker really resolves the override, and it really contains the fix:

- `llvm-ar t …/libc.a` → the two `setjmp.S.obj` members sit at indices 2 and 9; the snes one is first.
- `llvm-objdump -d --section=.text.longjmp` on member 2 shows `rep #$20; and #$ff; ora #$100; tcs; sep #$20`
  then `sta $1,s`/`sta $2,s` — the reconstruct, not the 6502 `tax; txs`.

**Runtime** — the full differential, the project bar:

```
==> corpus-setjmp_sim: differential default vs +mos-a16  (expected 0x2007; bsnes=yes)
  [PASS] corpus-setjmp_sim  0x2007 (all agree)
RESULT: PASS — corpus-setjmp_sim: default == +mos-a16 == host on both emulators
```

`host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg = 0x2007`. Before the fix
`corpus_result` stuck at the pre-`longjmp` sentinel `0x1111` (control never returned to the `setjmp` site).
A permanent regression guard, `examples/snes/corpus/setjmp_sim.c`, is now in the corpus.

---

## 7. Two detours that looked like compiler bugs but were not

Per the project's governing lesson (a differential/`-verify`/crash failure is a *compiler* bug to isolate,
not to dodge), both were chased to a concrete cause before being set aside.

**(a) `setjmp_sim` reported `[CRASH] verify-machineinstrs (+mos-a16) failed`.** This was **not** a compiler
crash. The corpus-a16 verify gate compiles with `--target=mos` and **no `--config`**, so it has no
`-isystem` path for platform libc headers; `#include <setjmp.h>` failed with `'setjmp.h' file not found`
(returncode ≠ 0 → the gate's crash classifier reported `[CRASH]`). This is a documented, accepted harness
limitation — the Csmith fuzz path passes `verify=False` for the same reason (its TUs `#include <math.h>`).
The classifier distinguishes it from the real `a16-rc-undef-ra-pure-virtual` known issue (predicate:
`"Using an undefined physical register" in log`), which `setjmp_sim`'s log does not contain — hence hard-FAIL,
not XFAIL. **Resolution:** make the regression guard header-free by mirroring the `setjmp`/`longjmp`/`jmp_buf`
declarations inline from `<setjmp.h>`. Proven codegen-identical by diffing the `-S` output (only the module
filename and internal-symbol GUIDs differ — both derived from the source path).

**(b) `preserve_none` warns under `--target=mos` but not under `--config`.** The attribute is
"not supported for this target" and **ignored in both cases** — the real `<setjmp.h>` is a *system* header, so
clang silences `-Wunknown/ignored-attributes` there; my inline copy (a non-system TU) surfaced the warning.
So `preserve_none` is a **no-op on the mos target today**; the `<setjmp.h>` build gets the same (default)
calling convention as the inline build, which is why the `-S` diff is identical. Kept the attribute verbatim
for fidelity to the header and silenced the diagnostic with a scoped `#pragma clang diagnostic`.

(Unrelated pre-existing corpus reds seen in the same run, neither touched by this change: `nbody_sim` FAILs on
a manifest/filename typo — `corpus/nbody_sim.c` vs the real `n-body_sim.c`; `multibase_sim` has its own
pre-existing verify FAIL.)

---

## 8. Upstream posture

This belongs in `llvm-mos-sdk`'s SNES platform. It should land **with the SNES-platform PR**
(llvm-mos-sdk#415 reconciliation) — upstream has no 65816 `setjmp.S` today, so there is nothing there yet to
compile one. Standalone, the bug is still worth filing; the ready-to-post `gh` command and framing are in
[upstream-contribution-status.md](../upstream-contribution-status.md) §9.

---

## 9. Hardening: Round 6 Cluster G (#116–118)

Round 6's charter is "re-stress every bug we found and fixed," but its clusters map onto **codegen** patches
(`0002`/`0016`/`0017`/`0010`/`0011…`). The setjmp bug was absent for two reasons: it is a **runtime/library**
fix (no `patches/llvm-mos/*.patch`), and it was still BLOCKED when Round 6 was drafted (2026-07-01). Now that
the fix has landed, its own charter makes it a gap — closed by **Cluster G** (drafted, not yet built):

- **#116 `backtrack`** — idea #35 realized: a recursive solver that `longjmp`s to the last choice point,
  unwinding many `jsr` frames per jump → exercises the page-1 `S` reconstruct + CSR/soft-SP restore that the
  one-frame `corpus/setjmp_sim.c` guard never touches. The flagship.
- **#117 `csrjmp`** — all 14 `__rc18..31` callee-saved values live across the `setjmp`→`longjmp` round-trip;
  an off-by-one in the renumbered restore offsets corrupts exactly one.
- **#118 `retryjmp`** — re-entering one `setjmp` site from varying call depths with a deep soft stack (the
  `setjmp`-as-exceptions idiom).

Full spec in the [demo-ideas doc](2026-06-27-compiler-stress-test-demo-ideas.md) (`# Round 6`, Cluster G).

---

## 10. Artifacts

| File | Role |
|---|---|
| `platforms/snes/setjmp.S` | the fix — 65816-aware `setjmp`/`longjmp` |
| `platforms/snes/CMakeLists.txt` | wires it into `snes-c` (`-mcpu=mosw65816`; links `common-asminc`) |
| `examples/snes/corpus/setjmp_sim.c` + `expected.tsv` | permanent regression guard (`0x2007`) |
| [`docs/investigations/2026-06-30-…-native-stack-bug.md`](2026-06-30-setjmp-longjmp-65816-native-stack-bug.md) | root-cause record + Fix section |
| [`docs/plans/2026-07-02-35-…-fix.md`](../plans/2026-07-02-35-setjmp-longjmp-65816-fix.md) | plan + numbered verification with evidence |
| [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md) §9 | upstream posture + `gh` command |

Commits (unpushed): `04a8495` (fix + guard + docs), `aacc8fa` (Round 6 Cluster G).
