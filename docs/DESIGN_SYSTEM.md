# SenomyOS design system

## Authority and construction

The accepted language is precise, dark, terminal-informed native instrumentation. Preserve the existing authored Island/expanded Senomy artwork, cut-corner frame
construction and semantic roles. Obsidian Rail is the compact system surface;
Cathedral informs Performance information architecture.

Use the [design-director workflow](DESIGN_INTELLIGENCE_GUIDE.md) and
[curated cases](design/design-intelligence/INDEX.md). A case's approval applies
only to its recorded decisions. Candidate renders, agent selection and archived
comparison sheets cannot confer owner approval. Preserve rejected cases as
learning evidence, with their scope and reason.

## Sources of truth

| Concern | Source |
| --- | --- |
| Shared semantic colour/type/motion/auth roles | `appearance/tokens.json` and its maintained generator/native projections |
| Authored skin and artwork selection | `appearance/skins/default.json`, Skin and validated user overrides |
| Native theme fallback | `shell/quickshell/config/Theme.qml` |
| Directory/shared controls | `DirectoryStyle.qml` and existing native controls |
| Rail/quick controls | RailStyle, QuickPanelStyle and original authored artwork |
| Shared motion | Motion and ReflectionLight |
| Authentication projections | Existing native SDDM/Hyprlock sources and shared auth roles |

Link actual token/schema sources rather than repeating a changing palette or
complete size catalog here. Hand-authored corners remain authored source; never
regenerate them with an incompatible historical frame projector. Preserve the
editable masters and context-sized bounded asset decoding.

## Typography, hierarchy and framing

Current Directory/Island roles use Bruno Ace SC display headings, Audiowide
values, readable sans-serif body/control text and the Theme data-font role for
technical information. JetBrainsMono is a technical role, not a universal body
font. A symbol-only fallback never becomes the global text face. Font packaging
must preserve licensing/provenance and declared runtime dependencies.

Use one authored perimeter and organize contents by alignment, proximity, spacing
and typography. Avoid repeating nested ornamental cards or inventing a generic
row/card system for unrelated tasks. Opaque or sufficiently strong backing keeps
text readable over artwork. Primary cards/headers do not duplicate character art.

The expanded Senomy island is a preserved reference, not an unsolicited redesign
target. Keep original corner paths, interruptions, framing, texture and identity.
Other functional surfaces may transfer that language while improving their own
task hierarchy. The earlier Control Overview A remains historical; P13 records the current
Control Centre composition and preserves its provider/action/navigation boundaries.

The native GTK3 Thunar extension follows the owner's later sculpted file-manager
reference: substantial chrome artwork in the heading and lower corners, a real
folder/path heading, steel persistent Places selection, a dense ruled file table
and a dedicated object inspector. This composition supersedes theme-only backdrop
iterations. One clipped blackened surface fills the gutters and corner interiors;
the file reading plane stays dark and quiet. Artwork belongs to the structural
edges, with local dark backing protecting heading contrast. Filenames and column
labels use readable body type, while the heading uses the authored display role.
Pointer states use a restrained translucent silver wash and fine border, never
an opaque white tile; persistent selection and static keyboard focus are distinct.

The inspector docks at widths of at least 1120px and becomes a scrollable native
popover below that width. Its real metadata uses the installed public Thunarx
interface; cancellable local-only enumeration reads at most nine immediate entries,
showing eight and truthful overflow, without recursive or remote scans. Compose
before initial native measurement/map and coalesce topology changes outside GTK
allocation. These are native lifecycle rules, not animation or first-buffer claims.

Keep Name responsive but bounded so metadata stays beside filenames on wide windows.
The explicit native fixed-column profile supports this policy; a manual Name width
change relinquishes automatic fitting for that column's lifetime. Preserve manual
metadata widths, search, tabs, Places and native toolbar mechanics. Controls dispatch
available native actions and disable unavailable bindings. Thunar retains file
operations, providers and selection ownership. Standard/touch density changes target
size and row pitch rather than the visual world; GTK animation policy governs short
CSS transitions without a decorative timer. Current application and acceptance
scope remain in PROJECT_STATE.

The owner-approved 15 November Audio quick panel shares `IslandPopupFrame` with
the Command Lens: authored clipped artwork, a dominant output level, secondary
microphone gain and shaped mute controls. Zero volume and mute remain distinct;
muting retains the level. High contrast provides the opaque reading alternative.
Audio uses quiet pointer states without hover outlines, visible static keyboard
focus, and stable equal dimensions within mute/transport button groups. A track
strip expands inside the Audio body; overflow-only text travels left/right only
while the panel and strip are visible and the selected player is playing.
Reduced motion disables that scrolling; paused/no-player states remain still.
Playback/seek capabilities come from the existing MediaService, never fake meters.
These decisions are scoped to Audio, the approved Network, Battery and application tray popups, and existing Lens material, not all popups.

