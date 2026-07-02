export const meta = {
  name: 'round5-stress-demo-ideation',
  description: 'Generate + adversarially verify 20 new SNES 65816 compiler stress-test demo ideas (Round 5, #73-#92)',
  phases: [
    { title: 'Understand', detail: 'inventory covered corners, backend opcodes, libcalls/libm, render surface' },
    { title: 'Ideate', detail: '7 diverse lenses each propose candidate demos' },
    { title: 'Verify', detail: 'adversarially check each candidate: distinct + present + differential-safe + visual' },
    { title: 'Synthesize', detail: 'rank + select the best 20 with category spread' },
  ],
}

const CONSTRAINTS = [
  'THE BAR each demo must meet (from docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md):',
  '1. A SHARED host+target logic header (examples/65816/<slug>.h): portable C99, <stdint.h> only, uint16_t/int16_t/uint32_t/int32_t, NEVER bare int (int is 16-bit on the 65816 target, 32-bit on host, so bare int diverges). The SAME body compiles for the host oracle and the 65816.',
  '2. A DIFFERENTIAL CRC: fold the result/state into a uint16 and assert host == default-8-bit == +mos-a16 == +mos-xy16 (== bsnes-jg). Any disagreement, a -verify-machineinstrs crash, an assembler/linker error, or a ROM crash IS a real compiler defect (the SUCCESS condition). So the computation MUST be deterministic + bit-exact host vs target: integer/fixed-point is bit-exact by construction; float is ONLY safe if you use float arithmetic + header-shipped polynomials OR correctly-rounded IEEE ops (sqrtf, conversions, floorf/ceilf/roundf/truncf/rintf, copysignf, fminf/fmaxf), NEVER glibc libm transcendentals (sinf/expf/logf/powf/atan2f: not correctly-rounded, ULP mismatch host vs picolibc), and NEVER fold raw NaN payload bits (fold the branch OUTCOME instead).',
  '3. A snesgfx render (examples/snes/snesgfx/): BG3 2bpp BitmapCanvas (128x128, 4 colours) or TextLayer or a custom Drawable or sprites or Mode7; NO far pointers (all data in bank-0 WRAM so it builds default/a16/xy16). Low-WRAM budget ~7680 bytes total. The picture IS the proof: VISUALLY INTERESTING AND ACTIVE (animated/evolving), not a static toy.',
  '4. Each demo must open a codegen corner that NONE of the existing 72 demos (Rounds 1-4) exercise, verified PRESENT in vendor/llvm-mos before drafting (cite the generic-ISel opcode in vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp, or the compiler-rt libcall, or the picolibc function).',
].join('\n')

