#!/usr/bin/env python3
"""Render a private plain-text Markdown report as a dependency-free PDF."""

from pathlib import Path
import sys
import textwrap


def pdf_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def main() -> int:
    if len(sys.argv) != 3:
        return 2
    source, target = map(Path, sys.argv[1:])
    lines = []
    for raw in source.read_text(encoding="utf-8", errors="replace").splitlines():
        cleaned = raw.replace("#", "").replace("`", "").strip()
        lines.extend(textwrap.wrap(cleaned, width=92) or [""])
    pages = [lines[index:index + 52] for index in range(0, len(lines), 52)] or [["Empty report"]]

    objects = [b""]
    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    page_ids = [4 + index * 2 for index in range(len(pages))]
    objects.append(f"<< /Type /Pages /Kids [{' '.join(f'{pid} 0 R' for pid in page_ids)}] /Count {len(pages)} >>".encode())
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>")
    for page_index, page in enumerate(pages):
        page_id = 4 + page_index * 2
        stream_id = page_id + 1
        commands = ["BT", "/F1 9 Tf", "42 800 Td", "12 TL"]
        for line in page:
            commands.append(f"({pdf_escape(line)}) Tj T*")
        commands.append("ET")
        stream = "\n".join(commands).encode("latin-1", errors="replace")
        objects.append(f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents {stream_id} 0 R >>".encode())
        objects.append(f"<< /Length {len(stream)} >>\nstream\n".encode() + stream + b"\nendstream")

    output = bytearray(b"%PDF-1.4\n%SenomyOS\n")
    offsets = [0]
    for number, obj in enumerate(objects[1:], 1):
        offsets.append(len(output))
        output.extend(f"{number} 0 obj\n".encode() + obj + b"\nendobj\n")
    xref = len(output)
    output.extend(f"xref\n0 {len(objects)}\n0000000000 65535 f \n".encode())
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode())
    output.extend(f"trailer << /Size {len(objects)} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
    target.write_bytes(output)
    target.chmod(0o600)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
