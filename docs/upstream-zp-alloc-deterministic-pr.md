# [MOS] Make zero page allocation deterministic (pointer-hash iteration order decided the winners)

<!-- DRAFT 2026-08-01 — NOT POSTED. Provenance: the lzss-gallery non-reproducible-build
     investigation, docs/plans/2026-08-01-gallery-nonreproducible-build.md (throwaway branch
     throwaway/gallery-repro-bisect, worktree /home/will/llvm-mos-65816-gallery-repro).
     Fork patch: patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch.
     BLOCKED BEFORE POSTING: the fix is authored and applies cleanly both ways, but the
     toolchain rebuild + post-fix measurement (dev/measure-gallery-repro.sh tie/rom, MOS lit
     suite) has NOT been run — the build was denied by the sandbox permission classifier.
     Do not post until the Verification section carries real numbers. -->

## Summary

`llvm-mos` does not build reproducibly when `-mlto-zp` is in effect. The same source,
the same compiler, and byte-identical LTO IR produce one of several different binaries,
because `MOSZeroPageAlloc` decides which globals get zero-page storage in an order derived
from **heap addresses**.

`collectCandidates` accumulates each global's benefit in a `DenseMap` keyed by
`GlobalVariable *`, then iterates that map to build the candidate list:

```cpp
  DenseMap<GlobalVariable *, float> GlobalBenefit;
  ...
  for (const auto &KV : GlobalBenefit) {
    ...
    LocalCandidates.push_back(LocalCandidate{Cand, Benefit});
  }
```

`DenseMapInfo<T *>` hashes the pointer value, so that iteration is in address order. The
only ordering applied afterwards is a `stable_sort` on benefit:

```cpp
    stable_sort(EG.Candidates,
                [](const EntryCandidate &A, const EntryCandidate &B) {
                  return A.Benefit > B.Benefit;
                });
```

which by definition leaves equal-benefit candidates in their insertion order — i.e. in
address order. When the zero page fills, whichever tied candidate happened to be visited
first takes the last free byte. Every reference to the loser stays a 3-byte absolute
access instead of a 2-byte zero-page one, the enclosing function changes size, and
everything laid out after it shifts.

## Reproduction

Eight one-byte globals, each stored exactly once from the same basic block, so every
benefit is exactly `2 * 1.0 / 1`; room in the zero page for four of them:

```llvm
target triple = "mos"
@g0 = global i8 undef, align 1
; ... g1 .. g7 ...
define void @main() {
entry:
  store volatile i8 1, ptr @g0, align 1
  ; ... eight stores, g0 .. g7 ...
  ret void
}
```

```console
$ for i in $(seq 20); do
    llc -mtriple=mos -zp-avail=4 zptie.ll -o - | sed -n 's/.*stx\tmos8(\(g[0-7]\)).*/\1/p' | tr '\n' ' '; echo
  done | sort | uniq -c
      6 g1 g5 g6 g7
      6 g1 g2 g3 g4
      2 g2 g3 g4 g6
      2 g0 g2 g3 g4
      2 g0 g1 g6 g7
      2 g0 g1 g5 g7
```

Six different answers from one single-threaded `llc` process on one input file. It is not
threading (`llc` is single-threaded here; `lld --threads=1` behaves the same) and it is
not the input: under `setarch -R`, with the input file path held fixed, the same command
returns one answer 10 times out of 10.

At whole-program scale it is a reproducible-build defect rather than a curiosity. Linking
a 1 MiB SNES ROM 30 times from identical sources gave two distinct images, 18/12; the LTO
IR entering codegen (`--save-temps`, all four `*.bc` stages) was byte-identical across all
30. The entire delta was one 1-byte global swapping in and out of `.zp.bss`, worth ±2 bytes
in one function — and, downstream of that, a +2 byte shift in 1476 of 2291 linked symbols.

Note that `setarch -R` alone does *not* hide the problem end-to-end, which is what made this
look like something other than an address-order effect at first: the clang driver hands lld a
randomly named temp object (`/tmp/foo-XXXXXX.o`), and that is enough to move the allocations
around. Feeding `ld.lld` a randomly named copy of a byte-identical input, with ASLR off,
restores the 50/50 split.

## Fix

Three containers in `MOSZeroPageAlloc.cpp` are iterated in an address-derived order and
each feeds the allocation decision. All three become order-preserving equivalents; no
heuristic changes.

1. **`GlobalBenefit`** — `DenseMap` → `MapVector`. This is the one demonstrated above:
   candidate collection order *is* the tie-break, and `MapVector` iterates in insertion
   order, which is the deterministic `MachineInstr` walk order.

2. **`CalleeFreqs`** (`buildEntryGraphs`) — `DenseMap` → `MapVector`. Its iteration order
   is the order of `float +=` accumulation into `EntryFreqs`. Floating-point addition is
   not associative, so an address-ordered walk perturbs every derived benefit in its last
   ULP; that breaks *near*-ties as well as exact ones, and near-ties are the common case in
   real code.

3. **`SCCCallees`** (`buildSCCGraph`) — `SmallSet<const CallGraphNode *, 4>` →
   `SmallSetVector`. `SmallSet` degrades to `std::set<T, std::less<T>>` past its inline
   capacity, i.e. it orders by pointer value. `SCC::Callees` seeds the `EntryGraph` list,
   and entry graphs are served zero page **round-robin**, so an address-ordered callee list
   changes which entry point gets served first — and therefore who wins.

Everything else in the pass that is keyed by a pointer (`SCCIdx`, `GVCandidates`,
`FunctionSCCs`, `MFZPSizes`, `NextOffsets`, the two `DenseSet<Register>`s) is used only for
lookup or membership and is never iterated, so it is left alone.

Alternatives considered: sorting the candidate list by global name instead of by collection
order would also be deterministic, but it changes the heuristic (name order is not related
to access frequency or locality) and would need every tie-break site fixed separately.
Making `stable_sort` a total order by adding a name tiebreaker fixes only (1) and leaves the
float-accumulation and round-robin paths address-ordered.

## Tests

`llvm/test/CodeGen/MOS/zp-alloc-deterministic.ll` — the eight-tied-globals module above,
`-zp-avail=4`, with `FileCheck` pinning the winners to the first four in module order (the
insertion-order answer) via their `mos8()` operands and `.zp.noinit` placement.

Nondeterminism is awkward to test directly; this pins the now-deterministic output instead,
which is a sound proxy because the correct answer is a specific one of the eight-choose-four
possibilities. Red/green measured on the unfixed compiler: **0 pass / 20 fail out of 20
runs** — the address-ordered result never coincided with insertion order in that sample.

## Real-world sighting

Found while chasing why a 62-work SNES LZSS gallery ROM
([playable here](https://biohack.net/snes/lzss-gallery/)) hashed to one of two values from
identical sources, which was intermittently tripping a byte-identity guard in our release
tooling. The `-zp-avail=4` case above is the minimal upstream-only formulation and needs
none of that context.
