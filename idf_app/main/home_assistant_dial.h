// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
/* Dial Home Assistant light runtime. Implements platform_lights.h; the web
 * settings page uses the configuration calls below. */
#pragma once
#include "home_assistant_lights.h"
#include <stdbool.h>
#include <stddef.h>

typedef enum {
  HA_DIAL_SAVE_INVALID = 0,
  HA_DIAL_SAVE_STORAGE_FAILED,
  HA_DIAL_SAVE_OK,
  HA_DIAL_SAVE_CLEARED,
} ha_dial_save_result_t;

/* Call once after nvs_flash_init(). Loads saved lights; no network work. */
void home_assistant_dial_init(void);
/* Copies the active configuration without the token. */
void home_assistant_dial_config(ha_lights_config_t *out, bool *has_token);
/* Validates, persists and applies a candidate. An empty token keeps the saved
 * one. An empty URL with no lights clears the feature. Rows with an empty
 * entity are dropped; `error` explains an INVALID result. */
ha_dial_save_result_t home_assistant_dial_save(const ha_lights_config_t *candidate,
                                               char *error, size_t error_size);
