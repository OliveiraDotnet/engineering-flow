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
    [string]$TestLabel = '',
    [string]$Harness = $env:EF_HARNESS,
    [string]$HarnessArgs = $env:EF_HARNESS_ARGS,
    [string]$HarnessCommand = $env:EF_TESTER_CMD,
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir 'ef-secrets.ps1')

if (-not $TestCommand) {
    [Console]::Error.WriteLine('Error: -TestCommand is required.')
    exit 2
}

$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$EvidenceDir = Join-Path $RepoRoot ".agent-pack/evidencias/$CardId"
$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$HarnessLogDir = if ($env:EF_HARNESS_LOG_DIR) { $env:EF_HARNESS_LOG_DIR } else { Join-Path $RepoRoot ".agent-pack/logs/$CardId" }
$EvidenceFile = Join-Path $EvidenceDir 'EVIDENCIA.md'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Pwsh = (Get-Process -Id $PID).Path

$loadRc = ef_load_secrets -RepoRoot $RepoRoot -HarnessLogDir $HarnessLogDir
if ($loadRc -ne 0) { exit $loadRc }

if ($Phase -eq 'validate') {
    $markerRc = ef_validate_evidence_markers $EvidenceFile
    if ($markerRc -ne 0) { exit $markerRc }
}

$parsedHargs = @(ef_split_args $HarnessArgs)
$harnessFlagNames = ef_extract_flag_names $parsedHargs

if ($Harness) {
    switch ($Harness) {
        'agy' {
            $effRc = ef_check_agy_effort $parsedHargs
            if ($effRc -ne 0) { exit $effRc }
        }
        'claude' { }
        'grok' {
            if ($parsedHargs.Count -eq 0) {
                [Console]::Error.WriteLine('Error: -Harness grok requires explicit -HarnessArgs.')
                exit 2
            }
        }
        default {
            [Console]::Error.WriteLine("Error: Unknown -Harness '$Harness'. Allowed: agy, claude, grok.")
            exit 2
        }
    }
}

New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
New-Item -ItemType Directory -Path $HarnessLogDir -Force | Out-Null

$attempt = if ($env:EF_ATTEMPT) { $env:EF_ATTEMPT } else { '1' }

if ($Harness -or $HarnessCommand) {
    $promptFile = Join-Path $RepoRoot 'prompts/13-tester-harness.md'
    $basePrompt = if (Test-Path -LiteralPath $promptFile -PathType Leaf) { Get-Content -LiteralPath $promptFile -Raw } else { '' }
    $rawTesterPrompt = "# Contexto de Execucao — Tester`n- Card: $CardId`n- DemandType: $DemandType`n- Phase: $Phase`n`n$basePrompt`n"
    $tmpMaskCnt = 0
    $maskedTesterPrompt = ef_mask_string -Text $rawTesterPrompt -CountRef ([ref]$tmpMaskCnt)
    $testerPromptFile = Join-Path $RuntimeDir "tester-prompt-$CardId.md"
    [IO.File]::WriteAllText($testerPromptFile, $maskedTesterPrompt, $Utf8NoBom)

    $env:EF_CARD_ID = $CardId
    $env:EF_PHASE = $Phase
    $env:EF_PROMPT_FILE = $testerPromptFile

    $stdoutLog = Join-Path $HarnessLogDir "${CardId}_tester_attempt${attempt}.jsonl"
    $stderrLog = Join-Path $HarnessLogDir "${CardId}_tester_attempt${attempt}.err"

    $binPath = $null
    $cliArgs = @()
    if ($Harness) {
        $cmdInfo = Get-Command "$Harness.ps1" -CommandType ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmdInfo) { $cmdInfo = Get-Command $Harness -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if (-not $cmdInfo) {
            [Console]::Error.WriteLine("Error: Harness CLI '$Harness' not found on PATH.")
            exit 2
        }
        $binPath = $cmdInfo.Source
        switch ($Harness) {
            'agy' {
                $hasEffort = $false
                foreach ($tok in $parsedHargs) {
                    if ($tok -eq '--effort' -or $tok -like '--effort=*') { $hasEffort = $true; break }
                }
                $cliArgs = @('-p', $maskedTesterPrompt, '--model', 'gemini-4-hydrogen-high')
                if (-not $hasEffort) { $cliArgs += @('--effort', 'high') }
                $cliArgs += @('--output-format', 'stream-json')
                if ($parsedHargs.Count -gt 0) { $cliArgs += $parsedHargs }
            }
            'claude' {
                $cliArgs = @('-p', $maskedTesterPrompt, '--output-format', 'stream-json', '--verbose')
                if ($parsedHargs.Count -gt 0) { $cliArgs += $parsedHargs }
            }
            'grok' {
                $cliArgs = @($parsedHargs)
            }
        }
    }
    else {
        $binPath = $Pwsh
        $cliArgs = @('-NoProfile', '-Command', $HarnessCommand)
    }

    $outWriter = [IO.StreamWriter]::new($stdoutLog, $false, $Utf8NoBom)
    $errWriter = [IO.StreamWriter]::new($stderrLog, $false, $Utf8NoBom)
    $outWriter.AutoFlush = $true
    $errWriter.AutoFlush = $true
    $harnessRc = 0
    $prevEap = $ErrorActionPreference
    $hasNativePref = (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) -ne $null
    $prevNativePref = if ($hasNativePref) { $PSNativeCommandUseErrorActionPreference } else { $false }
    Push-Location $RepoRoot
    try {
        $ErrorActionPreference = 'Continue'
        if ($hasNativePref) { $PSNativeCommandUseErrorActionPreference = $false }
        $global:LASTEXITCODE = 0
        & $binPath @cliArgs 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $c = 0
                $maskedLine = ef_mask_line -Line $_.ToString() -CountRef ([ref]$c)
                $errWriter.WriteLine($maskedLine)
                [Console]::Error.WriteLine($maskedLine)
            }
            else {
                $c = 0
                $maskedLine = ef_mask_line -Line ([string]$_) -CountRef ([ref]$c)
                $outWriter.WriteLine($maskedLine)
                Write-Output $maskedLine
            }
        }
        $harnessRc = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    }
    finally {
        $ErrorActionPreference = $prevEap
        if ($hasNativePref) { $PSNativeCommandUseErrorActionPreference = $prevNativePref }
        Pop-Location
        $outWriter.Dispose()
        $errWriter.Dispose()
    }

    if ($harnessRc -ne 0) {
        $scanRc = ef_scan -RepoRoot $RepoRoot -CardId $CardId -HarnessLogDir $HarnessLogDir
        if ($scanRc -eq 6) {
            $ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            ef_write_test_status -StatusFile (Join-Path $RuntimeDir 'test-status.json') -Mode 'scan_fail' -Values @{
                cardId       = $CardId
                evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
                timestamp    = $ts
            }
            exit 6
        }
        exit $harnessRc
    }
}

$timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Output "==> [TESTER] Validando Card $CardId (Tipo: $DemandType, Fase: $Phase)..."

$cmdSha256 = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($TestCommand))).Replace('-', '').ToLowerInvariant().Substring(0, 12)
$maskedLabel = ''
if ($TestLabel) {
    $lc = 0
    $maskedLabel = ef_mask_string -Text $TestLabel -CountRef ([ref]$lc)
}

$rawOutput = ''
$testExitCode = 0
$prevEap2 = $ErrorActionPreference
$hasNativePref2 = (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) -ne $null
$prevNativePref2 = if ($hasNativePref2) { $PSNativeCommandUseErrorActionPreference } else { $false }
Push-Location $RepoRoot
try {
    $ErrorActionPreference = 'Continue'
    if ($hasNativePref2) { $PSNativeCommandUseErrorActionPreference = $false }
    $global:LASTEXITCODE = 0
    $outputLines = & $Pwsh -NoProfile -Command $TestCommand 2>&1
    $testExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $rawOutput = (($outputLines | ForEach-Object { $_.ToString() }) -join "`n")
}
catch {
    $testExitCode = if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { [int]$LASTEXITCODE } else { 1 }
    $rawOutput = $_.ToString()
}
finally {
    $ErrorActionPreference = $prevEap2
    if ($hasNativePref2) { $PSNativeCommandUseErrorActionPreference = $prevNativePref2 }
    Pop-Location
}

$maskCount = 0
$maskedOutput = ef_mask_string -Text $rawOutput -CountRef ([ref]$maskCount)
if ($maskedOutput -and -not $maskedOutput.EndsWith("`n")) {
    $maskedOutput += "`n"
}

if ($Phase -eq 'r0-red') {
    $r0RedFile = Join-Path $EvidenceDir 'r0-red.log'
    $r0Tmp = Join-Path $EvidenceDir ".r0-red.tmp.$PID"
    [IO.File]::WriteAllText($r0Tmp, $maskedOutput, $Utf8NoBom)
    [IO.File]::Move($r0Tmp, $r0RedFile, $true)

    $scanRc = ef_scan -RepoRoot $RepoRoot -CardId $CardId -HarnessLogDir $HarnessLogDir
    if ($scanRc -eq 6) {
        ef_write_test_status -StatusFile (Join-Path $RuntimeDir 'test-status.json') -Mode 'scan_fail' -Values @{
            cardId       = $CardId
            evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
            timestamp    = $timestamp
        }
        [Console]::Error.WriteLine('==> [TESTER] ERRO CRITICO: SECRET_IN_LOG detectado durante r0-red.')
        exit 6
    }

    if ($testExitCode -ne 0) {
        Write-Output "==> [TESTER] R0-RED confirmado (teste falhou antes da correcao com exit $testExitCode)."
        exit 0
    }
    [Console]::Error.WriteLine('==> [TESTER] ERRO R0-RED: o teste de regressao passou antes da correcao (exit 0). O R0 deve falhar antes do fix.')
    exit 2
}

