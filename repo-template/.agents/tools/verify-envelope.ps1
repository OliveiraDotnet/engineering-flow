#Requires -Version 7
[CmdletBinding()]
param(
    [string]$Repo = '.',
    [string]$TaskSpec = '',
    [string]$TestStatus = '',
    [switch]$SkipEvidenceCheck,
    [switch]$RecordViolation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (& git -C $Repo rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) {
    [Console]::Error.WriteLine("FAIL [1]: Not a git repository: $Repo")
    exit 1
}
$RepoRoot = $RepoRoot.Trim()

$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$TaskSpecPath = if ($TaskSpec) { $TaskSpec } else { Join-Path $RuntimeDir 'TASK_SPEC.md' }
$TestStatusPath = if ($TestStatus) { $TestStatus } else { Join-Path $RuntimeDir 'test-status.json' }
$SessionStatePath = Join-Path $RuntimeDir 'session-state.json'
$SessionTool = Join-Path $PSScriptRoot 'session-state.ps1'

function Fail-Envelope {
    param([int]$Code, [string]$Message)
    if ($RecordViolation -and (Test-Path -LiteralPath $SessionTool -PathType Leaf)) {
        try { & $SessionTool update -Repo $RepoRoot -IncrementEnvelopeViolation | Out-Null } catch { }
    }
    [Console]::Error.WriteLine("ENVELOPE_VIOLATION [$Code]: $Message")
    exit $Code
}

function Normalize-RelPath([string]$PathValue) {
    return ($PathValue.Trim().Trim('"').Replace('\', '/') -replace '^\./', '')
}

function Get-ProtectedBranches([string]$RepoPath) {
    $prot = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($b in @('main', 'master', 'HEAD', '')) { [void]$prot.Add($b) }
    $addBranches = {
        param([string]$raw)
        if ([string]::IsNullOrWhiteSpace($raw)) { return }
        $stripped = ($raw -replace '\s*\(.*$', '').Trim()
        foreach ($item in ($stripped -split ',')) {
            $clean = $item.Trim()
            if (-not $clean) { continue }
            if ($clean -match '^\[.*\]$' -or $clean.Contains('|') -or $clean.Contains('...')) { continue }
            $clean = $clean.Trim('`', '"', "'").Trim()
            if (-not $clean -or $clean -match '\s') { continue }
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
            elseif ($line -match '^\s*-\s*Branch\s+principal\s+\(produ[cç][aã]o\)\s*:\s*(.+)$') {
                & $addBranches $Matches[1]
            }
        }
    }
    return $prot
}

# 1. Protected branch check (main, master, EF_PROTECTED_BRANCHES, and AGENTS.md declared protected/production branches)
$Branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $Branch) { $Branch = 'HEAD' } else { $Branch = $Branch.Trim() }
$ProtectedBranches = Get-ProtectedBranches $RepoRoot
if ($ProtectedBranches.Contains($Branch)) {
    Fail-Envelope 10 "Current branch '$Branch' is protected. Work must happen on a card branch (feat/... or fix/...)."
}

# 2. Operational file staging leak check (99.9% decoupling: ONLY AGENTS.md may be versioned from SpecGuard)
$OperationalRegex = '^(?:\.agent-pack/|\.agents/|\.grok/|\.claude/skills/|\.claude/agents/|\.cursor/skills/|\.github/skills/|\.dsh/skills/|docs/engineering-flow/|docs/ai/|prompts/|Planejamento/|planejamento/|\.engineering-flow-evidence/|\.ai-memory\.toml$)|\.agent-pack\.new$|\.agent-pack\.backup-'
$StagedFiles = @(& git -C $RepoRoot diff --cached --name-only 2>$null | Where-Object { $_ -and $_.Trim() } | ForEach-Object { Normalize-RelPath $_ })
$LeakedOperational = @($StagedFiles | Where-Object { $_ -match $OperationalRegex })
if ($LeakedOperational.Count -gt 0) {
    Fail-Envelope 12 ("Operational SpecGuard files staged in Git (must stay gitignored): " + ($LeakedOperational -join ', '))
}

# 3. Parse ef:paths from TASK_SPEC.md and verify blast radius of all non-ignored changes
if (-not (Test-Path -LiteralPath $TaskSpecPath -PathType Leaf)) {
    Fail-Envelope 11 "TASK_SPEC.md not found at '$TaskSpecPath'."
}

$allowedPaths = New-Object System.Collections.Generic.List[string]
$inBlock = $false
foreach ($line in [IO.File]::ReadAllLines($TaskSpecPath)) {
    if ($line -match '<!--\s*ef:paths:begin\s*-->') { $inBlock = $true; continue }
    if ($line -match '<!--\s*ef:paths:end\s*-->') { $inBlock = $false; break }
    if ($inBlock) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith('#')) { continue }
        $entry = ($entry -replace '^[-*]\s+', '').Trim('`', ' ')
        if (-not $entry) { continue }
        $norm = Normalize-RelPath $entry
        if ($norm.EndsWith('/') -or $norm.Contains('*') -or $norm -eq '.') {
            Fail-Envelope 11 "Invalid ef:paths entry '$entry' (directories/globs are forbidden; list individual files only)."
        }
        if (-not $allowedPaths.Contains($norm)) { $allowedPaths.Add($norm) }
    }
}
if ($allowedPaths.Count -eq 0) {
    Fail-Envelope 11 "No files declared inside <!-- ef:paths:begin --> ... <!-- ef:paths:end --> in '$TaskSpecPath'."
}

