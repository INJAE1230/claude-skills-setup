# claude-skills-setup

새 PC나 새 환경에서 Claude Code 스킬·플러그인을 한 번에 복구하기 위한 설치 스크립트입니다.

## 사용법

```powershell
powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
```

전역(`~/.claude/skills`)에 설치되며, Claude Code를 재시작하면 스킬 목록에 나타납니다.

## 설치되는 스킬 (20개)

| 스킬 | 출처 | 용도 |
| --- | --- | --- |
| `mcp-builder` | `anthropics/skills` | MCP 서버 제작 가이드 |
| `skill-creator` | `anthropics/skills` | 스킬 생성·개선·평가 |
| `webapp-testing` | `anthropics/skills` | Playwright 기반 웹앱 테스트 |
| `agent-browser` | `vercel-labs/agent-browser` | 브라우저 자동화 CLI |
| `vercel-react-best-practices` | `vercel-labs/agent-skills` | React/Next.js 성능 최적화 |
| `web-design-guidelines` | `vercel-labs/agent-skills` | UI 접근성·디자인 가이드라인 점검 |
| `brainstorming` | `obra/superpowers` | 아이디어를 설계·스펙으로 정리 |
| `prompt-engineer` | `jeffallan/claude-skills` | 프롬프트 작성·리팩터링·평가 |
| `design-taste-frontend` | `leonxlnx/taste-skill` | 랜딩·포트폴리오 프런트엔드 디자인 |
| `image-to-code` | `leonxlnx/taste-skill` | 디자인 이미지를 먼저 만들고 그대로 코드로 구현 |
| `accessibility-compliance` | `wshobson/agents` | WCAG 2.2 접근성 준수·ARIA 패턴 구현 |
| `design-md` | `nexu-io/open-design` | DESIGN.md 디자인 토큰·시각 규칙 문서 작성 |
| `ux-heuristics` | `wondelai/skills` | 닐슨 휴리스틱 기반 사용성 점검 |
| `handoff` | `mattpocock/skills` | 작업 인수인계 문서 작성 |
| `grill-with-docs` | `mattpocock/skills` | 계획·설계를 집요하게 캐물어 다듬고 ADR·용어집 작성 |
| `tdd` | `mattpocock/skills` | 테스트 우선(레드-그린-리팩터) 개발 |
| `diagnosing-bugs` | `mattpocock/skills` | 어려운 버그·성능 회귀 진단 루프 |
| `archify` | `tt-a1i/archify` | 아키텍처·워크플로·시퀀스 다이어그램(HTML) |
| `archify-review` | `tt-a1i/archify` | Archify 이슈·PR·코드 리뷰 |
| `impeccable` | `pbakaus/impeccable` | 프런트엔드 UI 디자인·리디자인·비평·감사·다듬기 |

## 설치되는 플러그인 (7개)

| 플러그인 | 마켓플레이스 | 용도 |
| --- | --- | --- |
| vercel@claude-plugins-official | `anthropics/claude-plugins-official` | Vercel·Next.js·AI SDK 가이드 |
| humanize-korean@im-not-ai | `epoko77-ai/im-not-ai` | AI 티 나는 한글 윤문 |
| ponytail@ponytail | `DietrichGebert/ponytail` | 과설계 방지(최소 구현) 모드 |
| claude-mem@thedotmack | `thedotmack/claude-mem` | 세션 간 기억 저장·검색 |
| prompts.chat@prompts.chat | `f/prompts.chat` | prompts.chat 프롬프트·스킬 검색·저장 |
| claude-code-setup@claude-plugins-official | `anthropics/claude-plugins-official` | 코드베이스 분석 후 훅·스킬·MCP 자동화 추천 |
| caveman@caveman | `JuliusBrussee/caveman` | 응답을 짧게 압축하는 모드 · cavecrew 서브에이전트 |

플러그인 표 첫 칸에 백틱을 쓰지 않는 이유: `verify-skills.ps1` 이 백틱으로 시작하는 줄을 스킬로 센다.

## 제거된 스킬과 이유

보안 점검에서 걸러낸 스킬입니다. 설치 목록에서 빼는 것만으로는 이미 설치된 PC가
정리되지 않아, `install-skills.ps1` 시작 부분의 **제거 대상 스킬** 섹션이 설치 전에
먼저 지웁니다. 해당 스킬이 없으면 조용히 넘어갑니다.

| 스킬 | 출처 | 제거 이유 |
| --- | --- | --- |
| code-reviewer | `jeffallan/claude-skills` | Gen 감사 CRITICAL |
| deploy-to-vercel | `vercel-labs/agent-skills` | 프로젝트 소스를 외부 엔드포인트(`claude-skills-deploy.vercel.com`)로 인증 없이 업로드하는 경로 |
| find-skills | `vercel-labs/skills` | `npx skills add` 로 제3자 저장소 코드 설치를 유도하는 공급망 진입점 |

제거는 `npx skills remove` 로 하고, `~/.agents/.skill-lock.json` 에 남은 엔트리까지
같이 지웁니다. 록 엔트리를 남겨두면 `npx skills update` 가 제거한 스킬을 다시 끌어옵니다.

설치 위치는 `~/.claude/skills` 와 `~/.agents/skills` 두 곳이라 양쪽을 다 확인합니다
(`find-skills` 는 `~/.agents/skills` 에만 설치돼 `~/.claude/skills` 만 보면 못 찾습니다).

제거 표 첫 칸에도 백틱을 쓰지 않습니다 — 위와 같은 이유로 `verify-skills.ps1` 이
설치 대상 스킬로 오인합니다.

## 참고

- 설치 후 확인: `Get-ChildItem $HOME\.claude\skills` · `claude plugin list`
- 개별 스킬만 다시 설치하려면 `install-skills.ps1`에서 해당 줄만 실행하면 됩니다.

## 검증

설치 목록이 실제 설치 상태와 어긋났는지 확인합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\verify-skills.ps1
```

`install-skills.ps1`, `README.md` 표, 실제 설치 상태 세 곳을 대조합니다.

- **스킬**: `~/.claude/skills` 와 대조 — 빠진 스킬·설치 안 된 스킬
- **플러그인**: `~/.claude/plugins/installed_plugins.json` 과 대조 — 빠진 플러그인·설치 안 된 플러그인,
  그리고 **마켓플레이스 등록 줄(`claude plugin marketplace add`)이 빠진 플러그인**
  (새 PC에는 마켓이 등록돼 있지 않아 그 줄이 없으면 설치가 실패합니다)
- **개수 표기**: 스크립트·README에 적힌 스킬·플러그인 개수

일치하면 종료 코드 0, 어긋나면 1을 반환하므로 pre-commit 훅이나 CI에 그대로 걸 수 있습니다.
