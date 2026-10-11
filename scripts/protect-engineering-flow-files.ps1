[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RepoPath,[switch]$CheckOnly,[switch]$DryRun)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $RepoPath).Path
$path=Join-Path $root '.gitignore'
$utf8=[Text.UTF8Encoding]::new($false,$true)
$patterns=@('*.agent-pack.new','*.agent-pack.backup-*','.agent-pack/.runtime/','.agent-pack/*.tmp','.agent-pack/*.lock','.agent-pack/logs/','.agent-pack/cache/','.agent-pack/tmp/','.agent-pack/sessions/','.agent-pack/worktrees/','.engineering-flow-evidence/','.grok/sessions/','.grok/worktrees/','.codex/sessions/','.codex/worktrees/','.claude/sessions/','.claude/worktrees/')
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
$lines=@($text -split '\r?\n')
$missing=@($patterns | Where-Object { $_ -notin $lines })
if (-not $missing.Count) { return }
if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReadOnly)) { throw '.gitignore is read-only; protection requires a reviewed permission change.' }
if ($CheckOnly) { return }
if ($DryRun) { Write-Host "IGNORE    $path ($($missing.Count) rules, dry-run)"; return }
$newline=if ($text.Contains("`r`n")) {"`r`n"} else {"`n"}
$prefix=if ($text -and -not $text.EndsWith("`n")) {$newline} else {''}
$addition=$prefix+$newline+'# Engineering Flow: generated files only; state.txt and project guidance stay versionable.'+$newline+($missing -join $newline)+$newline
# Append retains original bytes (including UTF-8 BOM), content and custom rules.
$stream=[IO.File]::Open($path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try { $extra=$utf8.GetBytes($addition); $stream.Write($extra,0,$extra.Length) } finally { $stream.Dispose() }
Write-Host "IGNORE    $path ($($missing.Count) generated-file rules added)"
