# SenomyOS Data Sources and Command Policy

## Principles

- Presentation consumes normalized data.
- Status collectors are read-only.
- Mutating actions live in separate scripts.
- Missing tools and hardware are normal states.
- No collector may expose credentials or secrets through Eww variables.
- Expensive checks should run on demand or at long intervals.

## Common JSON envelope

New collectors should prefer:

```json
{
  "ok": true,
  "source": "pamixer",
  "observed_at": 0,
  "data": {},
  "error": null
}
```

On failure:

```json
{
  "ok": false,
  "source": "missing-command",
  "observed_at": 0,
  "data": null,
  "error": {
    "code": "dependency_missing",
    "message": "Required command is unavailable"
  }
}
```

Messages must be safe to show in the UI and must not contain command lines with
secrets.

## Source inventory

| Domain | Preferred source | Suggested cadence | Notes |
|---|---|---:|---|
| Workspaces | Hyprland `.socket2.sock` events plus `hyprctl -j workspaces`, `activeworkspace`, and `clients` snapshots | event-triggered; 10s cached heartbeat; 30s safety resync | Preserve the systemd-owned listener; discover the active runtime instance if inherited session variables are absent |
| Battery bar summary | UPower DisplayDevice + per-pack UPower | 10s | Energy-weighted aggregate plus compact dual-pack state |
| Companion media | MPRIS through `playerctl` | 3s | Read-only active-session snapshot; no playback control or history |
| Detailed Power | UPower + `/sys/class/power_supply` + optional TLP runtime | 5s while visible | Identity, chemistry, energy, health, wear, cycles, electrical values, estimates, thresholds, effective policy, and explicit unavailable fields |
| Volume/mute | `pamixer` | event or 1–2s while visible | `wpctl`/`pactl` for endpoints |
| Audio devices | `wpctl`, `pactl` | event or panel-open poll | Handle PipeWire naming changes |
| Wi-Fi state | `nmcli` | 5–15s while visible | Never request stored passwords |
| Wi-Fi scan | `nmcli` | manual refresh | Scans can be slow and disruptive |
| Ethernet | `nmcli` | 5–15s while visible | Show disconnected cleanly |
| CPU/RAM | Eww built-ins or `/proc` | 1–2s while dashboard open | Keep bar summary lightweight |
| Uptime/load | `/proc/uptime`, `uptime` | 30–60s | No reason for one-second polling |
| Processes | `ps` and `/proc` | 3–5s while dashboard open | Stable PID and command parsing |
| Monitors | `hyprctl -j monitors` | panel open / events | Avoid monitor index assumptions |
| Input devices | `hyprctl -j devices` | panel open / events | Redact nothing sensitive |
| Temperatures | Eww built-ins or `sensors` | 3–5s while dashboard open | Show unavailable if unsupported |
| Storage | `df`, optional SMART tooling | 30–60s / manual | SMART may require tools/privilege |
| Official packages | `checkupdates`, fallback `pacman -Qun` | manual | Fallback uses potentially stale local databases |
| AUR packages | `paru -Qua --nodevel` | explicit manual action | Sends installed foreign package names to AUR |
| User services | `systemctl --user` | panel open / manual | Allowlist restart targets |
| Background applications | user systemd, session D-Bus, StatusNotifierWatcher | 2s while Applications is visible | Registry is metadata; actions remain hard-coded |
| Logs | `journalctl --user` | manual | Limit lines and redact sensitive data |
| Display geometry | `hyprctl -j monitors` | events / surface open | Drives responsive work area |
| Input capabilities | `hyprctl -j devices`, optional libinput/udev data | login / device events | Prefer capabilities over model names |
| Orientation | compositor/profile source | events when available | Fall back to configured profile |

Optional commands must be checked with `command -v`.

Hardware detection should produce normalized capabilities rather than branching
the UI on a laptop model. Example capabilities include:

```text
has_touchscreen
has_pointer
has_keyboard
has_battery
battery_count
has_bluetooth
has_internal_display
orientation_supported
```

