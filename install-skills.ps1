# install-skills.ps1
# Claude Code 전역 스킬 22개 · 플러그인 8개 · MCP 1개 · 도구 5개 일괄 설치 스크립트
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\install-skills.ps1
#   powershell -ExecutionPolicy Bypass -File .\install-skills.ps1 -WithWhisper
#     -WithWhisper: watch 플러그인의 로컬 음성 인식(WhisperX, 약 3GB)까지 설치
#
# 옵션 설명:
#   -g              전역(~/.claude/skills)에 설치
#   -y              프롬프트 자동 확인
#   -a claude-code  대상 에이전트를 Claude Code로 지정
#
# 한 줄이 실패해도 중단하지 않는다. 실패한 항목은 끝에 모아서 보여주고,
# 하나라도 실패하면 종료 코드 1로 끝난다.

param([switch]$WithWhisper)

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
# 보안 점검에서 걸러냈거나 출처 저장소에서 사라진 스킬이다. 예전 버전의 이 스크립트로
# 설치한 PC에도 남아 있을 수 있어, 설치 전에 먼저 지운다. 없으면 조용히 넘어간다.
#   code-reviewer     — Gen 감사 CRITICAL
#   deploy-to-vercel  — 프로젝트 소스를 외부 엔드포인트로 업로드하는 경로
#   find-skills       — npx skills add 로 제3자 저장소 코드 설치를 유도하는 공급망 진입점
#   image-to-code     — 출처 저장소(leonxlnx/taste-skill)에서 삭제됨
# verify-skills.ps1 이 이 줄을 정규식으로 읽는다. 한 줄 형태를 유지할 것.
$removeSkills = @('code-reviewer', 'deploy-to-vercel', 'find-skills', 'image-to-code')

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
# 도구
# ---------------------------------------------------------------------------
# skillspector: 새 스킬·플러그인을 추가하기 전에 보안 검사하는 도구 (NVIDIA)
# ffmpeg·yt-dlp·deno: watch 플러그인이 영상을 받고 장면을 뽑는 데 쓴다
# 없는 것만 설치한다. winget 은 PATH 를 현재 셸에 반영하지 않아 설치 뒤 다시 읽는다.
# verify-skills.ps1 이 아래 $requiredTools 줄을 정규식으로 읽는다. 한 줄 형태를 유지할 것.
$requiredTools = @('uv', 'ffmpeg', 'yt-dlp', 'deno', 'skillspector')
$wingetIds = @{ 'uv' = 'astral-sh.uv'; 'ffmpeg' = 'Gyan.FFmpeg'; 'yt-dlp' = 'yt-dlp.yt-dlp'; 'deno' = 'DenoLand.Deno' }

function Update-PathFromRegistry {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host ''
Write-Host '도구를 확인합니다...' -ForegroundColor Cyan

# watch 는 Python 3.10 이상이 필요하다. Microsoft Store 의 가짜 python 별칭은 여기서 걸러진다.
python -c "import sys; sys.exit(sys.version_info < (3, 10))" *> $null
if ($LASTEXITCODE -ne 0) {
    Invoke-Step -Label 'Python 3.12 (winget)' -Action { winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity }
    Update-PathFromRegistry
}

foreach ($tool in $requiredTools) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "  ${tool}: 이미 있음" -ForegroundColor DarkGray
        continue
    }
    if ($wingetIds.ContainsKey($tool)) {
        $id = $wingetIds[$tool]
        Invoke-Step -Label "$tool (winget $id)" -Action { winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity }
    } else {
        # skillspector: PyPI 에 없어 GitHub 저장소에서 바로 설치한다. uv 가 위에서 먼저 깔린다.
        Invoke-Step -Label 'skillspector (uv)' -Action { uv tool install git+https://github.com/NVIDIA/skillspector.git }
    }
    Update-PathFromRegistry
}

