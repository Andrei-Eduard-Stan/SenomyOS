---
title: Control Centre
category: Shell
category_order: 20
order: 20
summary: Ten stable contextual routes in one 888px desktop panel with guarded actions and truthful states.
---

# Control Centre

The Control Centre is one shared panel. A Rail control opens its matching
route, a different control switches in place, and repeating the active control
closes it. On wide desktops every route uses the same 888 by 700 geometry; the
panel caps and reflows on smaller focused monitors.

## Stable routes

| Route | Current responsibility |
| --- | --- |
| Overview | CPU, memory, network, power, and direct specialist routes |
| Network | NetworkManager state, nearby Wi-Fi, profiles, and guarded connection actions |
| Audio | PipeWire endpoints, levels, mute, and route controls |
| Power | Dual-battery detail, brightness, health, and confirmed TLP profiles |
| Calendar | Local calendar, locale, timezone, and synchronization evidence |
| Input | Hyprland keyboards, pointers, touchscreens, and tablets |
| Devices | Displays, interfaces, audio hardware, batteries, and BlueZ devices |
| Applications | Native tray evidence and managed background applications |
| Appearance | Validated typography, density, accent, and edge preferences |
| Settings | Shell state, recovery routes, Wiki, and GTK inspection |

Appearance intentionally stays separate from Settings so presentation options
can grow without mixing them with recovery and runtime maintenance. Neither
route accepts arbitrary CSS or silently edits privileged system configuration.

Continue to [[panels|Contextual panels]] or [[recovery|Shell recovery]].
