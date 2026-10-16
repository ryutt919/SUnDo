"""VERSION = 'v1': Collect installed agent skills into a portable JSON inventory."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

VERSION = "v1"
PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT_ROOT / "data" / "01_skills_inventory.json"
KST = timezone(timedelta(hours=9), "KST")
CATEGORIES = [
    ("디자인과 인터페이스", r"design|frontend|front-end|ui(?:-|$)|ux|css|tailwind|figma|canvas|animation|motion|accessibility|typography"),
    ("모바일과 앱", r"android|ios|swift|flutter|dart|expo|react-native|mobile|electron|avalonia"),
    ("데이터와 인공지능", r"data|machine-learning|deep-learning|(?:^|-)ml(?:-|$)|(?:^|-)ai(?:-|$)|llm|embedding|rag|pytorch|tensorflow|pandas|numpy|statistic|analytics"),
    ("연구와 과학", r"research|academic|paper|scientific|bio|chem|physic|astro|quantum|citation|experiment|medical|health"),
    ("보안과 감사", r"security|audit|attack|penetration|vulnerab|exploit|fuzz|reverse|binary|malware|auth|threat|red-team"),
    ("클라우드와 운영", r"cloud|aws|azure|gcp|docker|kubernetes|deploy|devops|infra|terraform|monitor|observab|incident|performance|cost|sre|cicd|ci-cd"),
    ("개발과 코드 품질", r"code|debug|test|refactor|git|github|commit|branch|pull-request|lint|build|architecture|architect|pattern|api|backend|database|sql|migration|programming|(?:^|-)pro$"),
    ("웹과 브라우저", r"web|browser|chrome|nextjs|next-js|react|angular|vue|svelte|astro|html|seo|wordpress|extension"),
    ("문서와 지식 관리", r"doc|pdf|markdown|report|writing|write|readme|notion|obsidian|knowledge|spreadsheet|excel|ppt|slide|presentation|libreoffice|calc"),
    ("업무와 서비스 연동", r"automation|workflow|integration|slack|discord|teams|calendar|email|gmail|outlook|airtable|asana|clickup|linear|jira|drive|dropbox|box|zapier|crm|salesforce|hubspot"),
    ("마케팅과 비즈니스", r"market|business|sales|growth|brand|copy|content|social|advert|creative|product|customer|pricing|startup|founder|finance|financial|billing|commerce|payment|shopify|trade|legal|contract"),
    ("게임과 미디어", r"game|gaming|unity|unreal|godot|bevy|audio|video|image|music|art(?:-|$)|3d|2d|shader|remotion|transcrib|voice"),
    ("스킬과 에이전트", r"skill|agent|orchestrat|context|memory|prompt|codex|claude|octopus|octo|copilot"),
    ("개발 언어와 도구", r"python|javascript|typescript|java|golang|rust|ruby|php|csharp|cpp|dotnet|elixir|bash|shell|powershell|bun|node|tool|cli|terminal|linux|windows"),
]


def category_for(name: str, description: str) -> str:
    for text in (name.casefold(), description.casefold()):
        for label, pattern in CATEGORIES:
            if re.search(pattern, text):
                return label
    return "기타"


def regex_frontmatter_values(text: str) -> dict[str, str]:
    """Recover name/description from pre-existing invalid YAML after a warning."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    values: dict[str, str] = {}
    index = 1
    while index < len(lines) and lines[index].strip() != "---":
        match = re.match(r"^(name|description):\s*(.*)$", lines[index])
        if not match:
            index += 1
            continue
        key, value = match.groups()
        if re.fullmatch(r"[>|][+-]?", value.strip()) or not value.strip():
            chunks = []
            index += 1
            while index < len(lines) and (lines[index].startswith((" ", "\t")) or not lines[index].strip()):
                chunks.append(lines[index].strip())
                index += 1
            value = " ".join(chunks)
        else:
            index += 1
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = re.sub(r"\s+", " ", value).strip()
    return values


def fallback_description(text: str) -> str:
    body = re.sub(r"\A---\s*\n.*?\n---\s*\n", "", text, count=1, flags=re.S)
    for paragraph in re.split(r"\n\s*\n", body):
        paragraph = paragraph.strip()
        if not paragraph or paragraph.startswith(("#", "```", "---", "<", "|")):
            continue
        cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", paragraph)
        cleaned = re.sub(r"[*`>#]", "", cleaned)
        return re.sub(r"\s+", " ", cleaned).strip()[:600]
    return "설명 없음"


