#include "controller_navigation.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
  for (int page = 0; page < CONTROLLER_SCREEN_COUNT; page++)
    assert(controller_navigation_encoder_uses_volume(page) ==
           (page == CONTROLLER_SCREEN_ARTWORK ||
            page == CONTROLLER_SCREEN_NOW_PLAYING));
  assert(!controller_navigation_encoder_uses_volume(99));
  puts("controller navigation contracts passed");
}
