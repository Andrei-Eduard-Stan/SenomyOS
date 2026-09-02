# SenomyOS Design Matrix

Status: proposal for review; no implementation authorized.

## 1. Surface-level matrix

| Surface | Owner / opens from | Current reference geometry | Interaction level | Frame tier | Motif | Composition strategy | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Obsidian Rail | Eww / always visible | 100% x 64, bottom, exclusive | Level 2 direct shell control | Compact | workspace, identity, telemetry, controls, clock-notification, power | Shared Compact island frame; existing topology retained | Foundation |
| Control Centre | Eww / Rail system controls and deep links | 888x700, bottom-right | Level 2 guarded control | Large | controls, local junction/power | Shared Large shell plus ten bespoke route compositions | P1 |
| Senomy Insights | Eww / identity, notification, companion deep links | 750x700, bottom-centre | Level 1–2 evidence and bounded actions | Large | identity, diagnostic-tick | Shared Large shell plus narrative/ledger/reader compositions | P1 |
| Performance Dashboard | Eww / CPU, MEM, UP telemetry | 1480x760 target, bottom-centre | Level 1 read-only, Level 2 guarded process/benchmark | Large | telemetry, junction, diagnostic-tick | Bespoke Cathedral Deck using shared instruments | P1 |
| Volume flyout | Eww / Rail audio | 350x62, bottom-right | Level 2 bounded audio control | Standard | controls | Shared flyout shell, horizontal channel strip | Pilot |
| Tray overflow | Eww / Rail tray | 260x112, bottom-right | Level 1 native registry/handoff | Standard | controls or junction | Shared flyout shell, vertical app ledger | Pilot |
| Companion expanded | Eww / separate Rail avatar | 330x760, top edge | Level 1–2 ambient/handoff | Standard | identity | Bespoke edge ribbon; one artwork zone | P2 |
| Companion compact | Eww / timed or manual collapse | 300x410, top edge | Level 1 ambient/handoff | Compact outer tab with Standard content plate | identity | Avatar-and-state tab; materially smaller than current | P2 |
| Shared dismiss layer | Eww / coordinator | full work area, transparent | Infrastructure | none | none | Remain invisible; separate any future dim layer | Foundation |
| Command Lens | Rofi / Super+R, app handoffs | 720 wide, y=60 | Level 1 keyboard-first launcher | Standard projection | junction | Bespoke input/results composition in Rasi | P3 |
| SwayNC popup | SwayNC / provider event | 500 wide | Level 1–2 transient native action | Standard projection | clock-notification | Shared notification plate in SwayNC CSS | P3 |
| SwayNC centre | SwayNC client / external provider path | 500x600, top-right | Level 1–2 provider ledger | Standard projection | clock-notification | Bespoke provider ledger; never another primary shell | P3 |
| File Workspace | Thunar GTK 3 / Super+E, Lens, handoffs | normal native window | Level 1 native application | Native Level 1 | optional junction in header | Namespaced GTK tokens plus quiet compositor edge | P3 |
| Other GTK/native utilities | App/tool / bounded handoffs | native | Level 0–2 depending on tool | Native Level 0–1 | none | Minimal native integration; preserve privilege cues | P3 |
| Tiled windows | Hyprland | work-area layout | Native | compositor edge | none | Silver active edge, quiet inactive edge, no heavy shadow | P4 |
| Floating windows | Hyprland | app-owned | Native | compositor edge | none | Slightly stronger shadow/rounding than tiled | P4 |
| Modal dialogs | App/GTK/Qt/polkit | centred/parent-owned | Privileged where applicable | Native Level 0–1 | none | Clear parent dim and focus, no decorative shell frame | P4 |
| Urgent windows | Hyprland/app hint | existing geometry | Native attention | compositor signal | diagnostic-tick equivalent | Static violet local signal; no pulsing full glow | P4 |
| Fullscreen windows | Hyprland/app | output-sized | Native | none | none | Remove borders, gaps, rounding, shadows | P4 |
| SDDM login | QML / pre-session | lower auth rail | Authentication | Large projection + Compact cells | identity, power | Approved bespoke authentication rail | P5 |
| Hyprlock | Hyprlock / guarded lock | lower auth rail | Authentication | Large projection + Compact marks | identity | SDDM-relative composition within Hyprlock limits | P5 |
| Recovery UI | GTK/restricted session | about 700x560 centred | Privileged recovery | Large native projection | diagnostic-tick, identity | One-task recovery composition | P5 |
| GRUB / Plymouth | boot renderers | output-dependent | Boot | token projection only | identity | Shared handoff sequence, not desktop frame reuse | P6 |

