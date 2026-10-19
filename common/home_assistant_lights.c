// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
#include "home_assistant_lights.h"
#include "cJSON.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static bool host_char(char c) {
  return isalnum((unsigned char)c) || c == '.' || c == '-' || c == '_';
}

bool ha_lights_normalize_url(const char *input, char *out, size_t capacity) {
  if (!input || !out || !capacity)
    return false;
  out[0] = 0;
  while (isspace((unsigned char)*input))
    input++;
  size_t length = strlen(input);
  while (length && isspace((unsigned char)input[length - 1]))
    length--;
  if (!length || length >= HA_LIGHTS_URL_MAX)
    return false;
  char value[HA_LIGHTS_URL_MAX];
  memcpy(value, input, length);
  value[length] = 0;
  bool https = !strncmp(value, "https://", 8);
  const char *authority = value;
  if (https)
    authority += 8;
  else if (!strncmp(value, "http://", 7))
    authority += 7;
  else if (strstr(value, "://"))
    return false;
  char host[HA_LIGHTS_URL_MAX];
  snprintf(host, sizeof(host), "%s", authority);
  char *slash = strchr(host, '/');
  if (slash) {
    if (slash[1]) /* Home Assistant's API lives at the root. */
      return false;
    *slash = 0;
  }
  if (!*host || host[0] == ':')
    return false;
  const char *port = NULL;
  if (host[0] == '[') {
    char *close = strchr(host, ']');
    if (!close || close == host + 1)
      return false;
    for (const char *c = host + 1; c < close; c++)
      if (!isxdigit((unsigned char)*c) && *c != ':' && *c != '.')
        return false;
    if (close[1] == ':')
      port = close + 2;
    else if (close[1])
      return false;
  } else {
    char *colon = strchr(host, ':');
    if (colon) {
      if (strchr(colon + 1, ':'))
        return false;
      port = colon + 1;
    }
    for (const char *c = host; *c && *c != ':'; c++)
      if (!host_char(*c))
        return false;
  }
  if (port) {
    if (!*port || strlen(port) > 5)
      return false;
    for (const char *c = port; *c; c++)
      if (!isdigit((unsigned char)*c))
        return false;
    long number = strtol(port, NULL, 10);
    if (number < 1 || number > 65535)
      return false;
  }
  int n = snprintf(out, capacity, "%s://%s%s", https ? "https" : "http", host,
                   port || https ? "" : ":8123");
  if (n <= 0 || (size_t)n >= capacity) {
    out[0] = 0;
    return false;
  }
  return true;
}

bool ha_lights_valid_entity(const char *entity_id) {
  if (!entity_id || strncmp(entity_id, "light.", 6))
    return false;
  size_t length = strlen(entity_id);
  if (length == 6 || length >= HA_LIGHTS_ENTITY_MAX)
    return false;
  for (const char *c = entity_id + 6; *c; c++)
    if (!islower((unsigned char)*c) && !isdigit((unsigned char)*c) &&
        *c != '_')
      return false;
  return true;
}

bool ha_lights_valid_token(const char *token) {
  if (!token)
    return false;
  size_t length = strlen(token);
  if (length < 20 || length >= HA_LIGHTS_TOKEN_MAX)
    return false;
  for (const char *c = token; *c; c++)
    if (!isalnum((unsigned char)*c) && *c != '.' && *c != '-' && *c != '_')
      return false;
  return true;
}

void ha_lights_copy_name(char *out, size_t capacity, const char *input) {
  if (!out || !capacity)
    return;
  out[0] = 0;
  if (!input)
    return;
  while (isspace((unsigned char)*input))
    input++;
  size_t n = 0;
  for (; *input && n + 1 < capacity; input++)
    if ((unsigned char)*input >= 0x20 && *input != 0x7f)
      out[n++] = *input;
  /* Never end on a partial UTF-8 sequence. */
  if (*input) {
    while (n && ((unsigned char)out[n - 1] & 0xc0) == 0x80)
      n--;
    if (n && ((unsigned char)out[n - 1] & 0xc0) == 0xc0)
      n--;
  }
  while (n && isspace((unsigned char)out[n - 1]))
    n--;
  out[n] = 0;
}

bool ha_lights_config_usable(const ha_lights_config_t *config) {
  char normalized[HA_LIGHTS_URL_MAX];
  if (!config || config->count < 1 || config->count > HA_LIGHTS_MAX ||
      !ha_lights_normalize_url(config->base_url, normalized,
                               sizeof(normalized)) ||
      strcmp(normalized, config->base_url) ||
      !ha_lights_valid_token(config->token))
    return false;
  for (int i = 0; i < config->count; i++)
    if (!ha_lights_valid_entity(config->lights[i].entity_id))
      return false;
  return true;
}

