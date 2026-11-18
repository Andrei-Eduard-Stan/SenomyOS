---
title: Contextual Panels
category: Shell
category_order: 20
order: 10
summary: One primary workspace, one quick popover and protected review/navigation.
---

# Contextual panels

Control Centre, Performance and Senomy Insights are the three primary experiences.
Only one is active. Compact Control Centre and full resizable Settings share the
same pages, search, services and unsaved-draft guards.

One quick popover may stay open alongside a primary. Click its trigger again to
close it, or another quick control to switch directly. Opening/focusing a primary
dismisses the quick popover. Pending reviews and unsaved forms remain protected;
use their explicit Cancel, Keep or Discard controls. Escape dismisses the innermost
available overlay first. Every surface has a visible close action.

For read-only shell health use `senomy-shell status` or `senomy-shell doctor`.
Continue to [[control-centre|Control Centre]] or [[recovery|Shell recovery]].


## Fullscreen shortcuts

- Super + F toggles fullscreen, including the application's fullscreen mode.
- Super + Shift + F toggles immersive mode: fill the display while keeping the
  application's normal menus, tabs and toolbars.

Press the other shortcut to switch modes directly. Press the current mode's
shortcut again to restore the window's earlier normal or maximized state.
Each window keeps its own restore state, including after moving between displays.
Only the display containing a visible fullscreen window yields its Rail;
maximized windows keep the Rail. These shortcuts use the supported Hyprland Lua
configuration and verify the exact target window's resulting state.
