#!/usr/bin/env bash

# Static staging checks only. No boot configuration or initramfs is touched.

set -euo pipefail
export LC_ALL=C

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PLYMOUTH="$REPO_ROOT/appearance/boot/plymouth/senomyos"
readonly GRUB="$REPO_ROOT/appearance/boot/grub/senomyos"
readonly BOOT="$REPO_ROOT/appearance/boot"
readonly BRAND="$REPO_ROOT/appearance/shared/brand"

jq -e '
  .schema_version == 1 and
  .branding.mark_source == "appearance/shared/brand/senomyos-mark.svg.in" and
  .branding.mark_generated == "appearance/shared/brand/senomyos-mark-256.png" and
  .branding.mark_boot_projection == "appearance/boot/assets/senomyos-mark.png" and
  .stages.firmware.managed_by_senomyos == false and
  .stages.bootloader.renderer == "grub" and
  .stages.bootloader.supports_video == false and
  .stages.early_userspace.renderer == "plymouth" and
  .stages.early_userspace.supports_video == false and
  (.stages.early_userspace.messages | length >= 3) and
  .activation.enabled == false
' "$BOOT/sequence.json" >/dev/null

mapfile -t mark_sources < <(find "$REPO_ROOT/appearance" -type f -name 'senomyos-mark.svg.in' -print)
[[ "${#mark_sources[@]}" -eq 1 && "${mark_sources[0]}" == "$BRAND/senomyos-mark.svg.in" ]]
grep -qF 'id="senomy-lancets"' "$BRAND/senomyos-mark.svg.in"
for lancet in left centre right; do
  grep -qF "id=\"senomy-lancet-${lancet}\"" "$BRAND/senomyos-mark.svg.in"
done

for size in 64 128 256; do
  file "$BRAND/senomyos-mark-${size}.png" | grep -qF "${size} x ${size}"
  [[ "$(stat -c %a "$BRAND/senomyos-mark-${size}.png")" == 644 ]]
done
[[ "$(stat -c %a "$BRAND/senomyos-mark.svg.in")" == 644 ]]
[[ "$(stat -c %a "$BRAND/senomyos-mark.svg")" == 644 ]]
cmp -s "$BRAND/senomyos-mark.svg" "$BOOT/assets/senomyos-mark.svg"
cmp -s "$BRAND/senomyos-mark-256.png" "$BOOT/assets/senomyos-mark.png"

grep -qxF 'ModuleName=script' "$PLYMOUTH/senomyos.plymouth"
grep -qxF 'ImageDir=/usr/share/plymouth/themes/senomyos' "$PLYMOUTH/senomyos.plymouth"
grep -qxF 'ScriptFile=/usr/share/plymouth/themes/senomyos/senomyos.script' "$PLYMOUTH/senomyos.plymouth"
grep -qF 'Window.SetBackgroundTopColor' "$PLYMOUTH/senomyos.script"
grep -qF 'Plymouth.SetMessageFunction(message_callback);' "$PLYMOUTH/senomyos.script"
grep -qF 'logo.image = Image("logo.png");' "$PLYMOUTH/senomyos.script"
! grep -Eq 'System\.|Command\.|/bin/|/usr/bin/' "$PLYMOUTH/senomyos.script"

grep -qxF 'desktop-image: "background.png"' "$GRUB/theme.txt"
grep -qxF 'desktop-image-scale-method: "crop"' "$GRUB/theme.txt"
grep -qF '+ boot_menu {' "$GRUB/theme.txt"
grep -qF 'file = "logo.png"' "$GRUB/theme.txt"
grep -qF 'id = "__timeout__"' "$GRUB/theme.txt"
python3 - "$GRUB/theme.txt" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
depth = 0
for line_number, raw in enumerate(text.splitlines(), 1):
    line = raw.split("#", 1)[0]
    depth += line.count("{") - line.count("}")
    if depth < 0:
        raise SystemExit(f"theme brace underflow at line {line_number}")
if depth:
    raise SystemExit("theme braces are unbalanced")
PY

file "$REPO_ROOT/appearance/shared/backgrounds/desktop.png" | grep -qF '1920 x 1080'
jq -e '.components[] | select(.id == "plymouth-staged") | .readiness == "ready"' "$REPO_ROOT/deploy/system-manifest.json" >/dev/null
jq -e '.components[] | select(.id == "grub-staged") | .readiness == "ready"' "$REPO_ROOT/deploy/system-manifest.json" >/dev/null
jq -e '.components[] | select(.id == "plymouth-staged") | any(.entries[]; .id == "logo")' "$REPO_ROOT/deploy/system-manifest.json" >/dev/null
jq -e '.components[] | select(.id == "grub-staged") | any(.entries[]; .id == "logo")' "$REPO_ROOT/deploy/system-manifest.json" >/dev/null
"$REPO_ROOT/scripts/senomy-system-deploy.sh" plan plymouth-staged >/dev/null
"$REPO_ROOT/scripts/senomy-system-deploy.sh" plan grub-staged >/dev/null
"$REPO_ROOT/scripts/senomy-bootctl" status | jq -e '.ok == true and .data.source.valid == true and .data.activation_ready == false' >/dev/null
"$REPO_ROOT/scripts/senomy-bootctl" plan plymouth | jq -e '.plan.status == "blocked"' >/dev/null
"$REPO_ROOT/scripts/senomy-bootctl" plan grub | jq -e '.plan.status == "blocked"' >/dev/null
if "$REPO_ROOT/scripts/senomy-bootctl" activate >/dev/null 2>&1; then
  printf 'Boot activation unexpectedly bypassed its acceptance gate.\n' >&2
  exit 1
fi

printf 'SenomyOS boot themes: Plymouth/GRUB sources stage cleanly and activation remains gated.\n'
