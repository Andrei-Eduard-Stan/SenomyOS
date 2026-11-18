# Design intelligence audit and tool recommendation

Audit date: 9 November 2026. Scoped static review and reference inspection; none
of the evaluated skill CLIs, installers, hooks or engines was executed. Upstream
source snapshots were read in a temporary review directory, not installed here.
Pinned file URLs and SHA-256 fingerprints are in `third-party-review.json`.
This is not an exhaustive dependency, binary or supply-chain audit.

## Findings and proposed architecture

selected the authoritative Quickshell repository for this installation. Its
tree is already heavily modified; the audit used actual working-tree bytes,
not only HEAD. Existing changes are preserved.

Existing visual memory is substantial but dispersed across `DESIGN_SYSTEM.md`,
decisions, concept art, Illustrator/SVG assets and dated QA. Some files contain
both historical rules and explicit later supersession. Repeatedly reading a
generic aesthetic prompt loses this chronology. Some valuable recent QA/artwork
is untracked, so a bare link alone would not survive a clean checkout.

The proposed architecture, implemented in this setup, is:

| Layer | Role |
| --- | --- |
| `.agents/skills/senomy-design-director/SKILL.md` | Short automatic/explicit native UI workflow, with task-based reference loading |
| `AGENTS.md` routing rule | Makes the workflow required for future repository UI tasks, even if implicit matching misses |
| `INDEX.md` + `catalogue.json` | Retrieval, evidence status, decision authority, transfer limits and lifecycle |
| `CASES.md` + curated `evidence/` | Analysed visual examples, scoped anti-references and durable copies of selected internal evidence |
| `CONSTRUCTION.md` | Maps decisions to actual token, skin, frame, type and motion owners |
| `provenance.json` | Source/evidence fingerprints, dimensions, capture origin and transforms; freshness without silent approval |
| Skill `references/visual-gate.md` | Native composition → critique → actual capture → comparison → refinement and truthful completion states |
| Skill `scripts/check_library.py` | Offline structural/link/fingerprint validation and reference lookup; no desktop access |
| `docs/DESIGN_INTELLIGENCE_GUIDE.md` | How to invoke, maintain, review and move the system |

These documents do not introduce runtime tokens or replace the existing design
system. No new frontend framework, asset generator, inference service or network
dependency is needed. Only relevant cases need opening for an ordinary UI task.

## Available skills and smallest complementary set

The session exposes skill-creator and openai-docs, plus the installed Impeccable
plugin. Product Design audit/image-to-code skills are available for explicitly
requested product audits or faithful visual implementation; their web/image
workflows do not replace native QML verification. Figma, image generation and
browser skills are optional specialist tools, not dependencies of this director.
UI/UX Pro Max and frontend-skill were not in the available local skill catalogue.

**Recommend: Senomy design director + existing Impeccable critique guidance.**
The director supplies project memory, native construction and completion gates;
Impeccable contributes critique vocabulary when useful. The director remains
usable without Impeccable. Do not install another copy or enable automatic hooks
for this setup. Neither additional evaluated skill supplies enough missing native
capability to justify its overlap now.

| Candidate | Useful contribution | Fit and decision |
| --- | --- | --- |
| Impeccable | Hierarchy, spacing, typography, interaction and critique playbooks; current guidance respects an existing brief | Already available as plugin 4.3.1. Use relevant guidance under native constraints; launcher not run. No duplicate install or hooks |
| UI/UX Pro Max | Searchable UX/chart/layout recommendations | No Quickshell/QML stack in reviewed data. Broad style/palette/font generation overlaps existing owners. Defer; if later needed, use narrow evidence-checked UX/chart queries, not generated design-system persistence |
| OpenAI Frontend Skill | Composition, restrained app layout and utility-oriented copy | Useful but overlapping. Published guidance includes web hero/imagery/motion defaults and frontend libraries; preserve existing-system exceptions. Defer rather than importing another general visual authority |

OpenAI's published skill includes useful advice on readable operational density,
minimal chrome and task-focused copy. Its promotion-oriented defaults and motion
suggestions require adaptation to this native shell. Existing authored frames and
type roles take precedence. The official page documents installation through
skill-installer; this audit read the published skill text, not an installed package.
[Primary Frontend Skill source](https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4).

## Impeccable: inspected code and hooks

