# Figma audit board plan

Status: upload-ready manifest; Figma creation is blocked in this chat because the installed Figma connector is not exposed as a callable tool and no in-app browser is connected.

## Board contract

- File title: `SenomyOS — Luminous Reliquary Surface Audit`
- Section title: `SenomyOS Surface Redesign — Current Rendering and Architecture Notes`
- Evidence source: accepted, inspected images under `baseline/current-run/` only.
- Do not upload the older `baseline/*-full.png` captures.
- Current-run images already redact retained notification prose, network identifiers/addressing, one Bluetooth hardware address, and process usernames.
- Place cards left to right in step order with 200px between cards.
- Start a new row after every 15 cards and leave 600px between rows.
- Keep each screenshot, step title, health label, findings, accessibility note, and recommendation together.
- Wrap all cards and notes in the titled Figma Section before handoff.

## Visual treatment

The board is documentation, not a proposed production UI. Use a quiet near-black canvas, ivory text, cool-grey metadata, and violet only for numbered markers and priority flags. Avoid decorative Luminous Reliquary frames around the evidence itself; screenshots must remain visually neutral and easy to compare.

Recommended card anatomy:

1. `STEP NN // SURFACE` eyebrow
2. short surface/state title
3. screenshot at native aspect ratio
4. health chip: `HEALTHY`, `MIXED`, `NEEDS REDESIGN`, `DECISION BLOCKER`, or `NOT CAPTURED`
5. Evidence
6. Accessibility risk
7. Proposed direction

## Ordered cards

