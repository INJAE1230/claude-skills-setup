# install-skills.ps1
# Claude Code 전역 스킬 일괄 설치 스크립트 (총 11개)
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
#
# 옵션 설명:
#   -g              전역(~/.claude/skills)에 설치
#   -y              프롬프트 자동 확인
#   -a claude-code  대상 에이전트를 Claude Code로 지정

Write-Host "Claude Code 스킬 11개 설치를 시작합니다..." -ForegroundColor Cyan

# --- Anthropic 공식 (anthropics/skills) ---
npx skills add anthropics/skills --skill mcp-builder -g -y -a claude-code
npx skills add anthropics/skills --skill skill-creator -g -y -a claude-code
npx skills add anthropics/skills --skill webapp-testing -g -y -a claude-code

# --- Vercel (vercel-labs) ---
npx skills add vercel-labs/agent-browser --skill agent-browser -g -y -a claude-code
npx skills add vercel-labs/agent-skills --skill vercel-react-best-practices -g -y -a claude-code
npx skills add vercel-labs/agent-skills --skill web-design-guidelines -g -y -a claude-code
npx skills add vercel-labs/agent-skills --skill deploy-to-vercel -g -y -a claude-code

# --- 커뮤니티 ---
npx skills add obra/superpowers --skill brainstorming -g -y -a claude-code
npx skills add jeffallan/claude-skills --skill code-reviewer -g -y -a claude-code
npx skills add jeffallan/claude-skills --skill prompt-engineer -g -y -a claude-code
npx skills add leonxlnx/taste-skill --skill design-taste-frontend -g -y -a claude-code

Write-Host "설치 완료. 확인: Get-ChildItem $HOME\.claude\skills" -ForegroundColor Green