$statusLines = @(& git -C $RepoRoot status --porcelain --untracked-files=all 2>$null | Where-Object { $_ -and $_.Length -ge 4 })
$changedFiles = New-Object System.Collections.Generic.List[string]
foreach ($sl in $statusLines) {
    $rawPath = $sl.Substring(3).Trim()
    if ($rawPath -match ' -> ') { $rawPath = ($rawPath -split ' -> ')[-1].Trim() }
    $norm = Normalize-RelPath $rawPath
    if ($norm -and -not $changedFiles.Contains($norm)) { $changedFiles.Add($norm) }
}

$outOfEnvelope = @($changedFiles | Where-Object { -not $allowedPaths.Contains($_) })
if ($outOfEnvelope.Count -gt 0) {
    Fail-Envelope 11 ("Modified/untracked files outside authorized ef:paths envelope: " + ($outOfEnvelope -join ', '))
}

# 4. Test status, stale card mismatch & secret scan check (Gate 2 readiness)
if (-not $SkipEvidenceCheck) {
    if (-not (Test-Path -LiteralPath $TestStatusPath -PathType Leaf)) {
        Fail-Envelope 14 "test-status.json not found at '$TestStatusPath'. Run Tester validation before Gate 2."
    }
    $ts = [IO.File]::ReadAllText($TestStatusPath) | ConvertFrom-Json
    $reasonProp = $ts.PSObject.Properties['reason']
    $reasonVal = if ($reasonProp -and $null -ne $reasonProp.Value) { [string]$reasonProp.Value } else { '' }
    $secretProp = $ts.PSObject.Properties['secretScan']
    $secretStatus = if ($secretProp -and $null -ne $secretProp.Value -and $secretProp.Value.PSObject.Properties['status']) { [string]$secretProp.Value.status } else { '' }

    if ($reasonVal -eq 'SECRET_IN_LOG' -or ($secretStatus -and $secretStatus -ne 'clean')) {
        Fail-Envelope 13 "Secret scan is not clean (reason='$reasonVal', secretScan.status='$secretStatus'). Gate 2 is blocked."
    }

    if (Test-Path -LiteralPath $SessionStatePath -PathType Leaf) {
        $ss = [IO.File]::ReadAllText($SessionStatePath) | ConvertFrom-Json
        $ssCard = if ($ss.PSObject.Properties['card'] -and $null -ne $ss.card) { ([string]$ss.card).Trim() } else { '' }
        $tsCard = if ($ts.PSObject.Properties['cardId'] -and $null -ne $ts.cardId) { ([string]$ts.cardId).Trim() } else { '' }
        if ($ssCard -and $tsCard -and $ssCard -ne $tsCard) {
            Fail-Envelope 14 "Stale test-status.json belongs to card '$tsCard', expected active session card '$ssCard'. Run Tester for '$ssCard' before Gate 2."
        }
    }

    $passedProp = $ts.PSObject.Properties['passed']
    $isPassed = ($passedProp -and $passedProp.Value -eq $true)
    $allowProp = $ts.PSObject.Properties['allowUnvalidated']
    $allowReasonProp = $ts.PSObject.Properties['allowUnvalidatedReason']
    $isAllowedUnvalidated = ($allowProp -and $allowProp.Value -eq $true -and $allowReasonProp -and -not [string]::IsNullOrWhiteSpace([string]$allowReasonProp.Value))

    if (-not $isPassed -and -not $isAllowedUnvalidated) {
        Fail-Envelope 14 "Validation has not passed in test-status.json (passed=$($passedProp.Value), reason='$reasonVal')."
    }
}

Write-Output "ENVELOPE_OK: branch=$Branch | files_changed=$($changedFiles.Count)/$($allowedPaths.Count) | operational_leaks=0 | evidence=$(if ($SkipEvidenceCheck) { 'skipped' } else { 'verified' })"
exit 0
