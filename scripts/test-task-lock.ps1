#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = Split-Path -Parent $ScriptDir
$LockTool = Join-Path $PackRoot 'tools/task-lock.ps1'
$Pwsh = (Get-Process -Id $PID).Path

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('pack-task-lock-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

function Invoke-Lock {
    $output = & $Pwsh -NoProfile -File $LockTool @args -Repo $scratch 2>&1
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($output | Out-String) }
}
function New-Commit([string]$Message) {
    & git -C $scratch -c user.name=test -c user.email=test@example.invalid commit -q --allow-empty -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
}

try {
    & git -C $scratch init -q -b work
    New-Commit 'init'
    $lockFile = Join-Path $scratch '.agent-pack/.runtime/task.lock'
    $head = (& git -C $scratch rev-parse HEAD).Trim()

    $r = Invoke-Lock status
    Assert-True ($r.Exit -eq 0 -and $r.Text.Trim() -eq 'no lock') 'status without lock'

    $r = Invoke-Lock acquire -Task T-1 -Bot demand-bot
    Assert-True ($r.Exit -eq 0) 'acquire'
    $content = [IO.File]::ReadAllLines($lockFile)
    Assert-True ($content -contains 'harness=Grok Build') 'default harness'
    Assert-True ($content -contains 'task=T-1') 'task field'
    Assert-True ($content -contains 'branch=work') 'default branch'
    Assert-True ($content -contains 'bot=demand-bot') 'bot field'
    Assert-True ($content -contains "head=$head") 'head field'
    Assert-True (@($content | Where-Object { $_ -match '^acquired_at=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$' }).Count -eq 1) 'ISO 8601 timestamp'
    Assert-True ((Invoke-Lock status).Text -match '\(active\)') 'status active'

    $r = Invoke-Lock acquire -Task T-1
    Assert-True ($r.Exit -eq 0 -and $r.Text -match 'no change') 'idempotent re-acquire'

    Assert-True ((Invoke-Lock acquire -Task T-2).Exit -ne 0) 'conflict on other task'
    $r = Invoke-Lock acquire -Task T-1 -Harness 'Other Harness'
    Assert-True ($r.Exit -ne 0 -and $r.Text -match 'Task lock conflict') 'conflict on other harness'
    Assert-True ([IO.File]::ReadAllLines($lockFile) -contains 'task=T-1') 'conflict must not overwrite'

    Assert-True ((Invoke-Lock release -Task T-2).Exit -ne 0) 'release of other task without -Force'
    Assert-True (Test-Path -LiteralPath $lockFile) 'lock removed without -Force'
    Assert-True ((Invoke-Lock release -Task T-1).Exit -eq 0) 'release own task'
    Assert-True (-not (Test-Path -LiteralPath $lockFile)) 'release did not remove lock'
    Assert-True ((Invoke-Lock status).Text.Trim() -eq 'no lock') 'status after release'

    Invoke-Lock acquire -Task T-3 -Harness 'Harness A' | Out-Null
    Assert-True ((Invoke-Lock release -Force).Exit -eq 0) 'release -Force'
    Assert-True (-not (Test-Path -LiteralPath $lockFile)) 'release -Force did not remove lock'

    Invoke-Lock acquire -Task T-4 | Out-Null
    New-Commit 'second'
    Assert-True ((Invoke-Lock status).Text -match '\(expired\)') 'status expired'
    $r = Invoke-Lock acquire -Task T-5 -Harness 'Harness B'
    Assert-True ($r.Exit -eq 0 -and $r.Text -match 'expired') 'acquire over expired lock'
    Assert-True ([IO.File]::ReadAllLines($lockFile) -contains 'task=T-5') 'expired lock not overwritten'
    Invoke-Lock release -Force | Out-Null
} finally {
    if ($scratch.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $scratch) -like 'pack-task-lock-*') {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
Write-Host 'Task lock tests passed.'
