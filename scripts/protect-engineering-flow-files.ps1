#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoPath,
    [switch]$CheckOnly,
    [switch]$DryRun,
    [switch]$UnignoreAgentsMd
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $RepoPath).Path
$path=Join-Path $root '.gitignore'
$utf8=[Text.UTF8Encoding]::new($false,$true)
$patterns=@('*.agent-pack.new','*.agent-pack.backup-*','.agent-pack/','.agent-pack/.runtime/','.agent-pack/.runtime/task.lock','.agent-pack/*.tmp','.agent-pack/*.lock','.agent-pack/logs/','.agent-pack/cache/','.agent-pack/tmp/','.agent-pack/sessions/','.agent-pack/worktrees/','.agent-pack/evidencias/','.agents/','.claude/','.grok/','.grok/sessions/','.grok/worktrees/','.ai-memory.toml','docs/engineering-flow/','docs/ai/','prompts/','.engineering-flow-evidence/','Planejamento/','planejamento/')
$bytes=[byte[]]@()
$text=''
if (Test-Path -LiteralPath $path) {
 $item=Get-Item -LiteralPath $path -Force
 if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked/non-file .gitignore cannot be protected safely.' }
 $bytes=[IO.File]::ReadAllBytes($path)
 if ($bytes -contains 0) { throw 'Non UTF-8 .gitignore needs a reviewed encoding-preserving change.' }
 $offset=if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {3} else {0}
 $text=$utf8.GetString($bytes,$offset,$bytes.Length-$offset)
}

function Get-IgnoreSourceLine {
 param([string]$RawOutput)
 $firstLine=($RawOutput -split '\r?\n' | Where-Object { $_ } | Select-Object -First 1)
 $left=($firstLine -split "`t", 2)[0]
 $parts=$left -split ':', 3
 return "$($parts[0]):$($parts[1])"
}

if ($UnignoreAgentsMd) {
 if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $global:LASTEXITCODE=0; exit 0 }
 & git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
 if ($LASTEXITCODE -ne 0) { $global:LASTEXITCODE=0; exit 0 }

 & git -C $root check-ignore -q -- AGENTS.md
 $checkRc=$LASTEXITCODE
 if ($checkRc -eq 1) { $global:LASTEXITCODE=0; exit 0 }
 if ($checkRc -ne 0) { throw "git check-ignore failed with exit code $checkRc" }

 $ignoreInfo=(& git -C $root check-ignore -v -- AGENTS.md) | Out-String
 $sourceLine=Get-IgnoreSourceLine -RawOutput $ignoreInfo

 if ($DryRun) {
  Write-Host "WOULD-UNIGNORE $path (!AGENTS.md would be appended; was ignored by $sourceLine)"
  $global:LASTEXITCODE=0
  exit 0
 }

 if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReadOnly)) { throw '.gitignore is read-only; protection requires a reviewed permission change.' }
 $newline=if ($text.Contains("`r`n")) {"`r`n"} else {"`n"}
 $prefix=if ($text -and -not $text.EndsWith("`n")) {$newline} else {''}
 $addition=$prefix+'# Engineering Flow: AGENTS.md must stay versionable'+$newline+'!AGENTS.md'+$newline
 $stream=[IO.File]::Open($path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try { $extra=$utf8.GetBytes($addition); $stream.Write($extra,0,$extra.Length) } finally { $stream.Dispose() }

 Write-Host "UNIGNORE $path (!AGENTS.md appended; was ignored by $sourceLine)"

 & git -C $root check-ignore -q -- AGENTS.md
 if ($LASTEXITCODE -eq 0) {
  $recheckInfo=(& git -C $root check-ignore -v -- AGENTS.md) | Out-String
  $recheckSourceLine=Get-IgnoreSourceLine -RawOutput $recheckInfo
  [Console]::Error.WriteLine("ERROR: AGENTS.md is still ignored after appending !AGENTS.md ($recheckSourceLine)")
  exit 5
 }
 $global:LASTEXITCODE=0
 exit 0
}

$lines=@($text -split '\r?\n')
$missing=@($patterns | Where-Object { $_ -notin $lines })
if (-not $missing.Count) { exit 0 }
if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReadOnly)) { throw '.gitignore is read-only; protection requires a reviewed permission change.' }
if ($CheckOnly) { exit 0 }
if ($DryRun) { Write-Host "IGNORE    $path ($($missing.Count) rules, dry-run)"; exit 0 }
$newline=if ($text.Contains("`r`n")) {"`r`n"} else {"`n"}
$prefix=if ($text -and -not $text.EndsWith("`n")) {$newline} else {''}
$addition=$prefix+$newline+'# Engineering Flow: clean install; only AGENTS.md stays versionable.'+$newline+($missing -join $newline)+$newline
# Append retains original bytes (including UTF-8 BOM), content and custom rules.
$stream=[IO.File]::Open($path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try { $extra=$utf8.GetBytes($addition); $stream.Write($extra,0,$extra.Length) } finally { $stream.Dispose() }
Write-Host "IGNORE    $path ($($missing.Count) generated-file rules added)"
