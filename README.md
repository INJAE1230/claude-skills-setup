# claude-skills-setup

새 PC나 새 환경에서 Claude Code 스킬·플러그인·MCP·도구를 한 번에 복구하기 위한 설치 스크립트입니다.

## 새 스킬·플러그인 추가 규칙

**새 스킬이나 플러그인은 SkillSpector로 먼저 검사한 뒤에 추가합니다.**

```powershell
skillspector scan https://github.com/<owner>/<repo> --no-llm
```

- 점수만 보고 정하지 않습니다. `--no-llm` 은 문맥 없이 패턴만 찾아서 오탐이 많습니다
  (Anthropic 공식 `mcp-builder`·`skill-creator` 도 100점이 나옵니다).
- HIGH·CRITICAL 발견은 해당 파일·줄을 직접 열어 확인합니다. 설명 문서·예시·테스트 코드면 오탐,
  실제로 비밀 파일을 읽어 외부로 보내거나 몰래 명령을 실행하면 추가하지 않습니다.
- "분석 미완료(Incomplete referenced artifact analysis)"는 안전하다는 뜻이 아닙니다. 큰 번들 파일은 따로 봅니다.
- 여러 스킬을 한 번에 `--recursive` 로 돌리면 보고서 크기 제한에 걸려 일부가 빠집니다. 하나씩 검사합니다.

## 사용법

전역(`~/.claude/skills`)에 설치되며, Claude Code를 재시작하면 스킬 목록에 나타납니다.

### 실행 전 체크

- **Claude Code와 VS Code를 닫습니다.** 스킬 디렉터리를 쓰는 중이면 충돌합니다.
- `git`, Node.js(`npx`), `claude` CLI, `winget` 이 설치돼 있어야 합니다. 없으면 해당 줄이
  실패 목록에 뜨고 종료 코드 1로 끝납니다(조용히 넘어가지 않습니다).
- watch 의 음성 인식(로컬 WhisperX, 약 3GB)까지 깔려면 `-WithWhisper` 를 붙입니다.
  붙이지 않으면 영상 자막만 씁니다. 한 번 깔린 PC는 이후 `-WithWhisper` 없이 돌려도 유지됩니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\install-skills.ps1 -WithWhisper
```

### 처음 세팅하는 PC

```powershell
cd $HOME
git clone https://github.com/INJAE1230/claude-skills-setup.git
cd $HOME\claude-skills-setup
powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
powershell -ExecutionPolicy Bypass -File .\verify-skills.ps1
```

### 이미 받아둔 PC (노트북·회사 PC)

```powershell
cd $HOME\claude-skills-setup
git pull
powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
powershell -ExecutionPolicy Bypass -File .\verify-skills.ps1
```

`./install-skills.ps1` 로 바로 실행하지 않는 이유: Windows 클라이언트의 실행 정책
기본값이 `Restricted` 라서 `... cannot be loaded because running scripts is disabled
on this system.` 으로 거부됩니다. `powershell -ExecutionPolicy Bypass -File` 형태로
두 스크립트를 모두 실행합니다.

### 정상 결과

```
스크립트 선언: 22개 / 실제 설치: 22개
플러그인 선언: 8개 / 실제 설치: 8개
MCP 선언: 1개 / 등록: 1개
도구 선언: 5개 / 설치: 5개

일치합니다. 스킬 22개 · 플러그인 8개 · MCP 1개 · 도구 5개가 스크립트·README·실제 설치 상태에서 모두 동일합니다.
```

플러그인이 8개가 안 되면 Claude Code를 한 번 재시작하고 verify를 다시 돌립니다
(설치 직후 `installed_plugins.json` 반영이 늦을 수 있습니다).

## 설치되는 스킬 (22개)

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
| `supabase-postgres-best-practices` | `supabase/agent-skills` | Postgres 스키마·마이그레이션·RLS 정책·인덱스·쿼리 성능 모범사례 |
| `supabase` | `supabase/agent-skills` | Supabase Auth·Edge Functions·Storage·CLI·RLS 문제 해결 |
| `security-audit` | `cloudflare/security-audit-skill` | 코드베이스·API 보안 점검과 취약점 리뷰 |

`pdf`·`docx`·`xlsx`·`pptx`(`anthropics/skills`)는 넣지 않았습니다. claude.ai 계정에 딸린
`anthropic-skills` 로 이미 제공돼, 여기서 또 설치하면 같은 스킬이 두 벌 생깁니다.

## 설치되는 플러그인 (8개)

| 플러그인 | 마켓플레이스 | 용도 |
| --- | --- | --- |
| vercel@claude-plugins-official | `anthropics/claude-plugins-official` | Vercel·Next.js·AI SDK 가이드 |
| humanize-korean@im-not-ai | `epoko77-ai/im-not-ai` | AI 티 나는 한글 윤문 |
| ponytail@ponytail | `DietrichGebert/ponytail` | 과설계 방지(최소 구현) 모드 |
| claude-mem@thedotmack | `thedotmack/claude-mem` | 세션 간 기억 저장·검색 |
| prompts.chat@prompts.chat | `f/prompts.chat` | prompts.chat 프롬프트·스킬 검색·저장 |
| claude-code-setup@claude-plugins-official | `anthropics/claude-plugins-official` | 코드베이스 분석 후 훅·스킬·MCP 자동화 추천 |
| caveman@caveman | `JuliusBrussee/caveman` | 응답을 짧게 압축하는 모드 · cavecrew 서브에이전트 |
| watch@claude-video | `bradautomates/claude-video` | 영상(URL·파일)을 장면 이미지와 자막·음성 인식 텍스트로 바꿔 분석 |

플러그인 표 첫 칸에 백틱을 쓰지 않는 이유: `verify-skills.ps1` 이 백틱으로 시작하는 줄을 스킬로 센다.

## 설치되는 MCP (1개)

user 범위(`--scope user`)로 등록해 모든 프로젝트에서 씁니다.

| MCP | 실행 명령 | 용도 |
| --- | --- | --- |
| context7 | `cmd /c npx -y @upstash/context7-mcp` | 라이브러리·프레임워크 최신 문서 조회 |

API 키는 스크립트에 넣지 않습니다. 키 없이도 동작하며, 쓰려면 각 PC에서 따로 설정합니다.
MCP 표 첫 칸에도 백틱을 쓰지 않습니다(스킬로 세지 않도록).

## 설치되는 도구 (5개)

없는 것만 `winget`(skillspector 는 `uv`)으로 설치합니다. watch 용 Python 3.10 이상도 없으면 설치합니다.

| 도구 | 설치 방법 | 용도 |
| --- | --- | --- |
| uv | `winget install astral-sh.uv` | skillspector 설치 |
| skillspector | `uv tool install git+https://github.com/NVIDIA/skillspector.git` | 스킬·플러그인 보안 검사 |
| ffmpeg | `winget install Gyan.FFmpeg` | watch: 장면 추출·오디오 변환 |
| yt-dlp | `winget install yt-dlp.yt-dlp` | watch: 영상·자막 내려받기 |
| deno | `winget install DenoLand.Deno` | watch: yt-dlp 의 유튜브 처리 |

