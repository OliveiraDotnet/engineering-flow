#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('init', 'update', 'show', 'close')]
    [string]$Command,
    [string]$Card = '',
    [ValidateSet('', '0', '1', '2')]
    [string]$Tier = '',
    [string]$Branch = '',
    [string]$Phase = '',
    [string]$Role = '',
    [int]$Attempt = -1,
    [string[]]$Criteria = @(),
    [string[]]$Decisions = @(),
    [string]$CriterionId = '',
    [ValidateSet('', 'pending', 'verified_red', 'verified', 'failed', 'blocked')]
    [string]$CriterionStatus = '',
    [string]$CriterionArtifact = '',
    [string]$DeadEnd = '',
    [string]$NextAction = '',
    [string[]]$FilesTouched = @(),
    [switch]$IncrementBlocked,
    [switch]$IncrementEnvelopeViolation,
    [switch]$ReworkPostGate2,
    [switch]$KeepState,
    [switch]$Json,
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Utf8NoBom = [Text.UTF8Encoding]::new($false)

$RepoRoot = (& git -C $Repo rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) {
    $RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
}
else {
    $RepoRoot = $RepoRoot.Trim()
}

$RuntimeDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$StateFile = Join-Path $RuntimeDir 'session-state.json'
$MetricsFile = Join-Path $RuntimeDir 'metrics.jsonl'

function Get-GitValue([string[]]$GitArgs, [string]$Fallback) {
    $val = (& git -C $RepoRoot @GitArgs 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $val) { return $Fallback }
    return ($val -join '').Trim()
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) { return $null }
    return ([IO.File]::ReadAllText($StateFile, $Utf8NoBom) | ConvertFrom-Json)
}

function Write-State([object]$State) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
    $jsonText = ($State | ConvertTo-Json -Depth 6) + "`n"
    [IO.File]::WriteAllText($StateFile, $jsonText, $Utf8NoBom)
}

function Split-ListItems([string[]]$Items) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        if (-not $item) { continue }
        foreach ($part in ($item -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed -and -not $out.Contains($trimmed)) { $out.Add($trimmed) | Out-Null }
        }
    }
    return @($out.ToArray())
}

$NowUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$CurrentHead = Get-GitValue @('rev-parse', '--short', 'HEAD') 'none'
$CurrentBranch = Get-GitValue @('rev-parse', '--abbrev-ref', 'HEAD') 'unknown'

