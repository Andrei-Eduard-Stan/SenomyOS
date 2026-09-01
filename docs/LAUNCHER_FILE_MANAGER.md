# SenomyOS Launcher and File Workspace

## Status

**Selected direction:** Command Lens  
**Selected:** 2026-08-15  
**Implementation state:** Command Lens, scoped Thunar workspace/action layer,
and namespaced GTK 3 theme are deployed and manually verified; the launcher
binding and global GTK selection remain separate approval stages

The selected visual source is:

```text
docs/design-references/command-lens-rofi-thunar.png
```

It combines two related but deliberately separate tools:

- **Rofi / Command Lens:** the fast, temporary entry point for applications,
  files, windows, and allowlisted SenomyOS actions;
- **Thunar / File Workspace:** the persistent place for browsing, comparing,
  previewing, organizing, and acting on files.

Rofi must not grow into a second file manager. Thunar must not become a
dashboard or imitate Eww panels. Their common visual language should make them
feel like parts of one desktop without hiding their native roles.

## Current reference-system facts

Read-only inventory on 2026-08-15 found:

- `Super+R` now launches Command Lens and `Super+E` launches the scoped Thunar
  workspace through synchronized tracked/live Hyprland configuration;
- Rofi 2.0.0, Wofi 1.5.3, Thunar 4.20.9, and GTK 3.24 are installed;
- Rofi originally had no user configuration tree; the reviewed Command Lens
  files are now deployed through recorded transactions;
- Thunar retains `accels.scm` and the unrelated `Open Terminal Here` action;
  the deployed merge adds `Copy Path` and `Copy SHA-256`;
- the default GTK preference, icon theme, and UI font remain stock Adwaita;
  SenomyOS is installed as a namespaced GTK 3 theme for scoped launches;
- thumbnailing, GVFS integration, archive integration, removable-device
  helpers, and Catfish are not currently installed;
- the real live files are outside this repository and must be deployed
  deliberately.

These are inventory facts, not permanent product requirements. Optional
packages remain proposals until the user reviews and approves installation.

## Product outcome

The everyday flow should be:

```text
Super+R
  -> Command Lens opens on the focused monitor
  -> type once
  -> choose an application, file, window, or safe action
  -> Enter opens the result
  -> file results hand deeper work to Thunar
```

The launcher should usually disappear immediately after a successful action.
Thunar should remain a normal application window that can tile, float, move
between workspaces, and survive launcher use.

## Command Lens visual contract

### Geometry

- 760–840 logical pixels wide on the 1920x1080 reference display;
- centred horizontally in the upper third of the focused monitor;
- capped to the focused monitor's logical work area;
- approximately 420–540 logical pixels tall depending on result count;
- 4–6px corner radius, one outer border, and no full-screen card backdrop;
- near-black surface with enough opacity for text readability;
- optional compositor blur only when it remains legible and inexpensive.

Compact, narrow, and touch profiles must reduce result count or reflow metadata
before shrinking readable text. Rofi remains keyboard-first; pointer selection
is supported, but a separate visible route is required for a genuinely
touch-first application launcher.

### Hierarchy

1. One query field labelled `RUN //`.
2. Four stable scopes: `APPS`, `FILES`, `WINDOWS`, `ACTIONS`.
3. One grouped result list, not a tile grid.
4. Selected-row title, bounded metadata, and right-aligned keyboard hint.
5. A restrained footer for navigation/help only when needed.

The selected row uses a faint periwinkle surface tint, a thin left accent rule,
and clear foreground text. Unselected rows use spacing and separators rather
than individual cards.

### Modes and truthful functionality

#### APPS

- Rofi `drun` is the source of installed desktop applications.
- Names, descriptions, icons, and launch commands come from desktop entries.
- Frequently used or recent ranking is added only if it can be local, bounded,
  private, and predictable.

#### WINDOWS

- Rofi's window mode exposes currently managed windows.
- Selecting a result focuses the real window rather than launching a duplicate.
- Workspace identity may be shown only when the compositor source is reliable.

#### FILES

- A project-owned script provides bounded local file results.
- Search roots come from portable defaults plus explicit user bookmarks.
- The initial version does not index the whole filesystem, hidden caches,
  browser profiles, credential stores, or mounted remote locations.
- Results contain a display name and shortened parent path; the underlying path
  is passed as data, never interpolated into a shell command.
- Enter opens the file with its default application. A directory opens in
  Thunar. Optional secondary actions may reveal the parent directory or copy
  the path.

#### ACTIONS

- Actions are a curated registry, not arbitrary shell input.
- Suitable first actions include opening Senomy Insights, Performance,
  Control Centre routes, screenshot capture, shell recovery doctor, lock, and
  logout/reboot/shutdown confirmation entry points.
