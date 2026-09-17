# verify-skills.ps1
# install-skills.ps1 / README.md 와 실제 설치된 스킬(~/.claude/skills)·플러그인(~/.claude/plugins)이
# 일치하는지 검사한다.
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
    [string]$ReadmePath,
    [string]$PluginsRoot
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot 는 param 기본값이 묶이는 시점에 비어 있을 수 있어 본문에서 정한다.
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $root) { $root = (Get-Location).Path }

if (-not $SkillsRoot) { $SkillsRoot = Join-Path $HOME '.claude\skills' }
if (-not $ScriptPath) { $ScriptPath = Join-Path $root 'install-skills.ps1' }
if (-not $ReadmePath) { $ReadmePath = Join-Path $root 'README.md' }
if (-not $PluginsRoot) { $PluginsRoot = Join-Path $HOME '.claude\plugins' }

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

# --- 6. 플러그인 ---
# 선언: `claude plugin install <이름>@<마켓>` · `claude plugin marketplace add <owner/repo>`
# 실제: installed_plugins.json 의 키 · known_marketplaces.json 의 이름 → 저장소
$declaredPlugins = @()
$declaredMarketRepos = @()
foreach ($line in (Get-Content $ScriptPath -Encoding UTF8)) {
    if ($line -match '^\s*#') { continue }
    $p = [regex]::Match($line, 'claude\s+plugin\s+install\s+(?<id>[^\s]+@[^\s]+)')
    if ($p.Success) { $declaredPlugins += $p.Groups['id'].Value }
    $mk = [regex]::Match($line, 'claude\s+plugin\s+marketplace\s+add\s+(?<repo>[^\s]+)')
    if ($mk.Success) { $declaredMarketRepos += $mk.Groups['repo'].Value }
}
$declaredPlugins = @($declaredPlugins | Sort-Object -Unique)

