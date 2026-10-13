#include "platform/platform_touch_navigation.h"
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

const lv_font_t *platform_touch_font_small(void) { return font_manager_get_small(); }
const lv_font_t *platform_touch_font_normal(void) { return font_manager_get_normal(); }
