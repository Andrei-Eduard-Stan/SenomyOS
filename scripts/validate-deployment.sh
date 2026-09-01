#!/usr/bin/env bash

# Exercise deployment plan, apply, receipt, history, rollback, and path guards
# entirely under a temporary root. No live user configuration is touched.

set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/senomy-deployment-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

readonly TEST_REPO="$TEST_ROOT/repository"
readonly TEST_RUNTIME="$TEST_ROOT/runtime"
readonly TEST_HOME="$TEST_ROOT/home"
readonly TEST_CONFIG="$TEST_HOME/.config"
readonly TEST_STATE="$TEST_HOME/.local/state"

mkdir -p "$TEST_REPO/scripts" "$TEST_REPO/deploy" "$TEST_REPO/sources" \
  "$TEST_REPO/bin" "$TEST_CONFIG/example" "$TEST_STATE" "$TEST_RUNTIME" "$TEST_HOME"
cp -- "$CONFIG_DIR/scripts/senomy-deploy.sh" "$TEST_REPO/scripts/senomy-deploy.sh"
cp -- "$CONFIG_DIR/scripts/thunar-uca-merge.py" "$TEST_REPO/scripts/thunar-uca-merge.py"
chmod 755 "$TEST_REPO/scripts/senomy-deploy.sh"
chmod 755 "$TEST_REPO/scripts/thunar-uca-merge.py"

printf 'new managed value\n' >"$TEST_REPO/sources/managed.conf"
printf 'new created value\n' >"$TEST_REPO/sources/created.conf"
printf 'failed deployment value\n' >"$TEST_REPO/sources/failure.conf"
printf '%s\n' '-- valid test config' >"$TEST_REPO/hyprland.lua"
printf 'original user value\n' >"$TEST_CONFIG/example/managed.conf"
printf 'original failure value\n' >"$TEST_CONFIG/example/failure.conf"
cp -- "$CONFIG_DIR/components/file-manager/thunar/actions.json" "$TEST_REPO/sources/thunar-actions.json"
cp -- "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-thunar-action" "$TEST_REPO/sources/thunar-helper"
chmod 755 "$TEST_REPO/sources/thunar-helper"
mkdir -p "$TEST_CONFIG/Thunar"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<actions>' \
  '  <action>' \
  '    <icon>utilities-terminal</icon>' \
  '    <name>Fixture User Action</name>' \
  '    <unique-id>1752824457083670-1</unique-id>' \
  '    <command>exo-open --working-directory %f --launch TerminalEmulator</command>' \
  '    <description>Preserve this action exactly</description>' \
  '    <patterns>*</patterns>' \
  '    <directories />' \
  '  </action>' \
  '</actions>' >"$TEST_CONFIG/Thunar/uca.xml"
cp -- "$TEST_CONFIG/Thunar/uca.xml" "$TEST_ROOT/original-uca.xml"
chmod 600 "$TEST_CONFIG/Thunar/uca.xml"
chmod 600 "$TEST_CONFIG/example/managed.conf"
chmod 600 "$TEST_CONFIG/example/failure.conf"
printf '#!/usr/bin/env bash\nif grep -q "failed deployment value" "$XDG_CONFIG_HOME/example/failure.conf"; then printf "fixture config error\\n"; fi\n' >"$TEST_REPO/bin/hyprctl"
printf '%s\n' '#!/usr/bin/env bash' '[[ "${SENOMY_TEST_THUNAR_RUNNING:-0}" == 1 ]]' >"$TEST_REPO/bin/pgrep"
printf '%s\n' '#!/usr/bin/env bash' 'cp -- /dev/stdin /dev/null' >"$TEST_REPO/bin/wl-copy"
printf '%s\n' '#!/usr/bin/env bash' '[[ "${SENOMY_TEST_HYPRLAND_INVALID:-0}" != 1 ]] || exit 1' 'printf "config ok\\n"' >"$TEST_REPO/bin/Hyprland"
chmod 755 "$TEST_REPO/bin/hyprctl" "$TEST_REPO/bin/pgrep" "$TEST_REPO/bin/wl-copy" "$TEST_REPO/bin/Hyprland"

