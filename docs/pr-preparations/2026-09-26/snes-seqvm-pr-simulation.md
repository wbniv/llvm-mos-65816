# Internal PR simulation — SeqVM undefined Imag16 lane

**Status: not ready to submit.** The [SeqVM ROM](https://biohack.net/snes/seqvm/) exposed an undefined Imag16 high lane reaching a store after register allocation.

## Proposed change

Preserve the required lane definition through register allocation or make the later use reject an undefined lane. The [focused record](../../upstream-rc-undef-ra-pure-virtual-issue.md) retains the original diagnosis and its limits.

## Submission gate

Reconcile the responsible generic register-allocation path, preserved reproducer, and exact upstream revision before preparing an upstream PR.