// ---------- Phase 1: Understand ----------
phase('Understand')
const understand = await parallel([
  () => agent(
    'Read docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md (the full file, all 4 rounds + coverage maps) AND docs/investigations/plan-index.md. Produce a COMPLETE structured inventory of the CODEGEN CORNERS already covered by the existing 72 demos (#1-#72). For EACH demo give: id, slug, the one-line codegen corner it stresses (the specific compiler path/opcode/libcall/algorithm shape), and its category. Group by round. Be exhaustive + precise about WHAT COMPILER PATH each already tested. Also list the corpus slices in examples/snes/corpus/*.c and headers in examples/65816/*.h so we do not re-propose something already built. Return a dense structured text list.',
    { label: 'inv:covered-corners', phase: 'Understand', agentType: 'Explore' }),
  () => agent(
    'Read vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp thoroughly (and MOSLegalizerInfo.h / MOSISelLowering* if useful). Enumerate the GENERIC MACHINE-IR OPCODES (G_*) that have legalizer rules present, with line numbers and legalize action. For EACH, name the C-source construct or clang builtin that would cause the compiler to EMIT it. Examples to check specifically: G_ROTL/G_ROTR (rotate builtins or (x<<n)|(x>>(w-n))), G_FSHL/G_FSHR (funnel shift, __builtin_fshl), G_UADDSAT/SADDSAT/USUBSAT/SSUBSAT (saturating add/sub, __builtin_elementwise_add_sat/sub_sat), G_UMULO/SMULO (__builtin_mul_overflow), G_SEXT_INREG (signed narrow bitfield / (int8_t) narrowing), G_UDIVREM (combined unsigned divrem), G_FFLOOR/FCEIL/FRINT/FNEARBYINT/INTRINSIC_TRUNC/INTRINSIC_ROUND (floorf/ceilf/rintf/nearbyintf/truncf/roundf), G_FMINNUM/FMAXNUM (fminf/fmaxf), G_FCOPYSIGN/FABS (copysignf/fabsf), G_FSQRT (sqrtf), G_FMA (fmaf), G_MEMCPY/MEMMOVE/MEMSET (memcpy/memmove/memset). FLAG which opcodes are RARE / likely-NEVER emitted by ordinary integer/fixed-point demos (good untested-corner candidates), EXCLUDING ones Rounds 1-4 already covered (popcount/clz/ctz, bswap/bitreverse, UMULH/SMULH, SMIN/SMAX/UMIN/UMAX/ABS, unordsf2/eqsf2, div_t/SDIVREM, umoddi3). Return a dense table: opcode | vendor line | legalize action | C construct that emits it | likely-untested (yes/no + why).',
    { label: 'inv:backend-opcodes', phase: 'Understand', agentType: 'Explore' }),
  () => agent(
    'Investigate which floating-point + libc functions are ACTUALLY AVAILABLE and CORRECTLY-ROUNDED (thus differential-safe host==target) on this llvm-mos 65816 target. Check (a) compiler-rt libcalls: search vendor/llvm-mos/compiler-rt + the build for __floatsisf/__fixsfsi/__truncdfsf2/__addsf3/__mulsf3/__divsf3/__*di*, saturating (__*sat), rotate, mul-overflow helpers; (b) picolibc / SDK libm: does floorf/ceilf/roundf/truncf/rintf/nearbyintf/fminf/fmaxf/copysignf/fabsf/sqrtf/frexpf/ldexpf/modff/fmodf EXIST and link (grep SDK/picolibc headers + libs under build/ or vendor/), and which are correctly-rounded (floorf/ceilf/trunc/rint/nearbyint/copysign/fabs/sqrt are exact per IEEE; sinf/cosf/expf/logf/powf/atan2f/hypotf are NOT). Confirm div()/ldiv()/lldiv() are in picolibc. Note the #34 finding that sqrtf was earlier a library gap: determine whether sqrtf links now or must be self-shipped. Return a table: function | available (yes/no/unknown) | correctly-rounded (safe) | evidence (path).',
    { label: 'inv:libcalls-libm', phase: 'Understand', agentType: 'Explore' }),
  () => agent(
    'Read examples/snes/snesgfx/*.h (display, drawable, bitmap_canvas, text_layer, sprite_set, title_layer, upload, vram) and .claude/skills/snes-demo/SKILL.md. Summarize the RENDERING capabilities + budget: canvas size/bpp/colours, sprites, Mode7 availability, V-blank DMA budget, low-WRAM budget, the required TitleLayer pattern, the custom-Drawable pattern. Also list examples/snes/corpus/*.c and examples/65816/*.h filenames so we know which algorithms are ALREADY built (avoid re-proposing). Return a dense capability + already-built-list summary an idea-generator can use to judge visual feasibility.',
    { label: 'inv:render-surface', phase: 'Understand', agentType: 'Explore' }),
])
const digest = [
  '=== ALREADY-COVERED CORNERS (the 72 existing demos, DO NOT REPEAT) ===', understand[0],
  '=== BACKEND GENERIC-ISEL OPCODES PRESENT (verify-present reference; find the untested ones) ===', understand[1],
  '=== FLOAT/LIBC AVAILABILITY (differential-safety gate) ===', understand[2],
  '=== RENDER SURFACE + ALREADY-BUILT FILES ===', understand[3],
].filter(Boolean).join('\n\n')
log('Phase 1 complete: assembled covered-corner + backend + libc + render digest')

