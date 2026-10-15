// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
/* Exercise the production NVS adapter, including malformed persisted records. */
#include "platform/platform_bridge_cache.h"
#include <nvs.h>
#include <assert.h>
#include <string.h>
static platform_bridge_cache_t persisted;
static size_t stored_size;
static unsigned writes, commits;
static bool fail_open, fail_set;
esp_err_t nvs_open(const char *ns, int mode, nvs_handle_t *h) {
    assert(strcmp(ns, "rk_bridge") == 0); (void)mode; *h = 1; return fail_open ? -1 : 0;
}
esp_err_t nvs_get_blob(nvs_handle_t h, const char *key, void *out, size_t *size) {
    (void)h; assert(strcmp(key, "verified") == 0);
    if (stored_size > *size || !stored_size) return -1;
    memcpy(out, &persisted, stored_size); *size = stored_size; return 0;
}
esp_err_t nvs_set_blob(nvs_handle_t h, const char *key, const void *in, size_t size) {
    (void)h; (void)key; ++writes;
    if (fail_set) return -1;
    assert(size == sizeof(persisted)); memcpy(&persisted, in, size); stored_size = size; return 0;
}
esp_err_t nvs_commit(nvs_handle_t h) { (void)h; ++commits; return 0; }
void nvs_close(nvs_handle_t h) { (void)h; }
int main(void) {
    platform_bridge_cache_t v = {.version = 1, .selected = "http://nas.local:8088",
        .endpoint = "http://192.168.1.2:8088", .network = "home|192.168.1.1|255.255.255.0"}, out;
    assert(!platform_bridge_cache_read(&out));
    platform_bridge_cache_write(&v); assert(writes == 1 && commits == 1);
    for (int i = 0; i < 100; ++i) platform_bridge_cache_write(&v);
    assert(writes == 1); /* Routine polling never wears flash. */
    assert(platform_bridge_cache_read(&out) && !memcmp(&v, &out, sizeof(v)));
    persisted.version = 9; assert(!platform_bridge_cache_read(&out));
    persisted = v; stored_size--; assert(!platform_bridge_cache_read(&out));
    stored_size = sizeof(v); memset(persisted.network, 'x', sizeof(persisted.network));
    assert(!platform_bridge_cache_read(&out));
    persisted = v; strcpy(persisted.endpoint, "http://other.local:8088");
    assert(!platform_bridge_cache_read(&out));
    fail_open = true; assert(!platform_bridge_cache_read(&out));
    platform_bridge_cache_write(&v); assert(writes == 1);
    fail_open = false; fail_set = true;
    platform_bridge_cache_write(&v); assert(writes == 2 && commits == 1);
    return 0;
}
