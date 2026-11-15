# verify-skills.ps1
# install-skills.ps1 / README.md 와 실제 설치된 스킬(~/.claude/skills)·플러그인(~/.claude/plugins)·MCP(user 범위)·도구(PATH)가
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

# 제거 대상 목록($removeSkills = @(...)) — 이 스킬들은 "스크립트에 추가하라"고 안내하면 안 된다.
$removeNames = @()
$rm = [regex]::Match((Get-Content $ScriptPath -Raw -Encoding UTF8), '(?m)^\s*\$removeSkills\s*=\s*@\((?<list>[^)]*)\)')
if ($rm.Success) {
    $removeNames = @([regex]::Matches($rm.Groups['list'].Value, "'(?<n>[^']+)'") | ForEach-Object { $_.Groups['n'].Value })
}

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
$leftover = @($installed | Where-Object { $removeNames -contains $_ })
if ($leftover.Count -gt 0) {
    $problems += $leftover.Count
    Write-Section "[제거 대상] 지워야 할 스킬이 남아 있음 ($($leftover.Count)개) — 스크립트에 다시 추가하지 말 것"
    foreach ($name in $leftover) { Write-Host "  - $name" -ForegroundColor Yellow }
    Write-Host '  install-skills.ps1 을 다시 실행하면 폴더와 록 파일 엔트리까지 지운다.' -ForegroundColor DarkGray
}

$missingFromScript = @($installed | Where-Object { -not $declared.ContainsKey($_) -and $removeNames -notcontains $_ })
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

# --- 8. MCP ---
# 선언: `claude mcp add --scope user <이름> ...` · 실제: `claude mcp get <이름>` 종료 코드
# ~/.claude.json 을 직접 읽지 않는다 — 대소문자만 다른 경로 키가 있으면 PS 5.1 ConvertFrom-Json 이 실패한다.
# shortcut: 등록됐지만 스크립트에 없는 MCP 는 잡지 않는다(claude.ai·플러그인 MCP 와 섞여 나옴). MCP 가 늘면 claude mcp list 파싱 추가.
$declaredMcp = @()
foreach ($line in (Get-Content $ScriptPath -Encoding UTF8)) {
    if ($line -match '^\s*#') { continue }
    $m = [regex]::Match($line, 'claude\s+mcp\s+add\s+--scope\s+user\s+(?<name>[^\s'']+)')
    if ($m.Success) { $declaredMcp += $m.Groups['name'].Value }
}
$declaredMcp = @($declaredMcp | Sort-Object -Unique)

# 'Stop' 아래에서는 PS 5.1 이 네이티브 명령의 stderr 를 예외로 바꿔 스크립트가 멈춘다. 여기서만 Continue.
$mcpMissing = @($declaredMcp | Where-Object { $ErrorActionPreference = 'Continue'; claude mcp get $_ *> $null; $LASTEXITCODE -ne 0 })
Write-Host "MCP 선언: $($declaredMcp.Count)개 / 등록: $($declaredMcp.Count - $mcpMissing.Count)개"
if ($mcpMissing.Count -gt 0) {
    $problems += $mcpMissing.Count
    Write-Section "[미등록] install-skills.ps1에 있지만 등록되지 않은 MCP ($($mcpMissing.Count)개)"
    foreach ($n in $mcpMissing) { Write-Host "  - $n" -ForegroundColor Yellow }
}

if (Test-Path $ReadmePath) {
    # MCP 표는 '## 설치되는 MCP' 섹션 안의 표 첫 칸
    $mcpTable = @()
    $inMcp = $false
    foreach ($line in (Get-Content $ReadmePath -Encoding UTF8)) {
        if ($line -match '^##\s') { $inMcp = $line -match '^##\s+설치되는 MCP'; continue }
        if (-not $inMcp) { continue }
        $m = [regex]::Match($line, '^\|\s*(?<name>[^\s|`-][^\s|`]*)\s*\|')
        if ($m.Success -and $m.Groups['name'].Value -ne 'MCP') { $mcpTable += $m.Groups['name'].Value }
    }
    $mcpReadmeMissing = @($declaredMcp | Where-Object { $mcpTable -notcontains $_ })
    $mcpReadmeExtra = @($mcpTable | Where-Object { $declaredMcp -notcontains $_ })
    if ($mcpReadmeMissing.Count -gt 0 -or $mcpReadmeExtra.Count -gt 0) {
        $problems += ($mcpReadmeMissing.Count + $mcpReadmeExtra.Count)
        Write-Section '[README] MCP 표가 스크립트와 다름'
        foreach ($n in $mcpReadmeMissing) { Write-Host "  - 표에 없음: $n" -ForegroundColor Yellow }
        foreach ($n in $mcpReadmeExtra) { Write-Host "  - 표에만 있음: $n" -ForegroundColor Yellow }
    }
    foreach ($m in [regex]::Matches((Get-Content $ReadmePath -Raw -Encoding UTF8), '설치되는 MCP \((?<n>\d+)개\)')) {
        if ([int]$m.Groups['n'].Value -ne $declaredMcp.Count) {
            $problems++
            Write-Section '[개수] 표기가 실제 개수와 다름'
            Write-Host "  - README.md  '$($m.Value)' -> MCP $($declaredMcp.Count)개" -ForegroundColor Yellow
        }
    }
}

