#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CardId,
    [string]$Skill = '$bugfix',
    [string]$TaskSpec = '',
    [string]$Harness = $env:EF_HARNESS,
    [string]$HarnessArgs = $env:EF_HARNESS_ARGS,
    [string]$HarnessCommand = $env:EF_IMPLEMENTOR_CMD,
    [string]$Repo = '.',
    [switch]$CommitGate2,
    [string]$CommitMessage = '',
    [string[]]$Paths = @(),
    [switch]$AllowUnvalidated,
    [string]$Reason = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $ScriptDir 'ef-secrets.ps1')

$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$EvidenceDir = Join-Path $RepoRoot ".agent-pack/evidencias/$CardId"
$HarnessLogDir = if ($env:EF_HARNESS_LOG_DIR) { $env:EF_HARNESS_LOG_DIR } else { Join-Path $RepoRoot ".agent-pack/logs/$CardId" }
$StatusFile = Join-Path $RuntimeDir 'test-status.json'
$LockFile = Join-Path $RuntimeDir 'task.lock'
$EvidenceFile = Join-Path $EvidenceDir 'EVIDENCIA.md'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Pwsh = (Get-Process -Id $PID).Path

$loadRc = ef_load_secrets -RepoRoot $RepoRoot -HarnessLogDir $HarnessLogDir
if ($loadRc -ne 0) { exit $loadRc }

function Get-ProtectedBranches([string]$RepoPath) {
    $prot = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($b in @('main', 'master', 'HEAD', '')) { [void]$prot.Add($b) }
    $addBranches = {
        param([string]$raw)
        if ([string]::IsNullOrWhiteSpace($raw)) { return }
        foreach ($item in ($raw -split ',')) {
            $clean = $item.Trim().Trim('[', ']').Trim('`').Trim()
            if (-not $clean -or $clean -eq '...') { continue }
            [void]$prot.Add($clean)
        }
    }
    if ($env:EF_PROTECTED_BRANCHES) { & $addBranches $env:EF_PROTECTED_BRANCHES }
    $agentsMd = Join-Path $RepoPath 'AGENTS.md'
    if (Test-Path -LiteralPath $agentsMd -PathType Leaf) {
        foreach ($line in [IO.File]::ReadAllLines($agentsMd, [Text.Encoding]::UTF8)) {
            if ($line -match '^\s*-\s*Branches\s+protegidas\s+\(harness\)\s*:\s*(.+)$') {
                & $addBranches $Matches[1]
            }
        }
    }
    return $prot
}