Detection must tolerate devices appearing and disappearing at runtime.

## Existing verified commands

Verified on 2026-07-24:

- `eww`
- `hyprctl`
- `jq`
- `upower`
- `pamixer`
- `nmcli`
- `pactl`
- `wpctl`
- `paru`
- `pacman`
- `systemctl`
- `journalctl`
- `ps`
- `free`
- `uptime`

`checkupdates` and `yay` were not installed.

## System status collector

`scripts/system-status.sh` is the first normalized SenomyOS system collector.
It reads Linux procfs and emits schema version 1 JSON containing:

- sampled CPU utilization;
- total, used, and available memory;
- memory utilization;
- uptime in seconds and human-readable form;
- one-, five-, and fifteen-minute load averages.

It does not inspect a model name, monitor, user, home path, battery, or network
interface. `SENOMY_PROC_ROOT` and `SENOMY_CPU_SAMPLE_DELAY` are test overrides;
production uses `/proc` and a short sample delay.

The script returns structured error envelopes for missing procfs data, invalid
configuration, malformed sources, failed sampling, and a missing `jq`
dependency.

## Audio status collector

`scripts/audio-status.sh` reads PipeWire/PulseAudio compatibility data through
`pactl` and emits schema version 2 JSON containing:

- the default output and input;
- normalized display names, stable IDs, volume, mute, and state;
- physical routes, sample formats, channel maps, driver and codec identity;
- all available non-monitor outputs and inputs;
- card profiles, server/service state, endpoint and hardware counts.

The collector is read-only. It never changes volume, mute state, or routing.
PulseAudio monitor sources are excluded from the user-facing input list.

The script returns structured errors for missing dependencies, unavailable
audio services, and malformed JSON.

Eww consumes this collector every second only while the compact volume flyout
or the Control Centre Audio section is visible. `scripts/volume.sh` owns
default-output gain/mute; `scripts/audio-action.sh` validates current
endpoints and ports before input-mute or routing mutations.

The persistent Rail instead consumes `scripts/bar-audio-listener.sh`. It emits
one cheap default-sink summary at startup and refreshes it from
`pactl subscribe` sink, server, and card events. It does not enumerate audio
hardware continuously.

## Performance Dashboard collectors

`scripts/performance-history.sh` wraps `scripts/performance-live.sh`. Its
`sample` action returns one synchronized current-status envelope to Eww while
appending at most one normalized history point every five seconds. Its `read`
action returns a rolling 300-second array from
`${XDG_RUNTIME_DIR}/senomyos/performance-history.json`.

The runtime directory is mode 0700 and the atomically replaced history file is
mode 0600. The cache contains only timestamps and aggregate CPU, memory,
temperature, load, pressure, disk, network, and optional GPU values. It is
session-scoped, bounded, and continues to advance while the bar is running, so
destroying the Performance window cannot erase the visible period. Disk and
network charts use a dynamic five-minute peak with documented minimum scales;
the displayed current values remain unscaled real rates.

`scripts/performance-live.sh` takes two procfs/sysfs snapshots 250ms apart. One
sample supplies total and per-core CPU, CPU time distribution, scheduler rates,
memory composition, swap and commit, root-disk throughput/IOPS/busy time,
active-interface traffic and counters, PSI, frequency policy, temperatures,
fans, and optional DRM GPU telemetry. Missing capabilities are reported as
unavailable rather than estimated.

`scripts/performance-processes.sh` emits at most twelve process records with
PID, user, state, command name, instantaneous CPU from procfs deltas, resident
memory, thread count, age, priority, and nice value. It runs every three seconds
only while the Processes page is active and excludes its own short-lived
collector processes.

`scripts/performance-status.sh` emits the slower inventory:

