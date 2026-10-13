# Roku execution and review evidence

Issue: [#273](https://github.com/muness/roon-knob/issues/273). Library follow-up: [#274](https://github.com/muness/roon-knob/issues/274). Exact source SHA, Actions run and hardware disposition are recorded on the PR; this document describes the evidence and boundaries, not a parallel task database.

## Decision and scope

The user selected both native foreground controller and standalone screensaver, sharing most implementation and reclaiming control space in the screensaver. The implementation uses two manifests/entry points with shared Model, BridgeTask, ArtScene and settings. No firmware files, target profiles, UHC route/schema, model distribution, direct provider SDK, publication, tag or merge changes are included.

The scope is a testable Roku artifact and draft PR. Intended device behavior is artwork-first listening, explicit pinned room, remote controls on demand and full-art passive screensaver. It remains unqualified until exact-artifact physical testing. Installation/lifecycle failure triggers a return to solution-space, rather than synthetic input, fake audio/video or a new server renderer.

## Review and dissent: solution boundary

Review decision: **Continue with user-selected two-package scope.** It directly covers interactive control and automatic passive display without cloning networking or provider logic. Screensaver input cannot be used as controls: Roku terminates it on input and prohibits bundled utility/screensaver publication. The packages share code but do not assume shared live state or settings.

Dissent decision: **Adjust delivery expectations.** Functional failure could be idle takeover or blocked LAN traffic; adoption failure could be manual sideload/launch burden; opportunity cost could be maintaining an additional client when Android already works. One developer slot prevents testing both simultaneously by sideload. OS 15.3 cannot use the OS 16 SSE API. These constraints are reflected in packaging, fallback checks and instructions; they are not disguised as a completed unattended kiosk.

## Verification

| Check | Result | What it establishes |
|---|---|---|
| BrighterScript 0.73.6 validation of both staged packages | Passed | BrightScript syntax, SceneGraph component inheritance and references |
| BrightScript client/network/settings assertions | 67 passed | Capabilities, malformed payloads, pinned-zone/session guard, read-only dispatcher, one POST, uncertain outcome, timeout, cancellation, fresh reconciliation, polling/SSE gating and reconnect |
| Production artwork callback assertions | 7 passed | Delayed/wrong-session image callbacks rejected, old poster released on swap, failed loads retry, missing-zone cleanup |
| Production remote-handler assertions | 13 passed | Reveal before activation, key-repeat rejection, selection token, navigation, Options, Back, reserved Home/TV volume, return-to-art callback |
| Package checks | Passed | Reproducible bytes, manifests/icons, separate entry points, no ControllerScene in screensaver, full-height art, no render-thread roUrlTransfer, no second centered crop, pin setting and no test/tooling files |
| Impeccable scoped pass | Source inspection completed; mechanical detector returned [] | Full-art layout, compact selected-action overlay, clear disabled/empty/recovery states; detector does not validate Roku rendering |
| Roku ECP read-only device-info | Observed G854X / 100012586, OS 15.3.4 build 2303, TV true, developer false | Exact test target and OS 15 polling requirement; not app installation or LAN reachability from Roku |
| Developer installer probe | Port 80 not listening | User must enable developer mode on the TV before installation |
| Physical scene/remote/idle/crop/network/registry tests | Pending | No actual Roku execution, screen capture, installation, long-session or screen-reader evidence is claimed |

The malformed-JSON rejection test deliberately emits the interpreter's ParseJSON error diagnostic; all assertions and the test command succeed. Compiler/interpreter tests execute production BrightScript with mocked transfer/registry/scene objects where Roku-only APIs are unavailable. This verifies application logic, not native HTTP/SSE/SceneGraph behavior on hardware.

## Risk retirement gate

| Risk or alternate frame | Status | Tempting wrong patch rejected | Evidence or boundary |
|---|---|---|---|
| Sideload + LAN access on exact TV | Accepted with rationale | A mockup presented as compatibility | ECP target known but developer mode disabled; exact ZIP installation and Roku→UHC path require physical configuration/testing |
| Native SSE everywhere | Retired by evidence for dispatcher; native operation pending | Call OS 16 methods on OS 15 or buffer an endless stream into a string | OS gate, failed start/disconnect/backoff/server retry and stale-event tests; OS 15 polling interval checked; OS 16 native behavior needs OS 16 hardware |
| Late zone/session results affect commands or artwork | Retired by evidence | Refresh more often without identity guards | Delayed/mismatched/missing-zone snapshot, queued input token and image generation tests |
| Commands repeat or report false success | Retired by evidence | Retry POST after timeout or unlock on HTTP acceptance | One pending POST, timeout cancellation, no replay, stale GET cancellation and fresh-state reconciliation tests |
| Fixed, missing or malformed controls remain active | Retired by evidence | Optimistically assume capabilities or volume | Strict Boolean capability and known volume type tests; current selected action shows unavailable state |
| Screensaver accidentally sends commands | Retired by evidence | Hide controls while leaving a live dispatcher | Read-only profile enforced by AllowsCommand and actual dispatch test; no controller component in screensaver ZIP |
| Crop loses subjects on client | Retired by evidence for client policy; visual target test pending | Center-zoom the server-composed result again | Aspect-preserving fit and viewport package checks; delayed image tests; Crown/native Poster appearance still needs TV observation |
| Full-screen passive display wastes strip space | Retired by evidence | Reuse the controller's reserved metadata height | ArtViewport tests give saver 1080 / controller 1044 and saver base uses read-only mode |
| Pins silently move between rooms or packages | Retired by evidence for logic; native persistence pending | Default to first zone or reuse a single profile | Removed-zone and separate registry-flush assertions; native registry persistence across sideload replacement requires TV evidence |
| Idle/power/remote/accessibility behavior | Accepted with rationale | Fake playback/input to claim kiosk support | Target-only behavior requires two-hour idle, remote, TV power and screen-reader tests. No such workaround exists in this implementation |
| Screensaver alone / rendered video / Android alternative | Accepted with rationale | Expand first slice into a stream encoder | User selected two native modes; alternatives remain pivots if lifecycle/network evidence invalidates this approach |
| Maintenance and distribution | Accepted with rationale | Copy the client or imply indefinite beta distribution | Shared runtime source, distinct tiny entry points, one-slot instructions; public distribution deferred |
| Developer-tool dependency advisories | Accepted with rationale | Suppress audit or ship npm packages onto Roku | Archive/URI/UUID dependencies patched; remaining high glob advisories operate on trusted fixed local paths, with no npm tooling in ZIPs |

## Review and dissent: execution boundary

Review decision: **Continue to draft PR/artifacts.** Scope remains aligned; common code owns state/network/recovery/art and profile boundaries own controls/layout. Automated checks retire model-checkable failure cases. Actual visual/runtime, lifecycle and accessibility claims remain explicit hardware gates. Firmware diff is empty.

Dissent decision: **Proceed with qualification pending.** The strongest surviving argument is direct reuse of UHC's state/image/command contracts with no provider duplication or model cost on Roku. The weakest assumption remains useful unattended operation. OS 15 fallback is exercised, but neither SSE nor mocked SceneGraph tests substitute for exact-device observations. Broader library browsing is separately planned in #274 rather than expanded into this first slice.

## Delivery boundary

The delivery path is commit → draft PR → Roku clients CI → two ZIPs/SHA-256/build info/instructions → user developer-mode setup → one package at a time → exact-artifact hardware evidence. PR remains draft per AGENTS.md because hardware evidence is required. No merge/tag/public release has been requested or performed. General firmware CI may run under the existing repository workflow, but no firmware build is necessary to install these Roku apps.
