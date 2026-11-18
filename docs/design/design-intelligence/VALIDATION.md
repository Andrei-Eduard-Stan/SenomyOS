# Setup validation — 9 November 2026

Scope: reference-system setup only. No running component was redesigned or newly
rendered. Historical screenshots retain their dates; the Illustrator PDF-compatible
preview was rendered read-only into temporary files and its Rail excerpt archived.

## Checks and results

| Check | Result |
| --- | --- |
| Library structure, explicit case anchors and local Markdown links | Pass: 13 catalogue entries |
| Archived PNG SHA-256 and dimensions | Pass: 7 internal evidence images |
| Selected appearance/QML/document/SVG fingerprints | Pass: 21 inspected sources match |
| Reference lookup | Pass: `--find audio` returns P01 and R01 |
| Checker portability | Pass from an unrelated working directory against a temporary copied library |
| Skill-creator `quick_validate.py` | Pass: “Skill is valid!” |
| UI metadata | YAML parsed; name, discoverability, lengths and explicit invocation prompt checked |
| Checker Python syntax | Pass, compiled in memory without writing bytecode |
| `git diff --check` | Pass |
| Existing working-tree preservation | 8,047 pre-existing file hashes checked; only the two intended documentation additions differ |

The default system Python initially lacked PyYAML for skill-creator's validator.
Validation then used an existing cached PyYAML package without installing anything.
The delivered checker itself uses Python's standard library only.

## Integrity probes

Each change below was made in a disposable copied tree, never in runtime source.

| Probe | Observed checker outcome |
| --- | --- |
| Duplicate case ID | Exit 1, rejected |
| Source path escaping repository | Exit 1, rejected |
| Missing case analysis anchor | Exit 1, rejected |
| Promoting an unviewed external reference to visual exemplar | Exit 1, rejected |
| Altered archived image bytes | Exit 1, rejected |
| Changed inspected token source | Exit 2, source drift reported |
| Restore original copied bytes | Exit 0 |

These probes establish checker behavior, not visual quality. Automatic model skill
selection in a fresh session was not exercised; repository discovery follows the
documented `.agents/skills` mechanism and the explicit AGENTS routing rule.

## Protected boundary

A pre-edit SHA-256 snapshot covered existing tracked and untracked regular files
in this worktree. Setup ran on `feature/display-workspace-orchestration`; no branch
switch was performed. The 20 new files are the skill, guide and curated library.
The only changes to pre-existing files are the design-workflow subsection
appended within `AGENTS.md` and the new design-intelligence decision appended to
`docs/archive/README.md`; the incremental diff was inspected. Everything else added by
this stage is the local skill, guide and reference library. Existing unrelated
changes were not reverted, reformatted or synchronized.

No QML, SVG production asset, token registry, appearance projection, user preference,
service, device or compositor configuration was modified. No source-watcher trigger,
reload, restart, production fixture, device mutation, commit or push was performed.

Native rendering, interaction and hardware checks are intentionally absent because
this stage changes no running UI. Future UI completion must follow the skill's
actual-render/critique gate. Existing current-case limitations remain visible in
the catalogue, including pending Audio visual acceptance and the narrow Settings
loading capture; setup does not close those acceptance items.
