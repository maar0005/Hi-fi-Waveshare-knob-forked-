#include "controller_library.h"
#include "cJSON.h"
#include <ctype.h>
#include <stdio.h>
#include <string.h>
static const char *str(const cJSON *o, const char *k) {
  const cJSON *v = cJSON_GetObjectItemCaseSensitive(o, k);
  return cJSON_IsString(v) ? v->valuestring : "";
}
static bool copy(char *to, size_t n, const char *from) {
  if (strlen(from) >= n)
    return false;
  memcpy(to, from, strlen(from) + 1);
  return true;
}
static void copy_label(char *to, size_t n, const char *from) {
  size_t length = strlen(from);
  if (length >= n) {
    length = n - 1;
    while (length && (((unsigned char)from[length] & 0xc0) == 0x80))
      length--;
  }
  memcpy(to, from, length);
  to[length] = 0;
}
bool controller_library_image_path(const char *path) {
  const char *prefix = "/api/collections/image?ref=";
  if (strncmp(path, prefix, strlen(prefix)))
    return false;
  const char *p = path + strlen(prefix);
  if (!*p || strlen(p) > 512)
    return false;
  for (; *p; p++)
    if (!isalnum((unsigned char)*p) && !strchr("%._~-", *p))
      return false;
  return true;
}
bool controller_library_parse(const char *json, const char *zone, bool mutation,
                              controller_library_page_t *out) {
  memset(out, 0, sizeof(*out));
  out->next_offset = -1;
  snprintf(out->notice, sizeof(out->notice),
           "Library unavailable. Tap to retry.");
  cJSON *root = cJSON_Parse(json);
  bool ok = false;
  if (!root)
    return false;
  const char *scope =
      str(cJSON_GetObjectItemCaseSensitive(root, "scope"), "zone_id");
  if (strcmp(scope, zone)) {
    snprintf(out->notice, sizeof(out->notice),
             "Zone changed. Refresh Library.");
    goto done;
  }
  const char *outcome = str(root, "outcome");
  if (strcmp(outcome, "ok") && strcmp(outcome, "accepted")) {
    const char *detail =
        str(cJSON_GetObjectItemCaseSensitive(root, "refusal"), "detail");
    if (*detail)
      snprintf(out->notice, sizeof(out->notice), "%s", detail);
    goto done;
  }
  if (mutation) {
    out->accepted = true;
    snprintf(out->notice, sizeof(out->notice),
             "Accepted. Checking playback...");
    ok = true;
    goto done;
  }
  cJSON *data = cJSON_GetObjectItemCaseSensitive(root, "data");
  cJSON *items = cJSON_GetObjectItemCaseSensitive(data, "items");
  if (!cJSON_IsArray(items) ||
      cJSON_GetArraySize(items) > CONTROLLER_LIBRARY_PAGE_SIZE)
    goto done;
  cJSON *item;
  cJSON_ArrayForEach(item, items) {
    controller_library_item_t *r = &out->items[out->count];
    if (!*str(item, "title") ||
        !copy(r->location, sizeof(r->location), str(item, "location")) ||
        !copy(r->ref, sizeof(r->ref), str(item, "ref")))
      goto done;
    copy_label(r->title, sizeof(r->title), str(item, "title"));
    copy_label(r->subtitle, sizeof(r->subtitle), str(item, "subtitle"));
    const char *image = str(item, "image");
    if (controller_library_image_path(image))
      copy(r->image, sizeof(r->image), image);
    out->count++;
  }
  cJSON *next = cJSON_GetObjectItemCaseSensitive(data, "next_offset");
  if (cJSON_IsNumber(next) && next->valuedouble >= 0 &&
      next->valuedouble <= 1000000 && next->valuedouble == next->valueint)
    out->next_offset = next->valueint;
  out->notice[0] = 0;
  ok = true;
done:
  cJSON_Delete(root);
  if (!ok) {
    out->count = 0;
    out->next_offset = -1;
  }
  return ok;
}
char *controller_library_body(const char *zone, const char *location,
                              int offset, const char *ref, const char *action) {
  if (!zone || !*zone || !location || strlen(location) > 512 || offset < 0 ||
      offset > 1000000)
    return NULL;
  bool mutation = ref && *ref;
  if (mutation && (strlen(ref) > 512 || !action ||
                   (strcmp(action, "play") && strcmp(action, "queue"))))
    return NULL;
  cJSON *o = cJSON_CreateObject();
  if (!o)
    return NULL;
  cJSON_AddStringToObject(o, "zone_id", zone);
  if (mutation) {
    cJSON_AddStringToObject(o, "ref", ref);
    cJSON_AddStringToObject(o, "action", action);
  } else {
    cJSON_AddStringToObject(o, "action", "browse");
    cJSON_AddNumberToObject(o, "limit", CONTROLLER_LIBRARY_PAGE_SIZE);
    cJSON_AddNumberToObject(o, "offset", offset);
    if (*location)
      cJSON_AddStringToObject(o, "location", location);
  }
  char *body = cJSON_PrintUnformatted(o);
  cJSON_Delete(o);
  return body;
}
