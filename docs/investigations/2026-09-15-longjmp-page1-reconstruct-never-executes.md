# `longjmp`'s page‑1 stack reconstruction never executes — bug #35 is still live

**Status: OPEN defect, root-caused, no fix attempted here.** Found 2026‑09‑15 by the Round 6
Cluster G demo work ([plan](../plans/2026-09-15-116-118-setjmp-cluster-g-demos.md)), which is
blocked on it.

**Severity: high.** Every `longjmp` on the SNES leaves the 65816 hard stack pointer in **page 0**.
Any program that *returns* from the function that called `setjmp` — the ordinary
`setjmp`-as-exceptions idiom — `rts`-es to an address read out of the zero page and runs off into
garbage. Subsequent pushes also trample the `__rc` imaginary registers at `$0000‑$001F`.

## One-line cause

`platforms/snes/setjmp.S:170‑173`

```asm
  rep #$20
  and #$00ff
  ora #$0100
  tcs
```

The MOS assembler picks an immediate's width from the **value's magnitude**, not from the `M`
flag state established by `rep`/`sep`. `$00ff` fits in 8 bits, so `and #$00ff` is encoded as the
**2‑byte** `29 ff`; `$0100` does not, so `ora #$0100` is encoded as the **3‑byte** `09 00 01`.

Demonstrated directly (assemble the four instructions above plus `and #$01ff`):

```
$ mos-clang --target=mos -mcpu=mosw65816 -c enc.s -o enc.o
$ llvm-objdump -s --section=.text.enc enc.o
 0000 c22029ff 09000129 ff011be2 20
       ^rep    ^and     ^ora     ^and #$01ff  ^tcs ^sep
       c2 20   29 ff    09 00 01 29 ff 01     1b   e2 20
```

`and #$00ff` → 2 bytes. `and #$01ff` → 3 bytes. The encoder is width-by-magnitude.

At run time `M` is 0 (16‑bit A) when the CPU reaches `$80f2`, so the `29` opcode consumes a
**16‑bit** operand — and the two bytes it eats are `ff 09`, i.e. the low half of the intended mask
plus the **opcode byte of the `ora`**. So the executed stream is:

| bytes | executed as | intended |
|---|---|---|
| `29 ff 09` | `and #$09FF` | `and #$00FF` |
| `00 01` | `BRK #$01` | (nothing — these were the `ora` operand) |
| `1b` | `tcs` | `tcs` |

**The `ora #$0100` never executes.** `tcs` therefore loads `S` with `A & $09FF`, whose high byte
is normally `$00`. The page‑1 reconstruction that is the entire point of the #35 fix is dead code.

## Observed evidence

Minimal repro: [`sjreturn_min.c`](2026-09-15-longjmp-page1-reconstruct-never-executes/sjreturn_min.c)
(12 lines of C; build + run commands in its header comment). `longjmp` back into a **non-`main`**
function which then returns normally.

```
SMOKE: FAIL off=0x20 len=2 got=0x1111 want=0xF00D      (bsnes-jg, 300 frames)
```

A probe build that dumps memory instead of returning (MAME 0.285, headless):

```
ZP $00F0-$00FF = 55 55 55 55 55 55 55 55 55 55 4B 81 55 55 55 55
P1 $01F0-$01FF = 55 55 55 55 14 F7 80 00 8F 81 78 81 40 81 28 80
S=00FB PC=8171 E=0
```

Read that as:

- `E=0` — the CPU is in native mode, as the crt0 intends.
- `S=$00FB` — **the hard stack pointer is in page 0.**
- `$00FA/$00FB = 4B 81` — `longjmp`'s `sta 1,s` / `sta 2,s` wrote the saved `setjmp` return
  address `$814B` into the **zero page**.
- `$01FA/$01FB = 78 81` — the real page‑1 stack slot still holds the *caller's* return address
  `$8178`, untouched. Nothing was ever written to page 1.

The saved `jmp_buf` itself is correct (`ret_addr=$814B`, `s=$F9`, `sp=$2000`), so `setjmp` is fine;
the fault is entirely in `longjmp`'s `S` reconstruction.

