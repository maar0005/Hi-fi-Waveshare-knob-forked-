#include "cJSON.h"
#include "home_assistant_lights.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static void url(const char *input, const char *expected) {
  char out[HA_LIGHTS_URL_MAX];
  bool ok = ha_lights_normalize_url(input, out, sizeof(out));
  if (!expected) {
    assert(!ok && !out[0]);
    return;
  }
  assert(ok);
  assert(!strcmp(out, expected));
}

int main(void) {
  url("homeassistant.local", "http://homeassistant.local:8123");
  url(" 192.168.1.10 ", "http://192.168.1.10:8123");
  url("http://ha.lan", "http://ha.lan:8123");
  url("http://ha.lan:80/", "http://ha.lan:80");
  url("https://example.ui.nabu.casa", "https://example.ui.nabu.casa");
  url("https://ha.example.com:8443/", "https://ha.example.com:8443");
  url("[fd00::1]:8123", "http://[fd00::1]:8123");
  url("[fd00::1]", "http://[fd00::1]:8123");
  url("", NULL);
  url("ftp://ha.lan", NULL);
  url("http://ha.lan/lovelace", NULL);
  url("http://user@ha.lan", NULL);
  url("ha.lan:0", NULL);
  url("ha.lan:65536", NULL);
  url("ha.lan:80:81", NULL);
  url("ha lan", NULL);
  url("http://", NULL);
  char tiny[12];
  assert(!ha_lights_normalize_url("homeassistant.local", tiny, sizeof(tiny)));

  assert(ha_lights_valid_entity("light.living_room"));
  assert(ha_lights_valid_entity("light.lamp2"));
  assert(!ha_lights_valid_entity("light."));
  assert(!ha_lights_valid_entity("switch.lamp"));
  assert(!ha_lights_valid_entity("light.Living"));
  assert(!ha_lights_valid_entity("light.a/../b"));
  assert(!ha_lights_valid_entity("light.a b"));
  assert(!ha_lights_valid_entity(NULL));

  const char *token = "eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJhYmMifQ.sig-nature_1";
  assert(ha_lights_valid_token(token));
  assert(!ha_lights_valid_token("short"));
  assert(!ha_lights_valid_token("eyJhbGciOiJIUzI1NiJ9 with space"));
  assert(!ha_lights_valid_token("eyJhbGciOiJIUzI1NiJ9\r\nX-Injected: 1"));

  char name[HA_LIGHTS_NAME_MAX];
  ha_lights_copy_name(name, sizeof(name), "  Sofa\tlamp  ");
  assert(!strcmp(name, "Sofalamp"));
  ha_lights_copy_name(name, 6, "Stue \xc3\xa6\xc3\xb8");
  assert(!strcmp(name, "Stue")); /* never ends inside a UTF-8 sequence */
  ha_lights_copy_name(name, sizeof(name), NULL);
  assert(!name[0]);

  ha_lights_config_t config = {0};
  assert(!ha_lights_config_usable(&config));
  snprintf(config.base_url, sizeof(config.base_url), "http://ha.lan:8123");
  snprintf(config.token, sizeof(config.token), "%s", token);
  config.count = 1;
  snprintf(config.lights[0].entity_id, sizeof(config.lights[0].entity_id),
           "light.sofa");
  assert(ha_lights_config_usable(&config));
  snprintf(config.base_url, sizeof(config.base_url), "ha.lan");
  assert(!ha_lights_config_usable(&config)); /* must be stored normalized */
  snprintf(config.base_url, sizeof(config.base_url), "http://ha.lan:8123");
  config.count = HA_LIGHTS_MAX + 1;
  assert(!ha_lights_config_usable(&config));
  config.count = 2;
  assert(!ha_lights_config_usable(&config)); /* second entity empty */

  char out[256];
  assert(ha_lights_state_url("http://ha.lan:8123", "light.sofa", out, sizeof(out)));
  assert(!strcmp(out, "http://ha.lan:8123/api/states/light.sofa"));
  assert(!ha_lights_state_url("http://ha.lan:8123", "light.a/b", out, sizeof(out)));
  assert(ha_lights_service_url("http://ha.lan:8123", true, out, sizeof(out)));
  assert(!strcmp(out, "http://ha.lan:8123/api/services/light/turn_on"));
  assert(ha_lights_service_url("http://ha.lan:8123", false, out, sizeof(out)));
  assert(!strcmp(out, "http://ha.lan:8123/api/services/light/turn_off"));

  char *body = ha_lights_service_body("light.sofa", true, 40);
  assert(body && !strcmp(body, "{\"entity_id\":\"light.sofa\",\"brightness_pct\":40}"));
  cJSON_free(body);
  body = ha_lights_service_body("light.sofa", true, -1);
  assert(body && !strcmp(body, "{\"entity_id\":\"light.sofa\"}"));
  cJSON_free(body);
  body = ha_lights_service_body("light.sofa", false, 40);
  assert(body && !strcmp(body, "{\"entity_id\":\"light.sofa\"}"));
  cJSON_free(body);
  assert(!ha_lights_service_body("light.\"x", true, 10));
  assert(!ha_lights_service_body("light.sofa", true, 101));

  ha_light_state_t state;
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.sofa\",\"state\":\"on\",\"attributes\":{"
      "\"brightness\":128,\"friendly_name\":\"Sofa lamp\","
      "\"supported_color_modes\":[\"brightness\"]}}",
      "light.sofa", &state));
  assert(state.power == HA_LIGHT_ON && state.brightness_pct == 50 &&
         state.dimmable && !strcmp(state.friendly_name, "Sofa lamp"));
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.sofa\",\"state\":\"on\",\"attributes\":{"
      "\"brightness\":1}}",
      "light.sofa", &state));
  assert(state.brightness_pct == 1); /* on is never shown as 0% */
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.plug\",\"state\":\"on\",\"attributes\":{"
      "\"supported_color_modes\":[\"onoff\"]}}",
      "light.plug", &state));
  assert(state.power == HA_LIGHT_ON && state.brightness_pct == 100 &&
         !state.dimmable);
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.sofa\",\"state\":\"off\",\"attributes\":{}}",
      "light.sofa", &state));
  assert(state.power == HA_LIGHT_OFF && state.brightness_pct == 0);
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.sofa\",\"state\":\"unavailable\"}", "light.sofa",
      &state));
  assert(state.power == HA_LIGHT_UNAVAILABLE);
  assert(ha_lights_parse_state(
      "{\"entity_id\":\"light.sofa\",\"state\":\"on\",\"attributes\":{"
      "\"brightness\":999}}",
      "light.sofa", &state));
  assert(state.brightness_pct == 100); /* out-of-range attribute ignored */
  assert(!ha_lights_parse_state(
      "{\"entity_id\":\"light.other\",\"state\":\"on\"}", "light.sofa", &state));
  assert(!ha_lights_parse_state("{\"message\":\"Entity not found.\"}",
                                "light.sofa", &state));
  assert(!ha_lights_parse_state("401: Unauthorized", "light.sofa", &state));

  assert(ha_lights_step(false, 70, 1) == 5);   /* off starts from 0 */
  assert(ha_lights_step(true, 50, 2) == 60);
  assert(ha_lights_step(true, 10, -3) == 0);   /* reaching 0 means off */
  assert(ha_lights_step(true, 98, 5) == 100);
  assert(ha_lights_step(false, 0, -4) == 0);
  assert(ha_lights_step(true, 50, 2000000000) == 100);
  puts("home assistant lights: ok");
  return 0;
}
