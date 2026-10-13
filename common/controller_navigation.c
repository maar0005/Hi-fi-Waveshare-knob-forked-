#include "controller_navigation.h"
bool controller_navigation_encoder_uses_volume(controller_screen_t screen) {
  return screen == CONTROLLER_SCREEN_ARTWORK ||
         screen == CONTROLLER_SCREEN_NOW_PLAYING;
}
