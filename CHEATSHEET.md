# 사용법 치트시트

설치된 스킬 24개 · 플러그인 8개 · MCP 1개를 언제, 어떻게 부르는지 정리한 표입니다.
각 `SKILL.md` 의 `description` 과 `disable-model-invocation`, 플러그인의 `hooks` 설정을 직접 확인해 만들었습니다(2026-11-16).

## 분류

| 분류 | 뜻 | 부르는 법 |
| --- | --- | --- |
| ① 자동 작동 | 요청 내용이 `description` 과 맞으면 Claude 가 알아서 꺼내 씁니다 | 평소처럼 말하면 됨. 확실히 쓰게 하려면 `/이름` |
| ② 명령어로만 작동 | `disable-model-invocation: true` — Claude 가 스스로 꺼내지 않습니다 | 반드시 `/이름` 으로 직접 부름 |
| ③ 항상 켜짐(훅) | 세션 시작·프롬프트 입력 같은 때마다 자동으로 실행됩니다 | 따로 부를 필요 없음 |

플러그인 안의 스킬은 `/플러그인:스킬` 형태로 부릅니다(예: `/watch:watch`, `/ponytail:ponytail-review`).

## 스킬 (24개)

| 이름 | 분류 | 언제 쓰나 | 부르는 법 |
| --- | --- | --- | --- |
| grill-with-docs | ② 명령어 | 계획·설계를 집요하게 캐물어 다듬고 ADR·용어집까지 만들 때 | `/grill-with-docs 이 결제 기능 설계 검토해줘` |
| grilling | ① 자동 | 계획·결정을 집요하게 캐물어 검증할 때 (grill-with-docs 가 내부에서 부름) | "이 계획 grill 해줘" · `/grilling` |
| domain-modeling | ① 자동 | 용어집(GLOSSARY.md)·ADR 을 쓰거나 고칠 때 (grill-with-docs 가 내부에서 부름) | "이 용어 GLOSSARY.md 에 정리해줘" · `/domain-modeling` |
| handoff | ② 명령어 | 대화를 요약해 다른 세션·에이전트에 넘길 인수인계 문서를 만들 때 | `/handoff` |
| accessibility-compliance | ① 자동 | WCAG 2.2 접근성 점검, ARIA·스크린리더 대응 | "이 폼 접근성 점검해줘" · `/accessibility-compliance` |
| agent-browser | ① 자동 | 웹사이트 열기·클릭·폼 입력·스크린샷 등 브라우저 자동화 | "이 사이트 열어서 로그인 화면 스크린샷 찍어줘" · `/agent-browser` |
| archify | ① 자동 | 아키텍처·워크플로·시퀀스·ERD 등 다이어그램을 HTML로 만들 때 | "이 저장소 구조 다이어그램으로 그려줘" · `/archify` |
| archify-review | ① 자동 | Archify 이슈·PR·코드를 가치·비용·영향으로 리뷰 | "이 archify PR 리뷰해줘" · `/archify-review` |
| brainstorming | ① 자동 | 새 기능·컴포넌트·계획 등 무언가를 새로 만들기 전 아이디어 정리 | "새 대시보드 기능 아이디어 같이 잡아보자" · `/brainstorming` |
| design-md | ① 자동 | 디자인 방향·토큰·시각 규칙을 DESIGN.md 로 정리할 때 | "우리 디자인 규칙 DESIGN.md 로 만들어줘" · `/design-md` |
| design-taste-frontend | ① 자동 | 회사·제품·랜딩 페이지를 "AI 티" 안 나게 만들거나 다듬을 때 | "카페 랜딩 페이지 만들어줘" · `/design-taste-frontend` |
| diagnosing-bugs | ① 자동 | 원인을 모르는 버그·성능 저하를 단계적으로 진단할 때 | "이거 왜 느려졌는지 진단해줘" · `/diagnosing-bugs` |
| impeccable | ① 자동 | 기존 UI 디자인·리디자인·비평·감사·다듬기 | "이 대시보드 UI 다듬어줘" · `/impeccable` |
| mcp-builder | ① 자동 | 외부 API 를 연결하는 MCP 서버를 만들 때 | "노션 API 쓰는 MCP 서버 만들어줘" · `/mcp-builder` |
| prompt-engineer | ① 자동 | LLM 프롬프트 작성·개선·평가 기준 만들 때 | "이 시스템 프롬프트 개선해줘" · `/prompt-engineer` |
| security-audit | ① 자동 | 코드베이스·API 보안 질문, 취약점 리뷰, 전체 보안 감사 | "이 API 인증 부분 보안 점검해줘" · `/security-audit` |
| skill-creator | ① 자동 | 새 스킬 만들기·수정·평가 | "회의록 정리 스킬 만들어줘" · `/skill-creator` |
| supabase | ① 자동 | Supabase(Auth·Storage·Edge Functions·RLS 등) 관련 모든 작업 | "Supabase 로그인 세션이 자꾸 풀려" · `/supabase` |
| supabase-postgres-best-practices | ① 자동 | Postgres 테이블·마이그레이션·RLS·인덱스·느린 쿼리 | "주문 테이블 스키마 설계해줘" · `/supabase-postgres-best-practices` |
| tdd | ① 자동 | 테스트를 먼저 쓰고 기능 만들기·버그 고치기 | "TDD 로 이 함수 만들어줘" · `/tdd` |
| ux-heuristics | ① 자동 | 사용성 점검(닐슨 휴리스틱), "사용자가 헷갈려해" 같은 문제 | "이 회원가입 흐름 사용성 점검해줘" · `/ux-heuristics` |
| vercel-react-best-practices | ① 자동 | React·Next.js 코드 작성·리뷰 시 성능 최적화 | "이 Next.js 페이지 성능 개선해줘" · `/vercel-react-best-practices` |
| web-design-guidelines | ① 자동 | UI 코드를 웹 인터페이스 가이드라인 기준으로 리뷰 | "내 UI 가이드라인 기준으로 리뷰해줘" · `/web-design-guidelines` |
| webapp-testing | ① 자동 | 로컬 웹앱을 Playwright 로 테스트·스크린샷·로그 확인 | "로컬 서버 띄워서 버튼 동작 테스트해줘" · `/webapp-testing` |

