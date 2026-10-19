# HiPhi Dial v{{VERSION}}

Firmware for the Waveshare ESP32-S3-Knob-Touch-LCD-1.8 (HiPhi Dial) and its
auxiliary parking image. This fork builds only the Waveshare knob.

## Home Assistant lights and Roon playlists

When Home Assistant lights are configured on the Dial's web settings page
(`http://<dial-ip>/ha`), Menu shows **Lights**. Turn the knob to dim the chosen
light in 5% steps, drag the arc, or toggle it on and off. Roon playlists are
under **Menu → Library → Playlists**. See `docs/usage/HOME_ASSISTANT_LIGHTS.md`.

## The Waveshare Dial now sleeps between jobs

The Waveshare ESP32-S3-Knob-Touch-LCD-1.8 contains two programmable
processors. This alpha changes the power behavior of both:

- **Wi-Fi modem sleep:** the Dial stays connected, but its radio can sleep
  between access-point beacons and controller requests.
- **Automatic Light-sleep:** the main ESP32-S3 lowers its clock and sleeps
  between jobs when no task or radio lock needs it.
- **Main ESP32-S3 Deep-sleep:** on battery, the display progresses through Art
  mode, dim, panel off, and finally ESP32-S3 Deep-sleep. BLE, Wi-Fi, the LCD,
  and the backlight shut down first. Turning the encoder wakes the Dial with a
  fresh boot and reconnect.
- **Complete LCD/touch terminal shutdown:** Display Off alone left the LCD
  controller running. The Dial now also sends the controller's Sleep In command
  and holds the touch controller in reset before the ESP32-S3 enters Deep-sleep.
- **No inherited timer wake:** before Deep-sleep, the shared power preflight
  disables automatic Light-sleep and clears its temporary timer wake source.
  A direct powered test exposed and removed the timer reboot that had prevented
  the main ESP32-S3 from remaining asleep.
- **The second ESP32 is parked:** install the separate auxiliary parking image
  once. It mutes the audio DAC, disables every wake source, and immediately
  enters Deep-sleep on every boot. The board wires this chip's enable pin high,
  so firmware cannot literally cut its power.
- **Less repeated work while awake:** one shared power snapshot now supplies
  battery level and external-power state to the whole status cycle. The Dial's
  16-sample ADC reading is cached for 15 seconds instead of being repeated by
  the UI, polling, and sleep-policy callers.
- **Less log noise:** the routine two-second now-playing request, response, and
  parse messages and periodic memory reports now require debug logging. Power
  policy, shutdown, sleep, and wake events remain visible at normal log levels.

For fresh/default configurations, the battery timeline is 30 seconds to Art
mode, another 30 seconds to dim, another 60 seconds to turn the panel off, then
one minute to Deep-sleep. Existing saved timeout choices are preserved rather
than silently migrated. The server can override those values. While USB power
is detected, panel sleep and Deep-sleep remain disabled by default.

The Dial still chooses between its battery and plugged-in policies using a
voltage heuristic. A nearly full battery can temporarily receive the plugged-in
policy and stay awake longer than expected.

The Dial's `/power-debug/sleep` endpoint now runs one persistent power
experiment rather than the earlier one-shot sleep trigger. By default it wakes
every 20 minutes through a minimal boot path, samples raw ADC and battery
voltage, commits the bounded record to NVS, and immediately returns to
Deep-sleep without starting the display, Wi-Fi, BLE, or application. Supply
`interval_sec=0` when using an external current profiler: the same experiment
records its entry and final wake but adds no periodic sampling wakes. Both modes
take a maximum duration, have a unique experiment ID, export JSON or CSV, and
can be cleared. The export reports if a deliberately denser or longer run has
wrapped the 24-sample durable ring. Software checkpoints affect the discharge
curve and are marked as observer effects; neither mode substitutes for an ammeter.

The earlier v2.7.0-alpha.2 Dial image fully discharged one test unit overnight
despite reporting a Deep-sleep entry. This build closes the LCD/touch shutdown
gap and adds evidence that survives brownout, but battery runtime remains
unproven until an exact image completes an overnight test and external-current
measurement.

The Dial works after installing the main firmware. For the lowest idle draw,
also park the board's otherwise-unused auxiliary ESP32 once:

1. Install the [HiPhi Dial firmware](https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/hiphi_dial_merged.bin) on the main ESP32-S3.
2. Once, flip the USB-C cable to the other orientation and install the
   [auxiliary ESP32 parking image](https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/hiphi_knob_aux_park_merged.bin).
We have not measured a battery-life improvement yet.

## Wi-Fi scanning and power debug

The Dial scans for nearby 2.4 GHz networks during setup without stopping the
setup access point, and shows the list in both captive setup and connected
settings. You can pick a visible SSID, retry a scan, or type a hidden network.

The Dial exposes `/power-debug` and `/power-debug?format=json` from its
connected settings page, reporting the power source, active timeouts, display
state, reset and wake cause, and its sleep capabilities.

## Hardware

| HiPhi controller | Exact hardware | Buy from the manufacturer | Firmware |
| --- | --- | --- | --- |
| **HiPhi Dial** | Waveshare ESP32-S3-Knob-Touch-LCD-1.8; choose a battery-included variant for portable use | [Waveshare](https://www.waveshare.com/esp32-s3-knob-touch-lcd-1.8.htm) | [Main](https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/hiphi_dial_merged.bin) + [auxiliary parking image](https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/hiphi_knob_aux_park_merged.bin) |

The auxiliary parking image belongs to the HiPhi Dial's second chip; it is not
a separate controller.

[Download SHA-256 checksums](https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/SHA256SUMS.txt)

## Install

To update while keeping Wi-Fi and controller settings, write only the
application image at `0x10000`:

```console
esptool.py --chip esp32s3 write_flash 0x10000 hiphi_dial.bin
```

The merged `.bin` downloads are factory images; writing one at address `0x0`
erases saved settings.

Automatic updates come from the Unified Hi-Fi Control bridge, not from this
repository's releases, so an automatic update installs upstream HiPhi firmware
without this fork's changes.

**HiPhi by Open Horizon Labs** — [hiphi.audio](https://hiphi.audio)

Free for personal, noncommercial use under PolyForm Noncommercial 1.0.0.
Installers, integrators, and businesses need a commercial license (see
[COMMERCIAL-LICENSE.md](https://github.com/muness/roon-knob/blob/master/COMMERCIAL-LICENSE.md)).
