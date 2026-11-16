# 스킬·플러그인 보안 검사 결과

- **검사일:** 2026-11-16
- **도구:** NVIDIA SkillSpector v2.12.0, `--no-llm`(정적 패턴 분석만)
- **대상:** `~/.claude/skills` 의 스킬 24개(하나씩 검사), watch 플러그인(`bradautomates/claude-video`, 설치 전 검사)
- **원본 JSON:** 저장소에 올리지 않음

## 판단 기준

`--no-llm` 은 문맥을 보지 않고 패턴만 찾아 오탐이 많습니다. 그래서 점수가 아니라 **발견 내용**으로 판단했습니다.
HIGH·CRITICAL 발견은 해당 파일·줄을 직접 열어 확인했습니다. 설명 문서·예시·테스트 코드·방어용 문구면 오탐으로,
실제로 비밀 정보를 읽어 외부로 보내거나 몰래 명령을 실행하면 위험으로 봅니다.

`--recursive` 로 한꺼번에 돌리면 보고서 크기 제한(4MB)에 걸려 22개 중 7개만 검사됩니다. 하나씩 검사해야 합니다.

## 스킬별 결과

| 스킬 | 점수 | 등급 | 판단 | 확인 내용 |
| --- | --- | --- | --- | --- |
| archify | 100 | CRITICAL | 유지 | YARA 16건은 예시 HTML 속 글꼴 데이터(`data:font/woff2;base64`). 인증 파일 2건은 `.netrc` 등을 **읽지 않으려는** 차단 목록. "경고 생략"은 문서 문장, 도구 인자는 오류 메시지 문자열. 분석 미완료였던 `bin/archify.mjs` 는 따로 확인함(아래) |
| design-taste-frontend | 100 | CRITICAL | 유지(오탐) | 숨은 지시 19건은 HTML 예시 속 `<script>` 태그, 분석 미완료 24건은 참조 문서 |
| impeccable | 100 | CRITICAL | 유지(오탐) | 내부망 요청은 `localhost` 미리보기 서버, "경고 생략"은 "브라우저를 쓰지 말라"는 리뷰어 지시 |
| mcp-builder | 100 | CRITICAL | 유지(오탐) | Anthropic 공식. 외부 전송은 예시 코드의 `api.example.com`, 인증 접근은 OAuth 설명 문서 |
| prompt-engineer | 100 | CRITICAL | 유지(오탐) | 지시 무시·프롬프트 추출은 평가용 예시 입력("Ignore previous instructions…") |
| security-audit | 100 | CRITICAL | 유지(오탐) | 인증 접근·메모리 조작은 보안 점검 체크리스트 문구 |
| skill-creator | 100 | CRITICAL | 유지(오탐) | Anthropic 공식. 환경변수 수집은 `CLAUDECODE` 변수 제거, 설정 폴더 접근은 `.claude/` 로 프로젝트 루트 찾기 |
| supabase | 64 | HIGH | 유지(오탐) | 인증 접근 10건은 CHANGELOG의 토큰 권장 문구, MCP 설정은 "`.mcp.json` 확인" 안내 |
| vercel-react-best-practices | 59 | HIGH | 유지(오탐) | 출력 주입은 React `dangerouslySetInnerHTML` 사용 예시 |
| brainstorming | 52 | HIGH | 유지(오탐) | 세션 유지·도구 인자는 로컬 미리보기 서버 시작·종료 스크립트 |
| webapp-testing | 49 | MEDIUM | 유지 | subprocess 는 테스트 서버 실행 |
| diagnosing-bugs | 27 | MEDIUM | 유지 | 프롬프트 추출 1건 |
| accessibility-compliance | 25 | MEDIUM | 유지 | 참조 문서 분석 미완료 1건 |
| grilling | 8 | LOW | 유지(오탐) | 자율 결정(EA2) 1건은 "사실 조사는 서브에이전트가, **결정은 사용자에게 묻고 기다린다**"는 문장(`SKILL.md:28`). 실행 파일 없음 (2026-11-16 추가 검사) |
| ux-heuristics | 7 | LOW | 유지 | |
| agent-browser | 0 | LOW | 유지 | 발견 없음 |
| archify-review | 0 | LOW | 유지 | 발견 없음 |
| design-md | 0 | LOW | 유지 | 발견 없음 |
| domain-modeling | 0 | LOW | 유지 | 발견 없음. 실행 파일 없음, 마크다운 문서만 (2026-11-16 추가 검사) |
| grill-with-docs | 0 | LOW | 유지 | 발견 없음 |
| handoff | 0 | LOW | 유지 | 발견 없음 |
| supabase-postgres-best-practices | 0 | LOW | 유지 | 발견 없음 |
| tdd | 0 | LOW | 유지 | 발견 없음 |
| web-design-guidelines | 0 | LOW | 유지 | 발견 없음 |

### archify `bin/archify.mjs` 추가 확인 (2026-11-16)

SkillSpector 가 크기(288,781바이트) 때문에 끝까지 분석하지 못한 파일을 따로 확인했습니다.

| 항목 | 결과 |
| --- | --- |
| 파일 | `~/.claude/skills/archify/bin/archify.mjs` — Node.js ES 모듈, 7,289줄, 난독화·압축 없는 소스 |
| SHA256 | `3cebcee3fa339e3b98deacae8cb9a5570525e003d8823368d304d904ba9ceecd` |
| VirusTotal | 0/54 (직접 조회) |
| 원본 대조 | `tt-a1i/archify` 최신판 `archify/bin/archify.mjs` 와 SHA256 일치. 빌드 산출물이 아니라 공개된 소스 그 자체 |
| 자동 실행 | 없음. 훅이 없고, archify 스킬로 다이어그램을 만들 때 `node bin/archify.mjs finalize/guide/doctor/demo` 로만 실행 |
| 네트워크 | 없음. 파일 안에 URL 이 없고, 스킬 폴더의 `.mjs`·`.js` 전체에 `fetch`·`http.request` 등 통신 코드 없음 |
| 하는 일 | 같은 스킬 폴더의 렌더러를 Node 로 실행(`spawnSync(process.execPath, …)`), 자체 설정 환경변수(`ARCHIFY_*`)만 읽음 |
| 판정 | **유지** |

## 플러그인 (설치 전 검사)

| 플러그인 | 점수 | 등급 | 판단 | 확인 내용 |
| --- | --- | --- | --- | --- |
| watch@claude-video | 100 | CRITICAL | 설치 · 설정 고정 | 인증 접근 11건은 자기 API 키(`GEMINI/GROQ/OPENAI_API_KEY`) 읽기와 테스트 코드, sudo 는 설치 안내 문구, SessionStart 훅은 설정 확인만 함. **실제 위험 1건:** 기본 엔진 `auto` 는 환경변수나 작업 폴더 `.env` 에 키가 있으면 영상·음성을 클라우드로 올림 → `WATCH_ENGINE=local`, `WATCH_WHISPER_BACKEND=whisperx`/`none` 으로 고정 |

## 남은 확인 사항

- 51점 이상 스킬은 발견 유형별 대표 항목만 열어 봤습니다. 모든 발견을 하나씩 보지는 않았습니다.
- "분석 미완료" 파일은 안전이 증명된 상태가 아닙니다. `archify` 의 `bin/archify.mjs` 는 위처럼 따로 확인했고, 나머지 스킬의 분석 미완료 파일(대부분 참조 문서)은 따로 보지 않았습니다.
- 공급망 검사(SC4)는 OSV.dev 연결에 실패해 오프라인 목록만 썼습니다(`archify` 결과에서 확인). 의존성 취약점 확인은 불완전합니다.
