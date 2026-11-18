# Workflow acceptance reference

Stable W IDs and expected journeys from the existing acceptance matrix.
These rows specify tests; they do not claim execution or current support.
Current scoped results/remaining gates live in [PROJECT_STATE](../PROJECT_STATE.md).
Keep hashes, provider versions, environment, exclusions and evidence level in
the actual dated receipt. Never run device/lifecycle/authentication steps just
because they appear below. Quarantined compositor runners remain disabled.

## D01 — Obsidian Rail

| Workflow / class | Steps and expected result |
| --- | --- |
| W01.01 First setup | start clean laptop session and enumerate Rail layers; expect one per enabled independent output. |
| W01.02 Daily | invoke each quick control by pointer and keyboard; expect one transient, intended route and preserved Settings. |
| W01.03 Advanced | hide an external Rail and change workspace indicator policy; expect documented persistence and another access path. |
| W01.04 Failure | remove one data provider in a fixture; expect unavailable status with working launcher/session access. |
| W01.05 Change | attach/remove a mixed-scale display; expect correct instances, work-area reserve and no orphan overlay. |
| W01.06 Restart | restart only a disposable shell fixture; expect applications survive and preferences reload. |

## D02 — Quick popovers and panel management

| Workflow / class | Steps and expected result |
| --- | --- |
| W02.01 First setup | open every popup on a clean screen; expect a single correctly anchored transient. |
| W02.02 Daily | switch audio→network→calendar rapidly; expect no overlap and correct focus return. |
| W02.03 Advanced | open full Settings then a quick popup; expect existing Settings instance/content retained. |
| W02.04 Failure | deliver an old focus-clear callback after replacement; expect current popup remains mapped. |
| W02.05 Change | remove the popup-owning output in an isolated screen fixture then on hardware; expect safe dismissal/rehome policy. |
| W02.06 Restart | reload a disposable UI during pending backend work; expect backend receipt recoverable and no implied confirmation. |

## D03 — Command Lens

| Workflow / class | Steps and expected result |
| --- | --- |
| W03.01 First setup | discover installed apps and an empty file root; expect real catalogs and useful empty explanation. |
| W03.02 Daily | search exact app, prefix file and existing window using keyboard; expect deterministic activation. |
| W03.03 Advanced | configure a bounded file-search root and reveal a path with spaces; expect literal permitted identity. |
| W03.04 Failure | remove a result/provider before activation; expect rejection and visible error while other scopes work. |
| W03.05 Change | install/remove desktop entry or rename a file externally; expect fresh catalog after documented refresh. |
| W03.06 Restart | reopen Lens after shell restart; expect fixed geometry and configured roots retained without fictitious history. |

## D04 — Network and Wi-Fi

| Workflow / class | Steps and expected result |
| --- | --- |
| W04.01 First setup | connect an unknown secured SSID through the NM-owned TTY; expect secrets outside QML and actual connectivity. |
| W04.02 Daily | scan, connect saved Wi-Fi and review disconnect; expect progress, timeout and authoritative result. |
| W04.03 Advanced | edit IPv4/IPv6/DNS and create VPN in native editor; expect plugin-aware save and real traffic test. |
| W04.04 Failure | reject credentials and lose adapter mid-attempt; expect retryable failure without automatic password reuse. |
| W04.05 Change | switch wired/Wi-Fi externally and encounter captive portal; expect truthful interface/connectivity state. |
| W04.06 Restart | relogin with NM autoconnect configured; expect provider-owned policy and accurate Rail state. |

## D05 — Bluetooth

| Workflow / class | Steps and expected result |
| --- | --- |
| W05.01 First setup | pair a keyboard with displayed PIN and a headset with confirmation; expect correct real agent path. |
| W05.02 Daily | reconnect paired CMF Buds Pro 2 without forgetting; expect observed BlueZ service and separate audio outcome. |
| W05.03 Advanced | review alias/trust/block and inspect battery/services; expect exact identity and unsupported fields explained. |
| W05.04 Failure | cancel slow Connect/Pair, retry, and inspect native error; expect bounded terminal state and no stuck busy flag. |
| W05.05 Change | switch adapter, remove device or restart private BlueZ provider; expect generation-safe refresh and no borrowed scan stopped. |
| W05.06 Restart | reopen after shell restart and real suspend; expect pairing retained by BlueZ and no fabricated connected state. |

