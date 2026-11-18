# Native Thunar workspace

Thunar owns browsing, previews, search, tabs, split view and file operations.
SenomyOS supplies sculpted chrome and pane framing, a namespaced GTK3 theme,
a process-scoped native workspace module, a launcher, an explicit layout/Places
profile and five contextual clipboard actions. The owner approved application of
the reviewed sculpted rebuild on 18 November; the installed native Home window
was reopened and visually checked. `PUBLICATION.json` below records the result.
The product owner is `docs/PRODUCT_SPEC.md` (Everyday capabilities); visual rules
remain in `docs/DESIGN_SYSTEM.md` and `appearance/tokens.json`.

## Native controls

The optional profile places Menu, Back, Forward, Parent, location, Search, view
switcher, Split view and New tab in the toolbar, with Places and embedded image
previews. Details shows Name, Size and Date modified; the menu strip is replaced
by the native menu button. The module derives the heading from the current native
window/folder title, keeps toolbar glyphs compact and projects technical metadata without changing filename
semantics. Long headings elide at the end; the real path retains a full-path
tooltip.
Existing extra/custom toolbar items are retained after this core group. Menus and
native overflow remain available when the window narrows; details columns can
scroll. View/sort and other native choices are not reset by the launcher.

| Native command | Default shortcut |
| --- | --- |
| Search / cancel search | Ctrl+F / Escape |
| Split view | F3 |
| New tab / close tab | Ctrl+T / Ctrl+W |
| Enter a location | Ctrl+L |
| Back / parent folder | Alt+Left / Alt+Up |
| Show hidden files | Ctrl+H |

These are Thunar 4.20 defaults, verified against the native action table; user
shortcut overrides remain authoritative. Native menus show the current bindings.

## Resizing and Places

With the optional native module loaded, the workspace composes a folder heading,
real path, native navigation, dense ruled file table and object inspector. One new
transparent chrome sculpture is confined to the header and lower outer corners;
labels, file rows and controls remain native GTK widgets. The quiet reading plane
uses a near-opaque dark ground, with local backing under the heading labels.
Active Places uses a silver steel plate and selected files use blue-gray metal.
A native SVG pane frame surrounds the file table and inspector.

The Cairo handler clips the client surface at 12px chamfered corners, paints the
semantic ground at .96 alpha, the sculpture at .95 alpha in its bounded zones,
and a dark scrim at .08 alpha. Artwork is loaded once; GTK damage repaints it
without a timer. Only a window with the installed handler receives the material
class; without the module the theme retains its dark fallback. Missing artwork
is reported and retains the dark ground. Desktop transparency depends on the
compositor; this module supplies no blur or whole-window opacity.

At workspace widths of at least 1120px the object inspector docks beside the real
file view; below that width the same widget moves into a scrollable native
GtkPopover opened by **Inspector**. The dock also scrolls at short heights.
Hidden dock/command regions release their grid columns to the native body and
toolbar. Mode changes are coalesced outside GTK grid allocation.

The inspector reads the native selection cache/current directory through public
Thunarx metadata. It shows actual path, size, modified time, permissions and owner
when available; multiple selections are identified without inventing aggregates.
Visible local objects receive an asynchronous owner lookup. Visible local
directories enumerate at most nine immediate entries to display eight plus a
truthful “More items…” cue; remote previews are unavailable and no traversal is
recursive. Selection changes, unmap and destruction cancel work; generation and
weak-window checks reject stale callbacks. Inspector command buttons dispatch
registered native accelerator paths, with unavailable actions disabled. Thunar
retains operation semantics and guards; these operations were not exercised by
the candidate captures.

Controls use a quiet silver layer and fine border on hover (.065 fill/.30 border
alpha), with distinct checked (.09) and pressed (.13) fills. The active location
and view retain a silver line, keyboard focus has a static outline, and Places
selection remains distinct from row hover. Background/border transitions are
120ms ease-out under GTK's native animation policy; targets and layout stay fixed.

Details keeps Name and its metadata together: Name responds to the available
width between 112px and 680px (740px in touch density), while initial metadata
widths are 100/144px (112/168px touch). The last visible metadata column expands
into unused table space; this keeps its text near the other fields without
stretching Name across a wide display. Native metadata alignment is retained.
Metadata uses the existing JetBrainsMono technical role at 10pt (11pt touch);
filenames, labels and controls retain the readable sans body role.