def collect() -> dict:
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []

    def report_error(path: Path | str, error: Exception) -> None:
        record = {"path": str(path), "error": f"{type(error).__name__}: {error}"}
        errors.append(record)
        print(f"[수집 오류] {record['path']}: {record['error']}", file=sys.stderr)

    lock_path = Path.home() / ".agents" / ".skill-lock.json"
    lock: dict = {}
    if lock_path.exists():
        try:
            lock = json.loads(lock_path.read_text(encoding="utf-8-sig")).get("skills", {})
        except (OSError, UnicodeError, ValueError) as error:
            report_error(lock_path, error)

    roots = [
        (Path.home() / ".codex/skills", ["Codex"], "global"),
        (Path.home() / ".claude/skills", ["Claude Code"], "global"),
        (Path.home() / ".agents/skills", ["Codex"], "global"),
        (Path.home() / ".codex/plugins/cache", ["Codex"], "plugin"),
        (Path.home() / ".claude/plugins/cache", ["Claude Code"], "plugin"),
    ]
    groups: dict[str, dict] = {}
    discovered = 0
    root_counts = []
    for root, agents, kind in roots:
        count = 0
        if not root.exists():
            report_error(root, FileNotFoundError("스킬 탐색 경로가 없습니다"))
            continue
        visited: set[str] = set()
        for parent, directories, filenames in os.walk(root, followlinks=True, onerror=lambda error: report_error(error.filename or root, error)):
            parent_path = Path(parent)
            try:
                resolved = str(parent_path.resolve(strict=True)).casefold()
            except OSError as error:
                report_error(parent_path, error)
                directories[:] = []
                continue
            if resolved in visited:
                directories[:] = []
                continue
            visited.add(resolved)
            directories[:] = sorted(d for d in directories if d.casefold() != ".staging" and not d.casefold().startswith("plugin-install-"))
            for filename in filenames:
                if filename.casefold() != "skill.md":
                    continue
                path = parent_path / filename
                discovered += 1
                count += 1
                try:
                    raw = path.read_bytes()
                    content = raw.decode("utf-8-sig")
                    real_path = str(path.resolve(strict=True))
                except (OSError, UnicodeError) as error:
                    report_error(path, error)
                    continue
                metadata = {}
                frontmatter = re.match(r"\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|$)", content, flags=re.S)
                if frontmatter:
                    try:
                        parsed = yaml.safe_load(frontmatter.group(1))
                        if parsed is not None and not isinstance(parsed, dict):
                            raise ValueError("frontmatter가 YAML 매핑이 아닙니다")
                        metadata = {field: re.sub(r"\s+", " ", str(parsed[field])).strip() for field in ("name", "description") if parsed and parsed.get(field) is not None}
                    except (yaml.YAMLError, ValueError) as error:
                        warning = {"path": str(path), "warning": f"기존 YAML 파싱 실패, 정규식 복구 사용: {type(error).__name__}: {error}"}
                        warnings.append(warning)
                        print(f"[메타데이터 경고] {path}: {warning['warning']}", file=sys.stderr)
                        metadata = regex_frontmatter_values(content)
                elif content.startswith("---"):
                    warning = {"path": str(path), "warning": "frontmatter 닫는 구분자가 없어 정규식 복구 사용"}
                    warnings.append(warning)
                    print(f"[메타데이터 경고] {path}: {warning['warning']}", file=sys.stderr)
                    metadata = regex_frontmatter_values(content)
                name = metadata.get("name") or path.parent.name
                description = (metadata.get("description") or fallback_description(content)).replace("\u00b7", ",")
                key = name.casefold()
                digest = hashlib.sha256(raw).hexdigest()
                if key not in groups:
                    groups[key] = {"name": name, "description": description, "category": category_for(name, description), "agents": [], "locations": [], "sources": [], "_hashes": set()}
                item = groups[key]
                item["_hashes"].add(digest)
                for agent in agents:
                    if agent not in item["agents"]:
                        item["agents"].append(agent)
                    location = {"path": str(path), "realPath": real_path, "agent": agent, "kind": kind, "sha256": digest}
                    if location not in item["locations"]:
                        item["locations"].append(location)
                source = lock.get(name) or lock.get(path.parent.name)
                if source:
                    source_data = {field: source[field] for field in ("source", "sourceUrl", "skillPath", "sourceType", "installedAt", "updatedAt") if field in source}
                    if source_data not in item["sources"]:
                        item["sources"].append(source_data)
        root_counts.append({"path": str(root), "kind": kind, "agents": agents, "discoveredFiles": count})
    skills = []
    for item in sorted(groups.values(), key=lambda item: item["name"].casefold()):
        item["variants"] = len(item.pop("_hashes"))
        item["agents"].sort()
        representative = item["sources"][0] if item["sources"] else {}
        for field in ("source", "sourceUrl", "updatedAt"):
            item[field] = representative.get(field, "")
        skills.append(item)
    return {
        "meta": {"version": VERSION, "scannedAt": datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S KST"), "total": len(skills), "unique": len(skills), "discoveredFiles": discovered, "errors": errors, "warnings": warnings, "roots": root_counts, "lockPath": str(lock_path), "grouping": "name (case-insensitive)", "pluginCacheNote": "플러그인 캐시의 존재는 활성 설치를 보장하지 않습니다", "categories": dict(Counter(item["category"] for item in skills)), "agentCounts": {agent: sum(agent in item["agents"] for item in skills) for agent in ("Claude Code", "Codex")}},
        "skills": skills,
    }


if __name__ == "__main__":
    inventory = collect()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(OUTPUT), "total": inventory["meta"]["total"], "discoveredFiles": inventory["meta"]["discoveredFiles"], "errors": len(inventory["meta"]["errors"]), "agentCounts": inventory["meta"]["agentCounts"], "categories": inventory["meta"]["categories"]}, ensure_ascii=False))
