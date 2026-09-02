#!/usr/bin/env bash

# Validate the portable token registry and namespaced Rofi/GTK projections.
# GTK parsing is headless and does not launch or reconfigure an application.

set -euo pipefail
export LC_ALL=C

readonly CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TOKENS="$CONFIG_DIR/appearance/tokens.json"
readonly EWW_ENTRY="$CONFIG_DIR/eww.scss"
readonly ROFI_THEME="$CONFIG_DIR/appearance/launcher/rofi/themes/command-lens.rasi"
readonly ROFI_TOKENS="$CONFIG_DIR/appearance/launcher/rofi/themes/senomy-tokens.rasi"
readonly GTK_ROOT="$CONFIG_DIR/appearance/file-manager/gtk3/SenomyOS"
readonly GTK_THEME="$GTK_ROOT/gtk-3.0/gtk.css"
readonly GTK_TOKENS="$GTK_ROOT/gtk-3.0/senomy-tokens.css"
readonly GTK_ASSETS="$GTK_ROOT/gtk-3.0/assets"
readonly GTK_TOUCH_ROOT="$CONFIG_DIR/appearance/file-manager/gtk3/SenomyOS-Touch"
readonly GTK_TOUCH_THEME="$GTK_TOUCH_ROOT/gtk-3.0/gtk.css"
readonly FILE_ICON_ROOT="$CONFIG_DIR/appearance/file-manager/icons/SenomyOS-Files"
readonly FILE_ICON_PLACES="$FILE_ICON_ROOT/scalable/places"
GTK_PARSE_LOG="$(mktemp "${TMPDIR:-/tmp}/senomy-gtk-parse.XXXXXX")"
EWW_COMPILED_CSS="$(mktemp "${TMPDIR:-/tmp}/senomy-eww-css.XXXXXX")"
trap 'rm -f -- "$GTK_PARSE_LOG" "$EWW_COMPILED_CSS"' EXIT

"$CONFIG_DIR/scripts/generate-appearance.py" check
python3 "$CONFIG_DIR/scripts/validate-frame-system.py"
sassc "$EWW_ENTRY" "$EWW_COMPILED_CSS"
# sassc emits @charset when the stylesheet contains Nerd Font glyphs. GTK 3's
# CSS provider rejects that otherwise harmless first line, so validate the
# compiled declarations after removing only the generated charset directive.
sed -i '1{/^@charset /d;}' "$EWW_COMPILED_CSS"

jq -e '
  .schema_version == 1 and
  (.name | type == "string" and length > 0) and
  all(.colors.background,.colors.surface,.colors.surface_raised,.colors.foreground,
      .colors.muted,.colors.dim,.colors.border,.colors.accent,.colors.success,
      .colors.warning,.colors.danger; type == "string" and test("^#[0-9a-f]{6}$")) and
  (.colors.border_alpha >= 0 and .colors.border_alpha <= 1) and
  (.colors.border_strong_alpha >= 0 and .colors.border_strong_alpha <= 1) and
  (.colors.accent_surface_alpha >= 0 and .colors.accent_surface_alpha <= 1) and
  ([.palettes | keys[]] | sort) == ["amber", "cyan", "violet"] and
  all(.palettes[];
    (.accent | type == "string" and test("^#[0-9a-f]{6}$")) and
    (.bright | type == "string" and test("^#[0-9a-f]{6}$")) and
    (.soft_alpha >= 0 and .soft_alpha <= 1) and
    (.medium_alpha >= 0 and .medium_alpha <= 1) and
    (.strong_alpha >= 0 and .strong_alpha <= 1)
  ) and
  ([.palettes[].accent] | unique | length) == 3 and
  (.typography.family | type == "string" and length > 0) and
  (.typography.fallback | type == "string" and length > 0) and
  (.typography.base_px >= 11 and .typography.base_px <= 18) and
  (.geometry.radius_px >= 0 and .geometry.radius_px <= 8) and
  (.geometry.border_px == 1) and
  (.density.compact_row_px >= 30) and
  (.density.standard_row_px >= .density.compact_row_px) and
  (.density.touch_row_px >= 44) and
  (.frame_system.name == "Luminous Reliquary") and
  all(.frame_system.colors[];
    type == "string" and test("^#[0-9A-Fa-f]{6}$")
  ) and
  all(.frame_system.glass[]; . >= 0 and . <= 1)
