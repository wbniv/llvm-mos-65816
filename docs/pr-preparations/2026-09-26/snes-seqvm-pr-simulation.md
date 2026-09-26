# Simulated upstream PR — Preserve undefined Imag16 lane identity

**Internal only; do not submit yet.** The [SeqVM ROM](https://biohack.net/snes/seqvm/) exposed an undefined Imag16 high lane reaching a store after register allocation.

## Proposed PR body

Preserve the required lane definition through register allocation or make the later use reject an undefined lane. The [focused record](../../upstream-rc-undef-ra-pure-virtual-issue.md) retains the original diagnosis and its limits.

## Acceptance before submission

Reconcile the responsible generic register-allocation path, preserved reproducer, and exact upstream revision; then run the standalone and SeqVM gates. This is a simulated PR, not a claim that its destination is ready.