Metadata widths are seeded once per native column. Allocation changes adjust
only Name while its native fixed width still matches the module's last value.
A manual fixed-width change to Name relinquishes automatic sizing for that
column; manual metadata widths remain native. This is same-window ownership:
new columns in a new daemon receive initial policies again, rather than promising
persistence of manual widths across daemon restarts. Native truncation and scrolling
remain available, so long filenames need not fit fully at every width. A height
reduction minimally reveals the focused cursor if it was previously visible,
without changing selection or pulling an intentionally scrolled-away row back
into view.

The visible **Places** header button invokes Thunar's registered side-pane toggle,
including its configured accelerator. It preserves native hidden-Shortcuts/hidden-
Tree behavior rather than forcing a replacement pane type. If the action has no
bound accelerator, the control is disabled and its tooltip points to **Menu → View → Side Pane**. The module does not automatically hide/reopen Places at a width
threshold and adds no sidebar provider or navigation model. Owner pane choices
stay native. The remapped/unbound behavior comes from the registered-action lookup;
it is distinct from the exercised default-shortcut toggle sequence.

## Launch and density

`senomy-file-workspace` opens Home; `-- /absolute/path` opens a local path and
`--select /absolute/path` reveals a selected item through Thunar's native interface.
A fresh owned daemon receives the namespaced theme; an existing daemon is reused
with its current environment. No process is stopped to apply styling.

`SENOMY_FILE_DENSITY=standard|touch|auto` selects density. Auto uses the existing
SenomyOS profile/preferences; standard is the fallback. Touch enlarges controls,
rows and text. `SENOMY_GTK_THEME` selects the namespaced base theme when explicitly
set. Missing themes fall back to native Thunar with an explicit diagnostic; the
launcher does not change the desktop's global GTK/icon theme or launcher preference.

## Native module and host build

`native/senomy-thunar.c` supplies scoped material, icons and native column policy;
`native/senomy-workspace.c` and `.h` compose the heading, inspector and native
window controls. The GtkApplication `window-added` hook composes before initial
measurement/map; show/map/parent hooks cover later native widgets. Header drag,
edge resize and minimize/maximize/close use GTK window APIs. The module preserves
the original toolbar, native actions, tabs, split views, search and filename
semantics. It adds no polling, replacement file model or file-operation engine.

The sculpture is loaded from the selected base theme under
`${XDG_DATA_HOME:-$HOME/.local/share}/themes/`, normalizing GTK variant and `-Touch`
suffixes. Decoding is bounded to 1672×941 with aspect ratio preserved. The exact
built-in image-generation prompt, original source and hashes are retained in
`appearance/file-manager/gtk3/SenomyOS/gtk-3.0/assets/chrome-sculpture-v1.provenance.json`.
The deployment plan includes that PNG and the authored `workspace-pane.svg`.

From the repository/candidate root, `python3 scripts/build-thunar-ui.py` builds
`components/file-manager/thunar/native/libsenomy-thunar.so` using this host's `cc`,
`pkg-config`, GTK3 and installed `thunarx-3` development headers/libraries
(Thunarx 4.20.10 on this host). Both native C sources are linked. It installs no
packages and publishes no live files. Rebuild for the intended host ABI; the generated shared
object is not a universal cross-architecture payload. The existing `thunar`
deployment component includes the module as a regular file under
`${XDG_DATA_HOME:-$HOME/.local/share}/senomyos/thunar/`.

On a fresh owned daemon with the selected theme available, the workspace wrapper
appends that installed regular, non-symlink module to existing `GTK_MODULES`.
Incumbent module entries remain intact. If this module is absent or a symlink,
the wrapper keeps native/themed fallback behavior. Existing daemons retain their
original environment; launch never stops or replaces them. GTK_THEME and icon
selection stay inside this Thunar process rather than changing desktop-wide
GTK/icon preferences. The separate capture module is not deployed.

## One-time layout and exact restore

Installing helpers/themes and applying layout are separate operations. Deployment
uses the existing `gtk3` and `thunar` component plan/apply/rollback transactions;
inspect their plans and retain their deployment receipts. The `thunar` transaction
merges registered actions into `uca.xml`, preserving unrelated user-owned actions.
Actions whose dependencies are unavailable are omitted and reported by the merger.

After installation, inspect `senomy-thunar-layout plan`. Applying the optional
profile uses `senomy-thunar-layout apply --yes`; it requires every Thunar window
and background daemon already closed and never stops them itself. It changes managed
profile values and explicitly prepares native Places bookmarks, recording exact
previous preference values and bookmark bytes/mode/absence in
`${XDG_STATE_HOME:-~/.local/state}/senomyos/thunar-layouts/`. Its output names the
receipt. Reapplying matching settings makes no writes. The resize profile also
sets native `/last-details-view-fixed-columns=true` explicitly so GTK native
fixed widths support the bounded Name/adjacent metadata policy without competing
with Thunar's expandable-Name callback. This value
is covered by the same exact preimage and owner-edit-protected rollback. The
profile also seeds a 216px sidebar and 38% Details zoom (24px icons); other native
view/sort choices remain owner-controlled. Launch never reapplies these settings.

