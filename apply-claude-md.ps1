# apply-claude-md.ps1
# 저장소의 claude-md\*.md 를 전역 CLAUDE.md(~/.claude/CLAUDE.md)에 넣거나 갱신한다.
#
# 각 파일은 아래 표시 사이에 들어간다. 표시 사이만 교체하고 그 밖의 내용은 건드리지 않는다.
#   <!-- claude-skills-setup:<파일이름> BEGIN -->
#   ...
#   <!-- claude-skills-setup:<파일이름> END -->
# 표시가 없으면 파일 끝에 붙인다. 바꾸기 전 원본을 CLAUDE.md.bak 으로 남긴다.
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\apply-claude-md.ps1
#   install-skills.ps1 이 자동으로 부른다.

[CmdletBinding()]
param(
    [string]$Target = (Join-Path $HOME '.claude\CLAUDE.md')
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$utf8 = New-Object System.Text.UTF8Encoding $false   # BOM 없이: CLAUDE.md 원래 형식 유지

$text = ''
if (Test-Path $Target) { $text = [System.IO.File]::ReadAllText($Target, $utf8).TrimStart([char]0xFEFF) }
$original = $text

foreach ($file in (Get-ChildItem (Join-Path $root 'claude-md') -Filter *.md | Sort-Object Name)) {
    $id = $file.BaseName
    $begin = "<!-- claude-skills-setup:$id BEGIN -->"
    $end = "<!-- claude-skills-setup:$id END -->"
    $body = [System.IO.File]::ReadAllText($file.FullName, $utf8).TrimStart([char]0xFEFF).Replace("`r`n", "`n").Trim()
    $block = "$begin`n$body`n$end"

    $pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
    if ([regex]::IsMatch($text, $pattern)) {
        # 치환 문자열의 $ 가 그룹 참조로 읽히지 않게 MatchEvaluator 로 넣는다.
        $text = [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block }, 'None')
        Write-Host "  CLAUDE.md: '$id' 구역 갱신" -ForegroundColor DarkGray
    } else {
        $sep = if ($text.Length -eq 0) { '' } elseif ($text.EndsWith("`n")) { "`n" } else { "`n`n" }
        $text = $text + $sep + $block + "`n"
        Write-Host "  CLAUDE.md: '$id' 구역 추가" -ForegroundColor DarkGray
    }
}

if ($text -ceq $original) {
    Write-Host '  CLAUDE.md: 이미 최신' -ForegroundColor DarkGray
    exit 0
}

New-Item -ItemType Directory -Force (Split-Path -Parent $Target) | Out-Null
if (Test-Path $Target) { Copy-Item $Target "$Target.bak" -Force }
# 임시 파일에 다 쓴 뒤 바꿔치기: 중간에 실패해도 원본이 반쯤 잘리지 않는다.
$tmp = "$Target.tmp"
[System.IO.File]::WriteAllText($tmp, $text, $utf8)
Move-Item $tmp $Target -Force
Write-Host "  CLAUDE.md 저장: $Target (이전 내용: $Target.bak)" -ForegroundColor DarkGray