// ---------- Phase 2: Ideate ----------
phase('Ideate')
const CAND = { type: 'object', additionalProperties: false, required: ['candidates'], properties: {
  candidates: { type: 'array', items: { type: 'object', additionalProperties: false,
    required: ['title','slug','category','codegen_corner','candidate_opcode_or_libcall','distinct_from','algorithm','visual','differential_safety'],
    properties: {
      title: { type: 'string', description: 'punchy demo name' },
      slug: { type: 'string', description: 'lowercase [a-z0-9-] url/rom slug' },
      category: { type: 'string' },
      codegen_corner: { type: 'string', description: 'the specific NEW compiler path/opcode/libcall/algorithm-shape it stresses' },
      candidate_opcode_or_libcall: { type: 'string', description: 'the exact G_* opcode or __libcall or libc/picolibc function, plus the C construct/builtin that emits it' },
      distinct_from: { type: 'string', description: 'which existing demo(s) it is closest to and precisely why it is NOT a repeat' },
      algorithm: { type: 'string', description: 'the hot loop / kernel, detailed enough to implement; note widths' },
      visual: { type: 'string', description: 'what it renders and how it stays active/animated' },
      differential_safety: { type: 'string', description: 'integer-exact | fixed-point-exact | correctly-rounded-float | RISK (how host==target holds)' },
    } } } } }

