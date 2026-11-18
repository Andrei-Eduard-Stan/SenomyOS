#!/usr/bin/env python3
"""Read-only reference integrity/freshness checks. No network or desktop access."""
import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[4]
LIBRARY = ROOT / "docs/design/design-intelligence"
STATUSES = {
    "approved-direction", "approved-decision", "authored-reference",
    "implemented-review-pending", "observed", "rejected", "external", "documentary",
}


def local_path(value):
    """Reject machine-specific and escaping paths, including escaping symlinks."""
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError(f"Expected repository-relative path: {value!r}")
    result = (ROOT / value).resolve()
    if not result.is_relative_to(ROOT):
        raise ValueError(f"Path escapes repository: {value}")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise ValueError(f"Unsupported JSON schema: {path.relative_to(ROOT)}")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--find", help="Find references by ID, title, scope or tag; no writes")
    args = parser.parse_args()
    errors, drift = [], []
    try:
        catalogue = read_json(LIBRARY / "catalogue.json")
        provenance = read_json(LIBRARY / "provenance.json")
        review = read_json(LIBRARY / "third-party-review.json")
        entries = catalogue["entries"]
        if not isinstance(entries, list) or not entries:
            raise ValueError("Catalogue must contain a nonempty entries list")
        ids = set()
        for entry in entries:
            for key in ("id", "title", "status", "tags", "scope", "authority", "analysis", "evidence", "sources", "visual_inspection", "transfer", "exclude"):
                if key not in entry:
                    raise ValueError(f"{entry.get('id', '?')}: missing {key}")
            identity = entry["id"]
            if not isinstance(identity, str) or not re.fullmatch(r"[A-Z][0-9]{2}", identity) or identity in ids:
                raise ValueError(f"Invalid or duplicate case ID: {identity}")
            ids.add(identity)
            if entry["status"] not in STATUSES:
                raise ValueError(f"{identity}: unknown status")
            for key in ("tags", "evidence", "sources", "transfer", "exclude"):
                if not isinstance(entry[key], list) or not all(isinstance(v, str) and v for v in entry[key]):
                    raise ValueError(f"{identity}: {key} must be a list of nonempty strings")
            authority = entry["authority"]
            if not isinstance(authority, dict) or not authority.get("kind") or not authority.get("decision"):
                raise ValueError(f"{identity}: missing decision authority/scope")
            if entry["status"].startswith("approved-") and authority["kind"] not in ("project-record", "user-record"):
                raise ValueError(f"{identity}: approval requires project/user evidence")
            if not isinstance(entry["visual_inspection"], dict) or not entry["visual_inspection"].get("limits"):
                raise ValueError(f"{identity}: inspection limits must be explicit")
            if entry["status"] == "external" and not entry["visual_inspection"].get("images_viewed"):
                raise ValueError(f"{identity}: unviewed external belongs in documentary status")
            document, separator, anchor = entry["analysis"].partition("#")
            analysis = local_path(document)
            if not analysis.is_file() or not separator or f'<a id="{anchor}"></a>' not in analysis.read_text():
                errors.append(f"{identity}: missing analysis/anchor {entry['analysis']}")
            for relative in entry["evidence"] + entry["sources"]:
                if not local_path(relative).is_file():
                    errors.append(f"{identity}: missing {relative}")
        if args.find is not None:
            query = args.find.casefold()
            matches = [e for e in entries if query in " ".join([e["id"], e["title"], e["scope"], *e["tags"]]).casefold()]
            for entry in matches:
                print(f"{entry['id']} [{entry['status']}] {entry['title']}\n  {entry['analysis']}")
            print(f"{len(matches)} matching references")
            if errors:
                raise ValueError("; ".join(errors))
            return 0

        archive_paths = set()
        for item in provenance["evidence"]:
            path = local_path(item["archive_path"])
            archive_paths.add(item["archive_path"])
            if not path.is_file():
                errors.append(f"Missing archived evidence: {item['archive_path']}")
                continue
            if digest(path) != item["sha256"]:
                errors.append(f"Altered archived evidence: {item['archive_path']}")
            with path.open("rb") as stream:
                header = stream.read(24)
            if header[:8] != b"\x89PNG\r\n\x1a\n" or list(struct.unpack(">II", header[16:24])) != item["dimensions"]:
                errors.append(f"PNG dimensions/format changed: {item['archive_path']}")
            if not item.get("origin_path") or not item.get("origin_sha256") or not item.get("transform"):
                errors.append(f"Evidence lacks origin/transform: {item['archive_path']}")
        for entry in entries:
            for value in entry["evidence"]:
                if value.startswith("docs/design/design-intelligence/evidence/") and value not in archive_paths:
                    errors.append(f"Unrecorded evidence origin: {value}")
        for item in provenance["sources"]:
            path = local_path(item["path"])
            if not path.is_file() or digest(path) != item["sha256"]:
                drift.append(item["path"])
        for reference in provenance["external_inspections"]:
            if not reference.get("url", "").startswith("https://") or not reference.get("result"):
                errors.append("External inspection lacks primary URL/result")
        for package in review["packages"]:
            if not package.get("version") or not package.get("files"):
                errors.append("Third-party review lacks version/files")
            for item in package.get("files", []):
                if not re.fullmatch(r"[0-9a-f]{64}", item.get("sha256", "")):
                    errors.append("Invalid third-party source fingerprint")

        # Check maintained local Markdown links and explicit case anchors, offline.
        documents = [*LIBRARY.glob("*.md"), ROOT / "docs/DESIGN_INTELLIGENCE_GUIDE.md",
                     ROOT / ".agents/skills/senomy-design-director/SKILL.md",
                     ROOT / ".agents/skills/senomy-design-director/references/visual-gate.md"]
        for document in documents:
            for target in re.findall(r"\]\(([^\s)]+)\)", document.read_text()):
                if urlsplit(target).scheme:
                    continue
                name, _, fragment = unquote(target).partition("#")
                path = (document.parent / name).resolve() if name else document
                if not path.is_relative_to(ROOT) or not path.exists():
                    errors.append(f"Broken local link in {document.relative_to(ROOT)}: {target}")
                elif fragment and path.name == "CASES.md" and f'<a id="{fragment}"></a>' not in path.read_text():
                    errors.append(f"Broken case anchor: {target}")
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        for relative in drift:
            print("REVIEW SOURCE DRIFT: " + relative)
        if errors:
            return 1
        if drift:
            print("Source drift requires inspection; fingerprints were not changed.")
            return 2
        print(f"PASS: {len(entries)} references, {len(archive_paths)} archived images, "
              f"{len(provenance['sources'])} source fingerprints and local links")
        print("Integrity only; this does not certify aesthetics, approval or runtime behavior.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError, struct.error) as error:
        print(f"ERROR: invalid library: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