# ---------------------------------------------------------------------------
# 스킬 설치
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Claude Code 스킬 22개 설치를 시작합니다...' -ForegroundColor Cyan

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
Invoke-Step -Label 'supabase-postgres-best-practices' -Action { npx skills add supabase/agent-skills --skill supabase-postgres-best-practices -g -y -a claude-code }
Invoke-Step -Label 'supabase'              -Action { npx skills add supabase/agent-skills --skill supabase -g -y -a claude-code }
Invoke-Step -Label 'security-audit'        -Action { npx skills add cloudflare/security-audit-skill --skill security-audit -g -y -a claude-code }

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
Invoke-Step -AllowFailure -Label '마켓 bradautomates/claude-video'         -Action { claude plugin marketplace add bradautomates/claude-video }

Write-Host ''
Write-Host '플러그인 8개 설치를 시작합니다...' -ForegroundColor Cyan

Invoke-Step -Label 'vercel@claude-plugins-official'            -Action { claude plugin install vercel@claude-plugins-official }
Invoke-Step -Label 'humanize-korean@im-not-ai'                 -Action { claude plugin install humanize-korean@im-not-ai }
Invoke-Step -Label 'ponytail@ponytail'                         -Action { claude plugin install ponytail@ponytail }
Invoke-Step -Label 'claude-mem@thedotmack'                     -Action { claude plugin install claude-mem@thedotmack }
Invoke-Step -Label 'prompts.chat@prompts.chat'                 -Action { claude plugin install prompts.chat@prompts.chat }
Invoke-Step -Label 'claude-code-setup@claude-plugins-official' -Action { claude plugin install claude-code-setup@claude-plugins-official }
Invoke-Step -Label 'caveman@caveman'                           -Action { claude plugin install caveman@caveman }
Invoke-Step -Label 'watch@claude-video'                        -Action { claude plugin install watch@claude-video }

# --- watch 설정: 항상 로컬 엔진 ---
# 기본값 auto 는 환경변수나 작업 폴더 .env 에 GEMINI/GROQ/OPENAI 키가 있으면 영상·음성을
# 클라우드로 올린다. engine=local 로 고정하고, 음성 인식은 WhisperX(로컬) 또는 none(자막만).
# 이미 WhisperX 를 깐 PC 에서 -WithWhisper 없이 다시 돌려도 none 으로 되돌리지 않는다.
$watchSetup = Get-ChildItem "$HOME\.claude\plugins\cache\claude-video\watch\*\skills\watch\scripts\setup.py" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
if (-not $watchSetup) {
    $failed += 'watch 설정: setup.py 를 찾을 수 없음 (watch@claude-video 설치 실패?)'
} elseif ($WithWhisper -or (Test-Path "$HOME\.cache\watch\whisperx-venv\.deps-ok")) {
    Write-Host '  watch: 로컬 WhisperX 설치·설정 (처음에는 약 3GB 내려받음)' -ForegroundColor DarkGray
    Invoke-Step -Label 'watch WhisperX' -Action { python $watchSetup --install-whisperx --backend whisperx --engine local --detail balanced }
} else {
    Write-Host '  watch: 자막만 사용 (음성 인식은 -WithWhisper 로 설치)' -ForegroundColor DarkGray
    Invoke-Step -Label 'watch 설정' -Action { python $watchSetup --backend none --engine local --detail balanced }
}

# ---------------------------------------------------------------------------
# MCP (user 범위 — 모든 프로젝트에서 사용)
# ---------------------------------------------------------------------------
# API 키는 여기 넣지 않는다. 필요하면 각 PC에서 따로 설정한다.
# '--' 를 따옴표로 감싼다: Windows PowerShell 5.1 은 맨 '--' 를 지워서 claude 가 -y 를 자기 옵션으로 읽는다.
# 이미 등록돼 있으면 add 가 오류를 내므로 get 으로 먼저 확인한다.
Write-Host ''
Write-Host 'MCP 1개 등록을 확인합니다...' -ForegroundColor Cyan

claude mcp get context7 *> $null
if ($LASTEXITCODE -ne 0) {
    Invoke-Step -Label 'MCP context7' -Action { claude mcp add --scope user context7 '--' cmd /c npx -y @upstash/context7-mcp }
} else {
    Write-Host '  context7: 이미 등록됨' -ForegroundColor DarkGray
}

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
Write-Host '확인: powershell -ExecutionPolicy Bypass -File .\verify-skills.ps1  (Claude Code 재시작 후)' -ForegroundColor Green
if ($failed.Count -gt 0) { exit 1 }
