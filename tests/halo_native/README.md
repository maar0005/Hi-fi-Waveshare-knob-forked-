# Native HALO UI checks

This harness compiles the production `halo_navigation.c` renderer with HALO's pinned LVGL 9.5.0 and bitmap fonts. Pointer/scroll processing and widget rendering are real LVGL; hardware, queues, bridge state and HTTP are controlled substitutes. The network worker is not run. Fixtures are synthetic and no playback reaches a real server.

```sh
cmake -S tests/halo_native -B /tmp/halo-native-build -DLVGL_SOURCE="$PWD/halo_app/managed_components/lvgl__lvgl" -DCJSON_SOURCE="$IDF_PATH/components/json/cJSON" -DHALO_SANITIZE=ON
cmake --build /tmp/halo-native-build -j8
/tmp/halo-native-build/halo_native_checks
```

Without `CJSON_SOURCE`, CMake uses `pkg-config libcjson`; CI installs `libcjson-dev`. CI fetches the exact upstream LVGL 9.5.0 commit, matching the target's pinned version. Pass one existing output directory as the executable's optional argument to export round-masked PPM previews of Menu, Settings, Zones and the album carousel.

The harness checks slow pointer presses, vertical scrolling without accidental activation or navigation, 64-zone focus, touch/encoder scrolling, album snapping, direct selected-item Play after image IO, Back availability, cancellation on Home and chooser Back, stale image and old-zone browse results, repeated image URLs and excess detents across page boundaries. It uses the HALO's 24 KiB initial plus 72 KiB expansion pool. Native host object sizes and RGB888 rendering differ from the ESP's 32-bit objects/RGB565 display; device qualification remains mandatory.
