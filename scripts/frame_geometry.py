"""Native vector geometry for the SenomyOS Luminous Reliquary frame system.

The three corner families are deliberately authored at separate optical sizes.
Only the neutral edge paths are intended to stretch in a consumer.
"""

from __future__ import annotations


def stroke(
    path: str,
    color: str,
    width: float,
    opacity: float = 1.0,
    *,
    fill: str = "none",
) -> str:
    return (
        f'    <path d="{path}" fill="{fill}" stroke="{color}" '
        f'stroke-width="{width:g}" stroke-opacity="{opacity:g}" '
        'vector-effect="non-scaling-stroke"/>'
    )


CORNER_PATHS = {
    # Native client windows are clipped by Hyprland at a maximum 20px radius.
    # This adapter keeps the Reliquary stroke language while matching that
    # compositor silhouette instead of cropping a 32px or 48px panel corner.
    "window": (
        ("M1 19C1 9.059 9.059 1 19 1", "url(#senomy-frame-metal)", 1.25, 0.96),
        ("M4 19C4 10.716 10.716 4 19 4", "@COLD_SILVER@", 0.8, 0.78),
        ("M7 19C7 12.373 12.373 7 19 7", "@STEEL@", 0.68, 0.78),
        ("M1.8 14.5C4.5 7.5 7.5 4.5 14.5 1.8", "@IVORY@", 0.5, 0.7),
        ("M3 17C3.7 13 6 9 9.5 6.2", "url(#senomy-frame-violet)", 0.66, 0.88),
    ),
    "compact": (
        ("M1 15C1 7.268 7.268 1 15 1", "url(#senomy-frame-metal)", 1.15, 0.94),
        ("M4 15C4 8.925 8.925 4 15 4", "@STEEL@", 0.72, 0.78),
        ("M1.8 11.8C3.15 6.9 6.9 3.15 11.8 1.8", "@IVORY@", 0.48, 0.66),
        ("M2.2 13.7C2.8 11.1 3.55 9.1 5.2 7.3", "url(#senomy-frame-violet)", 0.62, 0.88),
    ),
    "standard": (
        ("M1 31C1 14.431 14.431 1 31 1", "url(#senomy-frame-metal)", 1.35, 0.96),
        ("M4 31C4 16.088 16.088 4 31 4", "@COLD_SILVER@", 0.84, 0.76),
        ("M8 31C8 18.297 18.297 8 31 8", "@STEEL@", 0.72, 0.76),
        ("M1.8 23.5C6.1 11.4 11.4 6.1 23.5 1.8", "@IVORY@", 0.52, 0.74),
        ("M3 28C4.4 21 8.5 15.2 14.2 10.5", "url(#senomy-frame-violet)", 0.68, 0.86),
        ("M8.7 8.7 13.2 7.8 15.4 4.1", "@STRUCTURAL@", 0.8, 0.9),
    ),
    "large": (
        ("M1 47C1 21.595 21.595 1 47 1", "url(#senomy-frame-metal)", 1.5, 0.98),
        ("M4.5 47C4.5 23.528 23.528 4.5 47 4.5", "@COLD_SILVER@", 0.94, 0.80),
        ("M9.5 47C9.5 26.289 26.289 9.5 47 9.5", "@STEEL@", 0.78, 0.82),
        ("M15 47C15 29.327 29.327 15 47 15", "@STRUCTURAL@", 0.74, 0.9),
        ("M2 34.5C8 17.1 17.1 8 34.5 2", "@IVORY@", 0.58, 0.78),
        ("M3.2 43.5C5.8 31 12.8 21.5 22.5 14.2", "url(#senomy-frame-violet)", 0.72, 0.88),
        ("M10.2 16.4 16.8 13.5 20.4 7.2M16.4 10.2 13.5 16.8 7.2 20.4", "@COLD_SILVER@", 0.55, 0.68),
    ),
}


