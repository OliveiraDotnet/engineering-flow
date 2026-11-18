#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = Split-Path -Parent $ScriptDir
$HarnessDir = Join-Path $PackRoot 'repo-template/.agents/skills/harness-cycle/scripts'
$Supervisor = if ($env:EF_TEST_SUPERVISOR) { $env:EF_TEST_SUPERVISOR } else { Join-Path $HarnessDir 'supervise-harness.ps1' }
$Implementor = if ($env:EF_TEST_IMPLEMENTOR) { $env:EF_TEST_IMPLEMENTOR } else { Join-Path $HarnessDir 'run-implementor.ps1' }
$Tester = if ($env:EF_TEST_TESTER) { $env:EF_TEST_TESTER } else { Join-Path $HarnessDir 'run-tester.ps1' }
$LockTool = Join-Path $PackRoot 'tools/task-lock.ps1'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('harness-cycle-tests-' + [Guid]::NewGuid().ToString('N'))
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TEST FAILURE: $Message" }
}

function Initialize-TestRepo([string]$Path, [string]$Branch = 'fix/AB-500-calc') {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    & git -C $Path init -q -b main
    & git -C $Path config user.email 'ci@example.com'
    & git -C $Path config user.name 'CI Runner'
    [IO.File]::WriteAllText((Join-Path $Path 'value.txt'), "0`n", $Utf8NoBom)
    & git -C $Path add value.txt
    & git -C $Path commit -q -m 'initial'
    if ($Branch -ne 'main') {
        & git -C $Path checkout -q -b $Branch
    }
}

function Assert-NoLiteral([string]$Needle, [string[]]$Dirs) {
    foreach ($dir in $Dirs) {
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        $files = Get-ChildItem -LiteralPath $dir -File -Recurse
        foreach ($f in $files) {
            $hit = Select-String -LiteralPath $f.FullName -Pattern $Needle -SimpleMatch -Quiet
            Assert-True (-not $hit) "Found unmasked literal secret in $($f.FullName)"
        }
    }
}

function Invoke-PwshScript {
    param(
        [string]$ScriptPath,
        [string[]]$ScriptArgs,
        [hashtable]$EnvOverrides = @{}
    )
    $saved = @{}
    foreach ($k in $EnvOverrides.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $EnvOverrides[$k])
    }
    $prevEap = $ErrorActionPreference
    $hasNative = (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) -ne $null
    $prevNative = if ($hasNative) { $PSNativeCommandUseErrorActionPreference } else { $false }
    try {
        $ErrorActionPreference = 'Continue'
        if ($hasNative) { $PSNativeCommandUseErrorActionPreference = $false }
        $errLines = [System.Collections.Generic.List[string]]::new()
        $outLines = [System.Collections.Generic.List[string]]::new()
        $global:LASTEXITCODE = 0
        & $Pwsh -NoProfile -File $ScriptPath @ScriptArgs 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $errLines.Add($_.ToString())
            }
            else {
                $outLines.Add([string]$_)
            }
        }
        $rc = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        return [ordered]@{
            ExitCode = $rc
            Stdout   = ($outLines -join "`n")
            Stderr   = ($errLines -join "`n")
        }
    }
    finally {
        $ErrorActionPreference = $prevEap
        if ($hasNative) { $PSNativeCommandUseErrorActionPreference = $prevNative }
        foreach ($k in $saved.Keys) {
            [Environment]::SetEnvironmentVariable($k, $saved[$k])
        }
    }
}

