# install-skills.ps1
# Claude Code 전역 스킬 20개 · 플러그인 7개 일괄 설치 스크립트
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
#
# 옵션 설명:
#   -g              전역(~/.claude/skills)에 설치
#   -y              프롬프트 자동 확인
#   -a claude-code  대상 에이전트를 Claude Code로 지정
#
# 한 줄이 실패해도 중단하지 않는다. 실패한 항목은 끝에 모아서 보여주고,
# 하나라도 실패하면 종료 코드 1로 끝난다.

$ErrorActionPreference = 'Continue'
$failed = @()

# 명령 한 줄을 실행하고, 실패하면 기록만 하고 넘어간다.
# -AllowFailure: 실패가 정상인 단계(이미 등록된 마켓플레이스 등)는 집계하지 않는다.
function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Action,
        [switch]$AllowFailure
    )
    $global:LASTEXITCODE = 0
    try {
        & $Action 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
            $script:failed += "$Label  (종료 코드 $LASTEXITCODE)"
        }
    } catch {
        if (-not $AllowFailure) { $script:failed += "$Label  ($($_.Exception.Message))" }
    }
}

# ---------------------------------------------------------------------------
# 제거 대상 스킬
# ---------------------------------------------------------------------------
# 보안 점검에서 걸러낸 스킬이다. 예전 버전의 이 스크립트로 설치한 PC에도
# 남아 있을 수 있어, 설치 전에 먼저 지운다. 없으면 조용히 넘어간다.
#   code-reviewer     — Gen 감사 CRITICAL
#   deploy-to-vercel  — 프로젝트 소스를 외부 엔드포인트로 업로드하는 경로
#   find-skills       — npx skills add 로 제3자 저장소 코드 설치를 유도하는 공급망 진입점
$removeSkills = @('code-reviewer', 'deploy-to-vercel', 'find-skills')

# 스킬은 ~/.claude/skills 뿐 아니라 ~/.agents/skills 에도 설치된다.
# (find-skills 는 .agents 쪽에만 있어서 .claude 만 보면 영영 못 찾는다.)
$skillRoots = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.agents\skills')
)

