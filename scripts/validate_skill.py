#!/usr/bin/env python3
"""Validate the skill layout and SKILL.md frontmatter.

Runs locally and in CI. Exits non-zero on the first structural problem so a
broken frontmatter never reaches the skills root where DSH would ignore it.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MAX_DESCRIPTION = 1024

errors: list[str] = []
notes: list[str] = []


def parse_frontmatter(text: str) -> dict[str, str]:
    """Return the flat key/value pairs of the leading YAML block.

    Only the two keys this skill actually uses are parsed; a full YAML parser
    would add a dependency for no benefit.
    """
    match = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.DOTALL)
    if not match:
        raise ValueError("SKILL.md 必须以 '---' 包裹的 frontmatter 开头")

    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            errors.append(f"frontmatter 行缺少冒号: {line!r}")
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip("\"'")
    return data


def check_layout() -> None:
    for rel in ("SKILL.md", "README.md", "LICENSE", "scripts/gh.ps1"):
        if not (ROOT / rel).is_file():
            errors.append(f"缺少文件: {rel}")


def check_skill_md() -> None:
    path = ROOT / "SKILL.md"
    if not path.is_file():
        return

    text = path.read_text(encoding="utf-8")
    try:
        meta = parse_frontmatter(text)
    except ValueError as exc:
        errors.append(str(exc))
        return

    name = meta.get("name", "")
    description = meta.get("description", "")

    if not name:
        errors.append("frontmatter 缺少 name")
    elif not NAME_RE.match(name):
        errors.append(f"name 必须是 kebab-case（小写字母数字与连字符）: {name!r}")
    elif name != ROOT.name:
        errors.append(f"name ({name!r}) 必须与目录名 ({ROOT.name!r}) 一致")

    if not description:
        errors.append("frontmatter 缺少 description")
    else:
        if len(description) > MAX_DESCRIPTION:
            errors.append(f"description 超过 {MAX_DESCRIPTION} 字符: {len(description)}")
        if "\n" in description:
            errors.append("description 必须是单行")
        lowered = description.lower()
        if not any(k in lowered for k in ("use when", "当", "需要")):
            notes.append("description 没写触发条件（建议以 'Use when ...' 开头）")

    body = text.split("---", 2)[-1].strip()
    if len(body) < 200:
        errors.append("SKILL.md 正文过短，检查是否被截断")


def main() -> int:
    check_layout()
    check_skill_md()

    for note in notes:
        print(f"note: {note}")
    if errors:
        for err in errors:
            print(f"error: {err}")
        print(f"\nFAILED ({len(errors)} error(s))")
        return 1

    print(f"OK  skill={ROOT.name}  description={len(parse_frontmatter((ROOT / 'SKILL.md').read_text(encoding='utf-8')).get('description', ''))} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