## D06 — Audio and media

| Workflow / class | Steps and expected result |
| --- | --- |
| W06.01 First setup | enumerate built-in output/mic and test sound/capture with native tools; expect real usable devices. |
| W06.02 Daily | change output during a disposable call and mute mic; expect selected device and per-stream routing observed. |
| W06.03 Advanced | choose A2DP/HFP or HDMI port and remember an app route; expect supported options and honest persistence semantics. |
| W06.04 Failure | remove endpoint or stop private graph watcher during pending review; expect refusal/timeout and retry access. |
| W06.05 Change | connect Bluetooth/USB/DP audio while mixer is open; expect live model and no false default claim. |
| W06.06 Restart | restart a disposable PipeWire/WirePlumber fixture/session; expect defaults and documented route policy restored. |

## D07 — Power, battery and session controls

| Workflow / class | Steps and expected result |
| --- | --- |
| W07.01 First setup | inspect intended versus actual power/idle ownership; preserve the user-selected inactive automatic timers. Activate only if separately chosen. |
| W07.02 Daily | inspect both battery packs and review/cancel a session action; expect truthful state without unintended mutation. |
| W07.03 Advanced | schedule lock in a disposable session, replace/cancel it and review power policy; expect one authoritative receipt. |
| W07.04 Failure | lose timer/provider or hit inhibitor; expect failed/unverified outcome and no force/retry bypass. |
| W07.05 Change | unplug AC, hot-remove supported pack or suspend/resume; expect correct aggregate state and the explicitly selected recovery/locking policy. |
| W07.06 Restart | separately authorize lifecycle acceptance; preserve chosen remain-on policy and prevent stale schedules in another session. |

## D08 — Displays and multi-monitor management

| Workflow / class | Steps and expected result |
| --- | --- |
| W08.01 First setup | identify every detected output including disabled ones and choose preferred screen; expect complete identity-aware inventory. |
| W08.02 Daily | preview Extend/Duplicate/Only modes with real windows; expect no lost clients and explicit Keep/Revert. |
| W08.03 Advanced | put two 1920×1080 externals at 0,0 and 1920,0 and laptop at 960,1080; expect logical preview/readback match. |
| W08.04 Failure | let preview expire or kill only a private renderer after arming fake recovery; expect independent rollback and visible failure receipt. |
| W08.05 Change | unplug/replug dock with a saved layout and mixed scale; expect safe missing/ambiguous state and bounded recovery. |
| W08.06 Restart | cold-login with matching/partial/delayed outputs; expect valid confirmed restoration and saved draft retained without surprise application. |

## D09 — Workspaces and window management

| Workflow / class | Steps and expected result |
| --- | --- |
| W09.01 First setup | connect two external displays with empty native landing workspaces; expect no unwanted pre-created indicators. |
| W09.02 Daily | create/switch local workspace 1 on each output; expect different native IDs and independent focus. |
| W09.03 Advanced | move a window then its workspace between monitors and set persistence; expect correct membership and local label. |
| W09.04 Failure | close/move selected window before confirmation; expect stale identity refusal and no unrelated movement. |
| W09.05 Change | remove monitor containing populated workspaces; expect windows retained and guest/home policy explicit. |
| W09.06 Restart | restart renderer then new compositor session in safe attended environment; expect policy restored without rendering-side creation. |

## D10 — Calendar, events, notes and reminders

| Workflow / class | Steps and expected result |
| --- | --- |
| W10.01 First setup | create a local event and dated note; expect durable records and clock date markers from the same owner. |
| W10.02 Daily | navigate Today/month/week/day, edit a recurring occurrence and snooze reminder; expect consistent agenda/briefing. |
| W10.03 Advanced | import ICS/CSV with DST/all-day recurrence then export; expect canonical preserved identity and bounded preview. |
| W10.04 Failure | lose socket during save, retry same request and recover draft; expect no duplicate or silent overwrite. |
| W10.05 Change | change display timezone or manually sync conflicting CalDAV edit; expect explicit conflict and no plaintext secrets in shell state. |
| W10.06 Restart | restart private daemon with pending reminder/draft and reopen UI; expect persistence, no duplicate alarm and honest uncertainty. |

