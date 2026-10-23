#Requires -Version 7
[CmdletBinding()]
param([string]$BashExecutable)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('engineering-flow-hygiene-'+[Guid]::NewGuid().ToString('N'))
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Put([string]$Repo,[string]$Path,[string]$Text) {
 $full=Join-Path $Repo $Path
 [IO.Directory]::CreateDirectory((Split-Path -Parent $full)) | Out-Null
 [IO.File]::WriteAllText($full,$Text,[Text.UTF8Encoding]::new($false))
}
function Assert-Hygiene([string]$Repo) {
 $ignored=@('AGENTS.md.agent-pack.new','AGENTS.md.agent-pack.backup-20261011','.agents/skills/bugfix/SKILL.md.agent-pack.new','.agent-pack/.runtime/.gitignore','.agent-pack/.runtime/backups/2.0.0/backup.txt','.agent-pack/.runtime/retired/old.txt','.agent-pack/.runtime/update.lock','.agent-pack/.runtime/task.lock','.agent-pack/state.txt.tmp','.agent-pack/cache/cache.txt','.agent-pack/logs/run.log','.grok/sessions/session.log','.engineering-flow-evidence/report.txt')
 $visible=@('AGENTS.md','.agent-pack/state.txt','.grok/config.toml','.grok/skills/new-project/SKILL.md','.agents/skills/new-project/SKILL.md','.grok/agents/repo-explorer.md','docs/ai/runbook.md')
 foreach ($p in $ignored+$visible) {
  if (-not (Test-Path (Join-Path $Repo $p))) {
   $text=if ($p -eq '.agent-pack/.runtime/.gitignore') {"*`n!.gitignore`n"} else {'fixture-only'}
   Put $Repo $p $text
  }
 }
 foreach ($p in $ignored) { & git -C $Repo check-ignore -q -- $p; Assert ($LASTEXITCODE -eq 0) "Generated file visible to Git: $p" }
 foreach ($p in $visible) { & git -C $Repo check-ignore -q -- $p; Assert ($LASTEXITCODE -eq 1) "Necessary project file hidden from Git: $p" }
 $status=@(& git -C $Repo status --short --untracked-files=all)
 Assert ($LASTEXITCODE -eq 0) 'Unable to inspect fixture Git status.'
 Assert (-not (($status -join "`n") -match 'agent-pack\.new|agent-pack\.backup|\.runtime/|sessions/|worktrees/|state\.txt\.tmp|run\.log')) 'Operational Git noise remains.'
 Assert (($status -join "`n").Contains('.agent-pack/state.txt')) 'State is not versionable.'
}
try {
 [IO.Directory]::CreateDirectory($temp) | Out-Null
 foreach ($mode in @('powershell','bash')) {
  if ($mode -eq 'bash' -and -not $BashExecutable) { continue }
  $repo=Join-Path $temp $mode
  [IO.Directory]::CreateDirectory($repo) | Out-Null
  & git -C $repo init -q
  Assert ($LASTEXITCODE -eq 0) 'Unable to create hygiene Git fixture.'
  $original="# Company rules`r`n.env`r`ncompany-cache/`r`n"
  [IO.File]::WriteAllText((Join-Path $repo '.gitignore'),$original,[Text.UTF8Encoding]::new($true))
  $before=[IO.File]::ReadAllBytes((Join-Path $repo '.gitignore'))
  if ($mode -eq 'powershell') { & (Join-Path $PSScriptRoot 'protect-engineering-flow-files.ps1') -RepoPath $repo -DryRun }
  else { & $BashExecutable (Join-Path $PSScriptRoot 'protect-engineering-flow-files.sh').Replace('\','/') $repo.Replace('\','/') dry-run; Assert ($LASTEXITCODE -eq 0) 'Bash protection preview failed.' }
  Assert ((Get-FileHash (Join-Path $repo '.gitignore')).Hash -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($before))) 'Protection preview wrote .gitignore.'
  foreach ($iteration in 1..2) {
   if ($mode -eq 'powershell') { & (Join-Path $PSScriptRoot 'protect-engineering-flow-files.ps1') -RepoPath $repo }
   else { & $BashExecutable (Join-Path $PSScriptRoot 'protect-engineering-flow-files.sh').Replace('\','/') $repo.Replace('\','/'); Assert ($LASTEXITCODE -eq 0) 'Bash protection failed.' }
   $after=[IO.File]::ReadAllBytes((Join-Path $repo '.gitignore'))
   Assert ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String($after[0..($before.Length-1)])) 'Custom .gitignore bytes/BOM/CRLF changed.'
   if ($iteration -eq 1) { $first=(Get-FileHash (Join-Path $repo '.gitignore')).Hash }
   else { Assert ((Get-FileHash (Join-Path $repo '.gitignore')).Hash -eq $first) 'Protection is not idempotent.' }
  }
  Assert-Hygiene $repo
 }
 # Integration: install preserves own rules; update also repairs missing protection.
 $installed=Join-Path $temp 'installed'
 [IO.Directory]::CreateDirectory($installed) | Out-Null
 & git -C $installed init -q
 Put $installed '.gitignore' "# custom destination`n.env`n"
 & (Join-Path $PSScriptRoot 'install-agent-pack.ps1') -RepoPath $installed -Profile core -Confirm:$false
 Assert-Hygiene $installed
 # The visibility fixture creates a synthetic lock; release it before exercising the updater.
 $fixtureLock=Join-Path $installed '.agent-pack/.runtime/update.lock'
 Assert ([IO.File]::ReadAllText($fixtureLock) -eq 'fixture-only') 'Unexpected lock content in hygiene fixture.'
 Remove-Item -LiteralPath $fixtureLock -Force
 Put $installed '.gitignore' "# custom destination`n.env`n"
 & (Join-Path $PSScriptRoot 'update-agent-pack.ps1') -RepoPath $installed -Apply -Confirm:$false
 Assert-Hygiene $installed
 Assert ((Get-Content (Join-Path $installed '.gitignore') -Raw).StartsWith("# custom destination`n.env`n")) 'Update replaced destination custom rules.'
 Write-Host 'Git hygiene passed: real check-ignore/status, custom UTF-8 BOM/CRLF preserved, preview/idempotence, necessary state/config/skills/docs visible, generated backups/conflicts/runtime/cache/session/worktree/evidence ignored; install and update integration verified.'
} finally {
 $full=[IO.Path]::GetFullPath($temp)
 $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
 if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notlike 'engineering-flow-hygiene-*') { throw 'Unsafe hygiene cleanup target.' }
 if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