- host, operating-system, kernel, architecture, and package count;
- CPU topology, cache sizes, virtualization, and frequency limits;
- root filesystem, mount options, block-device geometry, and disk inventory;
- capability-detected thermal sensors, fans, and GPU identity;
- active-interface addressing, connection, route, and gateway;
- aggregate socket counts without exposing remote endpoints;
- system and user service-manager health plus a bounded failed-unit list.

It runs every 15 seconds only while Performance is visible. The persistent
two-second sample remains owned by `performance-live.sh`, while
`performance-history.sh` retains the bounded five-minute visual history.

### Performance confidence benchmark

`scripts/benchmark-action.sh plan PROFILE` is the read-only contract for the
Quick and Standard profiles. `start PROFILE` launches one private detached
runner only after the Performance UI confirmation. Workloads are implemented
from fixed argument arrays and project-owned helpers: repeated 8 MiB SHA-256
blocks, bounded native memory writes, gzip level 1, a private direct-I/O
scratch file with labelled buffered fallback, and fixed-count process launch.

Quick targets approximately 70 seconds with a 256 MiB storage file. Standard
targets approximately 210 seconds with a 512 MiB storage file. CPU workers are
capped at eight; memory is capped at 1 GiB and one quarter of currently
available memory. Starts are refused below 25% while discharging or below 256
MiB available memory. `performance-live.sh` samples each sustained workload;
when a numeric CPU temperature reaches the configured 95 C default, the active
process group is stopped and the run terminates as `thermal-abort`. Missing
thermal evidence is reported rather than fabricated; finite duration remains
the fallback safety boundary.

Status, a bounded log, telemetry JSONL, reports, PDFs, and checksums live under
the private SenomyOS benchmark XDG state directory. The report collects
non-secret CPU, memory, PCI/USB, block/filesystem, sensor, display, OS, package,
and dependency evidence. Serial numbers, MAC/IP addresses, credentials,
environment dumps, unrestricted logs, network traffic, root access, and
automatic package installation are excluded.

## Network status collector

`scripts/network-status.sh` reads NetworkManager state through `nmcli` and
emits schema version 2 JSON containing:

- global state and connectivity;
- networking and Wi-Fi radio state;
- the primary non-loopback connection;
- access-point identity, signal, band, channel, frequency, rate, and security;
- a bounded nearby-network catalog grouped by SSID, preferring the active
  radio and otherwise the strongest radio while retaining band/radio counts;
- IPv4/IPv6, gateways, DNS, MTU, driver, firmware, carrier, and link speed;
- saved Wi-Fi profile UUID, display name, SSID, active/autoconnect state, and
  last-used timestamp without credentials;
- hidden access-point count without pretending hidden radios are connectable
  named networks;
- separate association/route and NetworkManager connectivity evidence, with
  explicit full-internet, captive-portal, limited, link-only, and offline
  labels;
- the complete interface inventory for Device Management.

The collector is read-only. It never scans for networks, connects,
disconnects, changes radios, or reads saved credentials.

The script returns structured errors for missing dependencies and an
unavailable NetworkManager service.

Eww polls every four seconds only while Network is visible.
`scripts/network-action.sh` accepts only radio/networking toggles, validated
disconnect, manual rescan, saved-profile activation/deactivation, autoconnect
toggle, profile edit/create, confirmed profile deletion, and secure interactive
connection. Every UUID, BSSID, and device is checked against current
NetworkManager state before use.

Saved profiles activate by UUID and never expose their stored authentication
material. Unknown networks launch `nmcli --ask` in a dedicated Kitty process;
the password travels directly from that terminal to NetworkManager and never
enters an Eww variable, generated shell command, collector payload, or SenomyOS
log. Profile creation/editing delegates to `nm-connection-editor`.

Cached open networks use a separate validated no-secret action. NetworkManager
may associate and obtain an address while reporting only site, portal, or
limited connectivity. The UI must call that state linked, not online, and
offer a browser-based captive-portal entry. An open hotspot does not request a
Wi-Fi password; any login belongs to its browser portal.

