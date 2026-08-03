# Round 7 (#119–#138) — twenty new ROM tests aimed at bugs we haven't seen yet

**Date:** 2026-08-03 · **Status:** proposed · **Feeds:** the demo battery
([ideas doc](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md) gets the Round-7
section when implementation starts; per-demo plans follow the usual
`docs/plans/YYYY-MM-DD-<n>-snes-<slug>.md` pattern).

**No mockups:** this is a test-selection plan; each demo's visual gets mocked in its own per-demo
plan, per the established Round 1–6 practice.

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
5. **Known gap, zero demos:** `MOSLegalizerInfo` marks the direct **s32→4×s8
   `G_UNMERGE_VALUES` as `unsupported`** — "no seed hit it yet" (agent-handoff, backend-nav
   section). A demo that forms it is a *guaranteed* finding: either the abort reproduces (gap
   confirmed, rule gets written) or the shape silently legalizes another way (the comment is
   stale and gets fixed).
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

## The twenty

### Cluster A — the `G_SCMP` playbook: form opcodes no demo has legalized

119. **Motion-Detect Difference Field (`absdiff`).** Per-cell `a > b ? a - b : b - a` on u8, s16,
     and u32 lanes between two animated fields — the exact idiom the combiner folds to
     `G_ABDU`/`G_ABDS`. If `MOSLegalizerInfo` has no rule, this aborts like #46 did; if it
     lowers, the branchless expansion gets its first differential. *Shows:* a motion-silhouette
     between two drifting patterns. *Differential:* CRC over the difference field, all widths.
120. **Bitboard Knight Tour (`bitboard64`).** A 64-bit-bitboard move generator scored with
     `__builtin_popcountll` / `__builtin_clzll` / `__builtin_ctzll` — the s64
     `G_CTPOP`/`G_CTLZ`/`G_CTTZ` paths and their `__popcountdi2`/`__clzdi2`/`__ctzdi2` libcalls,
     none ever linked (the battery stops at `__ffssi2`). *Shows:* the knight's reachable-square
     board filling in. *Differential:* CRC over per-step popcount/scan results.
121. **Seismograph Absolute Trace (`llabs64`).** `llabs()` and the `x < 0 ? -x : x` s64 idiom on
     values straddling `INT64_MIN+1..` — s64 `G_ABS` (the battery covers `G_ABS` only ≤32-bit)
     plus the negate-carry chain across 4 limbs. *Shows:* a rectified waveform. *Differential:*
     exact s64 results folded to CRC, including the `INT64_MIN` edge left *out* (UB) and
     `INT64_MIN+1` kept in.
122. **Checksum Byte-Serializer (`unmerge32`).** ⭐ Forms the **direct s32→4×s8
     `G_UNMERGE_VALUES`** the legalizer marks `unsupported`: compute a 32-bit checksum, then
     store its four bytes through independent per-byte extracts shaped so the a16 pipeline (s32 =
     2×s16) still requests the 4-way byte unmerge (mirror the shape `legalizeMergeS32FromBytes`
     handles on the merge side; iterate on `-print-after=legalizer` until the node forms).
     Either outcome is a deliverable: reproduce-the-abort → write the symmetric 2-level rule; or
     the node can't form → correct the stale `unsupported`/comment with the measured reason.
     *Shows:* checksum bytes as colour bars. *Differential:* CRC over the serialized bytes.

### Cluster B — mode state meets code the passes can't see through

123. **VBlank Interrupt Tally (`nmitally`).** First-ever `__attribute__((interrupt))` handler in
     the battery: an NMI ISR increments shared 16-bit/32-bit counters while the main loop runs
     `+mos-a16` arithmetic — the ISR prologue/epilogue must save/restore A/X/Y *width state* (M/X
     flags), the `Imag` ZP registers it touches, and re-establish its own assumed width. A
     one-frame-granularity handshake keeps the differential deterministic (main loop reads
     counters only at a fenced frame boundary). *Disasm gate:* ISR entry saves `$p` (or
     `rep`/`sep` re-establishment) + every Imag reg it defs. *Differential:* CRC over the tally
     after N frames, host oracle fed the same N.
124. **Mid-Bracket Interrupt Torture (`isrbracket`).** The adversarial sibling of 123: main-loop
     code arranged so NMI statistically lands *inside* `rep`/`sep` brackets (long 16-bit
     sequences, no interrupt masking), across thousands of frames. Any ISR that returns with the
     wrong M/X width corrupts the main loop's next native op — a class no gate has ever been able
     to see. *Differential:* long-run CRC; bsnes-jg 3× byte-identical is the flake screen.
