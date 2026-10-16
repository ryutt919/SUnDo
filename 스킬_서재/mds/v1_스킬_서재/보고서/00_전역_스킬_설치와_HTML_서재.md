# 전역 스킬 설치와 HTML 서재

## Task Metadata
- **작성 및 갱신 시각**: 2026-10-17 03:38:10 KST
- **사용 모델**: gpt-6
- **사용자 요구사항**: 디자인 도구 5종을 Claude Code와 Codex 전역에 설치하고, 처음 네 디자인 스킬을 사용해 설치된 모든 스킬을 보기 좋은 HTML로 정리한다.
- **버전**: v1 (폴더 v1_스킬_서재)

- **이전 위치**: mds/v1_스킬_서재/보고서/00_전역_스킬_설치와_HTML_서재.md
- **이번 정리 요구사항**: 스킬 서재 관련 파일을 전용 하위 폴더로 모은다.

## 결과
- 디자인 스킬 **5개**를 Skills CLI로 전역 설치하고 두 도구에서 SKILL.md 읽기를 검증했다.
- 설치 파일 **1,380개 경로**, 이름별 그룹 **1,119개**, 분류 **15개**를 수집했다.
- 전역 스킬 이름 **996개**, 플러그인 캐시 이름 **125개**, 두 유형에 공통 이름 2개다.
- 도구별 집계는 Claude Code 156개, Codex 1,105개이며, 플러그인 캐시를 포함한 수치다.
- 읽기 오류 **0개**다. 기존 YAML 형식 경고 4건은 기록 후 이름과 설명을 정규식으로 복구했다.
- 산출물: [오프라인 스킬 서재](../../../htmls/v1_스킬_서재/01_설치된_스킬.html), [원본 목록](../../../data/01_skills_inventory.json).

## 목표와 접근과 검증 계획
- 목표: 두 에이전트의 전역 설치를 완료하고 누락을 줄인 통합 탐색 화면을 제공한다.
- 접근: 배포처 확인, 요청 항목만 설치, 연결 경로를 따라 재귀 수집, 이름별 그룹화, 분야 자동 분류, 독립 HTML 생성 순서로 진행했다.
- 검증: 설치 파일 읽기, JSON 수량 검산, Chrome 기능 검증, 세 화면 크기와 어두운 테마와 동작 줄이기 확인을 수행했다.

