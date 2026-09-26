# Computed-carry scheduling PR packet

This publication contains the standalone 0064 preparation:

- [PR body](0064-pr-body.md).
- [Standalone upstream patch](0064-llvm-mos.patch).
- [Destination and profitability review](0064-review.md).
- [Validation and retained evidence](0064-validation.md).

Compiler commit `155e209c4cee` is based on llvm-mos main `7bd67c0ae4e8` and
is [pushed to the fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling). No PR has been opened.
The exact patch passes ten focused commands, 132 MOS tests (one unsupported),
and 512 Python-oracle runtime vectors per build. The targeted MIR kernel
shrinks 133 → 59 bytes; 117 ordinary-MOS corpus comparisons are unchanged.
Downstream size losses remain documented. Author review is complete; no
independent review, cycle-speed or compiler-overhead claim is made.

This repository’s `carry-scheduling-preparation` branch publishes the downstream
0064 patch, plan, evidence and dependency updates. It starts from `b3938bda`
and preserves other work in the shared checkout. The other local posting
packets remain outside this commit.

Preparation and publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