switch ($Command) {
    'init' {
        if (-not $Card) { [Console]::Error.WriteLine('init requires -Card <id>'); exit 2 }
        $tierNum = if ($Tier) { [int]$Tier } else { 1 }
        $branchVal = if ($Branch) { $Branch } else { $CurrentBranch }
        $roleVal = if ($Role) { $Role } else { 'Engenheiro-Chefe' }
        $phaseVal = if ($Phase) { $Phase } else { 'triagem' }
        $criteriaList = @()
        foreach ($cid in (Split-ListItems $Criteria)) {
            $criteriaList += [ordered]@{
                id       = $cid
                status   = 'pending'
                artifact = $null
            }
        }
        $state = [ordered]@{
            schemaVersion      = '6.0'
            card               = $Card
            tier               = $tierNum
            branch             = $branchVal
            phase              = $phaseVal
            activeRole         = $roleVal
            headCommit         = $CurrentHead
            attempt            = if ($Attempt -ge 0) { $Attempt } else { 0 }
            criteria           = $criteriaList
            decisionsInScope   = @(Split-ListItems $Decisions)
            deadEnds           = @()
            filesTouched       = @(Split-ListItems $FilesTouched)
            blockedDecisions   = 0
            envelopeViolations = 0
            nextAction         = $NextAction
            createdAt          = $NowUtc
            updatedAt          = $NowUtc
        }
        Write-State $state
        Write-Output "Session state initialized: $StateFile (card=$Card, tier=$tierNum, role=$roleVal)"
        exit 0
    }
    'update' {
        $state = Read-State
        if ($null -eq $state) { [Console]::Error.WriteLine("No session state found at $StateFile. Run 'init' first."); exit 3 }

        if ($Tier) { $state.tier = [int]$Tier }
        if ($Branch) { $state.branch = $Branch }
        if ($Phase) { $state.phase = $Phase }
        if ($Role) { $state.activeRole = $Role }
        if ($Attempt -ge 0) { $state.attempt = $Attempt }
        if ($NextAction) { $state.nextAction = $NextAction }
        if ($IncrementBlocked) { $state.blockedDecisions = ([int]$state.blockedDecisions) + 1 }
        if ($IncrementEnvelopeViolation) { $state.envelopeViolations = ([int]$state.envelopeViolations) + 1 }

        $newDecisions = @(Split-ListItems $Decisions)
        if ($newDecisions.Count -gt 0) {
            $existing = [System.Collections.Generic.List[string]]::new()
            foreach ($d in @($state.decisionsInScope)) { if ($d) { $existing.Add([string]$d) } }
            foreach ($d in $newDecisions) { if (-not $existing.Contains($d)) { $existing.Add($d) } }
            $state.decisionsInScope = @($existing.ToArray())
        }

        $newFiles = @(Split-ListItems $FilesTouched)
        if ($newFiles.Count -gt 0) {
            $existingFiles = [System.Collections.Generic.List[string]]::new()
            foreach ($f in @($state.filesTouched)) { if ($f) { $existingFiles.Add([string]$f) } }
            foreach ($f in $newFiles) { if (-not $existingFiles.Contains($f)) { $existingFiles.Add($f) } }
            $state.filesTouched = @($existingFiles.ToArray())
        }

        if ($DeadEnd) {
            $trimmedDead = $DeadEnd.Trim()
            $existingDead = [System.Collections.Generic.List[string]]::new()
            foreach ($item in @($state.deadEnds)) { if ($item) { $existingDead.Add([string]$item) } }
            if ($trimmedDead -and -not $existingDead.Contains($trimmedDead)) {
                $existingDead.Add($trimmedDead)
            }
            $state.deadEnds = @($existingDead.ToArray())
        }

        if ($CriterionId) {
            $statusVal = if ($CriterionStatus) { $CriterionStatus } else { 'pending' }
            $criteriaArr = [System.Collections.Generic.List[object]]::new()
            $found = $false
            foreach ($c in @($state.criteria)) {
                if ($c.id -eq $CriterionId) {
                    $c.status = $statusVal
                    if ($CriterionArtifact) { $c.artifact = $CriterionArtifact }
                    $found = $true
                }
                $criteriaArr.Add($c)
            }
            if (-not $found) {
                $criteriaArr.Add([ordered]@{
                    id       = $CriterionId
                    status   = $statusVal
                    artifact = if ($CriterionArtifact) { $CriterionArtifact } else { $null }
                })
            }
            $state.criteria = @($criteriaArr.ToArray())
        }

        $state.headCommit = $CurrentHead
        $state.updatedAt = $NowUtc
        Write-State $state
        Write-Output "Session state updated: card=$($state.card) phase=$($state.phase) role=$($state.activeRole) attempt=$($state.attempt)"
        exit 0
    }
    'show' {
        $state = Read-State
        if ($null -eq $state) { Write-Output 'no active session-state'; exit 0 }
        if ($Json) {
            Write-Output ($state | ConvertTo-Json -Depth 6)
            exit 0
        }
        Write-Output "Session: $($state.card) | Tier $($state.tier) | Branch: $($state.branch) | HEAD: $($state.headCommit)"
        Write-Output "Phase: $($state.phase) | Active Role: $($state.activeRole) | Attempt: $($state.attempt)"
        if (@($state.decisionsInScope).Count -gt 0) {
            Write-Output ("Decisions in scope: " + (@($state.decisionsInScope) -join ', '))
        }
        if (@($state.criteria).Count -gt 0) {
            $critLine = (@($state.criteria) | ForEach-Object { "$($_.id)=$($_.status)" }) -join ', '
            Write-Output "Criteria: $critLine"
        }
        if (@($state.deadEnds).Count -gt 0) {
            Write-Output 'Dead ends (DO NOT REPEAT):'
            foreach ($d in @($state.deadEnds)) { Write-Output "  - $d" }
        }
        if (@($state.filesTouched).Count -gt 0) {
            Write-Output ("Files touched: " + (@($state.filesTouched) -join ', '))
        }
        if ($state.nextAction) {
            Write-Output "Next action: $($state.nextAction)"
        }
        exit 0
    }
    'close' {
        $state = Read-State
        if ($null -eq $state) { Write-Output 'no active session-state to close'; exit 0 }
        New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
        $metric = [ordered]@{
            date                = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
            closed_at           = $NowUtc
            card                = $state.card
            tier                = $state.tier
            branch              = $state.branch
            harness_attempts    = $state.attempt
            envelope_violations = $state.envelopeViolations
            blocked_decisions   = $state.blockedDecisions
            dead_ends_count     = @($state.deadEnds).Count
            rework_post_gate2   = [bool]$ReworkPostGate2
        }
        $metricLine = ($metric | ConvertTo-Json -Compress) + "`n"
        [IO.File]::AppendAllText($MetricsFile, $metricLine, $Utf8NoBom)
        if (-not $KeepState -and (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
            Remove-Item -LiteralPath $StateFile -Force
        }
        Write-Output "Session closed and metric recorded: $MetricsFile (card=$($state.card), tier=$($state.tier), attempts=$($state.attempt))"
        exit 0
    }
}
