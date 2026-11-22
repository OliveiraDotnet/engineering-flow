#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackRoot = Split-Path -Parent $PSScriptRoot
$Verifier = Join-Path $PackRoot 'tools/verify-envelope.ps1'
$Protector = Join-Path $PackRoot 'scripts/protect-engineering-flow-files.ps1'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('test-verify-envelope-' + [Guid]::NewGuid().ToString('N'))
$Utf8 = [Text.UTF8Encoding]::new($false)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
    & git -C $TempRoot init -b main -q
    & $Protector -RepoPath $TempRoot | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $TempRoot 'src') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/App.cs'), "public class App {}`n", $Utf8)
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Other.cs'), "public class Other {}`n", $Utf8)
    & git -C $TempRoot add .gitignore src
    & git -C $TempRoot -c user.name="Test" -c user.email="test@example.com" commit -q -m "init"

    $rt = Join-Path $TempRoot '.agent-pack/.runtime'
    New-Item -ItemType Directory -Path $rt -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $rt 'TASK_SPEC.md'), @"
# TASK_SPEC AB-601
<!-- ef:paths:begin -->
- src/App.cs
<!-- ef:paths:end -->
"@, $Utf8)
    [IO.File]::WriteAllText((Join-Path $rt 'test-status.json'), '{"passed":true,"reason":null,"secretScan":{"status":"clean"}}', $Utf8)

    # Case 1: Protected branch (main) must fail with exit 10
    $null = & $Verifier -Repo $TempRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 10) "Expected exit 10 on main branch, got $LASTEXITCODE"

    # Switch to card branch
    & git -C $TempRoot checkout -b feat/AB-601-test -q

    # Case 2: Valid change strictly inside ef:paths + clean test-status -> exit 0
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/App.cs'), "public class App { public int V => 1; }`n", $Utf8)
    $okOut = (& $Verifier -Repo $TempRoot 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -eq 0 -and $okOut.Contains('ENVELOPE_OK')) "Expected ENVELOPE_OK (exit 0), got exit $LASTEXITCODE : $okOut"

    # Case 3: Out-of-envelope edit must fail with exit 11
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Other.cs'), "public class Other { public int Bad => 1; }`n", $Utf8)
    $null = & $Verifier -Repo $TempRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 11) "Expected exit 11 for out-of-envelope file, got $LASTEXITCODE"
    & git -C $TempRoot checkout -- src/Other.cs

    # Case 4: SECRET_IN_LOG must fail with exit 13
    [IO.File]::WriteAllText((Join-Path $rt 'test-status.json'), '{"passed":false,"reason":"SECRET_IN_LOG","secretScan":{"status":"dirty"}}', $Utf8)
    $null = & $Verifier -Repo $TempRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 13) "Expected exit 13 for SECRET_IN_LOG, got $LASTEXITCODE"

    # Case 5: Operational file force-staged must fail with exit 12
    [IO.File]::WriteAllText((Join-Path $rt 'test-status.json'), '{"passed":true,"reason":null,"secretScan":{"status":"clean"}}', $Utf8)
    & git -C $TempRoot add -f '.agent-pack/.runtime/TASK_SPEC.md'
    $null = & $Verifier -Repo $TempRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 12) "Expected exit 12 for staged operational file, got $LASTEXITCODE"

    Write-Host 'test-verify-envelope.ps1 passed.'
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolved = [IO.Path]::GetFullPath($TempRoot)
        $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'test-verify-envelope-*') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