Radio disable, active disconnect, and profile deletion require an in-panel
impact confirmation. Connecting to a selected network, changing autoconnect,
manual refresh, and opening NetworkManager's editor are explicit immediate
actions.

The persistent Rail consumes `scripts/bar-network-listener.sh`, which emits a
small current connection/radio summary at startup and again for each
`nmcli monitor` event. It does not scan or build the nearby-network catalog.

## Reports and user preferences

`scripts/performance-report.sh` generates Overview, Performance, Network,
Power, or Full evidence profiles from fixed read-only collectors. It writes an
immutable mode-0600 text artifact and JSON sidecar manifest beneath
`${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/reports`, plus a mode-0600
latest pointer. Insights previews at most 100 non-empty lines and indexes ten
recent manifests. Credentials, unrestricted logs, saved network secrets, and
environment dumps are excluded. The latest path may be copied or opened in a
real Kitty/`less` pager only after the manifest path is revalidated beneath the
report root.

## Insights Console collector

`scripts/console-status.sh` detects Kitty, tmux, Bash, Zsh, Fish, and
PowerShell without installing anything. Ten in-panel task IDs map to fixed,
read-only command implementations with an eight-second timeout, 80-line output
limit, 260-character line width, home-path normalization, and sensitive-term
redaction. The cache is mode 0600.

The launcher accepts only allowlisted shell IDs and resolves executables with
`command -v`. Available shells open in Kitty with a real PTY; free-form command
text never crosses from Eww into a shell command.

## Bluetooth device collector and actions

`scripts/bluetooth-status.sh` reads the BlueZ controller and at most 30 cached
devices through `bluetoothctl`. It reports power/discovery state, pairing,
trust, connection, block state, RSSI, audio capability, and battery percentage
only when BlueZ exposes the property. The collector never starts discovery or
changes a device.

`scripts/bluetooth-action.sh` accepts only fixed controller/device operations
and strict MAC addresses. Scan is bounded to 12 seconds. Pairing uses BlueZ's
`NoInputNoOutput` agent for devices such as earbuds; devices requiring PIN or
keyboard confirmation fail visibly rather than bypassing authentication.
Power-off, pairing, disconnect, and forget are confirmation-gated in Eww.
Action state is private mode-0600 cache data and contains no pairing secrets.

`scripts/settings-action.sh` accepts only the Rail density values `auto`,
`standard`, `compact`, and `narrow`. It atomically writes a mode-0600 versioned
preference under `${XDG_CONFIG_HOME}/senomyos/preferences.json` and publishes a
fresh `bar-layout.sh` result. Packaged defaults remain untouched.

## Polling budget

Persistent bar:

- clock: 30–60s;
- battery: 10–30s;
- telemetry summary: 2–5s;
- workspaces: refresh after relevant Hyprland workspace/window events, republish
  cached state every 10 seconds, and take a safety snapshot every 30 seconds;
- ambient Senomy dialogue: select from the local catalog every 15 minutes;
  verified warnings override ambient dialogue in the presentation layer.

The workspace listener validates an inherited
`HYPRLAND_INSTANCE_SIGNATURE` against its event socket. If it is absent or
stale, it selects the newest valid entry from `hyprctl instances -j`, exports
that instance and Wayland socket for its child commands, and then connects to
`.socket2.sock`. Failure remains explicit; systemd retries after two seconds
without a permanent start-limit lockout.

Control Centre:

- poll a section only while it is active where Eww supports `:run-while`;
- scan Wi-Fi manually;
- prefer PipeWire/NetworkManager events where the complexity is justified.

Performance Dashboard:

- synchronized current summary: 2s globally;
- multidomain history: retain one point at most every 5s for 300s;
- history cache reads: 2s only while Performance is visible;
- processes: 3s only on the Processes page;
- system and hardware inventory: 15s while Performance is open;
- stop expensive collectors when the dashboard closes.

Insights:

- package source checks: explicit manual action;
- update cache reads: 2s only while the Updates tab is visible;
- local Markdown catalog: 3s only while the Wiki tab is visible;
- maintenance and health summaries: derived from cached source records;
- never run an AUR update check every few seconds.

Applications:

- the native Eww tray host exists only while the tray flyout is visible;
- managed application status polls every two seconds while Applications or the
  tray flyout is visible;
- service state, application D-Bus readiness, and tray registration remain
  separate evidence fields;
- the registry supplies metadata only, while the action helper independently
  allowlists every application and verb.

## Senomy dialogue catalog

`data/senomy-dialogue.json` contains versioned personality lines. Each record
has a stable ID plus category, severity, rarity, language, tone, and text.
Wording belongs in the catalog rather than in the selector.

`scripts/senomy-dialogue.sh` validates the catalog and returns one normalized
record. Selection remains stable within a 15-minute time slot so Eww reloads do
not make the message flicker. One in five slots prefers the uncommon pool.

Ambient selection never overrides verified critical, warning, recommended, or
unavailable conditions. Those conditions are derived from successful system
sources before the selected ambient line reaches the bar.

## Senomy avatar catalog

`data/senomy-avatars.json` is the portable source of avatar state metadata.
Each allowlisted state contains an ID, label, emotion, activity, and relative
paths for a chibi and portrait asset under `assets/senomy/`.

`scripts/senomy-avatar.sh catalog` validates schema version 1, unique bounded
state IDs, the default state, path containment, and readable referenced files.
It emits absolute resolved paths only after validation. Eww polls this small
local catalog every five seconds. No image data, state, or path is sent over
the network.

Accepted source formats are SVG, PNG, JPG/JPEG, and GIF. Every asset is checked
for a matching image MIME type and remains under `assets/senomy/`. Animated
GIFs are limited to 32 MiB, 300 frames, and 4096 by 4096 pixels, then converted
with ImageMagick into private cached variants sized for the Rail, expanded
companion, and compact companion contexts. The catalog reports both source and
resolved context paths so Eww does not resize an intrinsic-size animation at
render time.

The helper also exposes `list`, `set STATE`, `reset`, and `show`. `set`
independently validates the state before updating the ambient Eww
`chibi_state` for backward-compatible/manual testing. The visible Rail and
companion state is centrally derived from verified UPower and MPRIS sources;
panel headers and content cards do not instantiate separate avatar domains.
Presentation surfaces never execute a path from widget text.

## Companion media snapshot

`scripts/companion-media.sh` emits schema-version-1 JSON from MPRIS through
`playerctl`. It checks command availability, bounds discovery to 24 players,
prefers an actively playing session, and truncates title, artist, album, and
player identity to presentation-safe lengths. The envelope distinguishes an
unavailable provider from no media session, paused playback, stopped playback,
and active playback.

Eww polls the snapshot every three seconds because the Rail avatar may react
even while the expanded companion is closed. This collector is read-only: it
does not control playback, retain listening history, query a network service,
or infer a track from window titles. In the companion resolver, verified UPower
low-battery evidence takes priority over music playback; otherwise the normal
browsing state is used.

## Insights Wiki collector

`scripts/wiki-status.py catalog` reads UTF-8 `.md` files below `wiki/` and
emits schema-version-1 JSON. It is implemented with the Python standard
library and has no package or network dependency.

The bounded contract permits at most 128 files, 256 KiB per file, 2 MiB total,
2,500 lines per article, 320 rendered blocks, eight table columns, and 64 table
rows. Symbolic-link files and names beginning with `_` are ignored. Supported
front matter is limited to `title`, `category`, `category_order`, `order`, and
`summary`.

The rendered Markdown subset is:

- headings levels one through three;
- paragraphs and inline emphasis reduced to plain text;
- ordered and unordered lists;
- block quotes and horizontal rules;
- fenced code blocks;
- pipe tables;
- `[label](article.md)` and `[[article|label]]` internal links.