const LENSES = [
  { key: 'int-lowering', brief: 'INTEGER / BITWISE lowering corners the battery never hit: saturating arithmetic intrinsics (G_UADDSAT/SADDSAT/USUBSAT/SSUBSAT via clang __builtin_elementwise_add_sat/sub_sat on scalars), rotates + funnel shift (G_ROTL/ROTR/FSHL/FSHR via __builtin_rotateleft32/rotateright32/fshl or (x<<n)|(x>>(w-n))), multiply-with-overflow (G_UMULO/SMULO via __builtin_mul_overflow, distinct from #44 add-overflow), signed narrow bitfield sign-extension (G_SEXT_INREG via a signed bitfield int f:5 read-back or (int8_t) narrowing), combined unsigned divrem (G_UDIVREM), memmove/memcpy/memset intrinsics (overlapping copy to __memmove). Prefer scalar ops that are bit-exact.' },
  { key: 'float-corners', brief: 'FLOATING-POINT corners that are DIFFERENTIAL-SAFE (correctly-rounded only): float rounding family floorf/ceilf/truncf/rintf/roundf/nearbyintf (G_FFLOOR/FCEIL/INTRINSIC_TRUNC/FRINT/INTRINSIC_ROUND/FNEARBYINT), float min/max fminf/fmaxf (G_FMINNUM/FMAXNUM, distinct from #57 integer min/max), copysignf/fabsf (G_FCOPYSIGN/FABS, the INTRINSIC path distinct from #45 union bit-pun), correctly-rounded sqrtf (G_FSQRT) if it links, frexpf/ldexpf/modff (exponent/mantissa decomposition). Each must fold a deterministic result. Only propose functions that are correctly-rounded (NOT libm transcendentals).' },
  { key: 'number-theory', brief: 'NUMBER-THEORETIC / iterative-numeric ALGORITHMS with a distinct codegen shape, all integer/fixed-point: CORDIC (shift-add-only trig/rotation/atan2/magnitude, variable-shift-by-loop-index + sign-driven add/sub, distinct from LUT trig #11/#56), digit-by-digit integer sqrt (isqrt, no libcall), extended Euclid / modular inverse (gcd back-substitution), Montgomery or Barrett modular reduction (modmul WITHOUT division, mul+shift, distinct from #61 umoddi3), bit-array prime sieve (arr[i>>3] set/test as a SET, Ulam-spiral render), a range/arithmetic coder (mul + carry renormalize, distinct from #67 Huffman bit-tree).' },
  { key: 'control-flow', brief: 'CONTROL-FLOW / LANGUAGE-FEATURE corners: __attribute__((cleanup)) scope-exit destructors (cleanup calls on every scope exit / early return, a C++-destructor-like codegen never tested), a FUNCTION-POINTER DISPATCH TABLE (indirect call through an array of fn ptrs, distinct from switch #37 and computed-goto #38 and single-callback qsort #46), a recursive-descent expression parser/evaluator (mutual recursion + precedence climbing, distinct from the #37/#38 bytecode VMs), a large STRUCT-RETURN-BY-VALUE (sret hidden-pointer ABI, a matrix/vector returned by value, distinct from #60 small div_t and #50 many-args), a mutual-recursion pair. setjmp/longjmp is BANNED (broken). Keep them visual + differential.' },
  { key: 'graph-game', brief: 'GRAPH / GAME-TREE / SEARCH algorithms with new codegen: A* or BFS/Dijkstra grid PATHFINDING (ring-buffer queue + visited grid + Manhattan heuristic, distinct from #62 union-find and #18 heap), minimax / alpha-beta GAME TREE (recursive max/min with pruning, tic-tac-toe/Othello/connect-4 self-play), 64-bit BITBOARD move generation (shifts+masks+popcount as game logic), topological sort / DFS ordering, flood fill (stack/queue region fill). All integer, all animated (a path solving, an AI playing itself).' },
  { key: 'dsp-transform', brief: 'DSP / SIGNAL / IMAGE-TRANSFORM kernels with distinct codegen (integer/fixed-point, NOT the already-built FFT fft_sim.c): 2-D CONVOLUTION with a signed kernel, Sobel/Prewitt EDGE DETECTION (multiply-accumulate over a 3x3 window + gradient magnitude via abs-sum or isqrt), a separable Gaussian blur, an 8x8 integer DCT (cosine transform, JPEG-style, distinct from FFT), ADPCM / delta decoding, a Hough transform (accumulator voting), integer Haar wavelet (lifting). Avoid the #48 IIR. Signed MAC over a window is the corner.' },
  { key: 'wildcard', brief: 'WILDCARD: any OTHER genuinely-distinct compiler corner + gorgeous visual not covered by the other lenses or the 72 existing demos: fixed-point matrix solve / Gaussian elimination with pivoting (data-dependent pivot select + division), a tagged-union (sum-type) interpreter, UTF-8 / variable-length decode state machine, a reaction-diffusion (Gray-Scott) simulation, a stack-based RPN calculator, a checksum family not yet used (Adler-32/Fletcher modular sum, distinct from #40 CRC32-table), a splay/AVL self-balancing tree (rotations). Pick the highest bug-yield + most visual.' },
]
const ideaBatches = await parallel(LENSES.map(L => () => agent(
  'You are generating NEW SNES 65816 C-compiler stress-test demo ideas for Round 5 (demos #73-#92). Your lens: ' + L.brief + '\n\n' + CONSTRAINTS +
  '\n\nHere is the digest of what is ALREADY covered (do NOT repeat), what backend opcodes are present (cite these), what float/libc functions are available + safe, and the render surface:\n\n' + digest +
  '\n\nPropose 5-6 STRONG candidate demos in your lens. Each MUST: (a) open a codegen corner none of the 72 existing demos run (state which existing demo it is closest to and why it differs), (b) name the exact G_* opcode / libcall / libc function it stresses AND the C construct/builtin that emits it (only propose ones the digest says are PRESENT + available; if unsure, say verify), (c) be differential-safe (integer-exact, or correctly-rounded float only, no libm transcendentals, no raw NaN bits), (d) render something visually interesting and ACTIVE within the snesgfx budget. Favour high bug-yield (brand-new libcall/ABI/legalizer paths) and vivid visuals. Return via the schema.',
  { label: 'ideate:' + L.key, phase: 'Ideate', schema: CAND })))
