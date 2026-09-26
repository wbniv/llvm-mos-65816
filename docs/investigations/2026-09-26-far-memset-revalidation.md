# Far memset: the original wrong-bank trigger is repaired by existing patch 0013

The 4096-byte fill at `$7E2000` is **fixed by existing patch 0013**, introduced
with the far runtime in commit `a81874d89ffaac1c34b06cbb8539db9e4785c41b` on
June 26. This revalidation adds evidence and regression coverage; it changes no
executable compiler or runtime code. The [structured record](../defects/mos-far-memset-wrong-bank.json)
defines the closure scope.

The motivating published demo is [Blossom](https://biohack.net/blossom), as
linked by its [polish record](../plans/2026-09-14-blossom-polish.md). This work
does not change or make new validation claims about the deployed ROM.

## Causal comparison

The [exact June C source](../defects/evidence/2026-09-26-far-memset/june-original.c.txt)
is recovered from `c75750e9`, including its discovery comments. The initially
captured `original.c.txt` is the later fixture: commit `903de3e5` adds `wai` to
its final idle loop. Both versions have matching-input red/green checks, with
the June version used for the canonical closure. Fresh preprocessing and
optimization produce [the shared LLVM IR](../defects/evidence/2026-09-26-far-memset/june-c-entry/input.ll):
`llvm.memset.p2.i32` writes 4096 bytes of `0x42` at `$7E2000`. Its length exceeds
the backend's inline limit. Both compilers receive that exact IR and identical
options, and their MIR before legalization is byte-identical.

The reconstructed baseline differs from the captured current compiler only by
removing patch 0013 from `MOSLegalizerInfo.cpp`, recompiling that object, and
relinking `llc` with the other existing libraries. Reapplying the patch reproduces
the current source byte-for-byte. The original June compiler has not been
recovered; this comparison is explicitly a reconstruction of the backend
mechanism on the current fork.

| Same input, `-Os` frontend / `llc -O2`, a16 | Without 0013 | With 0013 |
|---|---|---|
| Fill's runtime relocation | `__memset` | `__memset_far` |
| Target checksum | `0x0000` | `0x2000` |
| Physical `$7E2000..$7E2FFF` | All 4096 bytes differ from `0x42` | All 4096 bytes equal `0x42` |
| Regression runner | Fails | Passes |

The [baseline log](../defects/evidence/2026-09-26-far-memset/june-baseline/run.log)
and [candidate log](../defects/evidence/2026-09-26-far-memset/june-candidate/run.log)
retain complete commands and diagnostics. Both compilations pass the machine
verifier; only the baseline runtime and routing checks fail. bsnes-jg runs for
300 frames with deterministic power-on entropy (`JGX_ENTROPY=0`). Its physical
WRAM dump is checked byte-for-byte independently of compiled far loads; a sum
alone could have collisions.

The generic memory-libcall path passes the far pointer through the far ABI but
names the near routine, whose destination parameter has only 16 bits. Patch
0013 intercepts the non-inlined far operation and uses the far runtime ABI,
retaining the bank byte. It also coerces this 4096-byte length to the runtime's
16-bit `size_t`. This is a backend repair: both sides still contain the same
far intrinsic and `G_MEMSET`, so frontend optimization does not conceal it.

This record covers the original fill and its near/far runtime-routing contract.
It does not certify every memcpy/memmove combination or lengths above 65535.
The [June implementation plan](../plans/2026-06-26-fix-the-far-addrspace-2-memset-memcpy-memmove-sile.md)
retains its separate, broader historical tests.

## Retention and regression coverage

[Tool identities and reconstruction commands](../defects/evidence/2026-09-26-far-memset/identity.json)
identify vendor pin `8be0546128a55e78c63ca571d466aa72a782cd36`, the dirty source
diff, all patch hashes, SDK contents, resource headers, and compiler binaries.
Preserve `build/defect-baselines/2026-09-26-far-memset/`: it contains both `llc`
binaries, clang/lld, the SDK and emulator, and the compiler reconstruction files.
The compiler reconstruction ran in local Docker image `llvm-mos-65816-dev`;
runtime checks ran on the host. The build is Release, assertions disabled, with
`-verify-machineinstrs` enabled in the regression commands.

The new [runner](../../dev/check-far-memset.py) verifies the C entry point,
presence of the intrinsic, backend routing, target checksum, and all physical
bytes. The four non-LTO configurations (`-Os`/`-O2`, a16/xy16) pass. The retained
baseline and candidate use the same SDK and linker, with only the tested backend
object differing. The installed SDK's far runtime is tested as shipped; it is
not rebuilt in this investigation.

The [focused IR test](../defects/evidence/2026-09-26-far-memset/far-memset.ll)
checks constant and variable far fills plus a near fill. It fails its far checks
without 0013 and passes with it in both native modes. It is carried in patch
0013, and `dev/toolchain.sh` imports that test separately because the compiler
implementation is already folded into 0002. The patch reverses/reapplies exactly,
the test-only import works, and all existing `far-*.ll` inputs compile with
machine verification. [Validation commands](../defects/evidence/2026-09-26-far-memset/validation.json).

Run a fresh current-build check with an unused output directory:

```sh
python3 dev/check-far-memset.py --output /tmp/far-memset-replay
```

Replay the causal pair by passing the retained `june-c-entry/input.ll`, either archived
`bin/llc-without-0013` or `bin/llc`, and the archived clang/SDK/emulator options
shown in the two logs. No upstream submission or new platform deployment is
part of this work. The far compiler/ABI and SDK prerequisites still apply.

## Why the old report still looked open

The [discovery report](../320-far-memset-miscompile.md) was committed in
`c75750e9` on June 26 and had no later edit before this investigation. The repair
and passing results were recorded the same day in `a81874d`, the implementation
plan, and the contribution tracker. The original report continued to say that
the backend fix had not been attempted. Its source comments repeated that status
and advertised a nonexistent `dev/run.sh far_memset` gate.

The implementation plan directed results to another filename,
`docs/plans/2026-06-26-321-far-memset-miscompile.md`, which does not exist here.
References to the discovery report were mainly code-formatted paths rather than
links, so the dependency inventory did not connect those statements to the
report. The two-tier patch layout adds another lookup step: 0013 remains a
standalone artifact while its implementation is also present in 0002.

These facts explain this stale status. They do not demonstrate that every older
report has the same cause. In particular, a passing input by itself cannot close
another report: the recovered inline-bitboard case needed a causal comparison
with 0028, and the separate Imag8-only diagnosis was disproved by its matcher
contract. For this report, the current status now links to a structured record,
the historical text is explicitly dated, and the current report is registered as
a maintained summary of that record. Earlier summary receipts are retained in
[the prior manifest](../defects/evidence/2026-09-26-far-memset/prior-dependencies.json).

Investigation, reconstruction, tests, and documentation: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified from session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. The
[historical commit](../defects/evidence/2026-09-26-far-memset/historical-commit.txt)
preserves its original Claude Opus 4.8 (1M context) credit verbatim. Its tool
version, exact model ID, and reasoning effort are unknown from that commit;
this investigation does not infer them.
