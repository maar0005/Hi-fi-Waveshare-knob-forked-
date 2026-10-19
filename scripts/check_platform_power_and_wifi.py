#!/usr/bin/env python3
"""Guard shared power snapshots and Wi-Fi scan coverage on the Dial."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED: dict[str, tuple[str, ...]] = {
    "common/platform/platform_power.h": (
        "platform_power_snapshot_t",
        "void platform_power_snapshot(platform_power_snapshot_t *out)",
        "platform_power_diagnostics_t",
        "platform_power_diagnostics_snapshot",
        "platform_power_debug_arm_sleep",
        "platform_power_prepare_for_deep_sleep",
        "platform_power_evidence_note_entry",
        "PLATFORM_POWER_CAP_VOLTAGE_EXPERIMENT",
        "PLATFORM_POWER_EXPERIMENT_MAX_SAMPLES 24",
        "platform_power_experiment_arm",
        "platform_power_experiment_note_early_boot",
        "last_boot_followed_terminal_entry",
        "PLATFORM_POWER_TRACE_MAX_EVENTS 8",
        "platform_power_trace_event_t trace_events",
        "int64_t unix_time_ms",
    ),
    "common/platform/platform_power.c": (
        "controller_config_snapshot(&config)",
        "platform_power_diagnostics_enrich(out)",
        "esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL)",
        "pm_config.light_sleep_enable",
        'POWER_EVIDENCE_NAMESPACE = "pwr_evidence"',
        'POWER_EVIDENCE_KEY = "journal_v4"',
        'POWER_EVIDENCE_V3_KEY = "journal_v3"',
        "record.last_boot_followed_entry = record.entry_pending",
        "power_evidence_append(&record, PLATFORM_POWER_TRACE_BOOT",
        "platform_power_evidence_note_boot()",
        'POWER_EXPERIMENT_NAMESPACE = "pwr_experiment"',
        'POWER_EXPERIMENT_KEY = "experiment_v1"',
        "record.observer_effect = interval_sec > 0",
        "wake == ESP_SLEEP_WAKEUP_TIMER && record.interval_sec > 0",
        "power_experiment_save(&record)",
    ),
    "common/app_main.c": (
        "platform_power_evidence_note_boot()",
    ),
    "common/power_debug_web.c": (
        '"/power-debug"',
        '"/power-debug/sleep"',
        '"schema_version\\\":3',
        '"timestamp_utc\\\":%s%s%s',
        '"last_boot_followed_entry\\\"',
        '"events\\\":%s',
        '"sampling_mode\\\":\\\"%s',
        '"software-checkpoint" : "external-profiler"',
        'return "none"',
        '"power_experiment_supported\\\":%s',
        "parse_u32(value, &interval_sec)",
        "parse_u32(value, &duration_sec)",
        "interval_sec = POWER_EXPERIMENT_DEFAULT_INTERVAL_SEC",
        '"samples_truncated\\\":%s',
        "platform_power_experiment_clear()",
        'strcmp(format, "csv") == 0',
        "Persistent event tail",
        "power_debug_web_register",
    ),
    "common/bridge_client.c": (
        '"platform/platform_power.h"',
        "fetch_now_playing(&state, &power)",
        "wait_for_poll_interval(&power)",
        "check_charging_state_change(power.external_power)",
    ),
    "common/wifi_manager.c": (
        "esp_netif_sntp_init(&config)",
        "platform_power_evidence_note_time_sync",
    ),
    "common/ui.c": (
        '"platform/platform_power.h"',
        "platform_power_snapshot(&power)",
    ),
    "idf_app/main/platform_display_idf.c": (
        "void platform_power_snapshot",
        "battery_get_percentage()",
        "battery_is_charging()",
        "PLATFORM_POWER_CAP_VOLTAGE_EXPERIMENT",
        "platform_power_experiment_supported",
    ),
    "idf_app/main/battery.c": (
        "BATTERY_SAMPLE_CACHE_MS 15000",
        "s_cached_voltage_valid",
        "s_battery_mutex",
        "battery_get_measurement",
        "s_cached_raw_adc",
        "s_cached_adc_mv",
    ),
    "idf_app/main/main_idf.c": (
        "resume_power_experiment_before_ui();",
        "platform_power_experiment_note_early_boot(",
        "Power experiment checkpoint saved",
        "without UI, Wi-Fi, or BLE",
    ),
    "common/wifi_manager.c": (
        "esp_wifi_scan_start(&config, false)",
        "WIFI_MODE_APSTA",
    ),
    "common/wifi_portal_form.c": (
        "rk_wifi_portal_scan_prepare",
        "wifi_mgr_scan_start()",
        "rk_wifi_portal_render_options",
        "rk_wifi_portal_resolve_ssid",
    ),
    "common/wifi_portal_form.h": (
        "RK_WIFI_PORTAL_SELECT_OPEN",
        "RK_WIFI_PORTAL_SELECT_CLOSE",
        "RK_WIFI_PORTAL_AUTO_REFRESH_SCRIPT",
    ),
    "idf_app/main/captive_portal.c": (
        '"wifi_portal_form.h"',
        "rk_wifi_portal_scan_prepare",
        "rk_wifi_portal_render_options",
        "rk_wifi_portal_resolve_ssid",
    ),
    "idf_app/main/config_server.c": (
        '"wifi_portal_form.h"',
        "rk_wifi_portal_scan_prepare",
        "rk_wifi_portal_render_options",
        "rk_wifi_portal_resolve_ssid",
        "power_debug_web_register(s_server)",
    ),
    "idf_app/main/display_sleep.c": (
        "RTC_DATA_ATTR static power_debug_rtc_t",
        "s_power_debug_rtc.preflight_completions++",
        "s_power_debug_rtc.deep_sleep_entries++",
        "s_power_debug_rtc.encoder_wakes++",
        "platform_power_prepare_for_deep_sleep()",
        "LCD_CMD_SLEEP_IN",
        "LCD_CMD_SLEEP_OUT",
        "TOUCH_RESET_GPIO",
        "platform_power_evidence_note_preflight(durable_flags)",
        "platform_power_experiment_note_entry(",
        "esp_sleep_enable_timer_wakeup(",
        "must not silently cancel it",
        "display_get_state() != DISPLAY_STATE_SLEEP",
    ),
    "idf_app/main/CMakeLists.txt": (
        '"../../common/power_debug_web.c"',
        '"../../common/wifi_portal_form.c"',
    ),
    ".github/RELEASE_TEMPLATE.md": (
        "The Dial scans for nearby 2.4 GHz networks",
        "one shared power snapshot now supplies",
        "The Dial exposes `/power-debug`",
        "The Dial's `/power-debug/sleep` endpoint now runs one persistent power",
    ),
}

FORBIDDEN: dict[str, tuple[str, ...]] = {
    "common/platform/platform_display.h": ("platform_battery_",),
    "common/bridge_client.c": (
        "platform_battery_get_level()",
        "platform_battery_is_charging()",
    ),
    "common/ui.c": (
        "battery_get_percentage()",
        "battery_is_charging()",
    ),
    "idf_app/main/main_idf.c": (
        "wifi_mgr_start();\n    resume_power_experiment_before_ui();",
        "platform_display_init();\n    resume_power_experiment_before_ui();",
    ),
    "idf_app/main/config_server.c": ("display_power_debug_snapshot",),
    ".github/RELEASE_TEMPLATE.md": (
        "HiPhi Dial captive page still uses manual SSID entry",
    ),
}


def main() -> int:
    failures: list[str] = []
    for relative, needles in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"{relative}: required file is missing")
            continue
        text = path.read_text(encoding="utf-8")
        for needle in needles:
            if needle not in text:
                failures.append(f"{relative}: missing contract {needle!r}")

    for relative, needles in FORBIDDEN.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            if needle in text:
                failures.append(f"{relative}: forbidden legacy path {needle!r}")

    if failures:
        print("Platform power/Wi-Fi contract check FAILED", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Platform power/Wi-Fi contract check passed")
    print("- one power snapshot feeds each shared controller poll cycle")
    print("- the Dial exposes the shared non-blocking Wi-Fi scan")
    print("- the Dial exposes the shared power-debug schema")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
