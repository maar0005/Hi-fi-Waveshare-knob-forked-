#include "platform/platform_touch_navigation.h"
#include "font_manager.h"
#include "display_sleep.h"
#include "ui_network.h"
#include <nvs.h>
#include <esp_err.h>
void platform_touch_set_brightness(int percent) { display_set_user_brightness(percent); }
int platform_touch_load_brightness(void) {
    nvs_handle_t handle;
    uint8_t value = 100;
    if (nvs_open("hiphi_dial", NVS_READONLY, &handle) == ESP_OK) {
        if (nvs_get_u8(handle, "brightness", &value) != ESP_OK) value = 100;
        nvs_close(handle);
    }
    return value >= 5 && value <= 100 ? value : 100;
}
bool platform_touch_save_brightness(int percent) {
    if (percent < 5 || percent > 100) return false;
    nvs_handle_t handle;
    if (nvs_open("hiphi_dial", NVS_READWRITE, &handle) != ESP_OK) return false;
    esp_err_t err = nvs_set_u8(handle, "brightness", (uint8_t)percent);
    if (err == ESP_OK) err = nvs_commit(handle);
    uint8_t saved = 0;
    if (err == ESP_OK) err = nvs_get_u8(handle, "brightness", &saved);
    nvs_close(handle);
    return err == ESP_OK && saved == percent;
}
void platform_touch_screen_changed(controller_screen_t screen) {
    ui_network_hide_device_controls();
    if (screen == CONTROLLER_SCREEN_ARTWORK) display_art_mode();
    else { display_wake(); display_activity_detected(); }
}
bool platform_touch_has_device_controls(void) { return true; }
void platform_touch_show_device_controls(void) { ui_network_show_device_controls(); }
bool platform_touch_device_controls_visible(void) { return ui_network_device_controls_visible(); }
void platform_touch_scroll_device_controls(int delta) { ui_network_scroll_device_controls(delta); }

const lv_font_t *platform_touch_font_small(void) { return font_manager_get_small(); }
const lv_font_t *platform_touch_font_normal(void) { return font_manager_get_normal(); }
