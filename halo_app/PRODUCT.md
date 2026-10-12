# HiPhi HALO Touch

<!-- impeccable:product-schema 1 -->

## Platform

Native embedded LVGL on HALO TOUCH V2: 360×360 round touch display and rotary input, ESP32-S3, 8 MB PSRAM, USB power.

## Users and purpose

Listeners should see artwork and choose music, zones and routine controls without opening a general-purpose screen. Artwork leads the home view. Search is outside this prototype.

## Confirmed interaction

The maintainer tested the first five-screen swipe loop and found it extremely awkward. They authorized the full critique recommendations: named navigation, ordinary touch scrolling, an album carousel that follows the finger, reliable Back, and honest action labels. Rotary input adjusts volume only on Artwork/Now playing; everywhere else it scrolls content or choices. Touch must work without requiring the knob.

## Constraints and evidence

Preserve the existing panel, touch and encoder drivers, NVS and bootloader. Music browsing and commands use the existing UHC API. Other firmware targets retain their UI. Only the attached HALO with MAC 80:b5:4e:f9:e1:a8 is the hardware test target. Native host rendering can verify layout and pointer behavior; physical feel and exact-artifact hardware qualification remain human checks. No merge or release tag approval has been given.