Internal targets are normalized and checked against the parsed catalog.
Missing targets become visible unavailable links. External links are labelled
but never opened. Images, HTML, scripts, GTK markup, and code execution are not
supported. Eww polls every three seconds only while Insights Wiki is visible.

## Insights notification-history collector

`scripts/notification-history.sh capture` receives the documented SwayNC
script environment and appends one normalized JSON object to a private local
JSONL history. `scripts/swaync-history-integration.sh install` merges only the
named `senomy-history` receive rule into the user SwayNC configuration; it
copies the system default when no user configuration exists and backs up an
existing user file before changing it.

The collector retains the newest 120 entries by default and rejects configured
limits above 500. Application, title, body, category, and desktop-entry text is
stripped of markup and control characters and truncated before storage.
Notification actions and opaque hints are never stored. The state directory
and files are mode 0700/0600, remain local, and have an explicit confirmed
clear action.

`read` combines retained entries with bounded SwayNC count and Do Not Disturb
queries. Those client queries have a 400ms timeout so an unavailable D-Bus
provider cannot stall Insights. Eww polls once per second only while Insights /
Notifications is visible. This is notification history, not a guarantee that
every application or daemon will emit a notification.

## Insights timeline collector

`scripts/timeline-status.sh` provides bounded Timeline sources. Its allowlisted
modes are `activity`, `session`, `system`, `kernel`, and `eww`. `session` is the
user-level systemd journal; it is not presented as a record of everything the
person does.

`activity` reads the private mode-0600 journal written by
`scripts/senomy-event.sh`. The journal retains at most 500 structured shell
events such as surface transitions and section navigation. Categories, event
names, targets, and outcomes are allowlisted tokens. It never accepts arbitrary
command text and does not record keystrokes, file contents, websites, passwords,
credentials, or unrestricted application activity.

Journal records are reduced to an event ID, local date/time, normalized
severity, source/unit, and message. Messages are capped at 240 characters,
control characters are replaced, the current home path is normalized to
`$HOME`, and entries containing obvious credential terms are redacted before
they reach Eww state.

Each result contains at most 40 entries by default and rejects limits above
100. Eww maintains one source-specific poll per mode because Eww 0.5 poll
commands cannot interpolate variables. `:run-while` ensures continued
five-second polling applies only to the selected source while Insights
Timeline is visible and Follow is enabled. Activity uses a two-second interval.
If Eww creates an empty native cache log, Timeline reports that fact and points
to a labeled `eww-interaction-bridge` sourced from the same structured Activity
journal rather than representing the empty file as native daemon output.
Project-owned daemon startup paths enable Eww's global `--debug` option so
future daemon sessions populate the native source. Timeline still sanitizes and
limits what reaches widget state; the native cache remains local to the user.

## Insights updates collector

`scripts/update-status.sh` maintains the schema-version-1 Updates cache at
`${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/updates.json`.

The allowlisted actions are:

- `read`: return the cache or a truthful `never_checked` envelope;
- `check-official`: prefer `checkupdates`, otherwise run `pacman -Qun` against
  the existing local sync databases;
- `check-aur`: run `paru -Qua --nodevel` only after the dedicated AUR action.

Official fallback results use the source name `pacman-local-db`, include the
newest local sync-database timestamp, and always warn that the result may be
stale. They are not described as a live repository check. AUR results use the
source name `paru-aur` and retain a visible notice that the query sends
installed foreign package names to `aur.archlinux.org`. `--nodevel` prevents
additional VCS-remote probes during this check.

Checks use a non-blocking `flock`, a timeout of 30 seconds by default, and an
atomic temporary-file rename. Package output is accepted only in the
`name current -> available` format. Displayed lists are capped at 100 entries
per source by default while retaining the true parsed count and a truncation
flag. Raw command errors, package-manager progress, credentials, and
environment values never enter Eww state.

The collector has no action for package installation, removal, system
pacman-database synchronization, or privilege elevation.

## Insights diagnostics runner

