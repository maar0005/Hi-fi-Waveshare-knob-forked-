// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#include "platform_bridge_cache.h"
#include "platform_mdns_endpoint.h"
#include <nvs.h>
#include <lwip/inet.h>
#include <lwip/sockets.h>
#include <string.h>

static bool valid(const platform_bridge_cache_t *v) {
    char host[64];
    struct in_addr ip;
    return v->version == 1 && memchr(v->selected, 0, sizeof(v->selected)) &&
        memchr(v->endpoint, 0, sizeof(v->endpoint)) &&
        memchr(v->network, 0, sizeof(v->network)) && v->network[0] &&
        platform_mdns_url_host(v->selected, host, sizeof(host), NULL) &&
        platform_mdns_url_host(v->endpoint, host, sizeof(host), NULL) &&
        inet_pton(AF_INET, host, &ip) == 1;
}
bool platform_bridge_cache_read(platform_bridge_cache_t *out) {
    nvs_handle_t handle;
    if (!out || nvs_open("rk_bridge", NVS_READONLY, &handle) != ESP_OK) return false;
    size_t size = sizeof(*out);
    esp_err_t err = nvs_get_blob(handle, "verified", out, &size);
    nvs_close(handle);
    return err == ESP_OK && size == sizeof(*out) && valid(out);
}
void platform_bridge_cache_write(const platform_bridge_cache_t *value) {
    if (!value || !valid(value)) return;
    platform_bridge_cache_t old;
    if (platform_bridge_cache_read(&old) && memcmp(&old, value, sizeof(old)) == 0) return;
    nvs_handle_t handle;
    if (nvs_open("rk_bridge", NVS_READWRITE, &handle) != ESP_OK) return;
    if (nvs_set_blob(handle, "verified", value, sizeof(*value)) == ESP_OK)
        (void)nvs_commit(handle);
    nvs_close(handle);
}
