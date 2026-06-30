#!/usr/bin/env python3
"""a16_fuzz.py — differential fuzzer for #321 native-s16 (`+mos-a16`) codegen.

Generates random, strictly-well-defined C programs over a handful of volatile +
local 16/8-bit variables and the operator set `+ - & | ^ << >>(const) == != < <=
> >=`, plus assignments, if/else, bounded for-loops, pure noinline calls, and
arrays/pointers. Each program ends in a `volatile unsigned short corpus_result`.

For each program four independent values must agree:
  host    — computed in Python over the SAME AST with exact `& 0xFFFF` semantics
  default — compiled WITHOUT +mos-a16 (trusted 8-bit M1 reference), run in MAME
  a16     — compiled WITH    +mos-a16, run in MAME
  a16-jg  — the +mos-a16 ROM, run in the independent bsnes-jg core (if available)
Plus the +mos-a16 build is compiled under `-mllvm -verify-machineinstrs` to catch
compiler crashes / malformed MIR (the register-coalescer crash that gates Tier 2).

Any value disagreement or crash is a real defect: the .c, seed, both disasms and
the verify log are saved to build/fuzz-triage/ with a minimal repro line.

The generated C is UB-free so the differential oracle is sound:
  * arithmetic    (unsigned short)((unsigned)a OP (unsigned)b)   -> (a OP b) mod 2^16
  * unsigned shl  (unsigned short)((unsigned)x << k), k in 1..15 -> well-defined
  * unsigned shr  (unsigned short)((unsigned)x >> k)
  * signed   shr  (unsigned short)((short)x >> k)                -> arithmetic shift
  * compares cast both operands to (unsigned short) or (short)   -> unambiguous kind
  * no div/mod/mul; all loops bounded; no uninitialized reads.

Run INSIDE the dev container; drive from the host via `dev/run.sh fuzz [N] [seed]`.
"""
import argparse
import atexit
import os
import random
import re
import signal
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Environment / paths (container defaults; overridable)
# ---------------------------------------------------------------------------
ROOT = Path(os.environ.get("FUZZ_ROOT", "/work"))
BUILD = ROOT / "build"
TOOL = Path(os.environ.get("MOS_TOOLCHAIN", str(BUILD / "llvm-mos-install"))) / "bin"
CFG = BUILD / "install" / "bin" / "mos-snes.cfg"
CHECKSUM = ROOT / "tools" / "snes-checksum.py"
SMOKE_LUA = ROOT / "dev" / "smoke.lua"
ROMPATH = Path(os.environ.get("SNES_ROMPATH", str(ROOT / "dev" / "roms")))
JGX = BUILD / "jgxcheck"
JG_DB = ROOT / "vendor" / "bsnes-jg" / "Database"
TRIAGE = BUILD / "fuzz-triage"
SCRATCH = Path("/tmp/mame-scratch")
WORK = BUILD / "fuzz-work"

A16  = ["-Xclang", "-target-feature", "-Xclang", "+mos-a16"]
# #321 xy16: +mos-xy16 implies +mos-a16; a third differential track to ensure the
# X-flag lattice in MOSInsertREPSEP doesn't disturb M-flag placement or values.
XY16 = ["-Xclang", "-target-feature", "-Xclang", "+mos-xy16"]
GOT_RE = re.compile(r"got=0x([0-9A-Fa-f]+)")

ARR_N = 8
ARR_MASK = ARR_N - 1
# NOTE (xy16 cross-call boundary coverage): the `Index` expr masks with ARR_MASK (=7), so
# arr[(unsigned)idx & 7] is provably <= 7 and LTO narrows the index back to an 8-bit X (a valid
# optimization) -> the generated indexed loads do NOT exercise the genuine 16-bit-index (Xc16)
# path. That is intentional here; widening to an unmasked array purely to keep an index 16-bit
# across a call would perturb the host-eval model (State.arr / expected()) for little gain,
# because the cross-call boundary is already covered two ways: (1) RecFuncDef/Call already hold
# REC_LIVE 16-bit values live across calls, and the boundary is correct *by construction* — a
# cross-call-live 16-bit index lands in a callee-saved ZP imaginary pair ($rs10-$rs15), reloaded
# into X16 only at the point of use (physical X16 is never live across a call); (2) the
# deterministic `dev/run.sh xy16call` gate (examples/65816/xy16call.c) locks the genuine
# 16-bit-index-held-across-a-call case with a load-bearing-high-byte differential. See
# docs/investigations/65816-calling-convention-decision.md §"Index registers across calls".

# Recursion knobs (P0: force the soft/reentrant stack). MOSNonReentrant marks every
# NON-recursive function `nonreentrant` -> static frame, so genuine recursion is the
# one soft-stack trigger the generator can emit; without it expandLDSTStk (the
# soft-stack spill lowering, where the F3 Ac16 bug lived) is never exercised.
# See docs/plans/2026-06-16-321-soft-stack-spill-coverage.md.
P_RECURSIVE = 0.5      # per generated function: chance it is self-recursive
MAX_EVAL_DEPTH = 64    # host-eval recursion safety cap (real depth is bounded to <= 4)
# 16-bit values held live ACROSS the self-call. Being recursive only puts a function
# on the soft stack; the soft-stack SPILL path (STStk/LDStk -> expandLDSTStk, the F3
# bug) needs enough live-across-call pressure to exhaust the 4 hard-stack CSR slots so
# the caller must spill to its (soft) frame. Each value is anchored by a DISTINCT
# volatile input read so the optimizer cannot sink it past the call.
REC_LIVE_MIN, REC_LIVE_MAX = 5, 8
BINOPS = ["+", "-", "&", "|", "^"]

# ---------------------------------------------------------------------------
# Exact fixed-width helpers (mirror the emitted C casts)
# ---------------------------------------------------------------------------
def u16(x):
    return x & 0xFFFF


def u8(x):
    return x & 0xFF


def to_s16(x):
    x &= 0xFFFF
    return x - 0x10000 if (x & 0x8000) else x


def u32(x):
    return x & 0xFFFFFFFF


def to_s32(x):
    x &= 0xFFFFFFFF
    return x - 0x100000000 if (x & 0x80000000) else x


# ---------------------------------------------------------------------------
# 32-bit (long/int32_t) block — an ADDITIVE, --s32-gated track so the
# deterministic builtin oracle exercises the +mos-a16 s32 path (2x s16 carry,
# 4x s8<->s32 (un)merge, const/arith shifts, __mulsi3/__udivsi3 libcalls). One
# seeded op-list is interpreted by BOTH the C emitter (s32_emit) and the Python
# evaluator (s32_eval) so they cannot drift; s32_fold reduces the 32-bit registers
# to the u16 contribution XOR'd into corpus_result. All ops are strictly defined
# (shift counts 1..31; udiv guards /0; udiv is unsigned so no INT_MIN/-1 overflow).
# ---------------------------------------------------------------------------
S32_NREG = 4
S32_OPS = ["add", "sub", "and", "or", "xor", "mul", "shl", "shr", "sar", "udiv"]


def s32_emit(seq):
    """C statements (operating on uint32_t q0..q{N-1}) for the op-list."""
    L = []
    for (op, d, a, b) in seq:
        if op == "add":   s = "(uint32_t)(q%d + q%d)" % (a, b)
        elif op == "sub": s = "(uint32_t)(q%d - q%d)" % (a, b)
        elif op == "and": s = "(uint32_t)(q%d & q%d)" % (a, b)
        elif op == "or":  s = "(uint32_t)(q%d | q%d)" % (a, b)
        elif op == "xor": s = "(uint32_t)(q%d ^ q%d)" % (a, b)
        elif op == "mul": s = "(uint32_t)(q%d * q%d)" % (a, b)          # __mulsi3
        elif op == "shl": s = "(uint32_t)(q%d << %d)" % (a, b)          # b = count 1..31
        elif op == "shr": s = "(uint32_t)(q%d >> %d)" % (a, b)          # logical (q unsigned)
        elif op == "sar": s = "(uint32_t)((int32_t)q%d >> %d)" % (a, b) # arithmetic
        elif op == "udiv": s = "(q%d ? (uint32_t)(q%d / q%d) : q%d)" % (b, a, b, a)  # __udivsi3, /0 guard
        else: raise AssertionError(op)
        L.append("  q%d = %s;" % (d, s))
    return L


