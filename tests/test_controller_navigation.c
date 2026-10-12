#include "controller_navigation.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
  assert(controller_navigation_touch(0, -80, 100, 0) == CONTROLLER_TOUCH_UP);
  assert(controller_navigation_touch(0, -80, 100, 180) ==
         CONTROLLER_TOUCH_DOWN);
  assert(controller_navigation_touch(-80, 0, 100, 0) == CONTROLLER_TOUCH_LEFT);
  assert(controller_navigation_touch(-80, 0, 100, 180) ==
         CONTROLLER_TOUCH_RIGHT);
  assert(controller_navigation_touch(80, 120, 100, 0) == CONTROLLER_TOUCH_DOWN);
  assert(controller_navigation_touch(120, 80, 100, 0) ==
         CONTROLLER_TOUCH_RIGHT);
  assert(controller_navigation_touch(50, 50, 100, 0) == CONTROLLER_TOUCH_NONE);
  assert(controller_navigation_touch(0, -80, 500, 0) == CONTROLLER_TOUCH_NONE);
  assert(controller_navigation_touch(0, 0, 600, 0) == CONTROLLER_TOUCH_NONE);
  assert(controller_navigation_touch(8, 8, 100, 0) == CONTROLLER_TOUCH_TAP);
  assert(controller_navigation_touch(40, 0, 100, 0) == CONTROLLER_TOUCH_NONE);
  for (int page = 0; page < CONTROLLER_SCREEN_COUNT; page++)
    assert(controller_navigation_encoder_uses_volume(page) ==
           (page == CONTROLLER_SCREEN_ARTWORK ||
            page == CONTROLLER_SCREEN_NOW_PLAYING));
  assert(!controller_navigation_encoder_uses_volume(99));
  puts("controller navigation contracts passed");
}