Local plugin **4.3.1** was inspected as installed. Upstream snapshot
`a49e3e9be2daccdf96ccf1a081b73d7dd9f456fe` declares npm package **4.8.2** and engine
**0.1.21**; these are different review targets, not an assertion the local plugin
has been updated.

- Local shell launcher can use a packaged/configured/PATH engine or download a
  versioned release binary into a user cache. Its download checks a fetched SHA-256
  sidecar before execution. This is code execution and cache mutation, not simply
  reading a Markdown reference, so the launcher was not run.
- Upstream `cli/bin/cli.js` delegates to a platform executable or versioned cache,
  with checksum-manifest verification for fresh downloads. Optional platform npm
  packages bring executable binaries; package pinning alone does not audit them.
- Reviewed package manifests have development/package scripts; no install or
  postinstall lifecycle script is declared in the two main manifests examined.
  Transitive package scripts and the downloaded executable were not executed or
  exhaustively audited.
- Rust `commands.rs` installs downloaded skill bundles and considers hook consent;
  `--no-hooks` skips provider-hook installation. `bundle.rs`, `engine_binary.rs`
  and `hook_manifest.rs` were inspected for download/extraction/copying and hook
  boundaries. A future install needs the exact selected release/artifact reviewed,
  not an assumption it equals this upstream snapshot.
- The reviewed Codex manifest registers **PostToolUse** (5s) and **Stop** (30s)
  commands invoking the skill launcher. A hook can therefore execute after edits
  and at completion. Hook administration can edit project hook/config artifacts.
- Built-in detector extensions documented by the inspected plugin cover web
  sources; **`.qml` is not in that list**. No evidence establishes a native QML
  visual validator. Screenshot and native interaction review remain required.
- No `.codex/hooks.json`, `.impeccable/` configuration or skill-engine cache was
  created/changed by this setup. Referencing a playbook does not authorize an
  engine download. When unavailable, read project evidence directly as its skill
  fallback specifies.

[Primary repository](https://github.com/pbakaus/impeccable) and
[hook documentation](https://impeccable.style/docs/hooks/).

## UI/UX Pro Max: inspected installer and search path

Snapshot `4f2dbb67e64969a9a30ab00742f2d55d66ddec2b` declares CLI **2.5.0**. Reviewed
entry points include `init.ts`, `template.ts`, `extract.ts`, `github.ts`, the Codex
platform template, skill instructions, `search.py` and `core.py`.

- Default `init` generates from bundled templates. The Codex template targets
  `.agents/skills/ui-ux-pro-max`; the generator copies local data and Python scripts.
  `--global` targets home. Existing main skill is skipped without `--force`.
- **Default installation also copies six sibling skills:** banner-design, brand,
  design-system, design, slides and ui-styling. The old pasted recommendation
  understated this scope. Do not assume a single requested skill means one folder.
- The generator can remove legacy installs and replace non-directory data/script
  targets. Legacy ZIP mode fetches a release and shells out to `unzip` or PowerShell;
  copying has a shell fallback. Those branches need separate approval/review if used.
- Reviewed init/template paths do not register Codex execution hooks. That finding
  is scoped to reviewed code, not a guarantee about every package dependency.
- `search.py` imports local search/design-system modules. `core.py` searches local
  CSVs; CLI design-system persistence writes a separate `design-system/` tree.
  This audit did not execute or exhaustively review every imported module. Avoid
  persistence here: existing `appearance/` and native style roles already own design.
- Reviewed stack CSV names contain no QML/Quickshell/QtQuick implementation stack.
  Web accessibility/layout guidance can inspire a question, but its CSS/ARIA/GSAP
  syntax and palette/font recommendations are not native implementation authority.

[Primary repository](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill).

## Setup validation and boundaries

The system validates itself offline and preserves curated internal visual evidence.
External primary images for Unigrid/GNOME were inspected; Carbon's image fetch
failed, so it stays documentary. No fresh live UI capture, interaction or runtime
acceptance is claimed. Existing screenshots are dated evidence, never silently
relabeled as captures from this setup. No running component is redesigned.

The [setup validation record](VALIDATION.md) distinguishes integrity checks,
temporary corruption probes, skill validation and protected-source verification.

Before any later third-party install, review the selected immutable artifact,
dependency/lifecycle scripts, exact file-write plan, hooks and rollback scope,
then obtain approval for that concrete install. This setup requests no third-party
installation: the recommended complementary guidance is already available.
