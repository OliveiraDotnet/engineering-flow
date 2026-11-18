#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = Split-Path -Parent $ScriptDir
$Pwsh = (Get-Process -Id $PID).Path
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('test-validate-pack-' + [Guid]::NewGuid().ToString('N'))

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Copy-PackWithoutGit {
    param([Parameter(Mandatory = $true)][string]$Destination)

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $PackRoot -Force) {
        if ($item.Name -eq '.git') { continue }
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $Destination $item.Name) -Recurse -Force
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Destination '.git'))) 'Temp copy must not contain .git'
}

function Invoke-NegativeCase {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Mutator
    )

    $caseDir = Join-Path $TempRoot ("neg-$Name")
    Copy-PackWithoutGit -Destination $caseDir
    & $Mutator $caseDir
    $output = & $Pwsh -NoProfile -File (Join-Path $caseDir 'scripts/validate-pack.ps1') 2>&1
    Assert-True ($LASTEXITCODE -ne 0) "Negative case '$Name' unexpectedly passed validate-pack.ps1"
}

try {
    New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

    # Positive baseline: clean copy without .git must pass validate-pack.ps1
    $validCopy = Join-Path $TempRoot 'valid'
    Copy-PackWithoutGit -Destination $validCopy
    $out = & $Pwsh -NoProfile -File (Join-Path $validCopy 'scripts/validate-pack.ps1') 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "Valid pack copy failed validate-pack.ps1: $($out | Out-String)"

    # P4 negative: removing the harness-only runner rule from harness-cycle/SKILL.md must fail
    Invoke-NegativeCase -Name 'p4-missing-harness-only-phrase' -Mutator {
        param([string]$Root)
        $skill = Join-Path $Root 'repo-template/.agents/skills/harness-cycle/SKILL.md'
        $content = [IO.File]::ReadAllText($skill)
        $updated = $content.Replace('only the harness (Implementor/Tester) runs the runners', 'the coordinator runs the runners')
        [IO.File]::WriteAllText($skill, $updated, $Utf8NoBom)
    }

    # C8 negative: injecting an obsolete version title into README.md must fail
    Invoke-NegativeCase -Name 'c8-stale-version-title' -Mutator {
        param([string]$Root)
        $readme = Join-Path $Root 'README.md'
        $stale = 'Engineering Flow ' + '4.0'
        [IO.File]::AppendAllText($readme, "`n$stale`n", $Utf8NoBom)
    }

    # N1 negative: injecting stale clean-install v5 + .0 phrase into a doc must fail
    Invoke-NegativeCase -Name 'n1-stale-v50-phrase' -Mutator {
        param([string]$Root)
        $doc = Join-Path $Root 'INSTRUCOES_DETALHADAS.md'
        $stale = 'instalação limpa da v5' + '.0'
        [IO.File]::AppendAllText($doc, "`n$stale`n", $Utf8NoBom)
    }

    # C10 negatives: removing required gate-1/external-boundary/escalation markers must fail
    Invoke-NegativeCase -Name 'c10-implementor-missing-decisions' -Mutator {
        param([string]$Root)
        $f = Join-Path $Root 'repo-template/prompts/12-implementor-harness.md'
        $content = [IO.File]::ReadAllText($f)
        [IO.File]::WriteAllText($f, $content.Replace('docs/ai/decisions-and-pendencies.md', 'docs/ai/removed.md'), $Utf8NoBom)
    }

    Invoke-NegativeCase -Name 'c10-tester-missing-boundaries' -Mutator {
        param([string]$Root)
        $f = Join-Path $Root 'repo-template/prompts/13-tester-harness.md'
        $content = [IO.File]::ReadAllText($f)
        [IO.File]::WriteAllText($f, $content.Replace('docs/ai/external-boundaries.md', 'docs/ai/removed.md'), $Utf8NoBom)
    }

    Invoke-NegativeCase -Name 'c10-skill-missing-blocked' -Mutator {
        param([string]$Root)
        $f = Join-Path $Root 'repo-template/.agents/skills/harness-cycle/SKILL.md'
        $content = [IO.File]::ReadAllText($f)
        [IO.File]::WriteAllText($f, $content.Replace('BLOCKED_BY_DECISION', 'REMOVED_MARKER'), $Utf8NoBom)
    }

    Write-Host 'test-validate-pack.ps1 passed.'
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolved = [IO.Path]::GetFullPath($TempRoot)
        $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notlike 'test-validate-pack-*') {
            throw 'Unsafe cleanup path.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
