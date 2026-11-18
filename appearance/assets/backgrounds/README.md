# Surface background images

Put static PNG, JPG or SVG images in this folder. No image is enabled by default.
Edit `appearance/skins/default.json`, under `backgrounds`, and set a surface's
`source` to `../assets/backgrounds/your-image.png`.

Example (an included neutral sample is available as `example.svg`):

```json
"senomy-expanded": {
  "source": "../assets/backgrounds/example.svg",
  "imageOpacity": 1,
  "scaling": "crop",
  "scrimOpacity": 0.2
}
```

Use `fit` instead of `crop` to show the entire image. `imageOpacity` and
`scrimOpacity` range from 0 to 1. The latter darkens the image for legibility.
An empty source restores the existing fill; unreadable images also fall back.
Paths resolve relative to the manifest; portable relative paths are preferred.
After replacing an image at the same path, run from the repository root:

```sh
touch appearance/skins/default.json
```

Editing the manifest refreshes automatically. No restart is needed.

| Surface | Background key |
|---|---|
| Senomy Rail | `senomy-rail` |
| Expanded Senomy | `senomy-expanded` |
| Empty media slot beneath Host | `senomy-media-empty` |
| Behind the inner ring and portrait | `senomy-ring` |
| Workspace chips | `workspace` |
| Activity island | `context` |
| System controls island | `control` |
| Clock island | `clock` |
| Power island | `power-island` |
| Control Centre | `control-center` |
| Performance Dashboard | `dashboard` |
| Insights | `insights` |
| Calendar, volume, tray, power popups | `calendar`, `volume`, `tray`, `power` |
| Notification centre and toast | `notifications`, `notification-toast` |
| Companion modes | `companion`, `companion-compact` |
| Reusable cards, buttons, charts | `card`, `button`, `chart` |
| Cathedral tooltips | `tooltip` |

The remaining manifest keys support their corresponding retained frame consumers.
Qt's standard attached tooltips and external application menus are not shell skin

Images sit inside the borders, below live content. They do not change hit targets,
layout, text or frame artwork. The ring background is circular on the normal GPU
renderer (Qt's software renderer does not implement the masking effect).
Use square images for the ring, wide images for Rail islands, and landscape images
for wide panels; keep focal subjects centred for narrow layouts. The general fill
renderer caps decoded target dimensions at 4096 pixels. Static assets only.

`senomy-media-empty` is shown only when no media session is available. Its empty
source leaves the slot empty; the separator under Host remains visible. Playing,
paused and stopped sessions retain controls while the application exposes MPRIS.
