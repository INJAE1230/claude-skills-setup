# claude-skills-setup

새 PC나 새 환경에서 Claude Code 스킬을 한 번에 복구하기 위한 설치 스크립트입니다.

## 사용법

```powershell
powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
```

전역(`~/.claude/skills`)에 설치되며, Claude Code를 재시작하면 스킬 목록에 나타납니다.

## 설치되는 스킬 (11개)

| 스킬 | 출처 | 용도 |
| --- | --- | --- |
| `mcp-builder` | `anthropics/skills` | MCP 서버 제작 가이드 |
| `skill-creator` | `anthropics/skills` | 스킬 생성·개선·평가 |
| `webapp-testing` | `anthropics/skills` | Playwright 기반 웹앱 테스트 |
| `agent-browser` | `vercel-labs/agent-browser` | 브라우저 자동화 CLI |
| `vercel-react-best-practices` | `vercel-labs/agent-skills` | React/Next.js 성능 최적화 |
| `web-design-guidelines` | `vercel-labs/agent-skills` | UI 접근성·디자인 가이드라인 점검 |
| `deploy-to-vercel` | `vercel-labs/agent-skills` | Vercel 배포 |
| `brainstorming` | `obra/superpowers` | 아이디어를 설계·스펙으로 정리 |
| `code-reviewer` | `jeffallan/claude-skills` | 코드 리뷰·보안 취약점 점검 |
| `prompt-engineer` | `jeffallan/claude-skills` | 프롬프트 작성·리팩터링·평가 |
| `design-taste-frontend` | `leonxlnx/taste-skill` | 랜딩·포트폴리오 프런트엔드 디자인 |

## 참고

- 설치 후 확인: `Get-ChildItem $HOME\.claude\skills`
- 개별 스킬만 다시 설치하려면 `install-skills.ps1`에서 해당 줄만 실행하면 됩니다.
