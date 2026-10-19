# Target Notes

This fork builds one controller, the HiPhi Dial on the Waveshare ESP32-S3-Knob-Touch-LCD-1.8, plus the parking image for that board's second ESP32. Other HiPhi controllers (Frame, Slate, Joy, HALO, Tough and the M5 betas) were removed; they remain in the upstream HiPhi repository. ESP-IDF 5.5.5 is the current build baseline. The table records configured build geometry; exact-unit validation remains a separate release gate.

| Controller | Exact hardware | Build directory | Stable device slug | Chip / flash / PSRAM mode | Published application |
|---|---|---|---|---|---|
| [HiPhi Dial](#hiphi-dial) | Waveshare ESP32-S3-Knob-Touch-LCD-1.8 | `idf_app` | `hiphi-dial` | ESP32-S3 / 16 MB / octal | `hiphi_dial.bin` |
| [Dial auxiliary image](#dial-auxiliary-parking-image) | Waveshare knob, second ESP32 | `knob_aux_app` | n/a | ESP32 / 4 MB / none | `hiphi_knob_aux_park.bin` |

The device slug and the `roon_knob*.bin` Dial compatibility aliases remain fixed.

## Capability and support boundaries

| Capability | Boundary |
|---|---|
| BLE HID media remote | Shared optional host with persistent enablement and pairing/status controls, off by default. Pairing/reconnect and Wi-Fi coexistence still require exact-artifact hardware tests. |
| Home Assistant lights | Up to four `light.*` entities dimmed over Home Assistant's REST API; see [HOME_ASSISTANT_LIGHTS.md](../usage/HOME_ASSISTANT_LIGHTS.md). |
| Bridge-served on-device OTA | The bridge serves the upstream Dial feed. Firmware checks ESP32-S3, 16 MB geometry, and `hiphi_dial` or historical `roon_knob` application identity before erasing an OTA slot. This rejects accidental sibling images; it does not authenticate firmware. An automatic update installs upstream firmware without this fork's changes. |

Build success and artifact integrity establish reproducible delivery evidence. They do not establish cold boot, display/input behavior, sustained Wi-Fi/BLE operation or battery budgets. Record exact hardware revision, build SHA, artifact SHA-256, and observed results in the relevant GitHub issue/PR.

## HiPhi Dial

Fully documented. See [docs/usage/DIAL.md](../usage/DIAL.md) for setup and controls, and [`docs/dial/`](../dial/) for hardware and driver reference:

- [DISPLAY.md](../dial/DISPLAY.md), [TOUCH_INPUT.md](../dial/TOUCH_INPUT.md), [SWIPE_GESTURES.md](../dial/SWIPE_GESTURES.md), [ROTARY_ENCODER.md](../dial/ROTARY_ENCODER.md)
- [BATTERY_MONITORING.md](../dial/BATTERY_MONITORING.md), [FONTS.md](../dial/FONTS.md), [MEMORY.md](../dial/MEMORY.md)
- [BLE_HID.md](../dial/BLE_HID.md) — BLE media-remote host
- [hw-reference/](../dial/hw-reference/) — [board.md](../dial/hw-reference/board.md), [HARDWARE_PINS.md](../dial/hw-reference/HARDWARE_PINS.md)

## Dial auxiliary parking image

- [DUAL_CHIP_ARCHITECTURE.md](../dial/DUAL_CHIP_ARCHITECTURE.md) — why the board has a
second ESP32 and what the parking image does with it.

## Shared notes

- [usage/FIRMWARE_FLASHING.md](../usage/FIRMWARE_FLASHING.md)
- [usage/WIFI_PROVISIONING.md](../usage/WIFI_PROVISIONING.md)
- [usage/OTA_UPDATES.md](../usage/OTA_UPDATES.md)
- [dial/FIRMWARE_ARTIFACTS.md](../dial/FIRMWARE_ARTIFACTS.md) — artifact names and aliases
- [dial/NETWORK_IDENTITY.md](../dial/NETWORK_IDENTITY.md) — mDNS, hostname, and wire identity
- [connection-recovery.md](../connection-recovery.md)
- [`.oh/controller-provisioning-config.md`](../../.oh/controller-provisioning-config.md)
