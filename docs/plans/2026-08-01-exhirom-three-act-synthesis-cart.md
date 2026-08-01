# ExHiROM Phase 2 — the three-act boundary synthesis cartridge

**Status:** PLANNED 2026-08-01 (user-approved shape: "all 3 in a loop")
**Supersedes:** the video-reel Phase 2 of
[2026-07-30-exhirom-video-boundary-test.md](2026-07-30-exhirom-video-boundary-test.md) —
resolving the plan-shape escalation from the 2026-08-01 display-defect investigation: that
phase predates main's SVX2 pipeline, and a second video path would duplicate what the reel
already proves. The Phase 0–1 deliverables (mapper model, canary ROMs, published pages) stand.

## Why synthesis beats streaming as the boundary test

Video reads the cartridge *sequentially*: a decode defect in one mirror or window is only hit
if the stream happens to pass through it. The three acts below read the same 6 MiB with three
*different* access patterns — a sequential program-counter march, adversarial scattered
pointer-chasing, and locality-heavy 2D streaming — so together they cover the decode far more
densely per minute than any stream, and each is individually watchable. The user's verdict on
the flat canary wash ("boring") is the other half of the motivation.

## The cartridge

One 48 Mbit (6 MiB) ExHiROM image — same configuration as the published
[cartsize-exhirom-6m](https://biohack.net/snes/cartsize-exhirom-6m/) canary (32 + 16 Mbit
mask-ROM pair, map mode `$25`) — whose payload is generated, seam-aware data. The demo loops
three acts forever; each act folds its traversal into a WRAM CRC, and the differential gate
asserts the fold exactly like every other demo.

### Act 1 — "The cartridge is the program" (sequential march)

A bytecode stream spans the whole image; a tiny VM (lineage: `turtle-vm`, `seqvm`) executes
it as a generative graphics piece. The 24-bit program counter is shown live; the act's
centerpiece is the counter rolling file `$3FFFFF → $400000` — CPU `$FF:FFFF → $40:0000`, the
non-monotonic device seam — as an on-screen event (flash + address freeze-frame beat).
Compiler stress: every opcode is a far fetch + jump-table dispatch (`JMP (abs,X)`) and the
ALU ops go through a function-pointer table — the heaviest sustained indirect-control-flow
load any demo has put on the #320/#321 codegen.

### Act 2 — the boundary-hostile graph walk (scattered access)

A pointer-linked graph baked across the image, edge targets deliberately placed to hop
banks, mirrors, and the device seam (generated adversarially from the mapper model — every
decode window gets in-degree > 0). The walk renders as a spreading web (2bpp bitmap canvas,
existing `bitmap_canvas.h`), edges lighting up as traversed, seam-crossing edges in the
accent colour. This is the maximum-coverage act: dozens of adversarial far dereferences per
frame.

### Act 3 — Mode 7 flyover over the baked world (streaming access)

A camera flyover (existing Mode 7 + `m7title.h`/`video_hud.h` infra) over a heightmap/texture
atlas spanning the image, with the flight path scripted to cross seam-mapped texture pages.
The HUD shows the current texture page's file address. Prettiest act; exercises DMA-paced
streaming reads.

### Loop glue

Acts run ~20–30 s each and hand off with a one-second verdict strip: per-act CRC so far,
cumulative fold, and the entropy-proof backdrop verdict (green once all three acts have
folded correctly at least once). Loop forever; `corpus_result` latches after the first full
cycle so the gate frame budget is one cycle + margin.

## Test semantics (house pattern, unchanged)

- `tools/` generator bakes all three payloads **from `tools/snes_cartmap.py`** (the
  authoritative model) so every address, segment list, and seam placement derives from the
  same source the canaries proved; the generator emits the host oracle alongside.
- Host oracle re-implements all three traversals; `corpus_result` = fold(act1, act2, act3).
  Per-act sub-CRCs in adjacent WRAM for discrimination when the fold mismatches.
- Differential: host == default(no-a16 leg where linkable) == `+mos-a16` @ bsnes-jg; MAME leg
  joins when the SPC700 IPL gap clears. `-verify-machineinstrs` clean.
- Display: `snes_ppu_reset_blank()` at boot (mandatory — the entropy lesson, `811c1f8`) and
  the gate carries the 6b-style entropy fingerprint (one picture hash across entropy
  None/Low/High × 2 boots).

## Dependencies / ordering