| Step | Surface / state | Screenshot | Health | Notes beneath screenshot |
| --- | --- | --- | --- | --- |
| 01 | Obsidian Rail — resting | `baseline/current-run/rail-rest.png` | HEALTHY | Strongest family reference: segmented Compact islands, clear grouping, stable identity. The current cyan/green native-window edge competes directly above it. Verify keyboard focus, icon labels, touch targets, and narrow overflow. Preserve topology and use the Rail as the visual foundation. |
| 02 | Control Centre — Overview | `baseline/current-run/control-overview.png` | MIXED | Truthful summary and useful deep links, but four equal cards flatten priority. Small body/meta text and non-focusable Eww window are accessibility risks. Replace the card row with a connected operational spine. |
| 03 | Control Centre — Network | `baseline/current-run/control-network.png` | NEEDS REDESIGN | Strong source and action coverage; dense cards, clipped lower content, and similar visual weight for facts and actions. Network values are sensitive. Use Internet → interface → access-point topology, AP ledger, and guarded action dock. |
| 04 | Control Centre — Audio | `baseline/current-run/control-audio.png` | MIXED | Physical endpoints and route truth are useful, but the content becomes a vertical card stack. Slider labeling and target size need keyboard/touch testing. Use duplex output/input lanes and an endpoint bus. |
| 05 | Control Centre — Power | `baseline/current-run/control-power.png` | MIXED | Dual-battery and policy data are substantive; dozens of small boxes obscure the charge relationship. Tiny telemetry is an accessibility risk. Use paired battery cells, charge-flow thread, policy selector, brightness rail, and confirmation bay. |
| 06 | Control Centre — Calendar | `baseline/current-run/control-calendar.png` | NEEDS REDESIGN | Time evidence is correct, but a large empty bordered field and microtype waste the panel. Reading order and contrast need testing. Use a calendar field, chronometer column, and compact evidence footer. |
| 07 | Control Centre — Input | `baseline/current-run/control-input.png` | MIXED | Capability truth and read-only status are good; repetitive device rectangles make scanning slow. Ensure device names and disabled states do not rely on colour. Use a capability matrix and device tree. |
| 08 | Control Centre — Devices | `baseline/current-run/control-devices.png` | MIXED | Multi-domain inventory and guarded Bluetooth actions are strong. Nested cards and exposed hardware identifiers need visual/privacy discipline. Use a capability bus with grouped endpoints and bounded detail. |
| 09 | Control Centre — Applications | `baseline/current-run/control-apps.png` | MIXED | Lifecycle status and native/tray boundaries are explicit, but the single-item state leaves a large void. Stop/confirmation controls need stronger risk distinction. Use a content-bounded runtime ledger and action rail. |
| 10 | Control Centre — Appearance | `baseline/current-run/control-appearance.png` | DECISION BLOCKER | Live preferences work, but legacy accent/gradient controls can recolour the structural shell and conflict with the locked silver/violet direction. Focus and selection must not depend on the chosen palette. Approve a fixed structural palette and scoped personalization model first. |
| 11 | Control Centre — Settings | `baseline/current-run/control-settings.png` | MIXED | Ownership and recovery facts are useful; repeated full-width bordered actions look equivalent regardless of consequence. Improve focus, confirmation, and target size. Use a shell manifest plus clearly separated maintenance dock. |
| 12 | Volume flyout | `baseline/current-run/volume-flyout.png` | MIXED | Compact and direct, but reads as a thin cyan rectangle and has undersized targets. Fader keyboard/touch behavior needs testing. Migrate first as a Standard-frame horizontal channel strip. |
| 13 | Tray overflow | `baseline/current-run/tray-flyout.png` | NEEDS REDESIGN | Current one-item state is mostly empty space and does not explain native item semantics. Keyboard/native-menu behavior needs testing. Use a content-bounded app ledger with a clear Applications handoff. |
| 14 | Senomy companion — expanded | `baseline/current-run/companion-expanded.png` | MIXED | Character ownership is correct and visually distinctive; the tall column is mostly unused and the toolbar is tiny. Preserve dock/pin/timed collapse while converting it to a Standard edge ribbon. |
| 15 | Senomy companion — compact | `baseline/current-run/companion-compact.png` | NEEDS REDESIGN | Visually stronger than expanded mode, but 300x410 is not meaningfully compact. Expand/focus targets require proof. Reduce it to an avatar-and-state tab with one explicit expand action. |
| 16 | Insights — Briefing | `baseline/current-run/insights-briefing.png` | NEEDS REDESIGN | The correct system topics exist, but the first-class briefing reads as an unranked list. Tiny prose and a non-focusable window are accessibility risks. Use ranked current condition, material change, attention, and freshness. |
| 17 | Insights — Notifications | `baseline/current-run/insights-notifications.png` | MIXED | Bounded private retention is clear; stacked cards and long microtype make scanning difficult. Content may be private and export/redaction must be explicit. Use a time-ordered private ledger. |
| 18 | Insights — Timeline | `baseline/current-run/insights-timeline.png` | NEEDS REDESIGN | Sanitized sources, filters, and follow state are good; event cards do not express time or source relationships. Focus/follow state needs non-colour cues. Use a vertical event rail with source lanes and time anchors. |
| 19 | Insights — Updates | `baseline/current-run/insights-updates.png` | MIXED | Trust, source freshness, and no-install boundaries are unusually good. Equal bordered blocks weaken the source chain and action hierarchy. Use a trust-chain/source ledger with explicit cache age. |
| 20 | Insights — Diagnostics | `baseline/current-run/insights-diagnostics.png` | MIXED | Fixed allowlisted tasks are a strong safety boundary. Dense rows and tiny click targets need keyboard/touch proof. Use runbook rows with task code, exact scope, last state, and bounded output drawer. |
| 21 | Insights — Console | `baseline/current-run/insights-console.png` | MIXED | The refusal to imitate a free-form shell is correct. Stacked cards obscure the difference between detected shells and real-terminal handoff. Use curated command strips with one explicit handoff action. |
| 22 | Insights — Reports | `baseline/current-run/insights-reports.png` | MIXED | Privacy and profile boundaries are strong; repetitive rectangles flatten selection and artifact state. Ensure selected state is not violet-only. Use an evidence docket with included collectors and build state. |
| 23 | Insights — Wiki | `baseline/current-run/insights-wiki.png` | NEEDS REDESIGN | Local bounded Markdown is appropriate, but the 750px panel cramps index and reading plane. Body type and line length are accessibility risks. Widen Insights and use a 62–78 character reader. |
| 24 | Performance — Overview | `baseline/current-run/performance-overview.png` | MIXED | Real synchronized telemetry and provenance are excellent; equal cards and shallow charts flatten the machine story. Tiny labels are a major risk. Use paired machine-heart arcs, one 300s thread, and a platform/power rail. |
| 25 | Performance — CPU + GPU | `baseline/current-run/performance-cpu.png` | MIXED | Package, load, thermal, and thread evidence are real; charts are visually shallow and thread cells over-fragment the plane. Use a package/frequency/thermal spine and explicit GPU-unavailable state. |
| 26 | Performance — Memory | `baseline/current-run/performance-memory.png` | MIXED | Composition and pressure data are useful; multiple equal panels hide the used/cache/free relationship. Improve label size and scale explanation. Use a composition river plus pressure thread. |
| 27 | Performance — Storage | `baseline/current-run/performance-storage.png` | MIXED | Read/write, capacity, topology, pressure, and health boundaries are present. Card repetition and microtype weaken comprehension. Use mirrored I/O ribbons, capacity rail, and device chain. |
| 28 | Performance — Network | `baseline/current-run/performance-network.png` | MIXED | Duplex history and route/link evidence are useful; sensitive values need local-only treatment and the topology is visually flat. Use mirrored streams and route/interface/address relationships. |
| 29 | Performance — Processes | `baseline/current-run/performance-processes.png` | MIXED | The table is the strongest Performance information plane and existing filters are useful. Typography is too small and guarded selection/action needs a dedicated inspector. Preserve density while enlarging labels and clarifying action scope. |
| 30 | Performance — Benchmarks | `baseline/current-run/performance-benchmarks.png` | MIXED | Warnings, thresholds, progress, stop, and result boundaries are strong. The running state needs clearer phase/thermal hierarchy and keyboard confirmation proof. Use a warning gate, phase timeline, live thread, cooldown, and result ledger. |
| 31 | Command Lens — Applications | `baseline/current-run/command-lens-apps.png` | HEALTHY | Clear keyboard-first scopes, results, and shortcut footer. It still reads as a conventional rounded dark launcher. Preserve Rofi behavior and project the Standard frame with one local violet selection signal. |
| 32 | File Workspace — Thunar | `baseline/current-run/thunar-file-workspace.png` | HEALTHY | Namespaced GTK creates a precise, useful native workspace. The saturated compositor edge dominates the client and GTK 4 remains outside this theme. Keep native hierarchy; use quiet toolkit tokens and compositor treatment. |
| 33 | SwayNC — notification centre | `baseline/current-run/swaync-notification-centre.png` | NEEDS REDESIGN | Current rendering is generic dark GTK and duplicates part of Insights Notifications. Keyboard features exist but need direct testing. Keep provider functionality, style it as a Standard native ledger, and do not create another primary Rail route. |
| 34 | SDDM login | none — named blocker | NOT CAPTURED | Live capture would require leaving the session. Source and approved QA were audited, but do not present them as current-run screenshot evidence. Board note: retain the approved lower authentication rail and validate in the real QML renderer before implementation. |
| 35 | Hyprlock | none — named blocker | NOT CAPTURED | Live capture would deliberately lock the session. Source and existing QA were audited only. Board note: match the authentication family within Hyprlock limits and never imply non-clickable marks are controls. |
| 36 | Recovery UI | none — named blocker | NOT CAPTURED | Opening the restricted recovery session was not safe during the audit. Source was inspected only. Board note: one-task Large native recovery composition with keyboard, error, success, and helper-boundary validation. |

