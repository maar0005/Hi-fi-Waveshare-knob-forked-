# HALO Touch library prototype

Issue #277 and draft PR #278 target HALO TOUCH V2, MAC `80:b5:4e:f9:e1:a8`, on the v2.8 integration branch. The existing display initialization, encoder pin map and settings persistence remain the baseline. Other targets do not compile the HALO navigation renderer.

Artwork is home. Tap artwork to reveal playback controls and Menu; use Menu to choose Library, the listening zone or Settings. Home returns to artwork. Back returns to the parent collection or menu. Sources, folders, Zones and Settings scroll vertically with touch. Pages containing mostly cover images use a horizontal, center-snapping album carousel with adjacent cards visible. Open enters a collection; Play sends playback directly; Queue adds it to the queue. A playable leaf selected from a list opens explicit Play/Queue actions. Folder Back preserves page and selection; page boundaries have visible Previous/More controls.

The knob controls volume only on Artwork and Now playing. On all other surfaces it moves through rows, album cards or action choices, preserving accumulated detents. Touch scrolling updates the browsing focus so switching to the knob continues from the visible content. There is no global swipe-to-change-screen gesture. Pointer down, movement and release go directly to LVGL, providing normal pressed feedback, drag scrolling, inertia, click cancellation and carousel snapping. LVGL handles display rotation once. Deliberate slow taps have no custom time cutoff.

Settings exposes a brightness slider, connection refresh, Wi-Fi status and the music bridge address. Wi-Fi and bridge setup open the existing phone web-settings address. Brightness is session-only; HALO OTA remains unsupported.

The shared parser validates UHC zone scope, outcomes, page sizes and image paths. The worker runs HTTP outside the UI task. Memory is bounded to one 12-item page, eight levels of parent descriptors, and at most twelve 132×132 RGB565 covers (418,176 pixel bytes in PSRAM). Only the selected cover and its neighbours are fetched, once per page. Missing art has a placeholder. Leaving or changing a folder/zone/endpoint invalidates outstanding results. Back works during downloads. A deliberate playback action can wait for an image request to drain; navigating away cancels it. Playback is sent once and never automatically retried after a timeout. A later fresh bridge poll releases the mutation lock.

## Direction contract

THESIS: touch directly moves music content; navigation names destinations instead of hiding them in a mode loop.

OWN-WORLD: inherit HiPhi's dark artwork-led display, Lato/Noto Sans bitmap fonts, readable labels and restrained blue focus/pressed states.

STORY: see the music, open Menu, pick a collection or zone, then deliberately play. Return to artwork at any point.

FIRST VIEWPORT: full artwork without buttons, text or rings; tap artwork to reveal playback controls and Menu. Task screens have a heading, Back/Home, scrollable content and explicit actions within the round display.

FORM: native LVGL lists for hierarchy and settings; horizontal cover carousel for artwork-rich collections. The existing firmware's visual system stays intact.

FINISH: build and run native interaction checks, inspect round-masked production-widget renders, run finish review/dissent and record the exact hardware artifact. Physical usability remains a maintainer test; keep the PR draft until qualified.

## Verification

Shared parser tests cover wrong-zone envelopes, accepted/refused mutations, malformed rows, oversized pages and untrusted artwork URLs under AddressSanitizer/UndefinedBehaviorSanitizer. `tests/halo_native` executes the production renderer with real LVGL pointer/scroll processing and substituted hardware/network boundaries. It checks a held touch, drag without activation or mode changes, all zone rows, accumulated detents, carousel focus, one-touch Play, Back during image IO and cancellation when leaving before playback submission. It can export round-masked framebuffer previews using the production fonts. These are native host renders, not device photographs.

Physical testing must cover sustained boot, artwork, touch scrolling and snapping, mixed touch/knob navigation, folder Back and paging, deliberate playback in the chosen zone, reconnect, and zone changes during loading. Only write the application at `0x10000` on the verified attached unit. Preserve NVS, bootloader and partition table. Record source SHA, artifact SHA256 and observations in the issue/PR. A compile or boot is not proof of usable hardware behavior.
