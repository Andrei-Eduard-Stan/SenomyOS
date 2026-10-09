# OSK shared Caps Lock, movement and native toggling — 2026-10-09

User requested shared keyboard state (specifically alternating Caps Lock), a
repair for Super+Ctrl+K hiding, and fluid keyboard movement with work-area updates.
The user reports basic OSK typing/navigation work and defers network/audio/UI
refinement. This is partial physical acceptance, not a released OS claim.

## Implementation and boundaries

- Owned shortcut toggling uses wvkbd's Linux SIGRTMIN. The provider chooses from
  its real hidden/mapped state; shell geometry telemetry is not the authority.
  Existing explicit show/hide and confirmed stop remain available.
- A wide top-centre grip moves the keyboard; top away from the grip and side/
  corner handles resize it. All layouts recalculate key coordinates. Position
  and size survive hide/show in the current provider session.
- Movement stays within the output and leaves at least 30% of its work height
  usable above the keyboard. Bottom reservation extends to the keyboard's top.
  This is a rectangular strip: no claim that tiled apps wrap around its sides,
  that floating/fullscreen apps rearrange, or that app contents are controlled.
- A locally compiled Hyprland component shares the **Caps Lock locked state**
  between connected physical keyboards and wvkbd. It preserves other locked
  bits and depressed/latched modifiers. It uses modifier listeners and device
  membership reconciliation, never a key-event listener or arbitrary key logger.
- OSK Caps clicks become a fixed Caps-toggle IPC action. Compositor state returns
  over its event socket and fixed `caps:0/1` native stdin frames. No input-method
  keyboard grab, credential/input-text collection or polling subprocess loop.
- The component refuses an SDK/runtime commit mismatch. Confirmed OSK startup
  can load only the fixed local component after checking its build receipt,
  running compositor commit and binary hash. Missing/mismatched components keep
  ordinary manual OSK operation and expose unavailable shared-Caps status.
  Rebuild after a Hyprland update; automatic rebuild/install is not implemented.
- Physical Shift/Ctrl/Alt keycap highlighting, Num Lock UI and cross-compositor
  integration are not added or claimed. Held modifier combination remains the
  compositor's existing responsibility. Caps support is Linux/Hyprland specific.

## Evidence

- 9 capability Python tests, 13 provider Python tests, 18 Qt controller tests,
  actual adapter/UI fake fixture, 4 Caps IPC/schema/receipt/owned-parent-death boundary tests pass.
- Disposable managed C-stub lifecycle/readiness, show/hide, confirmed exit,
  source-reload cleanup and shell-exit cleanup pass. No user process is a target.
- Actual native keyboard in a private nested compositor: grip movement, side
  resizing, horizontal movement, changing compositor reservation and four
  native visibility toggles pass. Same provider process, no resize restart.
- Clicking the actual Special-layout CpL button set both compositor keyboard
  states on. A Caps key sent **only to the PID-checked, test-owned nested Wayland
  window** cleared both states through the nested physical-input path. Reverse
  physical-on/OSK-off sequence also passed. This is stronger than a fake
  controller test, but does not replace physical laptop-keyboard acceptance.
- Actual managed Quickshell/native integration passed startup, shared-Caps
  handshake, four repeated visibility toggles, same-child ownership and confirmed
  cleanup. No synthetic key was sent to a user's editor/browser.
- Ten Control routes passed the existing wide/constrained focus fixture.
- Native build and Caps component build succeeded; no compiler warnings in the
  extension build. Existing Qt fixture warnings are not reported as warning-free.
- An early nested launch failed because its parent Wayland socket was relative;
  corrected to an absolute parent socket before all accepted native results.
  Intermediate assertion/IPC syntax failures were corrected before publication.

Fixture files are dated execution records, requiring the prepared private
runtime, native build, driver and test-owned compositor. They are not standalone
scripts to run against a live user desktop. No compositor hook/trampoline or
privileged/root installation is used. Parent keyboard input was routed only to
the verified test window using the compositor's Lua send_shortcut API.

## Next attended checks

On the physical desktop, test Super+Ctrl+K with Caps off and on, alternate CpL and
physical Caps Lock while typing a test word, then move/resize and verify ordinary
tiled-window focus. Physical touch, rotation, multi-output, fractional scale,
resource/soak and lock/suspend acceptance remain open. Broad mobile support and
premium/release readiness are not established by this feature checkpoint.

## Live publication check

Published on 2026-10-09. Quickshell reloaded successfully in PID 1335 and remains
active/running, with the existing stackAfter warning and no Hyprland config
errors. The revised owned native provider negotiated shared-Caps mode; the local
component reports available=true. Direct execution of the bound shortcut helper
passed hide/show/hide with the same owned child, leaving the keyboard hidden.
This verifies the command path, not a physical Super+Ctrl+K keypress. No typing,
real Caps toggle, network/audio action, compositor config edit or service restart
was performed during live checks. The test-owned nested compositor was closed.
The installed binary/receipt and preserved before binary are recorded separately;
this source checkpoint does not turn the pre-existing dirty tree into a clean
checkout release artifact. The existing tracked/live Lua lid-binding difference
is preserved, with no Hyprland file changes in this stage.

Resizable fallback mode also sends Caps as a locked modifier, preserving shortcut
modifier matching when the optional shared-Caps component is unavailable. The
last native rebuild changed only that fallback condition; active shared mode
uses the same tested locked-modifier path. A final source reload and start activated
the rebuilt image and parent-death-protected bridge. After readiness, live
show/hide passed and the keyboard was left hidden. An intermediate live test
tried to toggle before readiness and correctly received a busy rejection.

The event bridge also arms Linux parent-death SIGTERM, so abrupt shell death
cannot leave an idle orphan listener. Its lifetime test signals only a
disposable Python owner and observes its disposable child exit.