const candidates = ideaBatches.filter(Boolean).flatMap(b => (b.candidates || []))
log('Phase 2 complete: ' + candidates.length + ' candidate demos across ' + LENSES.length + ' lenses')

// ---------- Phase 3: Verify (pipeline) ----------
phase('Verify')
const VERDICT = { type: 'object', additionalProperties: false,
  required: ['slug','keep','present','present_evidence','distinct','differential_safe','visual_active','score','reason','refined'],
  properties: {
    slug: { type: 'string' },
    keep: { type: 'boolean', description: 'true only if genuinely new + present + differential-safe + visual' },
    present: { type: 'boolean', description: 'is the codegen corner actually reachable on this target (legalizer rule / libcall / libc fn links)?' },
    present_evidence: { type: 'string', description: 'concrete evidence: vendor/llvm-mos file+line of the legalizer rule, or the libcall/libc fn + where it lives; or WHY it is absent' },
    distinct: { type: 'boolean', description: 'genuinely distinct from all 72 existing demos?' },
    differential_safe: { type: 'boolean' },
    visual_active: { type: 'boolean' },
    score: { type: 'number', description: '1-10 bug-yield x visual x novelty' },
    reason: { type: 'string' },
    refined: { type: 'string', description: 'a tightened accurate one-line codegen-corner description (fix any wrong opcode/claim), or a note to drop it' },
  } }
const verdicts = await pipeline(candidates,
  (c) => agent(
    'Adversarially VERIFY this proposed Round-5 stress-test demo candidate. Default to skepticism.\n\nCandidate: ' + JSON.stringify(c) +
    '\n\nChecks (do the work, grep vendor/ and the repo):\n' +
    '1. PRESENT: is the named opcode/libcall/libc-function actually reachable on the llvm-mos 65816 target? Grep vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp (+ .h) for the G_* opcode legalizer rule (give file:line), OR confirm the compiler-rt libcall / picolibc function exists + links. If NOT reachable (e.g. the builtin does not lower to that opcode on a scalar, or the libm fn is not correctly-rounded / does not link), set present=false and explain.\n' +
    '2. DISTINCT: grep docs/investigations/2026-06-27-compiler-stress-test-demo-ideas.md + docs/investigations/plan-index.md + examples/snes/corpus/*.c + examples/65816/*.h to confirm no existing demo (#1-#72) already runs this exact corner. If it is a rehash, distinct=false.\n' +
    '3. DIFFERENTIAL-SAFE: will host (32-bit int, gcc) == target (16-bit int, 65816) bit-exactly? Integer/fixed-point = yes; float only if correctly-rounded (floorf/ceilf/trunc/rint/nearbyint/copysign/fabs/sqrt/conversions); flag libm transcendentals or raw-NaN-folding as unsafe.\n' +
    '4. VISUAL: can it render something active within the snesgfx budget (128x128 2bpp canvas / sprites / Mode7, <7680B WRAM, no far pointers)?\n' +
    'Set keep=true only if all four hold. Give a refined one-line corner description with the CORRECT opcode/path. Be specific in present_evidence (cite the vendor line or the exact function).',
    { label: 'verify:' + c.slug, phase: 'Verify', schema: VERDICT, agentType: 'Explore' })
    .then(v => ({ ...v, candidate: c }))
    .catch(() => null))
const kept = verdicts.filter(Boolean).filter(v => v.keep && v.present && v.distinct && v.differential_safe)
log('Phase 3 complete: ' + kept.length + '/' + candidates.length + ' candidates survived adversarial verification')