## D11 — Notifications

| Workflow / class | Steps and expected result |
| --- | --- |
| W11.01 First setup | send replacement/action/transient/critical notifications on a private bus; expect one owner and correct capabilities. |
| W11.02 Daily | open/close centres, mark one message read and dismiss another; expect retained unrelated records. |
| W11.03 Advanced | configure app-specific popup/history policy once implemented; expect stable desktop-entry matching and default fallback. |
| W11.04 Failure | fail history save or change owner mid-clear; expect explicit uncertainty and stale review refusal. |
| W11.05 Change | reorder/remove primary output and enable DND; expect documented toast target and Critical behavior. |
| W11.06 Restart | restart private server, replay duplicate ID and inspect history; expect bounded retention and disabled stale actions. |

## D12 — Input and devices

| Workflow / class | Steps and expected result |
| --- | --- |
| W12.01 First setup | select system keyboard layout with fallback in isolated session; expect real compositor state before persisted success. |
| W12.02 Daily | change pointer speed/natural scroll/tap and revert; expect observed behavior and working keyboard. |
| W12.03 Advanced | use IME and OSK with physical Caps Lock plus multiple layouts; expect synchronized modifiers and safe protocol gating. |
| W12.04 Failure | inject zero-exit API rejection or partial apply; expect no false save, bounded rollback and useful error. |
| W12.05 Change | hotplug keyboard/mouse/touchscreen/camera; expect correct inventory and supported per-device controls only. |
| W12.06 Restart | relogin and externally change input settings; expect actual state reconciled with saved intent. |

## D13 — Applications and desktop integration

| Workflow / class | Steps and expected result |
| --- | --- |
| W13.01 First setup | discover applications and choose browser/file handlers; expect real XDG/GIO state and safe launching. |
| W13.02 Daily | launch app, open file and focus existing window through Lens; expect intended app and surviving process ownership. |
| W13.03 Advanced | add/disable user autostart override and edit MIME role; expect future-login semantics and retained system defaults. |
| W13.04 Failure | remove desktop entry or deny portal permission; expect stale-refusal/error with no blanket approval. |
| W13.05 Change | mount removable media and share screen from real native app; expect actual provider prompt and usable result. |
| W13.06 Restart | restart disposable shell with launched app, then next login for autostart; expect app survival and configured startup. |

## D14 — Accounts, authentication and security

| Workflow / class | Steps and expected result |
| --- | --- |
| W14.01 First setup | create a disposable standard account, set password in system TTY and login; expect usable session without privilege leakage. |
| W14.02 Daily | edit own display name/avatar and lock/unlock screen; expect real provider and greeter refresh. |
| W14.03 Advanced | authorize another inactive account type/lock change; expect polkit plus last-admin safeguards. |
| W14.04 Failure | cancel authorization, remove target externally or lose provider; expect no false success and safe refresh. |
| W14.05 Change | sign another account in during review and attempt deletion/demotion; expect active/quorum protection. |
| W14.06 Restart | reboot disposable system and authenticate normal/recovery sessions; expect isolated roles and retained home data. |

## D15 — Personalisation and appearance configuration

| Workflow / class | Steps and expected result |
| --- | --- |
| W15.01 First setup | review default skin/profile and select a background; expect preview then explicit saved preference. |
| W15.02 Daily | toggle reduced motion/text contrast and change image scrim; expect consistent shared surfaces. |
| W15.03 Advanced | import/export supported preferences once defined and configure per-output wallpaper; expect explicit scope. |
| W15.04 Failure | use missing/corrupt image or malformed manifest; expect previous usable fill and actionable error. |
| W15.05 Change | modify preferences externally with a dirty form; expect conflict preservation rather than overwrite. |
| W15.06 Restart | reload private shell from saved preferences; expect same settings and recoverable invalid-config path. |

## D16 — Performance, telemetry and Senomy Insights

