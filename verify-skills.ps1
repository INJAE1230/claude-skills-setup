# verify-skills.ps1
# install-skills.ps1 / README.md 와 실제 설치된 스킬(~/.claude/skills)이 일치하는지 검사한다.
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\verify-skills.ps1
#
# 종료 코드:
#   0  모두 일치
#   1  불일치 (pre-commit 훅이나 CI 게이트로 그대로 쓸 수 있다)

[CmdletBinding()]
param(
    [string]$SkillsRoot,
    [string]$ScriptPath,
    [string]$ReadmePath
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot 는 param 기본값이 묶이는 시점에 비어 있을 수 있어 본문에서 정한다.
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $root) { $root = (Get-Location).Path }

if (-not $SkillsRoot) { $SkillsRoot = Join-Path $HOME '.claude\skills' }
if (-not $ScriptPath) { $ScriptPath = Join-Path $root 'install-skills.ps1' }
if (-not $ReadmePath) { $ReadmePath = Join-Path $root 'README.md' }

function Write-Section($text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Cyan
}

if (-not (Test-Path $ScriptPath)) {
    Write-Host "install-skills.ps1을 찾을 수 없습니다: $ScriptPath" -ForegroundColor Red
    exit 1
}

# --- 1. install-skills.ps1에 선언된 스킬 파싱 ---
# 한 줄에 --skill 이 여러 번 오는 형태도 처리한다.
$declared = @{}
foreach ($line in (Get-Content $ScriptPath -Encoding UTF8)) {
    if ($line -match '^\s*#') { continue }
    $cmd = [regex]::Match($line, 'npx\s+skills\s+add\s+(?<repo>[^\s-][^\s]*)')
    if (-not $cmd.Success) { continue }
    $repo = $cmd.Groups['repo'].Value
    foreach ($m in [regex]::Matches($line, '--skill\s+(?<name>[^\s]+)')) {
        $declared[$m.Groups['name'].Value] = $repo
    }
}
$declaredNames = @($declared.Keys | Sort-Object)

# --- 2. 실제 설치된 스킬 ---
# SKILL.md 가 있는 디렉터리만 스킬로 본다. 플러그인이 제공하는 스킬은
# ~/.claude/plugins 아래에 있어 여기 잡히지 않으며, 이 스크립트의 대상도 아니다.
$installed = @()
if (Test-Path $SkillsRoot) {
    $installed = @(Get-ChildItem -Path $SkillsRoot -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
        Select-Object -ExpandProperty Name |
        Sort-Object)
} else {
    Write-Host "스킬 디렉터리가 없습니다: $SkillsRoot" -ForegroundColor Yellow
}

Write-Host "스크립트 선언: $($declaredNames.Count)개 / 실제 설치: $($installed.Count)개"

$problems = 0

# --- 3. 설치됐지만 스크립트에 없는 것 ---
$missingFromScript = @($installed | Where-Object { -not $declared.ContainsKey($_) })
if ($missingFromScript.Count -gt 0) {
    $problems += $missingFromScript.Count
    Write-Section "[누락] 설치돼 있지만 install-skills.ps1에 없음 ($($missingFromScript.Count)개)"
    foreach ($name in $missingFromScript) {
        Write-Host "  - $name" -ForegroundColor Yellow
        Write-Host "      npx skills add <출처저장소> --skill $name -g -y -a claude-code" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '  출처 저장소가 기억나지 않으면 실제 실행했던 설치 명령을 찾아본다:' -ForegroundColor DarkGray
    Write-Host '      Select-String "skills add" $HOME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt' -ForegroundColor DarkGray
}

# --- 4. 스크립트에 있지만 설치 안 된 것 ---
$notInstalled = @($declaredNames | Where-Object { $installed -notcontains $_ })
if ($notInstalled.Count -gt 0) {
    $problems += $notInstalled.Count
    Write-Section "[미설치] install-skills.ps1에 있지만 설치되지 않음 ($($notInstalled.Count)개)"
    foreach ($name in $notInstalled) {
        Write-Host "  - $name  (출처: $($declared[$name]))" -ForegroundColor Yellow
    }
    Write-Host '  스크립트를 다시 실행하면 설치된다.' -ForegroundColor DarkGray
}

# --- 5. README 표와 대조 ---
if (Test-Path $ReadmePath) {
    $tableNames = @()
    foreach ($line in (Get-Content $ReadmePath -Encoding UTF8)) {
        $m = [regex]::Match($line, '^\|\s*`(?<name>[^`]+)`')
        if ($m.Success) { $tableNames += $m.Groups['name'].Value }
    }
    $tableNames = @($tableNames | Sort-Object)

    $readmeMissing = @($declaredNames | Where-Object { $tableNames -notcontains $_ })
    $readmeExtra = @($tableNames | Where-Object { $declaredNames -notcontains $_ })
    if ($readmeMissing.Count -gt 0 -or $readmeExtra.Count -gt 0) {
        $problems += ($readmeMissing.Count + $readmeExtra.Count)
        Write-Section '[README] 표가 스크립트와 다름'
        foreach ($name in $readmeMissing) {
            Write-Host "  - 표에 없음: $name  (출처: $($declared[$name]))" -ForegroundColor Yellow
        }
        foreach ($name in $readmeExtra) {
            Write-Host "  - 표에만 있음: $name" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "README.md를 찾을 수 없어 표 검사는 건너뜁니다: $ReadmePath" -ForegroundColor DarkGray
}

# --- 6. 개수 표기 대조 ---
$expected = $declaredNames.Count
$countTargets = @(
    @{ Path = $ScriptPath; Label = 'install-skills.ps1'; Pattern = '(?:총|스킬)\s*(?<n>\d+)개' }
    @{ Path = $ReadmePath; Label = 'README.md';          Pattern = '설치되는 스킬 \((?<n>\d+)개\)' }
)
$staleCounts = @()
foreach ($t in $countTargets) {
    if (-not (Test-Path $t.Path)) { continue }
    $lineNo = 0
    foreach ($line in (Get-Content $t.Path -Encoding UTF8)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $t.Pattern)) {
            if ([int]$m.Groups['n'].Value -ne $expected) {
                $staleCounts += ("{0}:{1}  '{2}' -> {3}개" -f $t.Label, $lineNo, $m.Value, $expected)
            }
        }
    }
}
if ($staleCounts.Count -gt 0) {
    $problems += $staleCounts.Count
    Write-Section "[개수] 표기가 실제 ${expected}개와 다름"
    foreach ($s in $staleCounts) { Write-Host "  - $s" -ForegroundColor Yellow }
}

# --- 결과 ---
Write-Host ''
if ($problems -eq 0) {
    Write-Host "일치합니다. 스킬 ${expected}개가 스크립트·README·실제 설치 상태에서 모두 동일합니다." -ForegroundColor Green
    exit 0
}
Write-Host "불일치 $problems 건을 찾았습니다. 위 항목을 반영한 뒤 다시 실행하세요." -ForegroundColor Red
exit 1
