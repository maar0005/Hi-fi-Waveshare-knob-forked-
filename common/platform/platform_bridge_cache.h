// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#pragma once
#include <stdbool.h>
#include <stdint.h>
/* Sidecar only: never replaces the user's selected hostname or zone. */
typedef struct {
    uint32_t version;
    char selected[128];
    char endpoint[128];
    char network[96];
} platform_bridge_cache_t;
bool platform_bridge_cache_read(platform_bridge_cache_t *out);
void platform_bridge_cache_write(const platform_bridge_cache_t *value);