| Workflow / class | Steps and expected result |
| --- | --- |
| W16.01 First setup | leave all panels closed then open Performance; expect prior continuous real samples, not synthesized history. |
| W16.02 Daily | inspect CPU/RAM/disk/net and a process; expect units/timestamps and bounded selection-safe data. |
| W16.03 Advanced | run an allowlisted diagnostic/export and a short approved disposable benchmark; expect bounded receipt and explicit completion. |
| W16.04 Failure | inject malformed proc counters/provider loss and stale PID reuse; expect null/reset/refusal without unrelated termination. |
| W16.05 Change | suspend/resume and alter clock in fixture; expect gaps/new epoch and no averaged spike. |
| W16.06 Restart | restart isolated sampler/renderer and run soak; expect explicit epoch reset, bounded buffers and stable measured cost. |

## D17 — Maintenance and recovery

| Workflow / class | Steps and expected result |
| --- | --- |
| W17.01 First setup | install staged payload in disposable clean root/VM; expect declared dependencies and no developer-home requirement. |
| W17.02 Daily | review source-specific update freshness and system/storage health; expect no implicit install. |
| W17.03 Advanced | approve maintained package-manager update handoff and export redacted support report; expect traceable result and reboot guidance. |
| W17.04 Failure | inject invalid config or failed package transaction in VM; expect usable independent recovery and honest rollback limits. |
| W17.05 Change | remove optional utility or fill state volume; expect bounded useful errors, retained previous settings and no shell crash. |
| W17.06 Restart | cold boot previous/current release and restore configuration snapshot in VM; expect exact payload/preferences provenance. |

## D18 — Login, boot and session lifecycle

| Workflow / class | Steps and expected result |
| --- | --- |
| W18.01 First setup | cold boot a disposable installation and login on laptop-only hardware; expect correct greeter/session and one shell owner. |
| W18.02 Daily | lock/unlock and logout via reviewed path; expect authenticated usable desktop and graceful session end. |
| W18.03 Advanced | login with multiple monitors and restore saved display/workspace policy; expect visible controls on usable outputs. |
| W18.04 Failure | crash/restart disposable shell with an inert launched app; expect app survives and native notification ownership recovers. |
| W18.05 Change | suspend/resume with changed dock/providers; expect valid outputs, lock and refreshed capabilities. |
| W18.06 Restart | reboot disposable system into normal then separate recovery session; expect reproducible owners and authenticated recovery. |

## D19 — Full Settings and Control Centre integration

| Workflow / class | Steps and expected result |
| --- | --- |
| W19.01 First setup | launch full Settings from desktop entry and shortcut; expect one reusable native window with real categories. |
| W19.02 Daily | use quick Audio then advanced link and back/forward; expect shared provider and retained navigation. |
| W19.03 Advanced | search a task phrase and deep-link exact setting from Lens; expect focus on authoritative live control. |
| W19.04 Failure | leave dirty Calendar/Appearance or pending review via external entry; expect explicit keep/discard/cancel and no lost draft. |
| W19.05 Change | move/close owning output with native Settings open; expect usable surviving window and coherent quick-popup state. |
| W19.06 Restart | reload private shell and reopen saved settings; expect persistent configuration, explicit transient history reset and no automatic apply. |

## D20 — Accessibility and reliability

| Workflow / class | Steps and expected result |
| --- | --- |
| W20.01 First setup | keyboard-only traversal plus real screen reader on supported profile; expect named controls and reachable recovery. |
| W20.02 Daily | perform network/audio/calendar workflows without mouse; expect correct focus and helpful errors. |
| W20.03 Advanced | enable large text/high contrast/reduced motion/touch profile; expect every primary action remains reachable. |
| W20.04 Failure | inject provider loss, malformed data, disk-full save and rapid overlay input; expect bounded recoverable states. |
| W20.05 Change | rotate/resize/hotplug mixed-scale screens and switch hardware/OSK input; expect stable coordinates and no stuck grabs. |
| W20.06 Restart | run 8h/24h fixture soak with reload/resume cycles; expect bounded memory/subscriptions and preserved app/draft state. |
