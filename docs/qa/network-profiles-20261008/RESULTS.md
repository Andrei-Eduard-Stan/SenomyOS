# Saved network profiles and observed connection results — 2026-10-08

Read-only structured UUID/name/type/autoconnect/active inventory never requests
saved secrets. Escaped delimiters are parsed, malformed/oversized output rejected.
Fixed allowlist supports Wi-Fi/wired/VPN/WireGuard profiles; other types read-only.
Profile delete/disconnect/autoconnect require Cancel-focused preview, context and
snapshot revalidation, fixed argv, and observed resulting state. Active profiles
cannot be deleted. Unknown post-request state is unverified; errors/timeouts never
mean success. Policy changes do not activate a connection. Overlapping radio/
profile/connection operations are blocked. No automatic retry.

Native network/VPN editor handoffs validate installed tools and profile UUIDs.
Started means launch requested, not saved or working. DNS and proxy use the native
profile editor; proxy means NetworkManager PAC connection settings, not a blanket
application-wide proxy guarantee. VPN requires installed plugins. Secure terminal
availability gates authentication; credentials remain outside shell state.
ConnectionAttempt listens for native connectionFailed reasons and observes link
completion separately from Internet reachability; timeout stays unverified.

`python3 scripts/validate-network-profiles.py`: 11 mocked backend tests, 7 profile
controller Qt cases, 7 connection-attempt cases, prior 15 radio-confirmation cases,
24-profile keyboard/focus fixture at 600/340px and actual service load/guard checks.
The latter reads native networking but invokes no device mutation; query-disabled
profile service cannot apply contextless/foreign/busy operations. Actual Control
Centre route fixture also passes at wide/constrained sizes, no fake mutations.
Targeted lint exits zero. Read-only live inventory: 13 profiles; editor installed.
No live profile edit/delete/activation/disconnect/policy change was performed.

Physical credential flow, native editor saving, VPN plugins, DNS/proxy behavior and
scan freshness remain attended acceptance. Integration patches use zero context
and preserve pre-existing dirty/untracked consumers; replay needs hash checks and
git apply --unidiff-zero. No clean-checkout/release claim.

Primary references:
https://networkmanager.dev/docs/libnm/latest/NMSettingProxy.html
https://quickshell.org/docs/v0.3.0/types/Quickshell.Networking/WifiNetwork/
Installed Quickshell Networking plugin metadata confirms connectionFailed reasons.
