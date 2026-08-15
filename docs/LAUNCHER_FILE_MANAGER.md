# SenomyOS Launcher and File Workspace

## Status

**Selected direction:** Command Lens  
**Selected:** 2026-08-15  
**Implementation state:** design approved; no live configuration deployed

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

- `Super+R` still launches `wofi --show drun` from Hyprland;
- Rofi 2.0.0, Wofi 1.5.3, Thunar 4.20.9, and GTK 3.24 are installed;
- neither Rofi nor Wofi has a user theme/configuration tree;
- Thunar currently has `accels.scm` and one `Open Terminal Here` custom action;
- the GTK theme, icon theme, and UI font are effectively stock Adwaita;
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

The planned repository-owned sources are:

```text
components/
  launcher/rofi/
    config.rasi
    themes/command-lens.rasi
    scripts/
  file-manager/thunar/
    uca.xml
    accels.scm
    defaults/
  themes/gtk3/SenomyOS/
  themes/icons/SenomyOS/        # only if a complete maintained icon layer exists
deploy/
  user/
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

Deployment must back up user-owned live files, merge rather than blindly
overwrite Thunar actions/bookmarks, validate generated Rasi/XML/CSS, and retain
a rollback path. The tracked and live Hyprland files are synchronized only in
a separate reviewed step.

## Implementation stages

### A. Launcher prototype

1. Add repository-owned Rofi config, Command Lens theme, and a wrapper.
2. Implement APPS and WINDOWS with native Rofi modes.
3. Add bounded FILES and allowlisted ACTIONS scripts with fixtures.
4. Open it manually without changing `Super+R`.
5. Capture and compare it with the selected design.

### B. Thunar appearance prototype

1. Build the GTK 3 theme in a repository staging path.
2. Launch a test Thunar process with the staged theme where possible.
3. Verify toolbar, sidebar, rows, preview, menus, dialogs, destructive states,
   narrow width, and touch density.
4. Add custom actions separately from styling.
5. Review optional package installation before installing anything.

### C. Appearance integration

1. Add shared, versioned theme preferences.
2. Generate Rasi and GTK variants from the same semantic tokens.
3. Connect only allowlisted Appearance controls.
4. Verify other GTK applications before allowing a global theme switch.

### D. Deployment

1. Show the complete source and deployment diff.
2. Back up live user configuration.
3. Deploy Rofi and test it manually.
4. Change `Super+R` from Wofi to the verified Rofi wrapper in tracked and live
   Hyprland configs, then run `hyprctl configerrors`.
5. Deploy the GTK/Thunar layer only after visual and functional QA.

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
