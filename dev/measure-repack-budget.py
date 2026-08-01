#!/usr/bin/env python3
"""Bound the gallery "Verify fidelity" frame budget across the whole 62-work corpus.

The button's manifest entry carries `frames` — the number of frames the player is willing to
poll `gallery_shown.state` before giving up and showing the indeterminate badge. Sizing it
needs the WORST work in the corpus, but reading `gallery_repack_frames[]` for all 62 works out
of the ROM costs a ~620 000-frame bsnes-jg sweep (~3 h), and it has to be redone every time the
corpus is regenerated. That is exactly the maintenance cost that left `frames` at 200000 through
five corpus expansions.

So compute it on the host instead. `compress_far()` in examples/snes/lzss-gallery.c is a
deterministic function of the decoded image, and the decoded image is the `.idx` file the host
packer produced. Re-running the same algorithm here counts the work the 65816 will do.

  SELF-VALIDATION. The re-implementation is not trusted on inspection: it must reproduce
  `compressed_bytes` from derived/report.json for all 62 works, byte-exactly, or this script
  fails. A cost model that disagrees with the real encoder about its OUTPUT has no business
  making claims about its RUNTIME.

  THE BOUND. Per-work cost is counted in five classes -- raw bytes, tokens emitted, hash-chain
  steps walked, bytes compared, and outer 8-token groups. `compress_far` is `optnone` straight-
  line C, so its frame cost is a non-negative linear combination of those counts (whatever the
  per-class constants are). For ANY such combination, cost(k)/cost(0) is bounded by the largest
  per-class ratio max_k class_k / class_0 -- so one measured work calibrates a bound over all 62
  without needing to know the constants. That is why this is a bound and not a fit.

Usage:
  dev/measure-repack-budget.py                 # check the shipped 24000-frame budget
  dev/measure-repack-budget.py --budget 18000  # check a different budget
  dev/measure-repack-budget.py --top 10        # also list the 10 costliest works

Exits 1 if the corpus-wide worst case no longer fits the budget, or if the encoder
re-implementation stops reproducing report.json.
"""
import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DERIVED = ROOT / "assets/snes/lzss-gallery/derived"

# ---------------------------------------------------------------------------
# Calibration: frames measured on the target, bsnes-jg, from gallery_*_frames[k].
#
# ANCHOR is work 0 (great-wave) -- the work every ratio below is expressed against, and the one
# the headless `?verify=1` path always lands on.
ANCHOR_K = 0
ANCHOR_REPACK_FRAMES = 8169     # gallery_repack_frames[0]
ANCHOR_VERIFY_FRAMES = 336      # gallery_verify_frames[0]
ANCHOR_PREPARE_FRAMES = 144 + 53 + 123   # unpack + stage + near, work 0
# Splash + hold(60) before the first repack can start. Measured 536 (k=8) and 558 (k=22) on
# cold-boot JGX_POLL runs; take the larger. This part does not scale with the artwork.
COLD_BOOT_OVERHEAD = 558

# Independent validation points: (k, measured gallery_repack_frames[k], measured poll frame).
# Both were chosen BEFORE measuring, as the argmax of two different predictors, and both were
# then built with -DGALLERY_START=k and polled from cold boot.
VALIDATION = [(22, 9352, 10617), (8, 9023, 10253)]

CLASSES = ("raw", "tokens", "chain", "cmpb", "outer")