Priority key:

- **Foundation:** approve and build before any surface migration.
- **Pilot:** lowest-risk proof of Standard frames and shared state visuals.
- **P1:** core primary surfaces.
- **P2:** companion after primary ownership is stable.
- **P3:** native/toolkit projection.
- **P4:** compositor stage, independently recoverable.
- **P5/P6:** authentication, recovery, and boot after desktop validation.

## 2. Control Centre route matrix

| Route | Data character | Action risk | Primary visual form | Key states |
| --- | --- | --- | --- | --- |
| Overview | mixed live summary | low | connected operational spine | loading, degraded source, nominal |
| Network | topology + inventory | medium/high | route topology + AP ledger + action dock | offline, limited, captive, scanning, saved, unknown, connecting, confirm disconnect/remove |
| Audio | channels + endpoints | medium | duplex audio bus and fader lanes | unavailable, muted, suspended, active, operation pending/failed |
| Power | dual battery + policy | medium/high | paired cells and charge-flow thread | AC/battery, charging/discharging, missing battery, low/critical, confirmation/running/result |
| Calendar | temporal evidence | read-only | calendar field and chronometer | timezone/locale unavailable, synchronization state |
| Input | capability inventory | read-only today | capability matrix/device tree | no device, touch capable, read-only, future action disabled |
| Devices | multi-domain topology | medium/high | device bus with grouped endpoints | unavailable source, scan, pairing, paired, connected, trusted, confirmation |
| Applications | runtime registry | medium | lifecycle ledger | native-only, managed, tray registered, starting, running, stopping, failed, confirmation |
| Appearance | preference manifest | low but persistent | specimen stage and token controls | selected, preview, applying, persisted, failed, legacy palette migration notice |
| Settings | shell/recovery manifest | medium/high | ownership manifest and maintenance dock | ready, unavailable, planned, confirmation, running, success/failure |

## 3. Insights route matrix

| Route | Information mode | Primary visual form | Special constraint |
| --- | --- | --- | --- |
| Briefing | editorial summary | ranked briefing ribbon | must remain a first-class briefing, not a chat surface |
| Notifications | private retained ledger | time-ordered event ledger | bounded retention, private content, redaction/export rules |
| Timeline | sanitized events | vertical source/time rail | never collect keystrokes, file contents, websites, secrets, or unrestricted logs |
| Updates | maintenance discovery | trust-chain/source ledger | manual checks only; never imply install/upgrade happened |
| Diagnostics | allowlisted tasks | runbook with output drawer | fixed commands and arguments; no free-form prompt |
| Console | shell discovery/handoff | curated command strips | no arbitrary embedded shell; real terminal handoff is explicit |
| Reports | bounded artifact builder | evidence docket | profiles declare contents and privacy; never auto-upload |
| Wiki | local Markdown knowledge | index plus reading plane | readable measure, bounded source tree, truthful refresh/errors |

## 4. Performance route matrix

| Route | Main plane | Secondary plane | Guarded state |
| --- | --- | --- | --- |
| Overview | paired machine-heart arcs + 300s thread | platform/power/health rails | diagnostics handoff only |
| CPU + GPU | utilization/frequency/thermal spine | load, threads, scheduler, topology | GPU unavailable and stale-source states |
| Memory | composition river + pressure thread | reclaim/kernel/virtual-memory ledger | none |
| Storage | read/write ribbons + capacity rail | block topology, pressure, health | no privileged health claim without source |
| Network | mirrored duplex streams | route/address/link-integrity topology | sensitive runtime values remain local |
| Processes | sortable process table | selection inspector | confirm and report exact PID/action; graceful termination first |
| Benchmarks | phase timeline + thermal/load thread | comparable result ledger | warning gate, battery/thermal threshold, stop/cooldown/failure |

## 5. Shell-reuse decision

### Can reuse one shared visual shell

- Volume and Tray use one Standard anchored-flyout shell.
- Control Centre and Insights share the Large frame root, header contract, route component, state marks, source lines, and guarded-action components—but not the same content topology.
- SwayNC notification popup and centre share a native Standard token projection, not Eww widget code.
- SDDM and Hyprlock share authentication visual tokens and geometry intent, not renderer implementation.

