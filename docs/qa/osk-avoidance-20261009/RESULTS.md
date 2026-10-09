# OSK rectangle avoidance checkpoint — 2026-10-09

Implemented bottom edge/corner resizing, full-work-area movement, a native
FLOAT/REFIT header control and an Input UI mode control. Super+Ctrl+K remains
the visibility shortcut. Session placement survives hide/show, not restart.

The receipt-checked component is built for Hyprland commit
`efb50993780079460b0cbed1363e2166a2de1d9f`. Geometry IPC accepts bounded numeric
rectangles for the exact managed keyboard PID/layer. It changes client geometry,
keeps tiling targets/membership intact, respects minimum sizes, and restores the
latest compositor layout on float/hide/exit. Floating and fullscreen application
windows are excluded. Clients that cannot fit in any usable rectangle keep their
size; no impossible space or universal hardware support is claimed. Missing or
incompatible components retain the previous whole-strip reservation fallback.
The new mode button still allows floating without reservation in that fallback.

The mode signal is gated by native support telemetry; ordinary upstream
providers do not receive it. In float mode own Senomy panels use the Top layer
so the native Overlay stays above them, including subsequently opened panels.
Expanded Rail, dashboard and separate Insights wrappers choose the largest useful free region in the
monitor work area. Expanded content scrolls within its bounded frame. Extremely
small areas remain bounded; avoidance cannot be guaranteed when no usable piece
exists. The user screenshot's system/resources/artwork panel is the expanded
Rail panel, separate from primary Senomy Insights.

Validation:
- Pinned native C build and exact-SDK C++ component build passed.
- Native pointer drags in a private nested compositor: left tile retains full
  height with keyboard on right; right tile fits above/below; bottom edge keeps
  top fixed and recomputes key layouts; actual mode button restores/reapplies;
  hide/show and provider exit restore; adding a tile while open preserves the
  updated layout. See native-avoidance-results.log and numeric evidence JSON.
- Actual Quickshell managed native child: owned geometry bridge reaches panel
  state, both modes, shared-Caps handshake, four toggles with same PID and
  confirmed cleanup passed. No typing into user applications.
- Actual expanded/primary PanelWindows stayed within monitor bounds above/below
  synthetic OSK rectangles; constrained expanded content scrolls. The checked-in
  fixture requires SENOMY_PRIVATE_OSK_TEST=1 and a private compositor.
- Existing capability/provider/Caps helper/Qt controller and adapter fixtures,
  managed lifecycle, fixed wrapper/edge geometry, and ten Control Centre routes
  passed. Some existing Qt fixture diagnostics remain; not warning-free.
- Live PID 1335 reloaded; Rail present at 1920x72, y1008; configerrors empty;
  senomy-osk-state reports protocol 1. QQuickItem::stackAfter warnings
  appeared during source reload; configurations loaded without failure.

The large pre-existing dirty/untracked baseline is preserved. Consumer changes
and hashes are recorded beside this report rather than silently committing their
unrelated baseline. A clean-checkout release claim still requires that baseline
to be reviewed and packaged. Installed prior binary/library/receipt recovery
copies remain in the private development checkpoint's installed-before folder.

Attended acceptance remains: VS Code/browser resizing during pointer/touch
movement, narrow/portrait and multi-monitor hardware, real physical Caps Lock
alternation, and user preference for provider/style. These tests do not establish
mobile hardware compatibility or a complete premium OS release.

Final live check: reopened the keyboard through the existing senomy-osk wrapper.
Owned PID 21125 runs resize, shared-Caps and rectangle-avoidance flags; monitor
reservation remains only the 72px Rail, shared-Caps reports available, and the
keyboard is left open for attended testing. No key input was injected into user
applications. Source hashes above match the tested/published revision.
