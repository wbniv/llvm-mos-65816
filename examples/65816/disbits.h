// Shared, PURE cross-byte-boundary bitfield decoder — host-linkable, no hardware.  Demo #52.
//
// The codegen corner: **bitfields that straddle byte boundaries** inside a uint32_t.  A 65816
// instruction descriptor packs opcode:8, mode:3, len:2, group:5, cycles:4, flags:7, rmw:1 across a
// 32-bit word — several fields (group at bits 13-17 crosses the byte-1/2 boundary at bit 16; flags at
// bits 22-28 crosses byte-2/3 at bit 24) force MULTI-BYTE shift + mask to extract and read-modify-write
// to insert.  Distinct from #29b (truchet), whose fields all fit one uint16.  A "live disassembler"
// decodes an opcode byte-stream into these fields.
//
// Differential safety: the gate folds the READ-BACK FIELD VALUES (not the raw storage), so it is
// independent of the (implementation-defined) physical bit layout — yet a cross-byte insert that
// corrupts a neighbouring field would still diverge host vs target.  Width: fields are uint32_t;
// the fold masks to uint16_t.
// See docs/plans/2026-06-30-52-snes-disbits.md.
#ifndef DISBITS_H
#define DISBITS_H

#include <stdint.h>

typedef struct {
    uint32_t opcode : 8;   // bits  0- 7
    uint32_t mode   : 3;   // bits  8-10
    uint32_t len    : 2;   // bits 11-12
    uint32_t group  : 5;   // bits 13-17  (straddles the byte-1/2 boundary at bit 16)
    uint32_t cycles : 4;   // bits 18-21
    uint32_t flags  : 7;   // bits 22-28  (straddles the byte-2/3 boundary at bit 24)
    uint32_t rmw    : 1;   // bit  29
    uint32_t pad    : 2;   // bits 30-31
} Instr;

// Decode one opcode byte + operand byte into the packed instruction descriptor (insert path — the
// straddling fields need read-modify-write across bytes).
static void dis_decode(Instr *in, uint8_t op, uint8_t operand) {
    in->opcode = op;
    in->mode   = (uint8_t)(op & 7u);
    in->len    = (uint8_t)((op >> 3) & 3u);
    in->group  = (uint8_t)((op >> 3) & 31u);            // 5-bit, straddling field
    in->cycles = (uint8_t)((operand >> 1) & 15u);
    in->flags  = (uint8_t)(operand & 127u);             // 7-bit, straddling field
    in->rmw    = (uint8_t)((op >> 7) & 1u);
    in->pad    = 0u;
}

// Read the descriptor back (extract path) and fold every field so a cross-byte corruption diverges.
static uint16_t dis_fold_fields(const Instr *in) {
    uint16_t v = 0;
    v = (uint16_t)(v + in->opcode);
    v = (uint16_t)((v << 1) + in->mode);
    v = (uint16_t)((v << 1) + in->len);
    v = (uint16_t)((v << 1) + in->group);               // straddling extract
    v = (uint16_t)((v << 1) + in->cycles);
    v = (uint16_t)((v << 1) + in->flags);               // straddling extract
    v = (uint16_t)((v << 1) + in->rmw);
    return v;
}

// ---------------------------------------------------------------------------------------------
// Differential gate: decode a synthetic opcode stream and fold every decoded field.

static inline uint16_t db_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 128u
#endif

static uint16_t disbits_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        Instr in;
        uint8_t op      = (uint8_t)(i * 7u + 3u);
        uint8_t operand = (uint8_t)(i * 13u + 5u);
        dis_decode(&in, op, operand);
        h = db_fold(h, dis_fold_fields(&in));
    }
    return h;
}

#endif /* DISBITS_H */
