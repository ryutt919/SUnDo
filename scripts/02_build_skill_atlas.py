"""VERSION = "v1": 수집한 전역 스킬을 오프라인 HTML 서재로 생성한다."""
from pathlib import Path
import json

VERSION = "v1"
ROOT = Path(__file__).resolve().parents[1]


def main():
    data = json.loads((ROOT / "data/01_skills_inventory.json").read_text(encoding="utf-8"))
    template = (ROOT / "htmls/01_스킬_서재_템플릿.html").read_text(encoding="utf-8")
    assert template.count("__INVENTORY__") == 1, "HTML 데이터 삽입 위치가 정확히 하나여야 합니다."
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    payload = payload.replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    output = ROOT / "htmls/v1_스킬_서재/01_설치된_스킬.html"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(template.replace("__INVENTORY__", payload), encoding="utf-8")
    print(json.dumps({"output": str(output), "skills": len(data["skills"]), "bytes": output.stat().st_size}, ensure_ascii=False))


if __name__ == "__main__":
    main()
