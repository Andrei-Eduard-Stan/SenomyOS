# SenomyOS authentication Island

One compact Island groups selected account, password, Sign in, feedback and explicit
session/keyboard choices. Clock/date sit above it; readability, separate recovery
and guarded power actions stay subordinate. Account search and Other account preserve
exact usernames. Narrow and short outputs scroll focused fields and inline choices
into view. The chibi is omitted for now; account identity uses the full header width.
Pointer states are quiet; deliberate keyboard focus remains visible.

Main.qml retains the SDDM proxy and separate recovery boundary. Passwords clear on
handoff, failure, account change and protected review; busy/starting state prevents
repeat dispatch. Session directory/file/type identifies the chosen runtime across
model reordering; removal refuses handoff. Cancel is the default power-review target.
No authentication helper, password storage, arbitrary command or new PAM flow is added.

AuthBackdrop uses Qt Quick Effects MultiEffect to blur the bundled raw public
artwork. Software/unknown rendering and source-loading fallback use the paired
preblurred raster. This is a wallpaper on SDDM's separate greeter display; ordinary
logout ends the user desktop. No desktop-window capture is persisted for the greeter.

`theme.conf` owns Background/BlurredBackground, runtime BackgroundBlur and
BackgroundScrim. BackgroundArtwork points the auth-only generator to public artwork
under repository appearance/. Its default is the generated ivory/black/silver
metalheart master with embedded prompt and sidecar provenance. A later Settings
selector can target this separate login-background role without replacing the desktop
wallpaper. An administrative theme.conf.user may override runtime keys.

Use `scripts/generate-appearance.py build --auth-only` after changing source artwork;
review the resulting paired assets. Theme.js and authored corner projections remain
generated from the existing role system. Greeter fonts, artwork and native controls
are bundled/project-relative; SDDM needs Qt 6 with QtQuick.Effects. This stage adds no
package dependency beyond the existing native Qt stack.

The native fake-model/proxy suite and an independent RHI blur/sharp probe establish
composition and guarded dispatch at their scopes. They do not accept real PAM,
session start, output hotplug or physical input. A private headless run of the
installed SDDM test-mode executable did not complete; real greeter integration remains
unverified. Use the existing protected system deployment/rollback workflow and an
attended authentication check before release acceptance. Do not restart SDDM merely
to preview a theme.