' "$TOKENS" >/dev/null

python3 - "$CONFIG_DIR" "$TOKENS" "$ROFI_TOKENS" "$GTK_TOKENS" <<'PY'
from pathlib import Path
import json
import re
import sys

root = Path(sys.argv[1])
tokens = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
rofi = Path(sys.argv[3]).read_text(encoding="utf-8")
gtk = Path(sys.argv[4]).read_text(encoding="utf-8")
eww = "\n".join(
    path.read_text(encoding="utf-8")
    for path in (
        root / "eww.scss",
        root / "appearance/shell/eww.scss",
        root / "appearance/shell/_tokens.scss",
    )
)


def rgb(value: str) -> tuple[int, int, int]:
    return tuple(int(value[index:index + 2], 16) for index in (1, 3, 5))


rofi_names = {
    "background": "background-base",
    "surface": "surface",
    "surface_raised": "surface-raised",
    "foreground": "text-primary",
    "muted": "text-muted",
    "dim": "text-dim",
    "accent": "accent",
    "success": "success",
    "warning": "warning",
    "danger": "danger",
}
gtk_names = {
    "background": "senomy_bg",
    "surface": "senomy_surface",
    "surface_raised": "senomy_surface_raised",
    "foreground": "senomy_fg",
    "muted": "senomy_muted",
    "dim": "senomy_dim",
    "accent": "senomy_accent",
    "success": "senomy_success",
    "warning": "senomy_warning",
    "danger": "senomy_danger",
}

for key, rofi_name in rofi_names.items():
    red, green, blue = rgb(tokens["colors"][key])
    expected = f"{rofi_name}: rgba({red}, {green}, {blue},"
    if expected not in rofi:
        raise SystemExit(f"Rofi token projection is stale: {key}")

for key, gtk_name in gtk_names.items():
    expected = f"@define-color {gtk_name} {tokens['colors'][key]};"
    if expected not in gtk:
        raise SystemExit(f"GTK token projection is stale: {key}")

for key in ("background", "foreground", "muted", "accent"):
    value = tokens["colors"][key]
    red, green, blue = rgb(value)
    functional = re.compile(rf"rgba?\(\s*{red}\s*,\s*{green}\s*,\s*{blue}(?:\s*,|\s*\))")
    if value not in eww and not functional.search(eww):
        raise SystemExit(f"Eww core token is absent: {key}")
for family in (tokens["typography"]["family"], tokens["typography"]["fallback"]):
    if family not in eww:
        raise SystemExit(f"Eww font contract is absent: {family}")
for key, value in tokens["frame_system"]["colors"].items():
    expected = f"$senomy-frame-{key.replace('_', '-')}: {value};"
    if expected not in eww:
        raise SystemExit(f"Eww frame token projection is stale: {key}")
PY

