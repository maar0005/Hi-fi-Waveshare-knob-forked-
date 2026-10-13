#pragma once
#include <stdbool.h>
void controller_touch_navigation_process(void);
bool controller_touch_navigation_encoder(int delta);
void controller_touch_navigation_settings(void);
bool controller_touch_navigation_settings_visible(void);
void controller_touch_navigation_close_settings(void);
void controller_touch_navigation_show_artwork(void);
void controller_touch_navigation_restore_visibility(void);
