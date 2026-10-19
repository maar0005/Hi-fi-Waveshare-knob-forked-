// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
/* Optional room-light control used by the round touch navigation. A target
 * without lights returns 0 from platform_lights_count() and the UI hides the
 * Lights entry. All calls are non-blocking: network work happens elsewhere. */
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define PLATFORM_LIGHTS_NAME_MAX 33
#define PLATFORM_LIGHTS_NOTICE_MAX 64

typedef struct {
  char name[PLATFORM_LIGHTS_NAME_MAX];
  bool known;     /* a state has been read or confirmed */
  bool available; /* false when Home Assistant reports it unavailable */
  bool on;
  bool dimmable;
  bool busy;      /* a command or refresh is in flight or queued */
  int brightness_pct;
  char notice[PLATFORM_LIGHTS_NOTICE_MAX]; /* last error; empty when healthy */
} platform_light_view_t;

int platform_lights_count(void);
bool platform_lights_view(int index, platform_light_view_t *out);
/* Changes whenever any view changes, so the UI can redraw only when needed. */
uint32_t platform_lights_revision(void);
void platform_lights_refresh(int index);
/* 0 turns the light off. Rapid calls coalesce; the latest value wins. */
void platform_lights_set_brightness(int index, int percent);
void platform_lights_toggle(int index);
