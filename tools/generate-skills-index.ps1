#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackRoot = Split-Path -Parent $PSScriptRoot
$SkillsRoot = Join-Path $PackRoot 'repo-template/.agents/skills'
$Output = Join-Path $PackRoot 'SKILLS-INDEX.md'

if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
    throw "Missing skills root: $SkillsRoot"
}

function Get-FrontmatterValue {
    param([string]$Content, [string]$Key)
    $match = [regex]::Match($Content, "(?ms)\A---\s*\r?\n(.*?)\r?\n---")
    if (-not $match.Success) { return '' }
    $line = [regex]::Match($match.Groups[1].Value, "(?m)^$([regex]::Escape($Key)):\s*(.+?)\r?$")
    if ($line.Success) { return $line.Groups[1].Value.Trim() }
    return ''
}

$rows = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $SkillsRoot -Directory | Sort-Object Name | ForEach-Object {
    $skill = Join-Path $_.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skill -PathType Leaf)) { return }
    $content = Get-Content -LiteralPath $skill -Raw
    $name = Get-FrontmatterValue $content 'name'
    if (-not $name) { $name = $_.Name }
    $description = Get-FrontmatterValue $content 'description'
    if (-not $description) { $description = 'ver SKILL.md' }
    $required = Get-FrontmatterValue $content 'input'
    if (-not $required) { $required = Get-FrontmatterValue $content 'entrada' }
    if (-not $required) { $required = Get-FrontmatterValue $content 'required-input' }
    if (-not $required) { $required = 'ver SKILL.md' }
    $rows.Add([pscustomobject]@{ Name = $name; Description = $description; Input = $required }) | Out-Null
}

function Escape-Cell([string]$Value) { return ($Value -replace '\|', '\|') }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Índice de skills — Engineering Flow 3.0') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('Gerado por `tools/generate-skills-index.sh` a partir do frontmatter `name`/`description` de `repo-template/.agents/skills/*/SKILL.md`. O Grok Build lê este índice e carrega apenas a skill escolhida.') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Nome | Quando usar | Entrada exigida |') | Out-Null
$lines.Add('|---|---|---|') | Out-Null
foreach ($row in ($rows | Sort-Object Name)) {
    $lines.Add(('| {0} | {1} | {2} |' -f (Escape-Cell $row.Name), (Escape-Cell $row.Description), (Escape-Cell $row.Input))) | Out-Null
}
$lines.Add('') | Out-Null
[IO.File]::WriteAllText($Output, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $Output ($($rows.Count) skills)."