- Disruptive or destructive actions must route to an explicit confirmation
  surface; they never execute directly from the first result click.

### Keyboard and pointer behavior

- `Super+R`: open the Command Lens;
- typing: filter the active scope;
- arrows or `Ctrl+J` / `Ctrl+K`: move selection where Rofi supports it;
- `Enter`: perform the primary result action;
- `Escape`: close without side effects;
- mouse click: select and activate a visible result;
- scope shortcuts should be visible and configurable rather than hidden lore.

Exact shortcuts remain implementation details until tested against Rofi 2.0
and existing Hyprland bindings.

## Thunar File Workspace visual contract

### Geometry and hierarchy

Thunar remains a conventional GTK file manager with SenomyOS styling:

1. compact navigation toolbar;
2. breadcrumb/location path;
3. narrow Places and Devices sidebar;
4. detailed file list as the default working view;
5. optional right preview/metadata inspector;
6. one quiet status line;
7. native menus and dialogs where required.

The file list is the primary surface. It must not become a grid of cards.
Selected rows use the same restrained periwinkle treatment as Rofi. File type,
size, and modified time remain aligned and readable. Preview content is bounded
and never reduces the file list below a useful width.

### Native features to preserve

- detailed, icon, and compact views;
- tabs;
- F3 split view;
- hidden-file toggle;
- rename, copy, move, trash, restore, and properties;
- keyboard navigation and native context menus;
- location entry and breadcrumbs;
- preview pane where supported;
- removable and remote locations only when their providers are installed.

### Proposed connected features

The first safe custom actions should be:

- `Open Terminal Here` using the selected terminal;
- `Open in Visual Studio Code` when `code` is available;
- `Copy Path` using a detected Wayland clipboard provider;
- `Search This Folder` by opening Command Lens / FILES with a validated root;
- `Calculate SHA-256` as a read-only, bounded operation with visible output.

Archive extraction/creation, thumbnailing, trash/mount support, removable media,
and richer content search should use standard Arch/Xfce providers. Missing
providers produce an unavailable capability rather than a dead menu item.

## Shared appearance model

Rofi has its own `.rasi` theme. Thunar receives its appearance from GTK 3 and
the icon theme. They therefore share tokens but not one stylesheet.

```text
base             #08090b
surface          rgba(10, 12, 15, 0.96)
surface-raised   rgba(15, 17, 21, 0.98)
foreground       #f1f1f4
muted            #92959f
dim              #666a74
border           rgba(255, 255, 255, 0.18)
border-strong    rgba(255, 255, 255, 0.34)
accent           #9892e8
success          #7fa98a
warning          #c8a367
danger           #c46f7d
radius           4–6px
spacing          4 / 8 / 12 / 16 / 24 / 32
font             JetBrainsMono Nerd Font
```

Semantic colours are used only for real status. There are no decorative red
warnings, neon glows, fake telemetry, or additional Senomy mascot portraits.

### Appearance preferences

The future Appearance route may expose only validated choices:

- accent palette using the existing SenomyOS palette registry;
- Standard, Compact, or Touch density;
- restrained transparency/blur strength;
- icon-theme selection from an installed allowlist;
- Rofi result count and default scope;
- Thunar default view, preview visibility, hidden-file visibility, and
  single/split-pane preference.

Rofi preferences are rendered into a user-owned theme/config layer. Thunar
behavior preferences are applied through validated Xfconf keys. A GTK theme
switch affects other GTK applications, so it requires broader visual QA and
must not be presented as Thunar-only.

## Repository and deployment boundaries

The repository-owned source shape is:

```text
components/
  launcher/rofi/
    config.rasi
    themes/command-lens.rasi
    scripts/
  file-manager/thunar/
    actions.json
    thunar.desktop
    scripts/senomy-file-workspace
    scripts/senomy-thunar-action
  themes/gtk3/SenomyOS/
  themes/gtk3/SenomyOS-Touch/
  themes/icons/SenomyOS/        # only if a complete maintained icon layer exists
deploy/
  manifest.json
  README.md
profiles/
```

The real live targets remain separate:

```text
$XDG_CONFIG_HOME/rofi/
$XDG_CONFIG_HOME/Thunar/
$XDG_CONFIG_HOME/gtk-3.0/ or an installed GTK theme path
the user Xfconf database
$XDG_CONFIG_HOME/hypr/hyprland.conf
```

