// Mini variadic sprintf — portable, SNES demo #32.
//
// Implements mini_sprintf(buf, fmt, ...) supporting %u, %d, %x for uint16/int16 values.
// The va_arg calls exercise the variadic calling convention on the 65816:
//   va_arg(ap, unsigned int) — reads a 16-bit value from the variadic argument area
//   va_arg(ap, int)          — reads a signed 16-bit value
//
// On the 65816 with llvm-mos, variadic arguments are passed via the imaginary-register
// / soft-stack ABI. va_start() sets ap to the first variadic argument; va_arg() reads
// the value and advances ap. This is the first demo in the battery that exercises
// the variadic calling convention — an ABI corner none of the prior 31 demos touch.
//
// Width rules: unsigned int is 16-bit on the 65816 target (llvm-mos sets int = 16).
// va_arg(ap, unsigned int) reads exactly 2 bytes on target, 4 bytes on host (x86).
// The gate CRC passes small values (≤ 999) that are identical in both widths → bit-exact.
//
// NO bare int in return types or struct members — see CLAUDE.md §width rules.
// (va_arg *arguments* must use `unsigned int` or `int` per C promotion rules.)
#ifndef VAPRINTF_H
#define VAPRINTF_H

#include <stdarg.h>
#include <stdint.h>

/* Write decimal string of unsigned v (no leading zeros unless v==0) into buf.
   Returns number of characters written (no NUL). */
static uint8_t va_fmt_u(char *buf, uint16_t v) {
    char tmp[5]; uint8_t n = 0;
    if (!v) { buf[0] = '0'; return 1; }
    while (v) { tmp[n++] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; }
    for (uint8_t i = 0; i < n; i++) buf[i] = tmp[(uint8_t)(n - 1u - i)];
    return n;
}

/* Write 4-digit hex string of v (zero-padded) into buf. Returns 4. */
static uint8_t va_fmt_x(char *buf, uint16_t v) {
    static const char HEX[16] = "0123456789abcdef";
    buf[0] = HEX[(v >> 12) & 0xFu];
    buf[1] = HEX[(v >>  8) & 0xFu];
    buf[2] = HEX[(v >>  4) & 0xFu];
    buf[3] = HEX[(v      ) & 0xFu];
    return 4;
}

/* Mini variadic sprintf: writes NUL-terminated formatted string into buf.
   Supports: %u (uint16), %d (int16), %x (uint16 hex 4-digit), %% literal percent.
   All other conversions: written as-is after %. Caller ensures buf is large enough. */
static void mini_sprintf(char *buf, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    char *out = buf;
    for (; *fmt; fmt++) {
        if (*fmt != '%') { *out++ = *fmt; continue; }
        fmt++;
        switch (*fmt) {
        case 'u': {
            uint16_t v = (uint16_t)va_arg(ap, unsigned int);  /* va_arg: 16-bit on target */
            out += va_fmt_u(out, v);
            break;
        }
        case 'd': {
            int16_t v = (int16_t)va_arg(ap, int);             /* va_arg: signed 16-bit */
            if (v < 0) { *out++ = '-'; v = (int16_t)-v; }
            out += va_fmt_u(out, (uint16_t)v);
            break;
        }
        case 'x': {
            uint16_t v = (uint16_t)va_arg(ap, unsigned int);
            out += va_fmt_x(out, v);
            break;
        }
        case '%': *out++ = '%'; break;
        default:  *out++ = '%'; *out++ = *fmt; break;
        }
    }
    *out = '\0';
    va_end(ap);
}

/* Gate CRC: call mini_sprintf with various fixed arguments, fold output characters.
   4 calls × 2-3 va_arg each = 9 variadic reads total.
   Values are small (≤ 0xFFFF) so result is identical on 16-bit target and 32-bit host. */
static inline uint16_t vaprintf_gate_crc(void) {
    char buf[32];
    uint16_t h = 0;
    mini_sprintf(buf, "%u+%u", (unsigned)123u, (unsigned)456u);      /* "123+456"    */
    for (const char *p = buf; *p; p++) h = (uint16_t)((h<<1)|(h>>15)) ^ (uint16_t)(uint8_t)*p;
    mini_sprintf(buf, "%d/%u", (int)-7, (unsigned)3u);                /* "-7/3"      */
    for (const char *p = buf; *p; p++) h = (uint16_t)((h<<1)|(h>>15)) ^ (uint16_t)(uint8_t)*p;
    mini_sprintf(buf, "%x %x", (unsigned)0xBEEFu, (unsigned)0xCAFEu); /* "beef cafe" */
    for (const char *p = buf; *p; p++) h = (uint16_t)((h<<1)|(h>>15)) ^ (uint16_t)(uint8_t)*p;
    mini_sprintf(buf, "%u %d %x", (unsigned)999u, (int)-1, (unsigned)0xABCDu); /* "999 -1 abcd" */
    for (const char *p = buf; *p; p++) h = (uint16_t)((h<<1)|(h>>15)) ^ (uint16_t)(uint8_t)*p;
    return h;
}

#endif /* VAPRINTF_H */