## Summary panels

Place these after the ordered evidence cards, inside the same Section.

### A. Overall verdict

The Rail is already the visual foundation. Control, Insights, and Performance have credible functional boundaries and truthful data, but their flat cyan rectangles, tiny typography, repeated cards, and non-focusable Eww windows prevent the desktop from reading as one finished system.

### B. Frame-tier map

- Compact: Rail islands and compact companion tab.
- Standard: Volume, Tray, Command Lens, SwayNC, expanded companion.
- Large: Control Centre, Insights, Performance, SDDM/Hyprlock/Recovery projections.

### C. Highest-impact changes

1. Approve fixed silver structure, sparse violet signaling, type scale, spacing, and focus treatment.
2. Make primary Eww surfaces keyboard-focusable through an approved focus model.
3. Build one verified Compact/Standard/Large frame harness with exact safe insets.
4. Pilot Standard frames on Volume and Tray.
5. Give Control, Insights, and Performance distinct Large topologies rather than one generic card system.
6. Move compositor decoration from cyan/green pop-in styling to quiet silver ownership and restrained motion.

### D. Evidence limits

Screenshots do not prove screen-reader support, keyboard navigation, touch behavior, contrast compliance, reduced motion, error handling, or responsive layouts. SDDM, Hyprlock, Recovery, urgent/modal/fullscreen windows, notification action popups, portrait, phone, and touch modes still need real-renderer testing.

### E. Approval gates

- visual tokens and colour-role migration;
- keyboard focus architecture;
- representative desktop/narrow/touch mockups;
- shared frame/component contract;
- per-stage implementation and validation order.

## Completion check once Figma access is active

1. Create or select the destination Figma/FigJam file.
2. Upload each accepted local screenshot from the ordered table.
3. Place cards in order using the 15-card row and spacing rules.
4. Add the three named blocker cards without substituting old screenshots.
5. Add the five summary panels.
6. Wrap everything in the titled Section.
7. Inspect the rendered board and confirm every image is visible, correctly paired, uncropped, and not merely stored as an unused asset.
8. Return the Figma file link only after that inspection passes.
