# 65816: near-global absolute access stays 16-bit (suppress the abs→long bank-relaxation)

**Branch/worktree:** `wt/320-near-abs-bank-relax` (`/home/will/SRC/llvm-mos-65816-near-abs`), off `main`.
**Patch:** [`patches/llvm-mos/0007-65816-near-abs-bank-relax.patch`](../../patches/llvm-mos/0007-65816-near-abs-bank-relax.patch)
(regen: [`dev/regen-patch-0007.sh`](../../dev/regen-patch-0007.sh)).
**Origin:** this is the realization of **Task B** of
[`2026-06-21-320-packed24-productionization-handoff.md`](2026-06-21-320-packed24-productionization-handoff.md)
("fix the byte-2 absolute-long access cost"). Investigation showed the cost is **not** packed-24-specific —
it is a general 65816 assembler issue — so it lands as its own stacked patch (`0007`), independent of the
packed-24 patch (`0006`). (A *different* agent is separately landing a static-init p3 relocation fix in
`0006`; that is unrelated to this.)

## The bug (measured, not assumed)

A plain-symbol **absolute** access to a **near (bank-0)** global, when the value is in the **A register**,
was emitted as the 4-byte **absolute-LONG** form (`8f`/`af`/`6f`/… , `R_MOS_ADDR24`) instead of the 3-byte
**absolute** form (`8d`/`ad`/`6d`/…, `R_MOS_ADDR16`). It bloats by **1 byte per access**.

Reproduction (a plain near global, nothing exotic), BEFORE the fix:
```
store_x:  8f 00 00 00   sta  x        (R_MOS_ADDR24 / long)   <- 1 byte wasted; x is a NEAR global
load_x:   af 00 00 00   lda  x        (R_MOS_ADDR24 / long)   <- same
```
…confirmed to survive into the **linked ROM** (not just the `.o`): the linker fills the bank byte ($00) but
does **not** shrink long→abs (lld has no MOS `relaxOnce`). X/Y escape only because `STX`/`STY`/`LDX`/`LDY`
have **no** absolute-long form to relax to (so a 3-byte packed pointer's bytes 0/1 were already abs; only
its A-register byte 2 bloated — the original Task-B symptom). ~284 such A-register long sites across the
`examples/65816/a16*.c` corpus alone.

### Root cause

`MOSAsmBackend::fixupNeedsRelaxationAdvanced` decides instruction size via a single criterion —
zero-page vs not — and applies it to **both** relaxation steps: zero-page→absolute **and**
absolute→absolute-long ("bank relaxation"). For a near, non-zero-page symbol it therefore relaxes all the
way to long, even though 16-bit absolute suffices. There is no near-vs-far discrimination on the bank step.

### Why suppressing it is correct (and conservative)

- The compiler emits the **explicit** long form (`LDA/STA AbsoluteLong`, via `G_LOAD_FAR_ABS` /
  `address_space(2)` / `.far_*` data) whenever it genuinely wants a far access. So a plain-symbol *Absolute*
  reaching the bank relaxation is, by construction, an intended **near** access.
- Near data is bank-0 and accessed DBR-relative with **DBR=0** (the crt0 contract). The existing `STX`/`STY`
  near abs-stores **already** depend on exactly this invariant — so making the A-register path also abs adds
  **no new** correctness assumption; it removes an asymmetry.
