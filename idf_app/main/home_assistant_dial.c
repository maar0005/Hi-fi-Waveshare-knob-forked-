// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
/* Home Assistant lights on the Dial: target-local NVS configuration, one
 * network worker, and the platform_lights view used by touch navigation.
 * The UI never blocks: it records the desired brightness and the worker sends
 * the latest value, so a fast knob turn produces a few requests, not dozens. */
#include "home_assistant_dial.h"
#include "platform/platform_lights.h"
#include "cJSON.h"
#include <esp_heap_caps.h>
#include <esp_http_client.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
#include <nvs.h>
#include <sdkconfig.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if CONFIG_MBEDTLS_CERTIFICATE_BUNDLE
#include <esp_crt_bundle.h>
#endif

static const char *TAG = "home_assistant";

#define NVS_NAMESPACE "hiphi_ha"
#define STATE_MAX_BYTES 8192
#define HTTP_TIMEOUT_MS 4000
#define WORKER_STACK 12288
/* Brightness sentinel: turn on at the light's previous brightness. */
#define PCT_PREVIOUS (-1)

typedef struct {
  platform_light_view_t view;
  bool command_pending, refresh_pending, in_flight;
  int command_pct; /* 0 off, 1..100, or PCT_PREVIOUS */
} light_slot_t;

static SemaphoreHandle_t s_lock;
static TaskHandle_t s_worker;
static ha_lights_config_t s_config;
static light_slot_t s_slots[HA_LIGHTS_MAX];
static uint32_t s_revision = 1, s_generation = 1;
static bool s_usable;

static void lock(void) { xSemaphoreTake(s_lock, portMAX_DELAY); }
static void unlock(void) { xSemaphoreGive(s_lock); }

/* Caller holds the lock. */
static void reset_slots(void) {
  memset(s_slots, 0, sizeof(s_slots));
  for (int i = 0; i < s_config.count; i++) {
    platform_light_view_t *v = &s_slots[i].view;
    snprintf(v->name, sizeof(v->name), "%s",
             *s_config.lights[i].name ? s_config.lights[i].name
                                      : s_config.lights[i].entity_id + 6);
    v->available = true;
    v->dimmable = true;
  }
  s_generation++;
  s_revision++;
}

static void load_string(nvs_handle_t handle, const char *key, char *out,
                        size_t size) {
  size_t length = size;
  if (nvs_get_str(handle, key, out, &length) != ESP_OK)
    out[0] = 0;
}

static void load_config(ha_lights_config_t *out) {
  memset(out, 0, sizeof(*out));
  nvs_handle_t handle;
  if (nvs_open(NVS_NAMESPACE, NVS_READONLY, &handle) != ESP_OK)
    return;
  load_string(handle, "url", out->base_url, sizeof(out->base_url));
  load_string(handle, "token", out->token, sizeof(out->token));
  for (int i = 0; i < HA_LIGHTS_MAX; i++) {
    char key[4];
    ha_light_config_t *light = &out->lights[out->count];
    snprintf(key, sizeof(key), "e%d", i);
    load_string(handle, key, light->entity_id, sizeof(light->entity_id));
    snprintf(key, sizeof(key), "n%d", i);
    load_string(handle, key, light->name, sizeof(light->name));
    if (ha_lights_valid_entity(light->entity_id))
      out->count++;
    else
      memset(light, 0, sizeof(*light));
  }
  nvs_close(handle);
}

static esp_err_t write_config(const ha_lights_config_t *config) {
  nvs_handle_t handle;
  esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle);
  if (err != ESP_OK)
    return err;
  err = nvs_erase_all(handle);
  if (err == ESP_OK && config->count) {
    err = nvs_set_str(handle, "url", config->base_url);
    if (err == ESP_OK)
      err = nvs_set_str(handle, "token", config->token);
    for (int i = 0; err == ESP_OK && i < config->count; i++) {
      char key[4];
      snprintf(key, sizeof(key), "e%d", i);
      err = nvs_set_str(handle, key, config->lights[i].entity_id);
      if (err == ESP_OK && *config->lights[i].name) {
        snprintf(key, sizeof(key), "n%d", i);
        err = nvs_set_str(handle, key, config->lights[i].name);
      }
    }
  }
  if (err == ESP_OK)
    err = nvs_commit(handle);
  nvs_close(handle);
  return err;
}