$outputLogFile = Join-Path $EvidenceDir 'test-output.log'
$outputTmp = Join-Path $EvidenceDir ".test-output.tmp.$PID"
[IO.File]::WriteAllText($outputTmp, $maskedOutput, $Utf8NoBom)
[IO.File]::Move($outputTmp, $outputLogFile, $true)
$lineCount = if ([string]::IsNullOrEmpty($maskedOutput)) { 0 } else { ($maskedOutput.TrimEnd("`n") -split "`n").Count }

$scanRc = ef_scan -RepoRoot $RepoRoot -CardId $CardId -HarnessLogDir $HarnessLogDir

$passed = $false
$reason = $null
$statusLabel = 'FALHA (RED)'
$finalExit = 2
if ($scanRc -eq 6) {
    $passed = $false
    $reason = 'SECRET_IN_LOG'
    $statusLabel = 'BLOQUEADO (SECRET_IN_LOG)'
    $finalExit = 6
}
elseif ($testExitCode -eq 0) {
    $passed = $true
    $statusLabel = 'APROVADO (GREEN)'
    $finalExit = 0
}

$findingsSummary = ($script:EfScanFindings | ForEach-Object { "$($_.file) ($($_.count))" }) -join ', '
$unscannedSummary = $script:EfScanUnscanned -join ', '

$blockLines = [System.Collections.Generic.List[string]]::new()
$blockLines.Add("- **Fase:** $Phase")
$blockLines.Add("- **Tipo de Demanda:** $DemandType")
$blockLines.Add("- **Data/Hora (UTC):** $timestamp")
$blockLines.Add("- **Codigo de Saida:** ``$testExitCode``")
$blockLines.Add("- **Status Final:** $statusLabel")
$blockLines.Add("- **commandSha256:** ``$cmdSha256``")
if ($maskedLabel) { $blockLines.Add("- **testLabel:** $maskedLabel") }
if ($Harness) {
    $hLine = "- **harness:** ``$Harness``"
    if ($harnessFlagNames) { $hLine += " (flags: ``$harnessFlagNames``)" }
    $blockLines.Add($hLine)
}
if ($DemandType -eq 'Bug') {
    $r0RedLog = Join-Path $EvidenceDir 'r0-red.log'
    if (Test-Path -LiteralPath $r0RedLog -PathType Leaf) {
        $blockLines.Add("- **R0-RED:** ``.agent-pack/evidencias/$CardId/r0-red.log``")
    }
    else {
        $blockLines.Add('- **R0-RED:** Nao registrado ou dispensado explicitamente no Gate 1')
    }
}
$blockLines.Add("- **Log de Saida:** ``.agent-pack/evidencias/$CardId/test-output.log`` (lines: $lineCount, masked: $maskCount)")
$scanLine = "- **Secret Scan:** $($script:EfScanStatus)"
if ($findingsSummary) { $scanLine += "; findings: $findingsSummary" }
if ($unscannedSummary) { $scanLine += "; unscanned: $unscannedSummary" }
$blockLines.Add($scanLine)

$evRc = ef_update_evidence_block -EvidenceFile $EvidenceFile -CardId $CardId -Mode 'replace' -Body ($blockLines -join "`n")
if ($evRc -ne 0) { exit $evRc }

ef_write_test_status -StatusFile (Join-Path $RuntimeDir 'test-status.json') -Mode 'tester' -Values @{
    cardId       = $CardId
    demandType   = $DemandType
    phase        = $Phase
    passed       = $passed
    exitCode     = $testExitCode
    evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
    timestamp    = $timestamp
    reason       = $reason
    scanStatus   = $script:EfScanStatus
}

if ($finalExit -eq 6) {
    [Console]::Error.WriteLine('==> [TESTER] ERRO CRITICO: SECRET_IN_LOG detectado. Gate 2 bloqueado.')
    exit 6
}
elseif ($passed) {
    Write-Output "==> [TESTER] Testes passaram com sucesso. Evidencia pronta para Gate 2 em $EvidenceFile."
    exit 0
}
else {
    [Console]::Error.WriteLine("==> [TESTER] Testes falharam (exit $testExitCode). Feedback salvo para o Implementor.")
    exit 2
}