1. **`feature/exhirom-canaries` merge lands first** — this plan builds on the branch's
   ExHiROM platform + cartmap model. Merge is BLOCKED ×3; the substantive blocker is the
   `tools/snes-checksum.py` semantic conflict, whose correct resolution (a speed attribute in
   the cartmap model so `--fastrom` derives instead of ORs) is a small prerequisite work item,
   not a merge-time pick-a-side.
2. Acts are independent after the generator exists → P1–P3 can be built and gated one at a
   time, each shippable alone (Act 1 alone already replaces the boring wash).
3. Publication replaces nothing: new slug (e.g. `/snes/seamdemo/`), the cartsize canary pages
   stay as the minimal mapping tests.

## Phases

- **P0** — generator + host oracle (`tools/snes-seamdemo-gen.py` emitting bytecode stream,
  graph, heightmap, oracles from the mapper model); host structural gates.
- **P1** — Act 1 ROM (VM, PC ticker, seam event) + gate; publishable milestone.
- **P2** — Act 2 (graph walk + web render) folded in.
- **P3** — Act 3 (Mode 7 flyover) + loop glue + verdict strip; full-cycle gate.
- **P4** — publish via /snes-rom-page (data-driven registry).

## Mockups

Bundle: [2026-08-01-exhirom-three-act-synthesis-cart/](2026-08-01-exhirom-three-act-synthesis-cart/) —
[![four screen states](2026-08-01-exhirom-three-act-synthesis-cart/screens.png)](2026-08-01-exhirom-three-act-synthesis-cart/screens.html)
(Act 1 mid-march, Act 1 seam-crossing event, Act 2 web, Act 3 flyover + verdict strip — the
four states that matter; boot/blank is the entropy-proof solid running blue already proven by
the canary work.)

## P0 design — the contract P1–P3 build against

Settled 2026-08-01 by the P0 implementation. Everything below is *generated*, never
hand-written: [`tools/snes-seamdemo-gen.py`](../../tools/snes-seamdemo-gen.py) derives it from
[`tools/snes_cartmap.py`](../../tools/snes_cartmap.py), and
[`tools/snes_seamdemo_oracle.py`](../../tools/snes_seamdemo_oracle.py) reads it back out of the
image. P0 has no visible surface of its own — the mockups above still describe the ROM's screens —
so this section carries no new mockups.

### The coverage denominator: `CartMap.decode_cells()`

`windows()` answers *"where may a descriptor point"* — for 6 MiB ExHiROM that is **two** windows,
which is far too coarse to be a coverage target. The model gained one enumeration,
`decode_cells()`, derived entirely from `decode()`: **every 32 KiB CPU view of ROM, mirrors
included.** 32 KiB is exactly the right granularity — the board `map` lines only ever split a bank
at `$8000`, and `decompose` forces every device length to a multiple of 32 KiB — and the method
*asserts* that rather than assuming it. `decode_regions()` merges cells into maximal runs for
reports.

| | 6 MiB ExHiROM | 64 KiB HiROM (miniature) |
|---|---:|---:|
| decode cells | **380** | 380 |
| — canonical | 192 | 2 |
| — mirror | 188 | 378 |
| distinct file units | 192 | 2 |

For the cartridge the 380 break down as 64 upper halves in `$00-$3F` + 124 in `$40-$7D` (banks
`$7E`/`$7F` are WRAM) + 64 in `$80-$BF` + 128 in `$C0-$FF`.

### The slot record — one sub-layout, three acts, no collisions

A **slot** is one canonical 32 KiB file unit (192 of them). All three acts place payload at fixed
offsets inside slots, so they cannot collide by construction and the layout report is one table.

| offset | length | contents |
|---|---:|---|
| `+0x0000` | `0x0100` | straddle-in — bytecode continuing from the previous slot (used only at the seam) |
| `+0x0100` | `0x1000` | data page — 64×64 8bpp; act 3's texture and act 1's `LOAD` source |
| `+0x1100` | `0x0100` | heights — 16×16 |
| `+0x1200` | `0x0100` | page metadata — self-describing |
| `+0x2000` | `0x2000` | act 2 nodes — 16 B each, up to 512 |
| `+0x4000` | `0x0100` | act 1 chapter |
| `+0x7F80` | `0x0080` | straddle-out — bytecode running off the end of this slot |