void home_assistant_dial_init(void) {
  if (s_lock)
    return;
  s_lock = xSemaphoreCreateMutex();
  if (!s_lock) {
    ESP_LOGE(TAG, "No memory for Home Assistant lock");
    return;
  }
  ha_lights_config_t loaded;
  load_config(&loaded);
  lock();
  s_usable = ha_lights_config_usable(&loaded);
  if (s_usable)
    s_config = loaded;
  else
    memset(&s_config, 0, sizeof(s_config));
  reset_slots();
  unlock();
  memset(&loaded, 0, sizeof(loaded));
  ESP_LOGI(TAG, "%d light(s) configured", s_usable ? s_config.count : 0);
}

void home_assistant_dial_config(ha_lights_config_t *out, bool *has_token) {
  memset(out, 0, sizeof(*out));
  if (has_token)
    *has_token = false;
  if (!s_lock)
    return;
  lock();
  *out = s_config;
  if (has_token)
    *has_token = *s_config.token != 0;
  unlock();
  memset(out->token, 0, sizeof(out->token));
}

ha_dial_save_result_t home_assistant_dial_save(const ha_lights_config_t *candidate,
                                               char *error, size_t error_size) {
  snprintf(error, error_size, "%s", "");
  if (!s_lock || !candidate) {
    snprintf(error, error_size, "Home Assistant is not initialized.");
    return HA_DIAL_SAVE_INVALID;
  }
  ha_lights_config_t *next = heap_caps_calloc(1, sizeof(*next), MALLOC_CAP_8BIT);
  if (!next) {
    snprintf(error, error_size, "Not enough memory.");
    return HA_DIAL_SAVE_STORAGE_FAILED;
  }
  for (int i = 0; i < HA_LIGHTS_MAX && i < candidate->count; i++) {
    const ha_light_config_t *row = &candidate->lights[i];
    if (!*row->entity_id)
      continue;
    if (!ha_lights_valid_entity(row->entity_id)) {
      snprintf(error, error_size,
               "\"%.63s\" is not a light entity ID (for example light.sofa).",
               row->entity_id);
      free(next);
      return HA_DIAL_SAVE_INVALID;
    }
    ha_light_config_t *light = &next->lights[next->count++];
    snprintf(light->entity_id, sizeof(light->entity_id), "%s", row->entity_id);
    ha_lights_copy_name(light->name, sizeof(light->name), row->name);
  }
  bool clearing = !next->count && !*candidate->base_url;
  if (!clearing) {
    if (!ha_lights_normalize_url(candidate->base_url, next->base_url,
                                 sizeof(next->base_url))) {
      snprintf(error, error_size,
               "Enter the Home Assistant address, for example "
               "homeassistant.local or http://192.168.1.10:8123.");
      free(next);
      return HA_DIAL_SAVE_INVALID;
    }
    if (*candidate->token) {
      snprintf(next->token, sizeof(next->token), "%s", candidate->token);
    } else {
      lock();
      snprintf(next->token, sizeof(next->token), "%s", s_config.token);
      unlock();
    }
    if (!ha_lights_valid_token(next->token)) {
      snprintf(error, error_size,
               "Paste a long-lived access token from your Home Assistant "
               "profile (Security tab).");
      memset(next, 0, sizeof(*next));
      free(next);
      return HA_DIAL_SAVE_INVALID;
    }
    if (!next->count) {
      snprintf(error, error_size, "Add at least one light entity ID.");
      memset(next, 0, sizeof(*next));
      free(next);
      return HA_DIAL_SAVE_INVALID;
    }
  }
  esp_err_t err = write_config(next);
  ha_lights_config_t *verify = heap_caps_calloc(1, sizeof(*verify), MALLOC_CAP_8BIT);
  bool verified = err == ESP_OK && verify;
  if (verified) {
    load_config(verify);
    verified = !memcmp(verify, next, sizeof(*next));
  }
  if (verify) {
    memset(verify, 0, sizeof(*verify));
    free(verify);
  }
  if (!verified) {
    ESP_LOGE(TAG, "Saving configuration failed: %s", esp_err_to_name(err));
    snprintf(error, error_size, "Could not save to device storage. Try again.");
    memset(next, 0, sizeof(*next));
    free(next);
    return HA_DIAL_SAVE_STORAGE_FAILED;
  }
  lock();
  s_config = *next;
  s_usable = !clearing;
  reset_slots();
  unlock();
  memset(next, 0, sizeof(*next));
  free(next);
  ESP_LOGI(TAG, "Configuration saved: %d light(s)", s_usable ? s_config.count : 0);
  return clearing ? HA_DIAL_SAVE_CLEARED : HA_DIAL_SAVE_OK;
}

/* Returns the HTTP status, or -1 when Home Assistant could not be reached.
 * With `out`, a 200 body of at most max_bytes is returned in PSRAM. */
