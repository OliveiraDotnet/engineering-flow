[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoPath,

    [string[]]$Profile = @(),
    [string[]]$Integration = @(),

    [switch]$IncludeClaude,
    [switch]$IncludeGrokBuild,
    [switch]$InstallGlobal,
    [switch]$AllowNonGit,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$DiscoverOnly
)

# Engineering Flow alias: preserve legacy state, ownership and parameter semantics.
& (Join-Path $PSScriptRoot 'install-agent-pack.ps1') @PSBoundParameters
