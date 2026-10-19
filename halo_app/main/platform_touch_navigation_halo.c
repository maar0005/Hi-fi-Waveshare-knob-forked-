#include "platform/platform_touch_navigation.h"
#include "platform/platform_lights.h"
#include "font_manager.h"
#include "platform_display_halo.h"
void platform_touch_set_brightness(int percent) { platform_display_set_brightness(percent); }
int platform_touch_load_brightness(void) { return platform_display_load_brightness(); }
bool platform_touch_save_brightness(int percent) { return platform_display_save_brightness(percent); }
void platform_touch_screen_changed(controller_screen_t screen) { (void)screen; }
bool platform_touch_has_device_controls(void) { return false; }
void platform_touch_show_device_controls(void) {}
bool platform_touch_device_controls_visible(void) { return false; }
void platform_touch_scroll_device_controls(int delta) { (void)delta; }
/* HALO has no light integration; the Lights menu entry stays hidden. */
int platform_lights_count(void) { return 0; }
bool platform_lights_view(int index, platform_light_view_t *out) { (void)index; (void)out; return false; }
uint32_t platform_lights_revision(void) { return 0; }
void platform_lights_refresh(int index) { (void)index; }
void platform_lights_set_brightness(int index, int percent) { (void)index; (void)percent; }
void platform_lights_toggle(int index) { (void)index; }

const lv_font_t *platform_touch_font_small(void) { return font_manager_get_small(); }
const lv_font_t *platform_touch_font_normal(void) { return font_manager_get_normal(); }
