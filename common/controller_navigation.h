#pragma once
#include <stdbool.h>
#include <stdint.h>
typedef enum {
  CONTROLLER_SCREEN_ARTWORK,
  CONTROLLER_SCREEN_NOW_PLAYING,
  CONTROLLER_SCREEN_LIBRARY,
  CONTROLLER_SCREEN_ZONES,
  CONTROLLER_SCREEN_SETTINGS,
  CONTROLLER_SCREEN_COUNT
} controller_screen_t;
typedef enum {
  CONTROLLER_TOUCH_NONE,
  CONTROLLER_TOUCH_TAP,
  CONTROLLER_TOUCH_UP,
  CONTROLLER_TOUCH_DOWN,
  CONTROLLER_TOUCH_LEFT,
  CONTROLLER_TOUCH_RIGHT
} controller_touch_t;
controller_touch_t
controller_navigation_touch(int dx, int dy, int64_t elapsed_ms, int rotation);
bool controller_navigation_encoder_uses_volume(controller_screen_t screen);
