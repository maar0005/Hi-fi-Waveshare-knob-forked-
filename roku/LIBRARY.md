# Roku Library execution — #274

## Aim and scope

Use the remote to browse real provider content, deliberately play or queue an item in the pinned room, and return to artwork. This extends the shared baseline in #273 / PR #275. Existing Pin listening zone settings remain the only way to change rooms. The controller has no new persistent artwork chrome; the screensaver contains no LibraryPanel and still refuses library requests and mutations. No UHC provider integrations, backend routes, ESP firmware or public-store publication are added.

## Contract and provider evidence

The UHC beta4 source examined is `172e934efa70447e5388f0324a5e819278e23852`, specifically `src/api/browse.rs`, `src/mcp/tools/collections.rs`, `src/mcp/tools/library.rs`, `src/mcp/tools/queue.rs`, and `src/app/api.rs`. HTTP200 is only transport success; the JSON envelope carries outcome, scope and refusal. Roon/LMS/Music Assistant collection routes are implemented; other provider libraries remain unavailable through this surface. The controller trusts published browse_supported/library_tabs rather than inventing tabs for older/unknown bridges.

Collections use POST `/api/collections` with exact zone_id, action, limit=20, offset and optional opaque location. Root Radio is favorites/media_type=radio, root Favorites is favorites/media_type=tracks; folders use browse/location regardless of root tab. Navigation uses durable locations, not short-lived paths. Rows may be navigable, playable or both. POST `/api/search` uses query and exact pinned zone. POST `/api/play_ref` uses the current result’s opaque ref, exact zone_id and play/queue. Queue reads use POST `/api/queue` action=read only for Music Assistant within this provider slice; Roon/LMS unified queue reads are not implemented. Search is not paged by this endpoint. Current queue shows the server’s bounded snapshot and does not edit entries.

Read-only installed-bridge checks on October 11, 2026 confirmed published Roon tabs Browse/Playlists/Radio; its browse root contains Local Library, My Live Radio, Genres, TIDAL and Qobuz. Opening Local Library by its returned location yielded Search, Artists, Albums, Tracks, Composers and Tags, with a Local Library breadcrumb. No Play/queue mutation or TV interaction was sent during development.

## Preservation and success criteria

- Preserve independent exact room pins and clearing the pin on bridge change, artwork dimensions/crop behavior, readonly screensaver, existing transport controls and OS15 polling/OS16 SSE reconciliation.
- Deliver genuine hierarchy navigation, paging and Back/focus restoration; native keyboard search; explicit item Play/Add to queue; current queue only where the existing unified endpoint is implemented.
- Keep late request/session/zone responses, missing pins, unknown references, malformed pages and HTTP200 refusals from producing misleading results or unintended playback.
- Produce reproducible developer ZIPs in CI and keep the PR draft until exact-artifact remote/display/network tests on Roku pass.

## Verification

`npm run check` stages and compiles both packages. `npm test` runs production BrightScript with injected transports/SceneGraph primitives: 79 existing client/settings/network assertions, 47 Library model/Task assertions, 40 Library UI assertions, 9 artwork callbacks and 19 controller remote assertions (194 total). Package tests check deterministic bytes, separate entry points, absence of the controller/LibraryPanel from the screensaver, server crop preservation and no render-thread HTTP calls. The malformed-JSON client fixture intentionally emits a ParseJSON diagnostic; test failures still exit nonzero.

