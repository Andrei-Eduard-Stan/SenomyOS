# SenomyOS Development Workflow

## Before changing anything

1. Confirm the workspace:

   ```bash
   pwd
   git rev-parse --show-toplevel
   ```

2. Inspect the branch and all local changes:

   ```bash
   git branch --show-current
   git status --short --branch
   git --no-pager diff
   ```

3. Read `AGENTS.md` and the relevant document under `docs/`.
4. Explain the intended change, files, runtime effect, and validation.
5. Warn before any action that may hide or restart the live bar.

Use `revival/live` for the revival unless a later feature branch is explicitly
chosen.

## Live desktop boundaries

Editing files under `/home/Duku/.config/eww` changes files used by the live Eww
daemon, but does not necessarily reload the daemon.

The live Hyprland file is outside the repository:

```text
/home/Duku/.config/hypr/hyprland.conf
```

The tracked mirror is:

```text
/home/Duku/.config/eww/hyprland.conf
```

When a Hyprland change is required:

1. show the proposed tracked-file diff;
2. explain why Hyprland must change;
3. edit both files deliberately after approval;
4. compare them;
5. run `hyprctl configerrors`;
6. report whether a reload or next-login effect is expected.

Do not modify the secondary clone at `/home/Duku/Projects/SenomyOS`.

## Change size

Prefer stages that can be reverted or diagnosed independently:

- one data collector;
- one shared state transition;
- one bar layout;
- one panel shell;
- one section;
- one action/confirmation flow.

Avoid mixing structural Yuck changes, a large SCSS redesign, data collectors,
and Hyprland startup changes in one commit.

## Shell validation

For every changed shell script:

```bash
bash -n path/to/script.sh
```

For JSON-producing scripts, execute the read-only status path and validate:

```bash
bash path/to/script.sh | jq -e .
```

If a script has mutating verbs, validate only a documented read-only or dry-run
path until the user approves the action.

Check executable modes deliberately. A script invoked directly requires an
executable bit; a script invoked through `bash` does not.

## Eww validation

Eww 0.5.0 is the current target.

Before a live reload:

1. inspect Yuck includes and references;
2. check that every custom widget/window name is defined exactly once;
3. validate script outputs;
4. inspect SCSS for obvious syntax and selector errors;
5. show the diff;
6. warn that the bar may briefly disappear if parsing fails.

Where practical, validate a copied configuration with an isolated Eww instance
rather than disturbing the live daemon. Do not claim that `eww debug` validates
unloaded on-disk edits; it primarily describes the running daemon state.

After an approved live reload:

```bash
eww active-windows
eww state
eww logs
```

Verify the bar visually and test repeated-click and cross-surface switching.

## Hyprland validation

After an approved live Hyprland change:

```bash
hyprctl configerrors
```

When the tracked and live copies are intended to match:

```bash
cmp -s /home/Duku/.config/eww/hyprland.conf \
  /home/Duku/.config/hypr/hyprland.conf
```

An empty `hyprctl configerrors` response means no reported configuration
errors.

## Diff and commit gate

Before every commit:

```bash
git diff --check
git status --short
git --no-pager diff
```

Then report:

- files changed;
- user-visible effect;
- validation performed;
- limitations or planned follow-up;
- whether live state was reloaded.

Use small commit messages such as:

```text
docs: define SenomyOS shell architecture
fix(runtime): remove redundant update loop
feat(bar): add shared surface state
feat(insights): add truthful briefing shell
```

Do not push unless the user asks. Never push directly to `main`.

## Recovery

A recovery snapshot exists at:

```text
/home/Duku/SenomyOS-recovery/20260719-170831
```

Treat it as read-only unless the user explicitly asks to restore from it.
Before restoring anything, compare the exact target and explain what would be
overwritten.