The Places plan uses existing XDG Documents/Downloads/Pictures destinations (with
existing Home-folder fallbacks) and an existing Projects folder. It creates no
folders, adds no already-bookmarked URI and removes only an unlabelled exact Home
URI already supplied by native Home. Labelled Home aliases, remote bookmarks,
other owner entries and device/mount navigation remain. This transaction writes
`${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks`, the native GTK bookmark file
that other GTK applications may also display; it is not a private navigation store.
The read-only plan shows additions and duplicate-Home removals before application.

With Thunar closed, `senomy-thunar-layout rollback /absolute/receipt.json --yes`
restores exact preferences and the prior native bookmark bytes/mode or absence.
It refuses if a managed preference or changed bookmark file has drifted since
application, protecting later owner edits. Review such differences rather than
forcing restoration. Layout receipts restore xfconf preferences and native bookmarks; deployment
receipts restore installed files. Neither substitutes for the other. Launching
Thunar never reapplies the profile.

## Contextual clipboard actions

Select local items and open the native context menu's **SenomyOS** submenu.

| Action | Result and bound |
| --- | --- |
| Copy Path | Absolute paths, one per line; at most 100 items |
| Copy SHA-256 | Checksum output for at most 32 regular files; 30-second limit |
| Copy names | Filenames without parent directories; at most 100 items |
| Copy file links | Percent-encoded local `file:` links; at most 100 items |
| Copy project paths | Paths relative to the nearest Git/Mercurial root; at most 100 items in one workspace |

Helpers treat names as literal arguments, reject control characters and validate
the complete selection before preparing output. Project discovery checks at most
64 ancestors and supports Git worktree `.git` files. Preparation/dependency failures
leave the clipboard unchanged; a clipboard-provider write failure is reported.
These actions read selections and write the clipboard; they do not rename, move,
delete or execute selected files. Native file operations keep their own UI/guards.

## Evidence and limits

The isolated sculpted candidate receipt is
`~/.local/state/senomyos/design-examples/thunar-sculpted-20261117/`.
`COMPOSITION.md` records the current screenshot-led composition, `DOCUMENTATION.md`
indexes evidence, and `FINAL-REVIEW.md` records **ship at native-candidate scope**
after one correction round for heading contrast and narrow grid allocation.
The owner subsequently replied “Apply this rebuild”; `PUBLICATION.json` records
the installed payload parity, actual Home capture, runtime checks and exact
deployment/layout rollback receipts. `CANDIDATE.json` retains the historical
pre-approval seal. Application approval does not imply universal hardware acceptance.
Earlier themed, opaque and translucent passes are rejected composition history;
their publication receipts describe those earlier payloads only.

Actual candidate widgets run in private XDG/D-Bus Broadway, without replacement
UI. `captures/reference-wide.png` shows the 1660×900 composition.
`captures/retained.log` and the eight retained-size PNGs cover 935×760 → 640×680 →
1280×800 → 800×620 → 1600×900 → 935×360 → 1880×982 → 935×760, asserting the same
model, selected cursor, focus and visibility. Manual metadata width 132px and
Name width 280px survive growth/restoration; Places toggling retains selection
and active `Search: Design` survives narrowing/growth. The standard Name bound
is 680px. `captures/inspector-narrow-inspector-open.png` shows the actual native
800×620 popover; the wide capture shows selected-object metadata and actual
child directories. Physical column dragging/reordering was not established.

The reference-wide, retained and inspector-narrow logs record first native map
with heading/workspace ready and client sizes exactly 1660×900, 935×760 and
800×620. This establishes native preparation/geometry, not compositor first
visible buffer or timing/performance results. No artificial reveal delay or
window animation is introduced. Physical motion-policy acceptance is open.

No packages were installed. Live application followed explicit owner approval.
No live clipboard, real file mutation, native file-operation execution or nested
compositor was used. Physical
pointer/keyboard/touch, Wayland drag/resize/placement, DPI/fractional scale,
screen readers, desktop backdrop contrast and hardware acceptance remain open.
Optional thumbnail-provider warnings remain in private capture logs. Layout and
deployment still use their separate exact rollback receipts; the existing
product/design/architecture owners and `docs/PROJECT_STATE.md` retain authority.