**Reserved slots** are `129` (file `$408000-$40FFFF`, the linked near code + header — the range
comes from the canary tool's model-derived `layout()`, reused verbatim so the two fixture
generators cannot disagree) and `130` (file `$410000-$417FFF`, an arena for
`.far_text`/`.far_rodata`, widened with `--far-slots`). Those two slots account for **6** decode
cells, leaving **374 available**. `fill` refuses to write if the linker put anything in a payload
slot, so a ROM that outgrows the far arena fails loudly instead of losing code to the atlas.

The payload is **sparse** — only bytes a traversal reads are non-zero (the canary tool's lesson:
these ROMs are published to an in-browser player). 929,888 bytes, 14.8 % of the image.

### Act 1 — the VM ISA

Deliberately boring; the novelty budget went to seam coverage. **16 dense opcodes** so
`switch (op)` lowers to a jump table (`JMP (abs,X)`), and the ALU ops go through a function-pointer
table (`__call_indir`) — the same two lowerings `turtle-vm` proved. The PC is a **24-bit FILE
offset**, converted to a CPU address by a two-entry `far = file + delta` table generated from
`windows()`; that is what makes `$3FFFFF → $400000` a plain PC increment while the CPU address
jumps `$FF:FFFF → $40:0000`.

| op | mnemonic | operands | effect |
|---|---|---:|---|
| `0x00` | `HALT` | 0 | end of act |
| `0x01` | `NOP` | 0 | — (also the filler byte; one byte wide, so a run of it is self-aligning) |
| `0x02` | `IMM` | `a,i` | `r[a&7] = i` |
| `0x03` | `IMMH` | `a,i` | `r[a&7] = (r[a&7] & 0x00FF) \| (i << 8)` |
| `0x04` | `ALU` | `f,ab` | `r[d] = ALU[f&7](r[d], r[s])`, `d=(ab>>4)&7`, `s=ab&7` — **indirect call** |
| `0x05` | `MOVE` | `a` | pen-move `r[a&7]&63` units along heading; draws; folds `x0,y0,x1,y1,pen` |
| `0x06` | `TURN` | `i` | `heading = (heading + i) & 0xFF` |
| `0x07` | `PEN` | `i` | `pen = i & 3` |
| `0x08` | `JREL` | `i` | `pc += (int8)i` |
| `0x09` | `JZ` | `a,i` | `if (r[a&7] == 0) pc += (int8)i` |
| `0x0A` | `LOOP` | `a,i` | `if (--r[a&7] != 0) pc += (int8)i` |
| `0x0B` | `EMIT` | `a` | fold `r[a&7]`, low byte then high |
| `0x0C` | `MARK` | 0 | fold the 24-bit PC (lo, mid, hi) — the seam beat |
| `0x0D` | `LOAD` | `a,d` | `r[d&7] = mem8((pc & ~0x7FFF) + 0x0100 + (r[a&7] & 0x0FFF))`; folds the byte |
| `0x0E` | `JFAR` | `lo,mid,hi` | `pc = ` 24-bit **file** offset (chapter link) |
| `0x0F` | `SYNC` | `i` | fold `i`; the console yields `i` frames here |

ALU table (8, dense): `ADD SUB XOR AND OR SHL ROR MULLO`, all 16-bit wrapping. Headings use a
16-entry integer `DIR16` table — no trig at run time, so host and console agree bit-for-bit without
a shared sine table. Canvas is 128×128 (`& 0x7F`).

**Termination is structural, not hoped for.** Generated code has forward branches only; the single
backward branch (`LOOP`) is always preceded by an `IMM` seeding its counter with 2..8, and its body
provably never writes that counter (`LOOP_REGS` = `r6`,`r7`, excluded from every body emitter) and
contains no branches. The oracle still carries an op budget and treats exhausting it as a **defect**,
not a normal exit.

**The march.** One ~256-byte chapter per available slot, `JFAR`-chained in ascending *file* order,
each opening with `MARK`. 189 chapters, 191 marks, 65,961 ops, 12,729 drawn segments.

**The seam chapter is hand-laid, not generated.** It sits at `+0x7F80` of slot 127 and runs 256
bytes, so its body crosses the 4 MiB device boundary:

```
file $3FFF80  MARK          folds pc $3FFF81
file $3FFFFE  MARK          folds pc $3FFFFF
file $3FFFFF  SYNC opcode   <- $FF:FFFF, last byte of physical ROM 1
file $400000  SYNC operand  <- $40:0000, first byte of physical ROM 2   ** THE SEAM **
file $400001  MARK          folds pc $400002
file $400002  IMM r0,$10 ; LOAD r0,r1 ; EMIT r1   <- a data read on the far side
file $40007C  JFAR next
```

One VM instruction is split across the non-monotonic device boundary. Slot 128 therefore has no
chapter of its own — the straddle's tail already covers it, and that is the point of the act.

### Act 2 — the graph

**One 16-byte node per available decode cell** (374 nodes), placed at `slot + 0x2000 + 16·alias`
where `alias` is the node's position among the cells sharing that file unit. A node's address is
its *own* cell's CPU address, so a mirror-addressed node is a genuine mirror read.

| offset | field |
|---|---|
| `+0` | `kind` — 0 canonical, 1 mirror |
| `+1` | `weight` = `pattern(file_offset)` (the canary tool's discriminating byte) |
| `+2` | `flags` — bit0 seam-adjacent slot, bit1 second device, bit2 region B |
| `+3` | `hue` — render colour 0..3 |
| `+4..6`, `+7` | `next` (24-bit CPU far, LE) + edge flags |
| `+8..10`, `+11` | `peek0` + edge flags |
| `+12..14`, `+15` | `peek1` + edge flags |

Edge flags: `0x01` crosses the device seam, `0x02` target is a **mirror** address, `0x04` changes
the CPU bank byte.

`next` is a **seeded permutation cycle over every cell** — so in-degree is ≥ 1 for every cell *by
construction*, and a walk that always follows `next` visits every decode cell exactly once per lap
and provably closes. The two `peek` edges are adversarial and read-only: `peek0` is biased to the
**other physical device**, `peek1` to a **mirror-addressed** node, and both point at the target's
`weight` byte, whose value depends on all 24 bits of its file offset. The walk folds all 16 node
bytes plus the two peeked bytes, then the node count.

Coverage on the 6 MiB image: **1122 edges — 755 seam-crossing, 748 mirror-addressed, 1118
bank-crossing; minimum in-degree 1; 374 of 374 available cells covered, 6 reserved.**

### Act 3 — the atlas

One data page per slot, laid out as a `16 × 12` grid (`slot = gy·16 + gx`). A texel is
`(terrain8(...) >> 4) << 4 | (pattern(file_offset) & 0x0F)` — smooth terrain in the high nibble so
the flyover is a picture, the discriminating file-offset pattern in the low nibble so **every texel
read is a decode probe**. Heights are `terrain8` sampled 16×16. `terrain8` is a fixed integer field
over a 256-entry sine table whose fold **and** sum are baked, so a platform whose libm rounds
differently fails the self-check instead of shipping a quietly different cartridge.

Page metadata (`+0x1200`) is **self-describing**: `u24` file start, slot index, flags, `gx`, `gy`,
and folds of the page's texture and height blocks — a mis-decoded page is caught by its own
metadata.

The camera is a scripted **boustrophedon sweep** — regenerated identically on host and console from
four numbers plus the reserved-slot skip list — sampling 16 texels per page, 3040 samples over all
190 available pages. Per sample the fold takes the slot index (2 bytes), the texel, the height and
`meta[0]`.

### Oracle definitions

`fold(h, b) = rotl16(h, 1) + b`, and `pattern(off)`, are **imported from
`tools/snes-cartcanary.py`**, not re-typed — the fold's non-GF(2)-linearity and the pattern's
non-linearity were both learned the hard way there, and the self-check asserts the identity of the
function objects so a future copy-paste is caught.

```
corpus_result = fold(act1_lo, act1_hi, act2_lo, act2_hi, act3_lo, act3_hi)
```

Per-act sub-CRCs live in adjacent WRAM for discrimination. The oracle is the *only* host
implementation of the three traversals and it reads **bytes out of the image through
`CartMap.decode()`** — never the generator's construction — so the generator builds the payload,
then asks the oracle what the numbers are. A generator that lays a byte in the wrong place produces
a different oracle value instead of a matching pair of wrong numbers. The independent third
implementation lives in `selfcheck`, which recomputes acts 2 and 3 from first principles.

Because the CRCs are computed *before* the ROM is linked (the header needs them), the generator
asserts via `Image.slots_read` that **no traversal reads a reserved slot** — that is what makes the
pre-link prediction equal to the linked ROM's value.

**Generated values, seed `0x5EA3DE30`:**

| | value |
|---|---|
| act 1 CRC | `$93CF` (65,961 ops, 12,729 segments, 191 marks) |
| act 2 CRC | `$B596` (374 nodes, cycle closed) |
| act 3 CRC | `$6D21` (3040 samples, 190 pages) |
| **`corpus_result`** | **`$2B43`** |
| cartridge reads per cycle | 187,019 |

### Open for P1–P3

- **Act 1 pacing.** 65,961 ops is roughly 3 s of 65816 at a plausible cycle cost; `SYNC` is the
  pacing lever and P1 must decide ops-per-frame to reach the 20–30 s act.
- **Download size.** The full-entropy low nibble makes the image gzip to ~872 KB. On console act 3
  DMAs whole pages, so those bytes really are read — but if P4 needs a smaller download, restricting
  the pattern nibble to path-sampled texels is the lever, and it changes `act3_crc`.
- **`--far-slots`** is 1. If P1–P3's far code outgrows 32 KiB, widen it; `fill` will say so.

## Verification (to be executed per phase; format per house rules)

1. ~~P0: generator self-check — oracle reproduces a hand-computed fold on a 64 KiB miniature
   image; every decode window of the 6 MiB layout has in-degree > 0 in the Act 2 graph.~~
   **DONE 2026-08-01.** `python3 tools/snes-seamdemo-gen.py selfcheck`

    ```
    sin table: fold $FFFF (baked $FFFF), sum 32641 (baked 32641)
      [PASS] SIN256 is reproducible on this platform

    -- miniature: hirom 0x10000 --
      slots 2 (1 available, reserved [1]), nodes 126, payload 6880 bytes
      act1 $EBFA (397 ops)  act2 $CB9E  act3 $7BE0  corpus $3847
      [PASS] act1 halted (the stream terminates)
      [PASS] act2 fold: image-read oracle == independent recomputation  $CB9E vs $CB9E
      [PASS] act3 fold: image-read oracle == independent recomputation  $7BE0 vs $7BE0
      [PASS] corpus_result == fold(act1, act2, act3)
      [PASS] generation is deterministic (byte-identical rebuild)
      [PASS] no traversal reads a reserved slot (miniature)

    -- full cartridge: exhirom 0x600000 --
      slots 192 (190 available, reserved [129, 130]), nodes 374, payload 929888 bytes (14.8% of the image)
      act1 $93CF (65961 ops, 191 marks)  act2 $B596  act3 $6D21  corpus $2B43
      decode cells 380 = 192 canonical + 188 mirror; 6 reserved, 374 available; covered 374
      edges 1122 total, 755 seam-crossing, 748 mirror-addressed, 1118 bank-crossing; min in-degree 1
      [PASS] every AVAILABLE decode cell has in-degree > 0
      [PASS] covered + reserved == all decode cells  374 + 6 vs 380
      [PASS] act1 halted (the stream terminates)
      [PASS] act1 crosses the device seam inside one instruction  $400000
      [PASS] act1 marks one PC per chapter  191 marks / 190 available slots
      [PASS] act3 sweeps every available slot  190 / 190
      [PASS] act2 fold: image-read oracle == independent recomputation  $B596 vs $B596
      [PASS] act3 fold: image-read oracle == independent recomputation  $6D21 vs $6D21
      [PASS] no traversal reads a reserved slot (6 MiB)
      [PASS] payload never overlaps the linked-code range
      [PASS] fold/pattern are the canary tool's, not a second copy

    ALL PASS
    ```

    **PASS.** The plan's "every decode *window*" is realised as every decode **cell** —
    `CartMap.decode_cells()`, 380 of them including all 188 mirrors, which is a far stronger
    denominator than the 2 canonical windows. The model extension is covered by 5 new cases in
    `test/snes/cartridge-maps/test_snes_cartmap.py` (58 passed, 25044 subtests).
2. P1: Act 1 gate — `host == +mos-a16 @ bsnes-jg` fold; disasm shows jump-table dispatch +
   `__call_indir` + far fetches; seam event fires at the modeled file offset.
3. P2/P3: per-act sub-CRC gates + full-cycle `corpus_result` latch inside the frame budget.
4. All phases: entropy fingerprint (one picture hash across None/Low/High × 2).
5. P4: live-page WASM Verify fidelity == gate value.