## Why the existing guard misses it

`corpus/setjmp_sim.c` (`0x2007`) passes, and has passed since 2026‑07‑02. It does the `longjmp` from
`main`, and `main` then spins in `for (;;) wai` — **it never returns from the `setjmp` frame.** With
`S` at `$00F9`, `longjmp`'s `sta 1,s` / `sta 2,s` and its own `rts` are self-consistent within the
zero page, so the non-local return itself lands correctly. The corruption only becomes visible at the
*next* stack operation that relies on the real page‑1 frames — the first `rts` out of the `setjmp`
function, or the first push that walks down out of `$00xx`.

That is precisely the escalation Cluster G was written to perform, and #116 hit it immediately.

## Scope

- One occurrence. `grep -rn 'rep #\$20' platforms/` returns `platforms/snes/setjmp.S:170` and
  nothing else, so no other hand-written platform assembly is exposed to the same encoder trap.
- Mode-independent: reproduces in the **default 8‑bit** build. `+mos-a16` and `+mos-xy16` are not
  involved — `longjmp` runs at the ambient default widths.
- Not a codegen bug. The compiler output for the repro is correct; the defect is in hand-written
  runtime assembly plus the assembler's immediate-width policy.

## Resolution (2026-09-15)

The source CAN express "16-bit immediate whose value happens to fit in 8 bits": the MOS assembler
already has a modifier for exactly this, `mos16(...)` (`MOSMCExpr::VK_IMM16`,
`MOS/MCTargetDesc/MOSModifierNames.cpp:18`), which forces the 16-bit-sized encoding regardless of
the operand's value. Confirmed with a standalone probe before touching `setjmp.S`:

```
$ printf 'rep #$20\nand #$00ff\nora #$0100\ntcs\n' | mos-clang -x assembler-with-cpp -target mos -mcpu=mosw65816 -c -o /tmp/a.o -
$ llvm-objdump -d --triple=mos /tmp/a.o
   0: c2 20         rep  #$20
   2: 29 ff         and  #$ff      <- 2 bytes: the bug
   4: 09 00 01      ora  #$100
   7: 1b            tcs

$ printf 'rep #$20\nand #mos16($00ff)\nora #$0100\ntcs\n' | mos-clang -x assembler-with-cpp -target mos -mcpu=mosw65816 -c -o /tmp/b.o -
$ llvm-objdump -d --triple=mos /tmp/b.o
   0: c2 20         rep  #$20
   2: 29 ff 00      and  #mos16($ff)   <- 3 bytes: correct
   5: 09 00 01      ora  #$100
   8: 1b            tcs
```

Fix: wrap the immediate, `and #mos16($00ff)`, in `platforms/snes/setjmp.S`. One line, no behavior
change to anything except the encoding of that one operand. Question 3 (whether the assembler
should track `rep`/`sep` state itself) stays open as a separate, larger question — not needed for
this fix and not pursued here.

**Verified**, rebuilt SDK: `sjreturn_min.c`'s `corpus_result` is now `0xF00D` (was `0x1111`) at
300 frames on bsnes-jg. `corpus/setjmp_sim.c`'s existing 5-way guard (`0x2007`) still PASSes — the
fix doesn't disturb the one-frame case it already covered. `#116 backtrack`
(`examples/snes/corpus/backtrack_sim.c`) now PASSes its `0x7336` gate at default-8bit, `+mos-a16`,
and `+mos-xy16`, all matching the host oracle exactly (raw output in the plan's verification
record).

## Unblocks

[`docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md`](../plans/2026-09-15-116-118-setjmp-cluster-g-demos.md)
— #116 `backtrack`'s corpus slice is now gate-PASS on all three modes. Remaining: wire #116's
`expected.tsv` row + `dev/backtrack.sh` driver + the visual/title-screen half
(`examples/snes/backtrack.c`), and build #117 `csrjmp` / #118 `retryjmp`, now that the runtime bug
they'd have hit identically is fixed.
