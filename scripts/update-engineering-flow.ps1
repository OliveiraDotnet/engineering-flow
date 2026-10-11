[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoPath,

    [switch]$Check,
    [switch]$Apply,

    [string[]]$Integration = @(),

    [string[]]$AcceptPack = @(),
    [string[]]$AcceptMerge = @(),
    [string[]]$KeepLocal = @()
)

# Engineering Flow alias: preserve legacy state, ownership and parameter semantics.
& (Join-Path $PSScriptRoot 'update-agent-pack.ps1') @PSBoundParameters