function Resolve-Gate2Paths([string]$RepoPath, [string[]]$ExplicitPaths, [bool]$HasExplicitPaths, [string]$SpecPath) {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($HasExplicitPaths) {
        foreach ($entry in $ExplicitPaths) {
            if ($null -eq $entry) { continue }
            foreach ($p in ($entry -split ',')) {
                $t = $p.Trim()
                if ($t) { $candidates.Add($t) }
            }
        }
    }
    elseif ($SpecPath -and (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
        $inBlock = $false
        foreach ($line in [IO.File]::ReadAllLines($SpecPath, [Text.Encoding]::UTF8)) {
            $l = $line.TrimEnd("`r", "`n")
            if ($l -match '<!--\s*ef:paths:begin\s*-->') { $inBlock = $true; continue }
            if ($l -match '<!--\s*ef:paths:end\s*-->') { $inBlock = $false; break }
            if (-not $inBlock) { continue }
            $l = $l.Trim()
            if (-not $l -or $l.StartsWith('#')) { continue }
            if ($l -match '^-\s+(.+)$') { $l = $Matches[1].Trim() }
            if ($l -match '^`([^`]+)`') { $l = $Matches[1] }
            else { $l = $l.Trim('`') }
            $l = $l.Trim()
            if ($l) { $candidates.Add($l) }
        }
    }

    if ($candidates.Count -eq 0) {
        [Console]::Error.WriteLine('Error: Explicit -Paths or TASK_SPEC ef:paths block is required for -CommitGate2.')
        return $null
    }

    $repoAbs = Resolve-EfCanonicalPath $RepoPath
    $cleanList = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($raw in $candidates) {
        $p = $raw.Replace('\', '/')
        if ($p.StartsWith('/') -or $p -match '^[A-Za-z]:' -or $p.StartsWith('\\')) {
            [Console]::Error.WriteLine("Error: Forbidden absolute path in Gate 2 staging: $raw")
            return $null
        }
        $segs = $p.Split('/', [StringSplitOptions]::RemoveEmptyEntries)
        if ($segs -contains '..') {
            [Console]::Error.WriteLine("Error: Forbidden parent traversal (..) in Gate 2 staging: $raw")
            return $null
        }
        if ($p.StartsWith('./')) { $p = $p.Substring(2) }
        $p = $p.TrimEnd('/')
        if (-not $p) {
            [Console]::Error.WriteLine('Error: Empty path in Gate 2 staging.')
            return $null
        }
        if ($p -match '^(?:\.agent-pack|\.agents|\.grok|prompts|docs/engineering-flow)(?:/|$)') {
            [Console]::Error.WriteLine("Error: Forbidden protected path in Gate 2 staging: $p")
            return $null
        }
        $full = [IO.Path]::Combine($repoAbs, $p)
        if (Test-Path -LiteralPath $full) {
            $canon = Resolve-EfCanonicalPath $full
            $prefix = $repoAbs + [IO.Path]::DirectorySeparatorChar
            $cmp = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            if (-not [string]::Equals($canon, $repoAbs, $cmp) -and -not $canon.StartsWith($prefix, $cmp)) {
                [Console]::Error.WriteLine("Error: Path escapes repository root: $p")
                return $null
            }
        }
        if ($seen.Add($p)) { $cleanList.Add($p) }
    }
    return ,@($cleanList.ToArray())
}

if ($CommitGate2) {
    if (-not $CommitMessage) {
        [Console]::Error.WriteLine('Error: -CommitMessage is required with -CommitGate2.')
        exit 2
    }

    $trimmedReason = $Reason.Trim()
    if ($AllowUnvalidated) {
        if ($trimmedReason.Length -lt 10) {
            [Console]::Error.WriteLine('Error: -AllowUnvalidated requires -Reason with at least 10 characters.')
            exit 2
        }
    }

    $branchOut = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
    $branch = if ($LASTEXITCODE -eq 0 -and $branchOut) { ([string]$branchOut).Trim() } else { '' }
    $protBranches = Get-ProtectedBranches $RepoRoot
    if (-not $branch -or $protBranches.Contains($branch)) {
        [Console]::Error.WriteLine("Error: Gate 2 commit is forbidden on protected or detached branch '$branch'.")
        exit 3
    }

    if (Test-Path -LiteralPath $StatusFile -PathType Leaf) {
        $existingStatus = [IO.File]::ReadAllText($StatusFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($existingStatus.PSObject.Properties['reason'] -and $existingStatus.reason -eq 'SECRET_IN_LOG') {
            [Console]::Error.WriteLine("Error: SECRET_IN_LOG is active in $StatusFile. Run a clean validation cycle before Gate 2 commit.")
            exit 6
        }
    }

    if (-not $AllowUnvalidated) {
        if (-not (Test-Path -LiteralPath $StatusFile -PathType Leaf)) {
            [Console]::Error.WriteLine("Error: Missing test status file ($StatusFile). Run Tester before Gate 2 commit.")
            exit 4
        }
        $statusObj = [IO.File]::ReadAllText($StatusFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($statusObj.passed -ne $true) {
            [Console]::Error.WriteLine('Error: Tester report does not indicate passed=true. Gate 2 commit aborted.')
            exit 4
        }
    }

    $scanRc = ef_scan -RepoRoot $RepoRoot -CardId $CardId -HarnessLogDir $HarnessLogDir
    if ($scanRc -eq 6) {
        $nowUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        ef_write_test_status -StatusFile $StatusFile -Mode 'scan_fail' -Values @{
            cardId       = $CardId
            evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
            timestamp    = $nowUtc
        }
        $findingsMsg = ($script:EfScanFindings | ForEach-Object { "$($_.file) ($($_.count))" }) -join ', '
        [void](ef_update_evidence_block -EvidenceFile $EvidenceFile -CardId $CardId -Mode 'append_line' -Body "- **Secret Scan:** SECRET_IN_LOG; findings: $findingsMsg")
        [Console]::Error.WriteLine('Error: SECRET_IN_LOG detected during Gate 2 pre-commit scan. Commit aborted.')
        exit 6
    }

    $effectiveSpec = $TaskSpec
    $defaultSpec = Join-Path $RuntimeDir 'TASK_SPEC.md'
    if (-not $effectiveSpec -and (Test-Path -LiteralPath $defaultSpec -PathType Leaf)) {
        $effectiveSpec = $defaultSpec
    }

    $hasExplicitPaths = $PSBoundParameters.ContainsKey('Paths')
    $gate2Paths = Resolve-Gate2Paths -RepoPath $RepoRoot -ExplicitPaths $Paths -HasExplicitPaths $hasExplicitPaths -SpecPath $effectiveSpec
    if ($null -eq $gate2Paths -or $gate2Paths.Count -eq 0) {
        exit 5
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git -C $RepoRoot add -- @gate2Paths
    $addRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($addRc -ne 0) {
        & git -C $RepoRoot reset -q -- @gate2Paths 2>$null | Out-Null
        [Console]::Error.WriteLine('Error: Failed to stage authorized paths.')
        exit 5
    }

    $stagedFiles = @(& git -C $RepoRoot diff --cached --name-only | Where-Object { $_ -and $_.Trim() })
    if ($stagedFiles.Count -eq 0) {
        & git -C $RepoRoot reset -q -- @gate2Paths 2>$null | Out-Null
        [Console]::Error.WriteLine('Error: No staged changes among authorized paths.')
        exit 5
    }

    $pathSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($gp in $gate2Paths) { [void]$pathSet.Add($gp) }
    foreach ($sf in $stagedFiles) {
        if (-not $pathSet.Contains($sf.Trim())) {
            & git -C $RepoRoot reset -q -- @gate2Paths 2>$null | Out-Null
            [Console]::Error.WriteLine("Error: Staged file '$sf' is outside authorized Gate 2 paths.")
            exit 5
        }
    }

    $porcelainLines = @(& git -C $RepoRoot status --porcelain)
    foreach ($pl in $porcelainLines) {
        if (-not $pl -or $pl.Length -lt 4) { continue }
        $xy = $pl.Substring(0, 2)
        $wt = $pl.Substring(3)
        if ($wt -like '* -> *') { $wt = ($wt -split ' -> ')[-1] }
        $wt = $wt.Trim('"')
        if (-not $pathSet.Contains($wt) -and ($xy[1] -ne ' ' -or $xy -eq '??')) {
            Write-Output "UNSTAGED_OUT_OF_SCOPE: $wt"
        }
    }

    if ($AllowUnvalidated) {
        $nowUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        $rcnt = 0
        $maskedReason = ef_mask_string -Text $trimmedReason -CountRef ([ref]$rcnt)
        $evRc = ef_update_evidence_block -EvidenceFile $EvidenceFile -CardId $CardId -Mode 'append_line' -Body "allowUnvalidated: true — reason: $maskedReason — at: $nowUtc"
        if ($evRc -ne 0) { exit $evRc }
        ef_write_test_status -StatusFile $StatusFile -Mode 'allow_unvalidated' -Values @{
            cardId                 = $CardId
            allowUnvalidatedReason = $maskedReason
            allowUnvalidatedAt     = $nowUtc
        }
    }

    & git -C $RepoRoot commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path -LiteralPath $LockFile) { Remove-Item -LiteralPath $LockFile -Force }
    Write-Output "[IMPLEMENTOR] Gate 2 commit completed on branch '$branch' and task.lock released."
    exit 0
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
elseif (-not $HarnessCommand) {
    [Console]::Error.WriteLine('Error: No harness provided. Pass -Harness or -HarnessCommand (or set EF_HARNESS / EF_IMPLEMENTOR_CMD).')
    exit 2
}

New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
New-Item -ItemType Directory -Path $HarnessLogDir -Force | Out-Null

$promptFile = Join-Path $RepoRoot 'prompts/12-implementor-harness.md'
$basePrompt = if (Test-Path -LiteralPath $promptFile -PathType Leaf) { Get-Content -LiteralPath $promptFile -Raw } else { '' }
$specContent = if ($TaskSpec -and (Test-Path -LiteralPath $TaskSpec -PathType Leaf)) { Get-Content -LiteralPath $TaskSpec -Raw } else { '' }

$feedbackSection = ''
if (Test-Path -LiteralPath $StatusFile -PathType Leaf) {
    $statusObj = [IO.File]::ReadAllText($StatusFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($statusObj.passed -eq $false) {
        $runnerFb = ef_extract_evidence_runner_block $EvidenceFile
        $testOutLog = Join-Path $EvidenceDir 'test-output.log'
        $tailOut = ''
        if (Test-Path -LiteralPath $testOutLog -PathType Leaf) {
            $tailOut = (Get-Content -LiteralPath $testOutLog -Tail 200) -join "`n"
        }
        if ($runnerFb -or $tailOut) {
            $feedbackSection = "`n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]`n"
            if ($runnerFb) { $feedbackSection += "$runnerFb`n" }
            if (Test-Path -LiteralPath $testOutLog -PathType Leaf) {
                $feedbackSection += "Log: .agent-pack/evidencias/$CardId/test-output.log`n``````text`n$tailOut`n``````"
            }
        }
        else {
            $feedbackSection = "`n[CORRECAO NECESSARIA - FALHA REPORTADA PELO TESTER]`n$(Get-Content -LiteralPath $StatusFile -Raw)"
        }
    }
}

$rawContext = "# Contexto de Execucao — Implementor`n- Card: $CardId`n- Skill: $Skill`n`n"
if ($basePrompt) { $rawContext += "$basePrompt`n`n" }
if ($specContent) { $rawContext += "## Especificacao da Tarefa`n$specContent`n`n" }
if ($feedbackSection) { $rawContext += "$feedbackSection`n" }

$contextMaskCount = 0
$maskedContext = ef_mask_string -Text $rawContext -CountRef ([ref]$contextMaskCount)
$contextFile = Join-Path $RuntimeDir "implementor-prompt-$CardId.md"
$contextTmp = Join-Path $RuntimeDir ".implementor-prompt-$CardId.tmp.$PID"
[IO.File]::WriteAllText($contextTmp, $maskedContext, $Utf8NoBom)
[IO.File]::Move($contextTmp, $contextFile, $true)

Write-Output "==> [IMPLEMENTOR] Executando para o Card $CardId ($Skill)... (contexto mascarado: $contextMaskCount)"
if ($harnessFlagNames) { Write-Output "==> [IMPLEMENTOR] Harness flags: $harnessFlagNames" }

$env:EF_CARD_ID = $CardId
$env:EF_SKILL = $Skill
$env:EF_PROMPT_FILE = $contextFile

$attempt = if ($env:EF_ATTEMPT) { $env:EF_ATTEMPT } else { '1' }
$stdoutLog = Join-Path $HarnessLogDir "${CardId}_implementor_attempt${attempt}.jsonl"
$stderrLog = Join-Path $HarnessLogDir "${CardId}_implementor_attempt${attempt}.err"

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
            $cliArgs = @('-p', $maskedContext, '--model', 'gemini-4-hydrogen-high')
            if (-not $hasEffort) { $cliArgs += @('--effort', 'high') }
            $cliArgs += @('--output-format', 'stream-json')
            if ($parsedHargs.Count -gt 0) { $cliArgs += $parsedHargs }
        }
        'claude' {
            $cliArgs = @('-p', $maskedContext, '--output-format', 'stream-json', '--verbose')
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
$outMaskCnt = 0
$errMaskCnt = 0
$harnessRc = 0
$prevEap2 = $ErrorActionPreference
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
            $errMaskCnt += $c
            $errWriter.WriteLine($maskedLine)
            [Console]::Error.WriteLine($maskedLine)
        }
        else {
            $c = 0
            $maskedLine = ef_mask_line -Line ([string]$_) -CountRef ([ref]$c)
            $outMaskCnt += $c
            $outWriter.WriteLine($maskedLine)
            Write-Output $maskedLine
        }
    }
    $harnessRc = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
}
finally {
    $ErrorActionPreference = $prevEap2
    if ($hasNativePref) { $PSNativeCommandUseErrorActionPreference = $prevNativePref }
    Pop-Location
    $outWriter.Dispose()
    $errWriter.Dispose()
}

Write-Output "==> [IMPLEMENTOR] Log capturado (mascaramentos stdout=$outMaskCnt, stderr=$errMaskCnt)"

$scanRc = ef_scan -RepoRoot $RepoRoot -CardId $CardId -HarnessLogDir $HarnessLogDir
if ($scanRc -eq 6) {
    $nowUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    ef_write_test_status -StatusFile $StatusFile -Mode 'scan_fail' -Values @{
        cardId       = $CardId
        evidencePath = ".agent-pack/evidencias/$CardId/EVIDENCIA.md"
        timestamp    = $nowUtc
    }
    $findingsMsg = ($script:EfScanFindings | ForEach-Object { "$($_.file) ($($_.count))" }) -join ', '
    [void](ef_update_evidence_block -EvidenceFile $EvidenceFile -CardId $CardId -Mode 'append_line' -Body "- **Secret Scan:** SECRET_IN_LOG; findings: $findingsMsg")
    [Console]::Error.WriteLine('==> [IMPLEMENTOR] ERRO CRITICO: SECRET_IN_LOG detectado.')
    exit 6
}

if ($harnessRc -ne 0) { exit $harnessRc }
