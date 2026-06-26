/* snesgfx — Controller: a joypad object with edge detection.
 *
 * controller_poll() reads pad 1 (manual serial, AUTOJOY off); held/pressed/released expose the
 * current state and this-frame edges. Methods on an object (no bare reads in game code). For the
 * deterministic gate the pad reads a constant 0 on both emulators, so attract stays reproducible.
 *
 * Header-only (static inline). */
#ifndef SNESGFX_CONTROLLER_H
#define SNESGFX_CONTROLLER_H

#include <snes.h>

typedef struct { uint16_t cur, prev; } Controller;

static inline void controller_init(Controller *c) { c->cur = 0; c->prev = 0; }
static inline void controller_poll(Controller *c) { c->prev = c->cur; c->cur = snes_read_pad1(); }
static inline uint16_t controller_held    (const Controller *c) { return c->cur; }
static inline uint16_t controller_pressed (const Controller *c) { return (uint16_t)(c->cur & (uint16_t)~c->prev); }
static inline uint16_t controller_released(const Controller *c) { return (uint16_t)((uint16_t)~c->cur & c->prev); }

#endif /* SNESGFX_CONTROLLER_H */
