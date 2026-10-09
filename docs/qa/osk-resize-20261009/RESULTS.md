# OSK shortcut and resizing — 2026-10-09

Super+Ctrl+K calls the shell IPC oskToggle through the fixed senomy-osk wrapper.
It explicitly starts an available owned session child or shows/hides that same
child. Pending reviews/start/stop states reject repeated toggles. It never matches
process names, signals an external PID or stops a provider. UI Start/Stop reviews
remain. Shortcut show/start dismisses current shell surfaces at invocation so the
application can receive text focus; no delayed unrelated route dismissal.

A pinned wvkbd 0.21 patch adds top/side/corner pointer and touch handles, bounded
key-layout resizing and geometry-only telemetry. Real drag testing in a private
nested Wayland compositor exposed lost edge motion. The final transparent surface
captures outside-edge motion only during dragging, and restores the keyboard-only
input region afterward. It retains application focus and does not restart the
keyboard. A screenshot of the private compositor was inspected: keys aligned,
handles visible and unused side/top space transparent. Key popups are disabled in
this extension's managed launch; pressed-key highlighting remains.

Native private fixture passes: top/side/corner resizing, max height clamp,
observed compositor reserved-space changes, hide/re-show session dimensions and
exit releasing reservation. No live typing/device mutation was used in this test.
The recorded native fixture/driver require a separately prepared private nested
runtime and the official wlr-virtual-pointer protocol to compile; they are dated
execution evidence, not a standalone unattended live-desktop test. Protocol:
https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-virtual-pointer-unstable-v1.xml

Source checks: 9 capability Python cases, 13 launch/readiness Python cases,
18 Qt controller cases, actual adapter guards including malformed/stale geometry,
actual managed C-stub lifecycle/reload/exit cleanup, 2 resize/shortcut cases and
actual ten Control routes at wide/constrained sizes all pass. Rebuilt through the
public pinned-source helper; no new compiler warnings. Both tracked/live Lua parse
with Hyprland --verify-config. Bash syntax, observe JSON and whole-tree git
whitespace checks pass. Shell IPC introspection exposes oskToggle.

Warned publication: Quickshell Configuration Loaded 09:52:17, active PID1335;
Hyprland errors empty. Live bind reports modmask68/keyK. Tracked/live Lua retain
their previous lid-binding difference; only the shortcut was added to each.
No service restart or live shortcut activation was used. Existing stackAfter
warning remains. Native phone touch, rotation, fractional scaling and multiple
outputs, subjective smoothness and real application typing after this extension
remain attended acceptance. Tiled apps use a rectangular area above the keyboard;
floating/fullscreen layouts and application contents are not universally reflowed.

Existing dirty/untracked consumers are preserved through zero-context patches and
before/after hashes. Verify hashes before git apply --unidiff-zero. User-local
binary replaced only after matching its recorded original hash; recovery binary
retained in the private development stage. No package DB changes or push.
