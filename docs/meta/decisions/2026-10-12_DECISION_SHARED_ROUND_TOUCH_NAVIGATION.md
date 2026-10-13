# Shared round touch navigation for Dial and HALO

**Date:** 2026-10-12
**Status:** Implemented for PR #278; exact-artifact hardware qualification pending
**Issue:** #277

## Decision

The maintainer requested the tested HALO navigation and audit fixes on the Waveshare HiPhi Dial. Both targets have a 360px round LVGL surface. Share the existing renderer and asynchronous library coordinator in `common/controller_touch_navigation.c`, retaining HALO compatibility entry points. Target adapters implement fonts, brightness persistence, presentation/power transitions and optional device controls through `platform_touch_navigation.h`. Do not include HALO hardware code in the Dial build or duplicate the renderer.

## Alternatives and constraints

Flashing the HALO image is invalid: the Dial uses a different panel, input and power profile. Copying the renderer into `idf_app` would make future fixes diverge. Porting only Settings would omit the requested library/navigation experience. Sharing the frontend behind narrow target hooks preserves the tested behavior while keeping battery, BLE, OTA, wake and sleep machinery target-owned.

The shared module is a UI coordinator, not the target-neutral playback controller core. Its deliberate backend/configuration dependencies are enumerated in the include policy; the pure renderer/controller boundary rules are not relaxed. Target fonts are obtained through adapter hooks rather than shared code including an IDF implementation header.

## Risk retirement

Native checks run the same production renderer for both adapter capability profiles under ASan/UBSan, with real LVGL pointer scrolling, 180-degree pointer navigation, device-controls routing and full-contact wake suppression. Both firmware builds and dependency negative fixtures must pass. Dial stack analysis finds a 9,728-byte render frame nested under a 3,328-byte process frame; the UI task is 32 KiB, with runtime margin still requiring exact-artifact measurement. The optimized ESP-IDF 5.5.5, 16 MB build profile remains in force.

## Hardware boundary

The attached Waveshare main controller is ESP32-S3 MAC `d0:cf:13:1e:1b:f4`, with 8 MB embedded PSRAM. The first cable orientation exposed auxiliary ESP32 MAC `44:1d:64:92:a7:a8`; it was read only. After flipping USB-C, the main controller was identified. The live main partition table matches the Dial profile and both OTA metadata records are erased, so it boots factory app at `0x10000`. Installation must preserve the partition table, NVS, bootloader and auxiliary chip and use the exact CI application artifact. Build success is not physical touch, sleep, BLE or persistence qualification.
