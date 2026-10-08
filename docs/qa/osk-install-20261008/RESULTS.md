# User-local OSK installation — 2026-10-08

User requested continued functional completion after being told missing tools
prevent keyboard launch. No sudo access; user-local path used.
Built wvkbd 0.21 mobintl from pinned upstream commit
bbecd996aae5a4dc4bc32bd643d37cefa9f63752 using installed build dependencies.
Extracted wayland-info from official Arch wayland-utils 1.3.0-1 package after
successful gpgv verification with the installed Arch keyring (Antonio Rojas).
No package database or service was changed. Installed only two previously absent
executables in ~/.local/bin; retained private source/downloads and receipt.
Live shell PATH already includes ~/.local/bin.

Read-only osk-capabilities.py detect: providerInstalled=true,
protocolState=advertised, manualCandidate=true, integrated=false.
Required interfaces meet minimum versions; optional input-method-v2 advertised.
No real OSK was launched. Actual text entry, touch, focus, occlusion, lock and
recovery acceptance remain open. Reopen Input to refresh the tool capability.

Sources: https://github.com/jjsullivan5196/wvkbd
https://archive.archlinux.org/packages/w/wayland-utils/

## Subsequent user-reported acceptance — 2026-10-08

The user reports successful typing and opening/closing the installed keyboard.
The original installation probe did not launch it; this later real-session report
closes that specific reference-session evidence gap. Phone/tablet touch, rotation,
automatic focus, occlusion, lock and recovery are not accepted by this report.