## 설치 내역
| 요청 이름 | 배포처 | 실제 스킬 이름 |
|---|---|---|
| TasteSkill | [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) | design-taste-frontend |
| UI UX Pro Max | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | ui-ux-pro-max |
| Awesome Claude Design | [reason-machines/design-skills](https://github.com/reason-machines/design-skills) | awesome-claude-design |
| Design Motion Principles | [kylezantos/design-motion-principles](https://github.com/kylezantos/design-motion-principles) | design-motion-principles |
| DESIGN.md Chrome | [reason-machines/design-skills](https://github.com/reason-machines/design-skills) | design-md-chrome-extractor |

- 공통 옵션: `--global --agent claude-code codex --yes`.
- 실제 파일은 사용자 홈의 `.agents/skills/<스킬>`에 설치된다. Codex는 이 공용 전역 경로를 사용하며 Claude Code는 `.claude/skills/<스킬>` 연결을 사용한다.
- 설치 검증 매니페스트에 다섯 스킬의 122개 파일 목록, 두 도구 경로 10곳의 읽기 결과와 SHA256을 기록했다: [설치 검증](../../../data/02_design_skill_installation.json).
- [Awesome Claude Design 원본](https://github.com/VoltAgent/awesome-claude-design)은 견본 목록이다. 설치한 항목은 그 목록을 활용하는 가이드이며 68개가 별도 스킬로 설치된 것은 아니다.
- [DESIGN.md Chrome 원본](https://github.com/bergside/design-md-chrome)은 브라우저 확장이다. 이번에는 추출 방법 가이드를 설치했으며 확장 자체는 설치하지 않았다. [Chrome 웹 스토어](https://chromewebstore.google.com/detail/designmd-style-extractor/ogpdnchdjiibhobphelbbkemnnemkfma)에서 별도 설치할 수 있다.
- CLI는 요청하지 않은 스킬을 설치하지 않았다. 배포 저장소의 일부 다른 스킬에서 나온 필수 메타데이터 경고는 요청한 다섯 항목과 무관하다.
- 새 스킬은 다음 턴 또는 새 세션부터 검색된다. 기존 실행 중인 세션에서 보이지 않으면 해당 도구 세션을 재시작한다.

## 수집 기준
- 대상: `~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`, 양쪽 `plugins/cache`.
- 연결 경로를 추적하고 실경로 방문 집합으로 순환을 방지했다.
- `.staging`, `plugin-install-*` 임시 디렉터리는 제외했다.
- 같은 이름은 대소문자 구분 없이 하나로 묶었다. 서로 다른 내용이 있는 그룹 70개는 variants와 각 경로의 SHA256으로 보존했다.
- 분야는 이름 우선, 설명 보조의 정규식 분류다. 자동 분류의 정확도를 보장하지 않는다.
- 원문 설명은 보존하되 중간점 구분자는 쉼표로 정규화했다. 번역한 설명으로 가장하지 않는다.
- 설치 잠금 파일에 기록된 출처는 71개 그룹에서 찾았다. 나머지는 출처 미기록으로 표시한다.
- 공용 경로 자체는 Codex로만 판정한다. Claude Code는 실제 Claude 전역 경로에서 발견한 경우에만 표시한다.
- 캐시는 파일 존재만 뜻하며 현재 활성 상태를 보장하지 않는다.
- 기존 `readme-portfolio`와 `flow-discover`의 YAML 문제는 각 도구 사본에서 발생해 총 4건이다. 원본 파일은 수정하지 않았다.

## 네 디자인 스킬의 적용
- TasteSkill:
  - 최신 스킬의 적용 범위는 공개 웹페이지이며 대시보드를 제외한다. 사용자의 명시적 요청에 따라 이번 도구에는 장식 패턴 점검과 타이포그래피, 비대칭 구성 원칙만 적용했다.
  - 목록이 주인공이 되도록 그라데이션, 장식 그림자, 반복되는 소개 카드, 이모지 아이콘을 피했다.
  - 대시보드에 부적합한 무작위 마케팅 구성 추첨과 사진 최소 개수, 상시 움직임 요구는 적용하지 않았다.
- UI UX Pro Max:
  - 첫 검색의 웨딩 스타일 결과는 부적합해 버렸다.
  - `internal knowledge base dashboard`로 좁혀 Swiss Style, 검색 우선 탐색, 읽기 대비, 키보드와 터치 기준을 채택했다.
  - HTML은 프레임워크 없이 시스템 글꼴을 사용해 오프라인 실행을 지원한다.
- Awesome Claude Design:
  - 원본 목록과 [Notion 분석](https://getdesign.md/notion/design-md), [Linear 분석](https://getdesign.md/linear.app/design-md)을 확인했다.
  - Notion의 차분한 문서 공간과 Linear의 정밀한 정보 위계를 참고했다. 직접 DESIGN.md 다운로드는 HTTP 403이어서 원문 파일을 가져왔다고 주장하지 않는다.
  - 특정 서비스와의 공식 관계나 정확한 복제를 주장하지 않는다.
- Design Motion Principles:
  - 생성 절차, 모션 레시피, 접근성, 주의사항, Emil과 Jakub 참고 문서를 읽었다.
  - 생산성 도구 맥락에 대해 사용자가 “제안대로 진행”으로 확인했다.
  - 검색과 필터와 키보드 동작은 즉시 반응한다. 상세창은 opacity, transform, filter에 180ms 전환을 적용했다.
  - `prefers-reduced-motion`에서는 전환을 제거한다.

## 제공 기능
- 이름, 원문 설명, 분야, 출처와 신규 도구 한국어 별칭 검색.
- 분야, 설치 도구, 두 도구 공통 설치, 전역 / 캐시 필터.
- 이름순, 분야순, 설치 잠금 파일 기준 최근순 정렬.
- 60개씩 페이지 표시, 즐겨찾기와 테마의 로컬 저장.
- 상세창의 모든 설치 경로, 다른 내용 사본 수, 원본 저장소 링크.
- 호출 문구 복사, 현재 검색 결과 JSON 내보내기.
- 슬래시 검색 단축키, Escape 닫기, 포커스 복원, 모바일 메뉴의 키보드 순환.
- 자동 갱신 서비스가 아닌 수집 시점 스냅샷이다. 브라우저 저장소가 차단되면 보관 실패를 알린다.

## 검증과 재현
- [브라우저 검증 결과](../../../evidence/v1_스킬_서재/06_검증결과.json): 의미 있는 검증 항목 12개 통과.
- 1440px, 768px, 390px에서 가로 넘침 없음, 어두운 테마와 동작 줄이기 확인, 브라우저 JavaScript 예외 없음.
- 검색 결과 없음, 입력 문자열의 HTML 비실행, 즐겨찾기 재방문 보존, 필터 수량, 페이지 이동, JSON 내용 확인.
- [데스크톱 화면](../../../evidence/v1_스킬_서재/01_데스크톱.png), [태블릿 화면](../../../evidence/v1_스킬_서재/02_태블릿.png), [모바일 화면](../../../evidence/v1_스킬_서재/03_모바일.png), [상세창](../../../evidence/v1_스킬_서재/04_상세정보.png), [어두운 테마](../../../evidence/v1_스킬_서재/05_어두운테마.png).
- TasteSkill 소스 검사: 0 FAIL, 0 WARN. 상세창 그림자는 실제 오버레이로 명시했다.
- 렌더링 검사는 마케팅 전용 규칙을 제외한 결과와 남은 주의사항을 [검사 기록](../../../evidence/v1_스킬_서재/검사/report.json)에 보관했다.
  - 제외 사유: eyebrow는 실제 수집 시각, numbering은 실제 스킬 이름 007, still-page는 사용자가 승인한 생산성 도구의 절제된 동작이다.
  - 사진, 거대한 홍보 초점, 소개용 아이콘 카드 제한과 본문 최소 크기 판단은 마케팅 페이지 기준이므로 제외했다.
  - 남은 경고는 글자 크기 종류 수, 설명의 회색 톤, 긴 줄 길이, 영상 없음, 모바일의 명시적 가로 목록이다. 설명 대비는 약 5.7:1이며 웹 본문 기준 4.5:1 이상이다.
- 실행:
  ```powershell
  python scripts/01_collect_skills.py
  python scripts/02_build_skill_atlas.py
  node scripts/03_verify_skill_atlas.mjs
  ```
- 수집 의존성: Python 3와 PyYAML. 검증 의존성: Node 22 이상, Chrome / Edge, 설치된 TasteSkill의 CDP 보조 모듈.
- 생성된 HTML은 외부 자원이나 서버 없이 더블클릭으로 열 수 있다.

## 변경 파일과 환경
- 생성 파일:
  - [수집 스크립트](../../../scripts/01_collect_skills.py), [생성 스크립트](../../../scripts/02_build_skill_atlas.py), [브라우저 검증 스크립트](../../../scripts/03_verify_skill_atlas.mjs).
  - [HTML 템플릿](../../../htmls/01_스킬_서재_템플릿.html), [완성 HTML](../../../htmls/v1_스킬_서재/01_설치된_스킬.html).
  - [목록 JSON](../../../data/01_skills_inventory.json), [설치 매니페스트](../../../data/02_design_skill_installation.json).
  - 본 보고서, [버전 기록서](../00_버전_기록서.md), [인계 문서](../../../Agent_handoff/03_전역_스킬_서재.md), 검증 JSON과 이미지.
- 수정 파일: [PM](../../00_PM.md).
- 전역 환경 변경: 다섯 스킬의 122개 파일, Claude 연결 폴더 5개, `~/.agents/.skill-lock.json`. 구체적 파일은 설치 매니페스트 참조.

## 한계와 후속 작업
- Chrome 추출 확장 자체의 설치는 별도다.
- 설치된 스킬의 안전성 전체를 감사하거나 모두 실행한 것은 아니다.
- 서로 다른 저장소가 같은 이름을 사용하면 이름별 모음 안에 함께 표시된다.
- 설치 잠금 파일에 없는 사본의 최근 설치일은 알 수 없어 최근순의 뒤쪽에 배치된다.
- 스킬 파일은 사용자 전역 환경에 있으며 Git에 포함되지 않는다. Git에는 목록과 검증 기록만 저장한다.

## Change History
| 시각 | 모델 | 사용자 요구사항 | 작업 | 변경 요약 |
|---|---|---|---|---|
| 2026-10-17 03:11:28 KST | gpt-6 | 디자인 스킬 전역 설치와 전체 목록 HTML | 최초 구축 | 5개 설치, 1,119개 모음, 브라우저 검증과 재현 자료 생성 |
| 2026-10-17 03:34:55 KST | gpt-6 | 서재 파일 하위 폴더 통합 | 폴더 정리 | 내부 구조와 버전을 유지하여 스킬_서재로 이동 |
