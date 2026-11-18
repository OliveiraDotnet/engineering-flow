#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CardId,
    [ValidateSet('Bug', 'Feature', 'Refactor')]
    [string]$DemandType = 'Bug',
    [int]$MaxRetries = 3,
    [string]$ImplementorCommand = $env:EF_IMPLEMENTOR_CMD,
    [string]$Harness = $env:EF_HARNESS,
    [string]$HarnessArgs = $env:EF_HARNESS_ARGS,
    [Parameter(Mandatory = $true)]
    [string]$TestCommand,
    [string]$R0RedCommand = '',
    [switch]$SkipR0Red,
    [string]$TaskSpec = '',
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir 'ef-secrets.ps1')

if (-not $Harness -and -not $ImplementorCommand) {
    [Console]::Error.WriteLine('Error: -Harness or -ImplementorCommand is required.')
    exit 2
}

$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$HarnessLogDir = if ($env:EF_HARNESS_LOG_DIR) { $env:EF_HARNESS_LOG_DIR } else { Join-Path $RepoRoot ".agent-pack/logs/$CardId" }
$loadRc = ef_load_secrets -RepoRoot $RepoRoot -HarnessLogDir $HarnessLogDir
if ($loadRc -ne 0) { exit $loadRc }

$Pwsh = (Get-Process -Id $PID).Path
$statusFile = Join-Path $RepoRoot '.agent-pack/.runtime/test-status.json'
if (Test-Path -LiteralPath $statusFile) { Remove-Item -LiteralPath $statusFile -Force }

if ($DemandType -eq 'Bug' -and -not $SkipR0Red) {
    $effectiveR0 = if ($R0RedCommand) { $R0RedCommand } else { $TestCommand }
    Write-Output '========================================================'
    Write-Output "Fase Pre-Fix: Validando R0-RED para o Card $CardId"
    Write-Output '========================================================'
    & $Pwsh -NoProfile -File (Join-Path $ScriptDir 'run-tester.ps1') `
        -CardId $CardId `
        -DemandType $DemandType `
        -Phase 'r0-red' `
        -TestCommand $effectiveR0 `
        -Repo $RepoRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$skillName = switch ($DemandType) {
    'Bug' { '$bugfix' }
    'Refactor' { '$refactor' }
    default { '$feature-slice' }
}

$attempt = 1
$success = $false
while ($attempt -le $MaxRetries) {
    Write-Output '========================================================'
    Write-Output "Ciclo de Harness: Tentativa $attempt de $MaxRetries (Card: $CardId)"
    Write-Output '========================================================'
    $env:EF_ATTEMPT = [string]$attempt

    $impArgs = @(
        '-NoProfile', '-File', (Join-Path $ScriptDir 'run-implementor.ps1'),
        '-CardId', $CardId,
        '-Skill', $skillName,
        '-Repo', $RepoRoot
    )
    if ($Harness) {
        $impArgs += @('-Harness', $Harness)
        if ($HarnessArgs) { $impArgs += @('-HarnessArgs', $HarnessArgs) }
    }
    else {
        $impArgs += @('-HarnessCommand', $ImplementorCommand)
    }
    if ($TaskSpec) { $impArgs += @('-TaskSpec', $TaskSpec) }
    & $Pwsh @impArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $Pwsh -NoProfile -File (Join-Path $ScriptDir 'run-tester.ps1') `
        -CardId $CardId `
        -DemandType $DemandType `
        -Phase 'validate' `
        -TestCommand $TestCommand `
        -Repo $RepoRoot
    $testRc = $LASTEXITCODE

    if ($testRc -eq 0) {
        $success = $true
        break
    }

    if ($testRc -eq 6) {
        [Console]::Error.WriteLine('Erro critico: SECRET_IN_LOG detectado (exit 6). Abortando supervisor imediatamente.')
        exit 6
    }

    [Console]::Error.WriteLine("Aviso: Testes falharam na tentativa $attempt. Retornando feedback para o Implementor...")
    $attempt++
}

if ($success) {
    Write-Output ''
    Write-Output '[HARNESS CONCLUIDO COM SUCESSO]'
    Write-Output "Evidencias disponiveis em: .agent-pack/evidencias/$CardId/EVIDENCIA.md"
    Write-Output 'Aguardando aprovacao humana (Gate 2) para o Implementor realizar o commit.'
    exit 0
}
else {
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine("[UNABLE_TO_VALIDATE] Limite de $MaxRetries tentativas atingido sem aprovacao nos testes para o Card $CardId.")
    exit 1
}
