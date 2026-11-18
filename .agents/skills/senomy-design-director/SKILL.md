---
name: senomy-design-director
description: Direct SenomyOS native Quickshell/QML interface work using its curated visual evidence, appearance roles and authored artwork. Use for UI planning, composition, implementation, critique and visual acceptance, and for curating approved or rejected references. Backend-only work does not need this workflow.
---

# SenomyOS design director

Make design decisions traceable to SenomyOS evidence. The library lives in
[docs/design/design-intelligence](../../../docs/design/design-intelligence/INDEX.md).
Paths there are repository-relative unless stated otherwise. Resolve the repository
from this skill's location, not from the terminal's current directory.

## Establish authority

Read the target repository's `AGENTS.md`, current `docs/DESIGN_SYSTEM.md` updates,
and the target component before proposing changes. This is Quickshell/QML/QtQuick;
Quickshell watches source: an edit to active QML/assets can publish immediately.
Use an isolated candidate with inert providers for coordinated UI changes.

Current user instructions lead. Resolve historical conflicts using explicit
supersession in current decisions, the source and its dated visual evidence.
Running code establishes behavior, not automatic aesthetic approval. If approval
or runtime truth conflicts, name the conflict rather than inventing consensus.

## Required sequence for every UI task

1. **Study references.** Read [INDEX](../../../docs/design/design-intelligence/INDEX.md),
   select the closest relevant cases and anti-reference, then open their actual
   images. Read the corresponding [case analysis](../../../docs/design/design-intelligence/CASES.md)
   and [construction rules](../../../docs/design/design-intelligence/CONSTRUCTION.md).
   Check source freshness with `python3 .agents/skills/senomy-design-director/scripts/check_library.py`
   from the repository root. Investigate relevant drift; do not bless it by updating hashes.
2. **Develop composition.** State the user's task, dominant information/action,
   reading order, group proportions, alignment, density, narrow/touch behavior,
   asset/component mapping and preserved interaction contracts. For a small fix,
   a short paragraph suffices. Larger changes need a sketch/annotated layout
   before production code. Use existing QML or a static native sketch; no assumed HTML/CSS.
3. **Critique.** Compare that composition with the chosen cases. Identify the
   weakest hierarchy, wasted space, frame misuse and likely input/state failures.
   Resolve material weaknesses before implementing. Optional Impeccable guidance
   can sharpen critique; it never overrides this native product's evidence.
4. **Implement.** Reuse `Theme`, `DirectoryStyle`, `QuickPanelStyle` where applicable,
   `Motion`, `Skin`, shared native controls and authored frames. Preserve providers,
   navigation, confirmation guards, focus and action APIs. Do not create another
   palette, font registry, sampling loop or popup coordinator.
5. **Capture actual result.** Render the actual changed QML with isolated hosting
   and fake providers; record source hashes and fixture limitations. Inspect the
   resulting images at normal scale and relevant detail. Inspect a short motion
   sequence for motion changes. A mockup, lint result or unviewed screenshot is
   insufficient. Native placement/grab claims need native evidence.
6. **Compare.** Write concrete discrepancies against the reference and composition:
   proportion, hierarchy, rhythm, framing, typography, density and interaction.
   Check target states and constrained layouts from the
   [visual gate](references/visual-gate.md), not only the happy-path image.
7. **Refine.** Fix material discrepancies and capture the changed result again.
   Prefer one batched correction and confirmation pass. Stop on missing evidence
   or unresolved material defects; report `awaiting visual verification` or the
   precise remaining limitation instead of calling the component finished.

Visual inspection and written critique are mandatory before visual completion.
User aesthetic acceptance, functional tests and hardware acceptance remain
separate facts. Do not automatically turn a candidate into an approved reference.

## Maintain continuity

For a newly accepted/rejected direction, add the smallest useful case using the
schema and lifecycle in [INDEX](../../../docs/design/design-intelligence/INDEX.md).
Record who decided, which specific decisions apply, evidence provenance and what
is superseded. A screenshot filename containing “final” is not approval.
Use [the guide](../../../docs/DESIGN_INTELLIGENCE_GUIDE.md) for invocation,
reference curation, review notes and moving this skill with the repository.

External examples contribute a named transferable principle, never a replacement
brand. UI/UX Pro Max and Frontend Skill are not required dependencies. Do not run
installers, enable hooks or download an engine just because an optional skill's
setup requests it; first read the scoped
[tool review](../../../docs/design/design-intelligence/AUDIT.md).
