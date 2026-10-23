#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = Split-Path -Parent $ScriptDir
$Inspector = Join-Path $PackRoot "repo-template\.agents\skills\bootstrap-dotnet-repo\scripts\inspect-dotnet-repo.ps1"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$modernPath = Join-Path $PackRoot "tests\fixtures\modern-web"
$modern = & $Inspector -RepoPath $modernPath -Format json | ConvertFrom-Json
Assert-True ($modern.targetFrameworks -contains "net8.0") "Modern fixture target framework was not detected."
Assert-True ($modern.optionalProfilesSuggested -contains "web") "Modern web profile was not suggested."
Assert-True ($modern.optionalProfilesSuggested -notcontains "sqlserver") "Generic Dapper and SQL must not imply SQL Server."
Assert-True ($modern.testProjects.Count -eq 1) "Modern test project was not detected."

$legacyPath = Join-Path $PackRoot "tests\fixtures\legacy-framework"
$legacy = & $Inspector -RepoPath $legacyPath -Format json | ConvertFrom-Json
Assert-True ($legacy.targetFrameworks -contains "v4.8") "Legacy target framework was not detected."
Assert-True (@($legacy.projectFiles | Where-Object { $_.style -eq "classic" }).Count -eq 1) "Classic project style was not detected."
Assert-True ($legacy.applicationTypes -contains "classic-framework") "Classic application type was not detected."
Assert-True ($legacy.optionalProfilesSuggested -contains "web") "Legacy web profile was not suggested."
Assert-True ($legacy.optionalProfilesSuggested -notcontains "legacy-framework") "Inspector suggested a profile that the pack cannot install."

$scratch = Join-Path ([IO.Path]::GetTempPath()) ("pack-inspector-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $project = Join-Path $scratch 'App.csproj'
    foreach ($provider in @('EntityFramework', 'Dapper', 'Npgsql.EntityFrameworkCore.PostgreSQL', 'Microsoft.EntityFrameworkCore.Sqlite', 'Pomelo.EntityFrameworkCore.MySql')) {
        [IO.File]::WriteAllText($project, '<Project><ItemGroup><PackageReference Include="' + $provider + '" /></ItemGroup></Project>')
        $result = & $Inspector -RepoPath $scratch -Format json | ConvertFrom-Json
        Assert-True ($result.optionalProfilesSuggested -notcontains 'sqlserver') "False SQL Server suggestion for $provider."
    }
    foreach ($provider in @('Microsoft.EntityFrameworkCore.SqlServer', 'System.Data.SqlClient', 'Microsoft.Data.SqlClient')) {
        [IO.File]::WriteAllText($project, '<Project><ItemGroup><PackageReference Include="' + $provider + '" /></ItemGroup></Project>')
        $result = & $Inspector -RepoPath $scratch -Format json | ConvertFrom-Json
        Assert-True ($result.optionalProfilesSuggested -contains 'sqlserver') "Missing SQL Server suggestion for $provider."
    }
    [IO.File]::WriteAllText($project, '<Project />')
    $packages = Join-Path $scratch 'packages.config'
    [IO.File]::WriteAllText($packages, '<packages><package id="System.Data.SqlClient" /></packages>')
    $result = & $Inspector -RepoPath $scratch -Format json | ConvertFrom-Json
    Assert-True ($result.optionalProfilesSuggested -contains 'sqlserver') 'Classic packages.config provider not detected.'
    Remove-Item -LiteralPath $packages
    $generated = Join-Path $scratch 'obj'
    New-Item -ItemType Directory -Path $generated | Out-Null
    [IO.File]::WriteAllText((Join-Path $generated 'Generated.csproj'), '<Project>Microsoft.Data.SqlClient</Project>')
    $result = & $Inspector -RepoPath $scratch -Format json | ConvertFrom-Json
    Assert-True ($result.optionalProfilesSuggested -notcontains 'sqlserver') 'Generated files must be excluded.'
    [IO.File]::WriteAllText((Join-Path $scratch 'schema.sql'), 'SET ANSI_NULLS ON; -- synthetic-secret-not-for-output')
    $output = & $Inspector -RepoPath $scratch -Format json
    $result = $output | ConvertFrom-Json
    Assert-True ($result.optionalProfilesSuggested -contains 'sqlserver') 'T-SQL evidence not detected.'
    Assert-True (($output -join '') -notmatch 'synthetic-secret') 'Inspector leaked source content.'
} finally {
    if ($scratch.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $scratch) -like 'pack-inspector-*') {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
Write-Host "Repository inspector smoke and provider tests passed."
