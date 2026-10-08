# Populated focus validation — 2026-10-08

Original source: failed Network focus clipped inside ListView at y=333.
Repaired source: `python3 scripts/validate-control-routes.py` passes.
24 Wi-Fi, 24 Bluetooth and 32 audio endpoints are reached by Tab in both
1120x820 and 720x500 hosts. Every clipped ancestor contains focused controls.
Pending previews and all ten routes also load; fake mutations remain zero.
Compositor host is substituted. Physical pointer/touch/session acceptance stays open.
Targeted qmllint exits zero with existing warning categories.

Device controls use finite-provider Repeaters, retaining all rows in Tab order.
Nested scrolling reveals inner controls before placing the outer page.
Existing visual layout is unchanged; large-inventory resource measurement remains open.

Live publication initially failed because the watcher ran before the new module
was present. A source refresh after all files were present reports Configuration
Loaded at 13:20:46. Service active, same PID1373; Hyprland configerrors empty.
Existing stackAfter warning remains. No explicit service restart or device action.