def s32_eval(seq, init):
    """Exact mirror of s32_emit: returns the final register list (all u32)."""
    q = [u32(v) for v in init]
    for (op, d, a, b) in seq:
        if op == "add":   q[d] = u32(q[a] + q[b])
        elif op == "sub": q[d] = u32(q[a] - q[b])
        elif op == "and": q[d] = q[a] & q[b]
        elif op == "or":  q[d] = q[a] | q[b]
        elif op == "xor": q[d] = q[a] ^ q[b]
        elif op == "mul": q[d] = u32(q[a] * q[b])
        elif op == "shl": q[d] = u32(q[a] << b)
        elif op == "shr": q[d] = q[a] >> b
        elif op == "sar": q[d] = u32(to_s32(q[a]) >> b)
        elif op == "udiv": q[d] = (q[a] // q[b]) if q[b] else q[a]
        else: raise AssertionError(op)
    return q


def s32_fold(q):
    """Reduce the 32-bit registers to a u16 contribution for corpus_result."""
    sig = 0
    for v in q:
        sig ^= v
    return u16(sig ^ (sig >> 16))


# ---------------------------------------------------------------------------
# AST nodes — each has emit() -> C string (unsigned-short-valued) and
# eval(st) -> raw integer.  `st` is the interpreter State.
# ---------------------------------------------------------------------------
class Expr:
    def emit(self):  # -> C expression of type `unsigned short` (value 0..0xFFFF)
        raise NotImplementedError

    def eval(self, st):  # -> raw int (0..0xFFFF)
        raise NotImplementedError


class Const(Expr):
    def __init__(self, v):
        self.v = u16(v)

    def emit(self):
        return "(unsigned short)0x%04Xu" % self.v

    def eval(self, st):
        return self.v


class Var(Expr):
    """Read a declared variable as an unsigned-short value: (unsigned)name."""
    def __init__(self, name):
        self.name = name

    def emit(self):
        return "(unsigned)%s" % self.name

    def eval(self, st):
        return st.read(self.name)


class Index(Expr):
    """arr[(unsigned)idx & MASK] read."""
    def __init__(self, idx):
        self.idx = idx

    def emit(self):
        return "(unsigned)arr[(unsigned)(%s) & %d]" % (self.idx.emit(), ARR_MASK)

    def eval(self, st):
        return st.arr[self.idx.eval(st) & ARR_MASK]


class Deref(Expr):
    """*p read (p points into arr)."""
    def emit(self):
        return "(unsigned)(*p)"

    def eval(self, st):
        return st.arr[st.ptr]


def apply_bin(op, a, b):
    """Exact u16 semantics of the C `+ - & | ^` operators (shared by Bin.eval and
    the recursive-function combine in RecFuncDef.eval_body)."""
    if op == "+":
        r = a + b
    elif op == "-":
        r = a - b
    elif op == "&":
        r = a & b
    elif op == "|":
        r = a | b
    elif op == "^":
        r = a ^ b
    else:
        raise AssertionError(op)
    return u16(r)


class Bin(Expr):
    def __init__(self, op, a, b):
        self.op, self.a, self.b = op, a, b

    def emit(self):
        return "(unsigned short)(%s %s %s)" % (self.a.emit(), self.op, self.b.emit())

    def eval(self, st):
        return apply_bin(self.op, self.a.eval(st), self.b.eval(st))


class Shift(Expr):
    """k constant in 1..15.  kind in {'shl','shr','sar'}."""
    def __init__(self, kind, a, k):
        self.kind, self.a, self.k = kind, a, k

    def emit(self):
        if self.kind == "shl":
            return "(unsigned short)((unsigned)(%s) << %d)" % (self.a.emit(), self.k)
        if self.kind == "shr":
            # Reduce to 16 bits BEFORE the unsigned shift: a bare (unsigned)signed_var
            # sign-extends to int first, so `>>` would leak 1-bits on a 32-bit-int host
            # but not on the 16-bit-int target. (unsigned short)(...) makes it
            # width-independent — the shifted value is always the raw 16-bit pattern.
            return "(unsigned short)((unsigned)(unsigned short)(%s) >> %d)" % (self.a.emit(), self.k)
        # arithmetic (signed) right shift
        return "(unsigned short)((short)(%s) >> %d)" % (self.a.emit(), self.k)

    def eval(self, st):
        a = self.a.eval(st)
        if self.kind == "shl":
            return u16(a << self.k)
        if self.kind == "shr":
            return u16(a >> self.k)
        return u16(to_s16(a) >> self.k)


class Call(Expr):
    def __init__(self, fname, args):
        self.fname, self.args = fname, args

    def emit(self):
        return "(unsigned)%s(%s)" % (
            self.fname,
            ", ".join("(unsigned short)(%s)" % a.emit() for a in self.args),
        )

    def eval(self, st):
        argv = [a.eval(st) for a in self.args]
        return st.call(self.fname, argv)


class Cmp(Expr):
    """A boolean (C int 0/1).  signed selects (short) vs (unsigned short) operands."""
    def __init__(self, op, a, b, signed):
        self.op, self.a, self.b, self.signed = op, a, b, signed

    def emit(self):
        cast = "(short)" if self.signed else "(unsigned short)"
        return "(%s(%s) %s %s(%s))" % (cast, self.a.emit(), self.op, cast, self.b.emit())

    def eval(self, st):
        a, b = self.a.eval(st), self.b.eval(st)
        if self.signed:
            a, b = to_s16(a), to_s16(b)
        op = self.op
        r = (
            a == b if op == "=="
            else a != b if op == "!="
            else a < b if op == "<"
            else a <= b if op == "<="
            else a > b if op == ">"
            else a >= b
        )
        return 1 if r else 0


# ---------------------------------------------------------------------------
# Statements
# ---------------------------------------------------------------------------
class Stmt:
    def emit(self, ind):
        raise NotImplementedError

    def exec(self, st):
        raise NotImplementedError


def _store_for(name, expr_c):
    """Cast `expr_c` to the storage type of `name` for the assignment RHS."""
    t = VARTYPE[name]
    if t == "u8":
        return "(unsigned char)(%s)" % expr_c
    if t == "s16":
        return "(short)(%s)" % expr_c
    return "(unsigned short)(%s)" % expr_c


class AssignVar(Stmt):
    def __init__(self, name, expr):
        self.name, self.expr = name, expr

    def emit(self, ind):
        return "%s%s = %s;" % (ind, self.name, _store_for(self.name, self.expr.emit()))

    def exec(self, st):
        v = self.expr.eval(st)
        st.write(self.name, v)


class AssignIndex(Stmt):
    def __init__(self, idx, expr):
        self.idx, self.expr = idx, expr

    def emit(self, ind):
        return "%sarr[(unsigned)(%s) & %d] = (unsigned short)(%s);" % (
            ind, self.idx.emit(), ARR_MASK, self.expr.emit())

    def exec(self, st):
        i = self.idx.eval(st) & ARR_MASK
        v = u16(self.expr.eval(st))
        st.arr[i] = v


class AssignDeref(Stmt):
    def __init__(self, expr):
        self.expr = expr

    def emit(self, ind):
        return "%s*p = (unsigned short)(%s);" % (ind, self.expr.emit())

    def exec(self, st):
        st.arr[st.ptr] = u16(self.expr.eval(st))


class If(Stmt):
    def __init__(self, cond, then, els):
        self.cond, self.then, self.els = cond, then, els

    def emit(self, ind):
        out = ["%sif (%s) {" % (ind, self.cond.emit())]
        out += [s.emit(ind + "  ") for s in self.then]
        if self.els:
            out.append("%s} else {" % ind)
            out += [s.emit(ind + "  ") for s in self.els]
        out.append("%s}" % ind)
        return "\n".join(out)

    def exec(self, st):
        body = self.then if self.cond.eval(st) else self.els
        for s in body:
            s.exec(st)


class For(Stmt):
    def __init__(self, ctr, count, body):
        self.ctr, self.count, self.body = ctr, count, body

    def emit(self, ind):
        out = ["%sfor (%s = 0; %s < %d; %s++) {" % (ind, self.ctr, self.ctr, self.count, self.ctr)]
        out += [s.emit(ind + "  ") for s in self.body]
        out.append("%s}" % ind)
        return "\n".join(out)

    def exec(self, st):
        for i in range(self.count):
            st.write(self.ctr, i)
            for s in self.body:
                s.exec(st)


# ---------------------------------------------------------------------------
# Interpreter state
# ---------------------------------------------------------------------------
VARTYPE = {}  # name -> 'u16' | 's16' | 'u8'  (filled by the generator)


class State:
    def __init__(self, vars0, arr0, ptr, funcs, depth=0):
        self.vars = dict(vars0)
        self.arr = list(arr0)
        self.ptr = ptr
        self.funcs = funcs
        self.depth = depth  # call-stack depth, for the recursion safety cap

    def read(self, name):
        return self.vars[name]

    def write(self, name, v):
        t = VARTYPE[name]
        self.vars[name] = u8(v) if t == "u8" else u16(v)

    def call(self, fname, argv):
        fd = self.funcs[fname]
        if self.depth >= MAX_EVAL_DEPTH:
            # Real depth is bounded to <= 4 by Gen.call_args; hitting this means a
            # generator bug produced unbounded recursion — surface it loudly.
            raise RuntimeError(
                "host-eval recursion exceeded %d frames at %s (generator bug)"
                % (MAX_EVAL_DEPTH, fname))
        env = dict(self.vars)  # input globals are read-only, so their values are valid
        for p, a in zip(fd.params, argv):
            env[p] = u16(a)
        sub = State(env, self.arr, self.ptr, self.funcs, depth=self.depth + 1)
        return fd.eval_body(sub)


class FuncDef:
    def __init__(self, name, params, body):
        self.name, self.params, self.body = name, params, body
        self.recursive = False

    def emit(self):
        plist = ", ".join("unsigned short %s" % p for p in self.params)
        return (
            "__attribute__((noinline)) static unsigned short %s(%s) {\n"
            "  return (unsigned short)(%s);\n}" % (self.name, plist, self.body.emit())
        )

    def eval_body(self, st):
        return self.body.eval(st)


class RecFuncDef(FuncDef):
    """A genuinely self-recursive function — the ONLY soft-stack trigger the
    generator can emit (MOSNonReentrant spares only NON-recursive functions from
    `nonreentrant`/static frames). Generalizes examples/65816/a16spillr.c, the proven
    F3 soft-stack repro:

        __attribute__((noinline)) static unsigned short fN(unsigned short p0,
                                                           unsigned short p1) {
          if (p0 == 0) return (unsigned short)(BASE);
          unsigned short v0 = (unsigned short)(IN0 OP <pure>);   // each anchored by a
          unsigned short v1 = (unsigned short)(IN1 OP <pure>);   // DISTINCT volatile input
          ...                                                    // (REC_LIVE of them)
          unsigned short r = fN((unsigned short)(p0 - 1u), (unsigned short)(ARG1));
          return (unsigned short)(COMBINE(v0..v{k-1}, r));        // ALL live across the call
        }

    Each v_i reads a DISTINCT volatile input (so the read can't sink past the call)
    and is consumed in COMBINE after the call, so REC_LIVE (>4) 16-bit values are live
    ACROSS the self-call — exhausting the 4 hard-stack CSR slots and forcing the
    caller to spill to its frame. For a reentrant function that frame is the SOFT
    stack: STStk/LDStk -> expandLDSTStk (the F3 Ac16-spill path). The recursion is
    non-tail (the result feeds COMBINE) and the call is `noinline`, so the optimizer
    cannot unroll/inline it away: fN stays recursive -> reentrant -> soft stack. p0 is
    the counter — it strictly decreases by 1 and callers pass a small bounded constant
    (Gen.call_args) — so depth is shallow and soft-stack-safe, and host-eval terminates.
    """
    def __init__(self, name, params, base, lives, combine, arg1):
        super().__init__(name, params, base)  # `body` == the p0==0 base expr
        self.recursive = True
        self.base, self.lives, self.combine, self.arg1 = base, lives, combine, arg1

    def emit(self):
        ctr = self.params[0]
        plist = ", ".join("unsigned short %s" % p for p in self.params)
        lines = [
            "__attribute__((noinline)) static unsigned short %s(%s) {" % (self.name, plist),
            "  if (%s == 0)" % ctr,
            "    return (unsigned short)(%s);" % self.base.emit(),
        ]
        for i, e in enumerate(self.lives):
            lines.append("  unsigned short v%d = (unsigned short)(%s);" % (i, e.emit()))
        lines.append(
            "  unsigned short r = %s((unsigned short)((unsigned)%s - 1u), "
            "(unsigned short)(%s));" % (self.name, ctr, self.arg1.emit()))
        lines.append("  return (unsigned short)(%s);" % self.combine.emit())
        lines.append("}")
        return "\n".join(lines)

    def eval_body(self, st):
        ctr = st.read(self.params[0])
        if ctr == 0:
            return u16(self.base.eval(st))
        for i, e in enumerate(self.lives):
            st.vars["v%d" % i] = u16(e.eval(st))  # v0.. and r live in the frame's vars,
        st.vars["r"] = st.call(self.name, [u16(ctr - 1), u16(self.arg1.eval(st))])
        return u16(self.combine.eval(st))         # set directly (not via VARTYPE write)


# ---------------------------------------------------------------------------
# Generator
# ---------------------------------------------------------------------------
class Gen:
    def __init__(self, seed, s32=False):
        self.rng = random.Random(seed)
        self.seed = seed
        self.s32 = s32
        # variable pools (names -> type)  -------------------------------------
        self.inputs = {  # read-only volatile globals
            "in_u0": "u16", "in_u1": "u16", "in_u2": "u16",
            "in_s0": "s16", "in_b0": "u8", "in_idx": "u16",
        }
        self.scratch = {  # writable volatile globals
            "gu0": "u16", "gu1": "u16", "gs0": "s16", "gb0": "u8",
        }
        self.locals = {  # main locals
            "lu0": "u16", "lu1": "u16", "lu2": "u16",
            "ls0": "s16", "lb0": "u8",
        }
        VARTYPE.clear()
        VARTYPE.update(self.inputs)
        VARTYPE.update(self.scratch)
        VARTYPE.update(self.locals)
        VARTYPE["corpus_result"] = "u16"
        # initial values (deterministic) -------------------------------------
        self.init = {}
        for n, t in {**self.inputs, **self.scratch}.items():
            self.init[n] = u8(self.rng.randrange(256)) if t == "u8" else u16(self.rng.randrange(0x10000))
        self.local_init = {}
        for n, t in self.locals.items():
            self.local_init[n] = u8(self.rng.randrange(256)) if t == "u8" else u16(self.rng.randrange(0x10000))
        self.arr_init = [u16(self.rng.randrange(0x10000)) for _ in range(ARR_N)]
        self.ptr_target = self.init["in_idx"] & ARR_MASK
        self.funcs = {}
        self.readable = list(self.inputs) + list(self.scratch) + list(self.locals)
        self.writable = list(self.scratch) + list(self.locals)
        self.ctr_n = 0
        # 32-bit track (gated): a seeded straight-line op-list over S32_NREG uint32_t
        # globals. Only drawn when enabled, so without --s32 the rng stream (and thus
        # the whole generated program) is byte-identical to the pre-s32 generator.
        if self.s32:
            self.s32_init = [self.rng.randrange(0x100000000) for _ in range(S32_NREG)]
            self.s32_seq = []
            for _ in range(self.rng.randint(6, 12)):
                op = self.rng.choice(S32_OPS)
                d = self.rng.randrange(S32_NREG)
                a = self.rng.randrange(S32_NREG)
                b = (self.rng.randint(1, 31) if op in ("shl", "shr", "sar")
                     else self.rng.randrange(S32_NREG))
                self.s32_seq.append((op, d, a, b))

    # --- expression leaves & trees -----------------------------------------
    def leaf(self, pure=False):
        choices = ["const", "var"]
        if not pure:
            choices += ["index", "deref", "call"] if self.funcs else ["index", "deref"]
        kind = self.rng.choice(choices)
        if kind == "const":
            return Const(self.rng.randrange(0x10000))
        if kind == "var":
            pool = self.pure_pool if pure else self.readable
            return Var(self.rng.choice(pool))
        if kind == "index":
            return Index(self.small())
        if kind == "deref":
            return Deref()
        # call
        fd = self.funcs[self.rng.choice(list(self.funcs))]
        return Call(fd.name, self.call_args(fd))

    def small(self):
        """A shallow value expr (used for indices / call args)."""
        if self.rng.random() < 0.5:
            return Const(self.rng.randrange(0x10000))
        return Var(self.rng.choice(self.readable))

    def call_args(self, fd):
        """Argument exprs for a call to `fd`. For a recursive function the first
        param is the recursion counter, which MUST be a small bounded constant —
        otherwise the recursion would run away on both the soft stack (overflow)
        and the host evaluator. Data args stay arbitrary."""
        if fd.recursive:
            return [Const(self.rng.randint(2, 4))] + [
                self.small() for _ in fd.params[1:]]
        return [self.small() for _ in fd.params]

    def expr(self, depth, pure=False):
        if depth <= 0 or self.rng.random() < 0.45:
            return self.leaf(pure=pure)
        r = self.rng.random()
        if r < 0.6:
            op = self.rng.choice(BINOPS)
            return Bin(op, self.expr(depth - 1, pure), self.expr(depth - 1, pure))
        if r < 0.85:
            kind = self.rng.choice(["shl", "shr", "sar"])
            return Shift(kind, self.expr(depth - 1, pure), self.rng.randint(1, 15))
        # nested compare materialized as a 0/1 value (stored-bool path)
        return self.cmp(depth - 1, pure)

    def cmp(self, depth, pure=False):
        op = self.rng.choice(["==", "!=", "<", "<=", ">", ">="])
        signed = self.rng.random() < 0.5
        return Cmp(op, self.expr(depth, pure), self.expr(depth, pure), signed)

    # --- statements ---------------------------------------------------------
    def stmt(self, budget):
        r = self.rng.random()
        if budget > 0 and r < 0.18:
            return self.gen_if(budget)
        if budget > 0 and r < 0.30:
            return self.gen_for(budget)
        r = self.rng.random()
        if r < 0.12:
            return AssignIndex(self.small(), self.expr(1))
        if r < 0.22:
            return AssignDeref(self.expr(1))
        if r < 0.34:
            return AssignVar(self.rng.choice(self.writable), self.cmp(1))  # stored bool
        return AssignVar(self.rng.choice(self.writable), self.expr(2))

    def block(self, n, budget):
        return [self.stmt(budget) for _ in range(n)]

    def gen_if(self, budget):
        then = self.block(self.rng.randint(1, 2), budget - 1)
        els = self.block(self.rng.randint(0, 2), budget - 1)
        return If(self.cmp(1), then, els)

    def gen_for(self, budget):
        self.ctr_n += 1
        ctr = "i%d" % self.ctr_n
        VARTYPE[ctr] = "u16"
        self.loop_ctrs.append(ctr)
        # make the counter readable inside the body
        self.readable.append(ctr)
        body = self.block(self.rng.randint(1, 2), budget - 1)
        self.readable.remove(ctr)
        count = self.rng.randint(2, 8)
        return For(ctr, count, body)

    # --- functions ----------------------------------------------------------
    def gen_funcs(self):
        nf = self.rng.randint(1, 2)
        for k in range(nf):
            name = "f%d" % k
            params = ["p0", "p1"]
            self.pure_pool = params + list(self.inputs)
            if self.rng.random() < P_RECURSIVE:
                # Self-recursive -> soft stack. Hold REC_LIVE 16-bit values live across
                # the self-call, each anchored by a distinct volatile input read, then
                # COMBINE folds them + the recursive result -> caller spills to its soft
                # frame (STStk/LDStk -> expandLDSTStk).
                base = self.expr(2, pure=True)
                arg1 = self.expr(1, pure=True)
                k = self.rng.randint(REC_LIVE_MIN, REC_LIVE_MAX)
                vol = list(self.inputs)
                self.rng.shuffle(vol)
                lives = [Bin(self.rng.choice(BINOPS),
                             Var(vol[i % len(vol)]), self.expr(1, pure=True))
                         for i in range(k)]
                fold = ["v%d" % i for i in range(k)] + ["r"]
                self.rng.shuffle(fold)
                combine = Var(fold[0])
                for nm in fold[1:]:
                    combine = Bin(self.rng.choice(BINOPS), combine, Var(nm))
                self.funcs[name] = RecFuncDef(name, params, base, lives, combine, arg1)
            else:
                body = self.expr(2, pure=True)
                self.funcs[name] = FuncDef(name, params, body)
            del self.pure_pool

    # --- whole program ------------------------------------------------------
    def program(self):
        self.gen_funcs()
        self.loop_ctrs = []
        n = self.rng.randint(5, 9)
        body = self.block(n, budget=1)
        final = self.expr(2)
        # Guarantee every recursive function is actually invoked AND value-checked:
        # an uncalled `static` function is DCE'd (never exercising the soft stack),
        # and folding its result into corpus_result puts it under the differential
        # oracle. Random body/`final` calls may also hit it — this just ensures it.
        for name, fd in self.funcs.items():
            if fd.recursive:
                final = Bin("^", final, Call(name, self.call_args(fd)))
        body.append(AssignVar("corpus_result", final))
        self.body = body
        self.final = final
        return body

    # --- emit ---------------------------------------------------------------
    def emit_c(self):
        L = []
        L.append("// AUTO-GENERATED by tools/a16_fuzz.py  seed=%d" % self.seed)
        L.append("// Differential #321 +mos-a16 test. corpus_result must match the host")
        L.append("// evaluation AND the default 8-bit build on both emulators.")
        if self.s32:
            L.append("#include <stdint.h>  // --s32: 32-bit long/int32_t track")
        for n, t in self.inputs.items():
            L.append("volatile %s %s = 0x%X;" % (CTYPE[t], n, self.init[n]))
        for n, t in self.scratch.items():
            L.append("volatile %s %s = 0x%X;" % (CTYPE[t], n, self.init[n]))
        if self.s32:
            for i, v in enumerate(self.s32_init):
                L.append("volatile uint32_t q%d = 0x%Xu;" % (i, v))
        L.append("volatile unsigned short corpus_result;")
        L.append("unsigned short arr[%d] = {%s};" % (
            ARR_N, ", ".join("0x%X" % v for v in self.arr_init)))
        L.append("")
        for fd in self.funcs.values():
            L.append(fd.emit())
        L.append("")
        L.append("int main(void) {")
        for n, t in self.locals.items():
            L.append("  %s %s = 0x%X;" % (CTYPE[t], n, self.local_init[n]))
        for c in self.loop_ctrs:
            L.append("  unsigned short %s;" % c)
        L.append("  unsigned short *p = &arr[(unsigned)in_idx & %d];" % ARR_MASK)
        for s in self.body:
            L.append(s.emit("  "))
        if self.s32:
            # 32-bit straight-line block over the volatile uint32_t q globals, then
            # fold the registers into corpus_result (XOR of the two 16-bit halves of
            # their running XOR). Mirrored exactly by s32_eval/s32_fold in expected().
            L.extend(s32_emit(self.s32_seq))
            sig = " ^ ".join("q%d" % i for i in range(S32_NREG))
            L.append("  { uint32_t s32_sig = %s;" % sig)
            L.append("    corpus_result = (unsigned short)((unsigned)corpus_result"
                     " ^ (unsigned short)(s32_sig ^ (s32_sig >> 16))); }")
        L.append("  for (;;) {}")
        L.append("}")
        return "\n".join(L) + "\n"

    def expected(self):
        vars0 = {}
        for n in {**self.inputs, **self.scratch}:
            vars0[n] = self.init[n]
        for n in self.locals:
            vars0[n] = self.local_init[n]
        for c in self.loop_ctrs:
            vars0[c] = 0
        st = State(vars0, self.arr_init, self.ptr_target, self.funcs)
        for s in self.body:
            s.exec(st)
        cr = st.vars["corpus_result"]
        if self.s32:
            cr = u16(cr ^ s32_fold(s32_eval(self.s32_seq, self.s32_init)))
        return cr


CTYPE = {"u16": "unsigned short", "s16": "short", "u8": "unsigned char"}


# ---------------------------------------------------------------------------
# Toolchain orchestration
# ---------------------------------------------------------------------------
class CompileError(Exception):
    pass


def _run(cmd, timeout=120, retries=2):
    """Run a fast, deterministic toolchain command (compile / verify / objdump / checksum).

    A *persistent* timeout is a REAL defect, not noise: the gating bug this suite hunts is a
    backend pass that loops forever (e.g. F1, the `(short)>>8` legalizer hang) — that times
    out on EVERY attempt, survives the retries, and is surfaced by the final raise. Retries
    exist only to absorb a *transient* stretch: under heavy concurrent load (a parallel
    toolchain rebuild + emulator runs) a normally-sub-second compile can blow the budget
    once and pass immediately on retry. So: a flake clears, a true hang persists."""
    for attempt in range(retries + 1):
        try:
            return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            if attempt == retries:
                raise
            sys.stderr.write("  (toolchain timed out >%ss, retry %d/%d — transient load?)\n"
                             % (timeout, attempt + 1, retries))


def compile_rom(src, rom, mapf, flags, cflags=()):
    """Compile src -> SNES ROM. `flags` is a list of extra clang args (e.g. A16, XY16, []).
    `cflags` is extra front-end args (default empty); the Csmith runner passes its
    `-include csmith_snes.h -I vendor/csmith/include` adapter here. Every existing caller
    omits `cflags` → byte-for-byte unchanged."""
    # Legacy callers that pass a16 as a bool (True/False) → translate transparently.
    if isinstance(flags, bool):
        flags = A16 if flags else []
    tag = ("+mos-xy16" if "+mos-xy16" in flags else
           "+mos-a16"  if "+mos-a16"  in flags else "default")
    cmd = [str(TOOL / "mos-clang"), "--config", str(CFG), "-mcpu=mosw65816"]
    cmd += flags
    cmd += list(cflags)
    cmd += ["-Os", "-Wl,-Map=%s" % mapf, "-o", str(rom), str(src)]
    p = _run(cmd)
    if p.returncode != 0:
        raise CompileError("link (%s) rc=%d\n%s" % (tag, p.returncode, p.stderr))
    c = _run([sys.executable, str(CHECKSUM), str(rom)])
    if c.returncode != 0:
        raise CompileError("checksum rc=%d\n%s" % (c.returncode, c.stderr))


def verify_machineinstrs(src, obj, flags=None, cflags=()):
    """Compile with -verify-machineinstrs. `flags` defaults to A16. Returns (ok, log).
    `cflags` (default empty) threads extra front-end args through unchanged for callers
    that need an adapter header; the builtin path omits it. NOTE: this uses `--target=mos`
    (no `--config`), so a TU that #includes libc headers (e.g. Csmith's <math.h>) can't be
    verified here — the Csmith path skips this step (evaluate(..., verify=False)) and relies
    on the `--config` link in compile_rom as its crash gate instead."""
    if flags is None:
        flags = A16
    cmd = [str(TOOL / "mos-clang"), "--target=mos", "-mcpu=mosw65816", *flags, *cflags,
           "-Os", "-mllvm", "-verify-machineinstrs", "-c", "-o", str(obj), str(src)]
    try:
        p = _run(cmd)
    except subprocess.TimeoutExpired as e:
        # Persisted across every retry → a genuine compile hang (a backend pass looping),
        # which is exactly the gating defect this check exists to catch. Surface as a crash
        # (triaged), NOT a swallowed driver exception.
        return (False, "compile TIMEOUT >%ss across retries — possible backend infinite loop"
                % e.timeout)
    log = p.stdout + p.stderr
    # A verifier rejection / ICE / segfault all set a nonzero exit; "Bad machine code"
    # is belt-and-suspenders. (Don't match a bare "ERROR" substring — benign diagnostics
    # contain it and would flag false crashes.)
    bad = p.returncode != 0 or "Bad machine code" in log
    return (not bad, "rc=%d\n%s" % (p.returncode, log))


def disasm(src, obj, a16):
    cmd = [str(TOOL / "mos-clang"), "--target=mos", "-mcpu=mosw65816"]
    if a16:
        cmd += A16
    cmd += ["-Os", "-c", "-o", str(obj), str(src)]
    if _run(cmd).returncode != 0:
        return "(compile for disasm failed)"
    d = _run([str(TOOL / "llvm-objdump"), "-d", "--mcpu=mosw65816", str(obj)])
    return d.stdout


def map_lookup(mapf, sym):
    for line in Path(mapf).read_text().splitlines():
        f = line.split()
        if f and f[-1] == sym and len(f) >= 3:
            return int(f[0], 16), int(f[2], 16)
    return None, None


# Emulator subprocesses run in their own session (= own process group) so a stuck boot can be
# reaped as a WHOLE TREE, not just the direct child. A per-test MAME timeout, a Ctrl-C, or a
# SIGTERM otherwise leaks a process every time, and across a 1000+-boot local sweep they pile
# up and starve the box. We track live emu children and kill the group on: the inline timeout
# (below), interpreter exit / uncaught KeyboardInterrupt (atexit), and SIGTERM (handler).
_LIVE_EMUS = set()


def _kill_group(p):
    try:
        os.killpg(os.getpgid(p.pid), signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass  # already gone / not ours


def _reap_emus(*_):
    for p in list(_LIVE_EMUS):
        if p.poll() is None:
            _kill_group(p)


atexit.register(_reap_emus)
try:
    signal.signal(signal.SIGTERM, lambda *a: (_reap_emus(), sys.exit(143)))
except (ValueError, OSError):
    pass  # not on the main thread — atexit + the inline timeout kill still cover it


def _run_emu(cmd, timeout, env=None):
    """subprocess.run for an emulator, but in its own process group so a timeout reaps the
    whole tree (emulator + any children it forked). Returns a CompletedProcess and re-raises
    subprocess.TimeoutExpired (after killing the group), so callers' handling is unchanged."""
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, env=env, start_new_session=True)
    _LIVE_EMUS.add(p)
    try:
        out, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        _kill_group(p)
        try:
            p.communicate(timeout=10)  # reap the SIGKILL'd group (no zombie)
        except Exception:
            pass
        raise
    finally:
        _LIVE_EMUS.discard(p)
    return subprocess.CompletedProcess(cmd, p.returncode, out, err)


def run_mame(rom, addr, want, length):
    env = dict(os.environ)
    env.update(
        SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy",
        SMOKE_ADDR="0x%X" % addr, SMOKE_WANT="0x%X" % want, SMOKE_LEN=str(length),
        SMOKE_SETTLE=os.environ.get("SMOKE_SETTLE", "60"),
    )
    cmd = ["mame", "snes", "-cart", str(rom), "-rompath", str(ROMPATH),
           "-autoboot_script", str(SMOKE_LUA), "-skip_gameinfo",
           "-video", "none", "-sound", "none", "-nothrottle", "-seconds_to_run", "3",
           "-cfg_directory", str(SCRATCH), "-nvram_directory", str(SCRATCH)]
    p = _run_emu(cmd, timeout=90, env=env)
    m = re.search(r"^SMOKE:.*$", p.stdout, re.M)
    if not m:
        return None, "(no SMOKE line from MAME)\n" + p.stdout[-400:]
    g = GOT_RE.search(m.group(0))
    return (int(g.group(1), 16) if g else None), m.group(0)


def run_bsnes(rom, off, length, want):
    if not (JGX.exists() and JG_DB.is_dir()):
        return "skip", "(bsnes-jg unavailable)"
    cmd = [str(JGX), str(rom), str(JG_DB), "0x%X" % off, str(length), "0x%X" % want, "180"]
    p = _run_emu(cmd, timeout=90)
    line = (p.stdout + p.stderr).strip().splitlines()
    line = next((l for l in line if l.startswith("SMOKE:")), "(no SMOKE line)")
    g = GOT_RE.search(line)
    return (int(g.group(1), 16) if g else None), line


# ---------------------------------------------------------------------------
# Per-program driver
# ---------------------------------------------------------------------------
# Known, already-diagnosed +mos-a16 defects. A verify-machineinstrs failure whose log
# matches one of these is reported as XFAIL (not a spurious new failure) so the suite
# keeps exercising the rest of the space while the fix is tracked. New/unmatched crashes
# and ALL runtime value mismatches remain hard failures. See the Tier-1 plan §Findings.
#
# (F3, `cmp-value-selectimm` — the `SelectImm $a16` crash on a 16-bit-accumulator value
# spilled across a call — was FIXED 2026-06-16 by spilling Ac16 via a direct 16-bit
# LDAbs16/STAbs16 instead of a COPY through an 8-bit GPR (MOSInstrInfo.cpp loadStoreReg-
# StackSlot); its signature now hard-FAILS again so a regression cannot silently XFAIL.
# See docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md.)
KNOWN_ISSUES = [
    # (regalloc-out-of-registers — +mos-a16 -O1/-Os "ran out of registers" on a u16 accumulator
    # held live across a second loop alongside u16*u8 multiplies (repro globals.c / a16regpress.c)
    # — was FIXED 2026-06-24 by fork patch 0009 (i8 small-const add/sub -> relocatable INC/DEC, so
    # the strength-reduced byte index lives in X and frees A16). Its KNOWN_ISSUES entry +
    # KNOWN_ISSUE_REPROS row are removed so a recurrence hard-FAILS again; globals.c is now a
    # positive corpus gate. See docs/plans/2026-06-24-321-a16-pressure-fix-implementation.md.)
    # (scavenger-p-not-gpr — +mos-a16/+mos-xy16 -O1/-Os crashed the register scavenger:
    # MOSRegisterInfo::saveScavengerRegister assumed N/Z dead at every scavenge point, but a 16-bit
    # compare/ALU keeps N (or Z) live across a frame-index materialization whose carry the scavenger
    # places in $c (a sub-register of $p), forcing the whole $p preserved across an UNBALANCED stack
    # range -> illegal `STImag8 $p` ("$p is not a GPR register") + an undefined-$p `PH $p`
    # — was FIXED 2026-06-26 by UPSTREAM fork patch 0011 (route $p hard-stack-neutrally through a
    # dead index reg into RC17; flag the no-reaching-def PHP undef; scope the stale assert away). Its
    # KNOWN_ISSUES entry + KNOWN_ISSUE_REPROS row are removed so a recurrence hard-FAILS again;
    # a16scavnz.c is now a positive gate (dev/run.sh a16scavnz -> 0x22A6, both emulators). See
    # docs/plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md.)
    # (a16-zp-pressure-overflow — +mos-a16 -O1/-Os on the register-heavy pr15296.c link-overflowed
    # the zero page: "relocation R_MOS_ADDR8 out of range: 1043 ... references section '.zp.noinit'"
    # (DEFAULT 8-bit / +mos-a16 -O0 linked clean) — is FIXED as of the current stack. Verified
    # 2026-06-26: pr15296.c links clean (.zp.noinit 0x12 B, not 1043) and runs
    # default==+mos-a16==+mos-xy16==0x600D on MAME + bsnes-jg (dev/run.sh torture --tests pr15296.c,
    # -Os AND -O1). The recorded "Imag16 saturation past 256 B" mechanism was WRONG — the allocator
    # hard-caps the zero page at -zp-avail=224 (mos-snes.cfg), so the 1043 B was a register-pressure
    # artifact relieved by the post-0009 codegen advances (0010-0012; the 0011 scavenger live-$p
    # rework the likely relief, since its pre-fix $p mishandling inflated spill/ZP usage — exact
    # relieving patch not bisected, would need a counterfactual rebuild). Its KNOWN_ISSUES entry +
    # classifier are removed so a recurrence hard-FAILS again; pr15296.c is now a positive in-scope
    # c-torture gate. See docs/investigations/65816-a16-regalloc-pressure-failure.md.)
    # (a16-unmerge-s32 — the +mos-a16 `G_UNMERGE_VALUES s32` legalizer gap the Csmith fuzzer
    # found — was FIXED 2026-06-19 by representing s32 as 2x s16 under a16; its KNOWN_ISSUES
    # entry is removed so a recurrence hard-FAILS again. See the main-branch commit + plan
    # docs/plans/2026-06-19-321-a16-unmerge-s32-legalizer.md and the hermetic gate
    # examples/65816/a16unmerge.ll / dev/run.sh a16unmerge.)

    # (a16-newton-step-rc-undef — +mos-a16/+mos-xy16 -Os on newton_step() emitted "Using an undefined
    # physical register" for a COPY of a ZP-pair $rcN into $x — was FIXED 2026-06-30 (CAUSE #1: the
    # register COALESCER folded a value read straight out of a call-clobbered imaginary $rcN
    # (`vreg = COPY $rcN`) into an Imag16 pair that outlived the clobbering call, so the allocator
    # re-bound it to $rcN across the clobber → disconnected def→use). Fixed in
    # MOSRegisterInfo::shouldCoalesce (fork patch 0002, tightly gated: 4/34 corpus programs change,
    # all -verify clean + differential green). newton_sim.c now verifies CLEAN at -Os (the battery's
    # level) so its KNOWN_ISSUES entry + KNOWN_ISSUE_REPROS row are removed and a recurrence hard-FAILS;
    # gates: dev/run.sh rcundef (-verify) + dev/run.sh newton (0x4D8B, both emus). See
    # docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md.)

    # a16-rc-undef-ra-pure-virtual — the SECOND, distinct root cause (CAUSE #2) of the same
    # "Using an undefined physical register" symptom, NOT fixed by the cause-#1 coalescer guard. The
    # register ALLOCATOR binds a PURE-VIRTUAL Imag16 value — one with no `$rcN` copy anywhere in its
    # def/use chain during coalescing — to a call-clobbered `$rc` pair it is live across. Witnesses:
    # lsystem_sim.c `main` (all opt levels, $rc11) and newton_sim.c `newton_gate_crc` at -O1 only. With
    # no copy-hint signal, MOSRegisterInfo::shouldCoalesce cannot target it; the only coalescer rule
    # that masks it perturbs 22-25/34 corpus programs (forbidden blanket change). The genuine fix is
    # RA-interference-level (greedy RA / LiveRegMatrix must treat the call's regmask clobber of the
    # imaginary pair as interference). The code runs CORRECTLY (lsystem differential 0x79C3, both emus);
    # this is a latent-hazard verify XFAIL pending the RA fix. Repro: examples/snes/corpus/lsystem_sim.c
    # at -Os. See docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md (Cause #2).
    ("a16-rc-undef-ra-pure-virtual",
     lambda log: "Using an undefined physical register" in log),
]


def classify_known(log):
    for kid, pred in KNOWN_ISSUES:
        if pred(log):
            return kid
    return None


# Deterministic repros for the deferred KNOWN_ISSUES defects, each paired with the kid it must
# classify as. The `known-issues` XPASS guard (cmd_known_issues) asserts every one STILL crashes
# -verify-machineinstrs under BOTH +mos-a16 and +mos-xy16 with this exact signature. When an
# upstream/RA fix lands, the repro verifies CLEAN and the guard FAILS loudly — so the now-stale
# KNOWN_ISSUES entry gets dropped (else it would silently mask a future regression of the same
# signature) and the repro promoted to a positive differential gate. Maintain in lockstep with
# KNOWN_ISSUES: dropping an entry there means dropping its row here too.
# (a16-zp-pressure-overflow is intentionally absent: its repro is a gitignored c-torture file and
# a LINK error, not a verify crash — so it can't be a verify-only guard row.)
KNOWN_ISSUE_REPROS = [
    # a16-newton-step-rc-undef: $rcN COPY to $x in newton_step under +mos-a16/+mos-xy16.
    # Crashes verify-machineinstrs but runs correctly (gate: dev/run.sh newton → PASS 0x4D8B).
    ("examples/snes/corpus/newton_sim.c", "a16-newton-step-rc-undef"),
]


def save_known(seed, csrc, kid):
    d = TRIAGE / "known"
    d.mkdir(parents=True, exist_ok=True)
    (d / ("%s-seed-%05d.c" % (kid, seed))).write_text(csrc)


def triage(seed, csrc, reason, extra=None):
    TRIAGE.mkdir(parents=True, exist_ok=True)
    base = TRIAGE / ("seed-%05d" % seed)
    base.with_suffix(".c").write_text(csrc)
    info = ["seed=%d" % seed, "reason: %s" % reason,
            "repro: dev/run.sh fuzz 1 %d" % seed, ""]
    if extra:
        for k, v in extra.items():
            info.append("=== %s ===" % k)
            info.append(str(v))
            info.append("")
    base.with_suffix(".txt").write_text("\n".join(info))
    # disasms
    try:
        (base.parent / ("seed-%05d.default.s" % seed)).write_text(
            disasm(base.with_suffix(".c"), WORK / "t.o", False))
        (base.parent / ("seed-%05d.a16.s" % seed)).write_text(
            disasm(base.with_suffix(".c"), WORK / "t.o", True))
    except Exception:
        pass


def evaluate(src, expected, want_bsnes, on_triage, cflags=(), verify=True):
    """The shared safety net: verify-machineinstrs (a16) + compile default/a16 + run
    both on MAME (+ a16 on bsnes-jg) + assert every value agrees.

    src       path to a .c whose `volatile unsigned short corpus_result` is the result.
    expected  int reference value (host-computed / baked), or None to use the trusted
              DEFAULT build's result as the reference (pure default==a16 differential).
    on_triage callback(reason:str, extra:dict) — persist artifacts on failure.
    cflags    extra front-end args threaded to verify + every compile (default empty →
              every existing caller unchanged); the Csmith runner passes its adapter
              `-include csmith_snes.h -I vendor/csmith/include` here.
    verify    run the -verify-machineinstrs crash gate (default True). The Csmith path
              passes verify=False: its TUs #include <math.h>, which the verify command's
              bare `--target=mos` (no `--config`) can't find — so the `--config` LTO link
              in compile_rom is the crash gate there (it already aborts on a backend ICE,
              caught below as a CompileError and run through classify_known).
    Returns (status, message, ref_value). status in {PASS,FAIL,CRASH,ERROR,XFAIL}.
    """
    WORK.mkdir(parents=True, exist_ok=True)
    SCRATCH.mkdir(parents=True, exist_ok=True)

    # 1) crash detector: -verify-machineinstrs under +mos-a16 AND +mos-xy16 (xy16 implies a16).
    #    Run BOTH legs (unless a16 is itself a NEW crash) so a known a16 issue can never MASK a
    #    genuinely-new xy16-only crash. Priority: a NEW (unclassified) crash on EITHER leg hard-FAILs;
    #    only if neither leg has a new crash does a known issue on either leg yield XFAIL. See
    #    docs/plans/2026-06-21-321-xy16-verify-both-legs-hardening.md.
    if verify:
        ok_a, vlog_a = verify_machineinstrs(src, WORK / "chk.vo", flags=A16, cflags=cflags)
        kid_a = None if ok_a else classify_known(vlog_a)
        if not ok_a and not kid_a:
            # New, unclassified +mos-a16 crash — hard fail now; the xy16 leg can't change this.
            on_triage("verify-machineinstrs / compiler crash (+mos-a16)", {"verify": vlog_a})
            return "CRASH", "verify-machineinstrs (+mos-a16) failed", None
        # #321 xy16: always verify under +mos-xy16 too — EVEN when the a16 leg is a known issue — so a
        # NEW xy16-only crash (e.g. an X-lattice regression) on a known-a16 program is never hidden by
        # the a16 XFAIL. (xy16 catches X-lattice regressions; that's the population most likely to hit one.)
        ok_xy, vlog_xy = verify_machineinstrs(src, WORK / "chk_xy.vo", flags=XY16, cflags=cflags)
        kid_xy = None if ok_xy else classify_known(vlog_xy)
        if not ok_xy and not kid_xy:
            # New, unclassified +mos-xy16 crash — hard fail even if the a16 leg was a known XFAIL.
            on_triage("verify-machineinstrs / compiler crash (+mos-xy16)", {"verify": vlog_xy})
            return "CRASH", "verify-machineinstrs (+mos-xy16) failed", None
        # No NEW crash on either leg. If either leg hit a known, already-diagnosed defect → XFAIL
        # (regalloc-out-of-registers, scavenger-p-not-gpr, …). Both legs of a pressure defect produce
        # the same kid in practice; report the a16 one when set, else the xy16 one.
        kid = kid_a or kid_xy
        if kid:
            return "XFAIL", "known issue [%s]" % kid, None

    # 2) compile default, +mos-a16, and +mos-xy16 ROMs
    try:
        dft_rom, dft_map   = WORK / "chk_default.sfc", WORK / "chk_default.map"
        a16_rom, a16_map   = WORK / "chk_a16.sfc",     WORK / "chk_a16.map"
        xy16_rom, xy16_map = WORK / "chk_xy16.sfc",    WORK / "chk_xy16.map"
        compile_rom(src, dft_rom, dft_map, flags=[], cflags=cflags)
        compile_rom(src, a16_rom, a16_map, flags=A16, cflags=cflags)
        compile_rom(src, xy16_rom, xy16_map, flags=XY16, cflags=cflags)
    except (CompileError, subprocess.TimeoutExpired) as e:
        # CompileError = link/checksum reject; TimeoutExpired = a link compile that hung
        # past every retry (environmental flakes already cleared inside _run). When verify
        # is skipped (Csmith path), a backend ICE first appears HERE as a CompileError, not
        # as a verify rejection — so classify_known() must run on the link error too, else a
        # KNOWN_ISSUES crash that surfaces only at the --config LTO compile (e.g. a regalloc/
        # scavenger ICE on a Csmith program) would mis-report as a new CRASH instead of XFAIL.
        kid = classify_known(str(e))
        if kid:
            return "XFAIL", "known issue [%s]" % kid, None
        on_triage("compile failure", {"error": str(e)})
        return "CRASH", "compile failure", None

    vma, size = map_lookup(a16_map, "corpus_result")
    dvma, _ = map_lookup(dft_map, "corpus_result")
    xvma, _ = map_lookup(xy16_map, "corpus_result")
    if vma is None or dvma is None or xvma is None:
        on_triage("corpus_result not in map", None)
        return "ERROR", "corpus_result not in map", None
    length = max(size, 1)

    # 3) run default@MAME, a16@MAME, xy16@MAME, a16@bsnes
    want = expected if expected is not None else 0
    got_default, ml_d  = run_mame(dft_rom,  0x7E0000 + dvma, want, length)
    got_a16, ml_a      = run_mame(a16_rom,  0x7E0000 + vma,  want, length)
    got_xy16, ml_xy    = run_mame(xy16_rom, 0x7E0000 + xvma, want, length)
    got_jg, jl = (None, "skip")
    if want_bsnes:
        got_jg, jl = run_bsnes(a16_rom, vma, length, want)

    # The reference: the host/baked value if given, else the trusted default build.
    ref = expected if expected is not None else got_default
    vals = {"default@MAME": got_default, "a16@MAME": got_a16, "xy16@MAME": got_xy16}
    if expected is not None:
        vals = {"host": expected, **vals}
    if got_jg not in (None, "skip"):
        vals["a16@bsnes"] = got_jg

    bad = [k for k, v in vals.items() if v != ref]
    if ref is None or bad:
        on_triage("value mismatch (ref=%s; %s)" % (ref, ", ".join(bad) or "no reference"), {
            "values": "\n".join("%-14s = %s" % (k, ("0x%04X" % v if isinstance(v, int) else v))
                                for k, v in vals.items()),
            "mame_default": ml_d, "mame_a16": ml_a, "mame_xy16": ml_xy, "bsnes_a16": jl,
        })
        return "FAIL", "mismatch: " + ", ".join(
            "%s=%s" % (k, ("0x%04X" % vals[k] if isinstance(vals[k], int) else vals[k])) for k in vals), ref
    tag = "0x%04X" % ref if isinstance(ref, int) else str(ref)
    return "PASS", "%s (all agree)" % tag, ref


def run_one(seed, want_bsnes=True, s32=False):
    """Generate program `seed`, then run it through the shared safety net."""
    g = Gen(seed, s32=s32)
    g.program()
    csrc = g.emit_c()
    expected = g.expected()
    src = WORK / "fuzz.c"
    WORK.mkdir(parents=True, exist_ok=True)
    src.write_text(csrc)
    on_triage = lambda reason, extra: (triage(seed, csrc, reason, extra)
                                       if "known issue" not in reason else None)
    status, msg, _ = evaluate(src, expected, want_bsnes, on_triage)
    if status == "XFAIL":
        save_known(seed, csrc, "cmp-value-selectimm")
    return status, msg


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def cmd_gen(args):
    g = Gen(args.seed, s32=getattr(args, "s32", False))
    g.program()
    sys.stdout.write(g.emit_c())
    sys.stderr.write("expected corpus_result = 0x%04X\n" % g.expected())


def triage_file(name, src_path, reason, extra=None):
    TRIAGE.mkdir(parents=True, exist_ok=True)
    base = TRIAGE / name
    try:
        base.with_suffix(".c").write_text(Path(src_path).read_text())
    except Exception:
        pass
    info = ["name=%s" % name, "reason: %s" % reason, ""]
    for k, v in (extra or {}).items():
        info += ["=== %s ===" % k, str(v), ""]
    base.with_suffix(".txt").write_text("\n".join(info))


def cmd_known_issues(args):
    """XPASS guard: assert every KNOWN_ISSUE_REPROS file STILL crashes -verify-machineinstrs under
    BOTH +mos-a16 and +mos-xy16 with its expected signature. Fails loudly the moment one verifies
    clean (the deferred bug got fixed) so the stale KNOWN_ISSUES entry is dropped + the repro
    promoted to a positive gate. Pure host verify — no container/SDK/emulator/secret needed."""
    WORK.mkdir(parents=True, exist_ok=True)
    legs = [("+mos-a16", A16), ("+mos-xy16", XY16)]
    total = len(KNOWN_ISSUE_REPROS) * len(legs)
    reproduces = 0
    fixed, drift = [], []
    print("==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify "
          "(+mos-a16 AND +mos-xy16)")
    for rel, kid in KNOWN_ISSUE_REPROS:
        src = ROOT / rel
        if not src.exists():
            print("  %-30s  MISSING SOURCE (%s)" % (rel, src))
            drift.append((rel, kid, "repro source missing"))
            continue
        for tag, flags in legs:
            ok, vlog = verify_machineinstrs(src, WORK / "ki.vo", flags=flags)
            if ok:
                print("  %-30s %-9s  XPASS — verifies CLEAN (issue [%s] no longer reproduces)"
                      % (rel, tag, kid))
                fixed.append((rel, kid, tag))
            else:
                got = classify_known(vlog)
                if got == kid:
                    print("  %-30s %-9s  xfail [%s] (still reproduces)" % (rel, tag, kid))
                    reproduces += 1
                else:
                    print("  %-30s %-9s  DRIFT — crashes but signature=%s, expected [%s]"
                          % (rel, tag, ("[%s]" % got) if got else "unclassified", kid))
                    drift.append((rel, kid, "signature %s != [%s] under %s"
                                  % (("[%s]" % got) if got else "unclassified", kid, tag)))
    print()
    if fixed:
        print("XPASS: %d known-issue repro/leg(s) NO LONGER REPRODUCE — the deferred bug looks FIXED:"
              % len(fixed))
        for rel, kid, tag in fixed:
            print("  - %s verifies clean under %s" % (rel, tag))
        # de-dup the kids needing action
        for kid in sorted({k for _, k, _ in fixed}):
            print("ACTION: drop KNOWN_ISSUES['%s'] (and its KNOWN_ISSUE_REPROS row) in tools/a16_fuzz.py,"
                  % kid)
            print("        then promote the repro to a POSITIVE gate (host==default==+mos-a16==+mos-xy16).")
    if drift:
        print("DRIFT: %d known-issue repro(s) changed signature/availability — investigate before trusting"
              " the XFAIL:" % len(drift))
        for rel, kid, why in drift:
            print("  - %s [%s]: %s" % (rel, kid, why))
    if fixed or drift:
        print("RESULT: FAIL — known-issue guard tripped (see ACTION/DRIFT above)")
        return 1
    print("RESULT: PASS — %d/%d known-issue legs still reproduce (XFAIL regression guard intact)"
          % (reproduces, total))
    return 0


def cmd_check(args):
    """Differential check of one fixed source (a kernel / combinatorial test)."""
    src = Path(args.src)
    if not src.exists():
        print("RESULT: FAIL (no such source: %s)" % src)
        return 1
    expected = int(args.expected, 16) if args.expected else None
    name = args.name or src.stem
    want_bsnes = not args.no_bsnes and JGX.exists() and JG_DB.is_dir()
    print("==> %s: differential default vs +mos-a16  (%s; bsnes=%s)"
          % (name,
             ("expected 0x%04X" % expected) if expected is not None else "default build as reference",
             "yes" if want_bsnes else "no"))
    status, msg, ref = evaluate(src, expected, want_bsnes, lambda r, e: triage_file(name, src, r, e))
    print("  [%s] %s  %s" % (status, name, msg))
    if status == "PASS":
        print("RESULT: PASS — %s: default == +mos-a16%s on both emulators" % (
            name, " == host" if expected is not None else ""))
        return 0
    if status == "XFAIL":
        print("RESULT: PASS (known issue) — %s: %s" % (name, msg))
        return 0
    print("RESULT: FAIL — %s (triage in %s)" % (msg, TRIAGE))
    return 1


def cmd_run(args):
    total = args.count
    base = args.seed
    npass = nfail = ncrash = nerr = nxfail = 0
    s32 = getattr(args, "s32", False)
    print("==> a16 differential fuzz: %d program(s), seeds %d..%d%s"
          % (total, base, base + total - 1, "  [+32-bit track]" if s32 else ""))
    print("    toolchain=%s  bsnes=%s" % (TOOL, "yes" if (JGX.exists() and JG_DB.is_dir()) else "no"))
    for i in range(total):
        seed = base + i
        try:
            status, msg = run_one(seed, want_bsnes=not args.no_bsnes, s32=s32)
        except Exception as e:  # never let one program kill the run
            status, msg = "ERROR", "exception: %r" % e
            try:
                triage(seed, Gen(seed, s32=s32).program() and Gen(seed, s32=s32).emit_c(), "driver exception", {"error": repr(e)})
            except Exception:
                pass
        tag = {"PASS": " ok ", "FAIL": "FAIL", "CRASH": "CRSH", "ERROR": "ERR ", "XFAIL": "xfail"}[status]
        print("  [%s] seed %5d  %s" % (tag, seed, msg))
        npass += status == "PASS"
        nfail += status == "FAIL"
        ncrash += status == "CRASH"
        nerr += status == "ERROR"
        nxfail += status == "XFAIL"
    print("==> fuzz: %d/%d PASS, %d known-issue (xfail)  (%d mismatch, %d new-crash, %d error)"
          % (npass, total, nxfail, nfail, ncrash, nerr))
    if nfail or ncrash or nerr:
        print("    triage artifacts in %s" % TRIAGE)
        return 1
    return 0


def main():
    try:  # stream per-program lines even when stdout is redirected to a log file
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="differential fuzzer for #321 +mos-a16 codegen")
    sub = ap.add_subparsers(dest="cmd", required=True)
    pg = sub.add_parser("gen", help="emit one generated program to stdout")
    pg.add_argument("--seed", type=int, required=True)
    pg.add_argument("--s32", action="store_true", help="include the 32-bit long/int32_t track")
    pg.set_defaults(func=cmd_gen)
    pr = sub.add_parser("run", help="compile+run+compare N programs")
    pr.add_argument("--count", type=int, default=25)
    pr.add_argument("--seed", type=int, default=1)
    pr.add_argument("--no-bsnes", action="store_true")
    pr.add_argument("--s32", action="store_true", help="include the 32-bit long/int32_t track")
    pr.set_defaults(func=cmd_run)
    pc = sub.add_parser("check", help="differential check of one fixed .c (kernel/combinatorial test)")
    pc.add_argument("--src", required=True)
    pc.add_argument("--expected", help="baked reference value, hex (e.g. 0x29B1); omit to use the default build")
    pc.add_argument("--name")
    pc.add_argument("--no-bsnes", action="store_true")
    pc.set_defaults(func=cmd_check)
    pk = sub.add_parser("known-issues",
                        help="XPASS guard: assert each KNOWN_ISSUES repro still crashes verify "
                             "(fails loudly when a deferred bug is fixed → drop the entry)")
    pk.set_defaults(func=cmd_known_issues)
    args = ap.parse_args()
    rc = args.func(args)
    sys.exit(rc or 0)


if __name__ == "__main__":
    main()
