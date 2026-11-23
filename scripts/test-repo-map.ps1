#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackRoot = Split-Path -Parent $PSScriptRoot
$Inspector = Join-Path $PackRoot 'repo-template/.agents/skills/bootstrap-repo/scripts/inspect-repo.ps1'
$Protector = Join-Path $PackRoot 'scripts/protect-engineering-flow-files.ps1'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('test-repo-map-' + [Guid]::NewGuid().ToString('N'))
$Utf8 = [Text.UTF8Encoding]::new($false)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
    & git -C $TempRoot init -q
    Assert-True ($LASTEXITCODE -eq 0) 'git init failed.'

    & $Protector -RepoPath $TempRoot | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $TempRoot 'src/Billing') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Billing/InvoiceService.cs'), @"
namespace Billing;
public class InvoiceService
{
    private const string FakeSecret = "SuperSecretValue12345";
    public void Process() {}
}
public interface IInvoiceGateway {}
"@, $Utf8)
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Billing/schema.sql'), @"
CREATE TABLE dbo.Invoices (Id INT PRIMARY KEY);
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetInvoices AS SELECT 1;
"@, $Utf8)
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Billing/client.ts'), @"
export interface InvoiceDto { id: number; }
export async function fetchInvoices() { return "AnotherSecretBody999"; }
"@, $Utf8)

    & git -C $TempRoot add .gitignore src
    & git -C $TempRoot -c user.name="Test" -c user.email="test@example.com" commit -q -m "init"
    Assert-True ($LASTEXITCODE -eq 0) 'initial commit failed.'

    # 1. First run generates repo-map.txt
    $r1 = (& $Inspector -RepoPath $TempRoot -Format json -GenerateRepoMap | ConvertFrom-Json)
    Assert-True ($r1.repoMapStatus -eq 'generated') "Expected generated, got $($r1.repoMapStatus)"
    $mapPath = Join-Path $TempRoot '.agent-pack/.runtime/repo-map.txt'
    Assert-True (Test-Path -LiteralPath $mapPath -PathType Leaf) 'repo-map.txt not created.'

    # Verify git ignores repo-map.txt
    & git -C $TempRoot check-ignore -q -- '.agent-pack/.runtime/repo-map.txt'
    Assert-True ($LASTEXITCODE -eq 0) 'repo-map.txt must be ignored by Git.'

    $mapContent = [IO.File]::ReadAllText($mapPath, $Utf8)
    Assert-True ($mapContent.Contains('class InvoiceService')) 'Missing C# class symbol.'
    Assert-True ($mapContent.Contains('interface IInvoiceGateway')) 'Missing C# interface symbol.'
    Assert-True ($mapContent.Contains('TABLE dbo.Invoices')) 'Missing SQL table symbol.'
    Assert-True ($mapContent.Contains('PROCEDURE dbo.usp_GetInvoices')) 'Missing SQL proc symbol.'
    Assert-True ($mapContent.Contains('function fetchInvoices')) 'Missing TS function symbol.'
    Assert-True (-not $mapContent.Contains('SuperSecretValue12345')) 'Secret value leaked into repo-map.txt!'
    Assert-True (-not $mapContent.Contains('AnotherSecretBody999')) 'Function body leaked into repo-map.txt!'

    # 2. Second run on clean repo hits cache
    $r2 = (& $Inspector -RepoPath $TempRoot -Format json -GenerateRepoMap | ConvertFrom-Json)
    Assert-True ($r2.repoMapStatus -eq 'cache-hit') "Expected cache-hit on unchanged clean HEAD, got $($r2.repoMapStatus)"

    # 3. New commit invalidates cache and picks up new symbol
    [IO.File]::WriteAllText((Join-Path $TempRoot 'src/Billing/TaxCalculator.cs'), "public record TaxResult(decimal Value);`n", $Utf8)
    & git -C $TempRoot add src/Billing/TaxCalculator.cs
    & git -C $TempRoot -c user.name="Test" -c user.email="test@example.com" commit -q -m "add tax"
    $r3 = (& $Inspector -RepoPath $TempRoot -Format json -GenerateRepoMap | ConvertFrom-Json)
    Assert-True ($r3.repoMapStatus -eq 'generated') "Expected generated after commit, got $($r3.repoMapStatus)"
    $mapContent2 = [IO.File]::ReadAllText($mapPath, $Utf8)
    Assert-True ($mapContent2.Contains('record TaxResult')) 'New symbol missing after cache invalidation.'
    Assert-True ($mapContent2.Contains('cache_revision:')) 'Expected cache_revision header in repo-map.txt.'
    Assert-True (-not $mapContent2.Contains('cache_key:')) 'Legacy cache_key header should not be emitted.'

    # 4. ef_scan must NOT flag repo-map.txt (neither cache_revision nor legacy cache_key) as SECRET_IN_LOG
    . (Join-Path $PackRoot 'repo-template/.agents/skills/harness-cycle/scripts/ef-secrets.ps1')
    $loadRc = ef_load_secrets -RepoRoot $TempRoot
    Assert-True ($loadRc -eq 0) "ef_load_secrets failed with $loadRc"
    $scanRc = ef_scan -RepoRoot $TempRoot -CardId 'AB-612'
    Assert-True ($scanRc -eq 0) "ef_scan falsely flagged repo-map.txt (exit $scanRc)."

    Write-Host 'test-repo-map.ps1 passed.'
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolved = [IO.Path]::GetFullPath($TempRoot)
        $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'test-repo-map-*') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