The owner-approved Network popup leads with connection name and observed internet
status; signal strength is secondary. Details contains interface/security and
Disconnect. Local name and All/Saved filters operate on observed nearby networks;
Refresh is explicit. Open networks, portal sign-in, hardware block and unverified
internet remain distinct. Network and Audio use the shared QuietButton; Settings
keeps its existing row/review contracts. Popup-only rows/reviews have distinct names.

The owner-approved Battery popup leads with combined charge, source/state and a
provider-reported time estimate. Pack details are disclosed; health and threshold
editing stay in Power Settings. Equal profile controls show the current selection
and preserve guarded confirmation, including an existing battery-care review.
Unknown charge is distinct from zero; battery absence does not imply profile
absence. Use the same clipped Island material and quiet controls. Semantic low
charge emphasis never changes policy automatically. See curated case P05.

The approved application tray uses a compact icon/name grid without per-app
sub-descriptions or resting cards. Each app remains one target: left-click requests
native activation, right-click opens that registration's styled inline menu.
Native menu-only registrations retain their primary menu behavior. Hold, Menu
and Shift+F10 remain available; touch has an unframed menu target inside the cell.
Names wrap to two lines with a plain-text full-name tooltip; attention retains a
marker and accessible state. Arrows follow grid geometry and resizing keeps the
focused app visible. Root and nested app menus retain readable command lists,
Island material and quiet controls, exact identities, checked/disabled states
and Back/Escape navigation. Compact Rail icons stay unchanged. P09 supersedes
P06's row composition while retaining its native action/menu contracts.

The approved Calendar popup separates month navigation from the selected-day
agenda in wide layouts. Narrow layouts lead with the day and disclose the date
picker. Calendar/New event remain the primary footer pair; Briefing is a labelled
header control. Events first open a read-only inline preview with explicit Open
event; Back/Escape return to the day. Keep today, selection and focus distinct,
source/timezone/error truth and exact event identity. Calendar data/reminders and
full editing remain in their existing owners. See curated case P07.

The approved notification inbox keeps All/Unread and local search separate from
read state. Opening reads one version only; in Unread, an opened record stays
visible until closed. Details expose only exact live app actions. Dismiss, Mark
all read and guarded Clear all remain distinct. Quiet mode explains critical/
transient suppression truthfully; session commitments remain outside history.
Use the same Island material and quiet controls. Insights/toast/provider contracts
remain unchanged. See curated case P08.

The approved Power quick chooser uses one compact icon/short-label dock, centered
across two rows when narrow. The owner rejected tall descriptive lists as wasted
space. Keep consequences in prepared review rather than repeating prose in
chooser/options. Selecting an action opens Now/Schedule options; it never dispatches
immediately. Confirmation, authoritative timer monitoring/edit/cancel/postpone,
recovery and authentication remain in their native owners. Preserve quiet pointer
states and visible shaped keyboard focus. This is scoped to session-action
selection, not removal of explanatory text from notifications, forms or review.
See rejection R05 and approved implementation P10.


The approved Insights workspace keeps all eight routes in one Island-framed
primary window. Compact icon/label navigation replaces generic directory search
and repeated headers; narrow layouts keep a labelled drawer, Performance and Close.
Briefing prioritises observed attention and source uncertainty over telemetry.
Inbox retains exact-version read/live-action and clear guards, with session
commitments separate. Timeline/packages/Wiki use local filters; task selection
never executes and results stay tied to the exact task. Reports retain explicit
scope/Generate/Open and private exports. Narrow list/detail views have visible
Back, focus closes an obstructing drawer, and long output has a bounded keyboard
scroll region. Provider/action ownership, Performance/shared controls and expanded
Senomy remain unchanged. See P11; runtime publication does not imply hardware or
physical-input acceptance.

The owner-directed Performance workspace retains its searchable file-tree directory,
folder disclosure and direct resource leaves. Improve that structure rather than
replacing it with a flat menu. Keep quiet rows, visible selection/focus and the
same shaped search/control grammar as the Island frame. Tree leaves and local
resource tabs share exact view identity; sidebar/drawer share query and expansion.
Overview compares CPU/memory histories beside top processes; the process inspector
pins identity, Back and review controls at narrow widths. Unknowns, missing history
and unsupported capabilities remain explicit. Navigation never dispatches a signal,
restart or workload. Existing action guards and the single session sampler remain.
See P12; this scoped direction does not restyle Insights or the generic directory.

