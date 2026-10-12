#include "controller_navigation.h"
#include <stdlib.h>
controller_touch_t
controller_navigation_touch(int dx, int dy, int64_t elapsed_ms, int rotation) {
  if (elapsed_ms < 0 || elapsed_ms >= 500)
    return CONTROLLER_TOUCH_NONE;
  if (rotation == 180) {
    dx = -dx;
    dy = -dy;
  }
  if (abs(dx) >= 60 || abs(dy) >= 60) {
    if (abs(dy) > abs(dx))
      return dy < 0 ? CONTROLLER_TOUCH_UP : CONTROLLER_TOUCH_DOWN;
    return dx < 0 ? CONTROLLER_TOUCH_LEFT : CONTROLLER_TOUCH_RIGHT;
  }
  return abs(dx) < 40 && abs(dy) < 40 ? CONTROLLER_TOUCH_TAP
                                      : CONTROLLER_TOUCH_NONE;
}
bool controller_navigation_encoder_uses_volume(controller_screen_t screen) {
  return screen == CONTROLLER_SCREEN_ARTWORK ||
         screen == CONTROLLER_SCREEN_NOW_PLAYING;
}