These mocks verify client logic, not Roku-native rendering, focus propagation, held remote events, OS keyboard/dialog behavior or physical playback. The initial physical controller settings screenshot showed its raw internal pinned ID clipped to an ellipsis despite a successful fresh playback snapshot; shared settings now show Connected and the room name, with smaller type and sufficient height. The same fix accepts bare host/IP addresses and defaults to HTTP/port 8088, retaining explicit ports/HTTPS. Current refinements add deterministic focus after screen activation, keyboard Back/dismissal focus restoration, direct Up-to-Library access, visible compact controls, human room/action copy, actionable empty/loading states, wrapped heading/recovery text and interruptible art/control transitions. Production-code tests exercise loading returns, keyboard dismissal, empty search recovery, queue-heading restoration, pending-action Back, held arrow navigation and transition interruption. Library runtime screenshots remain unavailable; source layout inherits the baseline dark artwork/control palette and native LabelList. Official primitives: [LabelList](https://developer.roku.com/dev/docs/labellist), [StandardKeyboardDialog](https://developer.roku.com/dev/docs/standard-keyboard-dialog), [getScene](https://developer.roku.com/dev/docs/ifsgnodechildren). Firmware checks are unrelated to these Roku changes.

## Risk retirement

| Risk / stop trigger | Status | Tempting wrong patch that must fail | Evidence |
|---|---|---|---|
| Late page in the same room replaces newer results | Retired by evidence | Guard room only | Task generation and monotonic input tests; UI request-ID callback test |
| Room/bridge changes leak references or search submissions | Retired by evidence | Retain cached rows or open keyboard across room changes | Session/zone checks at both boundaries; cancellation/reset; search dialog dismissal and stale submission tests |
| Missing pin sends commands to another room | Retired by evidence | Select first available room | Existing pin/network tests and removed-room Library response/UI tests |
| HTTP200 means successful playback | Retired by evidence | Treat any 2xx as Playing | Refusal detail and accepted-with-uncertainty tests; snapshots reconcile actual state |
| Expired refs silently play a title match | Retired by evidence | Re-search and auto-retry Play | Ref list cleared, explicit Refresh, no mutation replay tests |
| Mutation timeout or repeated remote selection doubles playback | Retired by evidence | Retry a POST or unlock at HTTP acceptance | Shared pending/uncertain lock, timeout cancellation and UI busy tests; action chooser defaults to Back |
| Back/paging loses selection or reuses expired references | Retired by evidence | Cache old pages with live refs indefinitely | Descriptor-only bounded history, re-read on Back/reopen, paging/focus tests |
| Folder+playable row is treated as one exclusive kind | Retired by evidence | Check only the first field present | Both handles retained; native action chooser tests Open/Play/Queue |
| Unknown tabs/providers expand into fake categories | Retired by evidence | Default all four tabs or universal queue controls | Published-tab validation, malformed capability tests; MA-only current queue test |
| Full-art/screensaver behavior regresses | Retired by evidence | Put Library in shared screensaver UI | Existing art tests and package boundary checks; readonly library dispatcher tests |
| Useful native focus, text truncation, keyboard, held-key and playback behavior | Accepted with rationale | Claim mocks prove a working Roku | Requires the exact CI ZIP on physical TV; no device was changed while in use |
| Server action metadata/API insufficiency | Not triggered | Invent provider verbs/backend catalog | Existing play/queue and route-specific queue contract suffice; server refusals are displayed |

## Exact-artifact physical procedure

Install the CI controller ZIP on the test TV after developer mode is enabled. Confirm bridge and pinned room persist after exit/relaunch; change the bridge and confirm it requires a new pin. Enter Library, open Local Library → Albums, page forward, Back twice and verify folder/row focus. Search a known artist; open a result with both handles and check Open/Play/Add to queue are distinct. Hold OK while entering a chooser: its initial Back to list choice must prevent immediate Play.

Deliberately Play a known item in the named room and confirm that room’s actual playback and artwork update; Add to queue must not be described as observed success solely from an acknowledgement. Test an unsupported/missing room, bridge restart, an expired item reference, loss of network during a mutation, and interruption during navigation/search. Check that retries require fresh deliberate selection and no action reaches another room. For MA, inspect current queue and compare its visible rows with the server snapshot. Roon/LMS must not show a current-queue entry. Confirm long titles/breadcrumbs and empty/error states on the actual screen and with the audio guide if used. Return to artwork; idle behavior and screensaver remain subject to baseline #273 tests. Record artifact SHA256, source SHA, OS/model and observed results in #274/its PR.

## Review and dissent

Pre-flight review/dissent are recorded in #274. An independent Impeccable source reviewer returned ship at source-review scope with no material blocker; no runtime screenshot or native pixel review was available. The reviewed extension inherits the baseline palette/type and native list/dialog controls; no design-system files were replaced. Completion reports on the draft PR must name its exact source SHA and CI artifact. Native pixel/focus/playback approval remains pending independent physical observations; the source review cannot substitute for it. No merge or release is authorized by execution.
