# Native visual gate

Use a task-sized review note under `docs/qa/<task>/`. Do not execute an old QA
script without reading its current source, arguments and provider substitutions.
Do not run production `shell.qml` under a second shell process for a preview:
it can create real services, notification ownership and device operations.

## Before implementation

Record the target, user task, preserved behavior and non-goals. Identify two or
three useful reference decisions and one nearby failure, with catalogue IDs.
Open the images; reading the case prose alone is insufficient. If no case fits,
inspect the incumbent actual component and record new evidence before inventing
a style. Search primary external references only for a specific unresolved need.

Write the composition in task terms, for example:

> Audio quick control: endpoint and output gain lead; input is secondary; optional
> alternatives follow the controls. One authored perimeter, fixed numeric column,
> wrapping endpoint names. At short heights the body scrolls while close remains
> reachable. Selection continues through the existing review coordinator.

Specify container allocation versus optical frame bounds and content safe zones.
State which source tokens, skin keys and shared components supply each role.
Critique the proposal before editing: what competes with the task, which elements
share an alignment, where does narrow layout change topology, what survives
provider failure, and can keyboard/touch reach the same task?

## Capture truth

- Develop in an isolated source copy outside watched runtime paths. Copy mutable
  art/tokens too when changing them; a symlink back to live assets is not isolation.
- Reuse an existing fixture for the real component with fake providers. Isolate
  XDG config/state/runtime and the D-Bus session; use offscreen/software Qt where
  appropriate. Remove live compositor access when the fixture does not need it.
  Review process launch and action adapters, not just fixture names.
- Existing entry points include `scripts/validate-control-directory.py`,
  `validate-directory-surfaces.py`, `validate-audio-quick-quality.py`,
  `validate-uniform-button-hover.py`, and `validate-art-skins.py`. Their current
  interfaces and safety determine use; this list is not an instruction to run all.
  Some write dated output paths by default. Choose a new task output directory
  where supported. Do not overwrite reference goldens to make a check pass.
- Record candidate source hashes, output dimensions, logical size, Qt scale,
  text scale, touch/contrast/motion settings, provider state, capture method and
  whether native window hosting was substituted. Keep readable crops plus enough
  surrounding context to assess anchoring; avoid private desktop content.
- Compare at the same logical scale. Distinguish a smaller visible crop from a
  smaller control, and transparent pixels from the native input allocation.
- Open actual PNGs with the image viewer. A successful file write is not inspection.
  For motion, inspect start/intermediate/end/reversal and reduced-motion captures;
  stills cannot establish timing, frame rate or input-to-photon latency.

## Minimum relevant states

Select states affected by the task and justify omissions; do not manufacture a
huge unrelated test suite for a small change.

| Concern | Evidence to inspect |
| --- | --- |
| Layout/type | Actual normal-size wide view; narrow/short view if layout can change; long labels and existing text scaling |
| Interaction | Rest, hover, genuine selection/current, keyboard focus, disabled; distinguish pointer focus from keyboard focus |
| Async/data | Loading, empty, unavailable/error and pending/succeeded/failed where relevant; no fabricated success |
| Navigation | Existing route/search/scroll position, back/Escape, same-trigger close, replacements, dirty-draft or modal review |
| Artwork | Intended asset, cap/centre proportions, safe zones, decode failure/native fallback; no duplicate perimeter |
| Accessibility | Existing touch profile, large text, high contrast and reduced motion; labels alongside meaningful state |
| Hosting | Work-area bounds, owning screen and closing anchor if affected; Qt body fixtures alone cannot prove them |

Current known evidence limits matter: the 9 November Control Directory report
records matching baseline/candidate fake-provider warnings, and its narrow
Appearance image shows “Loading settings…”. Do not call that a verified complete
narrow page. Reproduce a ready state when making a page-layout claim.

## Compare and finish

Write observations, not “looks polished”. Example: “The endpoint now wraps within
its column; the value stays aligned. At 390px the title truncates before the
close control; shorten/reflow the title before acceptance.” Name which proposed
change fixes each material defect. Recapture after a correction.

Use separate outcomes:

- **Visual verification complete:** actual candidate inspected, comparison and
  corrections recorded, no material visual defect in tested scope.
- **Awaiting visual verification:** capture unavailable, stale or never inspected.
- **User acceptance pending:** visual/functional evidence exists but no explicit
  owner aesthetic decision. Do not invent that decision.
- **Hardware acceptance pending:** isolated evidence does not prove physical touch,
  GPU smoothness, live focus/grabs, routing or multi-monitor behavior.

If live publication is requested later, follow the repository's watched-source
warning and publication workflow. This skill's design workflow supplies no extra
authorization to reload, restart, change devices, commit or push.

## Review note template

```markdown
# <Component> design review — <date>
Task / preserved behavior:
References: <IDs and specific decisions used; anti-reference>
Source / fixture / capture provenance:
Composition and preimplementation critique:
Actual captures: <relative links, dimensions and states>
Comparison: <proportion, hierarchy, rhythm, framing, type, density, input>
Corrections and confirmation captures:
Functional checks and limitations:
Visual outcome / user acceptance / hardware acceptance:
Library update: <none, new candidate, or explicit scoped decision + evidence>
```