static int request(const char *url, const char *token, const char *body,
                   char **out, size_t max_bytes) {
  if (out)
    *out = NULL;
  esp_http_client_config_t config = {
      .url = url,
      .method = body ? HTTP_METHOD_POST : HTTP_METHOD_GET,
      .timeout_ms = HTTP_TIMEOUT_MS,
      .disable_auto_redirect = true,
#if CONFIG_MBEDTLS_CERTIFICATE_BUNDLE
      .crt_bundle_attach = esp_crt_bundle_attach,
#endif
  };
  esp_http_client_handle_t client = esp_http_client_init(&config);
  if (!client)
    return -1;
  char authorization[HA_LIGHTS_TOKEN_MAX + 8];
  snprintf(authorization, sizeof(authorization), "Bearer %s", token);
  esp_http_client_set_header(client, "Authorization", authorization);
  memset(authorization, 0, sizeof(authorization));
  esp_http_client_set_header(client, "Accept", "application/json");
  if (body)
    esp_http_client_set_header(client, "Content-Type", "application/json");
  int status = -1;
  size_t length = body ? strlen(body) : 0;
  if (esp_http_client_open(client, (int)length) != ESP_OK)
    goto done;
  if (body && esp_http_client_write(client, body, (int)length) != (int)length)
    goto done;
  int content_length = esp_http_client_fetch_headers(client);
  if (content_length < 0)
    goto done;
  status = esp_http_client_get_status_code(client);
  if (out && status == 200) {
    if ((size_t)content_length > max_bytes) {
      status = -1;
      goto done;
    }
    char *buffer = heap_caps_calloc(1, max_bytes + 1,
                                    MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!buffer) {
      status = -1;
      goto done;
    }
    size_t total = 0;
    for (;;) {
      int n = esp_http_client_read(client, buffer + total, (int)(max_bytes - total));
      if (n < 0) {
        free(buffer);
        status = -1;
        goto done;
      }
      if (n == 0)
        break;
      total += (size_t)n;
      if (total == max_bytes) {
        char excess;
        if (esp_http_client_read(client, &excess, 1) != 0) {
          free(buffer);
          status = -1;
          goto done;
        }
        break;
      }
    }
    buffer[total] = 0;
    *out = buffer;
  }
done:
  esp_http_client_close(client);
  esp_http_client_cleanup(client);
  return status;
}

static void describe_failure(int status, char *notice, size_t size) {
  if (status < 0)
    snprintf(notice, size, "Home Assistant unreachable");
  else if (status == 401 || status == 403)
    snprintf(notice, size, "Token rejected. Check web settings.");
  else if (status == 404)
    snprintf(notice, size, "Light not found in Home Assistant");
  else
    snprintf(notice, size, "Home Assistant error %d", status);
}

static void worker(void *arg) {
  (void)arg;
  char url[HA_LIGHTS_URL_MAX + 96], token[HA_LIGHTS_TOKEN_MAX],
      entity[HA_LIGHTS_ENTITY_MAX], notice[PLATFORM_LIGHTS_NOTICE_MAX];
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    for (;;) {
      int index = -1, pct = 0;
      bool command = false, dimmable = true;
      char base[HA_LIGHTS_URL_MAX];
      lock();
      /* Commands before refreshes: the user's latest intent goes first. */
      for (int pass = 0; pass < 2 && index < 0; pass++)
        for (int i = 0; i < s_config.count && index < 0; i++) {
          light_slot_t *slot = &s_slots[i];
          if (pass == 0 ? slot->command_pending : slot->refresh_pending) {
            index = i;
            command = pass == 0;
            pct = slot->command_pct;
            dimmable = slot->view.dimmable;
            slot->command_pending = command ? false : slot->command_pending;
            slot->refresh_pending = command ? slot->refresh_pending : false;
            slot->in_flight = true;
          }
        }
      uint32_t generation = s_generation;
      if (index >= 0) {
        snprintf(base, sizeof(base), "%s", s_config.base_url);
        snprintf(token, sizeof(token), "%s", s_config.token);
        snprintf(entity, sizeof(entity), "%s", s_config.lights[index].entity_id);
      }
      unlock();
      if (index < 0)
        break;
      notice[0] = 0;
      ha_light_state_t state = {0};
      bool ok = false;
      if (command) {
        if (!dimmable && pct > 0)
          pct = PCT_PREVIOUS; /* on/off-only lights reject a brightness */
        char *body = ha_lights_service_body(entity, pct != 0, pct);
        int status = -1;
        if (body && ha_lights_service_url(base, pct != 0, url, sizeof(url)))
          status = request(url, token, body, NULL, 0);
        cJSON_free(body);
        ok = status == 200;
        if (!ok)
          describe_failure(status, notice, sizeof(notice));
      } else {
        char *response = NULL;
        int status = -1;
        if (ha_lights_state_url(base, entity, url, sizeof(url)))
          status = request(url, token, NULL, &response, STATE_MAX_BYTES);
        ok = status == 200 && ha_lights_parse_state(response, entity, &state);
        if (status == 200 && !ok)
          snprintf(notice, sizeof(notice), "Unexpected Home Assistant reply");
        else if (!ok)
          describe_failure(status, notice, sizeof(notice));
        free(response);
      }
      memset(token, 0, sizeof(token));
      lock();
      if (generation == s_generation && index < s_config.count) {
        light_slot_t *slot = &s_slots[index];
        platform_light_view_t *v = &slot->view;
        slot->in_flight = false;
        snprintf(v->notice, sizeof(v->notice), "%s", notice);
        if (command && ok) {
          v->known = true;
          v->available = true;
          v->on = pct != 0;
          if (pct > 0)
            v->brightness_pct = pct;
          else if (pct == PCT_PREVIOUS)
            slot->refresh_pending = true; /* learn the restored brightness */
        } else if (command) {
          slot->refresh_pending = true; /* resynchronize the optimistic view */
        } else if (ok && !slot->command_pending) {
          /* A newer command wins over a state read taken before it. */
          v->known = true;
          v->available = state.power != HA_LIGHT_UNAVAILABLE;
          v->on = state.power == HA_LIGHT_ON;
          v->dimmable = state.dimmable;
          v->brightness_pct = v->on ? state.brightness_pct : v->brightness_pct;
          if (!*s_config.lights[index].name && *state.friendly_name)
            snprintf(v->name, sizeof(v->name), "%s", state.friendly_name);
          if (!v->available)
            snprintf(v->notice, sizeof(v->notice), "Unavailable in Home Assistant");
        }
        s_revision++;
      }
      unlock();
    }
  }
}