MOTIF_PATHS = {
    "workspace": (
        ("M0 3H3.2L5 1.2 6.8 3H10", "@COLD_SILVER@", 0.7, 0.82),
        ("M5 1.2 6.8 3 5 4.8 3.2 3Z", "url(#senomy-frame-violet)", 0.55, 0.92),
    ),
    "identity": (
        ("M0 6H7L12 1 17 6H24", "@COLD_SILVER@", 0.75, 0.86),
        ("M6 6 9.2 4.6 12 .8 14.8 4.6 18 6", "@IVORY@", 0.52, 0.82),
        ("M12 1 14.2 3.2 12 5.4 9.8 3.2Z", "url(#senomy-frame-violet)", 0.62, 0.95),
    ),
    "telemetry": (
        ("M0 3H5L7 1 9 5 11 3H18", "@COLD_SILVER@", 0.72, 0.82),
        ("M7 1 9 5", "url(#senomy-frame-violet)", 0.65, 0.88),
    ),
    "controls": (
        ("M0 3H3.2M6.8 3H10", "@COLD_SILVER@", 0.72, 0.82),
        ("M5 1 7 3 5 5 3 3Z", "url(#senomy-frame-violet)", 0.58, 0.9),
    ),
    "clock-notification": (
        ("M0 3H3.5M6.5 3H10", "@COLD_SILVER@", 0.72, 0.82),
        ("M5 1.5 6.5 3 5 4.5 3.5 3Z", "url(#senomy-frame-violet)", 0.5, 0.86),
    ),
    "power": (
        ("M1 4A3 3 0 1 0 7 4A3 3 0 1 0 1 4", "@COLD_SILVER@", 0.7, 0.78),
        ("M4 .5V3.5", "url(#senomy-frame-violet)", 0.68, 0.92),
    ),
    "diagnostic-tick": (
        ("M0 4H9L14 1 19 4H28", "@COLD_SILVER@", 0.72, 0.82),
        ("M14 1 16 4 14 7 12 4Z", "url(#senomy-frame-violet)", 0.62, 0.92),
    ),
    "junction": (
        ("M3 .5 5.5 3 3 5.5.5 3Z", "url(#senomy-frame-violet)", 0.55, 0.92),
        ("M3 1.5V4.5M1.5 3H4.5", "@IVORY@", 0.45, 0.84),
    ),
}


CREST_PATHS = {
    "mini": (
        ("M0 7H10L16 1 22 7H32", "@COLD_SILVER@", 0.72, 0.82),
        ("M9 7 12.5 5.5 16 .8 19.5 5.5 23 7", "@IVORY@", 0.48, 0.82),
        ("M16 1.2 18.2 3.4 16 5.6 13.8 3.4Z", "url(#senomy-frame-violet)", 0.58, 0.92),
    ),
    "medium": (
        ("M0 22H20C30 22 34 13 42 13L48 2 54 13C62 13 66 22 76 22H96", "@COLD_SILVER@", 0.9, 0.86),
        ("M18 22C31 19 36 10 42 8M54 8C60 10 65 19 78 22", "@IVORY@", 0.58, 0.78),
        ("M48 1 54 8 48 15 42 8Z", "url(#senomy-frame-violet)", 0.75, 0.94),
        ("M48 1V25", "@STRUCTURAL@", 0.7, 0.9),
    ),
    "wide": (
        ("M0 40H28C42 40 49 30 61 30C72 30 77 17 84 17L90 2 96 17C103 17 108 30 119 30C131 30 138 40 152 40H180", "@COLD_SILVER@", 1.05, 0.88),
        ("M22 40C43 36 51 24 63 23M117 23C129 24 137 36 158 40", "@IVORY@", 0.66, 0.82),
        ("M61 30C73 25 78 14 84 11M96 11C102 14 107 25 119 30", "@STEEL@", 0.72, 0.82),
        ("M90 1 98 10 90 22 82 10Z", "url(#senomy-frame-violet)", 0.9, 0.95),
        ("M90 1V46", "@STRUCTURAL@", 0.76, 0.92),
    ),
}


def corner_geometry(tier: str, corner: str, width: int, height: int) -> str:
    transforms = {
        "tl": "",
        "tr": f'transform="translate({width} 0) scale(-1 1)"',
        "bl": f'transform="translate(0 {height}) scale(1 -1)"',
        "br": f'transform="translate({width} {height}) scale(-1 -1)"',
    }
    lines = [f'    <g {transforms[corner]}>' if transforms[corner] else "    <g>"]
    lines.extend(stroke(*entry) for entry in CORNER_PATHS[tier])
    lines.append("    </g>")
    return "\n".join(lines)


def edge_geometry(edge: str, width: int, height: int) -> str:
    if edge == "top":
        paths = ((f"M0 1H{width}", "url(#senomy-frame-metal)", 1.05, 0.92),
                 (f"M0 3.35H{width}", "@STEEL@", 0.6, 0.66))
    elif edge == "bottom":
        paths = ((f"M0 {height - 1}H{width}", "url(#senomy-frame-metal)", 1.05, 0.92),
                 (f"M0 {height - 3.35:g}H{width}", "@STEEL@", 0.6, 0.66))
    elif edge == "left":
        paths = ((f"M1 0V{height}", "url(#senomy-frame-metal)", 1.05, 0.92),
                 (f"M3.35 0V{height}", "@STEEL@", 0.6, 0.66))
    else:
        paths = ((f"M{width - 1} 0V{height}", "url(#senomy-frame-metal)", 1.05, 0.92),
                 (f"M{width - 3.35:g} 0V{height}", "@STEEL@", 0.6, 0.66))
    return "\n".join(stroke(*entry) for entry in paths)


def motif_geometry(name: str) -> str:
    return "\n".join(stroke(*entry) for entry in MOTIF_PATHS[name])


def crest_geometry(name: str) -> str:
    return "\n".join(stroke(*entry) for entry in CREST_PATHS[name])
