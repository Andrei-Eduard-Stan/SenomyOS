#!/usr/bin/env python3

"""Build a deterministic Thunar uca.xml while preserving user-owned actions."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import xml.etree.ElementTree as ET


VALID_CONDITIONS = {
    "directories",
    "audio-files",
    "image-files",
    "other-files",
    "text-files",
    "video-files",
}
VALID_VERBS = {"copy-path", "copy-sha256"}
COMMAND_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
UNIQUE_ID_RE = re.compile(r"^[0-9]{16}-[0-9]+$")
RANGE_RE = re.compile(r"^[1-9][0-9]*-[1-9][0-9]*$")


def fail(message: str) -> "NoReturn":
    raise ValueError(message)


def load_registry(path: Path) -> list[dict[str, object]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail(f"invalid action registry: {exc}")

    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        fail("action registry must use schema version 1")
    actions = payload.get("actions")
    if not isinstance(actions, list) or not 1 <= len(actions) <= 16:
        fail("action registry must contain between one and sixteen actions")

    seen_ids: set[str] = set()
    seen_unique_ids: set[str] = set()
    for index, action in enumerate(actions):
        if not isinstance(action, dict):
            fail(f"action {index} is not an object")
        action_id = action.get("id")
        unique_id = action.get("unique_id")
        verb = action.get("verb")
        if not isinstance(action_id, str) or not ID_RE.fullmatch(action_id):
            fail(f"action {index} has an invalid id")
        if action_id in seen_ids:
            fail(f"duplicate action id: {action_id}")
        seen_ids.add(action_id)
        if not isinstance(unique_id, str) or not UNIQUE_ID_RE.fullmatch(unique_id):
            fail(f"action {action_id} has an invalid unique_id")
        if unique_id in seen_unique_ids:
            fail(f"duplicate action unique_id: {unique_id}")
        seen_unique_ids.add(unique_id)
        if verb not in VALID_VERBS:
            fail(f"action {action_id} has an unsupported verb")
        for field in ("name", "description", "icon", "placeholder", "patterns"):
            value = action.get(field)
            if not isinstance(value, str) or not value or any(ord(char) < 32 for char in value):
                fail(f"action {action_id} has an invalid {field}")
        if action["placeholder"] not in {"%f", "%F"}:
            fail(f"action {action_id} has an unsupported placeholder")
        selection_range = action.get("range")
        if not isinstance(selection_range, str) or not RANGE_RE.fullmatch(selection_range):
            fail(f"action {action_id} has an invalid range")
        requirements = action.get("requirements")
        if not isinstance(requirements, list) or not requirements:
            fail(f"action {action_id} must declare requirements")
        if not all(isinstance(item, str) and COMMAND_RE.fullmatch(item) for item in requirements):
            fail(f"action {action_id} has an invalid requirement")
        conditions = action.get("conditions")
        if not isinstance(conditions, list) or not conditions:
            fail(f"action {action_id} must declare conditions")
        if len(conditions) != len(set(conditions)) or not set(conditions) <= VALID_CONDITIONS:
            fail(f"action {action_id} has invalid or duplicate conditions")
    return actions


def load_base(path: Path) -> tuple[ET.Element, bool]:
    if not path.exists():
        return ET.Element("actions"), False
    if path.is_symlink() or not path.is_file():
        fail("base uca.xml must be a regular non-symlink file")
    try:
        parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
        root = ET.parse(path, parser=parser).getroot()
    except (OSError, ET.ParseError) as exc:
        fail(f"invalid base uca.xml: {exc}")
    if root.tag != "actions":
        fail("base uca.xml root must be <actions>")
    return root, True


def clean_whitespace(element: ET.Element) -> None:
    if element.text is not None and not element.text.strip():
        element.text = None
    if element.tail is not None and not element.tail.strip():
        element.tail = None
    for child in list(element):
        clean_whitespace(child)


def child_text(parent: ET.Element, name: str, value: str) -> None:
    child = ET.SubElement(parent, name)
    child.text = value


def build_action(action: dict[str, object], helper_target: Path) -> ET.Element:
    node = ET.Element("action")
    child_text(node, "icon", str(action["icon"]))
    child_text(node, "name", str(action["name"]))
    child_text(node, "submenu", "SenomyOS")
    child_text(node, "unique-id", str(action["unique_id"]))
    command = f"{shlex.quote(str(helper_target))} {action['verb']} {action['placeholder']}"
    child_text(node, "command", command)
    child_text(node, "description", str(action["description"]))
    child_text(node, "range", str(action["range"]))
    child_text(node, "patterns", str(action["patterns"]))
    ET.SubElement(node, "startup-notify")
    for condition in action["conditions"]:
        ET.SubElement(node, str(condition))
    return node


def write_output(root: ET.Element, output: Path) -> None:
    clean_whitespace(root)
    ET.indent(root, space="  ")
    tree = ET.ElementTree(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp-{os.getpid()}")
    try:
        tree.write(temporary, encoding="utf-8", xml_declaration=True, short_empty_elements=True)
        os.chmod(temporary, 0o600)
        os.replace(temporary, output)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--helper-target", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    if not args.helper_target.is_absolute() or any(ord(char) < 32 for char in str(args.helper_target)):
        fail("helper target must be an absolute path without control characters")

    actions = load_registry(args.registry)
    root, base_exists = load_base(args.base)
    managed_ids = {str(action["unique_id"]) for action in actions}
    seen_base_ids: set[str] = set()
    preserved = 0
    replaced: list[str] = []

    for child in list(root):
        if child.tag != "action":
            continue
        unique = child.findtext("unique-id")
        if not unique:
            fail("base uca.xml contains an action without unique-id")
        if unique in seen_base_ids:
            fail(f"base uca.xml contains duplicate unique-id: {unique}")
        seen_base_ids.add(unique)
        if unique in managed_ids:
            root.remove(child)
            replaced.append(unique)
        else:
            preserved += 1

    enabled: list[str] = []
    unavailable: list[dict[str, object]] = []
    for action in actions:
        missing = [str(command) for command in action["requirements"] if shutil.which(str(command)) is None]
        if missing:
            unavailable.append({"id": action["id"], "missing": missing})
            continue
        root.append(build_action(action, args.helper_target))
        enabled.append(str(action["id"]))

    write_output(root, args.output)
    report = {
        "schema_version": 1,
        "base_exists": base_exists,
        "preserved_user_actions": preserved,
        "replaced_managed_unique_ids": sorted(replaced),
        "enabled_actions": enabled,
        "unavailable_actions": unavailable,
        "result_actions": preserved + len(enabled),
    }
    encoded = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    if args.report:
        args.report.write_text(encoded, encoding="utf-8")
        os.chmod(args.report, 0o600)
    else:
        sys.stdout.write(encoded)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"thunar-uca-merge: {exc}", file=sys.stderr)
        raise SystemExit(1)
