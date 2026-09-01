# SenomyOS SDDM theme

This is the repository-owned SDDM source for the lower authentication
instruments. Its desktop layout uses independent Standard-tier modules from the
shared Luminous Reliquary frame system; the narrow layout uses the same frame
grammar. SDDM runs before a user session exists, so it uses the static,
privacy-safe blurred wallpaper in `assets/background.png`. The matching
Hyprlock source captures and blurs the real desktop only after the user session
has started.

The theme calls only SDDM's authentication, session-selection, keyboard,
restart, and power APIs. It does not expose an application launcher, URL
handler, shell, or arbitrary command execution.

The companion SDDM session guards preserve the standard session launchers for
ordinary users. For `senomy-recovery`, they deny every X11 session and every
Wayland command except the exact restricted recovery launcher. Provisioning
also assigns `/usr/bin/nologin`, so the credential cannot open a TTY or SSH
shell.

Normal session selection explicitly excludes `Senomy Recovery`, including
when SDDM reports it as the remembered last session. The greeter revalidates
the selected session before every normal login and uses ordinary `Hyprland` as
the preferred safe fallback.

`RECOVER` switches authentication to the dedicated `senomy-recovery` account
and the `Senomy Recovery` session. That runtime is installed and provisioned by
the privileged deployment workflow; the recovery credential is separate from
the normal user credential.

The bundled interface icons are selected from KDE's Breeze Icons and retain
their upstream LGPL license. The Senomy avatar and blurred background are
project assets.
