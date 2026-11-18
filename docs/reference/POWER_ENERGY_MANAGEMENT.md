# Power and battery contracts

Current delivery and acceptance are in [PROJECT_STATE](../PROJECT_STATE.md).
Preserve TLP policy ownership, normal provider authorization and disabled
automatic-idle locking. Undocked lid policy is a separate unresolved choice.

## Ownership, profiles and failure handling

The old defect was `SENOMY_POWER_PROFILES_AVAILABLE`, exported once by the startup runner and trusted for the whole session. The runner no longer creates that gate and the current shell no longer consumes its inherited old value.

The adapter observes currently owned modern/legacy profile APIs without D-Bus auto-activation. A compatible owned API is used first; otherwise an enabled, readable modern TLP state has a narrowly allowlisted authenticated CLI path. An ordinary app or arbitrary executable is never accepted as a profile command. Multiple policy writers or distinct conflicting API owners disable writes. **tlp-pd is Python**: its D-Bus peer PID is matched to the active systemd unit MainPID, rather than guessing from interpreter or argv names. Private tests cover a real Python D-Bus peer with that unit association. Tuned and its own bridge count as one owner, not two competing tuners.

One shell-owned watcher subscribes to provider ownership/properties, relevant systemd units, TLP runtime-file events and logind sleep/resume notification. Events coalesce for 500ms; a 60-second reconciliation covers missed events/package changes. It does not poll full TLP inventories each second. Expensive care/CPU/inhibitor details are read only when Power is opened or explicitly refreshed; closed Settings starts no duplicate collector. Native UPower continues to own ordinary battery updates. Observer failure removes profile-write availability, retries with backoff and never removes independent battery state.

Every profile button enters the existing exact-target review. The request retains the reviewed provider/source/profile token; confirm revalidates it, restricts the profile and submits one operation. Pending/in-flight state blocks duplicate requests, including the interval before Qt marks a child process running. An early watcher echo cannot complete a running action: the actual worker receipt and readback must agree. A provider identity change, refused request, denied/cancelled authentication, malformed result, missing interpreter, timeout, profile mismatch or uncertain partial outcome is never persisted as success. Worker refresh generations reject older responses.

A failed request does not trigger a compensating blind write, replay, service restart or configuration edit. Only **reported profile state** is verified: TLP's many kernel settings are not an atomic transaction, and no claim is made that every underlying tunable can be restored after partial failure. If a failed operation leaves a different reported profile, it is explicitly partially-applied; missing/late D-Bus replies and owner replacement are unverified. A timeout may finish later. Refresh before retrying. Profile-operation failures use the existing native notification path once per operation, preserving DND/history policy; no new critical-battery automation was added.

### Selection lifetime and source rules

Current TLP runtime configuration has `TLP_AUTO_SWITCH=2`, AC assigned PRF/performance and battery assigned BAL/balanced. This is the provider's existing **smart switching**, not new SenomyOS automation. Its current `-m` result does not identify who last selected balanced; the UI says origin not reported rather than inventing automatic/manual provenance.

The fixed performance/balanced/power-saver commands request runtime profiles and clear TLP's traditional manual AC/BAT override. Smart source switching can preserve a non-default selection across an AC change; a runtime selection is not a durable SenomyOS preference. Re-selecting the previous profile does not reconstruct a former manual-mode flag. Provider defaults and reboot behaviour remain TLP-owned. No automatic low-battery/dock/display rule, persistent override, restore-on-login profile or application hold is created. With a compatible D-Bus provider, actual holds/degradation are shown and provider persistence remains explicit; selection can release holds. Holds are not falsely shown as supported on this CLI-only host.

## Battery accuracy and advanced limits

The native aggregate remains total physical-pack energy divided by total current full-charge energy, excluding the synthetic display device. Unknown/non-finite/negative energy or missing full capacity is not silently summed into a healthy/empty pack; a valid UPower display estimate is a labelled fallback. Unknown charge remains N/A and cannot trigger critical state. Charging, discharging, full, pending-charge/discharge and external power remain distinct. AC is not synonymous with charging. Zero reported rate is valid; negative/non-finite rate or unknown duration is unavailable. Existing UPower matching-state time-to-full/empty estimates remain estimates, with no fabricated zero-minute result.

Care health is a full/design capacity ratio, including a like-for-like charge-capacity fallback when energy units are unavailable. It is not charge percentage, a lifespan prediction or a general device-condition score. Care diagnostics show source and capture time, are refreshable and do not add continuous battery polling.

**Threshold editing is not implemented or advertised as working.** Supported interfaces are present, but authoritative vendor ranges/current TLP care policy were not obtained: `tlp-stat -b` requires root. The UPower/kernel discrepancy must also be resolved before a change. No 0–100 slider, generic sysfs write, threshold save, forced discharge, fullcharge or recalibration is offered. A privileged persistent TLP care transaction, exact prior-value restoration and separate hardware authorization are still required to complete this advanced capability. G18 remains partial. CPU frequency writes, fan controls, CPU-watt attribution and measured energy savings are not claimed. The existing thermal sampler remains unchanged.

A permanent keep-awake inhibitor would duplicate the user's chosen idle policy, so none is added. Actual existing inhibitor scope/reason is exposed without closing applications, releasing their FDs, overriding policy or claiming every inhibitor blocks every form of sleep.

## Protected battery-care operations

Keep exact-pack identity, native kernel/provider capability discovery, reviewed
start/stop bounds and explicit runtime-versus-persistent intent. The narrow
root-owned helper and normal polkit authorization are the only mutation boundary;
no generic sysfs writer, shell path, arbitrary command or client-selected file
is accepted. Revalidate inventory, ownership and thresholds after authentication.
Read back kernel, persistent file and TLP parser outcomes separately; report
per-pack partial failure. Preserve exact account-scoped preimages and reject
Restore over externally changed state. Unknown/ambiguous/timed-out outcomes
retain evidence for manual recovery rather than claiming success.

Installed helper provenance and private-bus tests do not accept actual charge
threshold, charging, reboot or cross-source behaviour. Raw UPower activation
presets/enable flags are not kernel threshold state. Preserve capacity-source
provenance and weighted provider estimates; an all-full flag is not permission
to invent a numeric 100 percent. Profile selection and battery care are distinct
operations. Do not replace TLP or enable idle/lid actions to make a checklist pass.