try {
    New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

    # ==========================================================================
    # B0: Real CLI closed loop (R0-RED -> Implementor -> R0-GREEN -> Gate 2 + lock)
    # ==========================================================================
    $repo1 = Join-Path $TempRoot 'repo-b0-pass'
    Initialize-TestRepo $repo1 'fix/AB-500-fix-calculation'
    & $LockTool acquire -Task 'AB-500' -Repo $repo1 -Bot 'repo-lead' -Harness 'default' | Out-Null

    $res1 = Invoke-PwshScript -ScriptPath $Supervisor -ScriptArgs @(
        '-Repo', $repo1,
        '-CardId', 'AB-500',
        '-DemandType', 'Bug',
        '-ImplementorCommand', "Set-Content -Path value.txt -Value '1'",
        '-TestCommand', "if ((Get-Content value.txt -Raw).Trim() -ne '1') { exit 1 }",
        '-R0RedCommand', "if ((Get-Content value.txt -Raw).Trim() -ne '1') { exit 1 }",
        '-MaxRetries', '3'
    )
    Assert-True ($res1.ExitCode -eq 0) "B0: Supervisor failed on valid bugfix flow (rc=$($res1.ExitCode)): $($res1.Stderr)"

    $statusPath1 = Join-Path $repo1 '.agent-pack/.runtime/test-status.json'
    Assert-True (Test-Path -LiteralPath $statusPath1) 'B0: test-status.json was not generated.'
    $status1 = Get-Content -LiteralPath $statusPath1 -Raw | ConvertFrom-Json
    Assert-True ($status1.passed -eq $true) 'B0: Expected passed=true in test-status.json.'

    $evidencePath1 = Join-Path $repo1 '.agent-pack/evidencias/AB-500/EVIDENCIA.md'
    Assert-True (Test-Path -LiteralPath $evidencePath1) 'B0: EVIDENCIA.md was not generated.'
    $evText1 = Get-Content -LiteralPath $evidencePath1 -Raw
    Assert-True ($evText1.Contains('R0-RED') -and $evText1.Contains('APROVADO (GREEN)')) 'B0: Missing R0-RED or APROVADO (GREEN) in EVIDENCIA.md.'

    $resG2 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repo1,
        '-CardId', 'AB-500',
        '-CommitGate2',
        '-Paths', 'value.txt',
        '-CommitMessage', 'fix(AB-500): fix calculation'
    )
    Assert-True ($resG2.ExitCode -eq 0) "B0: CommitGate2 failed (rc=$($resG2.ExitCode)): $($resG2.Stderr)"
    $lastSubject = (& git -C $repo1 log -1 --pretty=%s | Select-Object -First 1).Trim()
    Assert-True ($lastSubject -eq 'fix(AB-500): fix calculation') 'B0: Gate 2 commit subject mismatch.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo1 '.agent-pack/.runtime/task.lock'))) 'B0: task.lock was not released after Gate 2 commit.'

    # B0 Retry loop via EF_ATTEMPT
    $repo2 = Join-Path $TempRoot 'repo-b0-retry'
    Initialize-TestRepo $repo2 'feat/AB-501-retry'
    $res2 = Invoke-PwshScript -ScriptPath $Supervisor -ScriptArgs @(
        '-Repo', $repo2,
        '-CardId', 'AB-501',
        '-DemandType', 'Feature',
        '-ImplementorCommand', "if (`$env:EF_ATTEMPT -eq '2') { Set-Content -Path value.txt -Value '1' }",
        '-TestCommand', "if ((Get-Content value.txt -Raw).Trim() -ne '1') { exit 1 }",
        '-MaxRetries', '3'
    )
    Assert-True ($res2.ExitCode -eq 0) "B0: Supervisor retry flow failed (rc=$($res2.ExitCode))."
    $status2 = Get-Content -LiteralPath (Join-Path $repo2 '.agent-pack/.runtime/test-status.json') -Raw | ConvertFrom-Json
    Assert-True ($status2.passed -eq $true) 'B0: Expected passed=true after retry.'

    # B0 Circuit breaker: fails 3 attempts -> exit 1 + UNABLE_TO_VALIDATE on stderr
    $repo3 = Join-Path $TempRoot 'repo-b0-fail'
    Initialize-TestRepo $repo3 'feat/AB-502-broken'
    $res3 = Invoke-PwshScript -ScriptPath $Supervisor -ScriptArgs @(
        '-Repo', $repo3,
        '-CardId', 'AB-502',
        '-DemandType', 'Feature',
        '-ImplementorCommand', "Set-Content -Path value.txt -Value 'broken'",
        '-TestCommand', "if ((Get-Content value.txt -Raw).Trim() -ne '1') { exit 1 }",
        '-MaxRetries', '3'
    )
    Assert-True ($res3.ExitCode -eq 1) "B0: Expected exit code 1 on circuit breaker, got $($res3.ExitCode)."
    Assert-True ($res3.Stderr.Contains('UNABLE_TO_VALIDATE')) 'B0: Expected UNABLE_TO_VALIDATE on stderr.'

    # ==========================================================================
    # S1: run-tester masking, commandSha256, delimited EVIDENCIA block
    # ==========================================================================
    $repoS1 = Join-Path $TempRoot 'repo-s1'
    Initialize-TestRepo $repoS1 'fix/AB-510-s1'
    $ticks = [DateTime]::UtcNow.Ticks.ToString()
    $fake1 = 'EFFAKE' + $ticks + 'SecOne'
    $fake2 = 'EFFAKE' + $ticks + 'BearTwo'
    $fakeGh = 'gh' + 'p_' + ('x' * 36)

    $s1r0 = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @(
        '-Repo', $repoS1, '-CardId', 'AB-510', '-DemandType', 'Bug', '-Phase', 'r0-red',
        '-TestCommand', "Write-Output 'password=$fake1'; Write-Output 'Authorization: Bearer $fake2'; Write-Output 'token=$fakeGh'; exit 1"
    ) -EnvOverrides @{ OSGT_API_KEY = $fake1 }
    Assert-True ($s1r0.ExitCode -eq 0) "S1-a: r0-red failed unexpectedly (rc=$($s1r0.ExitCode))."

    $s1val = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @(
        '-Repo', $repoS1, '-CardId', 'AB-510', '-DemandType', 'Bug', '-Phase', 'validate',
        '-TestCommand', "Write-Output 'password=$fake1'; Write-Output 'Authorization: Bearer $fake2'; Write-Output 'token=$fakeGh'; exit 0"
    ) -EnvOverrides @{ OSGT_API_KEY = $fake1 }
    Assert-True ($s1val.ExitCode -eq 0) "S1-a: validate failed unexpectedly (rc=$($s1val.ExitCode))."

    $s1Dirs = @(
        (Join-Path $repoS1 '.agent-pack/evidencias'),
        (Join-Path $repoS1 '.agent-pack/.runtime'),
        (Join-Path $repoS1 '.agent-pack/logs')
    )
    Assert-NoLiteral $fake1 $s1Dirs
    Assert-NoLiteral $fake2 $s1Dirs
    Assert-NoLiteral $fakeGh $s1Dirs

    $evS1 = Get-Content -LiteralPath (Join-Path $repoS1 '.agent-pack/evidencias/AB-510/EVIDENCIA.md') -Raw
    Assert-True (-not $evS1.Contains('Authorization: Bearer')) 'S1-b: Literal -TestCommand appeared in EVIDENCIA.md.'
    Assert-True ($evS1.Contains('commandSha256')) 'S1-b: commandSha256 missing from EVIDENCIA.md.'

    $outLogS1 = Join-Path $repoS1 '.agent-pack/evidencias/AB-510/test-output.log'
    Assert-True (Test-Path -LiteralPath $outLogS1) 'S1-e: test-output.log missing.'
    Assert-True ((Get-Content -LiteralPath $outLogS1 -Raw).Contains('[EF-MASKED]')) 'S1-e: [EF-MASKED] missing in test-output.log.'

    # S1-c: pre-created EVIDENCIA with BOM, CRLF, table, and sentinel stays byte-identical outside block
    $repoS1c = Join-Path $TempRoot 'repo-s1c'
    Initialize-TestRepo $repoS1c 'feat/AB-511-s1c'
    $evS1cDir = Join-Path $repoS1c '.agent-pack/evidencias/AB-511'
    New-Item -ItemType Directory -Force -Path $evS1cDir | Out-Null
    $evS1c = Join-Path $evS1cDir 'EVIDENCIA.md'
    $bomText = "# Custom Header`r`n`r`n| ID | Critério | Status |`r`n|---|---|---|`r`n| C1 | Ok | pendente |`r`n`r`n<!-- runner:begin -->`r`nold-content`r`n<!-- runner:end -->`r`n`r`nSENTINELA-FINAL-PRESERVADA`r`n"
    [IO.File]::WriteAllText($evS1c, $bomText, [Text.UTF8Encoding]::new($true))

    $getOutsideHash = {
        param([string]$path)
        $bytes = [IO.File]::ReadAllBytes($path)
        $raw = [Text.Encoding]::Latin1.GetString($bytes)
        $bp = $raw.IndexOf('<!-- runner:begin -->', [StringComparison]::Ordinal)
        $ep = $raw.IndexOf('<!-- runner:end -->', [StringComparison]::Ordinal)
        $outside = $raw.Substring(0, $bp) + '|||' + $raw.Substring($ep + '<!-- runner:end -->'.Length)
        $hashBytes = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::Latin1.GetBytes($outside))
        return [BitConverter]::ToString($hashBytes)
    }
    $outsideBefore = & $getOutsideHash $evS1c

    $r1c = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @('-Repo', $repoS1c, '-CardId', 'AB-511', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output ok1')
    Assert-True ($r1c.ExitCode -eq 0) 'S1-c: first validate failed.'
    $r2c = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @('-Repo', $repoS1c, '-CardId', 'AB-511', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output ok2')
    Assert-True ($r2c.ExitCode -eq 0) 'S1-c: second validate failed.'

    $outsideAfter = & $getOutsideHash $evS1c
    Assert-True ($outsideBefore -eq $outsideAfter) 'S1-c: Bytes outside runner block changed.'
    $evS1cText = [IO.File]::ReadAllText($evS1c, [Text.Encoding]::UTF8)
    Assert-True (([regex]::Matches($evS1cText, '<!-- runner:begin -->')).Count -eq 1) 'S1-c: Expected 1 runner:begin.'
    Assert-True (([regex]::Matches($evS1cText, '<!-- runner:end -->')).Count -eq 1) 'S1-c: Expected 1 runner:end.'

    # S1-d: orphan runner:begin -> exit 2, file hash unchanged
    [IO.File]::WriteAllText($evS1c, "`n<!-- runner:begin -->`norphan`n", $Utf8NoBom)
    $hashBefore = (Get-FileHash -LiteralPath $evS1c -Algorithm SHA256).Hash
    $r1d = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @('-Repo', $repoS1c, '-CardId', 'AB-511', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output ok3')
    Assert-True ($r1d.ExitCode -eq 2) "S1-d: Expected exit 2 for orphan marker, got $($r1d.ExitCode)."
    $hashAfter = (Get-FileHash -LiteralPath $evS1c -Algorithm SHA256).Hash
    Assert-True ($hashBefore -eq $hashAfter) 'S1-d: File was modified despite malformed markers.'

    # ==========================================================================
    # S2: run-implementor context masking
    # ==========================================================================
    $repoS2 = Join-Path $TempRoot 'repo-s2'
    Initialize-TestRepo $repoS2 'feat/AB-520-s2'
    $fake3 = 'EFFAKE' + $ticks + 'ConnThree'
    $fake4 = 'EFFAKE' + $ticks + 'EnvFour'
    $specS2 = Join-Path $TempRoot 'spec-s2.md'
    [IO.File]::WriteAllText($specS2, "# Task Spec`nconnection: Server=x;User ID=sa;Password=$fake3;`nextra: $fake4`n", $Utf8NoBom)

    $s2Res = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS2, '-CardId', 'AB-520', '-TaskSpec', $specS2, '-HarnessCommand', 'Write-Output ok'
    ) -EnvOverrides @{ EF_TEST_SECRET = $fake4 }
    Assert-True ($s2Res.ExitCode -eq 0) "S2-a: run-implementor failed (rc=$($s2Res.ExitCode))."

    $s2Dirs = @(
        (Join-Path $repoS2 '.agent-pack/.runtime'),
        (Join-Path $repoS2 '.agent-pack/evidencias'),
        (Join-Path $repoS2 '.agent-pack/logs')
    )
    Assert-NoLiteral $fake3 $s2Dirs
    Assert-NoLiteral $fake4 $s2Dirs
    $promptS2 = Join-Path $repoS2 '.agent-pack/.runtime/implementor-prompt-AB-520.md'
    Assert-True (Test-Path -LiteralPath $promptS2) 'S2-a: implementor-prompt missing.'
    Assert-True ((Get-Content -LiteralPath $promptS2 -Raw).Contains('[EF-MASKED]')) 'S2-a: [EF-MASKED] missing in implementor prompt.'

    # ==========================================================================
    # S3: Gate 2 explicit staging, protected branches, --allow-unvalidated --reason
    # ==========================================================================
    $repoS3 = Join-Path $TempRoot 'repo-s3'
    Initialize-TestRepo $repoS3 'main'
    [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "a0`n", $Utf8NoBom)
    [IO.File]::WriteAllText((Join-Path $repoS3 'b.txt'), "b0`n", $Utf8NoBom)
    [IO.File]::WriteAllText((Join-Path $repoS3 'c.txt'), "c0`n", $Utf8NoBom)
    & git -C $repoS3 add a.txt b.txt c.txt
    & git -C $repoS3 commit -q -m 'add abc'
    & git -C $repoS3 checkout -q -b 'feat/AB-530-s3'

    $s3t = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output pass')
    Assert-True ($s3t.ExitCode -eq 0) 'S3: tester validate failed.'

    # S3-a
    [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "a1`n", $Utf8NoBom)
    [IO.File]::WriteAllText((Join-Path $repoS3 'b.txt'), "b1`n", $Utf8NoBom)
    $s3a = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-CommitMessage', 'feat(AB-530): commit a only'
    )
    Assert-True ($s3a.ExitCode -eq 0) "S3-a: Gate 2 commit failed (rc=$($s3a.ExitCode)): $($s3a.Stderr)"
    $committedFiles = ((& git -C $repoS3 show --name-only --pretty='' HEAD) -join "`n").Trim()
    Assert-True ($committedFiles -eq 'a.txt') "S3-a: Expected only a.txt committed, got: $committedFiles"
    Assert-True ((Get-Content -LiteralPath (Join-Path $repoS3 'b.txt') -Raw).Trim() -eq 'b1') 'S3-a: b.txt should stay modified.'
    Assert-True ($s3a.Stdout.Contains('UNSTAGED_OUT_OF_SCOPE: b.txt')) 'S3-a: Expected UNSTAGED_OUT_OF_SCOPE: b.txt.'

    # S3-b
    $headBefore = (& git -C $repoS3 rev-parse HEAD).Trim()
    $s3b = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-CommitMessage', 'feat(AB-530): fail')
    Assert-True ($s3b.ExitCode -eq 5) "S3-b: Expected exit 5, got $($s3b.ExitCode)."
    Assert-True (((& git -C $repoS3 rev-parse HEAD).Trim()) -eq $headBefore) 'S3-b: HEAD changed.'

    # S3-c
    foreach ($badp in @('../x', '.agent-pack/x', '.agents/x', 'prompts/x', 'docs/engineering-flow/x')) {
        $s3c = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', $badp, '-CommitMessage', 'feat(AB-530): bad')
        Assert-True ($s3c.ExitCode -eq 5) "S3-c: Expected exit 5 for '$badp', got $($s3c.ExitCode)."
    }

    # S3-d
    [IO.File]::WriteAllText((Join-Path $repoS3 'c.txt'), "c1`n", $Utf8NoBom)
    $runtimeS3 = Join-Path $repoS3 '.agent-pack/.runtime'
    New-Item -ItemType Directory -Force -Path $runtimeS3 | Out-Null
    $taskSpecS3 = Join-Path $runtimeS3 'TASK_SPEC.md'
    [IO.File]::WriteAllText($taskSpecS3, "## Staging`n<!-- ef:paths:begin -->`n- ``c.txt```n<!-- ef:paths:end -->`n", $Utf8NoBom)
    $s3d = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-CommitMessage', 'feat(AB-530): commit c from spec')
    Assert-True ($s3d.ExitCode -eq 0) "S3-d: Gate 2 commit from TASK_SPEC failed (rc=$($s3d.ExitCode))."
    Assert-True ((((& git -C $repoS3 show --name-only --pretty='' HEAD) -join "`n").Trim()) -eq 'c.txt') 'S3-d: Expected c.txt committed.'
    Remove-Item -LiteralPath $taskSpecS3 -Force

    # S3-e: main without config, EF_PROTECTED_BRANCHES=new-hom, AGENTS.md protected branches
    & git -C $repoS3 checkout -q -- b.txt
    & git -C $repoS3 checkout -q main
    $headMain = (& git -C $repoS3 rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "m1`n", $Utf8NoBom)
    $s3eMain = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-CommitMessage', 'feat: main')
    Assert-True ($s3eMain.ExitCode -eq 3) "S3-e: Expected exit 3 on main, got $($s3eMain.ExitCode)."
    Assert-True (((& git -C $repoS3 rev-parse HEAD).Trim()) -eq $headMain) 'S3-e: main HEAD changed.'
    & git -C $repoS3 checkout -q -- a.txt

    & git -C $repoS3 checkout -q -b new-hom
    $headNh = (& git -C $repoS3 rev-parse HEAD).Trim()
    [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "nh1`n", $Utf8NoBom)
    $s3eNh = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-CommitMessage', 'feat: nh') -EnvOverrides @{ EF_PROTECTED_BRANCHES = 'new-hom' }
    Assert-True ($s3eNh.ExitCode -eq 3) "S3-e: Expected exit 3 with EF_PROTECTED_BRANCHES=new-hom, got $($s3eNh.ExitCode)."
    Assert-True (((& git -C $repoS3 rev-parse HEAD).Trim()) -eq $headNh) 'S3-e: new-hom HEAD changed.'
    & git -C $repoS3 checkout -q -- a.txt

    & git -C $repoS3 checkout -q feat/AB-530-s3
    [IO.File]::WriteAllText((Join-Path $repoS3 'AGENTS.md'), "# Repo`n## Convenções do projeto`n- Branches protegidas (harness): develop, demarchi, hom-demarchi, new-hom`n", $Utf8NoBom)
    & git -C $repoS3 add AGENTS.md
    & git -C $repoS3 commit -q -m 'add AGENTS.md'

    foreach ($pb in @('develop', 'demarchi', 'hom-demarchi', 'new-hom')) {
        & git -C $repoS3 checkout -q -B $pb
        $hb = (& git -C $repoS3 rev-parse HEAD).Trim()
        [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "pb`n", $Utf8NoBom)
        $s3ePb = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-CommitMessage', 'feat: pb')
        Assert-True ($s3ePb.ExitCode -eq 3) "S3-e: Expected exit 3 on '$pb', got $($s3ePb.ExitCode)."
        Assert-True (((& git -C $repoS3 rev-parse HEAD).Trim()) -eq $hb) "S3-e: HEAD changed on '$pb'."
        & git -C $repoS3 checkout -q -- a.txt
    }

    # S3-f
    & git -C $repoS3 checkout -q feat/AB-530-s3
    Remove-Item -LiteralPath (Join-Path $repoS3 '.agent-pack/.runtime/test-status.json') -Force
    [IO.File]::WriteAllText((Join-Path $repoS3 'a.txt'), "u1`n", $Utf8NoBom)

    $s3f1 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-AllowUnvalidated', '-CommitMessage', 'feat: no reason')
    Assert-True ($s3f1.ExitCode -eq 2) "S3-f: Expected exit 2 without -Reason, got $($s3f1.ExitCode)."

    $s3f2 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-AllowUnvalidated', '-Reason', 'curto', '-CommitMessage', 'feat: short')
    Assert-True ($s3f2.ExitCode -eq 2) "S3-f: Expected exit 2 for short -Reason, got $($s3f2.ExitCode)."

    $s3f3 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS3, '-CardId', 'AB-530', '-CommitGate2', '-Paths', 'a.txt', '-AllowUnvalidated', '-Reason', 'Hotfix emergencial aprovado pelo TL', '-CommitMessage', 'feat(AB-530): allow unvalidated')
    Assert-True ($s3f3.ExitCode -eq 0) "S3-f: Commit with -AllowUnvalidated -Reason failed (rc=$($s3f3.ExitCode))."
    $stS3f = Get-Content -LiteralPath (Join-Path $repoS3 '.agent-pack/.runtime/test-status.json') -Raw | ConvertFrom-Json
    Assert-True ($stS3f.allowUnvalidated -eq $true) 'S3-f: allowUnvalidated=true missing.'
    Assert-True ($stS3f.allowUnvalidatedReason -eq 'Hotfix emergencial aprovado pelo TL') 'S3-f: allowUnvalidatedReason mismatch.'
    $evS3f = Get-Content -LiteralPath (Join-Path $repoS3 '.agent-pack/evidencias/AB-530/EVIDENCIA.md') -Raw
    Assert-True ($evS3f.Contains('allowUnvalidated: true')) 'S3-f: allowUnvalidated line missing in EVIDENCIA.md.'

    # ==========================================================================
    # S4: Harness capture, EF_SECRET_VALUES_FILE, ef_scan (exit 6), EF_SECRET_NAMES, recovery
    # ==========================================================================
    $repoS4 = Join-Path $TempRoot 'repo-s4'
    Initialize-TestRepo $repoS4 'fix/AB-540-s4'
    New-Item -ItemType Directory -Force -Path (Join-Path $repoS4 'db') | Out-Null

    $fake5Part = 'EFFAKE' + $ticks + 'Sql'
    $fake5 = $fake5Part + '/"Five'
    $fake5Escaped = $fake5Part + '\/\"Five'
    $fake6 = 'EFFAKE' + $ticks + 'HdrSix'

    [IO.File]::WriteAllText((Join-Path $repoS4 'db/consolidado.sql'), "INSERT INTO cfg(val) VALUES ('$fake5');`n", $Utf8NoBom)
    & git -C $repoS4 add db/consolidado.sql
    & git -C $repoS4 commit -q -m 'add sql'

    $secretValsOutside = Join-Path $TempRoot 'outside-secrets.txt'
    [IO.File]::WriteAllText($secretValsOutside, "$fake5`n", $Utf8NoBom)

    $fakeBin = Join-Path $TempRoot 'fake-bin'
    New-Item -ItemType Directory -Force -Path $fakeBin | Out-Null
    $effortMarker = Join-Path $TempRoot 'agy-saw-effort-high'
    $fakeAgyPs1 = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)
