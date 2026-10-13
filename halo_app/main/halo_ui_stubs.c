/* HALO uses its full-screen navigation settings; OTA remains unsupported. */
#include "ui.h"
#include "halo_navigation.h"
#include "ota_update.h"
#include <esp_log.h>

void ui_show_settings(void) { halo_navigation_settings(); }
void ui_hide_settings(void) { halo_navigation_close_settings(); }
bool ui_is_settings_visible(void) { return halo_navigation_settings_visible(); }
void ota_start_update(void) { ESP_LOGW("ota", "OTA not supported on HALO yet"); }