$installedPlugins = @()
$marketRepo = @{}
$pluginsJson = Join-Path $PluginsRoot 'installed_plugins.json'
$marketsJson = Join-Path $PluginsRoot 'known_marketplaces.json'
if (Test-Path $pluginsJson) {
    $installedPlugins = @((Get-Content $pluginsJson -Raw -Encoding UTF8 | ConvertFrom-Json).plugins.PSObject.Properties.Name | Sort-Object)
} else {
    Write-Host "플러그인 목록이 없습니다: $pluginsJson" -ForegroundColor Yellow
}
if (Test-Path $marketsJson) {
    foreach ($prop in (Get-Content $marketsJson -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties) {
        $marketRepo[$prop.Name] = $prop.Value.source.repo
    }
}

Write-Host "플러그인 선언: $($declaredPlugins.Count)개 / 실제 설치: $($installedPlugins.Count)개"

$pluginMissing = @($installedPlugins | Where-Object { $declaredPlugins -notcontains $_ })
if ($pluginMissing.Count -gt 0) {
    $problems += $pluginMissing.Count
    Write-Section "[누락] 설치돼 있지만 install-skills.ps1에 없는 플러그인 ($($pluginMissing.Count)개)"
    foreach ($id in $pluginMissing) {
        $market = $id.Split('@')[1]
        Write-Host "  - $id" -ForegroundColor Yellow
        if ($marketRepo.ContainsKey($market)) {
            Write-Host "      claude plugin marketplace add $($marketRepo[$market])" -ForegroundColor DarkGray
        }
        Write-Host "      claude plugin install $id" -ForegroundColor DarkGray
    }
}

$pluginNotInstalled = @($declaredPlugins | Where-Object { $installedPlugins -notcontains $_ })
if ($pluginNotInstalled.Count -gt 0) {
    $problems += $pluginNotInstalled.Count
    Write-Section "[미설치] install-skills.ps1에 있지만 설치되지 않은 플러그인 ($($pluginNotInstalled.Count)개)"
    foreach ($id in $pluginNotInstalled) { Write-Host "  - $id" -ForegroundColor Yellow }
}

# 새 PC 에서는 마켓이 등록돼 있지 않다 — `marketplace add` 줄이 빠지면 install 이 실패한다.
$marketGaps = @()
foreach ($id in $declaredPlugins) {
    $market = $id.Split('@')[1]
    if (-not $marketRepo.ContainsKey($market)) {
        $marketGaps += "$id  (마켓 '$market' 이 이 PC에 등록돼 있지 않아 저장소를 확인할 수 없음)"
    } elseif ($declaredMarketRepos -notcontains $marketRepo[$market]) {
        $marketGaps += "$id  (claude plugin marketplace add $($marketRepo[$market]) 줄이 없음)"
    }
}
if ($marketGaps.Count -gt 0) {
    $problems += $marketGaps.Count
    Write-Section '[마켓] 플러그인의 마켓플레이스 등록 줄이 없음'
    foreach ($g in $marketGaps) { Write-Host "  - $g" -ForegroundColor Yellow }
}

if (Test-Path $ReadmePath) {
    # 플러그인 표는 첫 칸이 `이름@마켓` (백틱 없음 — 백틱 줄은 위 스킬 표 검사가 가져간다)
    $pluginTable = @()
    foreach ($line in (Get-Content $ReadmePath -Encoding UTF8)) {
        $m = [regex]::Match($line, '^\|\s*(?<id>[^\s|`]+@[^\s|]+)\s*\|')
        if ($m.Success) { $pluginTable += $m.Groups['id'].Value }
    }
    $pluginReadmeMissing = @($declaredPlugins | Where-Object { $pluginTable -notcontains $_ })
    $pluginReadmeExtra = @($pluginTable | Where-Object { $declaredPlugins -notcontains $_ })
    if ($pluginReadmeMissing.Count -gt 0 -or $pluginReadmeExtra.Count -gt 0) {
        $problems += ($pluginReadmeMissing.Count + $pluginReadmeExtra.Count)
        Write-Section '[README] 플러그인 표가 스크립트와 다름'
        foreach ($id in $pluginReadmeMissing) { Write-Host "  - 표에 없음: $id" -ForegroundColor Yellow }
        foreach ($id in $pluginReadmeExtra) { Write-Host "  - 표에만 있음: $id" -ForegroundColor Yellow }
    }
}

# --- 7. 개수 표기 대조 ---
$expected = $declaredNames.Count
$expectedPlugins = $declaredPlugins.Count
$countTargets = @(
    @{ Path = $ScriptPath; Label = 'install-skills.ps1'; Pattern = '(?:총|스킬)\s*(?<n>\d+)개';        Expected = $expected;        Kind = '스킬' }
    @{ Path = $ReadmePath; Label = 'README.md';          Pattern = '설치되는 스킬 \((?<n>\d+)개\)';      Expected = $expected;        Kind = '스킬' }
    @{ Path = $ScriptPath; Label = 'install-skills.ps1'; Pattern = '플러그인\s*(?<n>\d+)개';            Expected = $expectedPlugins; Kind = '플러그인' }
    @{ Path = $ReadmePath; Label = 'README.md';          Pattern = '설치되는 플러그인 \((?<n>\d+)개\)'; Expected = $expectedPlugins; Kind = '플러그인' }
)
$staleCounts = @()
foreach ($t in $countTargets) {
    if (-not (Test-Path $t.Path)) { continue }
    $lineNo = 0
    foreach ($line in (Get-Content $t.Path -Encoding UTF8)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $t.Pattern)) {
            if ([int]$m.Groups['n'].Value -ne $t.Expected) {
                $staleCounts += ("{0}:{1}  '{2}' -> {3} {4}개" -f $t.Label, $lineNo, $m.Value, $t.Kind, $t.Expected)
            }
        }
    }
}
if ($staleCounts.Count -gt 0) {
    $problems += $staleCounts.Count
    Write-Section '[개수] 표기가 실제 개수와 다름'
    foreach ($s in $staleCounts) { Write-Host "  - $s" -ForegroundColor Yellow }
}

# --- 결과 ---
Write-Host ''
if ($problems -eq 0) {
    Write-Host "일치합니다. 스킬 ${expected}개 · 플러그인 ${expectedPlugins}개가 스크립트·README·실제 설치 상태에서 모두 동일합니다." -ForegroundColor Green
    exit 0
}
Write-Host "불일치 $problems 건을 찾았습니다. 위 항목을 반영한 뒤 다시 실행하세요." -ForegroundColor Red
exit 1
