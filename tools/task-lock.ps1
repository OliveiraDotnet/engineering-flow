#Requires -Version 7
& (Join-Path $PSScriptRoot '..\repo-template\.agents\tools\task-lock.ps1') @args
exit $LASTEXITCODE
