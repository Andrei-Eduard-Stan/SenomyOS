#!/usr/bin/env python3

"""Parse the local SenomyOS Markdown wiki into bounded Eww-friendly JSON."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlparse

SCHEMA_VERSION = 1
MAX_FILES = 128
MAX_FILE_BYTES = 256 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024
MAX_LINES = 2500
MAX_BLOCKS = 320
MAX_TABLE_COLUMNS = 8
MAX_TABLE_ROWS = 64
MAX_TEXT = 12000

FRONT_MATTER_KEYS = {
    "title",
    "category",
    "category_order",
    "order",
    "summary",
}
HEADING_RE = re.compile(r"^(#{1,3})\s+(.+?)\s*#*\s*$")
UNORDERED_RE = re.compile(r"^\s*[-+*]\s+(.+)$")
ORDERED_RE = re.compile(r"^\s*(\d+)\.\s+(.+)$")
HORIZONTAL_RULE_RE = re.compile(r"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$")
TABLE_SEPARATOR_RE = re.compile(
    r"^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$"
)
INLINE_TOKEN_RE = re.compile(
    r"!\[([^\]]*)\]\(([^)]+)\)"
    r"|\[([^\]]+)\]\(([^)]+)\)"
    r"|\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"
)
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
SLUG_RE = re.compile(r"[^a-z0-9_-]+")


class WikiError(Exception):
    """A bounded, user-displayable wiki parsing error."""


def compact_json(value: object) -> None:
    json.dump(value, sys.stdout, ensure_ascii=True, separators=(",", ":"))
    sys.stdout.write("\n")


def clean_text(value: str, limit: int = MAX_TEXT) -> str:
    value = CONTROL_RE.sub(" ", value).strip()
    return value[:limit]


def slugify(value: str) -> str:
    slug = value.strip().lower().replace(" ", "-")
    slug = SLUG_RE.sub("-", slug)
    slug = re.sub(r"-{2,}", "-", slug).strip("-_")
    return slug or "untitled"


def article_id_for_path(relative_path: Path) -> str:
    without_suffix = relative_path.with_suffix("")
    return "/".join(slugify(part) for part in without_suffix.parts)


def parse_int(value: str, fallback: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return fallback
    return max(minimum, min(maximum, parsed))


def strip_scalar_quotes(value: str) -> str:
    value = value.strip()
    if (
        len(value) >= 2
        and value[0] == value[-1]
        and value[0] in {"'", '"'}
    ):
        return value[1:-1]
    return value


def parse_front_matter(
    lines: list[str], display_path: str
) -> tuple[dict[str, str], list[str], list[dict[str, str]]]:
    if not lines or lines[0].strip() != "---":
        return {}, lines, []

    metadata: dict[str, str] = {}
    warnings: list[dict[str, str]] = []
    closing_index = None

    for index in range(1, min(len(lines), 80)):
        line = lines[index].strip()
        if line == "---":
            closing_index = index
            break
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            warnings.append(
                {
                    "code": "front_matter_line_ignored",
                    "path": display_path,
                    "message": clean_text(line, 160),
                }
            )
            continue
        key, value = line.split(":", 1)
        key = key.strip().lower()
        if key not in FRONT_MATTER_KEYS:
            warnings.append(
                {
                    "code": "front_matter_key_ignored",
                    "path": display_path,
                    "message": f"Unsupported key: {clean_text(key, 64)}",
                }
            )
            continue
        metadata[key] = clean_text(strip_scalar_quotes(value), 300)

    if closing_index is None:
        raise WikiError("Front matter starts with --- but has no closing ---")

    return metadata, lines[closing_index + 1 :], warnings


def target_article_id(current_id: str, raw_target: str) -> tuple[str, bool]:
    target = clean_text(raw_target, 500)
    parsed = urlparse(target)
    if parsed.scheme or target.startswith("//"):
        return target, True

    path = unquote(parsed.path)
    if not path:
        return current_id, False
    if path.endswith(".md"):
        path = path[:-3]

    if path.startswith("/"):
        parts: list[str] = []
    else:
        parts = list(PurePosixPath(current_id).parent.parts)

    for part in PurePosixPath(path).parts:
        if part in {"", ".", "/"}:
            continue
        if part == "..":
            if not parts:
                return "", False
            parts.pop()
            continue
        parts.append(slugify(part))

    return "/".join(parts), False


def clean_inline_markup(value: str) -> str:
    value = value.replace("**", "").replace("__", "").replace("~~", "")
    value = value.replace("`", "")
    value = re.sub(r"(?<!\\)[*_]", "", value)
    return clean_text(value)


def parse_inline(value: str, current_id: str) -> tuple[str, list[dict[str, object]]]:
    rendered: list[str] = []
    links: list[dict[str, object]] = []
    cursor = 0

    for match in INLINE_TOKEN_RE.finditer(value):
        rendered.append(value[cursor : match.start()])
        image_alt, _image_path, link_label, link_target, wiki_target, wiki_label = (
            match.groups()
        )

        if image_alt is not None:
            rendered.append(image_alt or "image")
        else:
            label = link_label or wiki_label or wiki_target or "article"
            raw_target = link_target or wiki_target or ""
            article_id, external = target_article_id(current_id, raw_target)
            rendered.append(label)
            links.append(
                {
                    "label": clean_text(label, 120),
                    "article_id": article_id,
                    "external": external,
                }
            )

        cursor = match.end()

    rendered.append(value[cursor:])
    return clean_inline_markup("".join(rendered)), links


def split_table_row(line: str) -> list[str]:
    value = line.strip()
    if value.startswith("|"):
        value = value[1:]
    if value.endswith("|"):
        value = value[:-1]
    return [cell.strip() for cell in value.split("|")][:MAX_TABLE_COLUMNS]


def deduplicate_links(links: list[dict[str, object]]) -> list[dict[str, object]]:
    seen: set[tuple[str, str, bool]] = set()
    result: list[dict[str, object]] = []
    for link in links:
        key = (
            str(link.get("label", "")),
            str(link.get("article_id", "")),
            bool(link.get("external", False)),
        )
        if key in seen:
            continue
        seen.add(key)
        result.append(link)
    return result


def parse_blocks(
    lines: list[str], article_id: str, display_path: str
) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    blocks: list[dict[str, object]] = []
    warnings: list[dict[str, str]] = []
    paragraph: list[str] = []
    index = 0

    def append_block(block: dict[str, object]) -> None:
        if len(blocks) < MAX_BLOCKS:
            blocks.append(block)

    def flush_paragraph() -> None:
        if not paragraph:
            return
        text, links = parse_inline(" ".join(part.strip() for part in paragraph), article_id)
        if text:
            append_block(
                {
                    "type": "paragraph",
                    "text": text,
                    "links": deduplicate_links(links),
                }
            )
        paragraph.clear()

    while index < len(lines):
        line = lines[index].rstrip()

        if not line.strip():
            flush_paragraph()
            index += 1
            continue

        if line.lstrip().startswith("```"):
            flush_paragraph()
            language = clean_text(line.lstrip()[3:].strip(), 40)
            code_lines: list[str] = []
            index += 1
            closed = False
            while index < len(lines):
                if lines[index].lstrip().startswith("```"):
                    closed = True
                    index += 1
                    break
                code_lines.append(CONTROL_RE.sub(" ", lines[index].rstrip()))
                index += 1
            if not closed:
                warnings.append(
                    {
                        "code": "unclosed_code_fence",
                        "path": display_path,
                        "message": "Code block continued to the end of the article.",
                    }
                )
            append_block(
                {
                    "type": "code",
                    "language": language or "text",
                    "text": "\n".join(code_lines)[:MAX_TEXT],
                    "links": [],
                }
            )
            continue

        heading = HEADING_RE.match(line)
        if heading:
            flush_paragraph()
            text, links = parse_inline(heading.group(2), article_id)
            append_block(
                {
                    "type": "heading",
                    "level": len(heading.group(1)),
                    "text": text,
                    "links": deduplicate_links(links),
                }
            )
            index += 1
            continue

        if HORIZONTAL_RULE_RE.match(line):
            flush_paragraph()
            append_block({"type": "divider", "text": "", "links": []})
            index += 1
            continue

        if (
            "|" in line
            and index + 1 < len(lines)
            and TABLE_SEPARATOR_RE.match(lines[index + 1])
        ):
            flush_paragraph()
            header_values = split_table_row(line)
            headers: list[dict[str, str]] = []
            table_links: list[dict[str, object]] = []
            for value in header_values:
                text, links = parse_inline(value, article_id)
                headers.append({"text": text})
                table_links.extend(links)

            rows: list[dict[str, list[dict[str, str]]]] = []
            index += 2
            while (
                index < len(lines)
                and "|" in lines[index]
                and lines[index].strip()
                and len(rows) < MAX_TABLE_ROWS
            ):
                cells: list[dict[str, str]] = []
                for value in split_table_row(lines[index]):
                    text, links = parse_inline(value, article_id)
                    cells.append({"text": text})
                    table_links.extend(links)
                while len(cells) < len(headers):
                    cells.append({"text": ""})
                rows.append({"cells": cells[: len(headers)]})
                index += 1

            append_block(
                {
                    "type": "table",
                    "headers": headers,
                    "rows": rows,
                    "text": "",
                    "links": deduplicate_links(table_links),
                }
            )
            continue

        if line.lstrip().startswith(">"):
            flush_paragraph()
            quote_lines: list[str] = []
            while index < len(lines) and lines[index].lstrip().startswith(">"):
                quote_lines.append(lines[index].lstrip()[1:].lstrip())
                index += 1
            text, links = parse_inline(" ".join(quote_lines), article_id)
            append_block(
                {
                    "type": "quote",
                    "text": text,
                    "links": deduplicate_links(links),
                }
            )
            continue

        unordered = UNORDERED_RE.match(line)
        ordered = ORDERED_RE.match(line)
        if unordered or ordered:
            flush_paragraph()
            ordered_list = ordered is not None
            items: list[dict[str, object]] = []
            list_links: list[dict[str, object]] = []
            while index < len(lines):
                current = (
                    ORDERED_RE.match(lines[index])
                    if ordered_list
                    else UNORDERED_RE.match(lines[index])
                )
                if current is None:
                    break
                raw_text = current.group(2) if ordered_list else current.group(1)
                text, links = parse_inline(raw_text, article_id)
                items.append({"text": text, "index": len(items) + 1})
                list_links.extend(links)
                index += 1
            append_block(
                {
                    "type": "list",
                    "ordered": ordered_list,
                    "items": items,
                    "text": "",
                    "links": deduplicate_links(list_links),
                }
            )
            continue

        paragraph.append(line)
        index += 1

    flush_paragraph()

    if len(blocks) >= MAX_BLOCKS:
        warnings.append(
            {
                "code": "article_truncated",
                "path": display_path,
                "message": f"Only the first {MAX_BLOCKS} rendered blocks are shown.",
            }
        )

    return blocks, warnings


def first_heading(blocks: list[dict[str, object]]) -> str:
    for block in blocks:
        if block.get("type") == "heading" and block.get("level") == 1:
            return str(block.get("text", ""))
    return ""


def first_paragraph(blocks: list[dict[str, object]]) -> str:
    for block in blocks:
        if block.get("type") == "paragraph":
            return clean_text(str(block.get("text", "")), 220)
    return ""


def enrich_links(
    articles: list[dict[str, object]], warnings: list[dict[str, str]]
) -> None:
    article_map = {str(article["id"]): article for article in articles}

    for article in articles:
        for block in article["blocks"]:
            for link in block.get("links", []):
                if link["external"]:
                    link.update(
                        {
                            "available": False,
                            "category_id": "",
                            "target_title": "External link",
                        }
                    )
                    continue

                target = article_map.get(str(link["article_id"]))
                if target is None:
                    link.update(
                        {
                            "available": False,
                            "category_id": "",
                            "target_title": "Article unavailable",
                        }
                    )
                    warnings.append(
                        {
                            "code": "missing_internal_link",
                            "path": str(article["source_path"]),
                            "message": f"Missing article: {link['article_id']}",
                        }
                    )
                    continue

                link.update(
                    {
                        "available": True,
                        "category_id": target["category_id"],
                        "target_title": target["title"],
                    }
                )


def load_wiki(root: Path) -> dict[str, object]:
    observed_at = int(time.time())
    warnings: list[dict[str, str]] = []
    errors: list[dict[str, str]] = []
    articles: list[dict[str, object]] = []
    seen_ids: set[str] = set()
    total_bytes = 0

    if not root.is_dir():
        return {
            "schema_version": SCHEMA_VERSION,
            "ok": False,
            "source": "markdown-wiki",
            "observed_at": observed_at,
            "data": {
                "root": str(root),
                "default_category_id": "",
                "default_article_id": "",
                "category_count": 0,
                "article_count": 0,
                "categories": [],
                "articles": [],
                "warnings": [],
            },
            "error": {
                "code": "wiki_root_unavailable",
                "message": "The configured wiki directory is unavailable.",
            },
        }

    paths = sorted(
        path
        for path in root.rglob("*.md")
        if path.is_file()
        and not path.is_symlink()
        and not any(part.startswith("_") for part in path.relative_to(root).parts)
    )

    if len(paths) > MAX_FILES:
        warnings.append(
            {
                "code": "file_limit",
                "path": "wiki",
                "message": f"Only the first {MAX_FILES} Markdown files are loaded.",
            }
        )
        paths = paths[:MAX_FILES]

    for path in paths:
        relative = path.relative_to(root)
        display_path = f"wiki/{relative.as_posix()}"
        try:
            size = path.stat().st_size
            if size > MAX_FILE_BYTES:
                raise WikiError(
                    f"Article exceeds the {MAX_FILE_BYTES // 1024} KiB limit"
                )
            total_bytes += size
            if total_bytes > MAX_TOTAL_BYTES:
                raise WikiError("The wiki exceeds its total read limit")

            raw = path.read_text(encoding="utf-8")
            lines = raw.splitlines()
            if len(lines) > MAX_LINES:
                lines = lines[:MAX_LINES]
                warnings.append(
                    {
                        "code": "line_limit",
                        "path": display_path,
                        "message": f"Only the first {MAX_LINES} lines are loaded.",
                    }
                )

            metadata, body, front_warnings = parse_front_matter(lines, display_path)
            warnings.extend(front_warnings)
            article_id = article_id_for_path(relative)
            if article_id in seen_ids:
                raise WikiError(f"Article ID collides after normalization: {article_id}")
            seen_ids.add(article_id)

            blocks, block_warnings = parse_blocks(body, article_id, display_path)
            warnings.extend(block_warnings)
            title = metadata.get("title") or first_heading(blocks) or path.stem
            category_title = metadata.get("category") or "Unsorted"
            category_id = slugify(category_title)
            modified_at = int(path.stat().st_mtime)

            articles.append(
                {
                    "id": article_id,
                    "title": clean_text(title, 120),
                    "category_id": category_id,
                    "category_title": clean_text(category_title, 80),
                    "category_order": parse_int(
                        metadata.get("category_order", "100"), 100, 0, 9999
                    ),
                    "order": parse_int(metadata.get("order", "100"), 100, 0, 9999),
                    "summary": clean_text(
                        metadata.get("summary") or first_paragraph(blocks), 220
                    ),
                    "source_path": display_path,
                    "modified_at": modified_at,
                    "modified_label": time.strftime(
                        "%Y-%m-%d %H:%M", time.localtime(modified_at)
                    ),
                    "blocks": blocks,
                }
            )
        except (OSError, UnicodeError, WikiError) as exc:
            errors.append(
                {
                    "code": "article_unavailable",
                    "path": display_path,
                    "message": clean_text(str(exc), 240),
                }
            )

    articles.sort(
        key=lambda article: (
            int(article["category_order"]),
            str(article["category_title"]).casefold(),
            int(article["order"]),
            str(article["title"]).casefold(),
        )
    )
    enrich_links(articles, warnings)

    categories_by_id: dict[str, dict[str, object]] = {}
    for article in articles:
        category_id = str(article["category_id"])
        category = categories_by_id.setdefault(
            category_id,
            {
                "id": category_id,
                "title": article["category_title"],
                "order": article["category_order"],
                "article_count": 0,
                "default_article_id": article["id"],
            },
        )
        category["article_count"] = int(category["article_count"]) + 1

    categories = sorted(
        categories_by_id.values(),
        key=lambda category: (
            int(category["order"]),
            str(category["title"]).casefold(),
        ),
    )
    default_category_id = str(categories[0]["id"]) if categories else ""
    default_article_id = str(categories[0]["default_article_id"]) if categories else ""
    ok = bool(articles) or not errors

    return {
        "schema_version": SCHEMA_VERSION,
        "ok": ok,
        "source": "markdown-wiki",
        "observed_at": observed_at,
        "data": {
            "root": str(root),
            "default_category_id": default_category_id,
            "default_article_id": default_article_id,
            "category_count": len(categories),
            "article_count": len(articles),
            "categories": categories,
            "articles": articles,
            "warnings": warnings[:100],
            "errors": errors[:100],
        },
        "error": (
            None
            if ok
            else {
                "code": "wiki_articles_unavailable",
                "message": "No Markdown article could be loaded.",
            }
        ),
    }


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "catalog"
    if action != "catalog" or len(sys.argv) > 2:
        print("Usage: wiki-status.py catalog", file=sys.stderr)
        return 2

    script_dir = Path(__file__).resolve().parent
    config_dir = script_dir.parent
    configured_root = os.environ.get("SENOMY_WIKI_ROOT")
    root = Path(configured_root).expanduser() if configured_root else config_dir / "wiki"
    compact_json(load_wiki(root.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
