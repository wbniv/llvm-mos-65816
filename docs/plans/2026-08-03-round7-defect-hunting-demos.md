# Round 7 (#119–#138, addendum #139–#141) — new ROM tests aimed at bugs we haven't seen yet

**Date:** 2026-08-03 · **Status:** proposed · **Feeds:** the demo battery
([ideas doc](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md) gets the Round-7
section when implementation starts; per-demo plans follow the usual
`docs/plans/YYYY-MM-DD-<n>-snes-<slug>.md` pattern).

**No mockups:** this is a test-selection plan; each demo's visual gets mocked in its own per-demo
plan, per the established Round 1–6 practice.

**Natural-source publication invariant:** a demo intended to exercise a compiler construct must
retain that construct in the target source. Replacing it with precomputed offsets, assembly, or
another semantic workaround is not a passing demo. Contracted demos produce a pass receipt only
after their natural source compiles and all differential/emulator gates pass; publication verifies
that receipt against the exact ROM, source, and contract SHA-256 values. `farptrcmp` is the first
contracted demo and specifically requires a far-pointer array, far-pointer comparison, and
far-pointer subtraction. A compiler crash is a retained finding, not permission to bypass the test.

## Where the next bugs are (what the scoreboard actually says)

The [defect scoreboard](../investigations/2026-08-02-compiler-defects-found-by-demos.md) (17
defects) is not uniformly distributed across the corners the battery has swept. Reading it as a
targeting function:

1. **Combiner-formed opcodes with no legalizer rule** produced #46/`G_SCMP` (defect 17) — the
   compiler *invents* generic opcodes from C idioms nobody wrote directly, so C-level coverage
   maps say nothing about them. Any newer opcode the combiner can form is suspect until a demo
   forms it.
2. **Far pointers / `Imag32`** produced defects 1, 6, 13 — the richest single vein. Round 6's
   far cluster (F) was explicitly optional and only partially run.
3. **Machine-level mode state (`rep`/`sep`, flag liveness)** produced defects 4, 8, 12, 14 —
   and *nothing in six rounds has ever run an interrupt handler, an inline-asm island, or a
   mixed-width call boundary*, the three places where the M/X lattice meets code the pass can't
   see through.
4. **Legal-but-wrong MIR shapes are invisible to gates** (defects 3, 6) — so Round 7 pairs
   every machine-level demo with a **disasm gate**, not just the value differential.
