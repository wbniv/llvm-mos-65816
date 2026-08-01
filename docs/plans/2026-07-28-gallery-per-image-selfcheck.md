# Gallery "Verify fidelity" — assert ONE image, not the whole 62-work corpus

**Status:** planned 2026-07-28, user-directed ("make the button per image, not entire gallery").
Blocks [#137](2026-07-27-137-lzss-gallery-new-repack-visualization.md) step 6.

> **2026-07-30 — the per-work failures investigated below are ROOT-CAUSED AND FIXED.** Not a
> miscompile: the hand-written `decode_bank7e` thunk did `lda #$7e / pha / plb`, and the MOS
> convention passes `decode_near`'s `slen` in `A:X`, so every stream whose `(lz_len & 0xFF) > $7E`
> was truncated to `(lz_len & 0xFF00) | $7E`. 29 of 62 works. Full write-up, evidence and the
> `PEA`-based fix: [`2026-07-30-gallery-near-decode-abi-clobber.md`](2026-07-30-gallery-near-decode-abi-clobber.md).
> The "timing-dependent" clue in *Second-pass probe* was a red herring — bsnes-jg randomises the
> WRAM power-on fill, and the un-decoded tail of `FB_A` *was* that fill, feeding different bytes
> into the compressor each run. The truncation itself is fully deterministic.

## Problem

The site manifest's `selfcheck` is not only the offline gate — **it is what the in-page "Verify
fidelity" button runs in the browser**. For `lzss-gallery` it asserts `corpus_result`, which the ROM
only writes once **all 62 works** have decoded, repacked, byte-compared and folded.

Measured 2026-07-28 (`gallery_progress` @ `0x470` read at 200 000 frames):

```
works completed at 200000 frames: 22 of 62
linear need = 200000 * 62/22 = 563636 frames; +25% margin = 704545
```

So the shipped `frames: 200000` cannot reach the assertion, and the button has been failing. Git
history shows why nobody noticed the drift: **`frames` has never been raised while the corpus grew**
— it was set for the ~26-work corpus and carried forward unchanged through every expansion:

| manifest commit | frames | oracle | corpus |
|---|---|---|---|
| `c62d06d` | 200000 | `0x3D44` | ~26 works |
| `c10912e` | 200000 | `0xBA3A` | + Rijksmuseum |
| `91d58f0` | 200000 | `0x1D8E` | 60 works |
| `47d356f` | 200000 | `0x5CF0` | 62 works |
| `72e1b75` | 200000 | `0x839F` | 223-colour |

**Raising `frames` is the wrong fix.** The correct value (~710 000) is two orders of magnitude above
every other demo — median 500, largest non-gallery 6 000 — and would leave the button spinning for
minutes, reading as a hang. The offline gate wants the whole corpus; a person clicking a button
wants one image.

## Decision — split the two audiences

- **The button (site manifest):** assert **the artwork the gallery is currently displaying**.
  *(Will's call, 2026‑07‑31 — supersedes the original "first artwork only".)*
- **The full 62-work corpus:** stays exactly where it belongs, in `dev/lzss-gallery.sh`, which
  already drives its own `FRAMES` independently of the manifest. **No coverage is lost** — it moves
  from a check nobody could run to one that already runs offline.

Why the change matters: a visitor who has browsed to *Water Lilies* and presses **Verify fidelity**
is making a claim about *Water Lilies*. A button hard-wired to work 0 would answer a question the
visitor did not ask, and would keep reporting "verified" no matter how far they navigated — which
is the same category of mistake as the whole-corpus assertion this plan replaced: a check whose
subject is not the thing on screen.

> **Status of this respecification — 2026‑07‑31.** Mechanism chosen and the **ROM half + the
> offline tooling are implemented and gated** (*Chosen mechanism* and verification steps 5–9 below,
> branch `feature/verify-fidelity-button`). The **player half is specified and escalated** — it
> lives in `@wbniv/bsnes-jg-player`, a separate package with its own release cycle, and no button
> can honour "the displayed artwork" until it ships, because today's `verify()` power-cycles the
> ROM and destroys the visitor's position before reading anything. Until then the manifest carries
> the measured work‑0 fallback, which is at least *true*. The verification recorded further below
> was performed against that superseded work‑0 design and stands as evidence that the *codec* is
> correct.

## Design

The ROM already publishes per-work state (`record_result()`) — this was read, in 2026‑07‑28, as
meaning no ROM change is needed. It does not: the fields below describe the last *processed* work,
not the displayed one (see *Chosen mechanism*).

| symbol | addr | meaning |
|---|---|---|
| `gallery_progress` | `0x471` | count of completed works |
| `gallery_last_z` | `0x473` | **compressed size of the work that just finished** (uint16) |
| `gallery_last_work` | `0x475` | index of that work |
| `gallery_last_ok` | `0x476` | 1 if that work passed every stage |

> **These addresses are link addresses — they move.** The table above was re-measured 2026‑07‑31
> from `build/lzss-gallery.map`; an earlier revision listed them one to two bytes lower
> (`0x470`/`0x471`/`0x473`/`0x474`), and wiring the button from those stale values would have
> asserted `gallery_progress` instead of `gallery_last_z`. **Always read the symbol out of the map
> of the exact ROM being shipped** — never copy an address out of this document.

The superseded work‑0 design asserted **`gallery_last_z == 0x3BC9`** (15305 — work 0's
`compressed_bytes` from the host oracle `report.json`). That is a genuine correctness claim, not a
liveness ping: reaching it requires the ROM to have decoded the LZSS stream, recompressed it, and
produced *exactly* the byte count the host compressor produces. A miscompile in the codec moves it.

> **UNBLOCKED 2026‑07‑31 — the ROM now produces exactly 15305.** The `0x3B96` (15254) reading was
> the `decode_bank7e` A‑clobber; with the fix landed on `main` (`2932bcf`) a 12 000‑frame run reads
> `gallery_last_z = 0x3BC9` with `gallery_last_ok = 1`. Raw output under *Verification* below.

### Design notes for "currently displayed" — the two candidates costed on 2026‑07‑31

> **Superseded by *Chosen mechanism* below (2026‑07‑31).** Both candidates below assumed the check
> has to be *made to happen* on demand. It already happens — see the next section. Retained because
> the cost analysis is what led there.

**The core obstacle: one manifest entry can only assert one static value.** The manifest's
`off`/`len`/`want`/`frames` tuple is a single constant comparison — the player powers on, runs
`frames`, reads `len` bytes at `off`, and compares to `want`. "Whatever is on screen right now" is
by definition not a constant, so *something* has to bridge that. Two ways:

**(a) Player-side oracle table.** Ship the 62 `compressed_bytes` values from
`assets/snes/lzss-gallery/derived/report.json` to the player, and have the ROM publish the
**displayed-work index**. The button reads the index, looks up the expected size, and compares
against the ROM's reported size for that work.
*Cost:* the manifest schema grows from a scalar `want` to a keyed table, and the player needs a
lookup path it does not have today. *Benefit:* the oracle stays host-computed and independent —
the ROM never gets to assert its own correctness, which is what makes the check meaningful.

**(b) ROM-side check-on-display.** The ROM verifies the work it is displaying and publishes a
uniform pass/fail byte plus the work id. The button asserts the constant "pass", and shows the id.
*Cost:* the ROM becomes its own judge, so a codec bug that is symmetric between decode and repack
could self-certify; the independent host oracle drops out of the loop. Needs a ROM change.
*Benefit:* the manifest stays a scalar comparison — no player or schema change at all.

**What the ROM would have to publish either way.** The existing trio is the wrong state:
`gallery_last_work` / `gallery_last_z` / `gallery_last_ok` describe the **last *processed*** work —
the decode/repack pipeline's cursor, written by `record_result()` as the benchmark sweeps forward.
The **browsing cursor** — which artwork the viewer has navigated to and is looking at — is separate
state that the ROM does not currently expose. A "currently displayed" button needs that cursor
published (and, for (a), the per-work repacked size retained for the displayed work rather than
overwritten by the sweep, since `record_result()` rewrites `gallery_last_z` on every completed
work).

> The link-address warning above applies to every one of these symbols: whatever the ROM ends up
> publishing, its address must be read from the shipped ROM's `.map`, never copied from this
> document. `dev/sync-manifest-offsets.py` resyncs `off` via `selfcheck.symbol`.

Rejected alternatives:

- **Assert the *first* artwork only (work 0)** — the original decision here, superseded by Will on
  2026‑07‑31: it verifies a work the visitor may not be looking at, and reports "verified"
  regardless of where they have navigated. Retained as the fallback if the mechanism above proves
  disproportionate to the value.
- `gallery_progress >= 1` — reachable without the output being *right*; a liveness ping, not a gate.
- `gallery_last_ok == 1` — correct but a 1-byte value, far weaker evidence than a 16-bit length that
  must match an independently computed oracle. Worth adding as a second assertion if the manifest
  ever supports more than one field per demo. (Note this is close to mechanism (b), and carries the
  same self-certification caveat.)
- Keeping `corpus_result` and raising `frames` to ~710 000 — the unusable-button case above.

`frames` becomes "long enough that the displayed work has been verified", measured rather than
guessed — under the superseded work‑0 design that was 12 000, measured below.

## Chosen mechanism — 2026‑07‑31

**(c) Publish the displayed work's verdict; verify it *in place* against a host oracle table.**

Neither (a) nor (b) as written. Reading the player harness and the ROM's main loop turned up three
facts that reshape the problem, and the third dissolves most of it.

**Fact 1 — the button power-cycles the ROM, so "displayed" is unreachable without a player change.**
`verify()` in `@wbniv/bsnes-jg-player`'s `web/app.js` does not check the running machine. It
re-fetches the `.sfc`, calls `loadRomBytes()` (a cold power-on), runs `frames` frames from boot,
and only then reads WRAM:

```js
    stopLoop();
    // re-load this ROM to power on cleanly, like the gate's harness.
    fetch(bust("roms/" + current + ".sfc"))
      .then(...)
      .then(function (buf) {
        loadRomBytes(new Uint8Array(buf));
```

Whatever the visitor had navigated to is destroyed by the act of pressing the button. A
power-cycling button can only ever verify `GALLERY_START` — which *is* the superseded work‑0
design, reached by accident. **This forecloses the "no player change" branch of candidate (b): the
manifest staying a scalar comparison does not buy a working button, because the thing being
compared is no longer the thing the visitor was looking at.** A player change is unavoidable, and
once it is on the table the marginal cost of also doing a table lookup (candidate (a)) is small
next to the cost of the in-place-verify change itself.

**Fact 2 — the gallery already verifies every work in the frames it is displaying it.** The main
loop is not browse-then-check; it is a display-and-check pipeline (`lzss-gallery.c:1210`):
`prepare_slide(a)` puts work *k* on screen → `repack_slide(a)` recompresses the decoded pixels →
`verify_slide(a,z,ok)` byte-compares the repacked stream against the embedded one, decodes it
again and re-checksums → `record_result(...)`. Candidate (b)'s "ROM-side check-on-display" is
already built and shipping. There is nothing to add and no on-demand decode→repack to schedule.

**Fact 3 — `gallery_last_*` names the wrong subject, and the divergence window is the long one.**
Tracing the loop: `prepare_slide` changes the screen; `record_result` moves `gallery_last_work`.
Between those two calls sits the entire repack + verify phase, which is ~97% of a work's wall time
(measured below). So for almost the whole time a work is on screen, `gallery_last_work` still names
its **predecessor**. Outside that window the two agree — during `hold(180)`, and during the *next*
work's `unpack_slide`/`spinout`, where the screen still shows the old work. The gap is therefore
not "the ROM lacks a browsing cursor" (`gallery_current_asset` at `0x472` has been published all
along); it is that the *verdict* is published against the pipeline cursor rather than the screen.

So the mechanism is: **publish the existing verdict against the displayed work, coherently, and let
the player compare it to a host-computed table.**

### What the ROM publishes

One contiguous, padding-free record — `examples/snes/lzss-gallery.c`:

```c
#define GALLERY_SHOWN_NONE     0u  /* fields in flux, or nothing on screen yet */
#define GALLERY_SHOWN_PENDING  1u  /* `work` is on screen, verdict not in yet */
#define GALLERY_SHOWN_VERIFIED 2u  /* `work`/`z`/`ok` are a coherent verdict */
typedef struct{uint16_t z;uint8_t work,ok,state;}GalleryShown;
volatile GalleryShown gallery_shown;
```

| member | offset | meaning |
|---|---|---|
| `z` | base+0 | uint16 LE — repacked byte count of the displayed work |
| `work` | base+2 | index of the work **on screen** |
| `ok` | base+3 | 1 iff that work cleared every stage |
| `state` | base+4 | `0` none/in-flux, `1` on screen unverified, `2` verdict valid |

Written in exactly two places:

- **`prepare_slide()`**, right after `REG_INIDISP=INIDISP_ON` — a new work owns the screen, so the
  previous verdict is stale: `state=NONE`, then `z=0; ok=0; work=k`, then `state=PENDING`.
- **`record_result()`**, first thing — `state=NONE`, then `z=z; work=k; ok=ok`, then
  `state=VERIFIED`. The whole record is rewritten rather than patching the `PENDING` one, so it
  stays correct if the loop is ever restructured to reach `record_result` by another route.

**`state` is the publication barrier**: cleared before any other field is touched, raised after all
of them. A reader that samples `state == 2` is guaranteed `work`/`z`/`ok` describe the same work; a
reader must ignore every other field while `state == 0`. This matters even though the player reads
WRAM only between frames, because a frame boundary can fall between the individual stores.

`uint16_t` goes first so the record is padding-free on any ABI and the member offsets above are
fixed constants the manifest can carry. **The base is still a link address** — read it from the
shipped ROM's `.map` (`dev/sync-manifest-offsets.py` does this via `selfcheck.symbol`), never from
this document. In the 2026‑07‑31 build it is `0x477`, and adding it moved `gallery_failed`/
`gallery_done` from `0xdf9`/`0xe37` to `0xdfe`/`0xe3c` — the warning at the top of this plan,
demonstrated again by this very change.

`gallery_last_z`/`_work`/`_ok` and `gallery_current_asset` are left untouched: the offline gate,
`dev/jgxcheck.cpp` probes and the recorded evidence in this plan all reference them.

### The player / manifest contract

A new optional `selfcheck.mode`. **Absent ⇒ today's behaviour, byte-identical** — all 100+ other
demos are unaffected, and this is what makes the change safe to release.

```jsonc
"selfcheck": {
  "mode":   "live-record",              // opt in; absent = legacy power-on scalar assert
  "symbol": "gallery_shown",            // sync-manifest-offsets.py resolves `off` from this
  "off":    "0x477",                    // RESYNCED FROM THE MAP — never hand-written
  "record": { "z": [0,2], "work": 2, "ok": 3, "state": 4 },   // member offsets from `off`
  "ready":  2,                          // poll until state == this
  "oracle": [15305, 15234, ...],        // 62 host compressed_bytes, report.json array order
  "titles": ["Under the Wave off Kanagawa", ...],   // optional, for the badge text
  "frames": 24000,                      // poll budget (see Frames budget)
  "poll":   120,                        // frames per chunk, as today
  "label":  "displayed artwork repacked on-SNES == host oracle"
}
```

Player algorithm when `mode == "live-record"`:

1. **Do not reload the ROM and do not power-cycle.** Verify the machine that is running.
2. Chunk `poll` frames at a time, up to `frames` total. After each chunk read the `record` bytes at
   `off`.
3. While `state != ready`: badge `verifying <titles[work]>… n/frames` (when `state != 0`, so `work`
   is trustworthy; otherwise just `verifying…`).
4. On `state == ready`: **PASS iff `ok === 1 && z === oracle[work]`.**
   - pass → `✓ FIDELITY <titles[work]> — repacked on-SNES to <z> B == host oracle`
   - `z` mismatch → `✗ MISMATCH <titles[work]> got <z> want <oracle[work]>`
   - `ok === 0` → `✗ FAILED <titles[work]> — the ROM's own byte-compare rejected its repack`
5. If `work` changes mid-poll (the visitor navigated), re-target once and reset the frame counter,
   badging `following your navigation to <titles[work]>`; on a second change, stop with
   `navigation kept restarting the check — hold on one artwork and try again`.
6. On budget exhaustion: `⏱ still verifying <titles[work]> — not finished within <frames> frames`.
   **Indeterminate, not a failure** — it must not render as a red ✗.
7. Resume the live loop from wherever it reached. Because there is no reload, **the visitor's
   browsing position survives the button**, which today it does not.

Why the oracle stays on the player side: the ROM embeds its own `lz_len` per work and compares
against it, so `ok` alone is the ROM grading its own homework — candidate (b)'s objection, and it
is a real one. `oracle[]` is generated from `assets/snes/lzss-gallery/derived/report.json`, which
the **host** compressor produced; the browser does the comparison. That is what "reproduce the
gate's assert in this tab" means, and it also makes a corpus regeneration that outruns the ROM show
up as a loud mismatch instead of silent drift. Asserting `ok === 1` *as well* costs nothing and
catches the stages `z` cannot see (the second decode, both `fold_far` checksums, the byte compare).

**`?verify=1` keeps working, and stays deterministic.** `playUrl()` auto-fires `verify()` when the
query string carries `verify=1` — that is what `dev/verify-web-roms.sh` and the hook CI drive. On a
fresh page load the machine is at frame 0, so `gallery_shown.state == NONE` and the poll runs until
the *first* work verifies: under `?verify=1` the live-record mode degenerates exactly to the
work‑0 assertion, unattended and reproducible. The displayed-work behaviour only diverges from it
for a human who has actually navigated. **This is why in-place verification does not cost the
headless gate anything** — and why the budget below is sized on work 0, the one `?verify=1` waits
for.

Implementation shape, against the current `verify()` (`~/bsnes-jg-wasm/web/app.js:235`) — the
legacy path is the `else` branch and must stay byte-for-byte what it is today:

```js
  function verify() {
    var meta = romMeta(current); if (!meta || !meta.selfcheck) return;
    var sc = meta.selfcheck;
    if (sc.mode !== "live-record") { /* ...existing power-on path, unchanged... */ return; }

    // No stopLoop(), no fetch, no loadRomBytes: verify the machine that is running.
    var rec = sc.record, poll = sc.poll || 120, total = sc.frames, done = 0;
    var target = null, retargets = 0;
    checkEl.className = "badge running";
    (function chunk() {
      for (var i = 0; i < poll; i++) Module._bjg_run();
      done += poll; present();
      var wram = Module._bjg_wram() >>> 0, u8 = Module.HEAPU8, base = wram + Number(sc.off);
      var state = u8[base + rec.state];
      var work  = state ? u8[base + rec.work] : null;          // ignore every field while state==0
      var name  = (sc.titles && work != null) ? sc.titles[work] : ("work " + work);
      if (work != null && target != null && work !== target) {  // the visitor navigated
        if (++retargets > 1) return badge("fail", "navigation kept restarting the check…");
        target = work; done = 0;
        badge("running", "following your navigation to " + name);
      } else if (work != null && target == null) { target = work; }
      if (state !== sc.ready) {
        if (done >= total) return badge("warn", "⏱ still verifying " + name + " — …");
        return setTimeout(chunk, 0);                            // and keep the badge counting
      }
      var z = u8[base + rec.z[0]] | (u8[base + rec.z[0] + 1] << 8), ok = u8[base + rec.ok];
      var want = sc.oracle[work];
      if (ok === 1 && z === want) badge("pass", "✓ FIDELITY " + name + " — repacked on-SNES to " + z + " B == host oracle");
      else if (ok !== 1)          badge("fail", "✗ FAILED " + name + " — the ROM's own byte-compare rejected its repack");
      else                        badge("fail", "✗ MISMATCH " + name + " got " + z + " want " + want);
    })();
  }
```

Note `badge("warn", …)` needs a third badge class alongside `pass`/`fail` — timeout is
indeterminate and must not render red (failure mode table below).

### Frames budget

**The button is a real wait, and that is the honest answer — but it is not extra work.** The ROM
is already recompressing the displayed artwork; the button waits for a computation that was going
to happen regardless, and the wait is *visible on the SNES screen the whole time* (the `REPACK`
progress line and the live compressor cursor sweeping the image). That is the UX contract: the
badge counts frames next to a picture that is visibly being worked on, so it reads as watching,
not as hanging. It must never present as a spinner with nothing behind it.

Measured per-work stage costs (frames), read out of `gallery_repack_frames`/`gallery_verify_frames`
and the three decode counters at 30 000 frames:

| k | slug | unpack | stage | near | repack | verify | repack+verify | full work |
|---|---|---|---|---|---|---|---|---|
| 0 | great-wave | 144 | 53 | 123 | 8169 | 336 | **8505** | 8825 |
| 1 | grande-jatte | 140 | 54 | 120 | 7559 | 317 | **7876** | 8190 |
| 2 | water-lilies | 143 | 54 | 121 | 7688 | 325 | **8013** | 8331 |

So the two cases the budget has to cover are:

- **In-place, worst case** — the visitor presses the button one frame after a new work took the
  screen: `prepare_slide` + `hold(60)` + repack + verify ≈ **8 600 frames** for the works measured.
- **From a cold power-on** (`?verify=1`, and `dev/verify-web-roms.sh`) — splash + the first
  `unpack_slide` + `prepare_slide` + `hold(60)` + repack + verify. Measured exactly, not bracketed:
  `JGX_POLL` reports **frame 9 376** (step 8 below). The larger of the two, so it sets the budget.

`frames: 24000` — **2.56×** the measured cold-boot case, with headroom for the corpus's larger and
denser works (raw lengths run 12 692–16 184 B, and a literal-heavy image such as `thistles`, 14 186
literals, does more search per byte than `great-wave`'s 11 252). **This is a budget, not a
rendezvous:** both the browser and `dev/verify-web-roms.sh` stop the instant `state` reaches
`ready`, so the typical cost is ~8 500–9 400 frames and 24 000 is only ever reached by something
genuinely wrong.

> **Why a fixed frame count could not work here, and what it cost.** `VERIFIED` persists only from
> `record_result` until the *next* `prepare_slide` — `hold(180)` plus the next work's
> `unpack_slide` and `spinout`, ≈ 530 frames out of a ≈ 9 100-frame cycle. A harness that runs a
> fixed count and reads once lands inside that window ~6% of the time and would fail a correct ROM
> the other 94%. `dev/jgxcheck.cpp` therefore gained **`JGX_POLL=1`**: stop as soon as the asserted
> value appears, up to `frames`, and report the frame it matched on. That makes the headless replay
> the same algorithm as the browser's chunked poll instead of an approximation of it — and it is
> what makes the budget above measurable rather than guessed.

### Failure modes

| mode | behaviour | why it is safe |
|---|---|---|
| **Wrong work displayed mid-check** | `work` changes during the poll | Step 5: re-target once, then stop with an explanatory badge. The `state` barrier means a changed `work` can never be paired with the old `z`/`ok`. |
| **Check interrupted by navigation** | `nav_cancel` aborts repack; the loop re-enters `unpack_slide`/`prepare_slide` | `prepare_slide` drops `state` to `NONE` before naming the new work, so the player sees "not ready" rather than a stale verdict, and step 5 handles the rest. |
| **Stale oracle vs rebuilt ROM** | corpus regenerated, manifest `oracle[]` not | Loud per-artwork `✗ MISMATCH got/want`. `dev/sync-manifest-offsets.py --check` reports the drift offline before it ships. |
| **Stale `off` after a relink** | any struct change moves `gallery_shown` | Same guard as every other demo: `sync-manifest-offsets.py` resyncs `off` from the map via `selfcheck.symbol`, and refuses a map whose `build/<slug>.sfc` is not byte-identical to the shipped ROM. |
| **Torn read across a frame boundary** | player samples mid-`record_result` | `state` is the barrier; a partial record always reads `state == 0`. |
| **Power-on residue read as a verdict** | fresh boot, nothing displayed yet | `gallery_shown` is `.bss` (crt0-zeroed) and `GALLERY_SHOWN_NONE == 0`, so a fresh machine reads "not ready". |
| **Budget exhausted** | slow device, or the visitor pressed the button one frame after navigating | Indeterminate badge, not a red ✗ (step 6). The check never claims a failure it did not observe. |
| **Player still on the legacy build** | site not yet resynced | `mode` is unknown to it, so it takes the legacy path against `off`/`len`/`want`. Sequencing below keeps that path pointing at something true. |

### Rejected — and why

- **(a) as specified: player-side oracle table on top of a power-on run.** The lookup half is kept;
  the power-on half is what fails. Reaching an arbitrary displayed work from boot means replaying
  the visitor's navigation into a fresh machine, or waiting for the sweep to reach that work (up to
  ~62 works × the per-work cost). Both are worse than not power-cycling.
- **(b) as specified: ROM self-certifies, manifest stays scalar.** The "no player change" benefit
  is illusory (Fact 1), so its cost — the independent host oracle dropping out of the loop — buys
  nothing. `ok` is retained as a *secondary* assertion, not the primary one.
- **Infer readiness from the existing symbols** (`gallery_last_work == gallery_current_asset`, then
  read `gallery_last_z`). Tempting because it looks like a zero-ROM-change design, and the four
  bytes at `0x472`–`0x476` are conveniently contiguous today. It is not zero-change: (i)
  `record_result` writes `gallery_last_ok` *after* `gallery_last_work`, so a reader that trusts the
  equality can pair work *k* with work *k−1*'s `ok` — a real torn read needing a ROM reorder anyway;
  (ii) the contiguity is a linker accident of declaration order, not a declared layout; (iii) the
  reader has to infer a state machine that nothing in the ROM asserts. Given a ROM change is needed
  either way, an explicit five-byte record with a stated coherence rule costs the same rebuild and
  removes all three hazards.
- **A pad-injected "verify now" command** (player presses a chord, ROM re-runs decode→repack for the
  displayed work on demand). Adds a second verification path to the ROM, a button-mapping contract,
  and a full decode→repack the pipeline was about to do anyway. Fact 2 makes it redundant.
- The alternatives already rejected above (work‑0 only, `gallery_progress >= 1`, `corpus_result`
  with `frames ≈ 710 000`) stand rejected for the reasons given there.

### Sequencing — what lands where

The ROM half and the tooling half land in this repo and are inert to the current player: the record
is additive, and a legacy player ignores `mode`. The player half is a separate package
(`@wbniv/bsnes-jg-player`, `~/bsnes-jg-wasm`, `web/app.js` → `dist/engine/app.js`, synced to sites
by `bin/sync.mjs`) with its own release cycle — **specified above, escalated, not edited from here.**

Until that release, the manifest entry keeps the **legacy scalar form**, pointed at the measured
work‑0 fallback (`symbol: gallery_last_z`, `want 0x3BC9`, `frames 12000`). That is the superseded
design — but it is *true*, whereas the currently shipped entry (`off 0x46e`, `want 0x839F`,
`frames 200000`) is stale on all three counts and fails for every visitor. Restoring a true
assertion now and switching `mode` on when the player ships is strictly better than leaving the
button broken while waiting.

**Interim edit, ready to apply with the in-flight republish** (verification step 6 shows it is
valid against *both* the record-carrying ROM and the one without it, because this change moves no
previously published address):

```jsonc
"selfcheck": {
  "off":    "0x473",          // sync-manifest-offsets.py rewrites this from the map — do not hand-set
  "len":    2,
  "want":   "0x3BC9",         // 15305 = report.json[0].compressed_bytes, great-wave
  "frames": 12000,
  "symbol": "gallery_last_z", // MANDATORY, or the next resync points it back at corpus_result
  "label":  "first artwork repacked on-SNES == host oracle"
}
```

This repo does **not** edit `~/biohack.net` — the manifest edit belongs to whoever runs the
republish, immediately after `dev/sync-manifest-offsets.py`, and `dev/verify-web-roms.sh --only
lzss-gallery` must pass before the deploy.

## Steps

1. ~~Measure the frame at which work 0 completes (`gallery_progress` becomes 1); add margin.~~
   **Done 2026‑07‑31** — work 0 is complete well before 12 000 frames (`progress = 1`,
   `last_ok = 1`); 12 000 is the measured budget with margin.
2. ~~**RESPECIFIED 2026‑07‑31.** Choose mechanism (a) or (b), publish the browsing cursor from the
   ROM, and wire the button to the displayed work.~~ **Mechanism chosen and ROM half done
   2026‑07‑31** — neither (a) nor (b) but (c), *Chosen mechanism* above. `gallery_shown` is
   published by `prepare_slide()`/`record_result()`; verification steps 5–8 below.

   > The superseded work‑0 wiring, kept because it is measured and is what the manifest carries
   > until the player ships: `off` = the map's `gallery_last_z` (`0x473` in the 2026‑07‑31 build —
   > re-read it), `len 2`, `want 0x3BC9`, `frames 12000`, `"symbol": "gallery_last_z"`.

3. ~~Verify the new selfcheck passes headlessly before publishing.~~ **Tooling done 2026‑07‑31** —
   `dev/verify-web-roms.sh` learned `mode: "live-record"` and replays it headlessly (jgxcheck
   asserts `state` reached `ready`; a post-check does the `ok == 1 && z == oracle[work]` lookup out
   of the same run's WRAM dump). `dev/sync-manifest-offsets.py` learned `oracleFrom` and generates
   the 62-entry table. **The manifest edit itself still waits on the republish** (below).
4. Republish (biohack.net only — indri.studio has no `public/play/roms/manifest.json`), then wire
   the manifest entry. **BLOCKED on the gallery republish** — see *Sequencing* above.
5. ~~Record the full-corpus expectation in `dev/lzss-gallery.sh`~~ **Done** — the all-62-work
   `GALLERY_BENCH_ONLY` decode gate (`0x5CF0` all-pass / `0xA50F` any-failure) landed with the fix.
6. **Player package** — implement `mode: "live-record"` in `@wbniv/bsnes-jg-player` per *The player
   / manifest contract*, release, resync the sites. **ESCALATED — not landable from this repo.**

> **The `"symbol"` field is mandatory here, not decorative.** `dev/sync-manifest-offsets.py`
> rewrites every selfcheck's `off` to the freshly rebuilt ROM's link address, and it used to
> resolve **`corpus_result` for every demo unconditionally**. Pointing this button at
> `gallery_last_z` without teaching that script would have let the next republish silently rewrite
> `off` back to `corpus_result`'s address — the button would then assert `0x3BC9` against the
> whole-corpus field and fail for visitors. The script now honours an optional
> `selfcheck.symbol`, defaulting to `corpus_result`, so existing entries are unaffected.
>
> Consequence for sequencing: **the manifest edit must land together with the republished ROM.**
> `sync-manifest-offsets.py` deliberately refuses to trust a map unless `build/<slug>.sfc` is
> byte-identical to the shipped ROM, so the button cannot be wired before the gallery ROM is
> rebuilt from the fix and published.

## Verification

> **Scope of this evidence.** Steps 1–2 below were run against the **superseded work‑0 design**.
> They remain valid as proof that the *codec* and the *repack differential* are correct — which is
> what unblocked this plan — but they are not a validation of the respecified
> "currently displayed" button, which is unimplemented.

1. `gallery_last_z` reads `0x3BC9` at the chosen frame (raw jgxcheck output pasted below).

```
SMOKE: PASS off=0x473 len=2 got=0x3BC9 (ran 12000 frames, bsnes-jg)
jgxcheck: WRAM @0x46F: 00 00 01 01 C9 3B 00 01 00 46 00 00 00 00 00 00
                             ^^    ^^^^^ ^^ ^^
                       progress=1  last_z  |  last_ok=1
                                   0x3BC9  last_work=0
```

**PASS** — 15305 is exactly `report.json[0].compressed_bytes` for `great-wave`, and
`gallery_last_ok = 1` means that work cleared every stage (far decode, stage, near decode, both
`fold_far` checksums, and the byte-exact repack).

2. The value is *not* yet set materially earlier (i.e. the frame budget is genuinely needed, not
   passing by accident on a zeroed field).

**PASS** — `corpus_result` is still `0x0000` in the same dump, so the field being asserted is
distinct from the whole-corpus latch and is written only when work 0 actually completes. The
pre-fix ROM reached this same field and reported `0x3B96`/`ok=0`, which is what makes this a
correctness assertion rather than a liveness ping: a broken codec moves the number.

3. `dev/verify-web-roms.sh --only lzss-gallery` passes.

**NOT RUN — blocked on the republish.** The shipped `~/biohack.net/public/play/roms/lzss-gallery.sfc`
is still the pre-fix ROM, so this check would assert the new value against the old binary. It runs
once the gallery ROM is rebuilt and published.

4. Live check after deploy: both sites serve the new manifest and the button passes in-page.

**NOT RUN — blocked on the republish.** (Scope correction: only biohack.net has a
`public/play/roms/manifest.json`; indri.studio has none.)

### Added 2026‑07‑31 — the works 0–3 repack differential (the gate this plan was blocked on)

Visual ROM built from `main` after the fix landed, 40 000 frames, bsnes-jg, one 2568-byte WRAM dump
decoding `gallery_failed[62]` @ `0xdf9` and `gallery_done[62]` @ `0xe37`:

```
SMOKE: PASS off=0x471 len=1 got=0x04 (ran 40000 frames, bsnes-jg)

gallery_progress = 4      gallery_last_work = 3
gallery_last_z   = 15234 (0x3B82)   == basket-apples' embedded lz_len
gallery_last_ok  = 1

done[k]   : 111100000000...      done   = [0, 1, 2, 3]
failed[k] : 000000000000...      failed = []
```

**PASS** — against the recorded pre-fix observation `failed = [0, 2, 3]`. All four works now pass
their own decode → repack → byte-compare.

### Added 2026‑07‑31 — mechanism (c): the displayed-work record

Built on `feature/verify-fidelity-button` (worktree, hardlinked toolchain per
`docs/howto-feature-worktree.md`). All addresses below are read from that build's
`build/lzss-gallery.map`, never from prose.

5. **The full-corpus decode gate still passes with the record added** —
   `QUICK=1 BENCH_FRAMES=30000 dev/run.sh lzss-gallery`.

```
==> target build (+mos-a16, 1 MiB LoROM)
/work/build/lzss-gallery.sfc: LoROM size=1024KiB map_mode=0x20 rom_size_byte=0x0A checksum=0x63E2 complement=0x9C1D
NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)
decode_bank7e ABI audit: PASS (A-safe PEA/PLB; 08 8b f4 7e 7e ab ab 20 8a 82 ab 28 60)
bank $00 asset gate: PASS (FONT16=$15:EF29, FONT8=$07:FB54; 5779 B before header)
==> fast decode gate (GALLERY_BENCH_ONLY, all 62 works)
/work/build/lzss-gallery-bench.sfc: LoROM size=1024KiB map_mode=0x20 rom_size_byte=0x0A checksum=0xD65A complement=0x29A5
SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
==> corpus_result @ WRAM 0x46f; oracle 0x96D8
SMOKE: PASS off=0x471 len=1 got=0x00 (ran 1000 frames, bsnes-jg)
aa3b7f278ac689ca377bf4999cd316aa9fb0d5ac2e080796cc439a7d606f741f  /work/build/lzss-gallery.sfc
RESULT: PASS — 62-work LZSS gallery host oracle, relink, header and bsnes-jg gate
```

**PASS** — `0x5CF0` is the all-62-pass latch. Note `corpus_result`'s own oracle for the *visual*
ROM is `0x96D8`, not the `0x839F` the shipped manifest still asserts: a third independent way the
live entry is stale.

6. **The record is additive — every previously published address is unmoved.**

```
  corpus_result          main=46f    mine=46f    same
  gallery_progress       main=471    mine=471    same
  gallery_current_asset  main=472    mine=472    same
  gallery_last_z         main=473    mine=473    same
  gallery_last_work      main=475    mine=475    same
  gallery_last_ok        main=476    mine=476    same
  gallery_shown          main=-      mine=477    DIFFERS
```

**PASS** — `gallery_shown` lands at `0x477`, size 5 (padding-free, as the layout requires).
`gallery_failed`/`gallery_done` shift `0xdf9`→`0xdfe` and `0xe37`→`0xe3c`; nothing published
references them. The practical consequence is that **the interim work‑0 fallback wiring is valid
against both ROMs**, so it can be wired at the in-flight republish without waiting for this change.

7. **The state machine tracks the screen, and `gallery_last_*` demonstrably does not.** One
   4096-byte WRAM dump per frame count, decoded against the map:

```
gallery_shown @ 0x477 size 5
frame   3000 | shown: state=PENDING  work= 0 z=    0 ok=0 | last_work= 0 last_z=    0 last_ok=0 | current_asset= 0 progress=0
             | done=[] failed=[]
frame   9000 | shown: state=PENDING  work= 0 z=    0 ok=0 | last_work= 0 last_z=    0 last_ok=0 | current_asset= 0 progress=0
             | done=[] failed=[]
frame  12000 | shown: state=PENDING  work= 1 z=    0 ok=0 | last_work= 0 last_z=15305 last_ok=1 | current_asset= 1 progress=1
             | done=[0] failed=[]
frame  20000 | shown: state=PENDING  work= 2 z=    0 ok=0 | last_work= 1 last_z=14879 last_ok=1 | current_asset= 2 progress=2
             | done=[0, 1] failed=[]
frame  30000 | shown: state=PENDING  work= 3 z=    0 ok=0 | last_work= 2 last_z=14986 last_ok=1 | current_asset= 3 progress=3
             | done=[0, 1, 2] failed=[]
frame  40000 | shown: state=PENDING  work= 4 z=    0 ok=0 | last_work= 3 last_z=15234 last_ok=1 | current_asset= 4 progress=4
             | done=[0, 1, 2, 3] failed=[]
```

**PASS**, and it is the whole argument for the respec in one table:

- **`gallery_last_work` names the wrong painting, every time we looked.** At frame 12 000 the ROM
  is *displaying work 1* while `gallery_last_z` reads `15305` — work 0's answer. The superseded
  work‑0 wiring (`gallery_last_z == 0x3BC9`, `frames 12000`) passes at exactly that frame, and it
  is telling the visitor about a painting that left the screen. Same at 20 000, 30 000, 40 000:
  `shown.work` is always `last_work + 1`. This is not an edge case, it is the steady state.
- **`gallery_shown.work` tracks the screen** — it agrees with `gallery_current_asset` at all six
  samples.
- **The barrier holds.** Every sample reads `PENDING` with `z = 0, ok = 0`. That is the design
  working: `VERIFIED` is only ~530 frames of a ~9 100-frame cycle, so six blind samples landing
  outside it is the expected result — and in every one of them the record correctly refuses to
  offer a verdict rather than handing back a stale one.
- **The "infer it from the existing symbols" alternative would have reported a false failure.** At
  frame 3 000, `gallery_last_work == gallery_current_asset == 0` — the equality test says "ready" —
  but `gallery_last_z` is still `0` because `record_result` has not run yet. A player trusting that
  equality reads 0, compares against 15305, and shows the visitor `✗ MISMATCH` for a ROM that is
  perfectly correct. The `state` barrier is what makes that unrepresentable.
- **Works 0–3 remain clean** (`done=[0,1,2,3] failed=[]`), reproducing the pre-existing 40 000-frame
  differential above with the record added, and `last_z` matches the host oracle at each step:
  `15305, 14879, 14986, 15234` == `oracle[0..3]`.

7b. **The compiler emitted the barrier ordering** — the coherence rule is only real if the stores
   land in the written order. Absolute stores into `gallery_shown` (`0x477`–`0x47b`), scanned out
   of the linked ROM:

```
=== record_result @ 0xa857 — absolute stores into gallery_shown (0x477..0x47b) ===
  +0x01c  stz $047b      <- state
  +0x023  sta $0477      <- z.lo
  +0x028  sty $0479      <- work
  +0x02b  stx $047a      <- ok
  +0x030  sta $047b      <- state
=== prepare_slide @ 0x9c91 — absolute stores into gallery_shown (0x477..0x47b) ===
  +0x9f8  stz $047b      <- state
  +0x9fd  stz $0477      <- z.lo
  +0xa02  stz $047a      <- ok
  +0xa05  sta $0479      <- work
  +0xa0a  sta $047b      <- state
```

**PASS** — `state` is stored first and last in both writers, so no reordering collapsed the
barrier. A bonus the layout buys: under `+mos-a16` (`M=0`) the single `sta $0477` writes both bytes
of `z` in one instruction, so `z` cannot tear even without the barrier.

8. **End-to-end headless replay of the live-record contract.**

The whole contract, minus the browser: a fixture site whose ROM is byte-identical to the built one,
a `live-record` manifest entry with `off` and the 62-entry `oracle`/`titles` tables generated by
`dev/sync-manifest-offsets.py`, replayed by `dev/verify-web-roms.sh` in bsnes-jg.

```
  lzss-gallery     PASS  (24000 frames, Under the Wave off Kanagawa: repacked on-SNES to 15305 B == host oracle)

verify-web-roms: 1 passed, 0 failed, 0 missing
ALL PASS — safe to publish

real	2m21.464s
```

The record itself, read out of the same run (`JGX_POLL=1 JGX_WRAM_DUMP=0x477 JGX_WRAM_DUMP_LEN=5`,
asserting `state` at `0x47b` reaches `2`):

```
jgxcheck: JGX_POLL matched at frame 9376 of 24000 budgeted
jgxcheck: WRAM @0x477: C9 3B 00 01 02
                       ^^^^^ ^^ ^^ ^^
                     z=0x3BC9  |  |  state=2 (VERIFIED)
                        15305  |  ok=1
                            work=0
SMOKE: PASS off=0x47B len=1 got=0x02 (ran 24000 frames, bsnes-jg)
```

**PASS** — every field of the record decodes as designed, and `z = 15305` is `oracle[0]`, the value
the *host* compressor produced for `great-wave`. The match at frame 9 376 is the measured cold-boot
budget.

**And the negative case — a one-byte oracle corruption must be caught.** Same fixture with
`oracle[0]` edited `15305 → 15304`:

```
  lzss-gallery     FAIL  live-record: Under the Wave off Kanagawa: repacked 15305 B, host oracle says 15304 B

verify-web-roms: 0 passed, 1 failed, 0 missing
FAILED: lzss-gallery
```

**PASS (as a negative test)** — this is the regression guard for the whole chain. It proves the
replay is genuinely comparing the ROM's number against the host table rather than passing on
liveness, it names the artwork the visitor was looking at, and it is the exact failure a stale
`oracle[]` after a corpus regeneration would produce.

9. **The oracle table is generated, not hand-written** — `dev/sync-manifest-offsets.py` against a
   fixture site whose ROM is byte-identical to the built one.

```
=== --check (expect drift, exit 1) ===
  oracle-fixture   gallery_shown      off 0x0 -> 0x477
  oracle-fixture   oracle             table 0 -> 62 entries (regenerated)
  oracle-fixture   titles             table 0 -> 62 entries (regenerated)

1 offset(s) changed, 0 unchanged, 2 table(s) regenerated, 0 without a map
EXIT=1

=== write ===
wrote .../manifest.json
EXIT=0

=== --check again (expect clean, exit 0) ===

0 offset(s) changed, 1 unchanged, 0 table(s) regenerated, 0 without a map
EXIT=0

=== resulting entry ===
off      = 0x477
oracle   = 62 entries; first 4 = [15305, 14879, 14986, 15234]
titles   = 62 entries; first 2 = ['Under the Wave off Kanagawa', 'A Sunday on La Grande Jatte — 1884']
```

**PASS** — `oracle[0] = 15305` is `great-wave`, the value this plan already recorded as work 0's
answer; `oracle[3] = 15234` is `basket-apples`, matching the work‑3 figure in the 40 000-frame
evidence above. That agreement is also the proof that `report.json`'s array order is
`GALLERY_ASSETS`' order, which is what makes `oracle[work]` a legal indexing.

### Added 2026‑08‑01 — the budget, the record off work 0, and the reproducible build

10. **`frames: 24000` covers all 62 works, not just the three it was sized on.**

The budget above was extrapolated from works 0–2 with a hand-waved "headroom for the corpus's
larger and denser works". That is the same shape of reasoning that left `frames` at 200000 through
five corpus expansions, so it is now computed and re-runnable:
**[`dev/measure-repack-budget.py`](../../dev/measure-repack-budget.py)**.

Reading `gallery_repack_frames[]` for all 62 works off the target costs a ~620 000-frame bsnes-jg
sweep (≈3 h) and has to be redone on every corpus regeneration. It is not necessary. `compress_far`
is a deterministic function of the decoded image, and the decoded image *is* the `.idx` the host
packer produced — so the work the 65816 will do can be counted on the host. Two things make that
trustworthy rather than plausible:

- **The re-implementation must reproduce the encoder's output before it is allowed to talk about
  its runtime.** All 62 simulated stream sizes equal `report.json`'s `compressed_bytes` exactly.
- **The result is a bound, not a fit.** Cost is counted in five classes (raw bytes, tokens, chain
  steps, byte compares, outer groups). `compress_far` is `optnone` straight-line C, so its frame
  cost is *some* non-negative linear combination of those counts — and for **any** such
  combination, `cost(k)/cost(0)` is bounded by the largest per-class ratio. One measured work
  therefore calibrates a bound over all 62 without knowing the per-class constants.

```
corpus: 62 works from assets/snes/lzss-gallery/derived
encoder self-validation: PASS (62/62 works reproduce report.json compressed_bytes exactly)

anchor: k=0 great-wave repack=8169 verify=336 frames (measured)
per-class envelope over the corpus (max_k class_k / class_anchor):
  raw     1.0306  at k=21 (houses-parliament)
  tokens  1.1772  at k=22 (thistles)
  chain   1.1731  at k=22 (thistles)
  cmpb    1.1266  at k=8 (earthly-delights)
  outer   1.1766  at k=22 (thistles)
envelope bound = 1.1772 (binding class: tokens) -- valid for ANY non-negative linear cost model

worst-case cold-boot frame at which gallery_shown.state reaches VERIFIED:
  splash + hold(60)        558   (does not scale with the artwork)
  unpack+stage+near        330   (<= 1.0306 x anchor)
  repack                  9616   (<= 1.1772 x anchor)
  verify                   375   (<= 1.1156 x anchor)
  TOTAL                 10879

validation against works measured on the target (built -DGALLERY_START=k):
  k=22  thistles           repack 9352 <= 9616 OK  | poll 10617 <= 10879 OK
  k=8   earthly-delights   repack 9023 <= 9616 OK  | poll 10253 <= 10879 OK

budget 24000 frames -> margin 2.21x (45.3% of budget used by the worst case)
PASS: 24000 frames covers every work in the corpus.
```

**PASS** — no work in the corpus can reach `VERIFIED` later than frame **10 879**, so 24 000 carries
a **2.21×** margin against the worst case rather than 2.56× against work 0. The script exits 1 if a
corpus regeneration ever breaks that, which is the point: the budget stops being a number somebody
has to remember to re-derive.

11. **The record is correct for a work that is not work 0** — every previous run verified
    `great-wave`, so nothing had yet exercised `oracle[work]` at a non-zero index.

The two validation works above were chosen as the argmax of two different cost predictors
*before* being measured, built with `-DGALLERY_START=k`, and polled from cold boot with
`JGX_POLL=1` against `gallery_shown.state`:

```
=== k=22  gallery_shown=0x477  state=0x47b  budget 24000 ===
jgxcheck: JGX_POLL matched at frame 10617 of 24000 budgeted
SMOKE: PASS off=0x47B len=1 got=0x02 (ran 24000 frames, bsnes-jg)
  gallery_shown         = z=17075 work=22 ok=1 state=2      oracle[22]=17075  MATCH
  gallery_repack_frames[22] = 9352   gallery_verify_frames[22] = 357

=== k=8   gallery_shown=0x477  state=0x47b  budget 24000 ===
jgxcheck: JGX_POLL matched at frame 10253 of 24000 budgeted
SMOKE: PASS off=0x47B len=1 got=0x02 (ran 24000 frames, bsnes-jg)
  gallery_shown         = z=16473 work=8  ok=1 state=2      oracle[8]=16473   MATCH
  gallery_repack_frames[8]  = 9023   gallery_verify_frames[8]  = 353
```

**PASS** — `work` names the artwork actually on screen (22 and 8, agreeing with
`gallery_current_asset` in both dumps), and `z` equals that artwork's *own* host oracle entry.
The lookup `oracle[work]` is what is being exercised here, not a constant that happens to be
`oracle[0]`; a player that ignored `work` and compared against `oracle[0]` would report
`✗ MISMATCH` on both of these runs.

12. **The ROM now builds reproducibly** — `dev/lzss-gallery.sh`'s relink-once check, on the
    toolchain carrying `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch`, with the
    `gallery_shown` record present:

```
==> reproducible-build check (relink and compare)
reproducible build: PASS (5768147529a4d147fc497e25dea5a2071816f4f46eaa324a868f9d02fbf3a95d)
RESULT: PASS — 62-work LZSS gallery host oracle, relink, header and bsnes-jg gate
```

**PASS**, and it is the precondition the whole rollout was blocked on: `dev/sync-manifest-offsets.py`
refuses to trust a link map unless `build/<slug>.sfc` is byte-identical to the shipped ROM, and
before 0021 that comparison was a coin flip. The same run re-confirms the record is additive —
`corpus_result 0x46f`, `gallery_progress 0x471`, `gallery_current_asset 0x472`,
`gallery_last_z 0x473`, `gallery_last_work 0x475`, `gallery_last_ok 0x476` are all unmoved, with
`gallery_shown` at `0x477` size 5 — and that all 62 works still decode (`corpus_result 0x5CF0`).

13. **Badge states — which are exercisable without the player release, and which are not.**

The end-to-end chain, on a fixture site whose ROM is the merged, 0021-built one, with `off` and
the 62-entry tables generated by `dev/sync-manifest-offsets.py`:

```
=== --check (expect drift, exit 1) ===
  lzss-gallery     gallery_shown      off 0x0 -> 0x477
  lzss-gallery     oracle             table 0 -> 62 entries (regenerated)
  lzss-gallery     titles             table 0 -> 62 entries (regenerated)
1 offset(s) changed, 0 unchanged, 2 table(s) regenerated, 0 without a map        EXIT=1
=== write, then --check again ===
0 offset(s) changed, 1 unchanged, 0 table(s) regenerated, 0 without a map        EXIT=0
off = 0x477   oracle[0,8,22] = [15305, 16473, 17075]   titles[22] = Thistles

  lzss-gallery     PASS  (24000 frames, Under the Wave off Kanagawa: repacked on-SNES to 15305 B == host oracle)
verify-web-roms: 1 passed, 0 failed, 0 missing
ALL PASS — safe to publish
```

`oracle[8]` and `oracle[22]` are the values the ROM independently published in step 11 — the
generator and the target agree without either consulting the other.

The badge *decisions* are one three-branch comparison, and `record_check()` in
`dev/verify-web-roms.sh` runs the identical one. Driving it with synthetic records (the checker
extracted verbatim from the script so the exercise cannot drift from it):

```
  PASS  thistles k=22 ok=1           exit=0  Thistles: repacked on-SNES to 17075 B == host oracle
  PASS  great-wave k=0 ok=1          exit=0  Under the Wave off Kanagawa: repacked on-SNES to 15305 B == host oracle
  MISMATCH k=22 z off by one         exit=1  Thistles: repacked 17074 B, host oracle says 17075 B
  FAILED  k=22 ok=0                  exit=1  Thistles: the ROM's own byte-compare rejected its repack (ok=0)
  NOT READY state=PENDING            exit=1  record never reached ready (state=1)
  NOT READY state=NONE (power-on)    exit=1  record never reached ready (state=0)
```

And budget exhaustion, by replaying the same fixture with `frames: 500` — an order of magnitude
below the ~9 400-frame cold-boot cost:

```
  lzss-gallery     FAIL  live-record: record never reached ready (state=0)
verify-web-roms: 0 passed, 1 failed, 0 missing
```

| badge state | exercisable now? | evidence / what it needs |
|---|---|---|
| `pass` **✓ FIDELITY** | **YES** | fixture replay above, real ROM, real oracle table |
| `fail` **✗ MISMATCH** | **YES** | one-byte oracle corruption (step 8) and the synthetic record above |
| `fail` **✗ FAILED** (`ok≠1`) | **decision YES, ROM-side no** | the branch fires with the right message; producing `ok=0` from the ROM needs a deliberately broken build — the pre-fix ROM was exactly that and read `gallery_last_ok = 0` (*Findings 2026‑07‑28*) |
| `warn` **⏱ still verifying** | **condition YES, badge NO** | budget exhaustion reproduces headlessly, but the gate renders it **FAIL**, not `warn`. Correct for a gate (a check that could not confirm must not pass); the indeterminate rendering is browser-only |
| `running` "verifying…" / "verifying *T*… n/N" | **NO** | transient per-chunk state; `jgxcheck` polls internally and never surfaces it |
| `running` "following your navigation to *T*" | **NO** | needs live pad/keyboard input into a running machine mid-check |
| `fail` "navigation kept restarting the check" | **NO** | needs two navigations inside one check |

**PARTIAL — and the blocker is not the ROM.** Everything the ROM and the manifest owe the button
is verified. The four unexercised rows are all *player-runtime* behaviour, and they need the
package release (step 6), which is user-gated.

> **Found while doing this: the badge has never been styled.** `SnesPlayer.astro` renders
> `<span id="checkresult" class="rp-badge">` and biohack.net styles `.rp-badge.pass` /
> `.rp-badge.fail` / `.rp-badge.running` — but `badge()` in `app.js` assigns
> `checkEl.className = "badge " + cls`, which **replaces** `rp-badge`. No `.badge` rule exists
> anywhere on the site (`src/styles/{global,snes-page}.css`), so the green PASS pill and the red
> FAIL pill have never applied, on any demo page. This is **pre-existing** — the released `app.js`
> at biohack.net `HEAD` does the same at lines 247/265/268 — and not something `live-record`
> introduced. It does change the shape of the remaining work: this plan asks for a third `warn`
> class, but adding `.rp-badge.warn` alone would style nothing. The fix is `badge()` writing
> `rp-badge`, which belongs with the player release.

### Incidental finding — the gallery ROM does not build reproducibly (PRE-EXISTING, not this change)

> **RESOLVED 2026‑08‑01.** Root-caused and fixed upstream: `MOSZeroPageAlloc` broke benefit ties
> for zero-page placement in heap-address order, so identical sources produced one of two stable
> images. `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch` makes that container a
> `MapVector`; `dev/lzss-gallery.sh` gained the relink-once check whose PASS is step 12 above.
> The scoping below stands as the record of how it was narrowed.

Confirming that the gated ROM is what the final source builds turned up something else:
`examples/snes/lzss-gallery.c` compiles to **two different ROM images**, roughly 50/50 across
repeated identical invocations.

```
=== 6 builds of UNMODIFIED main-HEAD lzss-gallery.c (git show HEAD:…) ===
  base build 1: ff4071716ba4      base build 4: ff4071716ba4
  base build 2: cad7bfccffb5      base build 5: ff4071716ba4
  base build 3: cad7bfccffb5      base build 6: cad7bfccffb5
      3 cad7bfccffb5
      3 ff4071716ba4
```

Scoped as far as three hypotheses allow, then stopped:

- **Not introduced by this change** — reproduced on `git show HEAD:examples/snes/lzss-gallery.c`,
  the unmodified source.
- **Not linker parallelism** — `-Wl,--threads=1` and `-Wl,--thinlto-jobs=1` both still produce two
  distinct outputs.
- **Not ASLR** — `setarch -R` still produces two distinct outputs, which also rules out the usual
  pointer-keyed-container iteration-order explanation in its simplest form.
- **Not host-vs-Docker** — the Docker gate's artifact (`aa3b7f27…`, the sha the gate log prints)
  is byte-identical to one of the two host outputs.

**Why it does not invalidate anything above.** The two variants have **identical symbol addresses**
— diffing the two link maps over every `gallery_*`/`corpus_result` symbol reports no difference —
so every WRAM address in this plan, `gallery_shown` at `0x477`, and `dev/sync-manifest-offsets.py`'s
`off` resync are unaffected. The divergence is code bytes only (a 2-byte size difference cascading
into ~19.5 KB of shifted addresses). And the publish flow builds once and gates *that* artifact, so
it cannot ship an ungated variant; what breaks is only "rebuild later and compare bytes".

**Severity: reproducibility, not correctness — but it deserves its own item.** `dev/lzss-gallery.sh`
prints a `sha256sum` as though it were reproducible, and `dev/sync-manifest-offsets.py` gates on
`build/<slug>.sfc` being byte-identical to the shipped ROM, which will intermittently refuse (it
fails *safe* — it declines to resync rather than resyncing wrongly). Root-causing it means bisecting
the responsible pass; not attempted here.

## Findings — 2026-07-28 (why this is blocked)

Reading the intended field produced a blocking result. At frame 9000:

```
gallery_last_work = 0x00     work 0 (great-wave / Hokusai)
gallery_last_ok   = 0x00     FAILED
gallery_last_z    = 0x3B96   15254 bytes
GALLERY_ASSETS[0].lz_len     15305 bytes  (0x3BC9)
```

### Ruled out

- **"The images were never palette-remapped."** They were. Both `3e3f054` (223-colour) and
  `dcc80d9` (221-colour, 2026-07-28 08:10) regenerated `.idx`, `.lz`, `.pal`,
  `examples/snes/lzss-gallery-assets.h` **and** `assets/snes/lzss-gallery/derived/report.json` in
  the same commit. There is no asset-vs-oracle regeneration desync.
- **A stale or mismatched oracle.** The ROM does not consult `report.json`; it compares against its
  own embedded `lz_len`. Those agree: `GALLERY_ASSETS[0]` is `great_wave` at 15305, and
  `report.json[0]` is `great-wave` at 15305. Host side is self-consistent.
- **Comparing the wrong artwork.** `report.json`'s `manifest_order` is 1-based, which raised the
  possibility that ROM index `k=0` was some other painting — but the header's array order matches
  `report.json`'s array order, and **no artwork in the 62-work corpus compresses to 15254**, so
  15254 is not some other entry's correct answer.
- **A truncated/cancelled compress.** `compress_far` returns **0** on `nav_cancel`
  (`lzss-gallery.c:527,533,553`), and `verify_stream` short-circuits on `z==0`. A non-zero 15254 is
  therefore a *complete* compression run, not a partial one.

### Second-pass probe — 2026-07-28 (supersedes the first hypothesis)

An earlier revision of this section claimed work 0 skips `unpack_slide` and repacks a stale `FB_A`.
**That is wrong and is retracted.** Work 0 *is* decoded, by `ok = unpack_slide(a)` behind the title
card (`lzss-gallery.c:1167`), before the loop is entered with `decoded = 1`.

Two probes on the shipped ROM (`build/jgxcheck`, `JGX_WRAM_DUMP`):

**1. Stage counters for work 0, at 9000 frames** (`gallery_*_frames[0]`, one entry per array
non-zero — only work 0 had run):

```
unpack_frames[0] @0x2FA =  127 frames
stage_frames[0]  @0x376 =   52 frames
near_frames[0]   @0x3F2 =  118 frames
```

`unpack_slide` short-circuits with `||`, so reaching `benchmark_near_decode` proves
`benchmark_far_decode` **and** `benchmark_stage` both returned 1 — each of which requires
`!nav_cancel`. **The decode pipeline ran in full; nothing bailed early on spurious input.** The
failure is therefore one of the three data-mismatch conditions: `near_ok`, or either
`fold_far(FB_A/FB_B, raw_len) != a->checksum`.

**2. Per-work verdicts at 40 000 frames** (`gallery_failed[62]` @ `0xdfe`, `gallery_done[62]` @
`0xe3c`, contiguous — one 124-byte dump):

```
done[k]   : 1111000000...      4 works completed
failed[k] : 1011000000...
failed: [0, 2, 3]      passed: [1]
```

**This is not work-0-specific — 3 of the first 4 artworks fail their own repack differential.**
The title-path explanation is dead: works 1–3 decode inside the loop, with the splash long gone.

### What still holds

- `record_result` rewrites `gallery_last_z` on every completed work while `gallery_progress` only
  increments when `gallery_done[k]` is clear, so one `k` can be recorded twice with `progress`
  unchanged — the explanation for the `0x3B96` → `0x3B98` drift.
- 15254 is **99.7%** of 15305. Garbage or zeros would compress to a fraction of that, so `FB_A`
  holds a *nearly* correct image with a small corruption — and the run-to-run drift makes that
  corruption timing-dependent.

### Open question — ANSWERED 2026‑07‑31: demo bug

> Three of four works failing a byte-exact differential is either a genuine miscompile in the far
> decode / LZSS path (which is exactly the class this demo exists to catch) or a demo-level buffer
> bug.

**It was the demo — a hand-written assembly ABI violation, not a `+mos-a16` miscompile.** The
codegen is correct throughout; it faithfully implemented the A:X argument convention that the
thunk then violated. Re-verified independently before landing (`2932bcf`):

- **The ABI, read off the shipped ROMs.** Caller `benchmark_near_decode` ends
  `ldx $9 (__rc9) / lda $8 (__rc8) / jsr decode_bank7e`; callee `decode_near` opens
  `sta $28 / stx $29`. So `slen` genuinely travels in `A:X`, low byte in A. The pre-fix thunk sat
  between them executing `lda #$7e`, destroying A before the callee read it.
- **The model predicts rather than describes.** `slen_effective = (lz_len & 0xFF00) | 0x7E` fails
  exactly when `(lz_len & 0xFF) > $7E`. That forecasts **29 of 62** works corpus-wide (matching the
  independently reported count) and reproduces the per-work outcome for works 0–3 — `FAIL, pass,
  FAIL, FAIL`, **4/4 correct**. For work 0 it predicts the decode starves at `sp = 15230`, matching
  the recorded host trace exactly.
- **The gate discriminates.** Rebuilt from source, 62 works, bsnes-jg, 30 000 frames:
  fixed ROM → `corpus_result 0x5CF0` (all pass); pre-fix control → `0xA50F` (failure latched).

The "timing-dependent" clue was a red herring, as the banner at the top of this document records.

Note: the `decode_near` / `FB_A`‑`FB_B` / NMI‑DBR machinery that a later handoff described as
uncommitted work-in-progress was **already committed on `main`**; the only uncommitted delta was
the 31-line thunk fix itself.

Note: `dev/lzss-gallery.sh`'s offline gate is being raised 200000 → 700000 in parallel by another
worker (uncommitted at the time of writing), with an independently measured ~10k frames/work that
agrees with the ~9.1k measured here. That fixes the *budget*, not this correctness failure.

## Note on scope

This does not fix, and does not claim to fix, the two pre-existing gate failures found on
2026-07-28: `lzss-gallery`'s selfcheck (this plan) and `lsystem`'s BLANKSCAN (one frame with a
transient black band at the top — force-blank bleed, still unexamined). Neither was introduced by
that day's republish. *(Both since resolved elsewhere: the selfcheck failure was the
`decode_bank7e` A-clobber, fixed `2932bcf`; the BLANKSCAN flag was a detector false positive,
quiescence guard adopted `5587462`.)*

## Status (2026-07-31)

- **Interim selfcheck is live**: the republished gallery ships `selfcheck.symbol: gallery_last_z`,
  `want 0x3BC9` (work 0's exact host byte count), `frames 12000` — a genuine codec correctness
  assertion replacing the structurally broken `corpus_result/200000` entry.
- **ROM half of `live-record` done** on `feature/verify-fidelity-button` @ `f0d903d` (unmerged
  pending the post-republish window): `gallery_shown{z,work,ok,state}` record with verified store
  ordering, `JGX_POLL` harness, `verify-web-roms` live-record replay, oracle/titles generation in
  `sync-manifest-offsets.py`.
- **Player half in progress** in `~/bsnes-jg-wasm` (implement+test authorized; release/sync not
  yet): scenarios A (PASS badge), B (mismatch FAIL), C (warn/timeout) exercised; D
  (re-target-once) blocked on headless keyboard input reaching the emulator — being retried via
  direct pad injection; will land as an honest partial if the input harness cannot drive it.
- **Rollout chain**: player release + site sync → merge button branch → gallery republish with
  `gallery_shown` → manifest flips to `mode: "live-record"` with the 62-entry oracle table.

## Status (2026-08-01)

- ~~**ROM half unmerged**~~ — **merged to `main`.** The branch was rebased onto `main` and
  fast-forwarded; `f0d903d` above is the pre-rebase SHA and no longer exists.
- ~~**`frames: 24000` extrapolated from three works**~~ — **confirmed corpus-wide** (verification
  step 10). Worst case is frame 10 879 of 24 000; the check is `dev/measure-repack-budget.py` and
  it fails loudly if a corpus regeneration ever breaks it.
- ~~**The gallery ROM does not build reproducibly**~~ — **fixed** by
  `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch`; `dev/lzss-gallery.sh` reports
  `reproducible build: PASS` for the record-carrying ROM (verification step 12). This was the
  precondition for `dev/sync-manifest-offsets.py` to be trusted, and therefore for the manifest to
  be wired at all.
- ~~**`oracle[work]` only ever exercised at `work == 0`**~~ — **exercised at 22 and 8**
  (verification step 11), each matching that artwork's own host oracle entry.

### Still open

- **Player package release.** `~/bsnes-jg-wasm` carries a `verifyLiveRecord` implementation
  matching the contract above, and `~/biohack.net/public/play/app.js` is byte-identical to that
  repo's `dist/engine/app.js` — but **neither is committed**, `public/play/ENGINE_VERSION` still
  stamps the previous `app.js` sha256, and no version has been published. **USER-GATED.**
- **The badge is unstyled, and has been all along.** `SnesPlayer.astro` renders
  `<span id="checkresult" class="rp-badge">`, and biohack.net styles `.rp-badge.pass` /
  `.rp-badge.fail` / `.rp-badge.running` — but `badge()` in `app.js` assigns
  `checkEl.className = "badge " + cls`, which *replaces* `rp-badge`. No `.badge` rule exists
  anywhere on the site, so the green PASS pill and red FAIL pill have never applied on any demo
  page. **Pre-existing** (the released `app.js` at biohack.net HEAD does the same at lines
  247/265/268) and not introduced by `live-record` — but it means the `warn` class this plan asks
  for is only half the gap: `warn` needs a rule *and* the class name needs to be `rp-badge`.
  Fixing it belongs with the player package release.
- **Gallery republish.** The manifest still carries the interim work‑0 scalar entry. Flipping it
  to `mode: "live-record"` needs the republished ROM (`sync-manifest-offsets.py` gates on the
  built ROM being byte-identical to the shipped one) *and* a player that understands `mode`.
