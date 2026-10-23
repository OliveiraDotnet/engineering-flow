#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('acquire', 'release', 'status')]
    [string]$Command,
    [string]$Task = '',
    [string]$Harness = 'Grok Build',
    [string]$Branch = '',
    [string]$Bot = '',
    [string]$Repo = '.',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (& git -C $Repo rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) { [Console]::Error.WriteLine("Not a git repository: $Repo"); exit 1 }
$RepoRoot = $RepoRoot.Trim()
$LockDir = Join-Path $RepoRoot '.agent-pack/.runtime'
$LockFile = Join-Path $LockDir 'task.lock'
$CurrentHead = (& git -C $RepoRoot rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $CurrentHead) { $CurrentHead = 'none' } else { $CurrentHead = $CurrentHead.Trim() }

function Read-Lock {
    $data = @{}
    foreach ($line in [IO.File]::ReadAllLines($LockFile)) {
        $index = $line.IndexOf('=')
        if ($index -gt 0) { $data[$line.Substring(0, $index)] = $line.Substring($index + 1).TrimEnd("`r") }
    }
    return $data
}

function Get-Field([hashtable]$Data, [string]$Key) {
    if ($Data.ContainsKey($Key)) { return $Data[$Key] }
    return ''
}

function Get-LockState {
    if (-not (Test-Path -LiteralPath $LockFile -PathType Leaf)) { return 'none' }
    if ((Get-Field (Read-Lock) 'head') -eq $CurrentHead) { return 'active' }
    return 'expired'
}

$state = Get-LockState
switch ($Command) {
    'status' {
        if ($state -eq 'none') { Write-Output 'no lock'; exit 0 }
        $lock = Read-Lock
        Write-Output "Lock: $LockFile ($state)"
        foreach ($key in @('harness', 'task', 'branch', 'bot', 'acquired_at', 'head')) {
            Write-Output ('  {0,-12} {1}' -f "${key}:", (Get-Field $lock $key))
        }
        if ($state -eq 'expired') { Write-Output "  HEAD changed to $CurrentHead; lock expired by commit." }
        exit 0
    }
    'acquire' {
        if (-not $Task) { [Console]::Error.WriteLine('acquire requires -Task <id>'); exit 2 }
        if (-not $Branch) {
            $Branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
            if ($LASTEXITCODE -ne 0 -or -not $Branch) { $Branch = 'unknown' } else { $Branch = $Branch.Trim() }
        }
        if ($state -eq 'active') {
            $lock = Read-Lock
            $heldTask = Get-Field $lock 'task'
            $heldHarness = Get-Field $lock 'harness'
            if ($heldTask -eq $Task -and $heldHarness -eq $Harness) {
                Write-Output "Lock already held by '$Harness' for task '$Task' (no change)."
                exit 0
            }
            [Console]::Error.WriteLine("Task lock conflict: held by harness '$heldHarness' for task '$heldTask' (branch '$(Get-Field $lock 'branch')', since $(Get-Field $lock 'acquired_at')).")
            [Console]::Error.WriteLine('Wait for release, or have the demand bot run: task-lock.ps1 release -Force')
            exit 3
        }
        if ($state -eq 'expired') { Write-Output 'Previous lock expired (HEAD changed); overwriting.' }
        New-Item -ItemType Directory -Path $LockDir -Force | Out-Null
        $content = @(
            "harness=$Harness",
            "task=$Task",
            "branch=$Branch",
            "bot=$Bot",
            "acquired_at=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
            "head=$CurrentHead"
        ) -join "`n"
        $tmp = "$LockFile.tmp.$PID"
        [IO.File]::WriteAllText($tmp, $content + "`n", [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $LockFile -Force
        Write-Output "Lock acquired by '$Harness' for task '$Task' on branch '$Branch' at HEAD $CurrentHead."
        exit 0
    }
    'release' {
        if ($state -eq 'none') { Write-Output 'no lock'; exit 0 }
        $heldTask = Get-Field (Read-Lock) 'task'
        if (-not $Force -and $state -eq 'active' -and ((-not $Task) -or $Task -ne $heldTask)) {
            [Console]::Error.WriteLine("Lock belongs to task '$heldTask'. Pass -Task $heldTask, or use -Force to release a forgotten lock.")
            exit 4
        }
        Remove-Item -LiteralPath $LockFile -Force
        Write-Output "Lock released (task '$heldTask')."
        exit 0
    }
}