### Need their own composition inside shared primitives

- Companion expanded/compact: edge-ribbon geometry and artwork ownership.
- Command Lens: input/results/scopes model in Rasi.
- SwayNC centre: provider ledger and DND ownership.
- File Workspace: native file-manager hierarchy and dense tree/list affordances.
- Recovery: one-task privileged form.

### Require bespoke Large topology

- Control Centre: operational switchboard.
- Senomy Insights: briefing/evidence reader.
- Performance Dashboard: Cathedral Deck.
- SDDM/Hyprlock authentication rail and Recovery use bespoke compositions with token projection only.

## 6. Frame and motif rules

1. One dominant motif per frame. Secondary motifs may appear only at a real route/action junction.
2. Never put motifs behind body text, data labels, tables, sliders, or credential fields.
3. Silver defines the structure. Violet indicates a state. A surface should not have a continuously violet perimeter.
4. Use the canonical safe insets from `frame-system.json`; do not approximate them independently in each toolkit.
5. Compact corners never scale up to a Large panel. Large corners never shrink onto a Rail island.
6. Native applications receive a token projection or compositor edge, not a simulated Eww frame pasted inside content.
7. The character asset belongs to the Rail avatar, companion, and approved authentication context. Primary panels use identity marks, not character art.

## 7. Interaction-level rules

| Level | Meaning | Visual treatment |
| --- | --- | --- |
| Level 0 | purely native application behavior | compositor edge and native toolkit tokens only |
| Level 1 | read, navigate, filter, inspect, open safe handoff | silver structure, violet focus/selection, no confirmation theatre |
| Level 2 | changes a device, service, connection, process, profile, or persistent preference | distinct action dock, exact scope, pending/running/result state; confirmation when disruptive |
| Privileged | authentication, password, reboot, shutdown, recovery, elevated operation | native privilege identity, explicit consequence, guarded confirmation, no decorative ambiguity |

## 8. Responsive matrix

| Profile | Rail | Primary navigation | Primary surface | Touch |
| --- | --- | --- | --- | --- |
| Wide desktop | full island chain | persistent vertical/route strip | reference geometries | 40–44px primary targets |
| Standard laptop | full chain with bounded compression | persistent where space permits | 888–1000 Control/Insights, 1480 Performance cap | 40–44px |
| Narrow landscape | priority/overflow islands | horizontal route strip or drawer | near-full width with safe edge gaps | 44–48px |
| Portrait/tablet | two-row or scrollable Rail alternative requires mockup | horizontal route strip/drawer | near-full width, vertically scrolling route content | 48px minimum |
| Phone-sized Linux | identity, current route, essential controls, explicit overflow | drawer | one-column route composition | 48–56px |

Do not implement the phone/portrait rows from prose alone. They require approved mockups and input testing.

## 9. Required proof states

Every shared component and surface must demonstrate:

- loading;
- unavailable source;
- empty;
- nominal;
- hover;
- keyboard focus;
- selected/active;
- disabled;
- warning and error;
- pending confirmation;
- running;
- succeeded and failed;
- reduced motion;
- standard and touch density;
- narrow/portrait behavior where supported.

## 10. Implementation sequence and gates

| Stage | Scope | Approval gate |
| --- | --- | --- |
| 0 | tokens, type, spacing, frame contract, focus model, colour migration | representative mockups and accessibility review |
| 1 | isolated Compact/Standard/Large frame harness and shared primitives | SVG scaling/content-safe QA at multiple sizes |
| 2 | Volume and Tray | current actions, anchors, outside-dismiss, keyboard/touch proof |
| 3 | Control Centre shell and routes | no route/action/data regression; confirmation proof |
| 4 | Insights shell and routes | privacy, reading measure, allowlist and report boundaries |
| 5 | Performance shell and routes | history truth, table readability, benchmark/process guardrails |
| 6 | Companion | coexistence, timeout/pin/dock behavior, bounded asset decoding |
| 7 | Rofi, SwayNC, GTK/native projection | toolkit-specific QA and fallback behavior |
| 8 | Hyprland decoration/motion | synchronized tracked/live files, configerrors, tiled/floating/fullscreen proof |
| 9 | SDDM, Hyprlock, Recovery | real renderer, keyboard/auth/error/confirmation QA and recovery path |
| 10 | GRUB/Plymouth | boot/install/rollback and handoff QA |

No later stage should be used to conceal an unresolved Stage 0 decision.
