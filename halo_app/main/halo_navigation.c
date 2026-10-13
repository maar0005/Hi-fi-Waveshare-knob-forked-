/* Compatibility facade; both round targets use the shared touch renderer. */
#include "halo_navigation.h"
#include "controller_touch_navigation.h"
void halo_navigation_process(void) { controller_touch_navigation_process(); }
bool halo_navigation_encoder(int delta) { return controller_touch_navigation_encoder(delta); }
void halo_navigation_settings(void) { controller_touch_navigation_settings(); }
bool halo_navigation_settings_visible(void) { return controller_touch_navigation_settings_visible(); }
void halo_navigation_close_settings(void) { controller_touch_navigation_close_settings(); }