The approved Control Centre uses the same Island perimeter, artwork and quiet
control grammar. Its overview offers direct output/microphone controls, connection
and power observations, explicit DND On/Off and compact destinations; omit an inert
media strip when no player exists. Preserve the searchable tree in compact and full
Settings, exact dynamic identities, local subview choices, back/forward/session pins
and source availability. Detailed commands reuse scoped measured/wrapping controls.
Full Settings remains the same workspace in its native move/resize/maximise/close
host; mode switching, dirty edits, modal reviews and drawer/body focus stay guarded.
Equivalent standard QML primitives avoid inline-type reload incompatibility in the
published overview. This does not change providers, the sampler or unrelated shared
controls. See P13; staged review does not substitute for real device acceptance.

The remaining quick controls and deeper editors follow P14: Bluetooth keeps explicit
scan separate from local search/filters and inline details; toasts bound message and
exact-action scrolling separately, with pinned opaque session commitment controls.
Keyboard controls show observed ownership/visibility and preserve default Cancel.
Mixer direction/search/grouping, readable account fields and display draft/recovery
views reuse existing owners. Workspace keyboard focus reveals overflow without
activating a workspace. The independent companion is removed by owner direction;
the original expanded Island composition/art and Insights remain. Shared frames,
palette, action engines and 72px Rail reservation are retained.

Rail backgrounds use the expanded Island's existing skin artwork, crop and
transparency inside each compact seven-pixel chamfer, including collapsed/message
Senomy. Keep separate instruments and transparent gaps. RailIslandBackground is a
passive fill; SilverIslandFrame retains its existing stroke/reflection and provides
an opt-out for its old solid fill. Per-role image overrides still take precedence;
opaque high contrast and a dark absent-image fallback protect reading. Do not change
layout, anchors, input, feedback or the preserved expanded panel for this material
extension. See P15.

## Shared native anatomy

| Component | Rule |
| --- | --- |
| Ordinary command | Content-aware measured width/height, 20px standard horizontal safe inset, 10px vertical inset, 8px internal gap; 44px standard / 48px touch target |
| Symbol command | Centered symbol with useful compact target; do not apply text-only padding blindly |
| Search result | Separate icon slot, readable label and optional metadata; retain exact activation identity and full accessible context |
| Menu/choice | Wrap meaningful action labels, current choice uses quiet fill; hover and keyboard focus stay distinct |
| Task directory | Readable command titles, subordinate exact codes, selected details and one explicit Run action |
| Settings header | Title/window controls first; distinguish compact/full mode; reflow rather than crush controls |
| Network action | Separate observed connection state from the guarded action; names wrap and rows grow |
| Form control | Preserve native role, focus, caret/selection and meaningful label; callers consume implicitHeight |

DirectoryStyle owns corner-safe content allocation:
`ceil((frameInset + frameCorner + controlGap) / 4) * 4`.
The current 6px inset, 5px corner and 8px gap place text at 20px, 9px beyond the
corner tangent. Keep the authored outline; vertical breathing room and internal
icon/text gaps have separate roles. Icons, checks and trailing indicators get
independent slots. Ordinary text never occupies a corner slot.

Measured-width callers must consume minimumContentWidth or change topology.
Wrap long command labels and safety text; stack/flow peers when needed. Never
shrink text to rescue fixed-width layout. Elide variable filenames/window titles
deliberately while retaining accessible identity and location.

## States and interaction

Provide rest, hover, keyboard focus, active/open, selected, disabled, loading,
empty, warning and error states. Location/selection uses quiet fill and weight;
it does not automatically mean keyboard focus or show an animated trace.
Preserve actual selected/open indicators. Suppress automatic first-row focus
outlines after pointer opening without suppressing deliberate keyboard focus.

Use existing finite angular feedback for applicable controls. Preserve the scoped
workspace/Power border-glow exception and authored frame animation. Do not expand
that exception into an unrelated interaction system. The native frame's backing,
clipping and input region follow the same authored silhouette.

Popup coexistence, opening leases, dirty forms and protected modal reviews follow
[ARCHITECTURE](ARCHITECTURE.md). Visual cleanup cannot weaken those semantics.

## Responsive input and motion

Support landscape/portrait, narrow/wide work areas, scaling and larger text.
Navigation can become a visible drawer; focus returns to its toggle when closed.
Expose close, navigation and meaningful actions without relying on hover/gestures.
Touch-oriented controls use the current larger targets and adequate spacing.
Scrolling must keep safety/navigation controls reachable and accommodate an OSK.

Motion explains state transitions and respects the shared reduced-motion policy.
Freeze decorative light/rotation when appropriate and avoid hidden repainting.
Do not confuse a short visual feedback timer with a functional dwell, deadline,
notification lifetime or confirmed session schedule.