jq -n '{
  schema_version:1,
  backup_namespace:"senomyos/deployments",
  components:[
    {id:"fixture",description:"Isolated deployment fixture.",scope:"user",readiness:"ready",
     reason:"Fixture sources exist.",post_apply:[],entries:[
       {id:"managed",source:"sources/managed.conf",target:{root:"xdg_config",path:"example/managed.conf"},kind:"file",strategy:"replace",mode:"0644"},
       {id:"created",source:"sources/created.conf",target:{root:"xdg_config",path:"example/created.conf"},kind:"file",strategy:"replace",mode:"0600"}
     ]},
    {id:"failure",description:"Automatic rollback fixture.",scope:"user",readiness:"ready",
     reason:"Fixture source exists.",post_apply:["hyprland-configerrors"],entries:[
       {id:"failure",source:"sources/failure.conf",target:{root:"xdg_config",path:"example/failure.conf"},kind:"file",strategy:"replace",mode:"0644"}
     ]},
    {id:"thunar",description:"Deterministic merge fixture.",scope:"user",readiness:"ready",
     reason:"Fixture sources exist.",warning:"Close Thunar before changing its custom actions.",
     pre_apply:["thunar-not-running"],post_apply:["thunar-uca-xml"],entries:[
       {id:"action-helper",source:"sources/thunar-helper",target:{root:"user_bin",path:"senomy-thunar-action"},kind:"file",strategy:"replace",mode:"0755"},
       {id:"uca",source:"sources/thunar-actions.json",target:{root:"xdg_config",path:"Thunar/uca.xml"},
        helper_target:{root:"user_bin",path:"senomy-thunar-action"},kind:"file",strategy:"thunar-uca-merge",mode:"0600"}
     ]},
    {id:"hyprland",description:"Validated Lua fixture.",scope:"user",readiness:"ready",
     reason:"Fixture source exists.",pre_apply:["hyprland-lua-valid"],post_apply:[],entries:[
       {id:"config",source:"hyprland.lua",target:{root:"xdg_config",path:"hypr/hyprland.lua"},kind:"file",strategy:"replace",mode:"0644"}
     ]},
    {id:"future",description:"Planned fixture.",scope:"user",readiness:"planned",reason:"Not implemented.",post_apply:[],entries:[]}
  ]
}' >"$TEST_REPO/deploy/manifest.json"

run_deployer() {
  HOME="$TEST_HOME" \
  XDG_CONFIG_HOME="$TEST_CONFIG" \
  XDG_STATE_HOME="$TEST_STATE" \
  XDG_RUNTIME_DIR="$TEST_RUNTIME" \
  PATH="$TEST_REPO/bin:$PATH" \
    "$TEST_REPO/scripts/senomy-deploy.sh" "$@"
}

plan="$(run_deployer plan fixture)"
grep -qE '^UPDATE[[:space:]]+managed' <<<"$plan"
grep -qE '^CREATE[[:space:]]+created' <<<"$plan"

apply_output="$(run_deployer apply fixture --yes)"
deployment_id="$(sed -n 's/^Deployment applied: //p' <<<"$apply_output")"
[[ "$deployment_id" =~ ^[0-9]{8}-[0-9]{6}-fixture-[0-9]+$ ]]
[[ "$(cat "$TEST_CONFIG/example/managed.conf")" == 'new managed value' ]]
[[ "$(stat -c %a "$TEST_CONFIG/example/managed.conf")" == 644 ]]
[[ "$(cat "$TEST_CONFIG/example/created.conf")" == 'new created value' ]]
[[ "$(stat -c %a "$TEST_CONFIG/example/created.conf")" == 600 ]]

receipt="$TEST_STATE/senomyos/deployments/$deployment_id/receipt.json"
jq -e '.status == "applied" and (.entries | length == 2)' "$receipt" >/dev/null
[[ "$(stat -c %a "$receipt")" == 600 ]]
run_deployer history | grep -q "$deployment_id"

printf 'unrecorded user edit\n' >"$TEST_CONFIG/example/managed.conf"
if run_deployer rollback "$deployment_id" --yes >/dev/null 2>&1; then
  printf 'Rollback unexpectedly overwrote unrecorded target drift.\n' >&2
  exit 1
fi
printf 'new managed value\n' >"$TEST_CONFIG/example/managed.conf"
chmod 644 "$TEST_CONFIG/example/managed.conf"
run_deployer rollback "$deployment_id" --yes >/dev/null
[[ "$(cat "$TEST_CONFIG/example/managed.conf")" == 'original user value' ]]
[[ "$(stat -c %a "$TEST_CONFIG/example/managed.conf")" == 600 ]]
[[ ! -e "$TEST_CONFIG/example/created.conf" ]]
jq -e '.status == "rolled-back"' "$receipt" >/dev/null

if run_deployer apply failure --yes >/dev/null 2>&1; then
  printf 'Failing post-apply check unexpectedly allowed deployment.\n' >&2
  exit 1
fi
[[ "$(cat "$TEST_CONFIG/example/failure.conf")" == 'original failure value' ]]
[[ "$(stat -c %a "$TEST_CONFIG/example/failure.conf")" == 600 ]]
failure_receipt="$(find "$TEST_STATE/senomyos/deployments" -mindepth 2 -maxdepth 2 -type f -name receipt.json -print0 |
  xargs -0 jq -r 'select(.component == "failure") | input_filename')"
