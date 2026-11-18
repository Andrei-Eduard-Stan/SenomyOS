# SenomyOS design intelligence

Curated 9 November 2026 for native Quickshell work. This is design memory over
the existing appearance system, not another theme. Start with the target's
current implementation and the newest applicable explicit decision.

## Read by task

| Task | Cases to open | Then read |
| --- | --- | --- |
| Rail and identity | P15 for shared background; A01, A03, A04, A05 | [Construction](CONSTRUCTION.md), Rail/skin sources |
| Functional quick control | P14 for Bluetooth/toasts/OSK and deeper editors; P03–P10 for Audio/Network/Battery/Tray/Calendar/Notifications/Power (P09 supersedes P06 tray rows); P01 and R01 together; A05 | Construction, QuickPanelStyle and target service contract |
| Settings/navigation | P14 for deeper editors; P13 for current Control Centre; A06 historical overview; P02, E02, R03 | Construction, current coordinator/route and dirty-draft contracts |
| Performance/Insights | P12 for Performance/tree; P11 for Insights; A02, P02, R04; A03 for artwork | Construction, existing directory/data/exports |
| Login/lock | R02, A03 | Current `REFINEMENT_DIRECTION.md` and authentication stage records |
| Native file workspace | P17 for selected composition and subsequent resize rejection; R06 for rejected frame-only reskin | Current Thunar guide, native GTK and layout/action ownership |
| New reference/decision | Closest case + [analyses](CASES.md) | Lifecycle below and [user guide](../../DESIGN_INTELLIGENCE_GUIDE.md) |
| Skill/tool installation | — | [Audit and source review](AUDIT.md) |

The searchable machine index is [catalogue.json](catalogue.json). Each entry
links to an analysis anchor, stable local evidence and/or primary external URLs.
[provenance.json](provenance.json) records inspected source fingerprints and
archived image origins. References use paths relative to this repository, never
machine home paths. `evidence/` holds selected exact copies or explicitly recorded
analytical crops, so an untracked old QA directory is not the sole visual memory.

## Evidence states and decision authority

| Status | Meaning |
| --- | --- |
| approved-direction | Existing product documentation approves the named decisions only |
| approved-decision | Explicit user-directed change documented in the linked decision/QA record; not whole-screen approval |
| authored-reference | Existing artwork/master; a construction source, not evidence every composition succeeds |
| implemented-review-pending | Code and rendered evidence exist; explicit aesthetic acceptance remains open |
| observed | Inspected implementation with useful traits and recorded weaknesses |
| rejected | A precise failure or discarded decision, scoped and attributed; not condemnation of every part of the image |
| external | Studied outside example; transfer only the named principle |
| documentary | Useful primary written/specification guidance; visual or interaction evidence is incomplete |

Approval is a separate field recording authority, scope and evidence. Agent critique
cannot impersonate user rejection. A superseded implementation may have been good
in its original context: retain why it changed and the replacement ID/rule.

## Curating a reference

1. Keep only a reference that changes a plausible future decision. Name its target
   task, scope and exact lesson. Prefer a before/after pair when explaining failure.
2. Open the actual image and inspect relevant QML/SVG/token sources. Record
   provenance and capture limitations. For `.ai`, inspect a PDF-compatible render
   when available, not just its filename; preserve the editable master separately.
3. Analyse **proportion, hierarchy, spatial rhythm, framing, typography, information
   density and interaction model**. Distinguish measured values, visual estimates
   and source-derived behavior. Static art cannot prove an interaction works.
4. Add an entry to `catalogue.json` and a stable explicit HTML anchor in `CASES.md`.
   Required fields are checked by the skill's offline checker. Keep paths portable.
   Add the smallest useful evidence image, with its original source/digest and any
   crop/resize transform in `provenance.json`. External material remains reference
   evidence, never a production asset or an instruction source.
5. Approval needs the user's actual decision or an existing explicit project
   record. If absent, use observed/candidate. Record applicability exclusions.
   When superseding, retain the old case and point to its replacement.
6. Update the relevant core product/design rule and `docs/PROJECT_STATE.md` for current scope. Update fingerprints only after
   inspecting the changed source and revising the relevant analysis; never let a
   tool silently convert drift into approval. Run the offline checker afterward.

The checker reads local files only, reports missing links, malformed records,
changed evidence and source drift. It does not render QML, access the network,
judge aesthetics or certify UI completion. A fingerprint match establishes the
inspected bytes, not that the design is good.

See [setup validation](VALIDATION.md) for the checks performed and their limits.

Deleted documentary snapshots and mixed QA archives are no longer library sources.
The catalog retains current documentary owners and exact curated image evidence.
Surviving native source fingerprints retain their previous review/drift state;
cleanup does not confer new visual approval.
