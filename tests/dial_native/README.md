# Native Dial UI checks

This harness compiles the production round touch navigation (`common/controller_touch_navigation.c`) with the Dial's pinned LVGL 9.5.0 and bitmap fonts. Pointer/scroll processing and widget rendering are real LVGL; hardware, queues, bridge state, Home Assistant lights and HTTP are controlled substitutes. The network worker is not run. Fixtures are synthetic and no playback reaches a real server.

```sh
cmake -S tests/dial_native -B /tmp/dial-native-build -DLVGL_SOURCE="$PWD/idf_app/managed_components/lvgl__lvgl" -DCJSON_SOURCE="$IDF_PATH/components/json/cJSON" -DDIAL_SANITIZE=ON
cmake --build /tmp/dial-native-build -j8
/tmp/dial-native-build/dial_native_checks
```

Without `CJSON_SOURCE`, CMake uses `pkg-config libcjson`; CI installs `libcjson-dev`. CI fetches the exact upstream LVGL 9.5.0 commit, matching the target's pinned version. Pass one existing output directory as the executable's optional argument to export round-masked PPM previews of Menu, Settings, Zones, Lights and the album carousel.

The harness checks slow pointer presses, vertical scrolling without accidental activation or navigation, 64-zone focus, touch/encoder scrolling, album snapping, direct selected-item Play after image IO, Back availability, cancellation on Home and chooser Back, stale image and old-zone browse results, repeated image URLs and excess detents across page boundaries. It uses the Dial's 24 KiB initial plus 72 KiB expansion pool. Native host object sizes and RGB888 rendering differ from the ESP's 32-bit objects/RGB565 display; device qualification remains mandatory.

It also covers setup/offline/storage recovery and artwork restoration, native network/bridge entry validation, timeout feedback, saved-network confirmation and cancellation, brightness debounce/load/save boundary checks, Search filtering with preserved offsets, 180-degree pointer navigation, device-controls scrolling, latching the whole panel-wake contact until release, and the Lights list and dimmer (knob steps, arc drag, toggle, errors, periodic refresh). Shared UI, actual flash erase and NVS are boundary substitutes; the harness does not emulate the real Dial sleep engine, panel, BLE/OTA hardware or Home Assistant.
