#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackRoot = Split-Path -Parent $PSScriptRoot
$Tool = Join-Path $PackRoot 'tools/session-state.ps1'
$Protector = Join-Path $PackRoot 'scripts/protect-engineering-flow-files.ps1'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('test-session-state-' + [Guid]::NewGuid().ToString('N'))

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
    & git -C $TempRoot init -q
    Assert-True ($LASTEXITCODE -eq 0) 'Unable to initialize temp git repo.'

    # Apply EF gitignore protection to verify 99.9% decoupling (runtime files must stay ignored)
    & $Protector -RepoPath $TempRoot | Out-Null

    # 1. init
    & $Tool init -Repo $TempRoot -Card 'AB-600' -Tier '1' -Branch 'fix/AB-600-cache' -Role 'Tech Lead' -Criteria 'R0,C1' -Decisions 'D01,D02' -NextAction 'Validar R0-RED' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'session-state init failed.'

    $statePath = Join-Path $TempRoot '.agent-pack/.runtime/session-state.json'
    Assert-True (Test-Path -LiteralPath $statePath -PathType Leaf) 'session-state.json not created.'

    # Verify git ignores session-state.json
    & git -C $TempRoot check-ignore -q -- '.agent-pack/.runtime/session-state.json'
    Assert-True ($LASTEXITCODE -eq 0) 'session-state.json must be ignored by Git.'

    # 2. update + dead_ends deduplication + criteria status
    & $Tool update -Repo $TempRoot -Phase 'implementacao' -Role 'Implementor' -Attempt 1 -CriterionId 'R0' -CriterionStatus 'verified_red' -CriterionArtifact '.agent-pack/evidencias/AB-600/r0-red.log' -DeadEnd 'CultureInfo.CurrentCulture falhou em pt-BR' -FilesTouched 'src/Pricing.cs' -IncrementBlocked -NextAction 'Aplicar InvariantCulture' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'session-state update #1 failed.'

    # Duplicate dead-end must not duplicate
    & $Tool update -Repo $TempRoot -Attempt 2 -DeadEnd 'CultureInfo.CurrentCulture falhou em pt-BR' -CriterionId 'R0' -CriterionStatus 'verified' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'session-state update #2 failed.'

    $rawJson = (& $Tool show -Repo $TempRoot -Json) -join "`n"
    $state = $rawJson | ConvertFrom-Json
    Assert-True ($state.card -eq 'AB-600') "Unexpected card: $($state.card)"
    Assert-True ($state.tier -eq 1) "Unexpected tier: $($state.tier)"
    Assert-True ($state.attempt -eq 2) "Unexpected attempt: $($state.attempt)"
    Assert-True ($state.blockedDecisions -eq 1) "Unexpected blockedDecisions: $($state.blockedDecisions)"
    Assert-True (@($state.deadEnds).Count -eq 1) "deadEnds should deduplicate; got $(@($state.deadEnds).Count)"
    $r0 = @($state.criteria | Where-Object { $_.id -eq 'R0' })[0]
    Assert-True ($r0.status -eq 'verified') "Expected R0=verified, got $($r0.status)"

    $summaryOut = (& $Tool show -Repo $TempRoot) -join "`n"
    Assert-True ($summaryOut.Contains('Dead ends (DO NOT REPEAT):')) 'Compact show output missing dead ends section.'

    # 3. close -> records metrics.jsonl, removes session-state.json and cleans transient runtime files (keeping repo-map.txt & metrics.jsonl)
    $runtimeDir = Join-Path $TempRoot '.agent-pack/.runtime'
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    foreach ($transient in @('TASK_SPEC.md', 'test-status.json', 'NEXT_PROMPT.md', 'implementor-prompt-AB-600.md')) {
        [IO.File]::WriteAllText((Join-Path $runtimeDir $transient), "transient`n", $utf8NoBom)
    }
    $repoMapPath = Join-Path $runtimeDir 'repo-map.txt'
    [IO.File]::WriteAllText($repoMapPath, "# repo-map cache`n", $utf8NoBom)

    & $Tool close -Repo $TempRoot | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'session-state close failed.'
    Assert-True (-not (Test-Path -LiteralPath $statePath)) 'session-state.json should be removed on close.'
    foreach ($transient in @('TASK_SPEC.md', 'test-status.json', 'NEXT_PROMPT.md', 'implementor-prompt-AB-600.md')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $runtimeDir $transient))) "Transient runtime file should be removed on close: $transient"
    }
    Assert-True (Test-Path -LiteralPath $repoMapPath -PathType Leaf) 'repo-map.txt must be preserved on close.'

    $metricsPath = Join-Path $TempRoot '.agent-pack/.runtime/metrics.jsonl'
    Assert-True (Test-Path -LiteralPath $metricsPath -PathType Leaf) 'metrics.jsonl not created.'
    & git -C $TempRoot check-ignore -q -- '.agent-pack/.runtime/metrics.jsonl'
    Assert-True ($LASTEXITCODE -eq 0) 'metrics.jsonl must be ignored by Git.'

    $metricLines = [IO.File]::ReadAllLines($metricsPath)
    Assert-True ($metricLines.Count -eq 1) "Expected 1 metric line, got $($metricLines.Count)"
    $metric = $metricLines[0] | ConvertFrom-Json
    Assert-True ($metric.card -eq 'AB-600' -and $metric.tier -eq 1 -and $metric.harness_attempts -eq 2 -and $metric.dead_ends_count -eq 1 -and $metric.rework_post_gate2 -eq $false) 'Metric payload mismatch.'

    Write-Host 'test-session-state.ps1 passed.'
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolved = [IO.Path]::GetFullPath($TempRoot)
        $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'test-session-state-*') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