`scripts/senomy-deploy.sh` owns plan, private checksummed backup, prepared
receipt, atomic install, verification, and drift-aware rollback. Rofi is a
deployed complete-file component and passes isolated parser, mode, path-safety,
wrapper, and live visual checks. Thunar uses the one supported deterministic
merge strategy: unrelated custom actions are preserved and only registered
SenomyOS IDs are replaced. It does not replace `accels.scm` or write Xfconf or
GTK preferences. The tracked and live Hyprland files are synchronized only as
a separate reviewed component. A user `thunar.desktop` override makes normal
application-menu launches use the wrapper without editing the distribution
desktop entry.

The implemented Rofi source contains:

```text
components/launcher/rofi/
  config.rasi
  themes/command-lens.rasi
  scripts/senomy-command-lens
  scripts/senomy-rofi-files
  scripts/senomy-rofi-actions
```

`senomy-command-lens` registers native `drun` and `window` modes beside the
project-owned Files and Actions adapters, asks Rofi to use the monitor that
contains the focused window, and computes an explicit 800px or narrow-safe
width from that focused monitor. This avoids Rofi 2.0 media-query behavior that
expanded an 800px window as a percentage of the full monitor. The default Files policy searches only existing
standard user folders to depth five, for at most 500 results and two seconds
per root. An optional
`${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/file-search.json` may replace those
roots with at most sixteen relative paths beneath the real home directory and
may lower or raise only documented bounded limits.

Files mode excludes hidden paths and remote traversal, carries the original
path in `ROFI_INFO`, revalidates its real path on activation, and hands opens
and `Ctrl+Shift+Enter` reveals to `senomy-file-workspace`. The wrapper uses the
supported FileManager1 interface for reveal rather than an unsupported Thunar
`--select` option. Actions mode maps opaque
IDs to existing SenomyOS surface, capture, and file-workspace entry points. It
does not accept custom input and does not expose logout, reboot, shutdown, or
arbitrary commands.

The implemented Thunar action source contains:

```text
components/file-manager/thunar/
  actions.json
  thunar.desktop
  scripts/senomy-file-workspace
  scripts/senomy-thunar-action
scripts/thunar-uca-merge.py
```

The registry currently provides Copy Path and Copy SHA-256. Deployment builds
and validates a candidate from the current live `uca.xml`, retains unrelated
actions such as the existing Open Terminal Here action, and records the exact
prior file for rollback. The helper accepts only those two verbs and bounded
absolute paths. Apply and rollback refuse to continue while Thunar is running.
The workspace wrapper applies the selected `GTK_THEME` only to a fresh Thunar
daemon. It starts that daemon in a collected transient user service so D-Bus
activation cannot discard the theme environment, with a detached `nohup`
fallback when the user manager is unavailable. It waits for the service before
opening one explicit window or sending one FileManager1 reveal request. An
existing session is reused without restart or theme mutation.
The user `thunar.desktop` override calls the installed wrapper through
`~/.local/bin` explicitly and has no PATH-dependent `TryExec`; this keeps the
override eligible in display-manager sessions whose PATH contains only system
binary directories.
Automatic density uses the standard theme unless the bounded appearance
preference reports a touch font scale. The separately installed touch variant
imports the same canonical theme and raises primary controls and rows to 48px;
notebook-dialog controls retain an effective approximately 48px target while
using a smaller content minimum so native dialogs fit a 1080px screen.

## Implementation stages

### A. Launcher prototype

1. **Complete:** add repository-owned Rofi config, Command Lens theme, and a
   wrapper.
2. **Complete:** implement APPS and WINDOWS with native Rofi modes.
3. **Complete:** add bounded FILES and allowlisted ACTIONS scripts with
   hostile-path fixtures.
4. **Complete:** deploy and open it manually without changing `Super+R`.
5. **Complete:** capture and compare it with the selected design; the first
   live capture exposed inherited Adwaita rows and incorrect percentage width,
   which were corrected before binding integration.

### B. Thunar appearance prototype

1. **Complete:** build the namespaced GTK 3 theme in a repository staging path
   with the shared portable token contract.
2. **Complete:** launch an isolated test Thunar process with the staged theme.
   A separate GTK 3 application also passed visual QA; a GTK 4 control proved
   the toolkit boundary remains separate.
3. **Complete:** standard toolbar, sidebar, rows, native
   Preferences/Properties dialogs, and a 640px narrow layout passed clean
   post-deployment captures. The audit exposed and corrected unreadable native
   notebook pages, a first-launch D-Bus theme-environment loss, and a touch
   Preferences dialog taller than the 1080px screen. A later ordinary
   application-menu launch exposed a PATH-dependent `TryExec` that invalidated
   the user desktop override; the corrected entry now resolves ahead of the
   system entry. Standard and touch main windows and dialogs now pass the final
   visual check.
