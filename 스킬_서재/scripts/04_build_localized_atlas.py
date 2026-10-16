"""VERSION = "v1.1": 한국어 설명과 개인 메모를 지원하는 스킬 서재를 생성한다."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import re

VERSION = "v1.1"
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/v1.1_한국어_메모"
RAW = DATA / "04_수집_원본.json"
LOCALIZED = DATA / "05_한국어_전체_목록.json"
OUTPUT = ROOT / "htmls/v1.1_한국어_메모/01_설치된_스킬.html"


def collect():
    spec = importlib.util.spec_from_file_location("collect_skills", ROOT / "scripts/01_collect_skills.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = module.collect()
    DATA.mkdir(parents=True, exist_ok=True)
    RAW.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"collected": len(result["skills"]), "errors": result["meta"]["errors"]}, ensure_ascii=False))


def build():
    inventory = json.loads(RAW.read_text(encoding="utf-8"))
    translations = {}
    for path in sorted(DATA.glob("0[123]_한국어_설명.json")):
        chunk = json.loads(path.read_text(encoding="utf-8"))
        duplicates = set(chunk) & set(translations)
        if duplicates:
            raise ValueError(f"한국어 설명 키 중복: {sorted(duplicates)}")
        translations.update(chunk)
    missing = {skill["name"] for skill in inventory["skills"]} - translations.keys()
    if missing:
        raise ValueError(f"한국어 설명 누락 {len(missing)}개: {sorted(missing)}")
    for skill in inventory["skills"]:
        original = skill["description"]
        summary = translations[skill["name"]].strip()
        if not re.search("[가-힣]", summary) or len(summary) > 85 or "\n" in summary or "\u00b7" in summary:
            raise ValueError(f"한국어 설명 형식 오류: {skill['name']}: {summary}")
        skill["originalDescription"] = original
        skill["description"] = summary
        if skill["name"] == "karpathy-guidelines":
            skill["category"] = "개발과 코드 품질"
        skill["agents"].sort(key=str.casefold)
        skill["locations"].sort(key=lambda location: (location["agent"].casefold(), location["path"].casefold()))
    inventory["meta"]["version"] = VERSION
    inventory["meta"]["localizedAt"] = datetime.now(timezone(timedelta(hours=9))).isoformat()
    inventory["meta"]["descriptionLanguage"] = "ko"
    inventory["meta"]["localizedCount"] = len(inventory["skills"])
    inventory["meta"]["categories"] = dict(Counter(skill["category"] for skill in inventory["skills"]))
    LOCALIZED.write_text(json.dumps(inventory, ensure_ascii=False, indent=2), encoding="utf-8")
    template = (ROOT / "htmls/02_한국어_메모_템플릿.html").read_text(encoding="utf-8")
    notes_script = (ROOT / "htmls/03_스킬_메모.js").read_text(encoding="utf-8")
    assert template.count("__NOTES_SCRIPT__") == 1
    template = template.replace("__NOTES_SCRIPT__", notes_script)
    assert template.count("__INVENTORY__") == 1
    payload = json.dumps(inventory, ensure_ascii=False, separators=(",", ":"))
    payload = payload.replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(template.replace("__INVENTORY__", payload), encoding="utf-8")
    print(json.dumps({"version": VERSION, "skills": len(inventory["skills"]), "output": str(OUTPUT)}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--collect-only", action="store_true")
    args = parser.parse_args()
    if args.collect_only:
        collect()
    else:
        build()
