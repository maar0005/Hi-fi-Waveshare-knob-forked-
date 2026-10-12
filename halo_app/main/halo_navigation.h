#pragma once
#include <stdbool.h>
void halo_navigation_process(void);
void halo_navigation_swipe(int dx, int dy);
bool halo_navigation_encoder(int delta);
void halo_navigation_settings(void);
bool halo_navigation_settings_visible(void);
void halo_navigation_close_settings(void);
