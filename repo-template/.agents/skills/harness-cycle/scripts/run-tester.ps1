#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CardId,
    [ValidateSet('Bug', 'Feature', 'Refactor')]
    [string]$DemandType = 'Feature',
    [ValidateSet('r0-red', 'validate')]
    [string]$Phase = 'validate',
    [string]$TestCommand = $env:EF_TEST_CMD,
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $TestCommand) {
    [Console]::Error.WriteLine('Error: -TestCommand is required.')
    exit 2
}

$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$EvidenceDir = Join-Path $RepoRoot ".agent-pack/evidencias/$CardId"
$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

$timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Output "==> [TESTER] Validando Card $CardId (Tipo: $DemandType, Fase: $Phase)..."

Push-Location $RepoRoot
try {
    $outputLines = & pwsh -NoProfile -Command $TestCommand 2>&1
    $testExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $testOutput = ($outputLines | Out-String).TrimEnd()
}
catch {
    $testExitCode = if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { [int]$LASTEXITCODE } else { 1 }
    $testOutput = ($_ | Out-String).TrimEnd()
}
finally {
    Pop-Location
}

if ($Phase -eq 'r0-red') {
    $r0RedFile = Join-Path $EvidenceDir 'r0-red.log'
    [IO.File]::WriteAllText($r0RedFile, $testOutput + "`n", $Utf8NoBom)
    if ($testExitCode -ne 0) {
        Write-Output "==> [TESTER] R0-RED confirmado (teste falhou antes da correcao com exit $testExitCode)."
        exit 0
    }
    [Console]::Error.WriteLine('==> [TESTER] ERRO R0-RED: o teste de regressao passou antes da correcao (exit 0). O R0 deve falhar antes do fix.')
    exit 2
}

$passed = ($testExitCode -eq 0)
$statusLabel = if ($passed) { 'APROVADO (GREEN)' } else { 'FALHA (RED)' }
$evidenceFile = Join-Path $EvidenceDir 'EVIDENCIA.md'
$r0Section = ''
if ($DemandType -eq 'Bug') {
    $r0RedLog = Join-Path $EvidenceDir 'r0-red.log'
    if (Test-Path -LiteralPath $r0RedLog -PathType Leaf) {
        $r0Content = (Get-Content -LiteralPath $r0RedLog -Raw).TrimEnd()
        $r0Section = "## Comprovacao R0-RED (Falha Antes do Fix)`n``````text`n$r0Content`n```````n`n"
    }
    else {
        $r0Section = "## Comprovacao R0-RED`n- Status: Nao registrado ou dispensado explicitamente no Gate 1.`n`n"
    }
}

$markdown = @"
# Evidencia de Testes — Card $CardId

- **Tipo de Demanda:** $DemandType
- **Data/Hora (UTC):** $timestamp
- **Comando Executado:** ``$TestCommand``
- **Codigo de Saida:** ``$testExitCode``
- **Status Final:** $statusLabel

${r0Section}## Output da Validacao ($Phase)
``````text
$testOutput
``````
"@
[IO.File]::WriteAllText($evidenceFile, $markdown + "`n", $Utf8NoBom)

$statusObj = [ordered]@{
    cardId       = $CardId
    demandType   = $DemandType
    phase        = $Phase
    passed       = $passed
    exitCode     = $testExitCode
    evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
    timestamp    = $timestamp
}
[IO.File]::WriteAllText((Join-Path $RuntimeDir 'test-status.json'), (($statusObj | ConvertTo-Json) + "`n"), $Utf8NoBom)

if ($passed) {
    Write-Output "==> [TESTER] Testes passaram com sucesso. Evidencia pronta para Gate 2 em $evidenceFile."
    exit 0
}
else {
    [Console]::Error.WriteLine("==> [TESTER] Testes falharam (exit $testExitCode). Feedback salvo para o Implementor.")
    exit 2
}
