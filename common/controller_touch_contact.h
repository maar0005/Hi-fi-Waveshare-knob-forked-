#pragma once
#include <stdbool.h>
#include <stdint.h>
/* Consume the complete contact that wakes a panel, even after the wake window
 * expires. Preserve raw coordinates: LVGL owns display rotation. */
typedef struct { int16_t x, y; bool consume_until_release; } controller_touch_contact_t;
static inline bool controller_touch_contact_feed(controller_touch_contact_t *contact,
    bool down, int16_t x, int16_t y, bool asleep, bool suppressed) {
    if (!down) { contact->consume_until_release = false; return false; }
    contact->x = x; contact->y = y;
    if (asleep || suppressed) contact->consume_until_release = true;
    return !contact->consume_until_release;
}
