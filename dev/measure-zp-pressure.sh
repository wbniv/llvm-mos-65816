#!/usr/bin/env bash
# Measure per-function imaginary-register (zero-page) high-water mark under +mos-a16.
# Standalone, host-only. Serves the CC-frame DP-window revival trigger AND the
# multi-value-register-pressure Phase 0 scan. See
# docs/plans/2026-06-18-321-zp-pressure-measurement.md.
#
# Metric: distinct allocatable __rc<N> referenced per function in -S output. The register
# allocator reuses imaginary registers across non-overlapping live ranges, so the count of
# DISTINCT names a function touches approximates its peak imaginary-register pressure.
# Reserved names excluded: __rc0/__rc1 (soft-SP = RS0), __rc16/__rc17 (scavenger = RS8).
# Usable 16-bit pool = 14 pairs = 28 bytes (RS1-RS7, RS9-RS15); a function near/over ~28
# distinct __rc bytes is "ZP-tight" / pool-exhausting.
set -euo pipefail

usage() {
  cat <<'EOF'
measure-zp-pressure.sh - per-function imaginary-register high-water mark (+mos-a16 -Os)

Counts distinct allocatable __rc<N> per function (proxy for peak zero-page pressure),
over: a synthetic low->exhausting ladder, the 6 kernels, the 6 corpus programs, and the
a16* micro-tests. Prints per-function rows for real code + a summary with the verdict
inputs for the CC-frame DP-window decision and the multi-value Phase-0 scan.

Env overrides: CLANG, OBJDUMP (default $ROOT/build/llvm-mos-install/bin/...).
Usage: dev/measure-zp-pressure.sh [-h|--help]
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
CFLAGS=(--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os)
BUDGET_BYTES=28   # 14 usable 16-bit pairs

[[ -x "$CLANG" ]] || { echo "ERROR: CLANG not found/executable: $CLANG (set CLANG=...)" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Emit "<func>\t<distinct_rc>" for each function in a .s file.
zp_per_func() {  # $1 = .s
  awk '
    function flush(  r,n) { if (fn!="") { n=0; for (r in seen) n++; printf "%s\t%d\n", fn, n } delete seen; fn="" }
    /^[ \t]*\.section[ \t]+"?\.text/ { intext=1; next }
    /^[ \t]*\.text\b/                { intext=1; next }
    /^[ \t]*\.section[ \t]+"?\.(rodata|data|bss)/ { flush(); intext=0; next }
    /^[ \t]*\.(rodata|data|bss|zeropage|globl|type|size|p2align|cfi|file|ident|addrsig)/ { next }
    /^[A-Za-z_][A-Za-z0-9_$.]*:/ {
      lbl=$0; sub(/:.*/,"",lbl)
      if (intext && lbl !~ /^\.L/) { flush(); fn=lbl }
      next
    }
    { if (fn=="") next
      s=$0
      while (match(s,/__rc[0-9]+/)) {
        tok=substr(s,RSTART,RLENGTH); num=substr(tok,5)+0
        if (num!=0 && num!=1 && num!=16 && num!=17) seen[tok]=1
        s=substr(s,RSTART+RLENGTH)
      }
    }
    END { flush() }
  ' "$1"
}

compile_s() {  # $1=src $2=out.s
  "$CLANG" "${CFLAGS[@]}" -S "$1" -o "$2" 2>/dev/null
}

# results accumulator: "<group>\t<prog>\t<func>\t<count>"
RES="$tmp/res.tsv"; : > "$RES"
record() {  # $1=group $2=prog $3=src
  local s="$tmp/$2.s"
  if ! compile_s "$3" "$s"; then echo "  (compile failed: $2)"; return; fi
  while IFS=$'\t' read -r fn n; do printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$fn" "$n" >> "$RES"; done < <(zp_per_func "$s")
}

row() { awk -v p="$2" -v f="$3" -v n="$4" 'BEGIN{printf "  %-22s distinct_rc=%-3s (~%.0f pairs)\n", p":"f, n, n/2}'; }

echo "=== synthetic calibration ladder (known pressure; rep/sep bracket cross-check) ==="
cat > "$tmp/syn1.c" <<'EOF'
typedef unsigned short u16; volatile u16 a,b,c,d,r0;
void syn1(void){ r0 = a + b + c + d; }            /* 1 live value */
EOF
cat > "$tmp/syn2.c" <<'EOF'
typedef unsigned short u16; volatile u16 a,b,c,d,e,f,r0,r1;
void syn2(void){ u16 t=a+b+c; u16 u=d+e+f; r0=t&u; r1=t|u; }   /* 2 live */
EOF
cat > "$tmp/syn3.c" <<'EOF'
typedef unsigned short u16; volatile u16 a,b,c,d,e,f,g,h,r0;
void syn3(void){ u16 v0=a+b,v1=b+c,v2=c+d,v3=d+e,w0=e+f,w1=f+g,w2=g+h,w3=h+a;
  r0=(v0^w0)+(v1^w1)+(v2^w2)+(v3^w3); }                        /* 8 live */
EOF
cat > "$tmp/syn4.c" <<'EOF'
typedef unsigned short u16; volatile u16 in[24], out;
void syn4(void){ u16 t0=in[0]+in[1],t1=in[1]+in[2],t2=in[2]+in[3],t3=in[3]+in[4],
  t4=in[4]+in[5],t5=in[5]+in[6],t6=in[6]+in[7],t7=in[7]+in[8],t8=in[8]+in[9],t9=in[9]+in[10],
  ta=in[10]+in[11],tb=in[11]+in[12],tc=in[12]+in[13],td=in[13]+in[14],te=in[14]+in[15],
  tf=in[15]+in[16],tg=in[16]+in[17],th=in[17]+in[18],ti=in[18]+in[19],tj=in[19]+in[20];
  out=(t0^t1)+(t2^t3)+(t4^t5)+(t6^t7)+(t8^t9)+(ta^tb)+(tc^td)+(te^tf)+(tg^th)+(ti^tj); } /* ~20 live */
EOF
for s in syn1 syn2 syn3 syn4; do
  record synthetic "$s" "$tmp/$s.c"
  compile_s "$tmp/$s.c" "$tmp/$s.s"
  brk=$(grep -cE '^\s*(rep|sep)\b' "$tmp/$s.s" || true)
  while IFS=$'\t' read -r fn n; do
    awk -v f="$s" -v n="$n" -v b="$brk" 'BEGIN{printf "  %-8s distinct_rc=%-3s (~%.0f pairs)  rep+sep=%s\n", f, n, n/2, b}'
  done < <(zp_per_func "$tmp/$s.s")
done

echo ""
echo "=== kernels (real code) ==="
for f in "$ROOT"/examples/65816/k_*.c; do [[ -e "$f" ]] || continue; record kernel "$(basename "$f" .c)" "$f"; done
awk -F'\t' '$1=="kernel"{printf "  %-22s distinct_rc=%-3s (~%.0f pairs)\n",$2":"$3,$4,$4/2}' "$RES"

echo ""
echo "=== corpus (real code) ==="
for f in "$ROOT"/examples/snes/corpus/*.c; do [[ -e "$f" ]] || continue; record corpus "$(basename "$f" .c)" "$f"; done
awk -F'\t' '$1=="corpus"{printf "  %-22s distinct_rc=%-3s (~%.0f pairs)\n",$2":"$3,$4,$4/2}' "$RES"

echo ""
echo "=== a16 micro-tests (floor reference; summarized) ==="
for f in "$ROOT"/examples/65816/a16*.c; do [[ -e "$f" ]] || continue; record a16 "$(basename "$f" .c)" "$f"; done

echo ""
echo "=== SUMMARY ==="
awk -F'\t' -v BUD="$BUDGET_BYTES" '
  $1=="kernel"||$1=="corpus"{ real[nr++]=$4; if($4>rmax){rmax=$4;rmaxf=$2":"$3}; rsum+=$4; if($4>=24)tight++; if($4>BUD)exh++ }
  $1=="a16"{ a[na++]=$4; if($4>amax)amax=$4; asum+=$4 }
  $1=="synthetic"{}
  END{
    printf "real-code functions (kernels+corpus): n=%d  max=%d bytes (%s)  mean=%.1f\n", nr, rmax, rmaxf, (nr?rsum/nr:0)
    printf "  functions >= 24 bytes (~12+ pairs, near ceiling): %d\n", tight+0
    printf "  functions  > %d bytes  (pool-exhausting):          %d\n", BUD, exh+0
    printf "a16 micro-tests: n=%d  max=%d  mean=%.1f (leaf floor reference)\n", na, amax, (na?asum/na:0)
    print  ""
    print  "VERDICT INPUTS:"
    printf "  CC-frame DP-window:  ZP is %s (max real-code function = %d/%d-byte budget).\n", (rmax>=24?"TIGHT - revisit (a)":"SLACK - (c) stands, shelve (a) with evidence"), rmax, BUD
    printf "  multi-value Phase 0: pool-exhausting real functions = %d => %s\n", exh+0, (exh>0?"PROCEED (spill-fusion has a trigger)":"DEFER confirmed (no real function exhausts the pool)")
  }' "$RES"
