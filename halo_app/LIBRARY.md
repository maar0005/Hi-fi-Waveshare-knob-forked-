# HALO Touch library prototype

Issue #277 targets HALO TOUCH V2, MAC `80:b5:4e:f9:e1:a8`, on the existing v2.8 integration branch. Its 360×360 display, touch, encoder pin map and factory panel initialization remain the hardware baseline. Other targets do not compile the HALO navigation renderer.

Vertical swipes cycle Artwork → Now playing → Library → Zones → Settings. Horizontal swipes and the knob move through Library items. Touch opens a folder or a separate Play/Add to queue chooser. Back restores the previous folder, page and selection. The knob controls volume only on Artwork and Now playing; it scrolls items on Library, zone choices on Zones and setting choices on Settings. Search is deliberately omitted.

Settings displays Brightness, Connection, Wi-Fi and Music bridge as readable full-screen choices. Touch changes brightness, requests a connection refresh, or displays the existing web settings address. Brightness is session-only; saved network/bridge settings continue to use the existing web configuration owner. HALO OTA remains unsupported.

The shared `controller_library` parser/body builder uses UHC's opaque location/ref handles and validates envelope zone scope, outcome, page size and image paths. The HALO worker runs HTTP outside the UI task. It retains one 12-item page, an eight-level descriptor-only history and one 144×144 RGB565 cover. Image failures clear the previous cover. Zone/endpoint changes invalidate navigation results. Playback requests are sent once, require deliberate touch, and are not retried after a timeout. A subsequent fresh bridge poll releases the mutation lock; server refusals require a fresh browse before another selection.

Touch events are buffered until release so a directional swipe never delivers a tap to the button below it. Existing 60-pixel/500-ms gesture thresholds and 180-degree coordinate compensation are retained. The original immediate touch-to-exit-art behavior is replaced by the explicit screen flow for this HALO prototype.

## Verification and remaining evidence

The shared parser tests exercise wrong-zone envelopes, accepted-versus-refused mutations, malformed rows, oversized pages, foreign artwork URLs, extra URL parameters, opaque JSON quoting and unsupported mutation verbs under AddressSanitizer/UndefinedBehaviorSanitizer. Hardware checks must use the exact saved artifact: boot and Wi-Fi recovery, repeated vertical swipes, both directions of encoder scrolling on each page, album covers, folder/back/paging focus, deliberate playback in the displayed zone, reconnect and a zone change during loading. A compile or boot does not establish touch/display/playback success.

Only the application at `0x10000` may be written to the verified attached unit; its existing partition table matches this target's factory layout. Preserve NVS and bootloader. Record source SHA, artifact SHA256 and observations in the issue/PR. No merge or release tag is authorized by this prototype request.
