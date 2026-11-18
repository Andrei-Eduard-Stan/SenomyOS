# SenomyOS product specification

## Intent and scope

SenomyOS is a dark, precise Arch Linux desktop shell using Hyprland and native
Quickshell. It should provide coherent everyday control, trustworthy local
information and safe recovery. It remains a desktop in development; a reproducibly
deployable operating-system product is the destination. Current evidence and
unaccepted capabilities belong in [PROJECT_STATE](PROJECT_STATE.md).

## Surfaces

| Surface | Entry | Responsibility |
| --- | --- | --- |
| Obsidian Rail | Persistent bottom system bar | Workspaces, identity, telemetry, quick controls, clock and power |
| Control Centre | Contextual controls / Settings entry | One shared workspace in compact or full normal-window mode |
| Performance Dashboard | CPU/MEM/UP telemetry | System investigation, processes, services, guarded diagnostics and reports |
| Senomy Insights | Dialogue adjacent to the Rail avatar | Evidence-based local system briefing and knowledge |

Control Centre preserves Overview, Network, Audio, Power, Calendar, Input,
Device Management, Applications, Appearance and Settings. Device Management
covers available displays, endpoints, inputs, batteries, interfaces and Bluetooth.
Performance remains separate. Compact Control Centre and full resizable Settings
share pages, services, routing, search and unsaved-draft guards.

Insights preserves Briefing, Notifications, Timeline, Updates, Diagnostics,
Console, Reports and Wiki. It is a first-class system briefing, not a generic
chatbot. Show each observation's source, freshness and limits. Missing evidence
cannot become a diagnosis, update count, health claim or successful operation.

The Rail avatar and Insights dialogue are separate adjacent targets that read
as one identity. Primary headers/content cards do not reserve duplicate character
artwork. Preserve the approved expanded island artwork and its functional roles.

## Interaction contract

One primary state exists: `none|control|performance|insights`. Full Settings is
Control Centre's full entry mode, not another primary surface.

One quick popover may coexist with a primary. Repeating its trigger toggles it;
another quick trigger replaces it in one activation while preserving the primary.
Opening/focusing a primary dismisses the transient popup. Required modal reviews
and dirty forms retain explicit keep/discard/cancel semantics. Escape handles the
innermost dismissible overlay first. Every surface has a visible close path.

Native globally unique Hyprland workspace identities remain authoritative.
Monitor-local labels, order and home policy must not silently change identity.
The Rail should remain usable through provider failure and narrower work areas.
Hide subordinate words before essential controls or meaningful status.

## Everyday capabilities

- Network/Bluetooth/audio use their existing system providers with explicit
  availability, exact-target review and observed outcomes.
- Power supports zero, one or multiple batteries; charging, aggregate state and
  source provenance remain truthful. Preserve the user's disabled automatic-idle
  lock policy. Lid policy is a separate, explicitly accepted configuration choice.
- Calendar is a local organizer with a persistent service, drafts and reminders;
  remote accounts/sync depend on separately available providers.
- Quickshell owns native desktop notifications and bounded private retained
  history. Clearing is reviewed. Timeline does not silently capture unrestricted
  activity. No diagnostics or reports upload automatically.
- Command Lens opens on Apps, ordering the empty query by locally recorded successful
  desktop-app launches with an alphabetical option. Search relevance leads once typing;
  All, Files, Windows and Actions remain explicit scopes. New history starts empty,
  without inferring past use from running windows. It uses bounded catalogs and literal
  activation identities. Rofi is an explicitly selected legacy mode. Thunar stays
  the persistent native GTK file workspace; do not build a second file manager.