# --- 9. 도구 ---
# 선언: install-skills.ps1 의 $requiredTools = @(...) 한 줄 · 실제: PATH 에서 찾기
$declaredTools = @()
$rt = [regex]::Match((Get-Content $ScriptPath -Raw -Encoding UTF8), '(?m)^\s*\$requiredTools\s*=\s*@\((?<list>[^)]*)\)')
if ($rt.Success) {
    $declaredTools = @([regex]::Matches($rt.Groups['list'].Value, "'(?<n>[^']+)'") | ForEach-Object { $_.Groups['n'].Value })
}
# winget 으로 막 깐 도구는 이 셸의 PATH 에 아직 없을 수 있어 레지스트리 값으로 다시 읽는다.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$toolMissing = @($declaredTools | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
Write-Host "도구 선언: $($declaredTools.Count)개 / 설치: $($declaredTools.Count - $toolMissing.Count)개"
if ($toolMissing.Count -gt 0) {
    $problems += $toolMissing.Count
    Write-Section "[미설치] install-skills.ps1에 있지만 PATH에 없는 도구 ($($toolMissing.Count)개)"
    foreach ($n in $toolMissing) { Write-Host "  - $n" -ForegroundColor Yellow }
    Write-Host '  install-skills.ps1 을 다시 실행하거나, 새 터미널에서 verify 를 다시 돌린다.' -ForegroundColor DarkGray
}
foreach ($t in @(
    @{ Path = $ScriptPath; Label = 'install-skills.ps1'; Pattern = '도구\s*(?<n>\d+)개' }
    @{ Path = $ReadmePath; Label = 'README.md';          Pattern = '설치되는 도구 \((?<n>\d+)개\)' }
)) {
    if (-not (Test-Path $t.Path)) { continue }
    foreach ($m in [regex]::Matches((Get-Content $t.Path -Raw -Encoding UTF8), $t.Pattern)) {
        if ([int]$m.Groups['n'].Value -ne $declaredTools.Count) {
            $problems++
            Write-Section '[개수] 표기가 실제 개수와 다름'
            Write-Host "  - $($t.Label)  '$($m.Value)' -> 도구 $($declaredTools.Count)개" -ForegroundColor Yellow
        }
    }
}

# --- 10. 전역 CLAUDE.md 규칙 ---
# 저장소 claude-md\*.md 가 ~/.claude/CLAUDE.md 의 표시 구역에 그대로 들어가 있는지 (apply-claude-md.ps1 과 같은 형식)
$claudeMd = Join-Path $HOME '.claude\CLAUDE.md'
$utf8 = New-Object System.Text.UTF8Encoding $false
$claudeText = if (Test-Path $claudeMd) { [System.IO.File]::ReadAllText($claudeMd, $utf8).Replace("`r`n", "`n") } else { '' }
$ruleFiles = @(Get-ChildItem (Join-Path $root 'claude-md') -Filter *.md -ErrorAction SilentlyContinue)
$ruleStale = @($ruleFiles | Where-Object {
    $body = [System.IO.File]::ReadAllText($_.FullName, $utf8).TrimStart([char]0xFEFF).Replace("`r`n", "`n").Trim()
    -not $claudeText.Contains("<!-- claude-skills-setup:$($_.BaseName) BEGIN -->`n$body`n<!-- claude-skills-setup:$($_.BaseName) END -->")
})
Write-Host "CLAUDE.md 규칙 선언: $($ruleFiles.Count)개 / 반영: $($ruleFiles.Count - $ruleStale.Count)개"
if ($ruleStale.Count -gt 0) {
    $problems += $ruleStale.Count
    Write-Section "[CLAUDE.md] 전역 CLAUDE.md에 없거나 내용이 다른 규칙 ($($ruleStale.Count)개)"
    foreach ($f in $ruleStale) { Write-Host "  - claude-md\$($f.Name)" -ForegroundColor Yellow }
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\apply-claude-md.ps1 로 반영한다.' -ForegroundColor DarkGray
}

# --- 결과 ---
Write-Host ''
if ($problems -eq 0) {
    Write-Host "일치합니다. 스킬 ${expected}개 · 플러그인 ${expectedPlugins}개 · MCP $($declaredMcp.Count)개 · 도구 $($declaredTools.Count)개가 스크립트·README·실제 설치 상태에서 모두 동일합니다." -ForegroundColor Green
    exit 0
}
Write-Host "불일치 $problems 건을 찾았습니다. 위 항목을 반영한 뒤 다시 실행하세요." -ForegroundColor Red
exit 1