def compress_far(src):
    """Re-implementation of compress_far() from examples/snes/lzss-gallery.c.

    Returns (compressed_size, counts). HEAD/PREV are sized and masked exactly as the ROM's
    (HEAD[256] pre-filled 0xffff; PREV[4096] indexed by position & 4095, never read before it
    has been written for a position reachable from HEAD).
    """
    n = len(src)
    head = [0xFFFF] * 256
    prev = [0] * 4096
    pos = op = tokens = chain = cmpb = outer = 0

    def h(p):
        if p + 2 >= n:
            return 0
        return ((src[p] * 31) & 0xFF) ^ ((src[p + 1] * 17) & 0xFF) ^ src[p + 2]

    while pos < n:
        outer += 1
        op += 1                                  # flag byte
        for _ in range(8):
            if pos >= n:
                break
            p = head[h(pos)]
            best = distbest = seen = 0
            while p != 0xFFFF and ((pos - p) & 0xFFFF) <= 4095 and seen < 64:
                chain += 1
                m = 0
                while m < 18 and pos + m < n and src[p + m] == src[pos + m]:
                    cmpb += 1
                    m += 1
                cmpb += 1                        # the comparison that ends the run
                dist = (pos - p) & 0xFFFF
                if m >= 3 and (m > best or (m == best and dist < distbest)):
                    best, distbest = m, dist
                p = prev[p & 4095]
                seen += 1
            if best >= 3:
                op += 2
                advance = best
            else:
                op += 1
                advance = 1
            tokens += 1
            for j in range(advance):
                q = pos + j
                hv = h(q)
                prev[q & 4095] = head[hv]
                head[hv] = q
            pos += advance
    return op, {"raw": n, "tokens": tokens, "chain": chain, "cmpb": cmpb, "outer": outer}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--budget", type=int, default=24000,
                    help="manifest selfcheck.frames to check (default: 24000)")
    ap.add_argument("--top", type=int, default=0, help="also list the N costliest works")
    args = ap.parse_args()

    report = json.loads((DERIVED / "report.json").read_text())
    rows = []
    bad = []
    for k, w in enumerate(report):
        idx = (DERIVED / f"{w['slug']}.idx").read_bytes()
        z, counts = compress_far(idx)
        if z != w["compressed_bytes"] or len(idx) != w["raw_indexed_bytes"]:
            bad.append(f"{k}:{w['slug']} sim z={z} report z={w['compressed_bytes']}")
        rows.append({"k": k, "slug": w["slug"], "z": z, **counts})

    print(f"corpus: {len(rows)} works from {DERIVED.relative_to(ROOT)}")
    if bad:
        print("FATAL: the compress_far re-implementation no longer reproduces report.json:")
        for b in bad[:5]:
            print(f"  {b}")
        return 1
    print(f"encoder self-validation: PASS ({len(rows)}/{len(rows)} works reproduce "
          f"report.json compressed_bytes exactly)")

    anchor = rows[ANCHOR_K]
    print(f"\nanchor: k={ANCHOR_K} {anchor['slug']} "
          f"repack={ANCHOR_REPACK_FRAMES} verify={ANCHOR_VERIFY_FRAMES} frames (measured)")
    print("per-class envelope over the corpus (max_k class_k / class_anchor):")
    bound, binding = 0.0, ""
    for c in CLASSES:
        ratios = [(r[c] / anchor[c], r) for r in rows]
        mx, arg = max(ratios, key=lambda t: t[0])
        print(f"  {c:<7} {mx:.4f}  at k={arg['k']} ({arg['slug']})")
        if mx > bound:
            bound, binding = mx, c
    print(f"envelope bound = {bound:.4f} (binding class: {binding}) -- valid for ANY "
          f"non-negative linear cost model")

    repack_max = bound * ANCHOR_REPACK_FRAMES
    len_r = max(r["raw"] / anchor["raw"] for r in rows)
    verify_r = max(max(r["raw"] / anchor["raw"], r["z"] / anchor["z"]) for r in rows)
    worst = (COLD_BOOT_OVERHEAD + len_r * ANCHOR_PREPARE_FRAMES
             + repack_max + verify_r * ANCHOR_VERIFY_FRAMES)

    print(f"\nworst-case cold-boot frame at which gallery_shown.state reaches VERIFIED:")
    print(f"  splash + hold(60)   {COLD_BOOT_OVERHEAD:>8.0f}   (does not scale with the artwork)")
    print(f"  unpack+stage+near   {len_r * ANCHOR_PREPARE_FRAMES:>8.0f}   (<= {len_r:.4f} x anchor)")
    print(f"  repack              {repack_max:>8.0f}   (<= {bound:.4f} x anchor)")
    print(f"  verify              {verify_r * ANCHOR_VERIFY_FRAMES:>8.0f}   (<= {verify_r:.4f} x anchor)")
    print(f"  {'TOTAL':<18} {worst:>8.0f}")

    ok = True
    if VALIDATION:
        print("\nvalidation against works measured on the target (built -DGALLERY_START=k):")
        for k, meas_repack, meas_poll in VALIDATION:
            v1 = "OK " if meas_repack <= repack_max else "VIOLATED"
            v2 = "OK " if meas_poll <= worst else "VIOLATED"
            print(f"  k={k:<3} {rows[k]['slug']:<18} repack {meas_repack} <= {repack_max:.0f} {v1} "
                  f"| poll {meas_poll} <= {worst:.0f} {v2}")
            ok = ok and meas_repack <= repack_max and meas_poll <= worst

    if args.top:
        print(f"\ntop {args.top} works by hash-chain work (the dominant repack term):")
        for r in sorted(rows, key=lambda r: -r["chain"])[:args.top]:
            print(f"  k={r['k']:<3} {r['slug']:<22} chain={r['chain']:<8} tokens={r['tokens']:<6} "
                  f"raw={r['raw']:<6} z={r['z']}")

    print(f"\nbudget {args.budget} frames -> margin {args.budget / worst:.2f}x "
          f"({worst / args.budget * 100:.1f}% of budget used by the worst case)")
    if worst > args.budget:
        print(f"FAIL: the corpus-wide worst case ({worst:.0f}) exceeds selfcheck.frames "
              f"({args.budget}). Raise `frames` in the manifest entry.")
        return 1
    if not ok:
        print("FAIL: a measured work exceeded the bound -- the cost model is wrong, not the budget.")
        return 1
    print(f"PASS: {args.budget} frames covers every work in the corpus.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
