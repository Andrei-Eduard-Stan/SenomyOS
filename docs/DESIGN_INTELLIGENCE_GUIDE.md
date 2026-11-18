# Using and maintaining the SenomyOS design director

The skill and library live in this Quickshell repository. Open Codex here or in a
does not automatically discover this repository's skills. Repository discovery
and explicit invocation are documented by [OpenAI](https://learn.chatgpt.com/docs/build-skills).
Codex detects skill updates; restart if it does not appear. No npm installation,
desktop reload, service or API key is needed.

## Start a UI task

Paste this into Codex:

```text
$senomy-design-director
Study the current <component> and its closest approved/observed references.
Propose and critique its composition before implementation. Preserve existing
QML behavior, appearance roles and authored frames. Use an isolated candidate;
capture and inspect the actual result before declaring visual completion.
```

For diagnosis only:

```text
Use $senomy-design-director to critique <component>. Open actual visual evidence,
name the specific hierarchy/spacing/type/interaction problems and recommend one
composition. Do not edit runtime files or interact with the live desktop.
```

The repository `AGENTS.md` routes future UI work through the skill automatically.
Explicit invocation is useful when you want to be certain. If discovery fails,
ask Codex to read `.agents/skills/senomy-design-director/SKILL.md` directly.
Automatic selection is an agent instruction, not an executable enforcement hook.

## Add a reference yourself

1. Choose an image that explains one decision. Place a local evidence copy in
   `docs/design/design-intelligence/evidence/`, or use a stable existing tracked
   asset. For an external example retain its creator, primary page/image URL and
   inspection date. Do not turn external reference art into a runtime asset.
2. Describe what it accomplishes: “The value column stays aligned while endpoint
   names wrap”, rather than “clean futuristic design”. Describe the seven analysis
   dimensions listed in [the library](design/design-intelligence/INDEX.md).
3. Tell Codex your precise decision: “Approve the grouping and type hierarchy;
   reject the translucent reading surface.” Partial approval is useful. A design
   can contain both good and bad decisions.
4. Ask it to add a catalogue entry, case analysis and source/evidence provenance,
   using the existing schema. Start as observed/candidate unless approval exists.
   Retain replaced cases and their reasons. Run the offline checker.

For example:

```text
Use $senomy-design-director to curate this reference. I approve its output-first
hierarchy and aligned values, but reject nested frames. Inspect the image and
source, record that scoped decision and its limits in the library. Do not change
the live component. Preserve any earlier rejected case for comparison.
```

An agent may recommend a case, but cannot grant your approval. Correct the record
if it attributes a decision to you that you did not make.

## Find and verify references

From the repository root:

```bash
python3 .agents/skills/senomy-design-director/scripts/check_library.py --find audio
python3 .agents/skills/senomy-design-director/scripts/check_library.py
git diff --check
```

The checker uses Python's standard library, reads local files only and writes
nothing. Exit 0 means structural/fingerprint checks passed; 1 means broken library
structure/evidence; 2 means inspected sources drifted and need review. It does not
claim the UI looks good. Do not refresh fingerprints merely to silence drift:
inspect the affected source, revise the analysis and record the review first.
It works from any directory because it locates the root from its own file.

For an actual implementation, use the short review template in the skill's
[visual gate](../.agents/skills/senomy-design-director/references/visual-gate.md).
Record captures and limitations. A component without an inspected actual render
remains awaiting visual verification. Your aesthetic acceptance and real hardware
acceptance remain separate from passing code/fixture checks.

## Keep the system permanent

The reusable unit is the skill directory, this guide, the design-intelligence
directory and the AGENTS routing rule, together with the existing source assets
they reference. Keep them in the same repository; do not copy a skill alone and
leave its relative library links behind. The evidence archive preserves selected
recent images whose original QA/artwork directories were untracked at setup.

Review the incremental diff and validation before committing. Include new evidence
and provenance files as well as Markdown. No commit is made automatically; a file
that exists locally still needs a deliberate Git commit to travel with the project.
Review third-party additions separately. The
[tool audit](design/design-intelligence/AUDIT.md) explains why Impeccable guidance
is sufficient alongside this director and why two further installs were deferred.