// ---------- Phase 4: Synthesize ----------
phase('Synthesize')
const FINAL = { type: 'object', additionalProperties: false, required: ['demos','first_picks','round_intro','sub_categories'],
  properties: {
    round_intro: { type: 'string', description: '2-4 sentence intro for the Round 5 section: what rounds 1-4 exhausted, what Round 5 targets, the verified-present-in-vendor note.' },
    sub_categories: { type: 'array', items: { type: 'string' }, description: 'the sub-category headings to group the 20 demos under (like Round 4 used 4 groups)' },
    demos: { type: 'array', minItems: 20, maxItems: 20, items: { type: 'object', additionalProperties: false,
      required: ['title','slug','sub_category','codegen_corner','why_bugs_hide','stresses','shows','verified_present','differential_note'],
      properties: {
        title: { type: 'string', description: 'punchy name, e.g. Rotate-cipher kaleidoscope (G_ROTL funnel shift)' },
        slug: { type: 'string' },
        sub_category: { type: 'string', description: 'which of sub_categories this belongs to' },
        codegen_corner: { type: 'string', description: 'short label for the coverage-map New codegen corner cell' },
        why_bugs_hide: { type: 'string', description: 'the coverage-map Why bugs hide there cell' },
        stresses: { type: 'string', description: 'the Stresses clause: exact opcode/libcall + the C construct, and which existing demo it differs from' },
        shows: { type: 'string', description: 'the Shows clause: the vivid active visual' },
        verified_present: { type: 'string', description: 'the concrete present-evidence (vendor line / libcall / libc fn)' },
        differential_note: { type: 'string', description: 'how host==target holds (integer-exact / correctly-rounded)' },
      } } },
    first_picks: { type: 'array', minItems: 5, maxItems: 6, items: { type: 'object', additionalProperties: false,
      required: ['slug','why'], properties: { slug: { type: 'string' }, why: { type: 'string' } } } },
  } }
const keptForSynth = kept.map(v => ({ ...v.candidate, refined: v.refined, score: v.score, present_evidence: v.present_evidence }))
const synth = await agent(
  'You are the synthesis judge for Round 5 of the SNES 65816 compiler stress-test demo battery (demos #73-#92). From the VERIFIED-SURVIVING candidates below, select and polish EXACTLY 20 demos.\n\n' + CONSTRAINTS +
  '\n\nSelection rules:\n' +
  '- Pick the 20 with the highest bug-yield x novelty x visual appeal, ensuring GOOD SPREAD across codegen categories (do not take 8 float demos; balance integer-lowering / float / number-theory / control-flow / graph-game / DSP-transform / wildcard).\n' +
  '- Every one must open a corner none of the 72 existing demos run, use an opcode/libcall/function VERIFIED PRESENT (carry its present-evidence), and be differential-safe + visually active.\n' +
  '- Deduplicate: if two candidates hit the same corner, keep the better and drop/replace with the next-best DISTINCT candidate. All 20 corners must be mutually distinct.\n' +
  '- If fewer than 20 strong distinct candidates survived, you MAY add a few of your own that meet every rule (mark them in verified_present as propose-verify).\n' +
  '- Group the 20 under 3-5 sub-category headings (like Round 4 groups). Write each Stresses to name the exact opcode/libcall + C construct AND the closest existing demo it differs from, and Shows to describe a vivid ACTIVE visual.\n' +
  '- Choose 5-6 first picks: the sharpest brand-new paths.\n\n' +
  'Verified surviving candidates (with scores + evidence):\n' + JSON.stringify(keptForSynth, null, 1) +
  '\n\nReturn the final structured Round-5 spec via the schema.',
  { label: 'synthesize:round5', phase: 'Synthesize', schema: FINAL })

return { chosen: synth, stats: { candidates: candidates.length, kept: kept.length,
  dropped: verdicts.filter(Boolean).filter(v => !(v.keep && v.present && v.distinct && v.differential_safe)).map(v => ({ slug: v.slug, reason: v.reason })) } }
