# Native utility handoffs

## Scope

Kitty diagnostic/console sessions, `nm-connection-editor`, Flameshot, GTK Inspector, native tray menus, polkit/authentication dialogs, and other third-party utilities opened from Senomy surfaces.

## Visual contract

- Level 0: compositor decoration only.
- Level 1: compositor plus safe namespaced toolkit tokens.
- Privileged: native identity, consequence, focus, and confirmation take precedence over shell styling.
- No arbitrary third-party client receives an Eww Large frame.

## Handoff contract

The originating Senomy control states what opens, why, whether it is native, and what data/action scope it has. Curated console/diagnostic actions keep fixed commands and arguments. Untrusted widget text is never interpolated into a shell command.

## Acceptance

Window placement and focus are predictable; return to the originating surface is clear; tool failure is reported truthfully; privilege and destructive-action cues remain native and unmistakable.
