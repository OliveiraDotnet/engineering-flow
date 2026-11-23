#Requires -Version 7
& (Join-Path $PSScriptRoot '..\repo-template\.agents\tools\session-state.ps1') @args
exit $LASTEXITCODE
