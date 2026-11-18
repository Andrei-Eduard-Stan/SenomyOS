# Personal desktop wallpapers

On the reference development desktop, `desktop.png` in this folder is the live
selected wallpaper. Edit or atomically replace it to refresh the desktop within
about two seconds. Other images can live here without changing the selection.

Select an image in `${XDG_CONFIG_HOME:-$HOME/.config}/senomyos/wallpaper.json`:

```json
{
  "schema_version": 1,
  "source": "~/SenomyOS/appearance/wallpapers/desktop.png",
  "mode": "fill"
}
```

`source` supports an absolute path, `~/`, or a path relative to the settings
file. Modes: `fill`, `fit`, `stretch`, `center`, `tile`. Save the settings to
switch images live. Use static PNG or JPEG images supported by swaybg.

The launcher watches the selected file's metadata, including inode changes,
and the settings every half second; it waits for two stable samples before
loading. It does not repeatedly decode images or spawn commands while idle.
Invalid settings or failed image loads keep the previous running wallpaper.
On first launch, unavailable personal artwork falls back to the packaged image.
A single owner lock prevents duplicate watchers; it only stops its own provider.

The folder path above is a personal preference, not a packaged default.
Deployment installs the launcher, watcher and stock wallpaper, and does not
write personal wallpaper settings or this folder. A future Appearance picker can
write the same JSON contract. `senomy-wallpaper --once` is the legacy stock-image
handoff for diagnostics; normal login uses the live watcher automatically.