## 플러그인 (8개)

한 플러그인 안에 여러 분류가 섞여 있으면 모두 적었습니다.

| 이름 | 분류 | 언제 쓰나 | 부르는 법 |
| --- | --- | --- | --- |
| caveman | ③ 훅 + ① 자동 + ② 명령어 | 답변을 짧게 압축(세션 시작·입력마다 켜짐). 커밋 메시지·코드 리뷰·리팩터링 등 보조 스킬 | 켜기: `/caveman:caveman` · 끄기: "stop caveman" / 더 압축: `/caveman:caveman ultra`, `/caveman:caveman wenyan`(ultracave·megacave, ② 명령어) / `/caveman:caveman-commit`, `/caveman:caveman-review` |
| claude-mem | ③ 훅 + ① 자동 | 대화 내용을 자동 저장해 다음 세션에 기억으로 불러옴(훅 9종). 과거 작업 검색·계획·실행 | "지난번에 이거 어떻게 했지?" · `/claude-mem:mem-search` / `/claude-mem:make-plan`, `/claude-mem:do` |
| ponytail | ③ 훅 + ① 자동 | 코드를 최소한으로 쓰는 모드(세션 시작·입력마다 적용) + 입력창 위 밴드 패널. 리뷰·전체 감사 | `/ponytail:ponytail lite\|full\|ultra\|off` / `/ponytail:ponytail-review`, `/ponytail:ponytail-audit` / 패널 숨김 `/ponytail:ponytail band off` |
| vercel | ③ 훅 + ① 자동 | 세션 시작 때 최신 Vercel 지식 주입. Next.js·AI SDK·배포·환경변수 등 스킬 37개, 서브에이전트 3개 | "Next.js 앱 Vercel 에 배포해줘" / `/vercel:deploy`, `/vercel:env`, `/vercel:status` |
| watch | ③ 훅 + ① 자동 | 유튜브 주소나 mp4 파일을 장면 이미지·자막·음성 인식 텍스트로 분석(훅은 세션 시작 때 설정 확인만) | `/watch:watch https://youtu.be/... 핵심 요약해줘` · `/watch:watch C:\경로\녹화.mp4 3분쯤 에러가 뭐야?` |
| humanize-korean | ① 자동 + ② 명령어 | AI 가 쓴 한글 글(보고서·메일 등)을 사람이 쓴 것처럼 윤문 | "이 메일 AI 티 안 나게 다듬어줘" / `/humanize-korean:humanize`, `/humanize-korean:humanize --strict`, `/humanize-korean:humanize-redo`(② 명령어) |
| prompts.chat | ① 자동 | prompts.chat 에서 프롬프트·스킬 검색 | "코드 리뷰용 프롬프트 찾아줘" · `/prompts.chat:prompts`, `/prompts.chat:skills` |
| claude-code-setup | ① 자동 | 코드베이스를 보고 훅·스킬·MCP 자동화 추천 | "이 프로젝트에 맞는 Claude Code 자동화 추천해줘" · `/claude-code-setup:claude-automation-recommender` |

## MCP (1개)

| 이름 | 분류 | 언제 쓰나 | 부르는 법 |
| --- | --- | --- | --- |
| context7 | ① 자동 | 라이브러리·프레임워크·SDK 의 최신 공식 문서가 필요할 때 | "context7 으로 Next.js 16 캐시 문서 찾아서 알려줘" |

플러그인이 함께 등록하는 MCP 도 있습니다: vercel(`vercel`), claude-mem(`mcp-search`), prompts.chat(`prompts.chat`). 해당 플러그인을 쓰면 같이 쓰입니다.

## 참고

- ① 자동 작동은 Claude 가 `description` 을 보고 고르기 때문에, 비슷한 스킬이 여럿이면 원하는 것과 다른 스킬을 쓸 수 있습니다. 확실히 하려면 `/이름` 으로 부르세요.
- `/이름` 으로 부를 때 뒤에 하고 싶은 일을 한 문장으로 붙이면 바로 시작합니다.
- 보안 검사 결과는 [security-scan.md](security-scan.md) 에 있습니다.
