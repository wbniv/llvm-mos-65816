// zerobank_probe.c — adversarial best-case shapes for a HYPOTHETICAL zero-bank
// (AS4) far pointer, used by dev/measure-zerobank-census.sh to show that each
// shape collapses to the incumbent "a plain near pointer (+ on-demand near->far
// cast)". This is a MEASUREMENT fixture (compiled + disassembled), not a runnable
// differential test — AS4 is not built, so the "zero-bank" column is argued from
// the datalayout (-p4:16:8, byte-identical to near's -p0:16:8) and from the near
// disasm below, which IS the access AS4 would emit.
//
// Plan: docs/plans/2026-06-22-320-zerobank-as4-measure-and-close.md (Phase 0b/0c).
//
// Needs a post-F2 toolchain (sizeof(far*)==4; storable far pointers). Far machinery
// is +mos-a16-gated, so compile with -Xclang -target-feature -Xclang +mos-a16.

#define FAR __attribute__((address_space(2)))

// ── Bank-0 data ─────────────────────────────────────────────────────────────
// On the SNES, bank $00 is WRAM/ZP/MMIO + the local ROM window ($8000-$FFFF).
// This data lives in the default (near, addrspace 0) space — it is reached by a
// 16-bit near pointer, never needs a 24-bit far address.
unsigned char  wram_tbl[64];               // bank-0 RAM
const unsigned char rom_msg[] = "hi";      // bank-0 ROM (.rodata)

// ── Shape 1 — a far-typed API fed bank-0 data ───────────────────────────────
// far_first() is compiled ONCE for every far pointer; it cannot know its argument
// is bank-0, so its deref uses the far path. The INCUMBENT feeds it bank-0 data
// by casting a near pointer to far on demand (the cast is a $00-bank zero-extend).
// "Monomorphizing far_first on AS4" = writing a second, non-far callee = exactly
// near_first() below, which is strictly cheaper. So AS4 buys nothing here.
unsigned char far_first(const unsigned char FAR *p) { return p[0]; }
unsigned char call_far_with_bank0(void) {
    return far_first((const unsigned char FAR *)wram_tbl);   // near->far cast at the boundary
}

// ── Shape 2 — a stored table of far pointers whose targets are ALL bank-0 ────
// The one place a smaller far-pointer storage could matter. far_tbl is 4*4 = 16 B.
// But a NEAR table (near_tbl, below) is 4*2 = 8 B AND has cheaper access — and a
// zero-bank table would also be 4*2 = 8 B (p4:16:8 == p0:16:8), i.e. byte-identical
// to near. So AS4 ties near and merely beats far; near already wins.
const unsigned char FAR *far_tbl[4] = {
    (const unsigned char FAR *)wram_tbl, (const unsigned char FAR *)rom_msg,
    (const unsigned char FAR *)wram_tbl, (const unsigned char FAR *)rom_msg,
};
unsigned char walk_far_tbl(unsigned char i) { return far_tbl[i][0]; }

// ── The incumbent: the same shapes with a plain near pointer ────────────────
const unsigned char *near_tbl[4] = { wram_tbl, rom_msg, wram_tbl, rom_msg };
unsigned char walk_near_tbl(unsigned char i) { return near_tbl[i][0]; }
unsigned char near_first(const unsigned char *p) { return p[0]; }
unsigned char read_bank0(void) { return wram_tbl[0]; }   // the canonical near access (expect `ad`)