`scripts/diagnostics-status.sh` owns both the Diagnostics task catalog and its
schema-version-1 cache at
`${XDG_CACHE_HOME:-$HOME/.cache}/senomyos/diagnostics.json`.

Its allowlisted actions are:

- `catalog`: return task metadata without executing a diagnostic;
- `read`: return the current cache or a truthful idle envelope;
- `run <task-id>`: execute exactly one built-in read-only task.

The initial task IDs and operations are:

- `failed-units`: `systemctl --user --failed --no-pager --plain`;
- `workspace-service`:
  `systemctl --user status workspaces.service --no-pager --lines=20`;
- `recent-errors`:
  `journalctl --user --priority=warning..alert --since=-30min --no-pager
  --lines=40 --output=short-iso`;
- `memory-pressure`: `free -h` plus a direct read of
  `/proc/pressure/memory`;
- `filesystems`: `df -h` with temporary, device, SquashFS, and EFI variable
  filesystems excluded;
- `power-inventory`: `upower -e`.

The selected ID is looked up again inside the runner. Each external operation
uses a fixed executable and argument array; there is no `eval`, `sh -c`,
`bash -c`, free-form command input, `sudo`, or mutation action. Missing
dependencies produce an explicit unavailable result.

Only one task can run at a time. The default timeout is eight seconds and is
rejected above 30 seconds. Captured output defaults to 60 lines of at most 240
characters each, with hard configuration maxima of 100 lines and 500
characters. Control characters are replaced, the user's home path is
normalized to `$HOME`, and whole lines containing common credential terms are
redacted before data reaches Eww. Cache replacement is atomic and the result
file is mode `0600`.

Eww polls the catalog hourly and the result cache once per second only while
the Insights Diagnostics tab is visible. Polling reads local state; it never
runs a task. The cache intentionally retains only the latest result rather
than a command history.

## Device Management

Device Management should normalize:

- display outputs from Hyprland;
- audio endpoints from PipeWire/PulseAudio tools;
- input devices from Hyprland;
- batteries from UPower;
- network interfaces from NetworkManager;
- optional Bluetooth devices only if `bluetoothctl` or another suitable source
  is present.

Each device record should include a stable ID, display name, class, connection
state, source, and supported safe actions.

Portable code must not assume device identifiers such as `eDP-1`, `wlp3s0`,
`BAT0`, or monitor `0`. Collectors translate discovered devices into normalized
records, while hardware profiles may provide carefully scoped overrides.

## Process and service actions

Read-only inspection is the default.

Allowed process flow:

1. select a PID from fresh process data;
2. inspect its current identity;
3. preview the action;
4. confirm;
5. re-check that the PID still identifies the same process;
6. send `SIGTERM`;
7. report the result;
8. offer separately confirmed `SIGKILL` only if still running.

Never kill by a broad text match.

Restart is available only when the target maps to an allowlisted user service
or another known restart mechanism.

## Curated diagnostic console

The Insights implementation above establishes the reusable console contract.
The future Performance Dashboard console is likewise a menu of safe diagnostic
tasks, not arbitrary command execution.

Potential allowlisted tasks:

- inspect selected process;
- inspect selected user service;
- show recent logs for an allowlisted service;
- summarize CPU and memory pressure;
- list disks and filesystems;
- inspect UPower batteries;
- inspect Hyprland monitors and input devices;
- inspect PipeWire endpoints;
- inspect NetworkManager connection state;
- assemble a redacted troubleshooting report.

Arguments come from validated selections, never raw shell fragments entered in
a text field.

## Insights data policy

Each insight must cite its internal source and observation time. Insight
generation may summarize facts, but it must not turn absence of data into a
diagnosis.

Examples:

- Valid: “BAT1 is discharging faster than BAT0 over the last 30 minutes.”
- Invalid without history: “BAT1 is unhealthy.”
- Valid: “Package check unavailable: neither the configured helper nor a
  successful `paru` result is present.”
- Invalid: “12 updates available” when no successful check ran.
