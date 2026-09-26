# Independent review of the 0060 upstream-guard backport

September 26, 2026. **Approve the exact MOS backport and companion regression.**
Final current-MOS compilation and full reducer-suite validation remain owned by
the coordinator. This review performed no compiler build, patch modification,
posting, push, or shared-source edit.

Reviewed packet: [0060-llvm-mos.patch](0060-llvm-mos.patch), SHA-256
`a62ebcdbdd7059d85c638e20c9bff8efaed808e9df5c35c4d2d6c93b3be04601`.

## Prior work and submission identity

This is a backport of existing LLVM commit
[`b1ba3d515a0238adbfc6c349ed3b33f9060cea72`](https://github.com/llvm/llvm-project/commit/b1ba3d515a0238adbfc6c349ed3b33f9060cea72),
not a new upstream repair or a parallel-MIR implementation. The retained
[upstream commit metadata](0060-upstream-guard.json) dates it September 24,
before the local September 25 report, and contains the full four-file patch.
The audit script compares all four hunk payloads exactly with that metadata;
they match. The only additional file is the valid-MIR companion test.

Read current LLVM source at `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`: it already
contains the guard, accessor, and original rejection test. Read MOS main at
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`: the guard and accessor are absent.
Thus LLVM needs no duplicate submission; MOS is the backport destination.
The existing [canonical defect](../../defects/llvm-reduce-parallel-mir-crash.json)
and [ownership review](reducer-feature-review.md) remain the records for the
earlier crash and local parallel-clone candidate. Their immutable evidence is
not replaced by the guard's deliberate error result.

## Source and regression assessment

The guard runs after explicit `-x` / filename-based MIR-mode selection and the
required-argument checks, but before input parsing, interestingness execution,
or worker creation. `getNumChunkProcessingJobs()` returns the existing option
value, including the fixed serial value in a thread-disabled build. The delta
runner's parallel paths already require `NumJobs > 1`, so the guard rejects
exactly the unsupported MIR combination. IR reduction and serial MIR behavior
are unchanged. The result is an explicit diagnostic and exit 1, **not** a silent
fallback to serial reduction and not successful parallel MIR support.

The original two upstream RUNs cover inferred and explicit MIR mode. The
companion adds a valid X86 machine function with real def/use relationships,
first verifies it, proves serial instruction reduction retains `MOV32ri 2`
and the return, checks rejection for inferred `-j 2` and explicit `-j 4`, and
checks the existing `operands-skip.ll` IR reduction with two workers. Its
`thread_support` / `x86-registered-target` requirements match those operations.
Comments describe the transport limitation and present supported behavior.
No ownership or concurrent-context assertion from the earlier local candidate
is needed by this backport.

## Independent test replay

Ran `python3 build/post-ready-review-mos/0060/audit.py` using the coordinator's
preserved **LLVM baseline** snapshots under
`build/post-ready-validation-llvm/0060/baseline-bin/`. All **nine exact packet
RUNs pass**: two original rejection RUNs and seven companion RUNs. This LLVM
baseline already contains the upstream guard; these results validate the test
packet and supported/rejected behavior, not a fresh MOS candidate build.

An initial manual RUN replay did not resolve `--test FileCheck` to its absolute
executable path and failed with `posix_spawn failed: No such file or directory`.
Its output remains under `build/post-ready-review-mos/0060/run/`. The successful
replay uses lit-equivalent absolute FileCheck substitution and a separate
`run-resolved/` directory. The first attempt is a harness-resolution failure,
not an invalid MIR input or causal compiler baseline.

The successful receipt retains exact commands, input hashes, tool hashes,
return codes, and log hashes:

```text
857b5b41f3488f12135bb89a1cc34d9f0c25f8def0d84186833e71469deabfde  LLVM baseline llvm-reduce
93b6a35c447f85042c65830e1daea85e0f6103c1fb380c3df78cec658009c81c  LLVM baseline llc
df30e3ec3f104e1b11041cfeb6bd07b39bdb81c4094fde46e29c9d64365317d0  0060-upstream-guard.json
5f9c754a4676dd53e91a896708cd0848fd33b63bef4a858f2c7dda5ce493e2ad  build/post-ready-review-mos/0060/run-resolved/receipt.json
```

Independent review, comparison script, and test replays: OpenAI Codex CLI
0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort;
verified agent/session `/root/review_mos` /
`01a0db96-e0ef-75e2-89ad-2939c4954446`. Upstream authorship and earlier local
credits remain in their original linked records; this is not an authorship
claim for the guard.
