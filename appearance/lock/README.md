# SenomyOS lock surface

`hyprlock.conf` is the in-session counterpart to the SDDM theme. Its background
uses Hyprlock's `screenshot` source with local GPU blur, so it represents the
real desktop without letting pointer or keyboard input reach that desktop.

The pointer remains visible so the lock surface does not look frozen. Hyprlock
authentication is keyboard-driven: password input is captured globally and
Enter submits it, so the input field does not need to be clicked or selected.
The deliberately high-contrast rail, strong input outline, and left-aligned
password indicators must make typed input apparent at ordinary laptop viewing
angles. `Super+L` invokes the deployed `senomy-lock` wrapper; it locks the
existing session and does not log out or discard applications.
The lock configuration deliberately contains no `onclick` entries and no
dynamic command labels. Regular Hyprland application bindings are unavailable
while the session-lock protocol is active; only separately declared locked
media/brightness bindings may continue to work.

Password recovery is not executed inside the authenticated user's locked
session. It is offered by SDDM and enters the separate restricted recovery
session after authenticating the recovery credential.