Write-Host '제거 대상 스킬을 확인합니다...' -ForegroundColor Cyan
$toRemove = @($removeSkills | Where-Object {
    $name = $_
    @($skillRoots | Where-Object { Test-Path (Join-Path $_ "$name\SKILL.md") }).Count -gt 0
})
if ($toRemove.Count -gt 0) {
    Write-Host "  제거: $($toRemove -join ', ')" -ForegroundColor Yellow
    # npx skills remove 는 스킬 디렉터리를 지운다.
    # -g 필수: 없으면 현재 폴더(프로젝트 범위)만 보고 전역 스킬은 못 지운다.
    # -y: 확인 프롬프트에서 멈추지 않게 한다.
    Invoke-Step -Label "스킬 제거 ($($toRemove -join ', '))" -Action { npx skills remove $toRemove -g -y }

    # 종료 코드만 믿지 않고 폴더가 실제로 사라졌는지 확인한다.
    foreach ($name in $toRemove) {
        $left = @($skillRoots | ForEach-Object { Join-Path $_ $name } | Where-Object { Test-Path $_ })
        if ($left.Count -gt 0) {
            Write-Host "  남아 있음: $($left -join ', ')" -ForegroundColor Red
            $failed += "스킬 제거 확인 ($name): 폴더가 남아 있음 — $($left -join ', ')"
        } else {
            Write-Host "  제거 확인: $name" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host '  제거할 스킬이 없습니다.' -ForegroundColor DarkGray
}

# 디렉터리는 지워졌지만 록 파일에 엔트리만 남은 경우를 정리한다.
# 남겨두면 `npx skills update` 가 제거한 스킬을 다시 끌어온다.
$lockPath = Join-Path $HOME '.agents\.skill-lock.json'
if (Test-Path $lockPath) {
    try {
        $lock = Get-Content $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $stale = @($removeSkills | Where-Object { $lock.skills.PSObject.Properties.Name -contains $_ })
        if ($stale.Count -gt 0) {
            foreach ($name in $stale) { $lock.skills.PSObject.Properties.Remove($name) }
            # BOM 없이 써야 한다 — skills CLI 가 JSON.parse 로 읽는다.
            $json = $lock | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($lockPath, $json, (New-Object System.Text.UTF8Encoding $false))
            Write-Host "  록 파일에서 제거: $($stale -join ', ')" -ForegroundColor Yellow
        }
    } catch {
        $failed += "록 파일 정리 ($lockPath): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 스킬 설치
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Claude Code 스킬 20개 설치를 시작합니다...' -ForegroundColor Cyan

# --- Anthropic 공식 (anthropics/skills) ---
Invoke-Step -Label 'mcp-builder'    -Action { npx skills add anthropics/skills --skill mcp-builder -g -y -a claude-code }
Invoke-Step -Label 'skill-creator'  -Action { npx skills add anthropics/skills --skill skill-creator -g -y -a claude-code }
Invoke-Step -Label 'webapp-testing' -Action { npx skills add anthropics/skills --skill webapp-testing -g -y -a claude-code }

# --- Vercel (vercel-labs) ---
Invoke-Step -Label 'agent-browser'                -Action { npx skills add vercel-labs/agent-browser --skill agent-browser -g -y -a claude-code }
Invoke-Step -Label 'vercel-react-best-practices'  -Action { npx skills add vercel-labs/agent-skills --skill vercel-react-best-practices -g -y -a claude-code }
Invoke-Step -Label 'web-design-guidelines'        -Action { npx skills add vercel-labs/agent-skills --skill web-design-guidelines -g -y -a claude-code }

# --- 커뮤니티 ---
Invoke-Step -Label 'brainstorming'         -Action { npx skills add obra/superpowers --skill brainstorming -g -y -a claude-code }
Invoke-Step -Label 'prompt-engineer'       -Action { npx skills add jeffallan/claude-skills --skill prompt-engineer -g -y -a claude-code }
Invoke-Step -Label 'design-taste-frontend' -Action { npx skills add leonxlnx/taste-skill --skill design-taste-frontend -g -y -a claude-code }
Invoke-Step -Label 'image-to-code'         -Action { npx skills add leonxlnx/taste-skill --skill image-to-code -g -y -a claude-code }
Invoke-Step -Label 'accessibility-compliance' -Action { npx skills add wshobson/agents --skill accessibility-compliance -g -y -a claude-code }
Invoke-Step -Label 'design-md'             -Action { npx skills add nexu-io/open-design --skill design-md -g -y -a claude-code }
Invoke-Step -Label 'ux-heuristics'         -Action { npx skills add wondelai/skills --skill ux-heuristics -g -y -a claude-code }
Invoke-Step -Label 'handoff'               -Action { npx skills add mattpocock/skills --skill handoff -g -y -a claude-code }
Invoke-Step -Label 'grill-with-docs'       -Action { npx skills add mattpocock/skills --skill grill-with-docs -g -y -a claude-code }
Invoke-Step -Label 'tdd'                   -Action { npx skills add mattpocock/skills --skill tdd -g -y -a claude-code }
Invoke-Step -Label 'diagnosing-bugs'       -Action { npx skills add mattpocock/skills --skill diagnosing-bugs -g -y -a claude-code }
Invoke-Step -Label 'archify'               -Action { npx skills add tt-a1i/archify --skill archify -g -y -a claude-code }
Invoke-Step -Label 'archify-review'        -Action { npx skills add tt-a1i/archify --skill archify-review -g -y -a claude-code }
Invoke-Step -Label 'impeccable'            -Action { npx skills add pbakaus/impeccable --skill impeccable -g -y -a claude-code }

# ---------------------------------------------------------------------------
# 플러그인
# ---------------------------------------------------------------------------
# 마켓플레이스를 먼저 **전부** 등록하고, 그다음에 설치한다. 새 PC 에는 마켓이
# 등록돼 있지 않아 순서가 뒤집히면 install 이 실패한다.
# 이미 등록된 마켓은 오류를 내므로 -AllowFailure 로 집계에서 뺀다.
Write-Host ''
Write-Host '플러그인 마켓플레이스를 등록합니다...' -ForegroundColor Cyan

Invoke-Step -AllowFailure -Label '마켓 anthropics/claude-plugins-official' -Action { claude plugin marketplace add anthropics/claude-plugins-official }
Invoke-Step -AllowFailure -Label '마켓 epoko77-ai/im-not-ai'               -Action { claude plugin marketplace add epoko77-ai/im-not-ai }
Invoke-Step -AllowFailure -Label '마켓 DietrichGebert/ponytail'            -Action { claude plugin marketplace add DietrichGebert/ponytail }
Invoke-Step -AllowFailure -Label '마켓 thedotmack/claude-mem'              -Action { claude plugin marketplace add thedotmack/claude-mem }
Invoke-Step -AllowFailure -Label '마켓 f/prompts.chat'                     -Action { claude plugin marketplace add f/prompts.chat }
Invoke-Step -AllowFailure -Label '마켓 JuliusBrussee/caveman'              -Action { claude plugin marketplace add JuliusBrussee/caveman }

Write-Host ''
Write-Host '플러그인 7개 설치를 시작합니다...' -ForegroundColor Cyan

Invoke-Step -Label 'vercel@claude-plugins-official'            -Action { claude plugin install vercel@claude-plugins-official }
Invoke-Step -Label 'humanize-korean@im-not-ai'                 -Action { claude plugin install humanize-korean@im-not-ai }
Invoke-Step -Label 'ponytail@ponytail'                         -Action { claude plugin install ponytail@ponytail }
Invoke-Step -Label 'claude-mem@thedotmack'                     -Action { claude plugin install claude-mem@thedotmack }
Invoke-Step -Label 'prompts.chat@prompts.chat'                 -Action { claude plugin install prompts.chat@prompts.chat }
Invoke-Step -Label 'claude-code-setup@claude-plugins-official' -Action { claude plugin install claude-code-setup@claude-plugins-official }
Invoke-Step -Label 'caveman@caveman'                           -Action { claude plugin install caveman@caveman }

# ---------------------------------------------------------------------------
# 결과
# ---------------------------------------------------------------------------
Write-Host ''
if ($failed.Count -eq 0) {
    Write-Host '설치 완료. 전부 성공했습니다.' -ForegroundColor Green
} else {
    Write-Host "설치 완료. 실패 $($failed.Count)건:" -ForegroundColor Red
    foreach ($f in $failed) { Write-Host "  - $f" -ForegroundColor Yellow }
    Write-Host '  해당 줄만 다시 실행하면 됩니다.' -ForegroundColor DarkGray
}
Write-Host "확인: Get-ChildItem $HOME\.claude\skills / claude plugin list" -ForegroundColor Green
if ($failed.Count -gt 0) { exit 1 }
