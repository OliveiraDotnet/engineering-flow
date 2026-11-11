#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = Split-Path -Parent $ScriptDir
$Supervisor = Join-Path $PackRoot "repo-template/.agents/skills/harness-cycle/scripts/supervise-harness.ps1"
$Implementor = Join-Path $PackRoot "repo-template/.agents/skills/harness-cycle/scripts/run-implementor.ps1"
$LockTool = Join-Path $PackRoot "tools/task-lock.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("harness-cycle-tests-" + [Guid]::NewGuid().ToString("N"))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TEST FAILURE: $Message" }
}

function Initialize-TestRepo([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    & git -C $Path init -q
    & git -C $Path config user.email "ci@example.com"
    & git -C $Path config user.name "CI Runner"
    [IO.File]::WriteAllText((Join-Path $Path "value.txt"), "0`n", [Text.UTF8Encoding]::new($false))
    & git -C $Path add value.txt
    & git -C $Path commit -q -m "initial"
}

try {
    # 1. Closed-loop R0-RED -> Implementor -> R0-GREEN -> FULL -> Gate 2 commit
    $repo1 = Join-Path $TempRoot "repo-pass"
    Initialize-TestRepo $repo1
    & $LockTool acquire -Task "AB-500" -Repo $repo1 -Bot "repo-lead" -Harness "default" | Out-Null

    & $Supervisor `
        -RepoPath $repo1 `
        -Card "AB-500" `
        -Slug "fix-calculation" `
        -Type "bug" `
        -HarnessCommand "printf '1\n' > value.txt" `
        -TestCommand "grep -Fxq '1' value.txt" `
        -R0Command "grep -Fxq '1' value.txt" `
        -MaxAttempts 3 | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "Supervisor failed on valid bugfix flow."

    $statusPath1 = Join-Path $repo1 ".agent-pack/.runtime/test-status.json"
    Assert-True (Test-Path -LiteralPath $statusPath1) "test-status.json was not generated."
    Assert-True ((Get-Content -LiteralPath $statusPath1 -Raw) -match '"status":\s*"PASSED"') "Expected PASSED in test-status.json."

    $evidencePath1 = Join-Path $repo1 ".agent-pack/evidencias/AB-500/EVIDENCIA.md"
    Assert-True (Test-Path -LiteralPath $evidencePath1) "EVIDENCIA.md was not generated."
    $evidenceText1 = Get-Content -LiteralPath $evidencePath1 -Raw
    Assert-True ($evidenceText1.Contains("R0-RED") -and $evidenceText1.Contains("R0-GREEN")) "Missing R0-RED or R0-GREEN in EVIDENCIA.md."

    & $Implementor `
        -RepoPath $repo1 `
        -Card "AB-500" `
        -Slug "fix-calculation" `
        -Type "bug" `
        -CommitGate2 `
        -CommitMessage "fix(AB-500): fix calculation" | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "CommitGate2 failed."
    $lastSubject = (& git -C $repo1 log -1 --pretty=%s | Select-Object -First 1).Trim()
    Assert-True ($lastSubject -eq "fix(AB-500): fix calculation") "Gate 2 commit subject mismatch."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo1 ".agent-pack/.runtime/task.lock"))) "task.lock was not released after Gate 2 commit."

    # 2. Retry loop: fails attempt 1, succeeds attempt 2
    $repo2 = Join-Path $TempRoot "repo-retry"
    Initialize-TestRepo $repo2
    & $Supervisor `
        -RepoPath $repo2 `
        -Card "AB-501" `
        -Slug "retry-feature" `
        -Type "feature" `
        -HarnessCommand "if [ `"`$HARNESS_ATTEMPT`" = '2' ]; then printf '1\n' > value.txt; fi" `
        -TestCommand "grep -Fxq '1' value.txt" `
        -MaxAttempts 3 | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "Supervisor retry flow failed."

    # 3. 3-strike circuit breaker
    $repo3 = Join-Path $TempRoot "repo-fail"
    Initialize-TestRepo $repo3
    $global:LASTEXITCODE = 0
    & $Supervisor `
        -RepoPath $repo3 `
        -Card "AB-502" `
        -Slug "broken-feature" `
        -Type "feature" `
        -HarnessCommand "printf 'still-broken\n' > value.txt" `
        -TestCommand "grep -Fxq '1' value.txt" `
        -MaxAttempts 3 | Out-Null
    Assert-True ($LASTEXITCODE -eq 4) "Expected exit code 4 on 3-strike circuit breaker, got $LASTEXITCODE."
    $summary3 = Get-Content -LiteralPath (Join-Path $repo3 ".agent-pack/.runtime/harness-cycle-summary.md") -Raw
    Assert-True ($summary3.Contains("UNABLE_TO_VALIDATE")) "Expected UNABLE_TO_VALIDATE in summary."

    Write-Host "Harness cycle PowerShell tests passed: R0-RED/GREEN, FULL evidence, retry loop, 3-strike circuit breaker, and Gate 2 commit + lock expiration."
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