- The fix only suppresses the abs→long step for **near (non-`.far`) sections**. Banked `.far*` sections still
  relax to long (e.g. a hand-written `lda farsym`), and an unknown/non-ELF section already returns
  "relax" → so a misclassification can only ever **miss the size win, never emit a wrong-bank access**
  (lesson #2).

The fix: in the section-based tail of `fixupNeedsRelaxationAdvanced`, add
`if (BankRelax && !Sec->getName().starts_with(".far")) return false;`.

## Blast radius

65816 only (`FeatureW65816` gates the ZBIRE bank-relaxation; 6502 has no long form → byte-identical).
Affects **default-65816 and `+mos-a16`** alike: every plain-symbol A-register near-global access shrinks
long→abs — `sta`/`lda` byte accesses **and** the native-s16 ALU absolute ops (`adc`/`sbc`/`and`/`ora`/`eor`/
`lda` abs16) reading near globals. This is a strict size reduction, ~1 byte each, amplified across every
65816 program (lesson #3). It is **not** byte-identical to pre-fix default-65816 codegen (it is smaller),
which is why the verification below leans on the differential (values unchanged), not byte-identity.

## Verification (run in the `wt/320-packed24-incB` toolchain, which carried this fix; 2026-06-22)

> The fix was built + verified in the `wt/320-packed24-incB` compiler worktree (own vendor + warm build),
> then extracted to this lightweight worktree as the round-trip-verified `0007` patch. Re-running the full
> both-emulators gate in a fresh compiler worktree is the optional belt-and-suspenders step; the evidence
> below already establishes correctness (the differential is value-based, and abs/long read the same byte).

### 1. The fix does what it says (disasm), and far is preserved

```
set_g  byte2:  c: 8d 00 00     sta  g+2     (abs, R_MOS_ADDR16)   was 8f .. long  -> -1 B
deref_g byte2: 6: ad 00 00     lda  g+2     (abs, R_MOS_ADDR16)   was af .. long  -> -1 B
store_x:       0: 8d 00 00     sta  x       (abs)                 was 8f .. long  -> -1 B
load_fc (.far_rodata, AS_Far): 0: af 00 00 00  lda fc  (R_MOS_ADDR24 / long)  -> FAR STAYS LONG ✓
```
PASS — near → abs; far (`.far_rodata` / `address_space(2)`) still long.

### 2. Differential gate (correctness — the real bar for a shared-codegen change)

```
==> corpus: 7/7 passed
RESULT: PASS — packed-24 far ptr (3-byte store/load, bank $01) ... == 0xF3   (MAME + bsnes-jg)
FAR suite: far / far-bank1 / far_cast / far_arith / far_store / far_call / far_indir — all RESULT: PASS
==> csmith: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)     [fuzz 50 1]
==> csmith: 91/100 PASS, 0 xfail, 9 skip (0 mismatch, 0 crash, 0 error)     [fuzz 100 51]
```
PASS — host == default-65816 == `+mos-a16` (the fuzzer compiles each program *both* default-65816 and a16
and compares to the host oracle; 0 mismatch ⇒ the long→abs change preserves values in both builds). The
far suite proves genuine far accesses still use long and read the right bank.

### 3. a16 micro-test suite (the targeted regression guard — these hammer near-global ALU reads)

51 PASS; 6 `disasm-gate` "failures" (`a16bitchain`, `a16chainimm`, `a16chainld`, `a16localx`, `a16mixfold`,
`a16sunfold`) — **expected**: those gates hard-coded the **long** opcodes (`2f`/`6f`/`af`/…) that this fix
shortens to **abs** (`2d`/`6d`/`ad`/…). The *intent* ("native ALU reads the global directly, not via an
Imag16 round-trip") is unchanged, and the computed values are identical. Fixed by making each gate match
**both** forms (`Xf` → `X[df]`; awk equivalents), confirmed host-side per-test:

```
a16bitchain  and 2d=2 ora 0d=2 eor 4d=2  sta-zp=1            -> >=2/2/2, <=4   PASS
a16chainimm  adc 6d=4  adc#imm=2  sta-zp=1                   -> >=4, >=2, <=3  PASS
a16chainld   adc 6d=3  sta-zp=0                              -> >=3, <=1       PASS
a16localx    adc-zp 65=3 + adc-abs 6d=2 = 5                  -> >=4            PASS
a16mixfold   lda-abs ad=5  abs-ALU(6d/ed)=2  mat=1  direct=6 -> mat==1, >=6   PASS
a16sunfold   lda-abs ad=3  abs-ALU=6  mat=0  direct=9        -> mat==0,>=3,>=6 PASS
```
PASS — `X[df]` is a superset of `Xf`, so the gates remain correct with or without this fix.

### 4. Realized size win (Task A context, for reference — Task A itself is owned by the other agent)

A realistic far-pointer **table walked at runtime** in a 16-bit-ambient loop (16 entries),
`AS_Far` (4-byte elements) vs `AS_FarPacked` (3-byte): table storage **64→48 B (−16)**, access code
**98→93 B (−5)** — packed wins on **both** axes (the loop strength-reduces to a running pointer, so the
×3 vs ×4 stride is a free `adc #N`; packed loads 3 bytes/element vs 4). Net **−21 B at N=16, no break-even**.
This near-abs fix additionally trims the direct packed-pointer access pattern (store/load a packed slot at a
fixed address: byte-2 `8f/af` → `8d/ad`, −2 B).

## Files
- `vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSAsmBackend.cpp` — the one-hunk fix → `0007`.
- `dev/regen-patch-0007.sh` — regenerate + round-trip-verify `0007` (RESULT: PASS, 1 file, 28 lines).
- `dev/a16{bitchain,chainimm,chainld,localx,mixfold,sunfold}.sh` — disasm gates made relaxation-form-tolerant.

## Status
Fix DONE + verified. Landed as `0007` on `wt/320-near-abs-bank-relax`. **Not pushed** (coordinate — `0007`
stacks after the other agent's in-flight `0006` static-init work; the two are independent files).

### Optional follow-ups
- Belt-and-suspenders: re-run the full both-emulators gate in a fresh compiler worktree with 0001–0007.
- Upstreamable: this is a generic llvm-mos 65816 size fix (independent of #320/#321) — candidate for the
  upstream-contribution queue.