/* Caller holds the lock. Starts the worker on first use so an unconfigured
 * Dial spends no memory on it. */
static void wake_worker(void) {
  if (!s_worker) {
    if (xTaskCreatePinnedToCoreWithCaps(worker, "ha_lights", WORKER_STACK, NULL,
                                        3, &s_worker, tskNO_AFFINITY,
                                        MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT) != pdPASS &&
        xTaskCreate(worker, "ha_lights", WORKER_STACK, NULL, 3, &s_worker) != pdPASS) {
      s_worker = NULL;
      for (int i = 0; i < s_config.count; i++) {
        s_slots[i].command_pending = s_slots[i].refresh_pending = false;
        snprintf(s_slots[i].view.notice, sizeof(s_slots[i].view.notice),
                 "Not enough memory for lights");
      }
      s_revision++;
      return;
    }
  }
  xTaskNotifyGive(s_worker);
}

static bool valid_index(int index) {
  return s_lock && s_usable && index >= 0 && index < s_config.count;
}

int platform_lights_count(void) {
  if (!s_lock)
    return 0;
  lock();
  int count = s_usable ? s_config.count : 0;
  unlock();
  return count;
}

bool platform_lights_view(int index, platform_light_view_t *out) {
  if (!s_lock || !out)
    return false;
  lock();
  bool ok = valid_index(index);
  if (ok) {
    const light_slot_t *slot = &s_slots[index];
    *out = slot->view;
    out->busy = slot->command_pending || slot->refresh_pending || slot->in_flight;
  }
  unlock();
  return ok;
}

uint32_t platform_lights_revision(void) {
  if (!s_lock)
    return 0;
  lock();
  uint32_t revision = s_revision;
  unlock();
  return revision;
}

void platform_lights_refresh(int index) {
  if (!s_lock)
    return;
  lock();
  if (valid_index(index)) {
    s_slots[index].refresh_pending = true;
    s_revision++;
    wake_worker();
  }
  unlock();
}

static void queue_command(int index, int pct) {
  light_slot_t *slot = &s_slots[index];
  slot->command_pending = true;
  slot->command_pct = pct;
  /* Optimistic: the arc and label follow the knob immediately. */
  slot->view.on = pct != 0;
  if (pct > 0)
    slot->view.brightness_pct = pct;
  slot->view.notice[0] = 0;
  s_revision++;
  wake_worker();
}

void platform_lights_set_brightness(int index, int percent) {
  if (!s_lock)
    return;
  if (percent < 0)
    percent = 0;
  if (percent > 100)
    percent = 100;
  lock();
  if (valid_index(index))
    queue_command(index, percent);
  unlock();
}

void platform_lights_toggle(int index) {
  if (!s_lock)
    return;
  lock();
  if (valid_index(index))
    queue_command(index, s_slots[index].view.on ? 0 : PCT_PREVIOUS);
  unlock();
}
