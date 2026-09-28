#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/extload.h"
volatile uint16_t corpus_result;
int main(void) {
    static Display screen; static TextLayer text; static TitleLayer title;
    display_init(&screen); text_init(&text, 0x4000u, 1u, 25u);
    display_add(&screen, (Drawable *)&text);
    text_puts(&text, 0, 1, "EXTENDING LOAD MATRIX");
    title_begin16(&screen, &title, "EXTENDING LOAD", "SIGN MATRIX");
    corpus_result = extload_gate_crc(); title_end(&screen, &title, 90u);
    for (;;) display_frame(&screen);
}
