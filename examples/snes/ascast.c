// Build contract for dev/build.sh's example battery (grammar: dev/build.sh).
// mos-a16-only: the near-to-far address-space cast needs +mos-a16 (G_MERGE_VALUES legalization); see docs/defects/mos-default-mode-far-cast-legalization.json.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ascast.h"
volatile uint16_t corpus_result;
int main(void) {
    static Display screen; static TextLayer text; static TitleLayer title;
    display_init(&screen); text_init(&text, 0x4000u, 1u, 25u);
    display_add(&screen, (Drawable *)&text);
    text_puts(&text, 0, 1, "ADDRESS SPACE CASTS");
    title_begin16(&screen, &title, "NEAR TO FAR", "CAST LADDER");
    corpus_result = ascast_gate_crc(); title_end(&screen, &title, 90u);
    for (;;) display_frame(&screen);
}