125. **Inline-Asm Island (`asmisland`).** Inline-asm blocks (with clobber lists) embedded between
     native 16-bit ops: `MOSInsertREPSEP` must treat the island opaquely and re-establish width
     on exit; the register allocator must honour the clobbers against live `Imag16` values. Also
     the standing trap: asm immediates sized by magnitude, not M flag (`and #$00ff` → 2-byte
     assemble) — the demo's asm carries deliberately-ambiguous immediates written with explicit
     width suffixes, and the *disasm gate asserts the encoded operand widths*. *Differential:*
     CRC over values threaded through the islands.
126. **Split-Personality Link (`mixedwidth`).** One link mixing per-function target features —
     `__attribute__((target("mos-a16")))` functions called from default-8-bit code and back —
     the call-boundary mode contract (caller width vs callee expectation) that six rounds of
     whole-TU flags never once crossed. If the attribute is unsupported/ignored, that itself is
     the finding (diagnosed, not silent). *Disasm gate:* correct width establishment at each
     boundary. *Differential:* CRC across a call-ping-pong chain.
127. **Threaded-Code Interpreter (`modethread`).** A computed-goto bytecode interpreter compiled
     `+mos-a16`/`+mos-xy16` whose handlers deliberately alternate 8-bit-byte and 16-bit-native
     bodies — every indirect branch is a join where the M/X lattice must merge all handler entry
     states conservatively. (Round 3's computed-goto ran default-8-bit only; the lattice never
     saw an indirect successor.) *Shows:* the interpreted program drawing. *Differential:* CRC
     over the interpreter's output tape.

### Cluster C — far pointers, third pass (the richest vein: defects 1, 6, 13)

128. **Bank-Boundary Walker (`bankwalk`).** A far array deliberately placed to straddle a 64K
     bank boundary, walked by pointer increment and by indexed offset across the seam — the
     24-bit `G_PTR_ADD` carry into the bank byte, both directions (`p++` and `p += big`).
     *Differential:* CRC over values read across the seam; host oracle models flat memory.
129. **Pointer-Order Shuffle (`farptrcmp`).** Sorts/deduplicates an array *of far pointers* by
     pointer value and takes ptrdiffs between elements in different banks — `G_ICMP` on
     `addrspace(1)` (24-bit compare, three limbs) and 24-bit subtraction, neither ever formed.
     *Differential:* CRC over the sorted order + the diffs.
130. **Far Dispatch Matrix (`fardispatch`).** Function pointers *stored in far (bank-external)
     data*, loaded then called: two dependent 24-bit fetches, DBR vs program-bank interplay, and
     the `Imag32`-resident callee address surviving to the indirect call. (Extends the existing
     `far_fnptr` micro-shape into a full table-in-far-data dispatch under pressure.)
     *Differential:* CRC over dispatch results.
131. **Far-Spill Stress (`farspill`).** Re-stresses `0018` *past* its fixed shape: enough
     simultaneously-live far pointers (each derived, not rematerializable) to force multiple
     `Imag32` stack spills across `__mulsi3`-class clobbers — defect 6 was one spill through one
     GPR; this asks for many, interleaved. The standing `LDImm`-destination gate (defect 6's
     assert) is the tripwire. *Differential:* CRC; `-verify` clean is load-bearing here.

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
138. **Limb-Seam Barrel (`shift64seam`).** s64 shifts by *data-dependent* counts swept through
     0–63 with the differential weighting counts 31/32/33 and 15/16/17 (the intra-/inter-limb
     seams for 16-bit lanes) — `__ashldi3`/`__lshrdi3`/`__ashrdi3` with runtime amounts, which
     Round 2 exercised only at s32. Sign-propagation at the seam for `ashr` is the classic
     miss. *Shows:* a barrel-shifted texture. *Differential:* CRC over the full sweep.

## First picks (highest expected yield per unit effort)

1. **#122 `unmerge32`** — a *declared* gap; the only demo in seven rounds with a guaranteed
   finding on either outcome.
2. **#123 `nmitally`** — the interrupt CC has literally never executed; prologue width/Imag
   save-restore is a large, wholly untested surface.
3. **#126 `mixedwidth`** — per-function features is the kind of boundary nobody designed for;
   even "diagnosed as unsupported" is worth having on the record.
4. **#125 `asmisland`** — inline asm × `rep/sep` lattice, plus it institutionalizes the
   2026-08-02 immediate-sizing trap as a gated check.
5. **#119 `absdiff`** — the cheapest possible replay of the exact mechanism that produced
   defect 17.
6. **#131 `farspill`** — history says far-pointer pressure pays; `0018`'s standing assert makes
   any regression loud.

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
