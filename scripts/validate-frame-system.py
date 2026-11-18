#!/usr/bin/env python3
"""Validate and render the production SenomyOS frame asset system."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "appearance" / "shared" / "frames" / "frame-system.json"
SVG_NS = "http://www.w3.org/2000/svg"


def command(name: str) -> str:
    resolved = shutil.which(name)
    if not resolved:
        raise RuntimeError(f"{name} is required for frame-system validation")
    return resolved


def run(*args: str, capture: bool = False) -> str:
    result = subprocess.run(
        args,
        check=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip() if capture else ""


def validate_manifest(manifest: dict) -> None:
    if manifest.get("schema_version") != 1:
        raise ValueError("frame manifest schema_version must be 1")
    if sorted(manifest.get("tiers", {})) != ["compact", "large", "standard"]:
        raise ValueError("frame manifest must define compact, standard, and large")
    if len(manifest.get("motifs", {})) != 8:
        raise ValueError("frame manifest must define the eight production motifs")
    if sorted(manifest.get("crests", {})) != ["medium", "mini", "wide"]:
        raise ValueError("frame manifest must define mini, medium, and wide crests")

    for tier, spec in manifest["tiers"].items():
        minimum = spec["minimum"]
        corner = spec["corner"]
        safe = spec["content_safe"]
        edges = spec["edge"]
        if minimum["width"] < corner["width"] * 2:
            raise ValueError(f"{tier}: minimum width cannot contain both fixed corners")
        if minimum["height"] < corner["height"] * 2:
            raise ValueError(f"{tier}: minimum height cannot contain both fixed corners")
        if any(safe[side] < edges["horizontal" if side in ("top", "bottom") else "vertical"]["height" if side in ("top", "bottom") else "width"] for side in ("top", "right", "bottom", "left")):
            raise ValueError(f"{tier}: content-safe inset enters structural edge zone")
        if edges["horizontal"]["behaviour"] != "stretch_neutral_center":
            raise ValueError(f"{tier}: horizontal edge is not neutral-stretch only")
        if edges["vertical"]["behaviour"] != "stretch_neutral_center":
            raise ValueError(f"{tier}: vertical edge is not neutral-stretch only")


def validate_svg(
    path: Path,
    width: int,
    height: int,
    asset_id: str,
    *,
    stretchable: bool,
) -> None:
    root = ET.parse(path).getroot()
    if root.tag != f"{{{SVG_NS}}}svg":
        raise ValueError(f"{path}: root is not SVG")
    if root.get("width") != str(width) or root.get("height") != str(height):
        raise ValueError(f"{path}: intrinsic size is not {width}x{height}")
    if root.get("viewBox") != f"0 0 {width} {height}":
        raise ValueError(f"{path}: viewBox does not match intrinsic size")
    expected_aspect_ratio = "none" if stretchable else "xMidYMid meet"
    if root.get("preserveAspectRatio") != expected_aspect_ratio:
        raise ValueError(
            f"{path}: preserveAspectRatio must be {expected_aspect_ratio!r}"
        )
    forbidden = {f"{{{SVG_NS}}}image", f"{{{SVG_NS}}}foreignObject"}
    if any(node.tag in forbidden for node in root.iter()):
        raise ValueError(f"{path}: raster or foreign content is forbidden")
    source = path.read_text(encoding="utf-8")
    if "data:image" in source or "@" in source:
        raise ValueError(f"{path}: embedded raster or unresolved token found")
    ids = {node.get("id") for node in root.iter() if node.get("id")}
    if asset_id not in ids:
        raise ValueError(f"{path}: missing stable id {asset_id}")


def render_svg(source: Path, target: Path, width: int, height: int) -> None:
    run(
        command("rsvg-convert"),
        "--width", str(width),
        "--height", str(height),
        "--output", str(target),
        str(source),
    )
    dimensions = run(command("identify"), "-format", "%wx%h", str(target), capture=True)
    if dimensions != f"{width}x{height}":
        raise ValueError(f"{source.name}: rendered {dimensions}, expected {width}x{height}")


def composition_layers(
    temporary: Path,
    manifest: dict,
    tier: str,
    width: int,
    height: int,
    *,
    motif: str | None = None,
    crest: str | None = None,
    workspace_label_width: int | None = None,
) -> list[tuple[Path, int, int]]:
    root = ROOT / manifest["asset_root"]
    spec = manifest["tiers"][tier]
    corner_w = spec["corner"]["width"]
    corner_h = spec["corner"]["height"]
    horizontal = spec["edge"]["horizontal"]
    vertical = spec["edge"]["vertical"]
    middle_w = width - corner_w * 2
    middle_h = height - corner_h * 2
    if middle_w < 0 or middle_h < 0:
        raise ValueError(f"{tier} frame {width}x{height} is below fixed-corner minimum")

    layers: list[tuple[Path, int, int]] = []

    def add(asset: Path, rendered_w: int, rendered_h: int, x: int, y: int, label: str) -> None:
        target = temporary / f"{tier}-{width}x{height}-{label}-{len(layers)}.png"
        render_svg(asset, target, rendered_w, rendered_h)
        layers.append((target, x, y))

    if workspace_label_width is None:
        add(root / tier / "edge-top.svg", middle_w, horizontal["height"], corner_w, 0, "edge-top")
    else:
        bay = spec["workspace_bay"]
        bay_width = workspace_label_width + bay["horizontal_padding"] * 2
        rail_space = width - corner_w * 2 - bay_width
        left_width = rail_space // 2
        right_width = rail_space - left_width
        if left_width > 0:
            add(root / tier / "edge-top.svg", left_width, horizontal["height"], corner_w, 0, "bay-left")
        if right_width > 0:
            add(root / tier / "edge-top.svg", right_width, horizontal["height"], corner_w + left_width + bay_width, 0, "bay-right")
        junction = manifest["motifs"]["junction"]
        if left_width >= bay["endpoint_width"] and right_width >= bay["endpoint_width"]:
            add(root / "motifs" / "junction.svg", junction["width"], junction["height"], corner_w + left_width - junction["width"], 0, "bay-junction-left")
            add(root / "motifs" / "junction.svg", junction["width"], junction["height"], corner_w + left_width + bay_width, 0, "bay-junction-right")

    add(root / tier / "edge-bottom.svg", middle_w, horizontal["height"], corner_w, height - horizontal["height"], "edge-bottom")
    add(root / tier / "edge-left.svg", vertical["width"], middle_h, 0, corner_h, "edge-left")
    add(root / tier / "edge-right.svg", vertical["width"], middle_h, width - vertical["width"], corner_h, "edge-right")
    for name, x, y in (
        ("tl", 0, 0),
        ("tr", width - corner_w, 0),
        ("bl", 0, height - corner_h),
        ("br", width - corner_w, height - corner_h),
    ):
        add(root / tier / f"corner-{name}.svg", corner_w, corner_h, x, y, f"corner-{name}")

    if motif:
        motif_spec = manifest["motifs"][motif]
        anchor = motif_spec["default_anchor"]
        x = (width - motif_spec["width"]) // 2
        y = 0 if anchor == "top_center" else height - motif_spec["height"]
        add(root / "motifs" / f"{motif}.svg", motif_spec["width"], motif_spec["height"], x, y, f"motif-{motif}")
    if crest:
        crest_spec = manifest["crests"][crest]
        x = (width - crest_spec["width"]) // 2
        add(root / "crests" / f"{crest}.svg", crest_spec["width"], crest_spec["height"], x, 0, f"crest-{crest}")
    return layers


def compose_frame(
    temporary: Path,
    manifest: dict,
    tier: str,
    width: int,
    height: int,
    *,
    motif: str | None = None,
    crest: str | None = None,
    workspace_label_width: int | None = None,
) -> Path:
    target = temporary / f"frame-{tier}-{width}x{height}-{motif or crest or 'base'}-{workspace_label_width or 0}.png"
    args = [command("magick"), "-size", f"{width}x{height}", "xc:none"]
    for layer, x, y in composition_layers(
        temporary, manifest, tier, width, height,
        motif=motif, crest=crest, workspace_label_width=workspace_label_width,
    ):
        args.extend((str(layer), "-geometry", f"+{x}+{y}", "-composite"))
    args.append(str(target))
    run(*args)
    return target


def crop(source: Path, target: Path, geometry: str, *, alpha: bool = False) -> None:
    args = [command("magick"), str(source)]
    if alpha:
        args.extend(("-alpha", "extract"))
    args.extend(("-crop", geometry, "+repage", str(target)))
    run(*args)


def assert_pixel_equal(reference: Path, candidate: Path, label: str) -> None:
    result = subprocess.run(
        (command("compare"), "-metric", "AE", str(reference), str(candidate), "null:"),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    pixels = result.stderr.strip()
    try:
        error = float(pixels.split()[0])
    except (IndexError, ValueError):
        error = -1
    if result.returncode not in (0, 1) or error != 0:
        raise ValueError(f"{label}: pixel drift detected ({pixels or 'compare failed'})")


def alpha_at(source: Path, x: int, y: int) -> int:
    value = run(
        command("magick"), str(source), "-alpha", "extract",
        "-crop", f"1x1+{x}+{y}", "+repage",
        "-format", "%[fx:round(255*mean)]", "info:", capture=True,
    )
    return int(value)


def glass_backplate(frame: Path, target: Path, width: int, height: int, radius: int) -> None:
    run(
        command("magick"), "-size", f"{width}x{height}", "xc:none",
        "-fill", "rgba(12,14,19,0.58)",
        "-draw", f"roundrectangle 1,1 {width - 2},{height - 2} {radius},{radius}",
        str(frame), "-geometry", "+0+0", "-composite", str(target),
    )


def make_board(
    tier_renders: dict[str, list[tuple[tuple[int, int], Path]]],
    workspaces: list[tuple[str, Path]],
    destination: Path,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas_w, canvas_h = 1500, 1120
    args = [
        command("magick"), "-size", f"{canvas_w}x{canvas_h}", "xc:#08090b",
        "-fill", "#f4f5f8", "-font", "FreeSans", "-pointsize", "28",
        "-annotate", "+36+48", "SENOMYOS / PRODUCTION FRAME SYSTEM",
        "-fill", "#777c89", "-pointsize", "14",
        "-annotate", "+38+76", "fixed optical corners + neutral extensible edges + fixed anchored motifs",
    ]

    y = 110
    for tier in ("compact", "standard", "large"):
        args.extend(("-fill", "#dde0ea", "-pointsize", "16", "-annotate", f"+36+{y + 16}", tier.upper()))
        x = 170
        max_row_h = 0
        for (width, height), frame in tier_renders[tier]:
            max_w = 520 if tier == "large" else 400
            max_h = 250 if tier == "large" else 150
            thumb = destination.parent / f"harness-{tier}-{width}x{height}.png"
            run(command("magick"), str(frame), "-resize", f"{max_w}x{max_h}>", str(thumb))
            dims = run(command("identify"), "-format", "%w %h", str(thumb), capture=True).split()
            thumb_w, thumb_h = map(int, dims)
            if x + thumb_w > canvas_w - 30:
                x = 170
                y += max_row_h + 48
                max_row_h = 0
            args.extend((str(thumb), "-geometry", f"+{x}+{y}", "-composite"))
            args.extend(("-fill", "#9da2ae", "-pointsize", "11", "-annotate", f"+{x}+{y + thumb_h + 18}", f"{width} x {height}"))
            x += thumb_w + 34
            max_row_h = max(max_row_h, thumb_h + 24)
        y += max_row_h + 56

    args.extend(("-fill", "#dde0ea", "-pointsize", "16", "-annotate", f"+36+{y + 16}", "WORKSPACE BAY / ADAPTIVE APP GRID"))
    x = 170
    for label, workspace in workspaces:
        args.extend((str(workspace), "-geometry", f"+{x}+{y}", "-composite"))
        args.extend(("-fill", "#9da2ae", "-pointsize", "10", "-annotate", f"+{x}+{y + 62}", label))
        x += 150
    args.append(str(destination))
    run(*args)


def add_workspace_content(frame: Path, target: Path, label: str, cells: list[Path | str]) -> None:
    width, height = 120, 44
    glass = target.with_name(f".{target.stem}-glass.png")
    glass_backplate(frame, glass, width, height, 16)
    args = [command("magick"), str(glass), "-fill", "#f4f5f8", "-font", "FreeSans", "-pointsize", "10", "-gravity", "north", "-annotate", "+0+1", label]
    positions = {
        1: [(54, 20)],
        2: [(46, 20), (62, 20)],
        3: [(46, 17), (62, 17), (54, 29)],
        4: [(46, 17), (62, 17), (46, 29), (62, 29)],
    }[len(cells)]
    for cell, (x, y) in zip(cells, positions):
        if isinstance(cell, Path):
            icon = target.with_name(f".{target.stem}-{x}-{y}.png")
            run(command("magick"), str(cell), "-resize", "12x12", str(icon))
            args.extend((str(icon), "-geometry", f"+{x}+{y}", "-composite"))
        else:
            args.extend(("-fill", "rgba(244,245,248,0.08)", "-stroke", "#777c89", "-strokewidth", "1", "-draw", f"roundrectangle {x},{y} {x + 12},{y + 12} 3,3", "-stroke", "none", "-fill", "#dde0ea", "-pointsize", "7", "-gravity", "northwest", "-annotate", f"+{x + 1}+{y + 2}", cell))
    args.append(str(target))
    run(*args)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path)
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    validate_manifest(manifest)
    root = ROOT / manifest["asset_root"]

    for tier, spec in manifest["tiers"].items():
        cw, ch = spec["corner"]["width"], spec["corner"]["height"]
        hw, hh = spec["edge"]["horizontal"]["width"], spec["edge"]["horizontal"]["height"]
        vw, vh = spec["edge"]["vertical"]["width"], spec["edge"]["vertical"]["height"]
        for corner in ("tl", "tr", "bl", "br"):
            validate_svg(
                root / tier / f"corner-{corner}.svg",
                cw,
                ch,
                f"frame-{tier}-corner-{corner}",
                stretchable=False,
            )
        for edge in ("top", "bottom"):
            validate_svg(
                root / tier / f"edge-{edge}.svg",
                hw,
                hh,
                f"frame-{tier}-edge-{edge}",
                stretchable=True,
            )
        for edge in ("left", "right"):
            validate_svg(
                root / tier / f"edge-{edge}.svg",
                vw,
                vh,
                f"frame-{tier}-edge-{edge}",
                stretchable=True,
            )
    for name, spec in manifest["motifs"].items():
        validate_svg(
            root / "motifs" / f"{name}.svg",
            spec["width"],
            spec["height"],
            f"frame-motif-{name}",
            stretchable=False,
        )
    for name, spec in manifest["crests"].items():
        validate_svg(
            root / "crests" / f"{name}.svg",
            spec["width"],
            spec["height"],
            f"frame-crest-{name}",
            stretchable=False,
        )

    with tempfile.TemporaryDirectory(prefix="senomy-frame-system-") as temporary_name:
        temporary = Path(temporary_name)
        tier_renders: dict[str, list[tuple[tuple[int, int], Path]]] = {"compact": [], "standard": [], "large": []}
        size_keys = {"compact": "rail_validation_sizes", "standard": "standard_validation_sizes", "large": "large_validation_sizes"}
        motifs = {"compact": "telemetry", "standard": "diagnostic-tick", "large": None}
        crests = {"compact": None, "standard": None, "large": "wide"}

        for tier in ("compact", "standard", "large"):
            spec = manifest["tiers"][tier]
            corner_w, corner_h = spec["corner"]["width"], spec["corner"]["height"]
            edge_h = spec["edge"]["horizontal"]["height"]
            corner_reference: Path | None = None
            edge_reference: Path | None = None
            motif_reference: Path | None = None
            for width, height in manifest[size_keys[tier]]:
                # Fixed crests are optional and disappear when the safe edge
                # interval is too short; they are never squashed into it.
                crest_name = crests[tier] if width >= 480 else None
                frame = compose_frame(temporary, manifest, tier, width, height, motif=motifs[tier], crest=crest_name)
                if alpha_at(frame, width // 2, height // 2) != 0:
                    raise ValueError(f"{tier} {width}x{height}: content centre is not transparent")
                corner = temporary / f"{tier}-{width}x{height}-corner-alpha.png"
                edge = temporary / f"{tier}-{width}x{height}-edge-alpha.png"
                crop(frame, corner, f"{corner_w}x{corner_h}+0+0", alpha=True)
                crop(frame, edge, f"8x{edge_h}+{corner_w + 2}+0", alpha=True)
                if corner_reference is None:
                    corner_reference, edge_reference = corner, edge
                else:
                    assert_pixel_equal(corner_reference, corner, f"{tier} fixed corner at {width}x{height}")
                    assert_pixel_equal(edge_reference, edge, f"{tier} stable edge stroke at {width}x{height}")
                if motifs[tier]:
                    motif_spec = manifest["motifs"][motifs[tier]]
                    mx = (width - motif_spec["width"]) // 2
                    my = height - motif_spec["height"]
                    motif_crop = temporary / f"{tier}-{width}x{height}-motif-alpha.png"
                    crop(frame, motif_crop, f"{motif_spec['width']}x{motif_spec['height']}+{mx}+{my}", alpha=True)
                    if motif_reference is None:
                        motif_reference = motif_crop
                    else:
                        assert_pixel_equal(motif_reference, motif_crop, f"{tier} fixed motif at {width}x{height}")
                presentation = temporary / f"{tier}-{width}x{height}-glass.png"
                glass_backplate(frame, presentation, width, height, max(8, corner_w - 2))
                tier_renders[tier].append(((width, height), presentation))

        workspace_frames: list[tuple[str, Path]] = []
        icons = [
            Path("/usr/share/icons/Papirus/16x16/apps/vscode.svg"),
            Path("/usr/share/icons/Papirus/16x16/apps/firefox.svg"),
            Path("/usr/share/icons/hicolor/scalable/apps/kitty.svg"),
            Path("/usr/share/icons/hicolor/scalable/apps/org.xfce.thunar.svg"),
        ]
        if not all(path.is_file() for path in icons):
            icons = [root / "motifs" / "junction.svg"] * 4
        workspace_sets: list[tuple[str, list[Path | str]]] = [
            ("1 APP", icons[:1]),
            ("2 APPS", icons[:2]),
            ("3 APPS", icons[:3]),
            ("4 APPS", icons[:4]),
            ("+N", [icons[0], icons[1], icons[2], "+3"]),
        ]
        bay_reference: Path | None = None
        for index, (label, cells) in enumerate(workspace_sets, 1):
            frame = compose_frame(temporary, manifest, "compact", 120, 44, motif="workspace", workspace_label_width=14 if index < 5 else 22)
            if alpha_at(frame, 60, 1) != 0:
                raise ValueError("workspace top-centre label bay is not structurally open")
            bay_crop = temporary / f"workspace-bay-{index}.png"
            crop(frame, bay_crop, "14x6+53+0", alpha=True)
            if index < 5:
                if bay_reference is None:
                    bay_reference = bay_crop
                else:
                    assert_pixel_equal(bay_reference, bay_crop, "workspace label bay centring")
            output = temporary / f"workspace-{index}.png"
            add_workspace_content(frame, output, str(index), cells)
            workspace_frames.append((label, output))

        if args.artifacts_dir:
            destination = args.artifacts_dir.resolve()
            destination.mkdir(parents=True, exist_ok=True)
            retained: dict[str, list[tuple[tuple[int, int], Path]]] = {"compact": [], "standard": [], "large": []}
            for tier, items in tier_renders.items():
                for size, source in items:
                    target = destination / f"{tier}-{size[0]}x{size[1]}.png"
                    shutil.copy2(source, target)
                    retained[tier].append((size, target))
            retained_workspaces: list[tuple[str, Path]] = []
            for label, source in workspace_frames:
                target = destination / f"workspace-{label.lower().replace(' ', '-').replace('+', 'plus')}.png"
                shutil.copy2(source, target)
                retained_workspaces.append((label, target))
            make_board(retained, retained_workspaces, destination / "frame-system-harness.png")

    print("PASS  SenomyOS frame system: 35 production SVG modules, three optical tiers, fixed corners/motifs/crests, neutral extensible edges, safe centres, and adaptive workspace bays")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
