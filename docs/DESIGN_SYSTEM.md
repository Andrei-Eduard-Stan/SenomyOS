# SenomyOS Design System

## Approved direction

The main shell uses the **Obsidian Rail** direction: a compact bottom bar and a
right-anchored contextual Control Centre.

The separate Performance Dashboard uses the broader information architecture
from **Cathedral Deck**. It is opened from CPU/MEM/UP telemetry and is not a
Control Centre section.

Senomy Insights is a separate surface linked to the mascot and status message.

Local concept references:

- Obsidian Rail:
  `/home/Duku/.codex/generated_images/019efbe2-8acc-7161-9f04-56c1f4427d98/call_6bGKGVkvKVHWcFhB5cnHaPwW.png`
- Cathedral Deck:
  `/home/Duku/.codex/generated_images/019efbe2-8acc-7161-9f04-56c1f4427d98/call_i4FThxr2wLdg5zgzVKPFSt5L.png`
- Original functional wireframes:
  `/home/Duku/Downloads/IHvCMvnv.jpg`,
  `/home/Duku/Downloads/E0sf21hK.jpg`,
  `/home/Duku/Downloads/uQWETAHL.jpg`

The wireframes define features only. Do not reproduce their proportions.

## Character

SenomyOS is:

- dark and near-black;
- precise rather than decorative;
- technical without becoming a cyberpunk HUD;
- subtly gothic through atmosphere and identity;
- compact but comfortably readable;
- mostly squared, with slight softening where it helps separation;
- custom without imitating stock Windows, macOS, or Waybar themes.

## Colour tokens

Initial tokens for implementation and visual testing:

```text
--bg:             #08090b
--surface:        rgba(10, 12, 15, 0.94)
--surface-raised: rgba(15, 17, 21, 0.96)
--fg:             #f1f1f4
--fg-muted:       #92959f
--fg-dim:         #666a74
--border:         rgba(255, 255, 255, 0.18)
--border-strong:  rgba(255, 255, 255, 0.34)
--accent:         #9892e8
--success:        #7fa98a
--warning:        #c8a367
--danger:         #c46f7d
```

The periwinkle accent from Obsidian Rail is the product accent across all
surfaces. Cathedral Deck's garnet concept is layout inspiration, not a second
brand theme. Semantic colours appear only for real status.

## Typography

Primary UI font:

```text
JetBrainsMono Nerd Font
```

Icon fallback:

```text
Symbols Nerd Font Mono
```

Do not set the symbol-only font as the global text font.

Recommended scale:

```text
11px  metadata only
12px  compact secondary labels
13px  bar and dense table text
14px  normal panel body
16px  section title or key value
20px  important metric
```

Use tabular-looking alignment for metrics and process columns. Uppercase labels
are useful for short system headings, not long paragraphs.

## Spacing and geometry

Base spacing scale:

```text
4, 8, 12, 16, 24, 32
```

Initial targets:

- bar height: approximately 44px;
- compact pointer control target: at least 36x36px;
- touch-oriented control target: at least 44x44px, preferably 48x48px for
  frequently used actions;
- bar outer padding: 8–12px;
- Control Centre width: approximately 520–560px where space permits;
- Control Centre gap above bar: 12–16px;
- Performance Dashboard: broad relative width, capped to the work area;
- panel corner radius: 4–6px;
- row radius: zero unless the row is an actual selectable object.

Use spacing and alignment before adding borders. Use one outer panel border,
then row separators only where scanning needs them.

## Main bar hierarchy

The bar has three visual groups:

1. workspaces and Senomy identity;
2. telemetry;
3. controls and clock.

The clock is a compact two-row control with time above the short date. Battery
text and symbols use the same primary control scale as adjacent audio and
network controls; secondary clock date text may use the metadata scale.

Do not wrap every control in a visible box. Active state may combine:

- accent icon/text;
- a restrained bottom indicator;
- a subtle surface tint.

Hover should not move surrounding content.

Hover is supplementary. Active state, tooltips, and essential explanations
must remain available on devices that do not provide hover.

## Control Centre

Use a stable shell:

- title and state summary;
- close control;
- compact section navigation;
- one active section body.

Navigation may use a narrow labelled rail where width permits. On narrower
layouts, use a compact section selector without exposing a second panel.

Device Management replaces Performance in the navigation.

## Performance Dashboard

The dashboard is denser but follows the same tokens and typography.

Its hierarchy is:

1. dashboard title and scope;
2. metric summaries and history;
3. process/service investigation;
4. hardware health and reports;
5. curated diagnostic console;
6. confirmed actions.

Graphs should be thin and quiet. A process table is one shared surface with row
separators, not a grid of cards.

## Senomy Insights

Insights should feel like a briefing prepared by the desktop:

- concise leading status;
- grouped observations;
- evidence/source label;
- timestamp or freshness;
- one clear recommendation when applicable.

Severity uses text, icon shape, and restrained semantic colour together.
Critical styling is reserved for verified critical conditions.

The mascot is an identity asset, not an emoji. Final artwork should be produced
as a real raster asset sized for both the bar and Insights header.

Bar dialogue uses a short `Seno:` speaker label followed by one concise line.
Verified conditions outrank personality dialogue. Ambient lines may
occasionally use uncommon English/Latin phrasing, but translations stay brief
and the line must not imply a system fact that was not observed.

## Motion

Use motion only to explain:

- panel opening and closing;
- active-section switching;
- loading becoming ready;
- confirmed action progress.

Keep transitions subtle and short. Avoid glow pulses, constant animation, and
decorative movement.

## Adaptive and touch layouts

SenomyOS uses one visual identity across input modes, but density may change.

Pointer-dense mode:

- compact bar;
- smaller gaps;
- tooltips on hover;
- precise scroll and click behavior.

Touch-oriented mode:

- 44–48px primary targets;
- more space between destructive and safe controls;
- visible labels for ambiguous icons;
- no hover-only content;
- scrollable sections with comfortable edge padding;
- drag and swipe only as optional shortcuts;
- on-screen keyboard awareness;
- panels constrained above system gesture or keyboard areas where known.

Narrow portrait mode should prioritize:

1. time, power, network, and navigation;
2. Senomy status;
3. abbreviated telemetry;
4. overflow access to secondary controls.

The Performance Dashboard may change from three columns to stacked sections on
narrow or portrait displays. It must not merely shrink desktop typography until
it becomes unreadable.
