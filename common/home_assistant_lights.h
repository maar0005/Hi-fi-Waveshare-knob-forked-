// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
/* Home Assistant light control: pure validation, request and response helpers.
 * No transport, storage or UI; the target runtime owns those. */
#pragma once
#include <stdbool.h>
#include <stddef.h>

#define HA_LIGHTS_MAX 4
#define HA_LIGHTS_URL_MAX 128
/* Long-lived access tokens are ~183-character JWTs; leave headroom. */
#define HA_LIGHTS_TOKEN_MAX 320
#define HA_LIGHTS_ENTITY_MAX 64
#define HA_LIGHTS_NAME_MAX 33
#define HA_LIGHTS_STEP_PERCENT 5

typedef struct {
  char entity_id[HA_LIGHTS_ENTITY_MAX];
  char name[HA_LIGHTS_NAME_MAX];
} ha_light_config_t;

typedef struct {
  char base_url[HA_LIGHTS_URL_MAX];
  char token[HA_LIGHTS_TOKEN_MAX];
  ha_light_config_t lights[HA_LIGHTS_MAX];
  int count;
} ha_lights_config_t;

typedef enum {
  HA_LIGHT_UNKNOWN = 0,
  HA_LIGHT_OFF,
  HA_LIGHT_ON,
  HA_LIGHT_UNAVAILABLE,
} ha_light_power_t;

typedef struct {
  ha_light_power_t power;
  int brightness_pct; /* 0-100; meaningful while on */
  bool dimmable;
  char friendly_name[HA_LIGHTS_NAME_MAX];
} ha_light_state_t;

/* Accepts host, host:port or http(s)://host[:port][/]. Plain HTTP without a
 * port gets Home Assistant's default 8123; HTTPS keeps its default port. */
bool ha_lights_normalize_url(const char *input, char *out, size_t capacity);
/* light.<object_id> with Home Assistant's lowercase slug characters. */
bool ha_lights_valid_entity(const char *entity_id);
/* JWT/base64url characters only, so the value is safe in a header. */
bool ha_lights_valid_token(const char *token);
/* Copies a display name, trimming whitespace and dropping control bytes. */
void ha_lights_copy_name(char *out, size_t capacity, const char *input);
/* Complete, usable configuration: URL, token and 1..HA_LIGHTS_MAX lights. */
bool ha_lights_config_usable(const ha_lights_config_t *config);

bool ha_lights_state_url(const char *base_url, const char *entity_id,
                         char *out, size_t capacity);
bool ha_lights_service_url(const char *base_url, bool turn_on, char *out,
                           size_t capacity);
/* brightness_pct < 0 turns on at the light's previous brightness. Free the
 * result with cJSON_free. */
char *ha_lights_service_body(const char *entity_id, bool turn_on,
                             int brightness_pct);
/* Parses GET /api/states/<entity_id>; rejects a response for another entity. */
bool ha_lights_parse_state(const char *json, const char *entity_id,
                           ha_light_state_t *out);
/* Knob detents to a new brightness. Off counts as 0; a result of 0 is off. */
int ha_lights_step(bool on, int brightness_pct, int detents);