5. ~~**Known gap, zero demos:** `MOSLegalizerInfo` marks the direct **s32→4×s8
   `G_UNMERGE_VALUES` as `unsupported`** — "no seed hit it yet" (agent-handoff, backend-nav
   section). A demo that forms it is a *guaranteed* finding.~~ **WITHDRAWN 2026-08-03 — the
   premise was already false when this plan was written.** `MOSLegalizerInfo.cpp:188` reads
   `.legalFor({{S16,S32},{S32,S64}}).customFor({{S8,S32},{S16,S64}})`; `{S8,S32}` dispatches to
   `legalizeUnmergeS32ToBytes`, which *is* the symmetric 2-level rule this item proposed writing.
   It landed in [`cbc31da`](https://github.com/wbniv/llvm-mos-65816/commit/cbc31da) (#320 Inc 3c),
   refined by [`2bfe4f3`](https://github.com/wbniv/llvm-mos-65816/commit/2bfe4f3), and is
   regression-gated hermetically by `dev/run.sh a16unmerge` (`examples/65816/a16unmerge.ll`,
   frozen Csmith seed-11 IR) since 2026-07-19 — all of it predating this plan. Far from
   untouched, it is one of the hottest custom rules in the backend: an instrumented sweep of all
   112 corpus slices measured **385 fires across 52 slices**. See the withdrawal of **#122** below.
6. Rounds 5–6 (value-level arithmetic corners) came back green — the value-level libcall space
   is near-exhausted. Round 7 therefore tilts **away from arithmetic novelty and toward ABI,
   memory-model, mode-state, and pointer-provenance novelty**.

## Untested-corner coverage map (the point of Round 7)

| New corner | Why a bug would hide there | Demos |
|---|---|---|
| Combiner-formed opcodes never legalized by a demo (`G_ABDS`/`G_ABDU`, s64 `G_CTPOP`/`G_CTLZ`/`G_CTTZ`, s64 `G_ABS`) | the `G_SCMP` mechanism, verbatim: no C in six rounds wrote the forming idiom | 119, 120, 121 |
| Direct s32→4×s8 unmerge (**known `unsupported`**) | explicitly declared a gap; nothing has ever formed it | 122 |
| Interrupt calling convention under `+mos-a16`/`+mos-xy16` | ISR prologue must save/restore M+X width, `Imag` ZP regs, and the flag state mid-`rep/sep` bracket — never executed | 123, 124 |
| Inline-asm islands inside a16 regions | `MOSInsertREPSEP` must treat asm opaquely; the assembler's magnitude-sized immediates (2026-08-02 trap) live here too | 125 |
| Per-function target features (mixed a16/default in one link) | mode contract at call boundaries between differently-featured functions — never attempted | 126 |
| Indirect branch into mode-varied blocks (computed-goto interpreter under a16) | the M/X lattice must merge conservatively at indirect-successor joins | 127 |
| Bank-crossing far arithmetic + 24-bit pointer compare/ptrdiff | 24-bit carry into the bank byte; `G_ICMP` on `addrspace(1)` values | 128, 129 |
| Far double-indirection (far fn-pointer stored in far data) | two dependent 24-bit fetches with DBR in play | 130 |
| Far-pointer spill pressure (re-stress `0018` past its fix shape) | `0018` fixed the *single-GPR split*; many simultaneous `Imag32` spills is the next shape out | 131 |
| Frames past the 8-bit stack-relative displacement (>256 B locals) | `sr,S` offsets are u8; frame-index arithmetic must materialize beyond it | 132 |
| Runtime `alloca` + over-alignment, buffer escaping to a far-writing callee | dynamic frame + provenance across address spaces | 133 |
| sret self-overlap (`s = f(s)` by-value round trip) | in-place aggregate return aliasing the argument | 134 |
| Volatile 16-bit access discipline under a16 | load-fold helpers (`foldableAbsLoad16` etc.) must refuse volatile; write-twice semantics | 135 |
| `_Atomic` RMW (with a live ISR) | either missing `__atomic_*` libcalls (link gap) or a non-atomic RMW an ISR can tear | 136 |
| float ↔ 64-bit int conversions (`__floatdisf`/`__floatundisf`/`__fixsfdi`/`__fixunssfdi`) | four libcalls no round has linked | 137 |
| s64 data-dependent shift counts at the limb seams (31/32/33) | R2 did s32 variable shifts; s64 runtime counts crossing the 32 boundary is the classic off-by-limb spot | 138 |
| IRQ-vector entry + envelope reentrancy (NMI preempting the IRQ handler) *(addendum)* | only the NMI vector has ever run a C handler; the envelope has never nested | 139 |
| BRK/COP software-interrupt entry *(addendum)* | `link.ld` wires BRK to the shared `irq` symbol and **COP to `$0000`** — a native `cop` executes WRAM as code today | 140 |
| D/DBR state at interrupt entry *(addendum)* | the envelope saves A/X/Y/P but neither DBR nor D; the contract for user asm that windows them is undefined | 141 |

## The twenty (+ the 2026-08-04 addendum, #139–#141)

### Cluster A — the `G_SCMP` playbook: form opcodes no demo has legalized

119. **Motion-Detect Difference Field (`absdiff`).** **DONE + PUBLISHED 2026-08-03 — clean positive, `0x3482`.** Per-cell `a > b ? a - b : b - a` on u8, s16,
     and u32 lanes between two animated fields — the exact idiom the combiner folds to
     `G_ABDU`/`G_ABDS`. If `MOSLegalizerInfo` has no rule, this aborts like #46 did; if it
     lowers, the branchless expansion gets its first differential. *Shows:* a motion-silhouette
     between two drifting patterns. *Differential:* CRC over the difference field, all widths.
     Host/default/a16/xy16 agree; the three separated visual bands are driven by the same kernels.
     No compiler defect. Published on both sites. [Per-demo record](2026-08-03-119-snes-absdiff.md).
120. **Bitboard Knight Tour (`bitboard64`).** **DONE + PUBLISHED 2026-08-03 — `0xC074`, two backend findings retained.** A 64-bit-bitboard move generator scored with
     `__builtin_popcountll` / `__builtin_clzll` / `__builtin_ctzll` — the s64
     `G_CTPOP`/`G_CTLZ`/`G_CTTZ` paths and their `__popcountdi2`/`__clzdi2`/`__ctzdi2` libcalls,
     none ever linked (the battery stops at `__ffssi2`). *Shows:* the knight's reachable-square
     board filling in. *Differential:* CRC over per-step popcount/scan results. The backend actually
     expands all three inline. Helper-isolated host/default/a16/xy16 passes both emulators; direct
     variable s64 one-hot construction fails s8->s64 legalization, while all three inline expansions
     in one pressured caller produce undefined `__rc` uses. Published with both findings recorded.
     [Per-demo record](2026-08-03-120-snes-bitboard64.md).
121. **Seismograph Absolute Trace (`llabs64`).** **DONE + PUBLISHED 2026-08-03 — clean positive,
     `0x8490`.** `llabs()` and the `x < 0 ? -x : x` s64 idiom on
     values straddling `INT64_MIN+1..` — s64 `G_ABS` (the battery covers `G_ABS` only ≤32-bit)
     plus the negate-carry chain across 4 limbs. *Shows:* a rectified waveform. *Differential:*
     exact s64 results folded to CRC, including the `INT64_MIN` edge left *out* (UB) and
     `INT64_MIN+1` kept in. The i64 absolute-value form passes the non-LTO machine verifier;
     host/default/a16/xy16 agree on MAME and bsnes-jg. [Per-demo record](2026-08-03-121-snes-llabs64.md).
122. ~~**Checksum Byte-Serializer (`unmerge32`).** ⭐ Forms the **direct s32→4×s8
     `G_UNMERGE_VALUES`** the legalizer marks `unsupported`.~~ **WITHDRAWN 2026-08-03 — not
     built.** Investigated instead of implemented, because the gap it targeted was closed and
     regression-tested months before this plan was authored (details in point 5 above). There was
     no abort to reproduce, no rule to write, and no stale comment in `vendor/` to correct — the
     stale text was *this plan entry*. Nothing was committed and the compiler is byte-identical
     to `main`.

     **Kept from the investigation — the measured trigger.** Instrumenting
     `legalizeUnmergeS32ToBytes` shows all 385 fires are `ndefs=4`, sourced from
     `G_MERGE_VALUES` (208), `G_SEXT` (145), `G_ZEXT` (32). The node forms when a **narrower
     value is sign/zero-extended to s32, passes through arithmetic, then is split into bytes** —
     never from an already-32-bit source, because the artifact combiner folds
     unmerge-of-load/constant/merge first (28 probe shapes across six optimization levels —
     four independent byte stores, `memcpy`/union punning, `__builtin_bswap32`, popcount/clz,
     a CRC-32 loop, `__mulsi3`/`__udivsi3`, float and s64 forms — fired **zero** times).
     Minimal shape that does fire, correctly `hasAccum16`-gated:

     ```c
     int32_t x = (int32_t)src16 * 2654435761u;   /* G_SEXT s16->s32, then arithmetic */
     uint32_t h = (uint32_t)x ^ ((uint32_t)x >> 15);
     s0=(uint8_t)h; s1=(uint8_t)(h>>8); s2=(uint8_t)(h>>16); s3=(uint8_t)(h>>24);
     ```

     *Caveat on the 385 count:* it comes from `errs()` instrumentation on a build since reverted.
     Reproducible by re-applying the two-line probe; not re-verifiable against the current binary.

     **Spun out as a follow-up:** the same sweep measured that `G_ADD`/`G_SUB` is
     `.legalFor({S8}).widenScalarToNextMultipleOf(0,8).custom()` with **no `maxScalar`**, so an
     s32 add narrows to **4×s8 `G_UADDE` lanes even under `+mos-a16`** (identical MIR with and
     without the feature); only the bitwise ops get s16 lanes, via
     `MaxBitwise = STI.hasAccum16() ? S16 : S8`. Whether that is a deliberate carry-chain
     decision or a missed 16-bit opportunity is **not** established — it is now its own TODO
     item, not a demo.

### Cluster B — mode state meets code the passes can't see through

123. **VBlank Interrupt Tally (`nmitally`).** First-ever `__attribute__((interrupt))` handler in
     the battery: an NMI ISR increments shared 16-bit/32-bit counters while the main loop runs
     `+mos-a16` arithmetic — the ISR prologue/epilogue must save/restore A/X/Y *width state* (M/X
     flags), the `Imag` ZP registers it touches, and re-establish its own assumed width. A
     one-frame-granularity handshake keeps the differential deterministic (main loop reads
     counters only at a fenced frame boundary). *Disasm gate:* ISR entry saves `$p` (or
     `rep`/`sep` re-establishment) + every Imag reg it defs. *Differential:* CRC over the tally
     after N frames, host oracle fed the same N.
124. **Mid-Bracket Interrupt Torture (`isrbracket`).** **DONE + PUBLISHED 2026-08-03 — clean
     positive after the #123 interrupt-envelope fix, `0x1014`.** The adversarial sibling of 123: main-loop
     code arranged so NMI statistically lands *inside* `rep`/`sep` brackets (long 16-bit
     sequences, no interrupt masking), across thousands of frames. Any ISR that returns with the
     wrong M/X width corrupts the main loop's next native op — a class no gate has ever been able
     to see. Host/default/a16/xy16 pass the 1,024-NMI gate on MAME and three repeated bsnes-jg
     runs per mode. *Differential:* long-run CRC; bsnes-jg 3× byte-identical is the flake screen.
     [Per-demo record](2026-08-03-124-snes-isrbracket.md).
125. **Inline-Asm Island (`asmisland`).** **DONE + PUBLISHED 2026-08-03 — clean positive, `0x260B`.** Inline-asm blocks (with clobber lists) embedded between
     native 16-bit ops: `MOSInsertREPSEP` must treat the island opaquely and re-establish width
     on exit; the register allocator must honour the clobbers against live `Imag16` values. Also
     the standing trap: asm immediates sized by magnitude, not M flag (`and #$00ff` → 2-byte
     assemble) — the demo's asm carries deliberately-ambiguous immediates written with explicit
     width suffixes, and the *disasm gate asserts the encoded operand widths*. *Differential:*
     CRC over values threaded through the islands. Raw bytes prove explicit A8/A16 immediates and
     machine code re-establishes M16 after `plp`; all four oracles agree. No compiler defect.
     Published on [biohack.net](https://biohack.net/snes/asmisland/) and
     [indri.studio](https://indri.studio/apps/llvm-mos-65816/snes/asmisland/).
     [Per-demo record](2026-08-03-125-snes-asmisland.md).
126. **Split-Personality Link (`mixedwidth`).** **DONE 2026-08-03 — clean positive, `0x83B7`.** One link mixing per-function target features —
     `__attribute__((target("mos-a16")))` functions called from default-8-bit code and back —
     the call-boundary mode contract (caller width vs callee expectation) that six rounds of
     whole-TU flags never once crossed. If the attribute is unsupported/ignored, that itself is
     the finding (diagnosed, not silent). *Disasm gate:* correct width establishment at each
     boundary. *Differential:* CRC across a call-ping-pong chain. The attribute is supported; IR
     and disassembly prove distinct feature sets and correct M16/A8 bodies. Host/default/a16/xy16
     agree; no compiler defect. [Per-demo record](2026-08-03-126-snes-mixedwidth.md).
127. **Threaded-Code Interpreter (`modethread`).** **DONE + PUBLISHED 2026-08-04 — clean positive,
     `0x0489`.** A computed-goto bytecode interpreter compiled
     `+mos-a16`/`+mos-xy16` whose handlers deliberately alternate 8-bit-byte and 16-bit-native
     bodies — every indirect branch is a join where the M/X lattice must merge all handler entry
     states conservatively. (Round 3's computed-goto ran default-8-bit only; the lattice never
     saw an indirect successor.) *Shows:* the interpreted program drawing. *Differential:* CRC
     over the interpreter's output tape. Indirect jump plus `rep`/`sep` are disassembly-gated;
     host/default/a16/xy16 agree on MAME and bsnes-jg.
     [Per-demo record](2026-08-04-127-snes-modethread.md).

### Cluster B addendum (2026-08-04) — ask the interrupt-entry contract *completely*

The #123 lesson, generalized: the width bug hid in a corner of `+mos-a16` that no program had
ever asked a question of. The remaining interrupt-entry corners with the same silent-failure
shape, grounded in the current tree: the envelope is attribute-scoped
(`isISR && hasW65816` in `MOSFrameLowering`), so it *should* cover every vector — but only NMI
has ever fired; `platforms/snes/link.ld:61-63` wires BRK to the shared `irq` symbol and **COP to
`$0000`**; crt0 states DBR := 0 explicitly but D = 0 only implicitly, and the envelope saves
neither. Three demos, one per corner. Suggested order: **#140 first** (it starts from a known
platform defect, not just a question), then #139, then #141.

139. **IRQ Gate (`irqgate`).** The first non-NMI hardware vector ever to run a C handler:
     override crt0's weak `irq: rti` stub with a real `__attribute__((interrupt))` handler driven
     by the PPU H/V timer IRQ (`$4207–$420A` counts, `$4200` NMITIMEN enable, `$4211` TIMEUP
     ack), with NMI simultaneously live — timer IRQs land mid-scanline inside main's a16
     brackets, and NMI can preempt the IRQ handler *inside its own envelope*, nesting it for the
     first time (fully stack-based, so it should be safe — never proven). Same armed/done
     handshake as #123 on both tallies. Asks: envelope emitted on the IRQ path, CLI/SEI
     discipline from C, MMIO ack from a C handler, envelope reentrancy. *Disasm gate:*
     `tools/nmitally-isr-gate.py --symbol irq` (reusable as-is) + exact-envelope head/tail on
     both handlers. *Differential:* CRC over both tallies at fenced stop counts.
140. **Software Vectors (`brkcop`).** **DONE 2026-08-04 — clean positive + platform fix,
     `0xA34C` (`304f3c3`); assembler gap (no `cop` mnemonic, operand-less `brk`) queued
     upstream. [Per-demo record](2026-08-04-140-snes-brkcop.md).** BRK and COP — the synchronous software interrupts. Today a
     native-mode `cop` jumps to `$0000` and executes WRAM as code (silent corruption, found by
     this audit, worse than a crash); `brk` lands in the shared `irq` handler with no way to
     distinguish. The demo splits the vectors: separate weak `brk`/`cop` C-handler symbols in
     crt0/link.ld (the platform fix is part of the demo), then executes `brk #$xx` / `cop #$xx`
     from inline asm inside `rep #$30` brackets. Native BRK/COP push PC+2, so RTI must resume
     past the signature byte — asserted by resuming into a poison-guarded instruction stream.
     Asks: vector-wiring contract, envelope under software entry with M=0/X=0 at the fault site,
     signature-byte skip. *Disasm gate:* envelope on both handlers + a link-map gate that no
     native vector slot reads `$0000`. *Differential:* CRC over handler tallies + resumed values.
141. **Bank/Direct-Page Windows (`dpbank`).** The D/DBR half of the entry contract. Nothing in
     generated code or the far runtime moves either register (verified: no `plb`/`tcd` outside
     crt0's boot sequence) — but user inline asm legally can (the #125 `asmisland` precedent),
     and the interrupt contract for such windows is *undefined*: the envelope re-establishes
     M/X but neither DBR nor D, so an NMI landing in a `phb … plb` window sends every absolute
     store in the C handler to the wrong bank, and a moved D misdirects every `__rc` access.
     Main opens long asm windows with DB≠0 and separately D≠0 while the NMI handler mutates
     absolute WRAM and `__rc`-heavy state. Like #123, the outcome is a design decision either
     way: extend the envelope (`phb`/`phd` + re-establishment, and extend
     `interrupt-width-65816.ll`), or document "interrupt-enabled code must not move D/DBR" as
     the platform contract and make this demo its loud gate. *Disasm gate:* presence (or
     documented absence) of `phb`/`phd` in the envelope — the recorded contract. *Differential:*
     CRC with repeated a16 landing-window runs as in #124.

### Cluster C — far pointers, third pass (the richest vein: defects 1, 6, 13)

128. **Bank-Boundary Walker (`bankwalk`).** **DONE + PUBLISHED 2026-08-04 — clean positive,
     `0x4ED7`.** A far array deliberately placed to straddle a 64K
     bank boundary, walked by pointer increment and by indexed offset across the seam — the
     24-bit `G_PTR_ADD` carry into the bank byte, both directions (`p++` and `p += big`).
     *Differential:* CRC over values read across the seam; host oracle models flat memory.
     Host/a16/xy16 agree on MAME and bsnes-jg. [Per-demo record](2026-08-04-128-snes-bankwalk.md).
129. **Pointer-Order Shuffle (`farptrcmp`).** Sorts/deduplicates an array *of far pointers* by
     pointer value and takes ptrdiffs between elements in different banks — `G_ICMP` on
     `addrspace(1)` (24-bit compare, three limbs) and 24-bit subtraction, neither ever formed.
     *Differential:* CRC over the sorted order + the diffs.
130. **Far Dispatch Matrix (`fardispatch`).** Function pointers *stored in far (bank-external)
     data*, loaded then called: two dependent 24-bit fetches, DBR vs program-bank interplay, and
     the `Imag32`-resident callee address surviving to the indirect call. (Extends the existing
     `far_fnptr` micro-shape into a full table-in-far-data dispatch under pressure.)
     *Differential:* CRC over dispatch results.
131. **Far-Spill Stress (`farspill`).** **DONE + PUBLISHED 2026-08-03 — clean positive, `0x7F3B`.** Re-stresses `0018` *past* its fixed shape: enough
     simultaneously-live far pointers (each derived, not rematerializable) to force multiple
     `Imag32` stack spills across `__mulsi3`-class clobbers — defect 6 was one spill through one
     GPR; this asks for many, interleaved. The standing `LDImm`-destination gate (defect 6's
     assert) is the tripwire. *Differential:* CRC; `-verify` clean is load-bearing here.
     Ten live pointers force seven four-byte slots (28 stores + 28 reloads); all LDImm destinations
     remain GPRs and host/a16/xy16 agree on both emulators. No new defect. Published on both sites.
     [Per-demo record](2026-08-03-131-snes-farspill.md).

### Cluster D — frames, allocas, and aggregate ABI edges

132. **Big-Frame Recursor (`bigframe`).** Locals >256 bytes (a 320-byte scratch table) so
     stack-relative displacements exceed the u8 `sr,S` field — frame-index lowering must
     materialize far offsets — plus recursion so the soft stack compounds it. *Differential:*
     CRC over results computed *through* the deep frame slots (first and last bytes of the table
     both live, so a wrapped displacement corrupts visibly).
133. **Aligned Arena Builder (`allocalign`).** `__builtin_alloca_with_align` with runtime sizes
     in a loop, the buffer passed to a callee that writes it via a far-qualified alias —
     dynamic-frame codegen × address-space provenance. (Round 3's `alloca`/VLA was
     fixed-alignment, near-only.) *Differential:* CRC over arena contents.
134. **Round-Trip Struct (`sretself`).** By-value aggregate round trips shaped `s = f(s)` where
     `f` returns a modified copy of its 24-byte parameter — the sret destination aliases the
     source argument's frame slot; a copy-elision or ordering slip silently corrupts fields.
     (Round 2's #26 passed and returned structs but never back into *themselves*.)
     *Differential:* field-wise CRC after a chain of round trips.

### Cluster E — memory model: volatile and atomics

135. **Volatile Discipline Probe (`volprobe`).** Volatile 16-bit and 32-bit accesses under
     `+mos-a16` through aliasing WRAM pointers, shaped to *tempt* every load-fold helper
     (`foldableAbsLoad16`/`foldableIndirLoad16`) and the late-opt peepholes: a fold or elision of
     any volatile access changes the observable sequence. *Disasm gate:* exact count of
     loads/stores to the probe addresses equals the source count. *Differential:* CRC over a
     journal each volatile read appends to.
136. **Atomic Counter vs ISR (`atomictear`).** `_Atomic uint16_t`/`uint32_t` with
     `atomic_fetch_add` in the main loop while 123's NMI handler also increments — on a
     single-core 65816 the compiler must either emit an interrupt-safe RMW (SEI/CLI bracket or
     single-instruction) or link `__atomic_*` libcalls that may not exist. Missing libcall =
     link-time finding; torn 32-bit RMW = long-run CRC divergence. *Differential:* final counter
     vs host model of exactly N increments per side.

### Cluster F — the last untouched libcall seams

137. **Starfield Epoch Clock (`float64conv`).** A 64-bit tick accumulator converted to `float`
     (and back) each frame for brightness math — `__floatdisf`, `__floatundisf`, `__fixsfdi`,
     `__fixunssfdi`, four soft-float↔s64 libcalls the battery has never linked (float↔s32 came in
     Round 2; s64 stopped at integer arithmetic). Values chosen around 2^24/2^31/2^32/2^53-analog
     rounding seams. *Differential:* bit-exact CRC over the conversion results.
138. **Limb-Seam Barrel (`shift64seam`).** **DONE + PUBLISHED 2026-08-03 — `0x2007`, runnable
     widened-count positive plus retained narrow-count defect.** s64 shifts by *data-dependent* counts swept through
     0–63 with the differential weighting counts 31/32/33 and 15/16/17 (the intra-/inter-limb
     seams for 16-bit lanes) — `__ashldi3`/`__lshrdi3`/`__ashrdi3` with runtime amounts, which
     Round 2 exercised only at s32. Sign-propagation at the seam for `ashr` is the classic
     miss. Host/default/a16/xy16 pass on MAME and bsnes-jg when the count is explicitly widened;
     the natural `uint8_t` count still fails legalization at `G_ANYEXT s8 -> s64` and its minimized
     repro is retained. *Shows:* a barrel-shifted texture. *Differential:* CRC over the full sweep.
     [Per-demo record](2026-08-03-138-snes-shift64seam.md).

## Visual-design pass (2026-08-03)

The first three implemented ROMs proved that a compiler probe needs its visual metaphor designed
before implementation, not added after the differential gate is already working. The remaining
ROMs therefore carry an implementation brief below. These are not decorative attract modes: the
animated state must be derived from the same values exercised by the probe, while the deterministic
CRC continues to be computed by a bounded host-equivalent kernel. A fault should disturb both the
gate and something a person can see.

Shared presentation bar:

- Use most of the 256x224 field; a title and CRC line alone do not count as a visual.
- Give the tested operation a stable spatial metaphor, animated continuously after the gate result
  is published. Avoid explaining an invisible test solely with labels.
- Map operand classes, banks, widths, or execution agents to persistent colors, and reserve a bright
  warning color for seams/collisions rather than using arbitrary rainbow animation.
- Build the visualization from probe results or a second invocation of the same kernel. Do not let
  unrelated eye candy become the only moving element.
- Keep the gate independent of frame timing. The visual may run forever; the oracle must still
  publish at a fixed step count.

| ROM | Implementation-ready visual brief |
|---|---|
| **119 `absdiff`** | A full-field motion detector: two dim drifting source patterns overlap while their absolute difference becomes a bright cyan/yellow silhouette. Three horizontal bands run the u8, s16, and u32 kernels from the same phase; identical geometry but distinct palettes makes width divergence immediately visible. A narrow bottom strip graphs the per-frame difference energy. |
| **120 `bitboard64`** | An 8x8 board fills most of the screen. The current knight flashes gold, reachable bits pulse cyan, visited bits settle blue, and the square selected by `ctz` gets a white cursor before the next move. `popcount`, `clz`, and `ctz` drive the visible reach count and edge markers, so a wrong libcall changes the tour rather than only the CRC. |
| **121 `llabs64`** | A dual-trace seismograph scrolls across the screen: the signed input crosses a central zero line in dim blue and its absolute value rises as a bright mirrored envelope. Vertical markers call out carry propagation across 16-bit limbs, with `INT64_MIN+1` rendered as the tallest legal spike. |
| **124 `isrbracket`** | A long A16 “mode tunnel” scrolls horizontally as alternating wide operation blocks. A vertical NMI needle repeatedly cuts through the tunnel at varying phases; correctly restored execution leaves an unbroken alignment rail behind it. Width corruption would kink or tear the rail, making the asynchronous failure spatially obvious. |
| **127 `modethread`** | Present the bytecode as a moving instruction tape feeding a handler arena. A8 handlers are narrow blue lanes, A16 handlers broad magenta lanes, and the indirect PC cursor jumps among them while the program draws a persistent geometric glyph below. Both the cursor path and glyph come from interpreter output. |
| **128 `bankwalk`** | A panoramic byte strip crosses a bright vertical 64K bank seam. Two walkers traverse it in opposite directions—incremental pointer and indexed offset—leaving sampled-value trails above and below. The bank byte changes the background hue at the seam; a missed carry visibly wraps a walker to the wrong side. |
| **129 `farptrcmp`** | Far pointers appear as address cards colored by bank. Each pass physically shuffles cards into 24-bit order, merges duplicates, then draws proportional distance bars between survivors. Bank ordering and ptrdiff are therefore readable without inspecting hex values. |
| **130 `fardispatch`** | A far-data dispatch grid acts like a switchboard. A bright packet travels first from the selected matrix cell to the far function-pointer table, then to a color-coded code bank; the called function stamps its distinct shape into an output mosaic. This visualizes both dependent far fetches and the eventual indirect call. |
| **131 `farspill`** | Multiple colored far-pointer ribbons enter a narrow register funnel. Excess live ribbons fold into visible stack “parking slots,” cross a multiply/clobber chamber, then re-emerge and reconnect to their derived targets. The final target mosaic is indexed by the recovered pointers, so a bad spill changes the picture. |
| **132 `bigframe`** | Recursion descends through nested frames drawn as inset rooms. Each room contains a 320-byte heat strip; the first and last cells flash together as the kernel touches offsets on both sides of the 256-byte boundary. The unwind leaves a colored checksum border per depth. |
| **133 `allocalign`** | Runtime allocations pack an arena as blocks with visible alignment gutters. Requested alignment controls each block's starting column, and the far-qualified callee sweeps a stripe pattern through it. Misalignment, overlap, or a bad escaped pointer becomes a broken packing diagram. |
| **134 `sretself`** | Render the 24-byte struct as a six-cell parcel circulating through transformation stations. Each by-value return rotates/recolors selected fields and places the returned parcel directly back into its source slot; a ghost outline shows the expected prior state, exposing self-overlap corruption. |
| **135 `volprobe`** | A logic-analyzer display shows separate volatile read and write buses. Every source-level access emits one pulse and appends a colored sample to a scrolling journal; sequence numbers advance visibly. The disassembly count gate and the on-screen pulse count describe the same access discipline. |
| **136 `atomictear`** | Mainline and NMI are two opposing increment streams feeding a shared odometer. Completed increments lock into paired colored teeth; the 16- and 32-bit counters occupy separate tracks. A torn RMW would split a tooth or make the odometer tracks disagree, while the correct run stays phase-locked. |
| **137 `float64conv`** | An epoch-driven starfield fills the screen. Four star classes use the four conversion directions; converted magnitude controls radius/brightness and the seam values form labeled orbital rings around 2^24, 2^31, and 2^32. Rounding changes become visible as a star crossing a quantization ring. |
| **138 `shift64seam`** | Feed a 64-bit striped texture through a cylindrical barrel shifter. The shift amount rotates the texture continuously, while bright tick marks emphasize 15/16/17 and 31/32/33; logical-left, logical-right, and arithmetic-right occupy three synchronized bands. Wrong limb transfer or sign fill breaks alignment at a marked seam. |

### #119 first-frame contract

`absdiff` is next. Its visual should reserve roughly 24 px for title/status, 168 px for three
52–56 px difference bands, and 24 px for the energy history. Each band receives the same two
phase-driven source functions but stores/evaluates them at its declared width. Use a slowly moving
hard-edged foreground shape over a lower-frequency background so subtraction errors make stable,
recognizable holes rather than noise. The source fields remain dim; only the computed difference is
high-contrast. The fixed-step gate folds all three bands, while the post-gate animation continues
from the same kernels with no effect on `corpus_result`.

## First picks (highest expected yield per unit effort)

*Re-ranked 2026-08-03 after #122 was withdrawn (see above); the list below is the live order.*

1. **#123 `nmitally`** — the interrupt CC has literally never executed; prologue width/Imag
   save-restore is a large, wholly untested surface.
2. **#126 `mixedwidth`** — per-function features is the kind of boundary nobody designed for;
   even "diagnosed as unsupported" is worth having on the record.
3. **#125 `asmisland`** — inline asm × `rep/sep` lattice, plus it institutionalizes the
   2026-08-02 immediate-sizing trap as a gated check.
4. **#119 `absdiff`** — the cheapest possible replay of the exact mechanism that produced
   defect 17.
5. **#131 `farspill`** — history says far-pointer pressure pays; `0018`'s standing assert makes
   any regression loud.
6. ~~**#122 `unmerge32`** — a *declared* gap; the only demo in seven rounds with a guaranteed
   finding on either outcome.~~ **Withdrawn — the gap was already closed and gated.**

**Lesson for future rounds:** #122's justification was taken from a comment in `agent-handoff.md`'s
backend-nav section rather than from the legalizer source, and the comment had gone stale. A
"known gap" claim is only worth a ⭐ if it is re-checked against `vendor/` **at selection time** —
one `grep` would have caught this before the round was written.

## The bar (unchanged)

Every demo meets the Round 1–6 bar: shared host+target logic header (`<stdint.h>` widths), CRC
differential **host == default == `+mos-a16` == `+mos-xy16` @ bsnes-jg** (MAME legs as bonus,
per the demos-only relaxation), `-verify-machineinstrs` clean, bsnes-jg 3× byte-identical,
`snesgfx` on-screen render, published via `/snes-rom-page`. Cluster B/E demos additionally carry
**disasm gates** (mode-state and access-count assertions) because their failure class is
legal-MIR-wrong-machine-code — the class the scoreboard says value gates miss. Interrupt demos
(123/124/136) need a determinism design review in their per-demo plans before implementation:
the differential requires the ISR/main interleaving to be frame-fenced or the oracle to be
interleaving-independent (sum-preserving), and bsnes-jg 3× identical is the arbiter.

Implementation order: first picks above, then remaining clusters A→F; each demo gets its own
per-demo plan + `/snes-demo` run as usual.
