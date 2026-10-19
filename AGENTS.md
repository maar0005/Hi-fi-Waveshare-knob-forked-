# HiPhi ESP Firmware Agent Guide

## Open Horizons Framework

**The shift:** Action is cheap. Knowing what to do is scarce.

**The sequence:** aim → problem-space → problem-statement → solution-space → execute → ship

Use the installed skill that matches the altitude of the work:

- Cannot explain the intended behavior change → `/aim`
- Repeated blockers or accumulating patches → `/problem-space`
- Solutions feel forced or the framing may be wrong → `/problem-statement`
- About to choose an implementation → `/solution-space`
- Ready to implement a clear approach → `/execute`
- Code is complete and needs to reach a testable user artifact → `/ship`

Reflection skills are available at every phase:

- `/review` checks alignment and detects drift.
- `/dissent` actively seeks contrary evidence before consequential decisions.
- `/salvage` preserves learning before restarting or reintroducing prior work.
- `/distill` curates reusable metis and guardrails across sessions.

Enter at the altitude the work needs. Move back up when evidence invalidates the
current framing.

## Delivery Workflow

GitHub Issues is the source of truth for tasks. Do not maintain parallel task
databases or Markdown TODO lists.

1. Run `gh issue list` and inspect dependencies before starting.
2. Claim or create the correct issue; use task lists on program/epic issues.
3. For significant program work, follow `solution-space → execute → ship`.
4. Run `/review` and `/dissent` at each phase boundary. Post both reports to the
   PR with the issue number, phase, exact commit SHA, decision, evidence, and any
   remaining blockers so the output contract is auditable.
5. Keep PRs draft until their required hardware artifact is available and tested.
6. Never merge a PR or create/push a release tag without explicit user approval.

## Project Context

### Purpose

This repository is a fork of the **HiPhi ESP firmware family** that builds only
the **HiPhi Dial** on the Waveshare ESP32-S3-Knob-Touch-LCD-1.8, plus the
parking image for that board's second ESP32. The other HiPhi controllers were
removed and remain upstream. It turns that knob into an approachable, dedicated
hi-fi controller that can also dim Home Assistant lights. A controller should let someone perform routine listening without
opening a general-purpose screen: see what is playing and control transport,
volume, zones, playlists, and programs. Sources are Roon, Lyrion Music Server
(LMS), and OpenHome/UPnP, reached through the
[Unified Hi-Fi Control](https://github.com/open-horizon-labs/unified-hifi-control)
bridge. The brand is **HiPhi by Open Horizon Labs**; the public site is
[hiphi.audio](https://hiphi.audio/). This fork has no web flasher; its
firmware is published as GitHub Release assets.

### Targets

Every change should name the targets it touches.

| Target dir | Slug | Product name | Hardware |
|---|---|---|---|
| `idf_app` | `hiphi-dial` | HiPhi Dial | Waveshare ESP32-S3-Knob-Touch-LCD-1.8 |
| `knob_aux_app` | n/a | Dial auxiliary parking image | Waveshare knob, second ESP32 |

Slugs are device identity. Changing one costs testers a re-provision, so treat
them as fixed. Wire-contract strings (`_roonknob`, `X-Knob-Version`, `knob_id`,
`knob_name`, `rk_cfg`, and the `roon_knob*.bin` release aliases) are
deliberately retained for compatibility and are enforced by
`scripts/check_dial_identity.py` with `scripts/dial_identity_exceptions.json`.
Run that script before opening a PR that touches identity, naming, or docs.

### Licensing

The firmware is under the PolyForm Noncommercial License 1.0.0, copyright
Open Horizon Labs: free for individuals on their own systems, commercial
license required for installers, integrators, dealers, and paid or hosted
services. New **shared** source files should carry:

```c
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
```

Do not mass-edit existing files to add headers.

### Current Aims

- Factor a shared controller core for playback state, commands, configuration,
  connectivity, and recovery, cleanly decoupled from displays and physical input.
- Drive adaptive UI from server-provided control payloads.
- Control Home Assistant lights directly from the Dial (implemented over Home
  Assistant's REST API; see `docs/usage/HOME_ASSISTANT_LIGHTS.md`).
- Keep BLE HID media-remote pairing working on the Dial.
- Library browsing, including Roon playlists, through the bridge's collections API.

### Key Constraints

- Preserve the proven BLE HID behavior. `origin/v4` is a salvage/reference
  source and the known-working Dial build profile, not a wholesale merge target.
- Hardware claims must be tied to an exact target/revision. Do not infer flash,
  PSRAM, display, touch, power, or pin capabilities from a product-family name.
- Device-specific UI and input drivers may be compile-time inclusions; playback,
  connectivity, configuration, and recovery semantics belong in shared code.
- A green compile or configuration gate is not a working firmware artifact.
  Shipping requires the exact CI artifact to pass flash, sustained boot, and
  relevant display/input/connectivity checks on physical hardware.
- CI release builds must use an optimized, evidence-backed configuration. The
  recovery baseline carries v4's non-debug build settings onto master (PERF
  optimization and a 16 MB merged image). The v2.5.2 Dial artifact establishes
  ESP-IDF 5.5.5 as hardware-proven for Dial; each new Dial artifact still
  requires exact-artifact hardware evidence.
- This is a side project: prefer incremental factoring with shippable slices over
  an unbounded rewrite.

### Patterns to Follow

- Put target differences behind narrow platform/display/input interfaces.
- Represent target capabilities explicitly and fail safely on unknown hardware.
- Salvage behavior and learning from prior branches; direct code reuse is optional.
- Record decisions and hardware evidence in the relevant GitHub issue/PR and ADR.
- Keep documentation aligned with the effective build and the artifact users test.

### Anti-Patterns to Avoid

- Cloning the application per board.
- Coupling playback/source behavior directly to LVGL widgets or a display shape.
- Treating all ESP32-family boards as interchangeable.
- Calling an artifact fixed before an exact-SHA physical test.
- Replacing a known-working full build profile with isolated guessed settings.

### Decision Context

The maintainer approves architecture, merge, and release decisions. “Done” means
the scoped issue is implemented, review/dissent output contracts are posted,
automated checks pass, and any required exact-artifact hardware validation is
recorded.