bool ha_lights_state_url(const char *base_url, const char *entity_id,
                         char *out, size_t capacity) {
  if (!base_url || !*base_url || !ha_lights_valid_entity(entity_id))
    return false;
  int n = snprintf(out, capacity, "%s/api/states/%s", base_url, entity_id);
  return n > 0 && (size_t)n < capacity;
}

bool ha_lights_service_url(const char *base_url, bool turn_on, char *out,
                           size_t capacity) {
  if (!base_url || !*base_url)
    return false;
  int n = snprintf(out, capacity, "%s/api/services/light/%s", base_url,
                   turn_on ? "turn_on" : "turn_off");
  return n > 0 && (size_t)n < capacity;
}

char *ha_lights_service_body(const char *entity_id, bool turn_on,
                             int brightness_pct) {
  if (!ha_lights_valid_entity(entity_id) || brightness_pct > 100)
    return NULL;
  cJSON *o = cJSON_CreateObject();
  if (!o)
    return NULL;
  cJSON_AddStringToObject(o, "entity_id", entity_id);
  if (turn_on && brightness_pct >= 0)
    cJSON_AddNumberToObject(o, "brightness_pct", brightness_pct);
  char *body = cJSON_PrintUnformatted(o);
  cJSON_Delete(o);
  return body;
}

bool ha_lights_parse_state(const char *json, const char *entity_id,
                           ha_light_state_t *out) {
  if (!json || !out)
    return false;
  memset(out, 0, sizeof(*out));
  cJSON *root = cJSON_Parse(json);
  if (!root)
    return false;
  bool ok = false;
  const cJSON *id = cJSON_GetObjectItemCaseSensitive(root, "entity_id");
  const cJSON *state = cJSON_GetObjectItemCaseSensitive(root, "state");
  if (!cJSON_IsString(id) || !entity_id || strcmp(id->valuestring, entity_id) ||
      !cJSON_IsString(state))
    goto done;
  const cJSON *attributes = cJSON_GetObjectItemCaseSensitive(root, "attributes");
  const cJSON *name = cJSON_GetObjectItemCaseSensitive(attributes, "friendly_name");
  if (cJSON_IsString(name))
    ha_lights_copy_name(out->friendly_name, sizeof(out->friendly_name),
                        name->valuestring);
  /* Dimmable unless Home Assistant reports on/off as the only colour mode. */
  out->dimmable = true;
  const cJSON *modes =
      cJSON_GetObjectItemCaseSensitive(attributes, "supported_color_modes");
  if (cJSON_IsArray(modes) && cJSON_GetArraySize(modes) > 0) {
    out->dimmable = false;
    const cJSON *mode;
    cJSON_ArrayForEach(mode, modes) {
      if (!cJSON_IsString(mode) || strcmp(mode->valuestring, "onoff"))
        out->dimmable = true;
    }
  }
  if (!strcmp(state->valuestring, "on")) {
    out->power = HA_LIGHT_ON;
    out->brightness_pct = 100;
    const cJSON *brightness =
        cJSON_GetObjectItemCaseSensitive(attributes, "brightness");
    if (cJSON_IsNumber(brightness) && brightness->valuedouble >= 0 &&
        brightness->valuedouble <= 255) {
      out->brightness_pct = (int)((brightness->valuedouble * 100.0) / 255.0 + 0.5);
      if (out->brightness_pct < 1)
        out->brightness_pct = 1;
    }
  } else if (!strcmp(state->valuestring, "off")) {
    out->power = HA_LIGHT_OFF;
  } else if (!strcmp(state->valuestring, "unavailable")) {
    out->power = HA_LIGHT_UNAVAILABLE;
  } else {
    out->power = HA_LIGHT_UNKNOWN;
  }
  ok = true;
done:
  cJSON_Delete(root);
  return ok;
}

int ha_lights_step(bool on, int brightness_pct, int detents) {
  int base = on ? brightness_pct : 0;
  if (base < 0)
    base = 0;
  if (base > 100)
    base = 100;
  long next = (long)base + (long)detents * HA_LIGHTS_STEP_PERCENT;
  if (next < 0)
    next = 0;
  if (next > 100)
    next = 100;
  return (int)next;
}
