/* HALO renderer and asynchronous transport; browse schema is target-neutral. */
#include "halo_navigation.h"
#include "bridge_client.h"
#include "cJSON.h"
#include "controller_config.h"
#include "controller_library.h"
#include "font_manager.h"
#include "lvgl.h"
#include "platform_display_halo.h"
#include "ui.h"
#include "wifi_manager.h"
#include <esp_heap_caps.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { ARTWORK, NOW_PLAYING, LIBRARY, ZONES, SETTINGS, SCREEN_COUNT };
enum { BROWSE, PLAY, QUEUE, IMAGE };
#define HISTORY_MAX 8
#define COVER_SIZE 144
#define COVER_BYTES (COVER_SIZE * COVER_SIZE * 2)
typedef struct {
  unsigned generation;
  int kind, offset;
  char endpoint[128], zone[64], location[513], ref[513], image[600];
} request_t;
typedef struct {
  request_t request;
  controller_library_page_t page;
  char *pixels;
  bool ok;
} result_t;
static QueueHandle_t requests, results;
static bool busy, mutation_locked;
static int busy_kind;
static unsigned generation = 1;
static int screen = NOW_PLAYING, selected_index, offset, brightness = 100;
static controller_library_page_t *page;
static char endpoint[128], zone[64], location[513];
static struct {
  char location[513];
  int offset, selected_index;
} history[HISTORY_MAX];
static int depth, setting_index;
static lv_obj_t *overlay, *heading, *cover, *title, *subtitle, *counter, *back,
    *primary, *secondary;