4. **Complete:** add the first bounded custom actions separately from styling,
   using a deterministic preserve-and-replace merge.
5. Review optional package installation before installing anything.

### C. Appearance integration

1. Add shared, versioned theme preferences.
2. Generate Rasi and GTK variants from the same semantic tokens.
3. Connect only allowlisted Appearance controls.
4. Verify other GTK applications before allowing a global theme switch.

### D. Deployment

1. **Complete for Rofi:** show the complete source and deployment diff.
2. **Complete for Rofi:** back up live user configuration through receipts.
3. **Complete:** deploy Rofi and test all four scopes manually.
4. **Complete:** change `Super+R` from Wofi to the verified Rofi wrapper and
   `Super+E` to the file-workspace wrapper in tracked and live Hyprland files;
   the deployment post-check reported no configuration errors.
5. **Complete:** deploy the Thunar wrapper/action layer only while Thunar is
   closed, install the namespaced GTK 3 theme without selecting it globally,
   and verify a single themed live window plus the custom-action submenu.

## Acceptance criteria

- Command Lens opens once, on the focused monitor, without creating a daemon
  or duplicate process tree.
- APPS, FILES, WINDOWS, and ACTIONS show truthful bounded results.
- Escape closes cleanly; Enter performs the documented primary action.
- File paths containing spaces, quotes, leading dashes, or non-ASCII text are
  treated as data and cannot become shell syntax.
- Thunar retains native file operations, menus, keyboard behavior, and dialogs.
- Rofi and Thunar share visual tokens without pretending to be the same app.
- Standard, compact, narrow, and touch profiles remain readable.
- No global GTK change is deployed before testing other GTK applications.
- Live user files have a documented backup and rollback path.
- Tracked/live Hyprland copies match after the eventual launcher switch.

## Canonical ImageGen prompt

Use the following prompt with:

- a current private desktop capture as current-state reference only;
- `docs/design-references/obsidian-rail-approved.png` as the Obsidian Rail
  visual-language reference;
- `docs/design-references/cathedral-deck-approved.png` as the information-density
  reference.

Do not commit a desktop capture containing private application content.

```text
Use case: ui-mockup
Asset type: SenomyOS desktop UI concept showing a coordinated Rofi launcher and Thunar file manager
Primary request: Create the “Command Lens” direction. Rofi is the focused hero interaction in the upper centre of a realistic 1920x1080 Linux desktop, open over a restrained Thunar file workspace. Show one production-quality desktop frame, not a moodboard and not multiple concepts.
Input images: Image 1 is the actual current SenomyOS desktop and Rail implementation; Image 2 is the approved Obsidian Rail visual language; Image 3 is the Cathedral Deck information-density reference. Preserve their near-black technical character, thin borders, restrained periwinkle accent, and compact hierarchy without copying obsolete layouts.
Target dimensions: 1920x1080 desktop.
User goal: quickly launch an application, switch a window, run a safe command, or find a file, then continue deeper file work in Thunar.
Rofi composition: a 760–840px wide upper-centre command surface, near-black translucent background, 4–6px corner radius, one strong search field labelled exactly “RUN //”, compact mode tabs labelled exactly “APPS”, “FILES”, “WINDOWS”, “ACTIONS”, and a single grouped result list with realistic entries such as “Visual Studio Code”, “Thunar”, “Firefox”, and “Senomy Insights”. Use small monochrome icons, title plus muted metadata, and right-aligned keyboard hints. Selected result gets a subtle periwinkle surface tint and left accent rule. Avoid cards within cards.
Thunar composition: visible behind Rofi as a coherent dark GTK file workspace, one narrow Places sidebar, breadcrumb/path bar, detailed file list, and a restrained right preview/metadata inspector for one selected image. Keep standard recognizable file-manager affordances and realistic filenames. Show split view as available but not enabled.
SenomyOS language: #08090b base, near-black translucent raised surfaces, #f1f1f4 foreground, #92959f muted text, #9892e8 accent, thin white borders, JetBrains Mono-like typography, subtle gothic atmosphere only through texture and precision. Keep the Obsidian Rail visible at the bottom. No additional mascot portrait.
Functionality cues: search scope, result category, keyboard navigation, launch/open action, recent items, safe file handoff to Thunar.
Constraints: realistic Linux desktop UI; no Windows or macOS chrome; no neon cyberpunk HUD; no giant title; no excessive cards, gradients, glows, badges, or rounded pills; no fake system warnings; no terminal text wall; readable unclipped labels; no watermark.
```

The prompt is for design exploration. It is not a claim that every visible
detail is already available through Rofi, Thunar, or installed providers.
