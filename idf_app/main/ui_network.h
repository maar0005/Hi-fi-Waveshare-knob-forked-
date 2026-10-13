#pragma once

#include "wifi_manager.h"

void ui_network_register_menu(void); // adds Settings→Network screen
void ui_network_on_event(rk_net_evt_t evt, const char *ip_opt);
void ui_network_set_ble_status(const char *status);

void ui_network_show_device_controls(void);
void ui_network_hide_device_controls(void);
bool ui_network_device_controls_visible(void);
void ui_network_scroll_device_controls(int delta);