### Native motion

Native size, output and anchor must be resolved before presentation. Retain authored
corners and silhouettes at final scale; move/reveal internal presentation rather
than interpolating Wayland window dimensions. The trigger remains visible. Keep
layout, data and selection immediate; no chart-sample interpolation or result-row
stagger. `appearance/tokens.json` owns these initial hypotheses; `Theme` is its
generated projection and `Motion` applies live reduced-motion policy.

| Role | Normal duration | Movement |
| --- | ---: | --- |
| Hover / selection | 90 / 110 ms | Static targets; finite emphasis |
| Qt menu / dismissal | 120 / 0 ms | Opacity only |
| Compact popup | 160 ms | At most 4 logical px from the Rail |
| Command Lens | 180 ms | Unified frame/content opacity; 4 px |
| Expanded island | 240 ms | Unified authored surface; 6 px, scale 1 |
| Popup/island/primary retraction | 150 ms | Return toward the Rail |
| Primary content entrance | 190 ms | 4 px inside fixed geometry; Settings has no translation |
| Navigation / status response | 140 / 120 ms | Local readable opacity response |
| Directory disclosure | 180 ms | Retained rows make room, then children reveal |

`interaction/SurfaceMotion` owns only a cancellable scalar progress value.
The existing host and ShellState own native mapping, routes, leases, grabs and
protected reviews. Retarget from current progress and shorten the remaining
animation by distance. Unmap when progress actually completes; no close timeout.
The first queued native frame admits entrances, with lease checks for popups.
`NativePresentation` gates existing primary/toast hosts; it does not own routes
or native grabs. Full Settings advertises the intended/restored size before
mapping and admits content only after a matching configure/frame (or an observed
maximized state). Initial constraints then release for normal resizing. A work-area
shrink may clamp the actual window; opening no longer schedules a late resize/center. That callback is not proof of compositor presentation or scanout.

Quick grabs first admit the popup alone and add Rails only after native keyboard
ownership. Qt item focus alone is not proof of native focus. Closing quick popups
release their input region, child menus and grab immediately.
Same-token reopening can reverse retained presentation. Replacement, anchor loss
and capture hide abandon old presentation immediately rather than competing with
a new owner. Reduced motion sets displacement and durations to zero while keeping
feedback, focus and all guards. Functional hover dwell and scheduling/notification
deadlines retain their existing owners and durations.

Prepare request-dependent content before mapping; retain a Session editor during
an unfinished same-token retraction and reset only for a fresh mapping. Content
changes keep their native anchor. Month/day, local disclosures and report arrival
use local responses; no telemetry-driven page fade or sample-value interpolation.

Qt Popup owns menu focus and transition completion. Directory identity reconciliation
preserves unaffected delegates; search skips branch choreography. No new effect
layer, sampler, lifecycle coordinator or temporary morph window is introduced.
The owner authorized application of the full revamp; publication and verification
status belong in PROJECT_STATE. This does not confer aesthetic or hardware
acceptance. Native scene readbacks, compositor samples and queued-frame timing
have distinct limits; none alone certifies scanout or whole-device smoothness.


## Interface language

Commands name the next operation: Connect, Disable Wi-Fi, Refresh, Run check.
Use sentence case outside established display headings. Keep technical provider
prose out of ordinary action labels. Display observations separately: Connected,
Scanning, Unavailable, Running, Sign-in required, Internet access unverified.
Unknown is neither disconnected nor healthy; accepted dispatch is not success.

Show distinguishing metadata once. Explain consequences before disconnect,
restart or destructive operations. Keep confirmation/cancellation and provider
errors explicit. Error/empty states name the affected source and useful recovery;
avoid generic reassurance and repeated product names.

## Authentication Island

The owner-approved login/lock direction uses one clipped credential Island, the
configurable ivory/black/silver metalheart background, existing type roles and quiet
controls. Account, password, feedback and explicit session/keyboard choices establish
the reading order. The chibi is currently omitted from both authentication layouts;
shared desktop character assets remain available. SDDM blurs public wallpaper;
Hyprlock uses desktop screenshot blur unless both live compositor capabilities are
explicitly enabled. Preserve separate recovery, credential clearing, guarded power
and focused-field scrolling on short outputs. Offline projections do not establish
native authentication or lock security acceptance. See curated case P16.

## Acceptance

Inspect actual native output against the relevant reference, then record specific
hierarchy, spacing, type, state and input findings. Offscreen renders establish
only the hosted composition/logic they exercised; physical touch, grabs, Wayland
placement, fractional scale, hardware and authentication require their own
acceptance. Report remaining limits in [PROJECT_STATE](PROJECT_STATE.md), and
keep detailed receipts scoped and dated.