- The file workspace remains native GTK3 Thunar, extending the existing Island
  material, authored framing and readable body roles. Native search, tabs, split
  view, previews and file operations retain their upstream ownership. A native
  per-process presentation module supplies the authored heading, icon choice and
  metadata roles without becoming a data collector or file-action engine. An explicit
  one-time workspace profile exposes navigation/search/split/tab controls and useful
  Places through the shared native GTK bookmarks file, without resetting preferences
  at launch. Preserve labelled aliases, remote bookmarks, other owner entries, custom
  toolbar items, user actions and launcher choices. Record exact preference/bookmark
  preimages and refuse rollback over later owner edits.
  Five allowlisted clipboard actions cover absolute paths, SHA-256, names, local
  file links and paths within one Git/Mercurial workspace. Keep selections bounded
  and failures explicit; do not add arbitrary commands or a second file manager.
  Native captures and inert tests establish only their exercised states; live
  publication, physical input, Wayland placement/grabs and hardware acceptance
  require separate evidence.
- Performance keeps bounded timestamped telemetry and exposes explicit expensive
  work. Diagnostics are curated and allowlisted; unrestricted commands run in a
  real terminal PTY. A shell restart begins a new telemetry epoch.
- Appearance accepts validated preferences and authored assets, not arbitrary
  executable styling or privileged configuration.

## Actions and failure states

Distinguish loading, ready, empty, unavailable, disconnected, stale, malformed,
failed, pending/running and succeeded. Unknown is neither healthy nor disconnected.
Keep bar errors concise and expose source/recovery detail in the owning surface.

Disruptive actions name their target, operation and impact before confirmation.
Prefer SIGTERM; force-kill requires a separate stronger review. Restart only a
known managed target. Accepted dispatch, launched terminal and saved draft are
not proof of a completed system operation. Preserve cancellation and recovery
boundaries when external state changes.

## Portable deployment and hardware tiers

Portable defaults → architecture/form-factor profile → required hardware override
→ explicit user preferences. Keep personal state separate from defaults and
updates. Prefer capability detection to model checks. Do not embed a username,
home, output/index, interface, battery count, wallpaper or reference resolution
in shared defaults. Unknown hardware gets safe fallback and honest availability.

| Tier | Target and limits |
| --- | --- |
| 1: desktop/laptop | Initial x86_64 Arch/mainline target; keyboard/pointer, common PipeWire/NetworkManager devices, optional batteries |
| 2: touch/convertible | Touch density, OSK accommodation, portrait/landscape and visible gesture alternatives; physical acceptance required |
| 3: mini PC/appliance | Battery-free operation, hotplug inputs/displays and supported deployment profiles |
| 4: ARM/tablet/phone-sized | Experimental per-device support; bootloader, kernel, graphics, sensors, suspend and optional modem support must be tested |

The ThinkPad T480 is reference hardware, not the compatibility specification.
No universal PC/phone support is claimed. Existing automatic/desktop/touch/narrow
profiles express bounded layout preferences rather than device certification.

The delivery path is portable shell → repeatable package/service bootstrap →
versioned components and migrations → installer/recovery media → tested hardware
matrix. Preserve update, rollback, recovery and first-boot requirements now.

## Accessibility and release acceptance

Provide pointer, keyboard and touch paths. Essential information cannot require
hover; gestures need visible alternatives. Use visible focus, accessible names,
adequate contrast and non-colour state cues. General primary touch targets are at
least 44 logical pixels; current shared native controls use 48px in touch mode.
Wrap safety text and meaningful labels; never shrink it to rescue layout.
Accommodate text scaling, portrait/narrow work areas and the OSK.

Release claims require versioned manifests, supported architectures/devices, known
limits, source/artwork/font licensing, clean-VM/fresh-user installation, update/
rollback/recovery and measured resource/lifecycle evidence. Physical tests remain
necessary for touch, sensors, power, GPU, sleep and device routing. A fixture,
checkbox or source feature does not certify an entire domain.

Detailed operational standards and stable C/W/D identifiers live in the
[reference index](reference/README.md). Current next work has one owner:
[PROJECT_STATE](PROJECT_STATE.md).
