#pragma once
#include "controller_navigation.h"
#include <stdbool.h>
#include "lvgl.h"
void platform_touch_set_brightness(int percent);
int platform_touch_load_brightness(void);
bool platform_touch_save_brightness(int percent);
void platform_touch_screen_changed(controller_screen_t screen);
bool platform_touch_has_device_controls(void);
void platform_touch_show_device_controls(void);
bool platform_touch_device_controls_visible(void);
void platform_touch_scroll_device_controls(int delta);

const lv_font_t *platform_touch_font_small(void);
const lv_font_t *platform_touch_font_normal(void);