static lv_image_dsc_t cover_dsc;
static char *cover_pixels;
static bool chooser;
static int64_t mutation_sent_ms;
static void render(void);
static bool submit(int kind, const char *ref, const char *image);
static void reset_library(void) {
  generation++;
  depth = 0;
  selected_index = offset = 0;
  location[0] = 0;
  chooser = false;
  if (page) {
    memset(page, 0, sizeof(*page));
    page->next_offset = -1;
  }
}
static bool request_current(const request_t *r) {
  char base[128], selected[64];
  return bridge_client_get_request_base(base, sizeof(base)) &&
         bridge_client_get_current_zone_id(selected, sizeof(selected)) &&
         !strcmp(base, r->endpoint) && !strcmp(selected, r->zone);
}
static void worker(void *arg) {
  (void)arg;
  request_t r;
  for (;;) {
    if (xQueueReceive(requests, &r, portMAX_DELAY) != pdTRUE)
      continue;
    result_t *result = heap_caps_calloc(1, sizeof(*result),
                                        MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!result) { /* Return a small failure sentinel rather than leave the UI
                      busy forever. */
      result = NULL;
      xQueueSend(results, &result, portMAX_DELAY);
      continue;
    }
    result->request = r;
    snprintf(result->page.notice, sizeof(result->page.notice),
             "Connection changed. Tap to refresh.");
    if (request_current(&r)) {
      char url[850], *response = NULL;
      size_t len = 0;
      int rc = -1;
      if (r.kind == IMAGE) {
        snprintf(url, sizeof(url), "%s%s&width=%d&height=%d&format=rgb565",
                 r.endpoint, r.image, COVER_SIZE, COVER_SIZE);
        rc = platform_http_get_bounded(url, COVER_BYTES, &response, &len);
        if (rc == 0 && len == COVER_BYTES && request_current(&r)) {
          result->pixels = response;
          response = NULL;
          result->ok = true;
        }
      } else {
        bool mutation = r.kind == PLAY || r.kind == QUEUE;
        char *body = controller_library_body(
            r.zone, r.location, r.offset, mutation ? r.ref : NULL,
            r.kind == QUEUE ? "queue" : "play");
        snprintf(url, sizeof(url), "%s/api/%s", r.endpoint,
                 mutation ? "play_ref" : "collections");
        controller_connection_t connection;
        bridge_client_connection_snapshot(&connection);
        if (body && controller_connection_ready(&connection) &&
            request_current(&r))
          rc = platform_http_post_json(url, body, &response, &len);
        cJSON_free(body);
        if (rc == 0 && response && len <= PLATFORM_HTTP_JSON_MAX_BYTES &&
            request_current(&r))
          result->ok = controller_library_parse(response, r.zone, mutation,
                                                &result->page);
        else
          snprintf(result->page.notice, sizeof(result->page.notice), "%s",
                   mutation ? "Playback uncertain. Check now playing."
                            : "Library unavailable. Tap to retry.");
      }
      if (r.kind == BROWSE && result->ok && result->page.next_offset >= 0 &&
          (result->page.next_offset <= r.offset || result->page.count == 0)) {
        result->ok = false;
        result->page.count = 0;
        snprintf(result->page.notice, sizeof(result->page.notice),
                 "Invalid library page. Tap to refresh.");
      }
      platform_http_free(response);
    }
    xQueueSend(results, &result, portMAX_DELAY);
  }
}
static void clear_cover(void) {
  if (cover)
    lv_obj_add_flag(cover, LV_OBJ_FLAG_HIDDEN);
  if (cover)
    lv_image_set_src(cover, NULL);
  platform_http_free(cover_pixels);
  cover_pixels = NULL;
  memset(&cover_dsc, 0, sizeof(cover_dsc));
}
static void label(lv_obj_t **out, lv_obj_t *parent, int y, int width,
                  const lv_font_t *font) {
  *out = lv_label_create(parent);
  lv_obj_set_width(*out, width);
  lv_obj_align(*out, LV_ALIGN_TOP_MID, 0, y);
  lv_obj_set_style_text_font(*out, font, 0);
  lv_obj_set_style_text_color(*out, lv_color_hex(0xeeeeee), 0);
  lv_obj_set_style_text_align(*out, LV_TEXT_ALIGN_CENTER, 0);
  lv_label_set_long_mode(*out, LV_LABEL_LONG_DOT);
}
static void button_text(lv_obj_t *button, const char *text) {
  lv_obj_t *child = lv_obj_get_child(button, 0);
  lv_label_set_text(child, text);
  lv_obj_center(child);
}
static void change_screen(int next) {
  screen = next;
  chooser = false;
  generation++;
  ui_hide_zone_picker();
  ui_set_controls_visible(screen == NOW_PLAYING);
  if (overlay)
    lv_obj_add_flag(overlay, LV_OBJ_FLAG_HIDDEN);
  clear_cover();
  if (screen == LIBRARY || screen == SETTINGS) {
    render();
    if (screen == LIBRARY && !busy)
      submit(BROWSE, NULL, NULL);
  }
  if (screen == ZONES) {
    bridge_zone_t zones[BRIDGE_CLIENT_MAX_ZONES];
    const char *names[BRIDGE_CLIENT_MAX_ZONES], *ids[BRIDGE_CLIENT_MAX_ZONES];
    int n = bridge_client_get_zones(zones, BRIDGE_CLIENT_MAX_ZONES),
        selected = 0;
    char current[64];
    bridge_client_get_current_zone_id(current, sizeof(current));
    for (int i = 0; i < n; i++) {
      names[i] = zones[i].name;
      ids[i] = zones[i].id;
      if (!strcmp(ids[i], current))
        selected = i;
    }
    if (n > 0)
      ui_show_zone_picker(names, ids, n, selected);
    else {
      screen = SETTINGS;
      render();
      lv_label_set_text(subtitle, "No zones. Check connection.");
    }
  }
}
static void selected_cover(void) {
  clear_cover();
  if (screen == LIBRARY && !chooser && page && selected_index < page->count &&
      *page->items[selected_index].image && !busy)
    submit(IMAGE, NULL, page->items[selected_index].image);
}
static void move_item(int delta) {
  if ((busy && busy_kind != IMAGE) || chooser || !page || !page->count)
    return;
  int next = selected_index + (delta > 0 ? 1 : -1);
  if (next >= page->count) {
    if (page->next_offset >= 0) {
      offset = page->next_offset;
      selected_index = 0;
      submit(BROWSE, NULL, NULL);
    }
    return;
  }
  if (next < 0) {
    if (offset > 0) {
      offset = offset > CONTROLLER_LIBRARY_PAGE_SIZE
                   ? offset - CONTROLLER_LIBRARY_PAGE_SIZE
                   : 0;
      selected_index = CONTROLLER_LIBRARY_PAGE_SIZE - 1;
      submit(BROWSE, NULL, NULL);
    }
    return;
  }
  selected_index = next;
  generation++;
  render();
  selected_cover();
}
static void back_action(void) {
  if (busy)
    return;
  if (chooser) {
    chooser = false;
    render();
    selected_cover();
    return;
  }
  if (depth) {
    depth--;
    snprintf(location, sizeof(location), "%s", history[depth].location);
    offset = history[depth].offset;
    selected_index = history[depth].selected_index;
    submit(BROWSE, NULL, NULL);
  } else
    change_screen(NOW_PLAYING);
}
static void open_item(void) {
  if (busy || !page || selected_index >= page->count)
    return;
  controller_library_item_t *item = &page->items[selected_index];
  if (*item->location) {
    if (depth == HISTORY_MAX) {
      lv_label_set_text(subtitle, "Use Back before opening more folders.");
      return;
    }
    snprintf(history[depth].location, sizeof(history[depth].location), "%s",
             location);
    history[depth].offset = offset;
    history[depth].selected_index = selected_index;
    depth++;
    snprintf(location, sizeof(location), "%s", item->location);
    offset = selected_index = 0;
    submit(BROWSE, NULL, NULL);
  } else if (*item->ref) {
    chooser = true;
    render();
  }
}
static void tap(lv_event_t *event) {
  if (lv_event_get_code(event) != LV_EVENT_CLICKED)
    return;
  int action = (int)(intptr_t)lv_event_get_user_data(event);
  if (screen == SETTINGS) {
    if (action == 0)
      change_screen(NOW_PLAYING);
    if (action == 1 || action == 3) {
      if (setting_index == 0) {
        brightness = brightness == 100 ? 70 : brightness == 70 ? 40 : 100;
        platform_display_set_brightness(brightness);
        render();
      } else if (setting_index == 1) {
        bridge_client_request_poll();
        lv_label_set_text(subtitle, "Checking connection...");
      } else {
        char ip[32] = "";
        wifi_mgr_get_ip(ip, sizeof(ip));
        lv_label_set_text_fmt(subtitle,
                              "Open on your phone\nhttp://%s/settings", ip);
      }
    }
    return;
  }
  if (action == 0) {
    back_action();
    return;
  }
  if (busy || !page)
    return;
  if (!page->count) {
    reset_library();
    submit(BROWSE, NULL, NULL);
    return;
  }
  if (action == 3) {
    if (!chooser)
      open_item();
    return;
  }
  if (chooser) {
    if (mutation_locked)
      return;
    submit(action == 1 ? PLAY : QUEUE, page->items[selected_index].ref, NULL);
    return;
  }
  if (action == 1)
    open_item();
  if (action == 2 && *page->items[selected_index].ref) {
    chooser = true;
    render();
  }
}
static lv_obj_t *button(lv_obj_t *parent, int x, int y, int w, int action) {
  lv_obj_t *b = lv_button_create(parent);
  lv_obj_set_size(b, w, 42);
  lv_obj_align(b, LV_ALIGN_TOP_MID, x, y);
  lv_obj_set_style_pad_all(b, 4, 0);
  lv_obj_set_style_bg_color(b, lv_color_hex(0x252525), 0);
  lv_obj_set_style_radius(b, 16, 0);
  lv_obj_t *text = lv_label_create(b);
  lv_obj_set_style_text_font(text, font_manager_get_small(), 0);
  lv_obj_add_event_cb(b, tap, LV_EVENT_CLICKED, (void *)(intptr_t)action);
  return b;
}
static void ensure_overlay(void) {
  if (overlay)
    return;
  overlay = lv_obj_create(lv_screen_active());
  lv_obj_set_size(overlay, 360, 360);
  lv_obj_center(overlay);
  lv_obj_set_style_bg_color(overlay, lv_color_hex(0x080808), 0);
  lv_obj_set_style_bg_opa(overlay, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(overlay, 0, 0);
  lv_obj_set_style_pad_all(overlay, 0, 0);
  lv_obj_remove_flag(overlay, LV_OBJ_FLAG_SCROLLABLE);
  label(&heading, overlay, 24, 220, font_manager_get_small());
  cover = lv_image_create(overlay);
  lv_obj_align(cover, LV_ALIGN_TOP_MID, 0, 69);
  lv_obj_add_flag(cover, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_add_event_cb(cover, tap, LV_EVENT_CLICKED, (void *)3);
  label(&title, overlay, 226, 270, font_manager_get_normal());
  lv_obj_add_flag(title, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_add_event_cb(title, tap, LV_EVENT_CLICKED, (void *)3);
  label(&subtitle, overlay, 261, 250, font_manager_get_small());
  label(&counter, overlay, 337, 130, font_manager_get_small());
  back = button(overlay, -105, 67, 62, 0);
  primary = button(overlay, -52, 285, 96, 1);
  secondary = button(overlay, 52, 285, 96, 2);
  lv_obj_add_flag(overlay, LV_OBJ_FLAG_HIDDEN);
}
static void render(void) {
  ensure_overlay();
  lv_obj_remove_flag(overlay, LV_OBJ_FLAG_HIDDEN);
  lv_obj_move_foreground(overlay);
  button_text(back, "Back");
  lv_obj_remove_flag(primary, LV_OBJ_FLAG_HIDDEN);
  lv_obj_remove_flag(secondary, LV_OBJ_FLAG_HIDDEN);
  if (screen == SETTINGS) {
    clear_cover();
    lv_obj_set_width(primary, 128);
    lv_obj_align(primary, LV_ALIGN_TOP_MID, 0, 238);
    lv_obj_set_width(secondary, 128);
    lv_obj_align(secondary, LV_ALIGN_TOP_MID, 0, 285);
    lv_label_set_text(heading, "Settings");
    lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 84);
    lv_obj_align(subtitle, LV_ALIGN_TOP_MID, 0, 143);
    lv_obj_set_height(title, 36);
    lv_obj_set_height(subtitle, 80);
    const char *names[] = {"Brightness", "Connection", "Wi-Fi", "Music bridge"};
    lv_label_set_text(title, names[setting_index]);
    if (setting_index == 0)
      lv_label_set_text_fmt(subtitle, "%d%%\nTap to change", brightness);
    else if (setting_index == 1) {
      char summary[100], details[200];
      bridge_client_connection_status(summary, sizeof(summary), details,
                                      sizeof(details));
      lv_label_set_text(subtitle, summary);
    } else if (setting_index == 2) {
      char ip[32] = "";
      wifi_mgr_get_ip(ip, sizeof(ip));
      controller_config_snapshot_t config;
      controller_config_snapshot(&config);
      lv_label_set_text_fmt(subtitle, "%s\n%s", config.value.ssid, ip);
    } else {
      char bridge[128] = "";
      bridge_client_get_bridge_url(bridge, sizeof(bridge));
      lv_label_set_text(subtitle, bridge);
    }
    lv_label_set_text_fmt(counter, "%d / 4", setting_index + 1);
    button_text(primary, setting_index == 0   ? "Change"
                         : setting_index == 1 ? "Refresh"
                                              : "Setup");
    lv_obj_add_flag(secondary, LV_OBJ_FLAG_HIDDEN);
    return;
  }
  lv_obj_set_width(primary, 96);
  lv_obj_align(primary, LV_ALIGN_TOP_MID, -52, 285);
  lv_obj_set_width(secondary, 96);
  lv_obj_align(secondary, LV_ALIGN_TOP_MID, 52, 285);
  lv_obj_set_height(title, 36);
  lv_obj_set_height(subtitle, 30);
  lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 226);
  lv_obj_align(subtitle, LV_ALIGN_TOP_MID, 0, 261);
  lv_label_set_text(heading, chooser ? "Choose action" : "Library");
  if (busy && busy_kind != IMAGE) {
    lv_label_set_text(title, "Loading...");
    lv_label_set_text(subtitle, "");
  } else if (!page || !page->count) {
    lv_label_set_text(title, "Library");
    lv_label_set_text(subtitle, page && *page->notice
                                    ? page->notice
                                    : "No items. Tap to refresh.");
  } else {
    lv_label_set_text(title, page->items[selected_index].title);
    lv_label_set_text(subtitle, chooser
                                    ? (mutation_locked
                                           ? "Check now playing before retrying"
                                           : "Choose Play or queue")
                                    : page->items[selected_index].subtitle);
  }
  lv_label_set_text_fmt(counter, "%d",
                        page && page->count ? offset + selected_index + 1 : 0);
  button_text(primary,
              chooser ? "Play"
              : page && page->count && *page->items[selected_index].location
                  ? "Open"
                  : "Select");
  button_text(secondary, chooser ? "Queue" : "Play");
  if (!page || !page->count || (!chooser && !*page->items[selected_index].ref))
    lv_obj_add_flag(secondary, LV_OBJ_FLAG_HIDDEN);
}
static bool submit(int kind, const char *ref, const char *image) {
  if (busy || !requests)
    return false;
  if ((kind == PLAY || kind == QUEUE) && mutation_locked)
    return false;
  request_t *r =
      heap_caps_calloc(1, sizeof(*r), MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (!r)
    return false;
  r->generation = ++generation;
  r->kind = kind;
  r->offset = offset;
  if (!bridge_client_get_request_base(r->endpoint, sizeof(r->endpoint)) ||
      !bridge_client_get_current_zone_id(r->zone, sizeof(r->zone))) {
    free(r);
    if (page)
      snprintf(page->notice, sizeof(page->notice),
               "Pick a zone and connect first.");
    render();
    return false;
  }
  snprintf(r->location, sizeof(r->location), "%s", location);
  if (ref)
    snprintf(r->ref, sizeof(r->ref), "%s", ref);
  if (image)
    snprintf(r->image, sizeof(r->image), "%s", image);
  busy = xQueueSend(requests, r, 0) == pdTRUE;
  if (busy)
    busy_kind = kind;
  if (busy && (kind == PLAY || kind == QUEUE)) {
    mutation_locked = true;
    mutation_sent_ms = esp_timer_get_time() / 1000;
  }
  free(r);
  if (kind != IMAGE) {
    clear_cover();
    render();
  }
  return busy;
}
void halo_navigation_process(void) {
  if (!page) {
    page =
        heap_caps_calloc(1, sizeof(*page), MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!page)
      return;
    page->next_offset = -1;
    requests = xQueueCreate(1, sizeof(request_t));
    results = xQueueCreate(1, sizeof(result_t *));
    if (!requests || !results ||
        xTaskCreate(worker, "halo_library", 12288, NULL, 3, NULL) != pdPASS) {
      snprintf(page->notice, sizeof(page->notice),
               "Library memory unavailable");
      requests = NULL;
    }
  }
  char base[128] = "", selected[64] = "";
  bridge_client_get_request_base(base, sizeof(base));
  bridge_client_get_current_zone_id(selected, sizeof(selected));
  if (strcmp(base, endpoint) || strcmp(selected, zone)) {
    snprintf(endpoint, sizeof(endpoint), "%s", base);
    snprintf(zone, sizeof(zone), "%s", selected);
    reset_library();
    clear_cover();
    if (screen == LIBRARY && !busy) {
      render();
      submit(BROWSE, NULL, NULL);
    }
  }
  result_t *result;
  if (results && xQueueReceive(results, &result, 0) == pdTRUE) {
    busy = false;
    if (result && result->request.generation == generation &&
        request_current(&result->request)) {
      if (result->request.kind == IMAGE) {
        if (result->ok && screen == LIBRARY) {
          clear_cover();
          cover_pixels = result->pixels;
          result->pixels = NULL;
          cover_dsc.header.magic = LV_IMAGE_HEADER_MAGIC;
          cover_dsc.header.cf = LV_COLOR_FORMAT_RGB565;
          cover_dsc.header.w = COVER_SIZE;
          cover_dsc.header.h = COVER_SIZE;
          cover_dsc.header.stride = COVER_SIZE * 2;
          cover_dsc.data_size = COVER_BYTES;
          cover_dsc.data = (uint8_t *)cover_pixels;
          lv_image_set_src(cover, &cover_dsc);
          lv_obj_remove_flag(cover, LV_OBJ_FLAG_HIDDEN);
        }
      } else if (result->request.kind == BROWSE) {
        *page = result->page;
        if (selected_index >= page->count)
          selected_index = page->count ? page->count - 1 : 0;
        render();
        if (result->ok)
          selected_cover();
      } else {
        bridge_client_request_poll();
        if (result->ok) {
          reset_library();
          change_screen(NOW_PLAYING);
        } else {
          page->count = 0;
          snprintf(page->notice, sizeof(page->notice), "%s",
                   result->page.notice);
          render();
        }
      }
    } else if (screen == LIBRARY) {
      if (!result) {
        page->count = 0;
        snprintf(page->notice, sizeof(page->notice),
                 "Not enough memory. Tap to retry.");
        render();
      } else if (result->request.kind == IMAGE && page->count) {
        render();
        selected_cover();
      } else {
        render();
        submit(BROWSE, NULL, NULL);
      }
    }
    if (result) {
      platform_http_free(result->pixels);
      free(result);
    }
  }
  /* No automatic mutation replay. A later fresh bridge poll permits another
   * deliberate action. */
  if (mutation_locked && !busy) {
    controller_connection_t c;
    bridge_client_connection_snapshot(&c);
    if (controller_connection_ready(&c) &&
        c.last_success_ms > (uint64_t)mutation_sent_ms)
      mutation_locked = false;
  }
  if (screen == ZONES && !ui_is_zone_picker_visible())
    change_screen(NOW_PLAYING);
}
void halo_navigation_swipe(int dx, int dy) {
  if (abs(dy) > abs(dx))
    change_screen((screen + (dy < 0 ? 1 : SCREEN_COUNT - 1)) % SCREEN_COUNT);
  else if (screen == LIBRARY)
    move_item(dx < 0 ? 1 : -1);
}
bool halo_navigation_encoder(int delta) {
  if (screen == ZONES) {
    ui_zone_picker_scroll(delta > 0 ? 1 : -1);
    return true;
  }
  if (screen == LIBRARY) {
    move_item(delta);
    return true;
  }
  if (screen == SETTINGS) {
    setting_index += delta > 0 ? 1 : -1;
    if (setting_index < 0)
      setting_index = 0;
    if (setting_index > 3)
      setting_index = 3;
    render();
    return true;
  }
  return false;
}
void halo_navigation_settings(void) { change_screen(SETTINGS); }
bool halo_navigation_settings_visible(void) { return screen == SETTINGS; }

void halo_navigation_close_settings(void) {
  if (screen == SETTINGS)
    change_screen(NOW_PLAYING);
}