grep -qF '@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained.css");' "$GTK_THEME"
grep -qF '@import url("senomy-tokens.css");' "$GTK_THEME"
grep -qF 'notebook > stack:not(:only-child),' "$GTK_THEME"
grep -qF 'notebook > stack > box {' "$GTK_THEME"
grep -qF 'url("assets/frame-window-corner-tl.svg")' "$GTK_THEME"
grep -qF 'border-radius: 20px;' "$GTK_THEME"
grep -qF '.preview-pane' "$GTK_THEME"
grep -qF 'THUNAR_IMAGE_PREVIEW_MODE_STANDALONE' "$CONFIG_DIR/components/file-manager/thunar/scripts/senomy-file-workspace"
grep -qF 'GtkTheme=SenomyOS' "$GTK_ROOT/index.theme"
grep -qF 'IconTheme=SenomyOS-Files' "$GTK_ROOT/index.theme"
grep -qF -- '-gtk-icon-theme: "SenomyOS-Files";' "$GTK_THEME"
grep -qF '@import url("gtk.css");' "$GTK_ROOT/gtk-3.0/gtk-contained.css"
grep -qF '@import url("../../SenomyOS/gtk-3.0/gtk.css");' "$GTK_TOUCH_THEME"
grep -qF 'GtkTheme=SenomyOS-Touch' "$GTK_TOUCH_ROOT/index.theme"
grep -qF 'IconTheme=SenomyOS-Files' "$GTK_TOUCH_ROOT/index.theme"
grep -qF 'min-height: 48px;' "$GTK_TOUCH_THEME"
grep -qF 'notebook combobox button.combo,' "$GTK_TOUCH_THEME"
grep -qF 'min-height: 40px;' "$GTK_TOUCH_THEME"
grep -qF '@import url("gtk.css");' "$GTK_TOUCH_ROOT/gtk-3.0/gtk-contained.css"

for asset in \
  frame-window-corner-tl.svg frame-window-corner-tr.svg \
  frame-window-corner-bl.svg frame-window-corner-br.svg \
  frame-window-edge-top.svg frame-window-edge-bottom.svg \
  frame-window-edge-left.svg frame-window-edge-right.svg; do
  [[ -s "$GTK_ASSETS/$asset" ]]
done

grep -qF 'Inherits=Adwaita,hicolor' "$FILE_ICON_ROOT/index.theme"
grep -qF 'Directories=scalable/places' "$FILE_ICON_ROOT/index.theme"
for icon in \
  folder folder-drag-accept folder-documents folder-download folder-music \
  folder-network folder-open folder-pictures folder-publicshare folder-remote \
  folder-saved-search folder-templates folder-videos folder-visiting; do
  [[ -s "$FILE_ICON_PLACES/$icon.svg" ]]
  rsvg-convert --width 32 --height 32 "$FILE_ICON_PLACES/$icon.svg" >/dev/null
done

if ! python3 - "$GTK_THEME" "$GTK_TOUCH_THEME" "$EWW_COMPILED_CSS" 2>"$GTK_PARSE_LOG" <<'PY'
from pathlib import Path
import sys
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

for filename in sys.argv[1:]:
    errors = []
    provider = Gtk.CssProvider()
    provider.connect("parsing-error", lambda _provider, section, error: errors.append(
        f"{Path(section.get_file().get_path() or '<resource>').name}:{section.get_start_line() + 1}: {error.message}"
    ))
    provider.load_from_path(filename)
    if errors:
        raise SystemExit("\n".join(errors))
PY
then
  cat "$GTK_PARSE_LOG" >&2
  exit 1
fi

for file in \
  "$TOKENS" \
  "$ROFI_THEME" \
  "$ROFI_TOKENS" \
  "$GTK_ROOT/index.theme" \
  "$GTK_ROOT/gtk-3.0/gtk.css" \
  "$GTK_ROOT/gtk-3.0/gtk-contained.css" \
  "$GTK_TOKENS" \
  "$GTK_TOUCH_ROOT/index.theme" \
  "$GTK_TOUCH_ROOT/gtk-3.0/gtk.css" \
  "$GTK_TOUCH_ROOT/gtk-3.0/gtk-contained.css" \
  "$FILE_ICON_ROOT/index.theme" \
  "$FILE_ICON_ROOT/folder.svg.in" \
  "$FILE_ICON_PLACES/folder.svg"; do
  [[ "$(stat -c %a "$file")" == 644 ]]
done

printf 'SenomyOS theme: canonical tokens, Rofi projection, GTK inheritance, scoped silver folders, touch density, and headless GTK/Eww CSS parsing passed.\n'
