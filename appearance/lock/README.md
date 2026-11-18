# Matching authentication lock

Generated Hyprlock profiles retain PAM, native password/failure feedback, disabled
fingerprint policy, empty-input handling and ext-session-lock ownership. A centered
320×460 Island groups account identity, password and keyboard context; the larger
clock stays above it. The chibi is omitted for now, with identity and field labels
rebalanced within that frame. Authored assets and existing typography roles are retained.
The composition targets at least 360×640 logical output; smaller outputs are not
certified. Nothing here starts a lock or changes automatic-idle policy.

`hyprlock.conf` keeps the native screenshot/blur fallback. `hyprlock-live.conf` uses
an empty image path and translucent ground for live compositor blur. The guarded
senomy-lock launcher chooses live only when its deployed live config is a regular
non-symlink file and both misc:session_lock_xray and misc:session_lock_blur return
typed boolean true. Disabled, missing or malformed capability evidence falls back
to screenshot blur. Existing-lock ownership prevents a duplicate child.

`live-background.lua` is an optional Hyprland policy example. Applying it is a
separate deliberate compositor change; do not include it automatically or replace
the running configuration just to test a theme. The installed reference compositor
exposes these options, but native lock/unlock rendering and lifecycle remain
unaccepted until attended verification.

The auth-only appearance generator owns both emitted configs. The preview tool's
--lock-only mode projects widgets over a labelled public substitute background with
the configured brightness and scrim layering. These are offline geometry/type/asset
projections, not real Hyprlock pixels, live desktop capture or authentication proof.
Do not invoke a real lock as an unattended visual test.
