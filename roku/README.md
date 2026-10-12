# HiPhi for Roku

Two developer packages share the same UHC client and artwork renderer: **HiPhi Controller** is an artwork-first foreground controller; **HiPhi Artwork** is a standalone screensaver with full-screen art. This directory lives alongside firmware but changes no ESP build or UHC API. Both packages are experimental and require exact-artifact Roku testing before readiness or unattended-display claims.

## Build

Use Node 24 (minimum 22.12) and Python 3:

```sh
cd roku
npm ci --ignore-scripts
npm run check
npm test
npm run build
```

`dist/hiphi-roku-controller.zip` and `dist/hiphi-roku-screensaver.zip` are reproducible developer ZIPs with root-level manifests, distinct entry points and shared source/assets. `dist/SHA256.txt` identifies their bytes; `BUILDINFO.txt` records source SHA and dirty status. The **Roku clients** Actions workflow validates and uploads both packages, checksums and this guide. A ZIP and desktop test result do not establish working Roku hardware.

## Install on the test Roku TV

Observed October 11, 2026 at `192.168.2.245`: model `G854X`, display name `100012586`, Roku TV, OS `15.3.4`, build `2303`. ECP device information reports developer mode **disabled**; the developer web installer is not listening. This read-only observation did not change settings or install an app.

1. On the Roku remote press **Home three times, Up twice, Right, Left, Right, Left, Right**. Enable the Development Application Installer, accept Roku's developer terms, set its password and allow the reboot. Developer-program enrollment may be required. Do not put passwords in Git, screenshots or issue comments.
2. Open `http://192.168.2.245/` in a browser on the reachable LAN. Use username `rokudev` and the password you just set. Upload **one** of the ZIPs. Roku only supports one sideloaded app at a time: loading the other replaces the first. These packages cannot coexist as two sideloads on this TV. Broader distribution is a separate decision; beta distribution has its own 20-user/120-day limits.
3. For **Controller**, complete first-launch bridge/zone setup. Enter the root bridge URL `http://192.168.1.2:8088`, not `/ui/zones`. Choose **Pin listening zone**, select the intended listening room, then **Done**.
4. For **Artwork screensaver**, open Roku **Settings → Theme → Screensavers**, select **HiPhi Artwork**, then **Change screensaver settings**. Configure the same bridge and desired zone there, return to the screensaver menu, select it and Preview it. It does not prompt for input while running. If unconfigured, its bottom notice tells you to choose a bridge and zone.

The **Pin listening zone** setting persists the exact zone ID. It is the only place to change the listening zone; transient controls do not cycle rooms. A removed pinned zone fails closed and requires explicit repinning. Each package uses its own registry section (`hiphi-controller` / `hiphi-screensaver`). Bridge entry accepts a host/IP such as `192.168.1.2`; omitted scheme defaults to HTTP and omitted port defaults to 8088. Explicit ports and HTTPS are preserved. Configure both independently; they do not share live process objects or silently borrow a listening zone. Settings persistence while replacing sideloads must be checked on the actual TV and developer identity. They share implementation, not assumed installation state.

The Mac can reach the Roku, but that does not prove the Roku can reach `192.168.1.2:8088`. Verify that path through successful in-app zone/art loading; accommodate subnet/VLAN routing if necessary. The LAN API remains the existing trusted-network UHC endpoint; HTTPS uses Roku's CA bundle with certificate validation.

## Artwork and controls

Controller launches with almost all art: 1920×1044 artwork in an FHD design space plus a 36-pixel metadata/connectivity strip. The control overlay occupies no permanent art space. OK or an arrow reveals it; arrows select an action and OK activates it. Controls disappear after 20 seconds without interaction. Back hides controls, then leaves the app; Home remains Roku OS behavior. Options opens bridge/zone settings. Play toggles; PlayOnly plays; rewind/fast-forward request previous/next when allowed. Held-key repeats are ignored. Zone volume is available through the overlay; physical TV volume buttons are not claimed to control UHC.

**Library is temporary:** reveal the controls, choose Library, then select Browse, Playlists, Radio or Favorites only when the pinned zone publishes that tab. Use Up/Down and OK for the native list; Back returns to the preceding page and restores selection. “More results” advances the 20-item page. Options inside Library returns to its menu; leave Library to use Options for bridge/pin settings. Opening Library again resumes the previous page with fresh references. No library panel remains on the resting artwork screen.

Folders open directly. A playable item opens a small action list whose initial selection is **Back to list**, so held OK cannot immediately start playback. Items with both folder and playback references also offer **Open**. Deliberately choose **Play in pinned room** or **Add to queue**. Play acceptance returns to artwork; it is acknowledged as a request, with fresh now-playing reads establishing the actual result. Server refusals, expired references and uncertain timeouts show recovery choices without replaying the command. Refresh the list, select the item again and deliberately retry only after checking playback. Search uses Roku’s standard keyboard and always names the pinned provider. UHC’s `/api/search` currently has no paging arguments; its returned search list is shown as supplied.

Within the supported Library providers (Roon, LMS and Music Assistant), **Current queue** is offered only for Music Assistant. Roon/LMS can accept Add to queue through playable references but their unified queue-reading endpoint is not implemented. Current queue is a read-only server snapshot, bounded by the provider’s existing read limit; no guessed jump/remove/reorder controls are exposed. Provider refusals remain authoritative.