$sawEffort = $false
for ($i = 0; $i -lt $CliArgs.Count; $i++) {
    if ($CliArgs[$i] -eq '--effort' -and ($i + 1) -lt $CliArgs.Count -and $CliArgs[$i + 1] -eq 'high') {
        $sawEffort = $true
    }
}
if (-not $sawEffort) {
    [Console]::Error.WriteLine('missing --effort high')
    exit 11
}
if ($env:EF_FAKE_MARKER) { Set-Content -Path $env:EF_FAKE_MARKER -Value 'ok' }
if ($env:EF_FAKE_XAPI) {
    Write-Output '{"type":"init"}'
    Write-Output ('{"type":"header","content":"X-Api-Key: ' + $env:EF_FAKE_XAPI + '"}')
    Write-Output '{"type":"result","status":"ok"}'
} else {
    $sqlLine = (Get-Content -Path 'db/consolidado.sql' | Select-Object -First 1)
    $escaped = $sqlLine.Replace('\', '\\').Replace('"', '\"').Replace('/', '\/')
    Write-Output '{"type":"init"}'
    Write-Output ('{"type":"tool_result","content":"' + $escaped + '"}')
    Write-Output '{"type":"result","status":"ok"}'
}
'@
    [IO.File]::WriteAllText((Join-Path $fakeBin 'agy.ps1'), $fakeAgyPs1, $Utf8NoBom)

    # S4-a
    $s4a = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-Harness', 'agy'
    ) -EnvOverrides @{
        PATH                  = $fakeBin + [IO.Path]::PathSeparator + $env:PATH
        EF_SECRET_VALUES_FILE = $secretValsOutside
        EF_FAKE_MARKER        = $effortMarker
    }
    Assert-True ($s4a.ExitCode -eq 0) "S4-a: run-implementor -Harness agy failed (rc=$($s4a.ExitCode)): $($s4a.Stderr)"
    Assert-True (Test-Path -LiteralPath $effortMarker) 'S4-a: fake agy did not receive --effort high.'

    $logS4a = Join-Path $repoS4 '.agent-pack/logs/AB-540/AB-540_implementor_attempt1.jsonl'
    Assert-True (Test-Path -LiteralPath $logS4a) 'S4-a: captured .jsonl log missing.'
    Assert-True ((Get-Content -LiteralPath $logS4a -Raw).Contains('[EF-MASKED]')) 'S4-a: [EF-MASKED] missing in .jsonl log.'
    $s4Dirs = @(
        (Join-Path $repoS4 '.agent-pack/logs'),
        (Join-Path $repoS4 '.agent-pack/evidencias'),
        (Join-Path $repoS4 '.agent-pack/.runtime')
    )
    Assert-NoLiteral $fake5 $s4Dirs
    Assert-NoLiteral $fake5Escaped $s4Dirs

    # S4-c
    $insideSecrets = Join-Path $repoS4 'inside-secrets.txt'
    [IO.File]::WriteAllText($insideSecrets, "$fake5`n", $Utf8NoBom)
    $s4c = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-HarnessCommand', 'Write-Output ok'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $insideSecrets }
    Assert-True ($s4c.ExitCode -eq 2) "S4-c: Expected exit 2 for EF_SECRET_VALUES_FILE inside repo, got $($s4c.ExitCode)."
    Remove-Item -LiteralPath $insideSecrets -Force

    # S4-d
    $s4d1 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS4, '-CardId', 'AB-540', '-Harness', 'agy', '-HarnessArgs', '--effort medium')
    Assert-True ($s4d1.ExitCode -eq 2) "S4-d: Expected exit 2 for agy --effort medium, got $($s4d1.ExitCode)."
    $s4d2 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @('-Repo', $repoS4, '-CardId', 'AB-540', '-Harness', 'grok')
    Assert-True ($s4d2.ExitCode -eq 2) "S4-d: Expected exit 2 for grok without -HarnessArgs, got $($s4d2.ExitCode)."

    # S4-e
    $s4e = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-Harness', 'agy'
    ) -EnvOverrides @{
        PATH            = $fakeBin + [IO.Path]::PathSeparator + $env:PATH
        EF_SECRET_NAMES = 'X-Api-Key'
        EF_FAKE_XAPI    = $fake6
        EF_ATTEMPT      = '2'
    }
    Assert-True ($s4e.ExitCode -eq 0) "S4-e: run-implementor failed (rc=$($s4e.ExitCode))."
    $logS4e = Join-Path $repoS4 '.agent-pack/logs/AB-540/AB-540_implementor_attempt2.jsonl'
    Assert-True ((Get-Content -LiteralPath $logS4e -Raw).Contains('X-Api-Key: [EF-MASKED]')) 'S4-e: Expected X-Api-Key: [EF-MASKED] in log.'
    Assert-NoLiteral $fake6 $s4Dirs

    # S4-b: adhoc.jsonl bypasses capture -> scan exits 6, masks adhoc.jsonl, blocks Gate 2 & supervisor
    $adhocLog = Join-Path $repoS4 '.agent-pack/logs/AB-540/adhoc.jsonl'
    [IO.File]::WriteAllText($adhocLog, "{`"type`":`"tool_result`",`"content`":`"$fake5`"}`n", $Utf8NoBom)

    $s4bTest = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output ok'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4bTest.ExitCode -eq 6) "S4-b: Expected exit 6 on SECRET_IN_LOG in run-tester, got $($s4bTest.ExitCode)."
    $stS4b = Get-Content -LiteralPath (Join-Path $repoS4 '.agent-pack/.runtime/test-status.json') -Raw | ConvertFrom-Json
    Assert-True ($stS4b.passed -eq $false -and $stS4b.reason -eq 'SECRET_IN_LOG') 'S4-b: Expected passed=false and reason=SECRET_IN_LOG.'
    Assert-True ((Get-Content -LiteralPath $adhocLog -Raw).Contains('[EF-MASKED]')) 'S4-b: adhoc.jsonl should be masked in place.'
    Assert-NoLiteral $fake5 $s4Dirs

    [IO.File]::WriteAllText((Join-Path $repoS4 'value.txt'), "fix`n", $Utf8NoBom)
    $headS4 = (& git -C $repoS4 rev-parse HEAD).Trim()
    $s4bG1 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-CommitGate2', '-Paths', 'value.txt', '-CommitMessage', 'fix: blocked'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4bG1.ExitCode -eq 6) "S4-b: Expected exit 6 on -CommitGate2, got $($s4bG1.ExitCode)."
    Assert-True (((& git -C $repoS4 rev-parse HEAD).Trim()) -eq $headS4) 'S4-b: HEAD changed during blocked Gate 2.'

    $s4bG2 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-CommitGate2', '-Paths', 'value.txt',
        '-AllowUnvalidated', '-Reason', 'Tentativa de contornar SECRET_IN_LOG', '-CommitMessage', 'fix: blocked2'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4bG2.ExitCode -eq 6) "S4-b: Expected exit 6 on -CommitGate2 -AllowUnvalidated, got $($s4bG2.ExitCode)."
    Assert-True (((& git -C $repoS4 rev-parse HEAD).Trim()) -eq $headS4) 'S4-b: HEAD changed with -AllowUnvalidated.'

    # Supervisor aborts immediately with exit 6 without retrying
    [IO.File]::WriteAllText($adhocLog, "{`"type`":`"tool_result`",`"content`":`"$fake5`"}`n", $Utf8NoBom)
    $supAttempts = Join-Path $TempRoot 'sup-attempts.txt'
    $s4bSup = Invoke-PwshScript -ScriptPath $Supervisor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-DemandType', 'Feature',
        '-ImplementorCommand', "Add-Content -Path '$supAttempts' -Value 'attempt'",
        '-TestCommand', 'Write-Output ok', '-MaxRetries', '3'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4bSup.ExitCode -eq 6) "S4-b: Expected supervisor exit 6, got $($s4bSup.ExitCode)."
    Assert-True (@(Get-Content -LiteralPath $supAttempts).Count -eq 1) 'S4-b: Supervisor should not retry after exit 6.'

    # S4-f: Clean run-tester -Phase validate unblocks Gate 2
    $s4fTest = Invoke-PwshScript -ScriptPath $Tester -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-DemandType', 'Feature', '-Phase', 'validate', '-TestCommand', 'Write-Output clean'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4fTest.ExitCode -eq 0) "S4-f: Expected exit 0 on clean validate, got $($s4fTest.ExitCode)."
    $stS4f = Get-Content -LiteralPath (Join-Path $repoS4 '.agent-pack/.runtime/test-status.json') -Raw | ConvertFrom-Json
    Assert-True ($stS4f.passed -eq $true -and $null -eq $stS4f.reason -and $stS4f.secretScan.status -eq 'clean') 'S4-f: Expected passed=true, reason=null, secretScan.status=clean.'

    $s4fG2 = Invoke-PwshScript -ScriptPath $Implementor -ScriptArgs @(
        '-Repo', $repoS4, '-CardId', 'AB-540', '-CommitGate2', '-Paths', 'value.txt', '-CommitMessage', 'fix(AB-540): clean gate2 commit'
    ) -EnvOverrides @{ EF_SECRET_VALUES_FILE = $secretValsOutside }
    Assert-True ($s4fG2.ExitCode -eq 0) "S4-f: Gate 2 commit failed after clean validate (rc=$($s4fG2.ExitCode)): $($s4fG2.Stderr)"
    Assert-True (((& git -C $repoS4 log -1 --pretty=%s | Select-Object -First 1).Trim()) -eq 'fix(AB-540): clean gate2 commit') 'S4-f: Commit subject mismatch.'

    Write-Host 'Harness cycle PowerShell tests passed: B0, S1-a..e, S2-a, S3-a..f, S4-a..f.'
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