## watch 사용법

Claude Code 입력창에서 `/watch:watch` 다음에 영상 주소나 파일 경로와 질문을 씁니다.

```
/watch:watch https://www.youtube.com/watch?v=영상ID 이 영상 핵심 3줄로 요약해줘
/watch:watch C:\Users\tnvjf\Videos\화면녹화.mp4 3분쯤 에러 메시지가 뭐야?
```

- 유튜브 등 URL: 자막이 있으면 자막을 쓰고, 없으면 음성 인식(WhisperX)을 씁니다.
- 화면 녹화 mp4 같은 로컬 파일: 경로를 그대로 붙여 넣습니다. 장면 이미지와 음성 인식 결과를 봅니다.
- 10분 이하 영상이나 특정 구간을 물어볼 때 가장 정확합니다.

설정 파일은 `~/.config/watch/.env` 입니다. 스크립트가 아래처럼 고정합니다.

- `WATCH_ENGINE=local` — 영상을 Google(Gemini)로 올리지 않습니다. 기본값 `auto` 는 환경변수나
  **작업 폴더의 `.env`** 에 `GEMINI_API_KEY` 가 있으면 자동으로 클라우드를 씁니다.
- `WATCH_WHISPER_BACKEND=whisperx`(`-WithWhisper`) 또는 `none`(자막만) — Groq·OpenAI 키를 쓰지 않습니다.
- 로그인이 필요한 영상(인스타 등)용 쿠키 설정(`--cookies-from-browser`)은 넣지 않았습니다.

## 제거된 스킬과 이유

보안 점검에서 걸러냈거나 출처 저장소에서 사라진 스킬입니다. 설치 목록에서 빼는 것만으로는 이미 설치된 PC가
정리되지 않아, `install-skills.ps1` 시작 부분의 **제거 대상 스킬** 섹션이 설치 전에
먼저 지웁니다. 해당 스킬이 없으면 조용히 넘어갑니다.

| 스킬 | 출처 | 제거 이유 |
| --- | --- | --- |
| code-reviewer | `jeffallan/claude-skills` | Gen 감사 CRITICAL |
| deploy-to-vercel | `vercel-labs/agent-skills` | 프로젝트 소스를 외부 엔드포인트(`claude-skills-deploy.vercel.com`)로 인증 없이 업로드하는 경로 |
| find-skills | `vercel-labs/skills` | `npx skills add` 로 제3자 저장소 코드 설치를 유도하는 공급망 진입점 |
| image-to-code | `leonxlnx/taste-skill` | 출처 저장소에서 삭제됨 — 새 PC에 설치할 수 없음 |

제거는 `npx skills remove <스킬> -g -y` 로 하고, `~/.agents/.skill-lock.json` 에 남은 엔트리까지
같이 지웁니다. 록 엔트리를 남겨두면 `npx skills update` 가 제거한 스킬을 다시 끌어옵니다.
`-g` 가 없으면 현재 폴더(프로젝트 범위)만 보기 때문에 저장소 폴더에서 실행하면 전역 스킬이
지워지지 않습니다. 제거 뒤에는 두 설치 위치에 폴더가 남았는지 직접 확인하고, 남아 있으면
실패로 집계합니다.

설치 위치는 `~/.claude/skills` 와 `~/.agents/skills` 두 곳이라 양쪽을 다 확인합니다
(`find-skills` 는 `~/.agents/skills` 에만 설치돼 `~/.claude/skills` 만 보면 못 찾습니다).

제거 표 첫 칸에도 백틱을 쓰지 않습니다 — 위와 같은 이유로 `verify-skills.ps1` 이
설치 대상 스킬로 오인합니다.

## 참고

- 설치 후 확인: `verify-skills.ps1` (Claude Code 재시작 뒤, 새 터미널에서)
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
- **MCP**: 스크립트의 `claude mcp add --scope user` 줄마다 `claude mcp get` 으로 등록 여부 확인, README MCP 표와 대조
- **도구**: 스크립트의 `$requiredTools` 목록이 PATH 에 있는지 확인
- **개수 표기**: 스크립트·README에 적힌 스킬·플러그인·MCP·도구 개수

일치하면 종료 코드 0, 어긋나면 1을 반환하므로 pre-commit 훅이나 CI에 그대로 걸 수 있습니다.