[[ -n "$failure_receipt" ]]
jq -e '.status == "auto-rolled-back"' "$failure_receipt" >/dev/null

blocked_plan="$(SENOMY_TEST_THUNAR_RUNNING=1 run_deployer plan thunar)"
grep -q '^precondition: BLOCKED while Thunar is running' <<<"$blocked_plan"
if SENOMY_TEST_THUNAR_RUNNING=1 run_deployer apply thunar --yes >/dev/null 2>&1; then
  printf 'Thunar deployment unexpectedly ran while its process precondition was blocked.\n' >&2
  exit 1
fi
[[ ! -e "$TEST_HOME/.local/bin/senomy-thunar-action" ]]
cmp -s "$TEST_CONFIG/Thunar/uca.xml" "$TEST_ROOT/original-uca.xml"

thunar_plan="$(run_deployer plan thunar)"
grep -q '^precondition: ready; no Thunar process detected' <<<"$thunar_plan"
grep -qE '^CREATE[[:space:]]+action-helper' <<<"$thunar_plan"
grep -qE '^UPDATE[[:space:]]+uca' <<<"$thunar_plan"
thunar_apply="$(run_deployer apply thunar --yes)"
thunar_deployment_id="$(sed -n 's/^Deployment applied: //p' <<<"$thunar_apply")"
[[ "$thunar_deployment_id" =~ ^[0-9]{8}-[0-9]{6}-thunar-[0-9]+$ ]]
[[ -x "$TEST_HOME/.local/bin/senomy-thunar-action" ]]
xmllint --noout "$TEST_CONFIG/Thunar/uca.xml"
[[ "$(grep -c '<unique-id>' "$TEST_CONFIG/Thunar/uca.xml")" == 3 ]]
grep -q '<name>Fixture User Action</name>' "$TEST_CONFIG/Thunar/uca.xml"
grep -q '<name>Copy Path</name>' "$TEST_CONFIG/Thunar/uca.xml"
grep -q '<name>Copy SHA-256</name>' "$TEST_CONFIG/Thunar/uca.xml"
thunar_receipt="$TEST_STATE/senomyos/deployments/$thunar_deployment_id/receipt.json"
jq -e '
  .status == "applied" and
  .pre_apply == ["thunar-not-running"] and
  .post_apply == ["thunar-uca-xml"] and
  ([.entries[].strategy] | sort) == ["replace", "thunar-uca-merge"]
' "$thunar_receipt" >/dev/null
run_deployer rollback "$thunar_deployment_id" --yes >/dev/null
cmp -s "$TEST_CONFIG/Thunar/uca.xml" "$TEST_ROOT/original-uca.xml"
[[ "$(stat -c %a "$TEST_CONFIG/Thunar/uca.xml")" == 600 ]]
[[ ! -e "$TEST_HOME/.local/bin/senomy-thunar-action" ]]
jq -e '.status == "rolled-back"' "$thunar_receipt" >/dev/null

lua_plan="$(run_deployer plan hyprland)"
grep -q '^precondition: ready; Hyprland accepts the tracked Lua configuration' <<<"$lua_plan"
grep -qE '^CREATE[[:space:]]+config' <<<"$lua_plan"
if SENOMY_TEST_HYPRLAND_INVALID=1 run_deployer apply hyprland --yes >/dev/null 2>&1; then
  printf 'Invalid Hyprland Lua configuration unexpectedly deployed.\n' >&2
  exit 1
fi
[[ ! -e "$TEST_CONFIG/hypr/hyprland.lua" ]]
lua_apply="$(run_deployer apply hyprland --yes)"
lua_deployment_id="$(sed -n 's/^Deployment applied: //p' <<<"$lua_apply")"
[[ -f "$TEST_CONFIG/hypr/hyprland.lua" ]]
run_deployer rollback "$lua_deployment_id" --yes >/dev/null
[[ ! -e "$TEST_CONFIG/hypr/hyprland.lua" ]]

planned="$(run_deployer plan future)"
grep -q '^status: planned$' <<<"$planned"
if run_deployer apply future --yes >/dev/null 2>&1; then
  printf 'Planned component unexpectedly allowed apply.\n' >&2
  exit 1
fi

jq '.components[0].entries[0].target.path = "../escape.conf"' \
  "$TEST_REPO/deploy/manifest.json" >"$TEST_REPO/deploy/invalid.json"
if SENOMY_DEPLOY_MANIFEST="$TEST_REPO/deploy/invalid.json" run_deployer plan fixture >/dev/null 2>&1; then
  printf 'Parent traversal unexpectedly passed validation.\n' >&2
  exit 1
fi

printf 'SenomyOS deployment: plan, guarded merge, apply, receipt, history, drift guard, automatic rollback, manual rollback, readiness, and path guards passed.\n'
