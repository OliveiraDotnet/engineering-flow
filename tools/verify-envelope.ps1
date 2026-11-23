#Requires -Version 7
& (Join-Path $PSScriptRoot '..\repo-template\.agents\tools\verify-envelope.ps1') @args
exit $LASTEXITCODE