Screensaver requests 1920×1080 artwork, with no reserved strip or controller overlay. Healthy playback shows only artwork. A temporary bottom notice reports missing setup, connection loss or an artwork error. Any remote input exits the screensaver as required by Roku. The settings entry point is interactive; the screensaver entry point is read-only.

SceneGraph scales the FHD design for HD displays; this is not a 4K UI or arbitrary portrait-rotation implementation. UHC's viewport image endpoint supplies the crop, including Zensally on the current bridge. The Poster uses aspect-preserving fit, so Roku does not cut out a face with a second centered zoom. At most a displayed image and its pending replacement are kept. Delayed responses cannot replace a newer zone/session image; a room change clears the previous room's art immediately. Track changes in the same room keep the old cover until the new image is ready. The server's `k` parameter is a cache-buster, not an archival cover selector.

## State, recovery and commands

Shared BrightScript Model and BridgeTask code consume `/zones`, `/now_playing?zone_id=…`, `/events`, `/now_playing/image` and POST `/control` with `{zone_id, action}`. Initial/fresh HTTP snapshots are authoritative. A missing saved zone is retained as a missing selection; the client never redirects commands to the first available room.

**OS 15.3 test TV uses polling:** selected now-playing snapshots every two seconds while healthy and zone reconciliation every 30 seconds. Errors back off up to 60 seconds; individual JSON/command transfers time out after eight seconds. JSON responses over 1 MiB are rejected after transfer; this is not a hard network-buffer memory cap. **OS 16+ additionally uses native SSE** as invalidation, with 30-second snapshot reconciliation while events flow and polling restored after stream failure. Failed/disconnected SSE connections retry with bounded backoff and server retry guidance. The OS 16 streaming API is never called on the OS 15 fallback path. Event replay is not treated as complete state history.

Only one command can be pending. The background dispatcher checks selected session/zone, snapshot freshness, published capabilities, fixed/unknown/missing volume and the read-only profile. An accepted HTTP reply triggers a fresh read; a timeout/error has an uncertain outcome and is never replayed automatically. Reconciliation is required before further commands. A command with a stale snapshot requests refresh and must be deliberately tried again. Do not send commands from the screensaver settings or renderer.

## Exact-artifact acceptance

Record the Actions run, Git SHA, ZIP SHA-256, model, full OS/build and remote type in issue #273/its PR. Do not check the hardware acceptance box based on desktop tests.

- Controller: setup, explicit zone selection, artwork-first launch, focus navigation, capabilities, transport, volume and 20-second hide. Check actual room affected, held buttons, Back, Home and TV volume. Controls must remain usable when the TV screen reader is enabled; automatic hiding/accessibility behavior needs physical qualification.
- Artwork: choose it through screensaver settings, configure its independent selection, preview, wait for actual automatic idle entry, verify art fills the entire frame and remote input exits rather than sending commands.
- Use the Crown face example, wide and tall covers and a no-face cover. Confirm the server crop survives Roku presentation. Change the track while an image is delayed; change rooms while requests are delayed; stale room responses must not overwrite current art or command selection.
- Stop/restart UHC and interrupt the network while art is visible. The client must show disconnected state, recover without setup loss and refresh actual playback. Test unavailable/removed saved zones and fixed volume. A command interrupted on the wire must not be retried; verify actual music state.
- Leave both packages, separately installed, without input for at least two hours beyond the configured idle timers. Record system screensaver takeover for the controller, screensaver updates, TV sleep/power settings, memory symptoms, TV off/on and relaunch/settings persistence. We do not synthesize input or fake media playback to suppress system lifecycle.
- Test OS 16 SSE on actual OS 16 hardware before claiming that path qualified; this OS 15.3 TV validates the polling path only. A desktop mocked stream verifies dispatch/recovery logic, not Roku's native networking implementation.

## Architecture and tooling boundaries

The controller adds only its manifest, entry point and input/overlay component. The screensaver adds only its manifest and two entry points; it has no ControllerScene. Shared settings UI runs in a distinct settings entry point; shared networking denies all screensaver commands even if a command request is injected. Artwork models and provider SDKs stay on UHC.

The current manifests use `rsg_version=1.2` for the OS 15 personal sideload trial. Roku's current certification rules require 1.3 for publication; public-store release must deliberately migrate/qualify that observer model. No publication or certification approval is implied.

Pinned desktop compiler/interpreter dependencies are development-only and never enter the Roku ZIP. Patched archive/URI/UUID dependencies are overridden in the lockfile. npm audit still reports high-severity glob-pattern issues through the current compiler/interpreter stack; checks use fixed repository globs and local source only, not untrusted patterns or archives. Do not expose these developer tools as an upload service. This limitation is recorded rather than hidden by an audit suppression.

Sources: [developer setup](https://developer.roku.com/dev/docs/developer-setup), [screensaver constraints](https://developer.roku.com/dev/docs/screensavers), [native SSE](https://developer.roku.com/dev/docs/ifurltransfer), [Poster](https://developer.roku.com/dev/docs/poster), [remote keys](https://developer.roku.com/dev/docs/onkeyevent), [manifest](https://developer.roku.com/dev/docs/channel-manifest), [resolution scaling](https://developer.roku.com/dev/docs/specifying-display-resolution). Artwork models are not distributed in these packages. Software follows the repository license.

Library contract, risk-retirement evidence and exact-artifact test procedure: [LIBRARY.md](LIBRARY.md).
