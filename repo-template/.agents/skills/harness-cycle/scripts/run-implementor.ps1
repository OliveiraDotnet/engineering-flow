#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CardId,
    [string]$Skill = '$bugfix',
    [string]$TaskSpec = '',
    [string]$HarnessCommand = $env:EF_IMPLEMENTOR_CMD,
    [string]$Repo = '.',
    [switch]$CommitGate2,
    [string]$CommitMessage = '',
    [switch]$AllowUnvalidated
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$StatusFile = Join-Path $RuntimeDir 'test-status.json'
$LockFile = Join-Path $RuntimeDir 'task.lock'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

if ($CommitGate2) {
    if (-not $CommitMessage) {
        [Console]::Error.WriteLine('Error: -CommitMessage is required with -CommitGate2.')
        exit 2
    }
    $branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $branch) { $branch = '' } else { $branch = $branch.Trim() }
    if ($branch -in @('main', 'master', '')) {
        [Console]::Error.WriteLine("Error: Gate 2 commit is forbidden on branch '$branch'. Use a card branch (feat/$CardId-... or fix/$CardId-...).")
        exit 3
    }
    if (-not $AllowUnvalidated) {
        if (-not (Test-Path -LiteralPath $StatusFile -PathType Leaf)) {
            [Console]::Error.WriteLine("Error: Missing test status file ($StatusFile). Run Tester before Gate 2 commit.")
            exit 4
        }
        $statusObj = Get-Content -LiteralPath $StatusFile -Raw | ConvertFrom-Json
        if (-not $statusObj.passed) {
            [Console]::Error.WriteLine('Error: Tester report does not indicate passed=true. Gate 2 commit aborted.')
            exit 4
        }
    }
    & git -C $RepoRoot add -A
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & git -C $RepoRoot commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path -LiteralPath $LockFile) { Remove-Item -LiteralPath $LockFile -Force }
    Write-Output "[IMPLEMENTOR] Gate 2 commit completed on branch '$branch' and task.lock released."
    exit 0
}

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
$promptFile = Join-Path $RepoRoot 'prompts/12-implementor-harness.md'
$basePrompt = if (Test-Path -LiteralPath $promptFile -PathType Leaf) { Get-Content -LiteralPath $promptFile -Raw } else { '' }
$specContent = if ($TaskSpec -and (Test-Path -LiteralPath $TaskSpec -PathType Leaf)) { Get-Content -LiteralPath $TaskSpec -Raw } else { '' }

$feedbackSection = ''
if (Test-Path -LiteralPath $StatusFile -PathType Leaf) {
    $statusObj = Get-Content -LiteralPath $StatusFile -Raw | ConvertFrom-Json
    if (-not $statusObj.passed) {
        $evidenceFile = Join-Path $RepoRoot ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
        $details = if (Test-Path -LiteralPath $evidenceFile -PathType Leaf) { Get-Content -LiteralPath $evidenceFile -Raw } else { Get-Content -LiteralPath $StatusFile -Raw }
        $feedbackSection = "`n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]`n$details"
    }
}

$contextFile = Join-Path $RuntimeDir "implementor-prompt-$CardId.md"
$fullPrompt = "# Contexto de Execucao — Implementor`n- Card: $CardId`n- Skill: $Skill`n`n$basePrompt`n"
if ($specContent) { $fullPrompt += "`n## Especificacao da Tarefa`n$specContent`n" }
if ($feedbackSection) { $fullPrompt += "`n$feedbackSection`n" }
[IO.File]::WriteAllText($contextFile, $fullPrompt, $Utf8NoBom)

if (-not $HarnessCommand) {
    [Console]::Error.WriteLine('Error: No harness command provided. Pass -HarnessCommand or set EF_IMPLEMENTOR_CMD.')
    exit 2
}

Write-Output "==> [IMPLEMENTOR] Executando para o Card $CardId ($Skill)..."
$env:EF_CARD_ID = $CardId
$env:EF_SKILL = $Skill
$env:EF_PROMPT_FILE = $contextFile
Push-Location $RepoRoot
try {
    & pwsh -NoProfile -Command $HarnessCommand
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
